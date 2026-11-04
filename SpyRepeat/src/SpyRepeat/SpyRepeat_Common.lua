-- Shared definition only; no HD globals, scripts or database entries are replaced.
SpyRepeat = {};
SpyRepeat.Property = "SpyRepeat_Registry_v1";

function SpyRepeat.IsSpy(unit)
    if unit == nil then return false; end
    local definition = GameInfo.Units[unit:GetType()];
    return definition ~= nil and definition.Spy == true;
end

function SpyRepeat.IsRepeatable(operation)
    if operation == nil then return false; end
    local name = operation.OperationType;
    if name == "UNITOPERATION_SPY_COUNTERSPY" or name == "UNITOPERATION_SPY_LISTENING_POST" then
        return true;
    end
    -- Gain Sources is preparation, not a mission to run forever.
    return operation.CategoryInUI == "OFFENSIVESPY" and name ~= "UNITOPERATION_SPY_GAIN_SOURCES";
end
