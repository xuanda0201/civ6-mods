-- Native abilities give exact-radius, non-stacking escort immunity. We only manage
-- our own ability count; existing Zhanchi/Mandekalu/other-mod protection is untouched.
local SHIP='UNIT_XGYG_WUYA';
local ESCORT='ABILITY_XGYG_ESCORTED';
local POSITION='ABILITY_XGYG_POSITION';
local busy=false;
local function SetAbility(unit,name,wanted)
    local ability=unit:GetAbility();
    local count=ability:GetAbilityCount(name);
    local target=wanted and 1 or 0;
    if count~=target then ability:ChangeAbilityCount(name,target-count); end
end
local function IsType(unit,name)
    local definition=GameInfo.Units[unit:GetType()];
    return definition and definition.UnitType==name;
end
local function RefreshPlayer(id)
    local player=Players[id];
    if player==nil then return; end
    -- HD's Utils.LeaderHasTrait accepts this property as well as LeaderTraits.
    -- Preserve the conquest event while displaying only our merged ability.
    local config=PlayerConfigurations[id];
    if config and config:GetLeaderTypeName()=='LEADER_XGYG' and
       player:GetProperty('TRAIT_LEADER_KUBLAI_CAPTURED')~=true then
        player:SetProperty('TRAIT_LEADER_KUBLAI_CAPTURED',true);
    end
    local ships,traders={},{};
    for _,unit in player:GetUnits():Members() do
        if IsType(unit,SHIP) then ships[#ships+1]=unit;
        elseif IsType(unit,'UNIT_TRADER') or (GameInfo.Units[unit:GetType()] or {}).MakeTradeRoute then traders[#traders+1]=unit; end
    end
    local canal=GameInfo.Districts['DISTRICT_CANAL'];
    for _,ship in ipairs(ships) do
        local near=false;
        for dx=-2,2 do for dy=-2,2 do
            local plot=Map.GetPlotXYWithRangeCheck(ship:GetX(),ship:GetY(),dx,dy,2);
            if plot and plot:GetOwner()==id and canal and plot:GetDistrictType()==canal.Index then
                local district=CityManager.GetDistrictAt(plot:GetX(),plot:GetY());
                if district and district:IsComplete() then near=true; end
            end
        end end
        local plot=Map.GetPlot(ship:GetX(),ship:GetY());
        local coast=GameInfo.Terrains['TERRAIN_COAST'];
        local onCoast=plot and coast and plot:GetTerrainType()==coast.Index;
        SetAbility(ship,POSITION,near or onCoast);
    end
    for _,trader in ipairs(traders) do
        local protected=false;
        for _,ship in ipairs(ships) do
            if Map.GetPlotDistance(trader:GetX(),trader:GetY(),ship:GetX(),ship:GetY())<=4 then protected=true;break;end
        end
        SetAbility(trader,ESCORT,protected);
    end
end
local function Refresh(id)
    if busy then return; end
    busy=true;
    local ok,message=pcall(RefreshPlayer,id);
    busy=false;
    if not ok then print('[YangGuangRework] Ability refresh failed: '..tostring(message)); end
end
local function RefreshAll()
    for _,id in ipairs(PlayerManager.GetWasEverAliveIDs()) do Refresh(id); end
end
Events.UnitMoved.Add(Refresh);
Events.UnitAddedToMap.Add(Refresh);
Events.UnitRemovedFromMap.Add(Refresh);
Events.PlayerTurnActivated.Add(Refresh);
Events.DistrictBuildProgressChanged.Add(Refresh);
Events.LoadGameViewStateDone.Add(RefreshAll);
RefreshAll();
print('[YangGuangRework] Medieval fleet and escort bridge loaded');
