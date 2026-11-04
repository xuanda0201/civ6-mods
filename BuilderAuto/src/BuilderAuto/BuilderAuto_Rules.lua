local BA = BuilderAuto;
local regular = {IMPROVEMENT_FARM = true, IMPROVEMENT_MINE = true, IMPROVEMENT_LUMBER_MILL = true};
local resourceImprovements = {};
local features = {};
local yields = {};
local hd;
local hdAttempted = false;

for row in GameInfo.Improvement_ValidResources() do
    resourceImprovements[row.ResourceType] = resourceImprovements[row.ResourceType] or {};
    resourceImprovements[row.ResourceType][row.ImprovementType] = true;
end
for row in GameInfo.Improvement_ValidFeatures() do
    features[row.ImprovementType] = features[row.ImprovementType] or {};
    features[row.ImprovementType][row.FeatureType] = true;
end
for row in GameInfo.Improvement_YieldChanges() do
    yields[row.ImprovementType] = yields[row.ImprovementType] or {};
    yields[row.ImprovementType][row.YieldType] = row.YieldChange;
end

function BA.Prepare()
    if not ExposedMembers.BuilderAuto_v1 or not ExposedMembers.BuilderAuto_v1.CanPlace then return false, "BRIDGE"; end
    if GameInfo.ImprovementsRules_HD ~= nil and not hdAttempted then
        hdAttempted = true;
        local ok, errorMessage = pcall(function()
            -- Use the installed HD helpers, including its UI-only placement rules.
            include("HD_Improvements");
            include("FarmsOnFreshHills_Common");
            assert(type(CanBuildExtraImprovement) == "function");
            assert(type(CanBuildOnResourceWithSpecificTerrainOrFeature) == "function");
            assert(type(ShouldDisableHillFarm) == "function");
            hd = {count = CanBuildExtraImprovement,
                resource = CanBuildOnResourceWithSpecificTerrainOrFeature, hill = ShouldDisableHillFarm};
        end);
        if not ok then
            hd = nil;
            print("[BuilderAuto] HD adapter unavailable: " .. tostring(errorMessage));
        end
    end
    if hdAttempted and hd == nil then return false, "HD_RULES"; end
    return true;
end

