include("AutoTheme_Scoring");
AutoTheme = {};
local AT, Scoring = AutoTheme, AutoThemeScoring;
local artObjects = {GREATWORKOBJECT_SCULPTURE = true, GREATWORKOBJECT_LANDSCAPE = true,
    GREATWORKOBJECT_PORTRAIT = true, GREATWORKOBJECT_RELIGIOUS = true};
local validSlots, flexibility = {}, {};
for row in GameInfo.GreatWork_ValidSubTypes() do
    validSlots[row.GreatWorkSlotType] = validSlots[row.GreatWorkSlotType] or {};
    if not validSlots[row.GreatWorkSlotType][row.GreatWorkObjectType] then
        flexibility[row.GreatWorkSlotType] = (flexibility[row.GreatWorkSlotType] or 0) + 1;
    end
    validSlots[row.GreatWorkSlotType][row.GreatWorkObjectType] = true;
end

local function Flag(value) return value == true or value == 1; end
local function HasTheme(rules)
    return rules and (Flag(rules.ThemingUniquePerson) or Flag(rules.ThemingSameObjectType) or
        Flag(rules.ThemingUniqueCivs) or Flag(rules.ThemingSameEras) or
        (tonumber(rules.ThemingYieldMultiplier) or 0) > 0 or (tonumber(rules.ThemingTourismMultiplier) or 0) > 0);
end
local function Fits(work, slot)
    return work ~= nil and (validSlots[slot.slotType] or {})[work.object] == true;
end

function AT.SlotKey(city, building, slot) return table.concat({city, building, slot}, ":"); end
function AT.ReadSlot(slot)
    local player = Players[Game.GetLocalPlayer()];
    local city = player and player:GetCities():FindID(slot.city);
    if not city or city:GetOwner() ~= Game.GetLocalPlayer() then return nil; end
    local buildings = city:GetBuildings();
    if not buildings:HasBuilding(slot.building) or buildings:GetNumGreatWorkSlots(slot.building) <= slot.slot then return nil; end
    return buildings:GetGreatWorkInSlot(slot.building, slot.slot);
end

