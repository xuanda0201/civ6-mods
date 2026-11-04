include("SpyRepeat_Common");

local function OnSet(playerID, parameters)
    local player = Players[playerID];
    if player == nil or not player:IsHuman() or type(parameters.UnitID) ~= "number" then return; end
    local key = tostring(parameters.UnitID);
    local stored = player:GetProperty(SpyRepeat.Property) or {};
    local registry = {};
    for id, entry in pairs(stored) do registry[id] = entry; end
    local old = registry[key];

    if parameters.Action == "remove" then
        registry[key] = nil;
    elseif parameters.Action == "pause" or parameters.Action == "off" or parameters.Action == "reserve" then
        if old == nil then return; end
        local entry = {};
        for k, value in pairs(old) do entry[k] = value; end
        if parameters.Action == "reserve" then
            if not old.Enabled then return; end
            entry.LastRequestTurn = Game.GetCurrentGameTurn();
        else
            entry.Enabled = false;
            entry.Reason = parameters.Action == "off" and "OFF" or parameters.Reason;
        end
        entry.Token = parameters.Token;
        registry[key] = entry;
    elseif parameters.Action == "enable" then
        local unit = player:GetUnits():FindID(parameters.UnitID);
        local operation = GameInfo.UnitOperations[parameters.Operation];
        local plot = Map.GetPlotByIndex(parameters.Plot or -1);
        local city = plot and Cities.GetPlotPurchaseCity(plot);
        if not SpyRepeat.IsSpy(unit) or not SpyRepeat.IsRepeatable(operation) or city == nil then return; end
        local currentPlot = Map.GetPlot(unit:GetX(), unit:GetY());
        local currentCity = currentPlot and Cities.GetPlotPurchaseCity(currentPlot);
        if currentCity == nil or currentCity:GetOwner() ~= city:GetOwner() or
            currentCity:GetID() ~= city:GetID() then return; end
        registry[key] = {
            Enabled = true, Reason = "RUNNING", Operation = operation.OperationType,
            Plot = plot:GetIndex(), CityOwner = city:GetOwner(), CityID = city:GetID(),
            Name = unit:GetName(), UnitType = unit:GetType(), Token = parameters.Token
        };
    else return; end
    player:SetProperty(SpyRepeat.Property, registry);
end

GameEvents.SpyRepeat_Set.Add(OnSet);

-- Persist hazardous outcomes in gameplay immediately, including outside the
-- local player's active turn. Reloading must not discard an escape pause.
local function OnMissionCompleted(playerID, missionID)
    local player = Players[playerID];
    if player == nil then return; end
    local stored = player:GetProperty(SpyRepeat.Property);
    if stored == nil then return; end
    local mission = player:GetDiplomacy():GetMission(playerID, missionID);
    if type(mission) ~= "table" then return; end
    local result = mission.InitialResult;
    local reason;
    if result == EspionageResultTypes.SUCCESS_MUST_ESCAPE or result == EspionageResultTypes.FAIL_MUST_ESCAPE then
        reason = "ESCAPE";
    elseif result == EspionageResultTypes.CAPTURED or result == EspionageResultTypes.KILLED or
        mission.EscapeResult == EspionageResultTypes.CAPTURED or mission.EscapeResult == EspionageResultTypes.KILLED then
        reason = "OFF_MAP";
    end
    if reason == nil then return; end
    local registry = {};
    for key, old in pairs(stored) do
        local entry = {};
        for k, value in pairs(old) do entry[k] = value; end
        if entry.Enabled and entry.Name == mission.Name then
            entry.Enabled = false;
            entry.Reason = reason;
        end
        registry[key] = entry;
    end
    player:SetProperty(SpyRepeat.Property, registry);
end

Events.SpyMissionCompleted.Add(OnMissionCompleted);
print("[SpyRepeat] Save-state handler loaded");
