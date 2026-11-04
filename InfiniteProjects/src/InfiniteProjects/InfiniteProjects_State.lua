-- Settings belong to the save, not a machine-wide preferences database.
-- The UI requests a normal player script operation; only gameplay writes state.
local PROPERTY = "InfiniteProjects_Project_v1";
local OWNER = "InfiniteProjects_Owner_v1";

local function OnSetProject(playerID, parameters)
    local player = Players[playerID];
    if player == nil or not player:IsHuman() then return; end
    local city = player:GetCities():FindID(parameters.CityID);
    if city == nil or city:GetOwner() ~= playerID then return; end

    local projectType = parameters.ProjectType;
    if projectType ~= "" then
        local project = GameInfo.Projects[projectType];
        if project == nil or project.InternalOnly then return; end
        -- One-off projects should never be advertised as infinite loops.
        if (project.MaxPlayerInstances or -1) > 0 or
           (project.MaxWorldInstances or -1) > 0 then return; end
        if city:GetBuildQueue():GetCurrentProductionTypeHash() ~= project.Hash then return; end
    end

    city:SetProperty(PROPERTY, projectType);
    city:SetProperty(OWNER, playerID);
end

-- A conquered city must not retain its former owner's automation on recapture.
local function OnCityAdded(playerID, cityID)
    local player = Players[playerID];
    local city = player and player:GetCities():FindID(cityID);
    if city ~= nil and city:GetProperty(OWNER) ~= playerID then
        city:SetProperty(PROPERTY, "");
        city:SetProperty(OWNER, playerID);
    end
end

GameEvents.InfiniteProjects_SetProject.Add(OnSetProject);
Events.CityAddedToMap.Add(OnCityAdded);
print("[InfiniteProjects] Save-state handler loaded");
