include("BuilderAuto_Common");

local function OnSet(playerID, parameters)
    local player = Players[playerID];
    if player == nil or not player:IsHuman() then return; end
    local unit = player:GetUnits():FindID(parameters.UnitID);
    if not BuilderAuto.IsBuilder(unit) then return; end
    local old = unit:GetProperty(BuilderAuto.Property) or {};
    local state = {};
    for k, value in pairs(old) do state[k] = value; end
    if parameters.Action == "enable" then
        state.Enabled = true; state.Reason = "RUNNING";
    elseif parameters.Action == "off" then
        state.Enabled = false; state.Reason = parameters.Reason or "OFF";
    elseif parameters.Action == "reserve" then
        if not old.Enabled or parameters.Signature ~= BuilderAuto.Signature(unit) then return; end
        if old.LastSignature == parameters.Signature then return; end
        state.LastSignature = parameters.Signature;
    else return; end
    state.Token = parameters.Token;
    unit:SetProperty(BuilderAuto.Property, state);
end

-- Read-only geography query: ImprovementBuilder is not exposed to the UI.
-- Executing work still uses the normal UnitManager operation and its costs.
ExposedMembers.BuilderAuto_v1 = {
    CanPlace = function(playerID, plotID, improvementType)
        local plot = Map.GetPlotByIndex(plotID);
        local improvement = GameInfo.Improvements[improvementType];
        return plot ~= nil and plot:GetOwner() == playerID and improvement ~= nil and
            ImprovementBuilder.CanHaveImprovement(plot, improvement.Index, -1);
    end
};

GameEvents.BuilderAuto_Set.Add(OnSet);
print("[BuilderAuto] Save-state handler and read-only placement query loaded");
