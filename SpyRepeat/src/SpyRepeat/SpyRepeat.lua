include("InstanceManager");
include("SupportFunctions");
include("SpyRepeat_Common");

local rows = InstanceManager:new("SpyRow", "Root", Controls.SpyStack);
local pending = {};
local status = {};
local clock = 0;
local elapsed = 0;
local serial = 0;
local visible = false;
local urgentPauses = {};
local blocked = {};

local function Text(key, ...)
    return Locale.Lookup("LOC_SR_" .. key, ...);
end

local function Player()
    local id = Game.GetLocalPlayer();
    if id == nil or id < 0 then return nil; end
    return Players[id];
end

local function Registry()
    local player = Player();
    return player and player:GetProperty(SpyRepeat.Property) or {};
end

local function ActiveTurn()
    local player = Player();
    return player ~= nil and player:IsTurnActive();
end

local function CurrentOperation(unit)
    local id = unit:GetSpyOperation();
    return id ~= nil and id ~= -1 and GameInfo.UnitOperations[id] or nil;
end

local function CityAtUnit(unit)
    local plot = Map.GetPlot(unit:GetX(), unit:GetY());
    return plot and Cities.GetPlotPurchaseCity(plot);
end

local function Snapshot(unit)
    local operation = CurrentOperation(unit);
    if not SpyRepeat.IsRepeatable(operation) then return nil; end
    local plot = Map.GetPlot(unit:GetX(), unit:GetY());
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    if city == nil then return nil; end
    return {Operation = operation.OperationType, Plot = plot:GetIndex()};
end

local function Send(id, action, details, after)
    local key = tostring(id);
    if pending[key] ~= nil or not ActiveTurn() then return; end
    serial = serial + 1;
    local token = tostring(Game.GetCurrentGameTurn()) .. ":" .. tostring(clock) .. ":" .. tostring(serial);
    local parameters = {OnStart = "SpyRepeat_Set", UnitID = id, Action = action, Token = token};
    for k, value in pairs(details or {}) do parameters[k] = value; end
    pending[key] = {token = token, action = action, deadline = clock + 8, after = after};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, parameters);
end

local function Pause(id, reason)
    Send(id, "pause", {Reason = reason});
    -- A visible reason is actionable; open the list once when the pause is issued.
    visible = true;
    Controls.Panel:SetHide(false);
end

local function Target(entry)
    local plot = Map.GetPlotByIndex(entry.Plot);
    local city = plot and Cities.GetPlotPurchaseCity(plot);
    if city == nil or city:GetOwner() ~= entry.CityOwner or city:GetID() ~= entry.CityID then return nil; end
    return plot, city;
end

local function HasPromotion(unit)
    local can, results = UnitManager.CanStartCommand(unit, UnitCommandTypes.PROMOTE, true, true);
    local promotions = results and results[UnitCommandResults.PROMOTIONS];
    return can and promotions ~= nil and #promotions > 0;
end

local function Toggle(id)
    local key = tostring(id);
    local entry = Registry()[key];
    if entry and entry.Enabled then Send(id, "off"); return; end
    local unit = Player():GetUnits():FindID(id);
    if not SpyRepeat.IsSpy(unit) then return; end
    local snapshot = Snapshot(unit);
    if snapshot == nil and entry then
        -- Resume the saved assignment only while idle in the original city.
        local _, city = Target(entry);
        local currentCity = CityAtUnit(unit);
        if CurrentOperation(unit) == nil and city and currentCity and
            currentCity:GetOwner() == city:GetOwner() and currentCity:GetID() == city:GetID() then
            snapshot = {Operation = entry.Operation, Plot = entry.Plot};
        end
    end
    if snapshot == nil then status[key] = "ASSIGN_FIRST"; return; end
    if HasPromotion(unit) then status[key] = "PROMOTION"; return; end
    Send(id, "enable", snapshot);
end

local function Parameters(plot)
    local parameters = {};
    parameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    parameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
    return parameters;
end

