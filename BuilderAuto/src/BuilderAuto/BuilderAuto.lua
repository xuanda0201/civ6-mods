include("BuilderAuto_Common");
include("BuilderAuto_Rules");

local BA = BuilderAuto;
local pending, plans, flights, holds, urgent, statuses, examined = {}, {}, {}, {}, {}, {}, {};
local clock, elapsed, serial, revision = 0, 0, 0, 0;
local actionStack;
local actionParent;
local panelLookupWarned = false;

local function Text(key, ...)
    return Locale.Lookup("LOC_BA_" .. key, ...);
end

local function Player()
    local id = Game.GetLocalPlayer();
    return id ~= nil and id >= 0 and Players[id] or nil;
end

local function Unit(id)
    local player = Player();
    return player and player:GetUnits():FindID(id);
end

local function State(unit)
    return unit:GetProperty(BA.Property) or {};
end

local function Active()
    local player = Player();
    return player ~= nil and player:IsTurnActive();
end

local function Send(id, action, details, after)
    if pending[id] or not Active() then return; end
    serial = serial + 1;
    local token = table.concat({Game.GetCurrentGameTurn(), clock, serial}, ":");
    local parameters = {OnStart = "BuilderAuto_Set", UnitID = id, Action = action, Token = token};
    for k, value in pairs(details or {}) do parameters[k] = value; end
    pending[id] = {token = token, deadline = clock + 8, action = action, after = after};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, parameters);
end

local function Stop(id, reason)
    holds[id] = reason;
    urgent[id] = reason;
    plans[id] = nil;
    examined[id] = nil;
    if pending[id] then pending[id].after = nil; end
end

local function Toggle(id)
    local unit = Unit(id);
    if unit == nil or pending[id] then return; end
    local state = State(unit);
    if state.Enabled and not holds[id] then Stop(id, "OFF"); return; end
    -- Do not adopt a movement queue that was issued by the player.
    if UnitManager.GetQueuedDestination(unit) ~= nil then statuses[id] = "MANUAL_QUEUE"; return; end
    urgent[id] = nil;
    Send(id, "enable", nil, function()
        holds[id] = nil; examined[id] = nil; statuses[id] = "RUNNING";
    end);
end

local function OperationHash(operationID)
    local definition = GameInfo.UnitOperations[operationID];
    return definition and definition.Hash or operationID;
end

local function OnOperation(owner, id, operationID)
    if owner ~= Game.GetLocalPlayer() then return; end
    local flight = flights[id];
    if flight and not flight.acknowledged and flight.operation == OperationHash(operationID) then
        flight.acknowledged = true;
        return;
    end
    local unit = Unit(id);
    if unit and State(unit).Enabled then Stop(id, "MANUAL"); end
end

local function OnCommand(owner, id)
    if owner ~= Game.GetLocalPlayer() then return; end
    local unit = Unit(id);
    if unit and State(unit).Enabled then Stop(id, "MANUAL"); end
end

local function Execute(id, signature, operation, destination, improvement)
    local unit = Unit(id);
    if not Active() or unit == nil or not State(unit).Enabled or holds[id] or
        BA.Signature(unit) ~= signature or not unit:IsReadyToMove() then return; end
    local ready, reason = BA.Prepare();
    if not ready then Stop(id, reason); return; end
    local plot = Map.GetPlotByIndex(destination);
    local origin = Map.GetPlot(unit:GetX(), unit:GetY());
    local danger = {};
    if plot == nil or plot:GetOwner() ~= unit:GetOwner() or not BA.IsVisible(plot) or
        BA.Danger(origin, danger) or BA.Danger(plot, danger) then Stop(id, "DANGER"); return; end
    if operation ~= UnitOperationTypes.MOVE_TO and operation ~= UnitOperationTypes.SKIP_TURN then
        local job = BA.Job(plot, unit);
        if job == nil or job.operation ~= operation or job.improvement ~= improvement then
            Stop(id, "BLOCKED"); return;
        end
    end
    local parameters = operation == UnitOperationTypes.SKIP_TURN and {} or BA.Parameters(plot, improvement);
    if not UnitManager.CanStartOperation(unit, operation, nil, parameters) then Stop(id, "BLOCKED"); return; end
    -- Installed before dispatch so a synchronous operation event is recognized.
    flights[id] = {operation = operation, signature = signature, deadline = clock + 10, acknowledged = false};
    UnitManager.RequestOperation(unit, operation, parameters);
    print("[BuilderAuto] Requested " .. tostring(operation) .. " for " .. tostring(id) .. " at " .. tostring(destination));
end