function BA.Area(origin, radius)
    local visited = {[origin:GetIndex()] = true};
    local result = {origin};
    local frontier = {origin};
    for _ = 1, radius do
        local nextFrontier = {};
        for _, plot in ipairs(frontier) do
            for direction = 0, 5 do
                local adjacent = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
                if adjacent and not visited[adjacent:GetIndex()] then
                    visited[adjacent:GetIndex()] = true;
                    result[#result + 1] = adjacent;
                    nextFrontier[#nextFrontier + 1] = adjacent;
                end
            end
        end
        frontier = nextFrontier;
    end
    return result;
end

function BA.IsVisible(plot)
    local visibility = PlayersVisibility[Game.GetLocalPlayer()];
    return visibility ~= nil and visibility:IsVisible(plot:GetX(), plot:GetY());
end

function BA.Danger(plot, cache)
    local key = plot:GetIndex();
    if cache[key] ~= nil then return cache[key]; end
    local owner = Game.GetLocalPlayer();
    local diplomacy = Players[owner]:GetDiplomacy();
    local visibility = PlayersVisibility[owner];
    for _, nearby in ipairs(BA.Area(plot, 2)) do
        if BA.IsVisible(nearby) then
            local city = Cities.GetPlotPurchaseCity(nearby);
            if city and city:GetX() == nearby:GetX() and city:GetY() == nearby:GetY() and
                diplomacy:IsAtWarWith(city:GetOwner()) then cache[key] = true; return true; end
            local units = Units.GetUnitsInPlotLayerID(nearby:GetX(), nearby:GetY(), MapLayers.ANY) or {};
            for _, unit in ipairs(units) do
                if unit:GetOwner() ~= owner and diplomacy:IsAtWarWith(unit:GetOwner()) and
                    visibility:IsUnitVisible(unit) then cache[key] = true; return true; end
            end
        end
    end
    cache[key] = false;
    return false;
end

local function Occupied(plot, builder)
    local units = Units.GetUnitsInPlotLayerID(plot:GetX(), plot:GetY(), MapLayers.ANY) or {};
    for _, unit in ipairs(units) do
        if unit:GetOwner() ~= builder:GetOwner() or unit:GetID() ~= builder:GetID() then
            local info = GameInfo.Units[unit:GetType()];
            if info and info.FormationClass == "FORMATION_CLASS_CIVILIAN" then return true; end
        end
    end
    return false;
end

local function Resource(plot, player)
    local index = plot:GetResourceType();
    local resource = index ~= -1 and GameInfo.Resources[index] or nil;
    if resource and player:GetResources():IsResourceVisible(resource.Hash) then return resource; end
    return nil;
end

local function YieldScore(improvement, city)
    local score = 0;
    for name, amount in pairs(yields[improvement.ImprovementType] or {}) do
        local row = GameInfo.Yields[name];
        local weight = (name == "YIELD_FOOD" or name == "YIELD_PRODUCTION") and 2 or 1;
        if row and city:GetCitizens():IsFavoredYield(row.Index) then weight = weight * 3; end
        score = score + amount * weight;
    end
    return score;
end

local function Allowed(improvement, plot, city, player)
    -- Special/unique improvements remain manual in v1. Resource mappings are dynamic.
    if not improvement.Buildable or improvement.TraitType ~= nil or improvement.RemoveOnEntry then return false; end
    if improvement.PrereqTech then
        local technology = GameInfo.Technologies[improvement.PrereqTech];
        if technology == nil or not player:GetTechs():HasTech(technology.Index) then return false; end
    end
    if improvement.PrereqCivic then
        local civic = GameInfo.Civics[improvement.PrereqCivic];
        if civic == nil or not player:GetCulture():HasCivic(civic.Index) then return false; end
    end
    local featureIndex = plot:GetFeatureType();
    if featureIndex ~= -1 then
        local feature = GameInfo.Features[featureIndex];
        -- Explicit retention compatibility only: never clear a feature to make room.
        if feature == nil or not (features[improvement.ImprovementType] or {})[feature.FeatureType] then return false; end
    end
    if hd then
        local ok, allowed = pcall(function()
            return hd.resource(improvement.ImprovementType, plot) and hd.count(improvement.ImprovementType, city) and
                (improvement.ImprovementType ~= "IMPROVEMENT_FARM" or not hd.hill(plot, player));
        end);
        if not ok then error("HD placement helper failed: " .. tostring(allowed)); end
        if not allowed then return false; end
    end
    return ExposedMembers.BuilderAuto_v1.CanPlace(player:GetID(), plot:GetIndex(), improvement.ImprovementType);
end

function BA.Job(plot, builder)
    local player = Players[builder:GetOwner()];
    if plot:GetOwner() ~= builder:GetOwner() or not BA.IsVisible(plot) or plot:GetDistrictType() ~= -1 or
        plot:GetWonderType() ~= -1 then return nil; end
    local city = Cities.GetPlotPurchaseCity(plot);
    if city == nil then return nil; end
    if plot:GetImprovementType() ~= -1 then
        if plot:IsImprovementPillaged() then
            return {plot = plot:GetIndex(), operation = UnitOperationTypes.REPAIR, priority = 3, score = 0, kind = "REPAIR"};
        end
        if plot:IsRoutePillaged() then
            return {plot = plot:GetIndex(), operation = UnitOperationTypes.REPAIR_ROUTE, priority = 3, score = 0, kind = "REPAIR"};
        end
        return nil;
    end
    if plot:IsRoutePillaged() then
        return {plot = plot:GetIndex(), operation = UnitOperationTypes.REPAIR_ROUTE, priority = 3, score = 0, kind = "REPAIR"};
    end
    local resource = Resource(plot, player);
    if resource == nil and plot:GetWorkerCount() <= 0 then return nil; end
    local choices = resource and (resourceImprovements[resource.ResourceType] or {}) or regular;
    local best;
    for name in pairs(choices) do
        local improvement = GameInfo.Improvements[name];
        if improvement and Allowed(improvement, plot, city, player) then
            local score = YieldScore(improvement, city);
            if resource then
                score = score + (resource.ResourceClassType == "RESOURCECLASS_LUXURY" and 30 or
                    (resource.ResourceClassType == "RESOURCECLASS_STRATEGIC" and 20 or 10));
            end
            if best == nil or score > best.score or (score == best.score and improvement.Index < best.improvement) then
                best = {plot = plot:GetIndex(), operation = UnitOperationTypes.BUILD_IMPROVEMENT,
                    improvement = improvement.Index, priority = resource and 2 or 1, score = score,
                    kind = resource and "RESOURCE" or "WORKED"};
            end
        end
    end
    return best;
end

function BA.Path(builder, target, danger)
    if target:GetX() == builder:GetX() and target:GetY() == builder:GetY() then return {}, 0; end
    local path, turns = UnitManager.GetMoveToPath(builder, target:GetIndex());
    if path == nil or #path == 0 or path[#path] ~= target:GetIndex() then return nil; end
    if turns == nil or (turns[#turns] or 99) > BA.MaxTravelTurns then return nil; end
    for _, id in ipairs(path) do
        local plot = Map.GetPlotByIndex(id);
        if plot == nil or plot:GetOwner() ~= builder:GetOwner() or not BA.IsVisible(plot) or
            BA.Danger(plot, danger) or Occupied(plot, builder) then return nil; end
    end
    return path, turns[#turns] or 0;
end

function BA.Plan(builder, reservations, danger)
    local origin = Map.GetPlot(builder:GetX(), builder:GetY());
    local candidates = {};
    for _, plot in ipairs(BA.Area(origin, BA.Radius)) do
        local reserved = reservations[plot:GetIndex()];
        if (reserved == nil or reserved == builder:GetID()) and not Occupied(plot, builder) then
            local job = BA.Job(plot, builder);
            if job and not BA.Danger(plot, danger) then
                job.score = job.score - Map.GetPlotDistance(origin:GetIndex(), plot:GetIndex()) * 2;
                candidates[#candidates + 1] = job;
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority; end
        if a.score ~= b.score then return a.score > b.score; end
        return a.plot < b.plot;
    end);
    for _, job in ipairs(candidates) do
        local target = Map.GetPlotByIndex(job.plot);
        if BA.Path(builder, target, danger) then return job; end
    end
    return nil;
end
