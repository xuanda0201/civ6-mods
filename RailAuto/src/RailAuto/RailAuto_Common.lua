RailAuto = {};
local RA = RailAuto;
RA.Property = "RailAuto_State_v1";

function RA.Rules()
    local route = GameInfo.Routes and GameInfo.Routes["ROUTE_RAILROAD"];
    if route == nil or GameInfo.Routes_XP2 == nil or GameInfo.Route_ResourceCosts == nil or
        GameInfo.Route_ValidBuildUnits == nil then return nil; end
    local expansion;
    for row in GameInfo.Routes_XP2() do
        if row.RouteType == route.RouteType then expansion = row; break; end
    end
    if expansion == nil or expansion.BuildWithUnitChargeCost == nil then return nil; end
    return route, expansion;
end

function RA.Eligible(unit)
    if unit == nil or RA.Rules() == nil then return false; end
    local definition = GameInfo.Units[unit:GetType()];
    local name = definition and definition.UnitType;
    local seen = {};
    while name and not seen[name] do
        seen[name] = true;
        for row in GameInfo.Route_ValidBuildUnits() do
            if row.RouteType == "ROUTE_RAILROAD" and row.UnitType == name then return true; end
        end
        local replacement = GameInfo.UnitReplaces[name];
        name = replacement and replacement.ReplacesUnitType;
    end
    return false;
end
