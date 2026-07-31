local RESOURCE = 'codem-supreme-notification'

local function normalizeType(value)
    value = type(value) == 'string' and value:lower() or 'info'
    if value == 'success' then return 'success' end
    if value == 'error' or value == 'danger' then return 'error' end
    return 'info'
end

local function normalizeClientArgs(...)
    local args = { ... }
    local message, notifyType, duration

    if type(args[1]) == 'table' then
        local data = args[1]
        message = data.description or data.text or data.message or data.title
        notifyType = data.type or data.notifyType
        duration = data.duration or data.length or data.timeout
    else
        message = args[1]
        notifyType = args[2]
        duration = args[3]
    end

    if type(message) == 'table' then
        message = message.text or message.message or message.description or json.encode(message)
    end

    return tostring(message or ''), normalizeType(notifyType), tonumber(duration) or 3000
end

local function sendNotification(...)
    local message, notifyType, duration = normalizeClientArgs(...)

    if GetResourceState(RESOURCE) ~= 'started' then
        print(('[mri_supreme_bridge] %s'):format(message))
        return false
    end

    if notifyType == 'success' then
        exports[RESOURCE]:Success(message, duration)
    elseif notifyType == 'error' then
        exports[RESOURCE]:Error(message, duration)
    else
        exports[RESOURCE]:Info(message, duration)
    end

    return true
end

exports('Notify', sendNotification)

RegisterNetEvent('mri_supreme_bridge:notify', function(...)
    sendNotification(...)
end)

-- Compatibilidade para scripts protegidos ou não editados.
RegisterNetEvent('QBCore:Notify', function(...)
    sendNotification(...)
end)

RegisterNetEvent('qbx_core:client:notify', function(...)
    sendNotification(...)
end)
