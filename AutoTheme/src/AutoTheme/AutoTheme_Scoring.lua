-- Placement heuristics use only understood, unconditional database effects.
-- Theme matching is separate and always checked against the engine afterward.
AutoThemeScoring = {};
local S = AutoThemeScoring;
local yields, arguments, buildingModifiers, workModifiers = {}, {}, {}, {};
local function Rows(tableName)
    local data = GameInfo[tableName];
    return data and data() or function() return nil; end;
end
for row in Rows("GreatWork_YieldChanges") do
    yields[row.GreatWorkType] = yields[row.GreatWorkType] or {};
    yields[row.GreatWorkType][row.YieldType] = row.YieldChange;
end
for row in Rows("ModifierArguments") do
    arguments[row.ModifierId] = arguments[row.ModifierId] or {};
    arguments[row.ModifierId][row.Name] = row.Value;
end
for row in Rows("BuildingModifiers") do
    buildingModifiers[row.BuildingType] = buildingModifiers[row.BuildingType] or {};
    table.insert(buildingModifiers[row.BuildingType], row.ModifierId);
end
for row in Rows("GreatWorkModifiers") do
    workModifiers[row.GreatWorkType] = workModifiers[row.GreatWorkType] or {};
    table.insert(workModifiers[row.GreatWorkType], row.ModifierId or row.ModifierID);
end

local function Definition(id)
    local modifier = GameInfo.Modifiers and GameInfo.Modifiers[id];
    if modifier and not modifier.SubjectRequirementSetId and not modifier.OwnerRequirementSetId then
        return modifier, arguments[id] or {};
    end
    return nil;
end

function S.City(city)
    local result = {tourism = {}, yields = {}, favored = {}};
    local buildings = city:GetBuildings();
    for definition in GameInfo.Buildings() do
        if buildings:HasBuilding(definition.Index) and not buildings:IsPillaged(definition.Index) then
            for _, id in ipairs(buildingModifiers[definition.BuildingType] or {}) do
                local modifier, args = Definition(id);
                if modifier and modifier.ModifierType == "MODIFIER_SINGLE_CITY_ADJUST_TOURISM" and args.GreatWorkObjectType then
                    local object = args.GreatWorkObjectType;
                    result.tourism[object] = (result.tourism[object] or 0) + (tonumber(args.ScalingFactor) or 0);
                elseif modifier and modifier.ModifierType == "MODIFIER_SINGLE_CITY_ADJUST_RELIGIOUS_TOURISM" then
                    for _, object in ipairs({"GREATWORKOBJECT_RELIC", "GREATWORKOBJECT_RELIGIOUS"}) do
                        result.tourism[object] = (result.tourism[object] or 0) + (tonumber(args.Amount) or 0);
                    end
                end
            end
        end
    end
    for row in Rows("Yields") do
        result.yields[row.YieldType] = city:GetYield(row.Index);
        result.favored[row.YieldType] = city:GetCitizens():IsFavoredYield(row.Index);
    end
    return result;
end

function S.Work(info)
    local result = {tourism = tonumber(info.Tourism) or 0, yields = yields[info.GreatWorkType] or {}, percent = {}};
    for _, id in ipairs(workModifiers[info.GreatWorkType] or {}) do
        local modifier, args = Definition(id);
        if modifier and modifier.ModifierType == "MODIFIER_SINGLE_CITY_ADJUST_CITY_YIELD_MODIFIER" and args.YieldType then
            result.percent[args.YieldType] = (result.percent[args.YieldType] or 0) + (tonumber(args.Amount) or 0);
        end
    end
    return result;
end

function S.Value(work)
    local score = work.value.tourism;
    for _, amount in pairs(work.value.yields) do score = score + math.max(0, amount); end
    return math.max(1, score);
end

function S.Placement(work, slot)
    if work == nil then return 0; end
    local city = slot.container.cityData;
    local value = work.value;
    local score = value.tourism * (city.tourism[work.object] or 0) / 100;
    for name, amount in pairs(value.yields) do
        if city.favored[name] then score = score + amount * 0.25; end
    end
    for name, amount in pairs(value.percent) do
        score = score + math.max(0, city.yields[name] or 0) * amount / 100;
    end
    -- Prefer dedicated storage over broad wildcard slots when benefits tie.
    return score + 0.1 / math.max(1, slot.flexibility);
end
