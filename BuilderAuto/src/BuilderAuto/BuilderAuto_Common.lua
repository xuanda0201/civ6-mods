BuilderAuto = {};
BuilderAuto.Property = "BuilderAuto_State_v1";
BuilderAuto.Radius = 6;
BuilderAuto.MaxTravelTurns = 3;

function BuilderAuto.IsBuilder(unit)
    if unit == nil then return false; end
    local definition = GameInfo.Units[unit:GetType()];
    if definition == nil then return false; end
    local name = definition.UnitType;
    local seen = {};
    while name and not seen[name] do
        if name == "UNIT_BUILDER" then return true; end
        seen[name] = true;
        local replacement = GameInfo.UnitReplaces[name];
        name = replacement and replacement.ReplacesUnitType;
    end
    return false;
end

function BuilderAuto.Signature(unit)
    return table.concat({Game.GetCurrentGameTurn(), unit:GetX(), unit:GetY(),
        unit:GetMovesRemaining(), unit:GetBuildCharges()}, ":");
end

function BuilderAuto.Parameters(plot, improvement)
    local parameters = {};
    parameters[UnitOperationTypes.PARAM_X] = plot:GetX();
    parameters[UnitOperationTypes.PARAM_Y] = plot:GetY();
    if improvement then parameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvement; end
    return parameters;
end