function AT.Collect()
    local snapshot = {containers = {}, slots = {}, works = {}, themed = 0, locked = 0, objects = {}};
    local player = Players[Game.GetLocalPlayer()];
    if not player then return snapshot; end
    local metadata = {};
    for row in GameInfo.Building_GreatWorks() do
        metadata[row.BuildingType] = metadata[row.BuildingType] or {};
        metadata[row.BuildingType][row.GreatWorkSlotType] = row;
    end
    for _, city in player:GetCities():Members() do
        local buildings = city:GetBuildings();
        local cityData = Scoring.City(city);
        for definition in GameInfo.Buildings() do
            if buildings:HasBuilding(definition.Index) then
                local count = buildings:GetNumGreatWorkSlots(definition.Index);
                if count and count > 0 then
                    local container = {key = city:GetID() .. ":" .. definition.Index, city = city:GetID(),
                        building = definition.Index, count = count, slots = {}, groups = {}, cityData = cityData,
                        full = true, themeable = false, unlocked = not buildings:IsPillaged(definition.Index)};
                    for index = 0, count - 1 do
                        local slotDefinition = GameInfo.GreatWorkSlotTypes[buildings:GetGreatWorkSlotType(definition.Index, index)];
                        local slotType = slotDefinition and slotDefinition.GreatWorkSlotType;
                        local rules = slotType and (metadata[definition.BuildingType] or {})[slotType];
                        local group = slotType or ("unknown:" .. index);
                        container.groups[group] = container.groups[group] or {slots = {}, rules = rules};
                        if HasTheme(rules) then container.themeable = true; end
                        local id = buildings:GetGreatWorkInSlot(definition.Index, index);
                        local slot = {key = AT.SlotKey(city:GetID(), definition.Index, index), city = city:GetID(),
                            building = definition.Index, slot = index, slotType = slotType, work = id,
                            container = container, group = group, flexibility = flexibility[slotType] or 0};
                        container.slots[#container.slots + 1] = slot;
                        table.insert(container.groups[group].slots, slot);
                        snapshot.slots[slot.key] = slot;
                        if id == -1 then container.full = false;
                        else
                            local info = GameInfo.GreatWorks[buildings:GetGreatWorkTypeFromIndex(id)];
                            if info then
                                local movable = true;
                                if artObjects[info.GreatWorkObjectType] then
                                    movable = Game.GetCurrentGameTurn() >= buildings:GetTurnFromIndex(id) +
                                        (tonumber(GlobalParameters.GREATWORK_ART_LOCK_TIME) or 10);
                                end
                                snapshot.works[id] = {id = id, object = info.GreatWorkObjectType, era = info.EraType,
                                    person = info.GreatPersonIndividualType or buildings:GetCreatorNameFromIndex(id),
                                    civilization = Game.GetGreatWorkPlayer(id), movable = movable,
                                    home = container.key, originalSlot = slot.key, value = Scoring.Work(info)};
                                snapshot.objects[info.GreatWorkObjectType] = true;
                            end
                        end
                    end
                    -- Respect native auto-theme traits/modifiers as well as DB rules.
                    container.themed = buildings:IsBuildingThemedCorrectly(definition.Index);
                    if container.themed then snapshot.themed = snapshot.themed + 1; end
                    container.allowed = container.unlocked and not container.themed;
                    for _, slot in ipairs(container.slots) do
                        local work = snapshot.works[slot.work];
                        if work then
                            if work.object == "GREATWORKOBJECT_ARTIFACT" and not container.full then work.movable = false; end
                            work.available = container.allowed;
                        end
                    end
                    if not container.allowed then snapshot.locked = snapshot.locked + 1; end
                    snapshot.containers[#snapshot.containers + 1] = container;
                end
            end
        end
    end
    table.sort(snapshot.containers, function(a, b) return a.key < b.key; end);
    return snapshot;
end

local function Compatible(group, work, rules)
    if not rules then return true; end
    if Flag(rules.ThemingSameEras) and work.era == nil then return false; end
    if Flag(rules.ThemingUniquePerson) and (not work.person or work.person == "") then return false; end
    if Flag(rules.ThemingUniqueCivs) and (work.civilization == nil or work.civilization < 0) then return false; end
    for _, other in ipairs(group) do
        if Flag(rules.ThemingSameObjectType) and other.object ~= work.object then return false; end
        if Flag(rules.ThemingSameEras) and other.era ~= work.era then return false; end
        if Flag(rules.ThemingUniquePerson) and other.person == work.person then return false; end
        if Flag(rules.ThemingUniqueCivs) and other.civilization == work.civilization then return false; end
    end
    return true;
end

local function FindAssignment(container, snapshot, used, budget)
    local groups, assignment, selected, slots = {}, {}, {}, {};
    for name in pairs(container.groups) do groups[name] = {}; end
    for _, slot in ipairs(container.slots) do
        local work = snapshot.works[slot.work];
        if work and not work.movable then
            if used[work.id] or not Compatible(groups[slot.group], work, container.groups[slot.group].rules) then return nil; end
            assignment[slot.key] = work.id; selected[work.id] = true;
            table.insert(groups[slot.group], work);
        elseif slot.work ~= -1 and not work then return nil;
        else slots[#slots + 1] = slot; end
    end
    table.sort(slots, function(a, b)
        if a.flexibility ~= b.flexibility then return a.flexibility < b.flexibility; end
        return a.key < b.key;
    end);
    local nodes = 0;
    local function Search(position)
        nodes = nodes + 1; budget.nodes = budget.nodes + 1;
        if nodes > 12000 or budget.nodes > 150000 then return false; end
        if position > #slots then return true; end
        local slot = slots[position];
        local group, rules = groups[slot.group], container.groups[slot.group].rules;
        local pool = {};
        for _, work in pairs(snapshot.works) do
            if work.available and work.movable and not used[work.id] and not selected[work.id] and Fits(work, slot) and
                (work.object ~= "GREATWORKOBJECT_ARTIFACT" or container.full) and Compatible(group, work, rules) then
                pool[#pool + 1] = work;
            end
        end
        table.sort(pool, function(a, b)
            if (a.id == slot.work) ~= (b.id == slot.work) then return a.id == slot.work; end
            if (a.home == container.key) ~= (b.home == container.key) then return a.home == container.key; end
            return a.id < b.id;
        end);
        for _, work in ipairs(pool) do
            selected[work.id] = true; assignment[slot.key] = work.id; group[#group + 1] = work;
            if Search(position + 1) then return true; end
            selected[work.id] = nil; assignment[slot.key] = nil; group[#group] = nil;
        end
        return false;
    end
    if not Search(1) then return nil; end
    -- Slots in the same group have identical type/rules; preserve the positions
    -- of selected local works instead of needlessly shuffling them internally.
    for _, group in pairs(container.groups) do
        local remaining = {};
        for _, slot in ipairs(group.slots) do remaining[assignment[slot.key]] = true; end
        local normalized = {};
        for _, slot in ipairs(group.slots) do
            if remaining[slot.work] then normalized[slot.key] = slot.work; remaining[slot.work] = nil; end
        end
        local ids = {}; for id in pairs(remaining) do ids[#ids + 1] = id; end; table.sort(ids);
        local cursor = 1;
        for _, slot in ipairs(group.slots) do
            assignment[slot.key] = normalized[slot.key] or ids[cursor];
            if not normalized[slot.key] then cursor = cursor + 1; end
        end
    end
    return assignment;
end

function AT.CanSwap(source, destination, snapshot, contents)
    local a = contents and contents[source.key] or source.work;
    local b = contents and contents[destination.key] or destination.work;
    if a == -1 or source.key == destination.key or not source.container.allowed or not destination.container.allowed then return false; end
    local work, other = snapshot.works[a], snapshot.works[b];
    if not work or not work.movable or not Fits(work, destination) then return false; end
    if b ~= -1 and (not other or not other.movable or not Fits(other, source)) then return false; end
    local function Full(container)
        for _, slot in ipairs(container.slots) do
            if (contents and contents[slot.key] or slot.work) == -1 then return false; end
        end
        return true;
    end
    if work.object == "GREATWORKOBJECT_ARTIFACT" or (other and other.object == "GREATWORKOBJECT_ARTIFACT") then
        if not Full(source.container) or not Full(destination.container) then return false; end
    end
    return true;
end

local function Route(snapshot, desired, targets)
    local contents, steps, protected, accepted = {}, {}, {}, {};
    local slots = {};
    for key, slot in pairs(snapshot.slots) do contents[key] = slot.work; slots[#slots + 1] = slot; end
    table.sort(slots, function(a, b) return a.key < b.key; end);
    local function Swap(a, b)
        if protected[a.key] or protected[b.key] or not AT.CanSwap(a, b, snapshot, contents) then return false; end
        steps[#steps + 1] = {source = a.key, destination = b.key, work = contents[a.key], other = contents[b.key]};
        contents[a.key], contents[b.key] = contents[b.key], contents[a.key];
        return true;
    end
    for _, target in ipairs(targets) do
        local before, beforeProtected, start = {}, {}, #steps;
        for key, value in pairs(contents) do before[key] = value; end
        for key, value in pairs(protected) do beforeProtected[key] = value; end
        local success = true;
        for _, destination in ipairs(target.slots) do
            local wanted = desired[destination.key];
            if contents[destination.key] ~= wanted then
                local source;
                for _, slot in ipairs(slots) do if contents[slot.key] == wanted then source = slot; break; end end
                local done = source and Swap(source, destination);
                if source and not done and not protected[source.key] then
                    for _, buffer in ipairs(slots) do
                        if buffer ~= source and buffer ~= destination and not protected[buffer.key] then
                            local a, b = contents[destination.key], contents[buffer.key];
                            if AT.CanSwap(destination, buffer, snapshot, contents) then
                                contents[destination.key], contents[buffer.key] = b, a;
                                local canFinish = AT.CanSwap(source, destination, snapshot, contents);
                                contents[destination.key], contents[buffer.key] = a, b;
                                if canFinish then Swap(destination, buffer); done = Swap(source, destination); break; end
                            end
                            local x, y = contents[source.key], contents[buffer.key];
                            if AT.CanSwap(source, buffer, snapshot, contents) then
                                contents[source.key], contents[buffer.key] = y, x;
                                local canFinish = AT.CanSwap(buffer, destination, snapshot, contents);
                                contents[source.key], contents[buffer.key] = x, y;
                                if canFinish then Swap(source, buffer); done = Swap(buffer, destination); break; end
                            end
                        end
                    end
                end
                if not done then success = false; break; end
            end
            protected[destination.key] = true;
        end
        if success then accepted[#accepted + 1] = target;
        else
            contents, protected = before, beforeProtected;
            while #steps > start do steps[#steps] = nil; end
        end
    end
    return contents, steps, protected, accepted, slots;
end

function AT.Plan(snapshot)
    local desired, targets, used, selected = {}, {}, {}, {};
    local budget = {nodes = 0};
    while budget.nodes <= 150000 do
        local best;
        for _, container in ipairs(snapshot.containers) do
            if container.allowed and container.themeable and not selected[container.key] then
                local assignment = FindAssignment(container, snapshot, used, budget);
                if assignment then
                    local imports, gain = 0, 0;
                    for key, id in pairs(assignment) do
                        local work = snapshot.works[id];
                        if work.home ~= container.key then imports = imports + 1; end
                        local rules = container.groups[snapshot.slots[key].group].rules or {};
                        gain = gain + Scoring.Value(work) * math.max(tonumber(rules.ThemingTourismMultiplier) or 0,
                            tonumber(rules.ThemingYieldMultiplier) or 0, 100) / 100;
                    end
                    if not best or imports < best.imports or (imports == best.imports and gain > best.gain) then
                        best = {container = container, assignment = assignment, imports = imports, gain = gain};
                    end
                end
            end
        end
        if not best then break; end
        selected[best.container.key] = true; targets[#targets + 1] = best.container;
        for key, id in pairs(best.assignment) do desired[key] = id; used[id] = true; end
    end
    local contents, steps, protected, accepted, slots = Route(snapshot, desired, targets);
    local themeSteps = #steps;
    for _ = 1, 64 do
        local best;
        for i, source in ipairs(slots) do
            if not protected[source.key] then
                for j = i + 1, #slots do
                    local destination = slots[j];
                    if not protected[destination.key] then
                        local a, b = snapshot.works[contents[source.key]], snapshot.works[contents[destination.key]];
                        local first, second = source, destination;
                        if not a then first, second = destination, source; end
                        if (a or b) and AT.CanSwap(first, second, snapshot, contents) then
                            local gain = (a and Scoring.Placement(a, destination) - Scoring.Placement(a, source) or 0) +
                                (b and Scoring.Placement(b, source) - Scoring.Placement(b, destination) or 0);
                            if gain > 0.0001 and (not best or gain > best.gain) then best = {a = first, b = second, gain = gain}; end
                        end
                    end
                end
            end
        end
        if not best then break; end
        local a, b = best.a, best.b;
        steps[#steps + 1] = {source = a.key, destination = b.key, work = contents[a.key], other = contents[b.key]};
        contents[a.key], contents[b.key] = contents[b.key], contents[a.key];
    end
    return {steps = steps, targets = accepted, themeSteps = themeSteps, placementSteps = #steps - themeSteps,
        skipped = #targets - #accepted, limited = budget.nodes > 150000 or #steps - themeSteps >= 64};
end
