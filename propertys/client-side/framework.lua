
local function PropertyNotify(title, description, notifyType, duration)
    local normalized = notifyType
    if notifyType == "verde" then normalized = "success"
    elseif notifyType == "vermelho" then normalized = "error"
    elseif notifyType == "amarelo" or notifyType == "policia" then normalized = "inform"
    end

    local payload = {
        title = title or "Propriedades",
        description = description or "",
        type = normalized or "inform",
        duration = tonumber(duration) or 5000
    }

    if Config.Notification == "mri_supreme_bridge"
        and GetResourceState("mri_supreme_bridge") == "started" then
        exports.mri_supreme_bridge:Notify(payload)
        return
    end

    lib.notify(payload)
end

-- Compatibilidade local para as notificações herdadas do recurso original.
RegisterNetEvent("Notify", function(title, description, notifyType, duration)
    PropertyNotify(title, description, notifyType, duration)
end)

vSERVER = setmetatable({}, {
    __index = function(_, method)
        return function(...)
            return lib.callback.await(("propertys:qbox:%s"):format(method), false, ...)
        end
    end
})

lib.callback.register("propertys:qbox:confirm", function(title, message)
    local result = lib.alertDialog({
        header = title or "Propriedades",
        content = message or "",
        centered = true,
        cancel = true,
        labels = { confirm = "Confirmar", cancel = "Cancelar" }
    })
    return result == "confirm"
end)

lib.callback.register("propertys:qbox:input", function(label)
    local result = lib.inputDialog("Propriedades", {
        { type = "input", label = label or "Valor", required = true }
    })
    return result and result[1] or nil
end)

lib.callback.register("propertys:qbox:skillcheck", function(stages)
    local difficulty = {}
    local speed = tonumber(Config.LockpickSkillcheckSpeed) or 0.5
    local setting = { areaSize = 42, speedMultiplier = speed }

    for _ = 1, tonumber(stages) or 3 do difficulty[#difficulty + 1] = setting end
    return lib.skillCheck(difficulty, { "w", "a", "s", "d" })
end)

local function getAppearanceResource()
    local resource = Config.AppearanceResource or Config.Appearance or "illenium-clothing"
    return GetResourceState(resource) == "started" and resource or nil
end

lib.callback.register("propertys:qbox:appearance", function()
    local resource = getAppearanceResource()
    if not resource then
        PropertyNotify("Armário", "O illenium-clothing não está iniciado.", "error")
        return nil
    end

    local success, appearance = pcall(function()
        return exports[resource]:getPedAppearance(cache.ped)
    end)

    if not success or type(appearance) ~= "table" then
        PropertyNotify("Armário", "Não foi possível capturar a roupa atual.", "error")
        return nil
    end

    return appearance
end)

RegisterNetEvent("propertys:qbox:playAnim", function(_, animation, loop)
    if type(animation) ~= "table" then return end
    local dict, name = animation[1], animation[2]
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, 8.0, -8.0, loop and -1 or 5000, loop and 49 or 0, 0.0, false, false, false)
end)

RegisterNetEvent("propertys:qbox:stopAnim", function()
    ClearPedTasks(cache.ped)
end)

PropertyFramework = {}
function PropertyFramework.playAnim(upper, animation, loop)
    local dict, name = animation[1], animation[2]
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, 8.0, -8.0, loop and -1 or 5000, upper and 49 or 0, 0.0, false, false, false)
end
function PropertyFramework.Destroy()
    ClearPedTasks(cache.ped)
end


local menuContexts = {}
local rootOptions = {}
local menuOptionKeys = {}

local function normalizeText(value)
    value = tostring(value or "")
    value = value:gsub("<br%s*/?>", "\n")
    value = value:gsub("<yellow>", "**"):gsub("</yellow>", "**")
    value = value:gsub("<[^>]+>", "")
    return value
end

local function contextId(id)
    return ("propertys_%s"):format(tostring(id or "root"):gsub("[^%w_]", "_"))
end

PropertyMenu = {}

function PropertyMenu.Reset()
    menuContexts = {}
    rootOptions = {}
    menuOptionKeys = {}
end