local function Process(unit, reservations, danger)
    local id = unit:GetID();
    local state = State(unit);
    if not state.Enabled or holds[id] or pending[id] then return; end
    local signature = BA.Signature(unit);
    local flight = flights[id];
    if flight then
        if flight.operation == UnitOperationTypes.SKIP_TURN and
            (flight.acknowledged or not unit:IsReadyToMove()) then
            flights[id] = nil;
            return;
        elseif signature ~= flight.signature then
            flights[id] = nil;
        elseif clock >= flight.deadline then
            flights[id] = nil; Stop(id, "BLOCKED"); return;
        else return; end
    end
    local origin = Map.GetPlot(unit:GetX(), unit:GetY());
    if origin == nil or origin:GetOwner() ~= unit:GetOwner() then Stop(id, "OUTSIDE"); return; end
    if BA.Danger(origin, danger) then Stop(id, "DANGER"); return; end
    if not unit:IsReadyToMove() or unit:GetMovesRemaining() <= 0 then
        if statuses[id] ~= "NO_WORK" then statuses[id] = "WAIT_MOVES"; end
        return;
    end
    if UnitManager.GetQueuedDestination(unit) ~= nil then Stop(id, "MANUAL"); return; end
    local ready, reason = BA.Prepare();
    if not ready then Stop(id, reason); return; end
    if state.LastSignature == signature then statuses[id] = "WAIT_TURN"; return; end
    local scanKey = signature .. ":" .. tostring(revision);
    if examined[id] == scanKey then return; end
    examined[id] = scanKey;

    local job = plans[id];
    if job then
        local target = Map.GetPlotByIndex(job.plot);
        local current = target and BA.Job(target, unit);
        if current == nil or current.operation ~= job.operation or current.improvement ~= job.improvement or
            (reservations[job.plot] ~= nil and reservations[job.plot] ~= id) or
            not BA.Path(unit, target, danger) then
            if reservations[job.plot] == id then reservations[job.plot] = nil; end
            job = nil; plans[id] = nil;
        end
    end
    if job == nil then job = BA.Plan(unit, reservations, danger); end
    if job == nil then
        statuses[id] = "NO_WORK";
        -- Standing by must not leave another idle-unit prompt every turn.
        -- Skip only this turn, so the builder wakes and checks for new work next turn.
        if UnitOperationTypes.SKIP_TURN and
            UnitManager.CanStartOperation(unit, UnitOperationTypes.SKIP_TURN, nil, {}) then
            Send(id, "reserve", {Signature = signature}, function()
                Execute(id, signature, UnitOperationTypes.SKIP_TURN, origin:GetIndex(), nil);
            end);
        end
        return;
    end
    plans[id] = job;
    reservations[job.plot] = id;
    statuses[id] = job.kind;
    local target = Map.GetPlotByIndex(job.plot);
    local destination, operation, improvement = job.plot, job.operation, job.improvement;
    if origin:GetIndex() ~= job.plot then
        local path = BA.Path(unit, target, danger);
        if path == nil then plans[id] = nil; return; end
        destination = nil;
        for _, index in ipairs(path) do
            if index ~= origin:GetIndex() then destination = index; break; end
        end
        if destination == nil then Stop(id, "BLOCKED"); return; end
        operation = UnitOperationTypes.MOVE_TO; improvement = nil;
        statuses[id] = "MOVING";
    end
    local parameters = BA.Parameters(Map.GetPlotByIndex(destination), improvement);
    if not UnitManager.CanStartOperation(unit, operation, nil, parameters) then Stop(id, "BLOCKED"); return; end
    Send(id, "reserve", {Signature = signature}, function()
        Execute(id, signature, operation, destination, improvement);
    end);
end

