-- Compatibility helpers for the original Creative property configuration.
-- Replace these fallbacks with metadata from your own item/vehicle definitions when desired.

Currency = Currency or "R$ "

function parseInt(value, positive)
    local number = math.floor(tonumber(value) or 0)
    if positive and number < 0 then return 0 end
    return number
end

function Dotted(value)
    local formatted = tostring(parseInt(value))
    while true do
        local changed
        formatted, changed = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        if changed == 0 then break end
    end
    return formatted
end

function splitString(value, separator)
    local result = {}
    separator = separator or "-"
    for part in string.gmatch(tostring(value), "([^"..separator.."]+)") do
        result[#result + 1] = part
    end
    return result
end

function GenerateString(pattern)
    return (pattern:gsub("[LD]", function(token)
        if token == "L" then return string.char(math.random(65, 90)) end
        return tostring(math.random(0, 9))
    end))
end

function ItemExist(item)
    return type(item) == "string" and item ~= ""
end

function ItemName(item)
    local base = splitString(item)[1]
    local data = exports.ox_inventory and exports.ox_inventory:Items(base)
    return data and data.label or base
end

function ItemNamed(item)
    local data = exports.ox_inventory and exports.ox_inventory:Items(splitString(item)[1])
    return data and data.close ~= nil or false
end

function ItemFridge(item)
    local data = exports.ox_inventory and exports.ox_inventory:Items(splitString(item)[1])
    return data and data.fridge == true or false
end

function ItemDurability(item)
    local data = exports.ox_inventory and exports.ox_inventory:Items(splitString(item)[1])
    return data and data.degrade or false
end

function ItemLoads(item)
    local data = exports.ox_inventory and exports.ox_inventory:Items(splitString(item)[1])
    return data and data.ammo or false
end

function VehicleExist(model)
    return type(model) == "string" and model ~= ""
end

function VehicleName(model)
    return model
end
