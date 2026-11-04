include("AutoTheme_Planner");
local AT = AutoTheme;
local run;
local elapsed, clock = 0, 0;

local function Text(key, ...)
    return Locale.Lookup("LOC_AT_" .. key, ...);
end

local function Status(key, ...)
    Controls.StatusPanel:SetHide(false);
    Controls.StatusLabel:SetText(Text(key, ...));
end

local function Active()
    local id = Game.GetLocalPlayer();
    return id ~= nil and id >= 0 and Players[id] ~= nil and Players[id]:IsTurnActive();
end

local function Finish(reason, ...)
    run = nil;
    Controls.ThemeButton:SetText(Text("START"));
    Status(reason, ...);
end

local function Begin()
    if run then run.cancel = true; Status("CANCELLING"); return; end
    if not Active() then Status("WAIT_TURN"); return; end
    -- Do planning on the next UI update so the status can be drawn first.
    run = {planning = true, moves = 0};
    Controls.ThemeButton:SetText(Text("CANCEL"));
    Status("PLANNING");
end

local function Prepare()
    local snapshot = AT.Collect();
    local plan = AT.Plan(snapshot);
    if #plan.steps == 0 then
        local reason = plan.limited and "SEARCH_LIMIT" or (plan.skipped > 0 and "NO_ROUTE" or
            (#plan.targets > 0 and "RULE_MISMATCH" or "NO_COMBINATION"));
        Finish(reason); return;
    end
    run.planning = false;
    run.snapshot = snapshot;
    run.plan = plan;
    run.allowed = {};
    run.expected = {};
    run.counts = {};
    run.cursor = 1;
    for _, container in ipairs(snapshot.containers) do
        run.allowed[container.key] = container.allowed;
        run.counts[container.key] = container.count;
    end
    for key, slot in pairs(snapshot.slots) do run.expected[key] = slot.work; end
    Status("RUNNING", #plan.targets, #plan.steps);
end

local function ReadAll(expected)
    for key, value in pairs(expected) do
        if AT.ReadSlot(run.snapshot.slots[key]) ~= value then return false; end
    end
    return true;
end

local function Move(source, destination)
    local parameters = {};
    parameters[PlayerOperations.PARAM_PLAYER_ONE] = Game.GetLocalPlayer();
    parameters[PlayerOperations.PARAM_CITY_SRC] = source.city;
    parameters[PlayerOperations.PARAM_CITY_DEST] = destination.city;
    parameters[PlayerOperations.PARAM_GREAT_WORK_INDEX] = source.work;
    parameters[PlayerOperations.PARAM_BUILDING_SRC] = source.building;
    parameters[PlayerOperations.PARAM_BUILDING_DEST] = destination.building;
    parameters[PlayerOperations.PARAM_SLOT] = destination.slot;
    local after = {};
    for key, value in pairs(run.expected) do after[key] = value; end
    after[source.key] = destination.work;
    after[destination.key] = source.work;
    -- Wait for the actual slot contents before submitting another swap.
    run.pending = {after = after, deadline = clock + 8};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.MOVE_GREAT_WORK, parameters);
    print("[AutoTheme] Requested work " .. tostring(source.work) .. " -> " .. destination.key);
end

local function Step()
    if run == nil then return; end
    if not Active() then Finish("TURN_ENDED"); return; end
    if UI.IsGameCoreBusy() then return; end
    if run.planning then
        if run.cancel then Finish("CANCELLED", run.moves); else Prepare(); end
        return;
    end
    if run.pending then
        if ReadAll(run.pending.after) then
            run.expected = run.pending.after;
            run.pending = nil;
            run.moves = run.moves + 1;
            run.cursor = run.cursor + 1;
        elseif not ReadAll(run.expected) then Finish("CHANGED"); return;
        elseif clock >= run.pending.deadline then Finish("REJECTED"); return;
        else return; end
    end
    if run.cancel then Finish("CANCELLED", run.moves); return; end
    if not ReadAll(run.expected) then Finish("CHANGED"); return; end

    local current = AT.Collect();
    local byContainer = {};
    for _, container in ipairs(current.containers) do
        byContainer[container.key] = container;
        container.allowed = container.unlocked and run.allowed[container.key] == true;
        if run.counts[container.key] and container.count ~= run.counts[container.key] then Finish("CHANGED"); return; end
    end
    local nextStep = run.plan.steps[run.cursor];
    if nextStep == nil then
        for _, target in ipairs(run.plan.targets) do
            local container = byContainer[target.key];
            if not container or not container.themed then Finish("RULE_MISMATCH"); return; end
        end
        local gained = current.themed - run.snapshot.themed;
        local reason = run.plan.limited and "LIMITED" or (run.plan.skipped > 0 and "DONE_PARTIAL" or "DONE");
        Finish(reason, gained, run.moves, run.plan.skipped);
        return;
    end
    local source, destination = current.slots[nextStep.source], current.slots[nextStep.destination];
    if not source or not destination or source.work ~= nextStep.work or destination.work ~= nextStep.other then
        Finish("CHANGED"); return;
    end
    if not AT.CanSwap(source, destination, current) then Finish("REJECTED"); return; end
    Move(source, destination);
end

local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.2 then return; end
    elapsed = 0;
    local id = Game.GetLocalPlayer();
    Controls.ThemeButton:SetHide(id == nil or id < 0);
    local ok, errorMessage = pcall(Step);
    if not ok then
        print("[AutoTheme] Stopped: " .. tostring(errorMessage));
        Finish("ERROR");
    end
end

Controls.ThemeButton:RegisterCallback(Mouse.eLClick, Begin);
Controls.ThemeButton:SetToolTipString(Text("HELP"));
ContextPtr:SetUpdate(Update);
print("[AutoTheme] UI loaded");
