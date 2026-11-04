include("RailAuto_Common");
local RA = RailAuto;
local parent, pending;
local clock, elapsed, serial = 0, 0, 0;
local saveFailed = false;
local function Text(key) return Locale.Lookup("LOC_RA_" .. key); end
local function Selected()
    local unit = UI.GetHeadSelectedUnit();
    if unit and unit:GetOwner() == Game.GetLocalPlayer() and RA.Eligible(unit) then return unit; end
end
local function Refresh()
    local anchor = ContextPtr:LookUpControl("/InGame/UnitPanel/ActionsStack");
    if anchor and parent ~= anchor then
        Controls.RailAction:ChangeParent(anchor); parent = anchor;
        print("[RailAuto] Button attached to unit panel");
    end
    local unit = Selected();
    Controls.RailAction:SetHide(anchor == nil or unit == nil);
    if not unit then return; end
    local id = unit:GetID();
    local state = unit:GetProperty(RA.Property) or {};
    local saving = pending and pending.id == id;
    local label = state.Enabled and "BUTTON_ON" or "BUTTON_OFF";
    if saving then label = "SAVING";
    elseif not state.Enabled and state.Reason and state.Reason ~= "OFF" then label = "BUTTON_PAUSED"; end
    Controls.RailButton:SetText(Text(label));
    Controls.RailButton:SetToolTipString(Text(saveFailed and "SAVE_FAILED" or state.Reason or "OFF") ..
        "[NEWLINE][NEWLINE]" .. Text("HELP"));
    local player = Players[Game.GetLocalPlayer()];
    Controls.RailButton:SetDisabled(pending ~= nil or not player or not player:IsTurnActive());
    if parent then
        parent:CalculateSize(); parent:ReprocessAnchoring();
        local panel = ContextPtr:LookUpControl("/InGame/UnitPanel/UnitPanelBaseContainer");
        if panel and parent:GetSizeX() > panel:GetSizeX() then panel:SetSizeX(parent:GetSizeX() + 20); end
    end
end
local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.25 then return; end
    elapsed = 0;
    if pending then
        local player = Players[Game.GetLocalPlayer()];
        local unit = player and player:GetUnits():FindID(pending.id);
        if not unit or (unit:GetProperty(RA.Property) or {}).Token == pending.token then pending = nil;
        elseif clock > pending.deadline then pending = nil; saveFailed = true; end
    end
    Refresh();
end
Controls.RailButton:RegisterCallback(Mouse.eLClick, function()
    local unit = Selected();
    local player = Players[Game.GetLocalPlayer()];
    if not unit or pending or not player or not player:IsTurnActive() then return; end
    serial = serial + 1; saveFailed = false;
    local token = tostring(Game.GetCurrentGameTurn()) .. ":" .. tostring(clock) .. ":" .. tostring(serial);
    pending = {id = unit:GetID(), token = token, deadline = clock + 8};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT,
        {OnStart = "RailAuto_Set", UnitID = unit:GetID(),
        Action = (unit:GetProperty(RA.Property) or {}).Enabled and "off" or "enable", Token = token});
    Refresh();
end);
Events.UnitSelectionChanged.Add(Refresh);
ContextPtr:SetUpdate(Update);
Refresh();
print("[RailAuto] UI loaded (0.1.0)");
