local PROPERTY = "InfiniteProjects_Project_v1";
local OWNER = "InfiniteProjects_Owner_v1";
local pendingSettings = {};
local requestedTurn = {};
local statuses = {};
local elapsed = 0;
local dirty = true;
local clock = 0;

local function Text(key, ...)
    return Locale.Lookup("LOC_IP_" .. key, ...);
end

local function Key(city)
    return tostring(city:GetOwner()) .. ":" .. tostring(city:GetID());
end

local function LocalPlayer()
    local id = Game.GetLocalPlayer();
    if id == nil or id < 0 then return nil; end
    return Players[id];
end

local function SelectedCity()
    local city = UI.GetHeadSelectedCity();
    if city ~= nil and city:GetOwner() == Game.GetLocalPlayer() then return city; end
    return nil;
end

local function SavedProject(city)
    if city:GetProperty(OWNER) ~= city:GetOwner() then return nil; end
    local value = city:GetProperty(PROPERTY);
    if value == nil or value == "" then return nil; end
    return GameInfo.Projects[value];
end

local function CurrentProject(city)
    local hash = city:GetBuildQueue():GetCurrentProductionTypeHash();
    return hash ~= nil and GameInfo.Projects[hash] or nil;
end

local function Repeatable(project)
    return project ~= nil and not project.InternalOnly and
        (project.MaxPlayerInstances or -1) <= 0 and
        (project.MaxWorldInstances or -1) <= 0;
end

local function ActiveTurn()
    local player = LocalPlayer();
    return player ~= nil and player:IsTurnActive();
end

local function RefreshPanel()
    local city = SelectedCity();
    Controls.ProjectPanel:SetHide(city == nil);
    if city == nil then return; end

    local key = Key(city);
    local pending = pendingSettings[key];
    if pending ~= nil and city:GetProperty(PROPERTY) == pending.projectType and
        city:GetProperty(OWNER) == city:GetOwner() then
        pendingSettings[key] = nil;
        pending = nil;
        dirty = true;
    end
    Controls.CityLabel:SetText(Locale.Lookup(city:GetName()));
    local project = SavedProject(city);
    local current = CurrentProject(city);
    Controls.ToggleButton:SetDisabled(pending ~= nil or not ActiveTurn() or
        (project == nil and not Repeatable(current)));
    Controls.ToggleButton:SetText(Text(project and "DISABLE" or "ENABLE"));
    Controls.ToggleButton:SetToolTipString(Text("HELP"));

    local status;
    if pending then status = Text("SAVING");
    elseif project then
        status = Text(statuses[key] or "ENABLED", Locale.Lookup(project.Name));
    elseif statuses[key] == "SAVE_FAILED" then status = Text("SAVE_FAILED");
    elseif current ~= nil and not Repeatable(current) then status = Text("ONE_OFF");
    else status = Text("SELECT_PROJECT"); end
    Controls.StatusLabel:SetText(status);
end

local function Toggle()
    local city = SelectedCity();
    if city == nil or not ActiveTurn() or pendingSettings[Key(city)] then return; end
    local projectType = "";
    if SavedProject(city) == nil then
        local project = CurrentProject(city);
        if not Repeatable(project) then return; end
        projectType = project.ProjectType;
    end
    statuses[Key(city)] = nil;
    pendingSettings[Key(city)] = {projectType = projectType, deadline = clock + 8};
    UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, {
        OnStart = "InfiniteProjects_SetProject",
        CityID = city:GetID(),
        ProjectType = projectType
    });
    dirty = true;
    RefreshPanel();
end

local function Refill(city)
    local key = Key(city);
    local pending = pendingSettings[key];
    if pending ~= nil then
        if city:GetProperty(PROPERTY) == pending.projectType and
           city:GetProperty(OWNER) == city:GetOwner() then
            pendingSettings[key] = nil;
        elseif clock >= pending.deadline then
            pendingSettings[key] = nil;
            statuses[key] = "SAVE_FAILED";
            return;
        else
            dirty = true;
            return;
        end
    end
    local project = SavedProject(city);
    if project == nil then return; end
    local queue = city:GetBuildQueue();
    local current = queue:GetCurrentProductionTypeHash();
    -- Wait for the ENTIRE manual queue to finish. Never replace the head.
    if current ~= nil and current ~= 0 and current ~= -1 then
        statuses[key] = current == project.Hash and "ENABLED" or "MANUAL_FIRST";
        return;
    end
    if not Repeatable(project) or not queue:CanProduce(project.Hash, false) then
        statuses[key] = "UNAVAILABLE";
        return;
    end
    local turn = Game.GetCurrentGameTurn();
    if requestedTurn[key] == turn then return; end
    local parameters = {};
    parameters[CityOperationTypes.PARAM_PROJECT_TYPE] = project.Hash;
    parameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_APPEND;
    if not CityManager.CanStartOperation(city, CityOperationTypes.BUILD, parameters, false) then
        statuses[key] = "UNAVAILABLE";
        return;
    end
    -- Reserve before submitting: completion/production events can fire repeatedly.
    requestedTurn[key] = turn;
    statuses[key] = "REQUESTED";
    CityManager.RequestOperation(city, CityOperationTypes.BUILD, parameters);
    print("[InfiniteProjects] Requested " .. project.ProjectType .. " for " .. key);
end

local function MarkDirty(owner)
    if owner == nil or owner == Game.GetLocalPlayer() then dirty = true; end
end

local function Update(delta)
    clock = clock + delta;
    elapsed = elapsed + delta;
    if elapsed < 0.25 then return; end
    elapsed = 0;
    -- Process on the next UI update, after completion has advanced the queue.
    RefreshPanel();
    if not dirty or not ActiveTurn() then return; end
    dirty = false;
    local player = LocalPlayer();
    for _, city in player:GetCities():Members() do Refill(city); end
    RefreshPanel();
end

Controls.ToggleButton:RegisterCallback(Mouse.eLClick, Toggle);
Events.CitySelectionChanged.Add(MarkDirty);
Events.CityProductionCompleted.Add(MarkDirty);
Events.CityProductionChanged.Add(MarkDirty);
Events.CityProductionUpdated.Add(MarkDirty);
Events.PlayerTurnActivated.Add(MarkDirty);
Events.LoadScreenClose.Add(function() dirty = true; end);
ContextPtr:SetUpdate(Update);
print("[InfiniteProjects] UI loaded");