local function StartReserved(id)
    local entry = Registry()[tostring(id)];
    local unit = Player():GetUnits():FindID(id);
    if not ActiveTurn() or not entry or not entry.Enabled or not SpyRepeat.IsSpy(unit) then return; end
    -- Re-check after the save-state acknowledgement: the player may have intervened.
    if CurrentOperation(unit) ~= nil or not unit:IsReadyToMove() then return; end
    if HasPromotion(unit) then Pause(id, "PROMOTION"); return; end
    local plot = Target(entry);
    local currentCity = CityAtUnit(unit);
    if not plot or not currentCity or currentCity:GetOwner() ~= entry.CityOwner or
        currentCity:GetID() ~= entry.CityID then Pause(id, "TARGET_CHANGED"); return; end
    local operation = GameInfo.UnitOperations[entry.Operation];
    local parameters = Parameters(plot);
    if not SpyRepeat.IsRepeatable(operation) or
        not UnitManager.CanStartOperation(unit, operation.Hash, plot, parameters) then
        Pause(id, "UNAVAILABLE"); return;
    end
    UnitManager.RequestOperation(unit, operation.Hash, parameters);
    status[tostring(id)] = "REQUESTED";
    print("[SpyRepeat] Requested " .. entry.Operation .. " for " .. tostring(id));
end

local function Process(id, entry)
    local key = tostring(id);
    if not entry.Enabled or pending[key] or blocked[key] then return; end
    local unit = Player():GetUnits():FindID(id);
    if not SpyRepeat.IsSpy(unit) or unit:GetName() ~= entry.Name or unit:GetType() ~= entry.UnitType then
        Pause(id, "OFF_MAP"); return;
    end
    if HasPromotion(unit) then Pause(id, "PROMOTION"); return; end
    local plot = Target(entry);
    local city = CityAtUnit(unit);
    if not plot or not city or city:GetOwner() ~= entry.CityOwner or city:GetID() ~= entry.CityID then
        Pause(id, "TARGET_CHANGED"); return;
    end
    local current = CurrentOperation(unit);
    if current ~= nil then
        if not SpyRepeat.IsRepeatable(current) then Pause(id, "CHANGED"); return; end
        local snapshot = Snapshot(unit);
        if snapshot and (snapshot.Operation ~= entry.Operation or snapshot.Plot ~= entry.Plot) then
            -- A manual assignment in the same city replaces the saved assignment.
            Send(id, "enable", snapshot);
        else status[key] = "RUNNING"; end
        return;
    end
    if not unit:IsReadyToMove() then status[key] = "WAITING"; return; end
    if entry.LastRequestTurn == Game.GetCurrentGameTurn() then return; end
    local operation = GameInfo.UnitOperations[entry.Operation];
    if not SpyRepeat.IsRepeatable(operation) or
        not UnitManager.CanStartOperation(unit, operation.Hash, plot, Parameters(plot)) then
        Pause(id, "UNAVAILABLE"); return;
    end
    -- Persist the guard before dispatch, preventing duplicates even after a UI reload.
    Send(id, "reserve", nil, function() StartReserved(id); end);
end

local function MissionCompleted(owner, missionID)
    if owner ~= Game.GetLocalPlayer() then return; end
    local mission = Player():GetDiplomacy():GetMission(owner, missionID);
    if type(mission) ~= "table" then return; end
    local result = mission.InitialResult;
    local reason;
    if result == EspionageResultTypes.SUCCESS_MUST_ESCAPE or result == EspionageResultTypes.FAIL_MUST_ESCAPE then
        reason = "ESCAPE";
    elseif result == EspionageResultTypes.CAPTURED or result == EspionageResultTypes.KILLED or
        mission.EscapeResult == EspionageResultTypes.CAPTURED or mission.EscapeResult == EspionageResultTypes.KILLED then
        reason = "OFF_MAP";
    end
    if reason then
        for key, entry in pairs(Registry()) do
            if entry.Name == mission.Name then
                -- Also prevents a pending reservation from dispatching after an escape event.
                if pending[key] then pending[key].after = nil; end
                status[key] = reason;
                -- Queue after any outstanding settings acknowledgement.
                urgentPauses[key] = reason;
                visible = true;
                Controls.Panel:SetHide(false);
            end
        end
    end
end

local function OperationStarted(owner, id, operationID)
    if owner ~= Game.GetLocalPlayer() then return; end
    local entry = Registry()[tostring(id)];
    local operation = GameInfo.UnitOperations[operationID];
    if entry and entry.Enabled and operation and
        string.find(operation.OperationType, "UNITOPERATION_SPY_TRAVEL", 1, true) then
        urgentPauses[tostring(id)] = "CHANGED";
        if pending[tostring(id)] then pending[tostring(id)].after = nil; end
    end
end

