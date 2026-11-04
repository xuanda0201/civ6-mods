include("RailAuto_Common");
local RA = RailAuto;
local parent, actionStack, pending;
local clock, elapsed, serial = 0, 0, 0;
local saveFailedId;
local function Text(key) return Locale.Lookup("LOC_RA_" .. key); end
local function Selected()
    local unit = UI.GetHeadSelectedUnit();
    if unit and unit:GetOwner() == Game.GetLocalPlayer() and RA.Eligible(unit) then return unit; end
end
local function LayoutActions()
    if not parent or not actionStack then return; end
    parent:CalculateSize(); parent:ReprocessAnchoring();
    if actionStack ~= parent then
        actionStack:CalculateSize(); actionStack:ReprocessAnchoring();
    end
    local panel = ContextPtr:LookUpControl("/InGame/UnitPanel/UnitPanelBaseContainer");
    if panel and actionStack:GetSizeX() > panel:GetSizeX() then panel:SetSizeX(actionStack:GetSizeX() + 20); end
end
local function Refresh()
    local root = ContextPtr:LookUpControl("/InGame/UnitPanel/ActionsStack");
    local anchor = ContextPtr:LookUpControl("/InGame/UnitPanel/StandardActionsStack") or root;
    if anchor and parent ~= anchor then
        Controls.RailAction:ChangeParent(anchor); parent = anchor;
        print("[RailAuto] Button attached to unit panel");
    end
    actionStack = root or anchor;
    local unit = Selected();
    Controls.RailAction:SetHide(anchor == nil or unit == nil);
    if not unit then LayoutActions(); return; end
    local id = unit:GetID();
    local state = unit:GetProperty(RA.Property) or {};
    local enabled = state.Enabled == true;
    local failed = saveFailedId == id;
    local saving = pending and pending.id == id;
    local label = enabled and "BUTTON_ON" or "BUTTON_OFF";
    if saving then label = "SAVING";
    elseif not enabled and (failed or (state.Reason and state.Reason ~= "OFF")) then label = "BUTTON_PAUSED"; end
    local operation = GameInfo.UnitOperations[UnitOperationTypes.BUILD_ROUTE];
    local icon = operation and operation.Icon;
    if icon == nil or icon == "" then icon = "ICON_UNITOPERATION_BUILD_ROUTE"; end
    Controls.RailIcon:SetIcon(icon);
    Controls.RailButton:SetSelected(enabled);
    Controls.RailButton:SetToolTipString(Text(label) .. "[NEWLINE]" ..
        Text(failed and "SAVE_FAILED" or state.Reason or "OFF") ..
        "[NEWLINE][NEWLINE]" .. Text(enabled and "DISABLE" or "ENABLE") ..
        "[NEWLINE]" .. Text("HELP"));
    local player = Players[Game.GetLocalPlayer()];
    local disabled = pending ~= nil or player == nil or not player:IsTurnActive();
    Controls.RailButton:SetDisabled(disabled);
    Controls.RailButton:SetAlpha(disabled and 0.7 or 1);
    LayoutActions();
end
local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.25 then return; end
    elapsed = 0;
    if pending then
        local player = Players[Game.GetLocalPlayer()];
        local unit = player and player:GetUnits():FindID(pending.id);
        if not unit or (unit:GetProperty(RA.Property) or {}).Token == pending.token then pending = nil;
        elseif clock > pending.deadline then saveFailedId = pending.id; pending = nil; end
    end
    Refresh();
end
Controls.RailButton:RegisterCallback(Mouse.eLClick, function()
    local unit = Selected();
    local player = Players[Game.GetLocalPlayer()];
    if not unit or pending or not player or not player:IsTurnActive() then return; end
    serial = serial + 1;
    if saveFailedId == unit:GetID() then saveFailedId = nil; end
    local token = tostring(Game.GetCurrentGameTurn()) .. ":" .. tostring(clock) .. ":" .. tostring(serial);
    pending = {id = unit:GetID(), token = token, deadline = clock + 8};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT,
        {OnStart = "RailAuto_Set", UnitID = unit:GetID(),
        Action = (unit:GetProperty(RA.Property) or {}).Enabled and "off" or "enable", Token = token});
    Refresh();
end);
Controls.RailButton:RegisterCallback(Mouse.eMouseEnter, function()
    UI.PlaySound("Main_Menu_Mouse_Over");
end);
Events.UnitSelectionChanged.Add(Refresh);
ContextPtr:SetUpdate(Update);
Refresh();
print("[RailAuto] UI loaded (0.1.1)");
