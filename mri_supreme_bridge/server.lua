local function normalizeServerArgs(...)
    local args = { ... }
    local target, payloadStart

    if type(args[1]) == 'number' then
        target = args[1]
        payloadStart = 2
    else
        target = source
        payloadStart = 1
    end

    local payload = {}
    for index = payloadStart, #args do
        payload[#payload + 1] = args[index]
    end

    return target, payload
end

local function notify(...)
    local target, payload = normalizeServerArgs(...)

    if not target or target <= 0 then
        print('[mri_supreme_bridge] Não foi possível determinar o jogador da notificação.')
        return false
    end

    TriggerClientEvent('mri_supreme_bridge:notify', target, table.unpack(payload))
    return true
end

exports('Notify', notify)

RegisterNetEvent('mri_supreme_bridge:notify', function(...)
    local src = source
    local args = { ... }

    -- Chamadas server-side podem informar o destino no primeiro argumento.
    if type(args[1]) == 'number' then
        TriggerClientEvent('mri_supreme_bridge:notify', args[1], table.unpack(args, 2))
    else
        TriggerClientEvent('mri_supreme_bridge:notify', src, table.unpack(args))
    end
end)
