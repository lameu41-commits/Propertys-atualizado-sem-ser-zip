Config = Config or {}

-- Integrações detectadas no resources.zip.
-- O nome da pasta instalada é "illenium-clothing", mas os eventos internos
-- permanecem com o prefixo oficial "illenium-appearance".
Config.Appearance = "illenium-clothing"
Config.AppearanceResource = "illenium-clothing"
Config.Notification = "mri_supreme_bridge"
Config.Dispatch = "native" -- o pack não contém ps-dispatch

Config.PoliceJobs = {
    police = true,
    sheriff = true,
    state = true
}

Config.RequirePoliceDuty = true
Config.AlertBlipDuration = 60

-- Garagem real do pack.
Config.Garage = "rhd_garage"
Config.GarageMaxDistance = 6.0
Config.GarageStoreDistance = 10.0
Config.GarageSetupMaxDistance = 45.0
Config.GarageSetupTimeout = 120000
Config.ServerValidationDistance = 7.0

-- O propertys original só possui a entrada da casa.
-- Cadastre coordenadas específicas abaixo quando desejar.
Config.PropertyGarages = {
    -- Propertys0001 = {
    --     menu = vec3(1000.0, -730.0, 57.8),
    --     spawn = vec4(1004.0, -734.0, 57.5, 90.0)
    -- }
}

-- Fallback usado quando uma propriedade não tem posição cadastrada.
Config.GarageFallbackOffset = vec3(4.0, 0.0, 0.0)
Config.GarageFallbackHeading = 0.0
Config.GarageVehicleTypes = { "car", "motorcycle", "cycles" }

-- Segurança e propriedade.
Config.OperationCooldown = 1500
Config.MaxProperties = 3

-- Itens do ox_inventory.
Config.PropertyKeyItem = "propertys"
Config.LockpickItem = "lockpick"
Config.GemItem = "gemstone"

-- Mantém a área de acerto da dificuldade "medium" e reduz a velocidade do minijogo.
-- 1.0 é a velocidade padrão; valores menores deixam a lockpick mais lenta.
Config.LockpickSkillcheckSpeed = 0.5

Config.MinimumPolice = 0
-- Toda invasão exige lockpick, inclusive para jogadores com cargo policial.
Config.RobberyPoliceBypass = true
Config.RobberyCooldownMinutes = 60
Config.RobberyInteractionDistance = 2.0
Config.RobberyStashSlots = 100
Config.RobberyStashWeight = 775000
Config.LockerStashWeight = 675000

Config.BenefitAces = {
    ["Central Plus"] = "propertys.benefit.plus",
    ["Central Silver"] = "propertys.benefit.silver",
    ["Central Basic"] = "propertys.benefit.basic"
}

Config.AlarmDuration = 20
-- O alarme é reproduzido apenas para quem estiver dentro da residência invadida.
-- Ajuste estes valores caso queira outro áudio nativo do GTA.
Config.AlarmVolume = 0.35

Config.GarageZoneRadius = 4.0
Config.DebugGarageZone = false
