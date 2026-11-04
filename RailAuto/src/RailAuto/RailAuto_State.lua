include("RailAuto_Common");
local RA = RailAuto;
local working = {};

local function Save(unit, reason, enabled, token)
    local old = unit:GetProperty(RA.Property) or {};
    local state = {};
    for key, value in pairs(old) do state[key] = value; end
    state.Reason = reason;
    if enabled ~= nil then state.Enabled = enabled; end
    if token ~= nil then state.Token = token; end
    unit:SetProperty(RA.Property, state);
end

local function Lay(unit)
    local player = Players[unit:GetOwner()];
    local state = unit:GetProperty(RA.Property) or {};
    if not player or not player:IsHuman() or not state.Enabled then return; end
    if not RA.Eligible(unit) then Save(unit, "RULES", false); return; end
    local route, expansion = RA.Rules();
    if tonumber(expansion.BuildWithUnitChargeCost) ~= 0 then Save(unit, "CHARGES", false); return; end
    if expansion.PrereqTech then
        local tech = GameInfo.Technologies[expansion.PrereqTech];
        if not tech then Save(unit, "RULES", false); return; end
        if not player:GetTechs():HasTech(tech.Index) then Save(unit, "TECH"); return; end
    end
    local plot = Map.GetPlot(unit:GetX(), unit:GetY());
    if plot == nil then return; end
    -- No custom movement, embarkation or territory privileges are granted.
    if plot:IsWater() or plot:IsMountain() or plot:IsImpassable() or plot:IsNaturalWonder() or
        plot:IsCity() or plot:GetWonderType() ~= -1 then Save(unit, "SKIP"); return; end
    if plot:GetOwner() ~= -1 and plot:GetOwner() ~= unit:GetOwner() then Save(unit, "FOREIGN"); return; end
    -- Do not repair pillaged railways or charge again for existing railways.
    if plot:GetRouteType() == route.Index then Save(unit, "EXISTING"); return; end
    local costs = {};
    for row in GameInfo.Route_ResourceCosts() do
        if row.RouteType == route.RouteType then
            local resource = GameInfo.Resources[row.ResourceType];
            local amount = tonumber(row.BuildWithUnitCost);
            if resource == nil or amount == nil or amount < 0 then Save(unit, "RULES", false); return; end
            costs[resource.Index] = (costs[resource.Index] or 0) + amount;
        end
    end
    local resources = player:GetResources();
    for index, amount in pairs(costs) do
        if resources:GetResourceAmount(index) < amount then Save(unit, "RESOURCES", false); return; end
    end
    -- The movement event runs in Gameplay; no delayed UI callback can paint a
    -- previously visited tile after the unit has left or the switch was disabled.
    local charged = {};
    local ok, errorMessage = pcall(function()
        for index, amount in pairs(costs) do
            resources:ChangeResourceAmount(index, -amount);
            charged[index] = amount;
        end
        RouteBuilder.SetRouteType(plot, route.Index);
    end);
    if plot:GetRouteType() ~= route.Index then
        for index, amount in pairs(charged) do resources:ChangeResourceAmount(index, amount); end
        Save(unit, "API_ERROR", false);
        print("[RailAuto] Placement failed: " .. tostring(errorMessage));
        return;
    end
    -- A setter which changed the map and then raised must not result in free rail.
    Save(unit, ok and "LAID" or "API_ERROR", ok and true or false);
end

local function Process(unit)
    if unit == nil then return; end
    local key = tostring(unit:GetOwner()) .. ":" .. tostring(unit:GetID());
    if working[key] then return; end
    working[key] = true;
    local ok, errorMessage = pcall(Lay, unit);
    working[key] = nil;
    if not ok then
        Save(unit, "API_ERROR", false);
        print("[RailAuto] Paused: " .. tostring(errorMessage));
    end
end

local function OnMoved(owner, id, x, y)
    local player = Players[owner];
    local unit = player and player:GetUnits():FindID(id);
    if not unit then return; end
    -- Ignore a stale movement event, never backfill arbitrary event coordinates.
    if x ~= nil and y ~= nil and (unit:GetX() ~= x or unit:GetY() ~= y) then return; end
    Process(unit);
end

local function OnSet(owner, parameters)
    local player = Players[owner];
    if not player or not player:IsHuman() then return; end
    local unit = player:GetUnits():FindID(parameters.UnitID);
    if not RA.Eligible(unit) then return; end
    if parameters.Action == "enable" then
        Save(unit, "ON", true, parameters.Token);
        Process(unit);
    elseif parameters.Action == "off" then Save(unit, "OFF", false, parameters.Token); end
end

local function OnTurn(owner)
    local player = Players[owner];
    if player and player:IsHuman() then
        for _, unit in player:GetUnits():Members() do Process(unit); end
    end
end

GameEvents.RailAuto_Set.Add(OnSet);
Events.UnitMoved.Add(OnMoved);
Events.PlayerTurnActivated.Add(OnTurn);
print("[RailAuto] Gameplay loaded (0.1.0)");