local function insertUniqueOption(containerKey, options, option, uniqueKey)
    containerKey = tostring(containerKey or "root")
    uniqueKey = ("%s:%s"):format(containerKey, tostring(uniqueKey or option.title or #options + 1))

    if menuOptionKeys[uniqueKey] then
        return false
    end

    menuOptionKeys[uniqueKey] = true
    table.insert(options, option)
    return true
end

function PropertyMenu.AddMenu(title, description, id, parent)
    local key = tostring(id)
    local targetId = contextId(key)

    menuContexts[key] = menuContexts[key] or {
        id = targetId,
        title = normalizeText(title),
        menu = parent and contextId(parent) or "propertys_root",
        options = {}
    }

    -- ox_lib exige uma opção explícita apontando para o submenu.
    local option = {
        title = normalizeText(title),
        description = normalizeText(description),
        menu = targetId
    }

    if parent and parent ~= false and tostring(parent) ~= "" then
        local parentKey = tostring(parent)
        menuContexts[parentKey] = menuContexts[parentKey] or {
            id = contextId(parentKey),
            title = parentKey,
            menu = "propertys_root",
            options = {}
        }
        insertUniqueOption(parentKey, menuContexts[parentKey].options, option, "menu:" .. key)
    else
        insertUniqueOption("root", rootOptions, option, "menu:" .. key)
    end
end

function PropertyMenu.AddButton(title, description, eventName, eventArgs, parent, isServer)
    local option = {
        title = normalizeText(title),
        description = normalizeText(description)
    }

    if eventName and eventName ~= "" then
        option.onSelect = function()
            if isServer then
                TriggerServerEvent(eventName, eventArgs)
            else
                TriggerEvent(eventName, eventArgs)
            end
        end
    else
        option.disabled = true
    end

    if parent and parent ~= false and tostring(parent) ~= "" then
        local key = tostring(parent)
        menuContexts[key] = menuContexts[key] or {
            id = contextId(key),
            title = key,
            options = {}
        }
        local eventKey = ("%s:%s:%s"):format(
            tostring(eventName or ""),
            tostring(eventArgs or ""),
            tostring(title or "")
        )
        insertUniqueOption(key, menuContexts[key].options, option, "button:" .. eventKey)
    else
        local eventKey = ("%s:%s:%s"):format(
            tostring(eventName or ""),
            tostring(eventArgs or ""),
            tostring(title or "")
        )
        insertUniqueOption("root", rootOptions, option, "button:" .. eventKey)
    end
end

function PropertyMenu.Open()
    for _, context in pairs(menuContexts) do
        lib.registerContext(context)
    end

    lib.registerContext({
        id = "propertys_root",
        title = "Propriedades",
        options = rootOptions
    })

    lib.showContext("propertys_root")
end

function PropertyMenu.Close()
    lib.hideContext(false)
    PropertyMenu.Reset()
end

RegisterNetEvent("propertys:menu:addMenu", function(...)
    PropertyMenu.AddMenu(...)
end)

RegisterNetEvent("propertys:menu:addButton", function(...)
    PropertyMenu.AddButton(...)
end)

RegisterNetEvent("propertys:menu:close", function()
    PropertyMenu.Close()
end)

RegisterNetEvent("propertys:client:openStash", function(stash)
    if not stash then return end
    exports.ox_inventory:openInventory("stash", stash)
end)

RegisterNetEvent("propertys:client:applyAppearance", function(appearance)
    if type(appearance) ~= "table" then
        PropertyNotify("Armário", "A vestimenta salva é inválida.", "error")
        return
    end

    local resource = getAppearanceResource()
    if not resource then
        PropertyNotify("Armário", "O illenium-clothing não está iniciado.", "error")
        return
    end

    local success = pcall(function()
        exports[resource]:setPedAppearance(cache.ped, appearance)
    end)

    if not success then
        PropertyNotify("Armário", "Não foi possível aplicar a aparência salva.", "error")
    end
end)

RegisterNetEvent("propertys:client:openAppearance", function()
    if not getAppearanceResource() then
        PropertyNotify("Armário", "O illenium-clothing não está iniciado.", "error")
        return
    end

    -- O recurso se chama illenium-clothing, porém mantém os eventos oficiais
    -- do illenium-appearance. Este menu permite editar roupas e acessar outfits.
    TriggerEvent("illenium-appearance:client:openClothingShopMenu", false)
end)

RegisterNetEvent("propertys:client:openOutfits", function()
    if not getAppearanceResource() then
        PropertyNotify("Armário", "O illenium-clothing não está iniciado.", "error")
        return
    end

    TriggerEvent("illenium-appearance:client:openOutfitMenu")
end)

RegisterNetEvent("propertys:client:policeAlert", function(data)
    data = data or {}
    local coords = data.coords
    lib.notify({
        title = data.title or "Central de polícia",
        description = "Possível invasão de propriedade.",
        type = "inform",
        duration = 10000
    })

    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.1)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.title or "Invasão de propriedade")
    EndTextCommandSetBlipName(blip)

    SetTimeout((Config.AlertBlipDuration or 60) * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)





local propertyGarageZones = {}
local garageTextVisible = false

local function hideGarageText()
    if garageTextVisible then
        lib.hideTextUI()
        garageTextVisible = false
    end
end

local function removePropertyGarageZone(propertyName)
    local zone = propertyGarageZones[propertyName]
    if zone then
        zone:remove()
        propertyGarageZones[propertyName] = nil
    end

    hideGarageText()
end

local function buildGarageArgs(propertyName, spawn)
    return {
        garage = ("property_%s"):format(propertyName),
        type = Config.GarageVehicleTypes or {
            "car",
            "motorcycle",
            "cycles"
        },
        spawnpoint = vec4(
            spawn.x,
            spawn.y,
            spawn.z,
            spawn.w or spawn.heading or 0.0
        ),
        ignoreDist = true,
        shared = false
    }
end

local function createPropertyGarageZone(propertyName, spawn)
    if not propertyName or not spawn then return end

    removePropertyGarageZone(propertyName)

    local zoneCoords = vec3(spawn.x, spawn.y, spawn.z)
    local radius = tonumber(Config.GarageZoneRadius) or 4.0
    local args = buildGarageArgs(propertyName, spawn)

    propertyGarageZones[propertyName] = lib.zones.sphere({
        coords = zoneCoords,
        radius = radius,
        debug = Config.DebugGarageZone == true,

        onEnter = function()
            local label = cache.vehicle
                and "[E] Guardar veículo"
                or "[E] Abrir garagem"

            lib.showTextUI(label, {
                position = "right-center",
                icon = "warehouse"
            })
            garageTextVisible = true
        end,

        inside = function()
            if not IsControlJustPressed(0, 38) then return end

            if GetResourceState("rhd_garage") ~= "started" then
                PropertyNotify(
                    "Garagem",
                    "O recurso rhd_garage não está iniciado.",
                    "error"
                )
                return
            end

            if cache.vehicle then
                exports.rhd_garage:storeVehicle(args)
            else
                exports.rhd_garage:openMenu(args)
            end
        end,

        onExit = function()
            hideGarageText()
        end
    })
end

local function refreshPropertyGarageZone(propertyName)
    local spawn = lib.callback.await(
        "propertys:qbox:OpenGarage",
        false,
        propertyName
    )

    if not spawn then
        removePropertyGarageZone(propertyName)
        return false
    end

    createPropertyGarageZone(propertyName, spawn)
    return true
end

RegisterNetEvent("propertys:client:refreshGarageZone", function(propertyName)
    refreshPropertyGarageZone(propertyName)
end)

RegisterNetEvent("propertys:client:removeGarageZone", function(propertyName)
    removePropertyGarageZone(propertyName)
end)

local garageSetupActive = false

local function getGarageEntity()
    local ped = cache.ped
    local vehicle = cache.vehicle

    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    return ped
end

local function getPropertyGarageArgs(propertyName)
    if not propertyName or propertyName == "" then
        return nil
    end

    local spawn = lib.callback.await(
        "propertys:qbox:OpenGarage",
        false,
        propertyName
    )

    if not spawn then
        PropertyNotify(
            "Garagem",
            "Você não possui acesso a esta garagem.",
            "error"
        )
        return nil
    end

    return {
        garage = ("property_%s"):format(propertyName),
        type = Config.GarageVehicleTypes or {
            "car",
            "motorcycle",
            "cycles"
        },
        spawnpoint = vec4(
            spawn.x,
            spawn.y,
            spawn.z,
            spawn.w or spawn.heading or 0.0
        ),
        ignoreDist = true,
        shared = false
    }
end

local function openConfiguredGarage(propertyName)
    if GetResourceState("rhd_garage") ~= "started" then
        PropertyNotify(
            "Garagem",
            "O recurso rhd_garage não está iniciado.",
            "error"
        )
        return
    end

    local args = getPropertyGarageArgs(propertyName)
    if not args then return end

    exports.rhd_garage:openMenu(args)
end

local function getNearbyGarageVehicle()
    local ped = cache.ped or PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(ped, false)

    if currentVehicle and currentVehicle ~= 0 then
        return currentVehicle
    end

    local coords = GetEntityCoords(ped)
    local closestVehicle = lib.getClosestVehicle(coords, 6.0, false)

    if closestVehicle and closestVehicle ~= 0
        and DoesEntityExist(closestVehicle) then
        return closestVehicle
    end

    return nil
end

local function storeConfiguredGarage(propertyName)
    if GetResourceState("rhd_garage") ~= "started" then
        PropertyNotify(
            "Garagem",
            "O recurso rhd_garage não está iniciado.",
            "error"
        )
        return
    end

    local vehicle = getNearbyGarageVehicle()
    if not vehicle then
        PropertyNotify(
            "Garagem",
            "Nenhum veículo foi encontrado em até 6 metros.",
            "error"
        )
        return
    end

    local ped = cache.ped or PlayerPedId()
    local driver = GetPedInVehicleSeat(vehicle, -1)

    if IsPedInVehicle(ped, vehicle, false) and driver ~= ped then
        PropertyNotify(
            "Garagem",
            "Você precisa estar no banco do motorista.",
            "error"
        )
        return
    end

    local args = getPropertyGarageArgs(propertyName)
    if not args then return end

    local vehicleCoords = GetEntityCoords(vehicle)
    local spawnCoords = args.spawnpoint.xyz
    local maxDistance = tonumber(Config.GarageStoreDistance) or 10.0

    if #(vehicleCoords - spawnCoords) > maxDistance then
        PropertyNotify(
            "Garagem",
            ("Leve o veículo para até %.0f metros do ponto de spawn."):format(maxDistance),
            "error"
        )
        return
    end

    exports.rhd_garage:storeVehicle(args)
end

local function startGarageSetup(propertyName)
    if garageSetupActive then
        return PropertyNotify("Garagem", "Você já está configurando uma garagem.", "error")
    end

    garageSetupActive = true
    lib.hideContext(false)

    PropertyNotify(
        "Garagem",
        "Vá até o local onde o veículo deverá aparecer. Posicione-se ou estacione um veículo e pressione E. Pressione BACKSPACE para cancelar.",
        "inform"
    )

    lib.showTextUI("[E] Salvar spawn  |  [BACKSPACE] Cancelar", {
        position = "right-center",
        icon = "car"
    })

    local expires = GetGameTimer() + (Config.GarageSetupTimeout or 120000)

    CreateThread(function()
        while garageSetupActive do
            Wait(0)

            local entity = getGarageEntity()
            local coords = GetEntityCoords(entity)
            local heading = GetEntityHeading(entity)

            DrawMarker(
                36,
                coords.x, coords.y, coords.z + 0.35,
                0.0, 0.0, 0.0,
                0.0, 0.0, heading,
                0.65, 0.65, 0.65,
                255, 255, 255, 180,
                false, true, 2, false,
                nil, nil, false
            )

            if IsControlJustPressed(0, 38) then
                garageSetupActive = false
                lib.hideTextUI()

                local success, message = lib.callback.await(
                    "propertys:qbox:SaveGarage",
                    false,
                    propertyName,
                    {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        w = heading
                    }
                )

                if success then
                    refreshPropertyGarageZone(propertyName)
                    PropertyNotify(
                        "Garagem",
                        message or "Spawn salvo e zona da garagem ativada.",
                        "success"
                    )
                else
                    PropertyNotify("Garagem", message or "Não foi possível salvar o spawn.", "error")
                end

                return
            end

            if IsControlJustPressed(0, 177) or GetGameTimer() >= expires then
                garageSetupActive = false
                lib.hideTextUI()
                PropertyNotify("Garagem", "Configuração cancelada.", "inform")
                return
            end
        end
    end)
end

local function openGaragePropertyMenu(propertyName)
    lib.registerContext({
        id = "propertys_garage_actions",
        title = "Garagem da propriedade",
        options = {
            {
                title = "Ativar ponto da garagem",
                description = "Cria ou atualiza a zona da garagem no ponto salvo.",
                icon = "warehouse",
                onSelect = function()
                    local created = refreshPropertyGarageZone(propertyName)
                    if created then
                        PropertyNotify(
                            "Garagem",
                            "Zona da garagem ativada. Use E no ponto configurado.",
                            "success"
                        )
                    else
                        PropertyNotify(
                            "Garagem",
                            "Configure primeiro o ponto de spawn.",
                            "error"
                        )
                    end
                end
            },
            {
                title = "Configurar ponto da garagem",
                description = "Somente o proprietário. Define onde abrir e guardar veículos.",
                icon = "location-dot",
                onSelect = function()
                    startGarageSetup(propertyName)
                end
            }
        }
    })

    lib.showContext("propertys_garage_actions")
end

RegisterNetEvent("propertys:client:garage", function(propertyName)
    openGaragePropertyMenu(propertyName)
end)

RegisterNetEvent("propertys:client:alarm", function(data)
    data = data or {}
    if LocalPlayer.state.insideProperty ~= data.property then return end

    local expires = GetGameTimer() + ((tonumber(data.duration) or 20) * 1000)
    CreateThread(function()
        SendNUIMessage({ action = "playAlarm", volume = Config.AlarmVolume or 0.35 })

        while GetGameTimer() < expires and LocalPlayer.state.insideProperty == data.property do
            Wait(250)
        end

        SendNUIMessage({ action = "stopAlarm" })
    end)
end)


AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SendNUIMessage({ action = "stopAlarm" })

    for propertyName in pairs(propertyGarageZones) do
        removePropertyGarageZone(propertyName)
    end
end)
