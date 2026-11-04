-- CityBuilt is a founding event, not a capture or save-load event.
local CLAIM = 'XGYG_FOUNDING_BUILDER_GRANTED_V1';
local function OnCityBuilt(id,cityID)
    local config = PlayerConfigurations[id];
    if not config or config:GetLeaderTypeName() ~= 'LEADER_XGYG' then return; end
    local city = CityManager.GetCity(id,cityID);
    if not city or city:GetOwner() ~= id or city:GetOriginalOwner() ~= id then return; end
    if city:GetProperty(CLAIM) == true then return; end
    -- One city property also prevents duplicate event delivery or re-entry.
    city:SetProperty(CLAIM,true);
    local ok,message = pcall(function() city:AttachModifierByID('XGYG_FOUNDING_BUILDER'); end);
    if not ok then print('[YangGuangRework] Founding Builder grant failed: '..tostring(message)); end
end
GameEvents.CityBuilt.Add(OnCityBuilt);
print('[YangGuangRework] New-city Builder reward loaded');