local function Builders()
    local result = {};
    local player = Player();
    if player then
        for _, unit in player:GetUnits():Members() do
            if BA.IsBuilder(unit) and unit:GetBuildCharges() > 0 then result[#result + 1] = unit; end
        end
    end
    table.sort(result, function(a, b) return a:GetID() < b:GetID(); end);
    return result;
end

-- Attach our own control to the installed unit panel without replacing its script.
-- Retry during updates: the unit panel can load after this UI context.
local function AttachButton()
    local root = ContextPtr:LookUpControl("/InGame/UnitPanel/ActionsStack");
    local parent = ContextPtr:LookUpControl("/InGame/UnitPanel/StandardActionsStack") or root;
    if parent == nil then
        if not panelLookupWarned then
            print("[BuilderAuto] Waiting for UnitPanel/ActionsStack");
            panelLookupWarned = true;
        end
        return false;
    end
    if actionParent ~= parent then
        Controls.AutomationAction:ChangeParent(parent);
        actionParent = parent;
        print("[BuilderAuto] Automation button attached to unit panel");
    end
    actionStack = root or parent;
    return true;
end

local function SelectedBuilder()
    local unit = UI.GetHeadSelectedUnit();
    if unit and unit:GetOwner() == Game.GetLocalPlayer() and
        BA.IsBuilder(unit) and unit:GetBuildCharges() > 0 then return unit; end
end

local function Refresh()
    local attached = AttachButton();
    local unit = SelectedBuilder();
    Controls.AutomationAction:SetHide(not attached or unit == nil);
    if attached and unit then
        local id = unit:GetID();
        local state = State(unit);
        local enabled = state.Enabled == true and not holds[id];
        local reason = pending[id] and "SAVING" or holds[id] or
            (not state.Enabled and state.Reason) or statuses[id] or (enabled and "RUNNING" or "OFF");
        local label = "BUTTON_OFF";
        if pending[id] then label = "BUTTON_SAVING";
        elseif enabled then label = "BUTTON_ON";
        elseif (holds[id] and holds[id] ~= "OFF") or
            (not state.Enabled and state.Reason and state.Reason ~= "OFF") then label = "BUTTON_PAUSED"; end
        local operation = GameInfo.UnitOperations[UnitOperationTypes.BUILD_IMPROVEMENT];
        local icon = operation and operation.Icon;
        if icon == nil or icon == "" then icon = "ICON_UNITOPERATION_BUILD_IMPROVEMENT"; end
        Controls.AutomationIcon:SetIcon(icon);
        Controls.AutomationButton:SetSelected(enabled);
        Controls.AutomationButton:SetToolTipString(Text(label) .. "[NEWLINE]" ..
            Text(reason) .. "[NEWLINE][NEWLINE]" .. Text(enabled and "DISABLE" or "ENABLE") ..
            "[NEWLINE]" .. Text("HELP"));
        local disabled = not Active() or pending[id] ~= nil;
        Controls.AutomationButton:SetDisabled(disabled);
        Controls.AutomationButton:SetAlpha(disabled and 0.7 or 1);
    end
    if actionStack then
        if actionParent and actionParent ~= actionStack then
            actionParent:CalculateSize();
            actionParent:ReprocessAnchoring();
        end
        actionStack:CalculateSize();
        actionStack:ReprocessAnchoring();
        -- The native panel also performs this sizing on its next refresh. Accommodate
        -- our extra action immediately, regardless of selection event handler order.
        local panel = ContextPtr:LookUpControl("/InGame/UnitPanel/UnitPanelBaseContainer");
        if panel and unit and actionStack:GetSizeX() > panel:GetSizeX() then
            panel:SetSizeX(actionStack:GetSizeX() + 20);
        end
    end
end

local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.5 then return; end
    elapsed = 0;
    if UI.IsGameCoreBusy() then return; end
    for id, request in pairs(pending) do
        local unit = Unit(id);
        if unit == nil then pending[id] = nil; plans[id] = nil; flights[id] = nil;
        elseif State(unit).Token == request.token then
            pending[id] = nil;
            if request.after and not urgent[id] then
                local ok, errorMessage = pcall(request.after);
                if not ok then
                    print("[BuilderAuto] Dispatch paused: " .. tostring(errorMessage));
                    Stop(id, "API_ERROR");
                end
            end
        elseif clock >= request.deadline then
            pending[id] = nil; holds[id] = "SAVE_FAILED"; urgent[id] = nil; plans[id] = nil;
        end
    end
    if Active() then
        for id, reason in pairs(urgent) do
            if not pending[id] then
                if Unit(id) then Send(id, "off", {Reason = reason}); end
                urgent[id] = nil;
            end
        end
        local reservations = {};
        for id, job in pairs(plans) do
            local unit = Unit(id);
            if unit and State(unit).Enabled and not holds[id] then reservations[job.plot] = id;
            else plans[id] = nil; end
        end
        local danger = {};
        for _, unit in ipairs(Builders()) do
            local ok, errorMessage = pcall(Process, unit, reservations, danger);
            if not ok then
                print("[BuilderAuto] Scheduler paused: " .. tostring(errorMessage));
                Stop(unit:GetID(), "API_ERROR");
            end
        end
    end
    Refresh();
end

local function MarkDirty()
    revision = revision + 1;
end

Controls.AutomationButton:RegisterCallback(Mouse.eLClick, function()
    -- Resolve the current selection on click; never act on a previously selected builder.
    local unit = SelectedBuilder();
    if unit then Toggle(unit:GetID()); end
    Refresh();
end);
Controls.AutomationButton:RegisterCallback(Mouse.eMouseEnter, function()
    UI.PlaySound("Main_Menu_Mouse_Over");
end);
Events.UnitSelectionChanged.Add(Refresh);
Events.UnitOperationStarted.Add(OnOperation);
Events.UnitCommandStarted.Add(OnCommand);
Events.UnitMoveComplete.Add(MarkDirty);
Events.UnitChargesChanged.Add(MarkDirty);
Events.ImprovementAddedToMap.Add(MarkDirty);
Events.ImprovementRemovedFromMap.Add(MarkDirty);
Events.PlayerTurnActivated.Add(MarkDirty);
ContextPtr:SetUpdate(Update);
Refresh();
print("[BuilderAuto] UI loaded");