local function Refresh()
    local player = Player();
    Controls.OpenButton:SetHide(player == nil);
    if player == nil then Controls.Panel:SetHide(true); return; end
    local registry = Registry();
    local list = {};
    local seen = {};
    local paused = 0;
    for _, unit in player:GetUnits():Members() do
        if SpyRepeat.IsSpy(unit) then
            local key = tostring(unit:GetID());
            list[#list + 1] = {id = unit:GetID(), unit = unit, entry = registry[key]};
            seen[key] = true;
        end
    end
    for key, entry in pairs(registry) do
        if not entry.Enabled and entry.Reason ~= "OFF" then paused = paused + 1; end
        if not seen[key] then list[#list + 1] = {id = tonumber(key), entry = entry}; end
    end
    Controls.OpenButton:SetText(Text("TITLE") .. (paused > 0 and " (" .. paused .. ")" or ""));
    if not visible then return; end
    table.sort(list, function(a, b) return a.id < b.id; end);
    rows:ResetInstances();
    for _, item in ipairs(list) do
        local id, unit, entry = item.id, item.unit, item.entry;
        local key = tostring(id);
        local row = rows:GetInstance();
        row.NameLabel:SetText(Locale.Lookup(unit and unit:GetName() or entry.Name));
        local operation = entry and GameInfo.UnitOperations[entry.Operation] or (unit and CurrentOperation(unit));
        local city = unit and CityAtUnit(unit);
        local location = city and Locale.Lookup(city:GetName()) or Text("AWAY");
        TruncateStringWithTooltip(row.MissionLabel, 370,
            location .. " · " .. (operation and Locale.Lookup(operation.Description) or Text("NO_MISSION")));
        local reason = pending[key] and "SAVING" or (blocked[key] and "SAVE_FAILED") or
            (urgentPauses[key] or (entry and not entry.Enabled and entry.Reason) or status[key] or "ASSIGN_FIRST");
        TruncateStringWithTooltip(row.StatusLabel, 370, Text(reason));
        row.ToggleButton:SetText(Text(entry and entry.Enabled and "DISABLE" or (entry and "RESUME" or "ENABLE")));
        row.ToggleButton:SetHide(false);
        row.ToggleButton:SetDisabled(not ActiveTurn() or pending[key] ~= nil or unit == nil);
        row.ToggleButton:RegisterCallback(Mouse.eLClick, function() Toggle(id); end);
        row.RemoveButton:SetHide(entry == nil or entry.Enabled);
        row.RemoveButton:SetDisabled(not ActiveTurn() or pending[key] ~= nil);
        row.RemoveButton:RegisterCallback(Mouse.eLClick, function() Send(id, "remove"); end);
    end
    if #list == 0 then
        local row = rows:GetInstance();
        row.NameLabel:SetText(Text("NO_SPIES"));
        row.MissionLabel:SetText(""); row.StatusLabel:SetText("");
        row.ToggleButton:SetHide(true); row.RemoveButton:SetHide(true);
    end
    Controls.SpyStack:CalculateSize();
    Controls.Scroll:CalculateInternalSize();
end

local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.5 then return; end
    elapsed = 0;
    local registry = Registry();
    for key, request in pairs(pending) do
        local entry = registry[key];
        if request.action == "reserve" and entry and not entry.Enabled then
            pending[key] = nil;
            status[key] = nil;
        elseif (request.action == "remove" and entry == nil) or (entry and entry.Token == request.token) then
            pending[key] = nil;
            blocked[key] = nil;
            status[key] = nil;
            if request.after and not urgentPauses[key] then request.after(); end
        elseif clock >= request.deadline then
            pending[key] = nil; status[key] = "SAVE_FAILED";
            -- No automatic retry loop on a rejected or missing gameplay operation.
            blocked[key] = true;
            urgentPauses[key] = nil;
        end
    end
    if ActiveTurn() then
        for key, reason in pairs(urgentPauses) do
            if not pending[key] then
                local entry = Registry()[key];
                if entry and entry.Enabled then Pause(tonumber(key), reason); end
                urgentPauses[key] = nil;
            end
        end
        for key, entry in pairs(Registry()) do
            if not urgentPauses[key] then Process(tonumber(key), entry); end
        end
    end
    Refresh();
end

Controls.OpenButton:RegisterCallback(Mouse.eLClick, function()
    visible = not visible; Controls.Panel:SetHide(not visible); Refresh();
end);
Controls.CloseButton:RegisterCallback(Mouse.eLClick, function() visible = false; Controls.Panel:SetHide(true); end);
Events.SpyMissionCompleted.Add(MissionCompleted);
Events.UnitOperationStarted.Add(OperationStarted);
ContextPtr:SetUpdate(Update);
print("[SpyRepeat] UI loaded");
