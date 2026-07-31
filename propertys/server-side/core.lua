



local function CompleteTimers(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400

    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600

    local minutes = math.floor(seconds / 60)

    local parts = {}

    if days > 0 then
        parts[#parts + 1] = ("%d dia%s"):format(days, days == 1 and "" or "s")
    end

    if hours > 0 then
        parts[#parts + 1] = ("%d hora%s"):format(hours, hours == 1 and "" or "s")
    end

    if minutes > 0 and #parts < 2 then
        parts[#parts + 1] = ("%d minuto%s"):format(minutes, minutes == 1 and "" or "s")
    end

    if #parts == 0 then
        return "menos de 1 minuto"
    end

    return table.concat(parts, " e ")
end

local function SafeClientEvent(eventName, target, ...)
    if type(eventName) ~= "string" or eventName == "" then
        print("^1[propertys] Evento de cliente inválido bloqueado.^0")
        return false
    end

    if target == -1 then
        TriggerClientEvent(eventName, -1, ...)
        return true
    end

    local playerId = tonumber(target)
    if not playerId or playerId <= 0 or GetPlayerPing(playerId) <= 0 then
        print(("^3[propertys] TriggerClientEvent '%s' ignorado: jogador inválido (%s).^0")
            :format(eventName, tostring(target)))
        return false
    end

    TriggerClientEvent(eventName, playerId, ...)
    return true
end

local function ValidPropertyName(name)
    return type(name) == "string" and Propertys[name] ~= nil
end

local function IsPlayerNearProperty(src, name, maxDistance)
    if not ValidPropertyName(name) then return false end
    local ped = GetPlayerPed(src)
    if ped <= 0 then return false end
    local coords = GetEntityCoords(ped)
    return #(coords - Propertys[name].Coords) <= (maxDistance or Config.ServerValidationDistance or 5.0)
end

local function HasPropertyAccess(src, name, ownerOnly)
    local citizenid = PropertyFramework.CitizenId(src)
    if not citizenid or not ValidPropertyName(name) then return false end
    local consult = PropertyFramework.SingleQuery("propertys/Exist", { Name = name })
    if not consult then return false end
    if consult.citizenid == citizenid then return true end
    return not ownerOnly and PropertyFramework.InventoryFull(citizenid, "propertys-" .. consult.Serial)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Lock = {}
local Saved = {}
local Inside = {}
local Active = {}
local Robbery = {}
local Markers = {}
local InsideName = {}
local CountClothes = {}
local PropertyService = {}

local PropertyLocks = {}
local EventCooldowns = {}

local function NotifyPlayer(src, message, notifyType)
    local normalized = notifyType
    if notifyType == "verde" then normalized = "success"
    elseif notifyType == "vermelho" then normalized = "error"
    elseif notifyType == "amarelo" or notifyType == "policia" then normalized = "inform"
    end

    local payload = {
        title = "Propriedades",
        description = message,
        type = normalized or "inform",
        duration = 10000
    }

    if Config.Notification == "mri_supreme_bridge"
        and GetResourceState("mri_supreme_bridge") == "started" then
        exports.mri_supreme_bridge:Notify(src, payload)
        return
    end

    exports.qbx_core:Notify(src, message, normalized or "inform", 10000)
end

local function RateLimited(src, action, milliseconds)
    local now = GetGameTimer()
    local key = ("%s:%s"):format(src, action)
    local expires = EventCooldowns[key] or 0
    if expires > now then return true end
    EventCooldowns[key] = now + (milliseconds or Config.OperationCooldown or 1500)
    return false
end

local function AcquirePropertyLock(name, src)
    if not ValidPropertyName(name) or PropertyLocks[name] then return false end
    PropertyLocks[name] = src
    return true
end

local function ReleasePropertyLock(name, src)
    if PropertyLocks[name] == src then PropertyLocks[name] = nil end
end

local function StableBucket(seed, offset)
    local hash = 0
    seed = tostring(seed or "")
    for index = 1, #seed do
        hash = (hash * 31 + seed:byte(index)) % 90000
    end
    return (offset or 100000) + hash
end

local function ValidateExteriorAction(src, name, ownerOnly)
    if not ValidPropertyName(name) then return false end
    if not IsPlayerNearProperty(src, name, Config.ServerValidationDistance or 5.0) then return false end
    if ownerOnly == nil then return true end
    return HasPropertyAccess(src, name, ownerOnly)
end


local function EnsureGarageTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `propertys_garages` (
            `property_name` varchar(100) NOT NULL,
            `x` double NOT NULL,
            `y` double NOT NULL,
            `z` double NOT NULL,
            `heading` float NOT NULL DEFAULT 0,
            `updated_by` varchar(50) DEFAULT NULL,
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
                ON UPDATE current_timestamp(),
            PRIMARY KEY (`property_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

CreateThread(function()
    EnsureGarageTable()
end)

local function GetSavedGarage(name)
    local row = MySQL.single.await(
        "SELECT x, y, z, heading FROM propertys_garages WHERE property_name = ? LIMIT 1",
        { name }
    )

    if not row then return nil end

    return {
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        w = tonumber(row.heading) or 0.0
    }
end

local function DispatchPolice(data)
    local coords = data and data.Coords or vec3(0.0, 0.0, 0.0)
    local alert = {
        source = data and data.Source,
        citizenid = data and data.citizenid,
        coords = coords,
        title = data and data.Title or "Invasão de propriedade",
        code = data and data.Code or 31
    }

    TriggerEvent("propertys:server:policeAlert", alert)

    if Config.Dispatch == "event" then
        return
    end

    for _, playerSource in ipairs(GetPlayers()) do
        playerSource = tonumber(playerSource)
        local player = exports.qbx_core:GetPlayer(playerSource)
        local job = player and player.PlayerData.job
        if job and Config.PoliceJobs[job.name]
            and (not Config.RequirePoliceDuty or job.onduty) then
            SafeClientEvent("propertys:client:policeAlert", playerSource, alert)
        end
    end
end

local function LockpickReduction(citizenid)
	if PropertyFramework.HasBenefit(citizenid,"Central Plus") then
		return 0.20
	end

	if PropertyFramework.HasBenefit(citizenid,"Central Silver") then
		return 0.10
	end

	if PropertyFramework.HasBenefit(citizenid,"Central Basic") then
		return 0.05
	end

	return 0.0
end

local function TryConsumeLockpick(citizenid,Item,BaseChance)
	if math.random() <= (BaseChance * (1.0 - LockpickReduction(citizenid))) then
		PropertyFramework.RemoveItem(citizenid,Item,1,true)
		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYALARM
-----------------------------------------------------------------------------------------------------------------------------------------
local function PlayAlarm(Name,InteriorType)
	if not Name or not Propertys[Name] then
		return
	end

	local OutsideCoords = Propertys[Name].Coords
	local Interior = InteriorType or Saved[Name]

	SafeClientEvent("propertys:client:alarm",-1,{
		property = Name,
		outside = OutsideCoords,
		inside = Interior and Internal[Interior] and Internal[Interior].Exit or nil,
		duration = Config.AlarmDuration or 20
	})
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ROBBERY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Robbery")
AddEventHandler("propertys:Robbery",function(Name)
	local src = source
	local citizenid = PropertyFramework.CitizenId(src)

	if RateLimited(src, "robbery", 3000) or not ValidateExteriorAction(src, Name, nil) then return false end
	if not citizenid or Active[citizenid] then
		return false
	end

	Active[citizenid] = true
	SafeClientEvent("propertys:menu:close",src)

	local Service = PropertyFramework.IsPolice(citizenid)
	if Config.RobberyPoliceBypass ~= true then Service = false end
	local Lockpick = PropertyFramework.ConsultItem(citizenid,(Config.LockpickItem or "lockpick"))
	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })
	local Warehouse = Consult and Consult.Interior == "Galpao"

	local robberyState = Robbery[Name]
	if robberyState and robberyState.expiresAt and robberyState.expiresAt > os.time() then
		NotifyPlayer(src, ("Esta propriedade já foi invadida recentemente. Aguarde %d minuto(s)."):format(math.ceil((robberyState.expiresAt - os.time()) / 60)))
		Active[citizenid] = nil
		return false
	end

	if Config.MinimumPolice and Config.MinimumPolice > 0 and not Service then
		local policeCount = PropertyFramework.CountPolice()
		if policeCount < Config.MinimumPolice then
			NotifyPlayer(src, ("É necessário ao menos %d policial(is) em serviço."):format(Config.MinimumPolice))
			Active[citizenid] = nil
			return false
		end
	end

	if Warehouse then
		SafeClientEvent("Notify",src,"Aviso","Galpões não podem ser invadidos.","amarelo",5000)
		Active[citizenid] = nil
		return false
	end

	if not Service and not Lockpick then
		SafeClientEvent("Notify",src,"Aviso","Você precisa de uma Lockpick para invadir a propriedade.","amarelo",5000)
		Active[citizenid] = nil
		return false
	end

	if not Service and Lockpick then
		if GetPlayerPing(src) <= 0 then
			Active[citizenid] = nil
			return false
		end

		local playerRef = Player(src)
		if playerRef and playerRef.state then
			playerRef.state:set("Buttons", true, true)
		end

		PropertyClient.playAnim(src,false,{"mini@repair","fixing_a_player"},true)
	end

	local TaskResult = Service or (Lockpick and PropertyFramework.Task(src,5,2500))
	
	if not Service and Lockpick then
		PropertyClient.Destroy(src)

		local playerRef = Player(src)
		if playerRef and playerRef.state then
			playerRef.state:set("Buttons", false, true)
		end
	end

	if TaskResult then
		Saved[Name] = Saved[Name] or (Consult and Consult.Interior or exports.propertys:Informations())
		Robbery[Name] = { expiresAt = os.time() + ((Config.RobberyCooldownMinutes or 60) * 60), items = {} }

		if not Service then
			if Lockpick then
				TryConsumeLockpick(citizenid,(Config.LockpickItem or "lockpick"),1.0)
			end

			if Consult then
				local Online = PropertyFramework.Source(Consult.citizenid)
				if Online then
					SafeClientEvent("Notify",Online,"Alerta de Segurança","Sua propriedade está sendo invadida, chame as autoridades para ajudar no local.","policia",10000)
				end
			end
		end

		SafeClientEvent("propertys:Enter",src,Name,Saved[Name])
	else
		if not Service and Lockpick then
			SafeClientEvent("Notify",src,"Aviso","Você falhou ao forçar a fechadura.","vermelho",5000)
		end
	end

	Active[citizenid] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ROBBERYITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:RobberyItem")
AddEventHandler("propertys:RobberyItem",function(Number,Name)
	local src = source
	local citizenid = PropertyFramework.CitizenId(src)

	if not citizenid then
		return false
	end

	if not Name or not Number or not ValidPropertyName(tostring(Name)) or InsideName[citizenid] ~= tostring(Name) then
		return false
	end

	Number = tostring(Number)
	Name = tostring(Name)

	local interiorName = Saved[Name]
	local furniture = interiorName and Internal[interiorName] and Internal[interiorName].Furniture
	local targetCoords = furniture and furniture[tonumber(Number)]
	if Number ~= "Locker" and (not targetCoords or not PropertyFramework.IsNearCoords(src, targetCoords, Config.RobberyInteractionDistance or 2.0)) then
		return false
	end

	if not Robbery[Name] or (Robbery[Name].expiresAt or 0) <= os.time() then
		return false
	end
	Robbery[Name].items = Robbery[Name].items or {}

	if Robbery[Name].items[Number] then
		SafeClientEvent("propertys:client:openStash",source,PropertyFramework.EnsureStash("Propertys:"..Name..":"..Number,100,775000))
		return false
	end

	local Locker = (Number == "Locker")

	Player(src).state.Buttons = true

	if not Locker then
		PropertyClient.playAnim(src,true,{"anim@gangops@facility@servers@bodysearch@","player_search"},true)
	end

	local TaskResult = (Locker and PropertyFramework.Safecrack(src,6)) or (not Locker and PropertyFramework.Task(src,5,2500))

	if not Locker then
		PropertyClient.Destroy(src)
	end

	Player(src).state.Buttons = false

	if not TaskResult then
		local Coords = Propertys[Name] and Propertys[Name].Coords or vec3(0.0,0.0,0.0)

		DispatchPolice({
			Source = src,
			citizenid = citizenid,
			Coords = Coords,
			Permission = "Policia",
			Title = "Roubo a Propriedade",
			Wanted = 30,
			Code = 31,
			Color = 44
		})

		PlayAlarm(Name,Saved[Name])

		return false
	end

	local Container = "Propertys:"..Name..":"..Number
	local Itens = Locker and LockerItens or OtherItens
	local Amount = Locker and 1 or math.random(3)

	PropertyFramework.PopulateRobberyStash(Container, Itens, Amount, Locker)
	SafeClientEvent("propertys:client:openStash",src,PropertyFramework.EnsureStash(Container,100,(Locker and 675000 or 775000)))
	SafeClientEvent("propertys:RemCircleZone",src,Number)
	Robbery[Name].items[Number] = true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- POLICE
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Police(source, Outside,Inside)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid then
		return false
	end

	DispatchPolice({
		Source = source,
		citizenid = citizenid,
		Coords = Outside,
		Permission = "Policia",
		Title = "Roubo a Propriedade",
		Wanted = 120,
		Code = 31,
		Color = 44
	})

	if InsideName[citizenid] then
		PlayAlarm(InsideName[citizenid],Saved[InsideName[citizenid]])
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Propertys(source, Name)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid or not ValidPropertyName(Name) or not IsPlayerNearProperty(source, Name) then
		return false
	end

	if Name == "Hotel" then
		return PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) <= 0 and "Hotel" or false
	end

	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })
	if not Consult then
		return "Nothing"
	end

	if Consult.citizenid ~= citizenid and Lock[Name] and not PropertyFramework.InventoryFull(citizenid,"propertys-"..Consult.Serial) then
		return false
	end

	if not Saved[Name] then
		Saved[Name] = Consult.Interior
	end

	local Interior = Saved[Name]
	local InteriorData = Informations[Interior]

	if not InteriorData or not tonumber(InteriorData.Price) then
		print(("^1[propertys] Interior inválido na propriedade '%s': %s^0")
			:format(tostring(Name), tostring(Interior)))
		return false
	end

	local CurrentTimer = os.time()
	local TaxTimestamp = tonumber(Consult.Tax) or 0
	local Price = tonumber(InteriorData.Price) * 0.25
	local Tax = CompleteTimers(TaxTimestamp - CurrentTimer)

	if CurrentTimer > TaxTimestamp then
		Tax = "Efetue o pagamento da Hipoteca."

		if PropertyFramework.Request(source,"Propriedades","Deseja pagar a hipoteca de "..Currency..Dotted(Price).."?") and PropertyFramework.PaymentFull(citizenid,Price) then
			SafeClientEvent("Notify",source,"Propriedades","Pagamento concluído.","verde",5000)
			PropertyFramework.Update("propertys/Tax",{ Name = Name })
			Tax = CompleteTimers(2592000)
		else
			return false
		end
	end

	return {
		Interior = Interior,
		Tax = Tax
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TOGGLE
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Toggle(source, Name,Mode)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid then
		return false
	end

	if Mode == "Exit" then
		InsideName[citizenid] = nil
		Inside[citizenid] = nil
		SetPlayerRoutingBucket(source, 0)
		TriggerEvent("PropertyFramework:ReloadWeapons",source)
	else
		if Name == "Hotel" and PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) > 0 then
			SafeClientEvent("Notify",source,"Hotel","Você não possui acesso ao hotel pois já possui propriedade(s).","amarelo",10000)
			return false
		end

		TriggerEvent("DebugWeapons",citizenid)
		Inside[citizenid] = Propertys[Name].Coords
		InsideName[citizenid] = Name

		local Bucket = Name == "Hotel" and StableBucket(citizenid, 200000) or StableBucket(Name, 100000)
		SetPlayerRoutingBucket(source, Bucket)
	end

	TriggerEvent("animals:Delete",citizenid,source)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:BUY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Buy")
AddEventHandler("propertys:Buy",function(Name)
	local src = source
	local Split = splitString(Name)
	local citizenid = PropertyFramework.CitizenId(src)

	if not citizenid or PropertyBankHasDebts(citizenid) then
		return false
	end

	local Name,Interior,Mode = Split[1],Split[2],Split[3]
	if RateLimited(src, "buy", 3000) or not ValidateExteriorAction(src, Name, nil)
		or not Informations[Interior] or (Mode ~= "Dollar" and Mode ~= "Gemstone") then
		return false
	end
	if not AcquirePropertyLock(Name, src) then return false end

	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })

	if Consult then
		ReleasePropertyLock(Name, src)
		return false
	end

	SafeClientEvent("propertys:menu:close",src)

	if not PropertyFramework.Request(src,"Propriedades","Deseja comprar a propriedade?") then
		ReleasePropertyLock(Name, src)
		return false
	end

	local Payment = false
	if Mode == "Dollar" then
		Payment = PropertyFramework.PaymentFull(citizenid,Informations[Interior].Price)
	elseif Mode == "Gemstone" then
		Payment = PropertyFramework.PaymentGems(citizenid,Informations[Interior].Gemstone)
	end

	if not Payment then
		ReleasePropertyLock(Name, src)
		SafeClientEvent("Notify",src,"Propriedades",Mode == "Dollar" and "Dinheiro insuficiente." or "Diamante insuficiente.","amarelo",10000)
		return false
	end

	Lock[Name] = true
	Saved[Name] = Interior
	local Serial = PropertysSerials()

	local inserted = PropertyFramework.Query("propertys/Buy",{
		Name = Name,
		Interior = Interior,
		citizenid = citizenid,
		Serial = Serial,
		Vault = Informations[Interior].Vault or 0,
		Fridge = Informations[Interior].Fridge or 0
	})
	if not inserted then
		PropertyFramework.RefundPayment(citizenid, Mode, Mode == "Dollar" and Informations[Interior].Price or Informations[Interior].Gemstone)
		ReleasePropertyLock(Name, src)
		NotifyPlayer(src, "A propriedade acabou de ser adquirida por outra pessoa.")
		return false
	end

	PropertyFramework.GiveItem(citizenid,"propertys-"..Serial,3,true)
	if Mode == "Dollar" then
		PropertyBankAddTax(citizenid, src, Informations[Interior].Price)
	end
	Markers[Name] = true
	ReleasePropertyLock(Name, src)
	SafeClientEvent("Notify",src,"Propriedades","Compra concluída.","verde",10000)

	local HasAccess = PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) <= 0
	SafeClientEvent("propertys:HotelAccess",src,HasAccess)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:LOCK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Lock")
AddEventHandler("propertys:Lock",function(Name)
	local src = source
	if RateLimited(src, "lock") or not ValidateExteriorAction(src, Name, false) then return false end
	local citizenid = PropertyFramework.CitizenId(src)
	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })

	if not (citizenid and Consult) then
		return false
	end

	if Consult.citizenid ~= citizenid and not PropertyFramework.InventoryFull(citizenid,"propertys-"..Consult.Serial) then
		return false
	end

	Lock[Name] = not Lock[Name]

	SafeClientEvent("Notify",src,"Aviso","Propriedade "..(Lock[Name] and "trancada" or "destrancada")..".","default",10000)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:INTERIOR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Interior")
AddEventHandler("propertys:Interior",function(Table)
	local src = source
	local Split = splitString(Table)
	if RateLimited(src, "interior", 2500) or not ValidateExteriorAction(src, Split[1], true) then return false end
	local citizenid = PropertyFramework.CitizenId(src)
	local Name,Interior = Split[1],Split[2]
	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })

	if not citizenid or not Consult or Consult.citizenid ~= citizenid or Consult.Interior == Interior
		or not Informations[Interior] or not Informations[Consult.Interior]
		or Interior == "Galpao" or Informations[Interior].Gemstone <= Informations[Consult.Interior].Gemstone then
		return false
	end

	SafeClientEvent("propertys:menu:close",source)

	local InteriorPrice = Informations[Interior].Gemstone
	local CurrentPrice = Informations[Consult.Interior].Gemstone
	if PropertyFramework.Request(src,"Propriedades","Deseja efetuar a troca do interior atual para o "..Interior.." por "..Dotted(InteriorPrice - CurrentPrice).." diamantes?") then
		if PropertyFramework.PaymentGems(citizenid,InteriorPrice - CurrentPrice) then
			exports.oxmysql:update_async("UPDATE propertys SET Interior = ? WHERE Name = ?",{ Interior,Name })
			SafeClientEvent("Notify",src,"Propriedades","Interior alterado com sucesso.","verde",10000)
			Saved[Name] = Interior
		else
			SafeClientEvent("Notify",src,"Propriedades","Diamantes insuficientes.","amarelo",10000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:SELL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Sell")
AddEventHandler("propertys:Sell", function(Name)
    local src = source

    if RateLimited(src, "sell", 3000) then
        NotifyPlayer(src, "Aguarde antes de tentar vender novamente.")
        return false
    end

    if not ValidateExteriorAction(src, Name, true) then
        NotifyPlayer(src, "Você precisa ser o proprietário e estar próximo da entrada.")
        return false
    end

    local citizenid = PropertyFramework.CitizenId(src)
    if not citizenid then
        NotifyPlayer(src, "Não foi possível identificar o proprietário.")
        return false
    end

    if Active[citizenid] then
        NotifyPlayer(src, "Outra operação da propriedade está em andamento.")
        return false
    end

    Active[citizenid] = true

    local function finish()
        Active[citizenid] = nil
    end

    local Consult = PropertyFramework.SingleQuery("propertys/Exist", { Name = Name })
    if not Consult or tostring(Consult.citizenid) ~= tostring(citizenid) then
        finish()
        NotifyPlayer(src, "Esta propriedade não pertence a você.")
        return false
    end

    local InteriorData = Informations[Consult.Interior]
    local InteriorPrice = InteriorData and tonumber(InteriorData.Price)

    if not InteriorPrice or InteriorPrice <= 0 then
        finish()
        NotifyPlayer(src, "O valor deste interior não está configurado.")
        return false
    end

    local Price = math.floor(InteriorPrice * 0.25)

    SafeClientEvent("propertys:menu:close", src)

    local confirmed = PropertyFramework.Request(
        src,
        "Venda da propriedade",
        "Deseja vender esta propriedade por " .. Currency .. Dotted(Price) .. "? Esta ação é permanente."
    )

    if not confirmed then
        finish()
        return false
    end

    if GetPlayerPing(src) <= 0 then
        finish()
        return false
    end

    if not IsPlayerNearProperty(src, Name, Config.ServerValidationDistance or 7.0) then
        finish()
        NotifyPlayer(src, "Você se afastou da propriedade. A venda foi cancelada.")
        return false
    end

    local deleted = PropertyFramework.DeleteOwnedProperty(Name, citizenid)
    if not deleted then
        finish()
        NotifyPlayer(src, "A propriedade não foi removida do banco de dados.")
        return false
    end

    MySQL.update.await(
        "DELETE FROM propertys_garages WHERE property_name = ?",
        { Name }
    )

    SafeClientEvent("propertys:client:removeGarageZone", src, Name)

    Lock[Name] = nil
    Saved[Name] = nil
    Markers[Name] = nil

    local paid = PropertyFramework.GiveBank(citizenid, Price)
    if not paid then
        print(("^1[propertys] ATENÇÃO: propriedade %s vendida, mas o pagamento de %s para %s falhou.^0")
            :format(Name, tostring(Price), tostring(citizenid)))
        NotifyPlayer(src, "A propriedade foi vendida, mas o pagamento falhou. Avise a administração.")
        finish()
        return false
    end

    PropertyFramework.RemSrvData("Vault:" .. Name)
    PropertyFramework.RemSrvData("Fridge:" .. Name)

    SafeClientEvent("Notify", src, "Propriedades", "Venda concluída. O valor foi depositado no banco.", "verde", 10000)

    Wait(100)

    if GetPlayerPing(src) > 0 then
        local count = tonumber(PropertyFramework.Scalar("propertys/Count", { citizenid = citizenid })) or 0
        SafeClientEvent("propertys:HotelAccess", src, count <= 0)
    end

    finish()
    return true
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Transfer")
AddEventHandler("propertys:Transfer",function(Name)
	if RateLimited(source, "transfer", 3000) or not ValidateExteriorAction(source, Name, true) then return false end
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid or Active[citizenid] then
		return false
	end

	Active[citizenid] = true

	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })
	if not (Consult and Consult.citizenid == citizenid) then
		Active[citizenid] = nil

		return false
	end

	SafeClientEvent("propertys:menu:close",source)

	local Keyboard = PropertyKeyboard.Primary(source,"Citizen ID")
	local Othercitizenid = Keyboard and Keyboard[1]

	if Othercitizenid then Othercitizenid = tostring(Othercitizenid):gsub("^%s+",""):gsub("%s+$","") end
	if not Othercitizenid or Othercitizenid == "" or Othercitizenid == citizenid or not PropertyFramework.Identity(Othercitizenid) then
		NotifyPlayer(source, "Citizen ID inválido.")
	elseif PropertyFramework.Scalar("propertys/Count",{ citizenid = Othercitizenid }) >= (Config.MaxProperties or 3) then
		NotifyPlayer(source, "O destinatário atingiu o limite de propriedades.")
	elseif PropertyFramework.Request(source,"Propriedades","Deseja transferir para o Citizen ID "..Othercitizenid.."?") then
		local changed = PropertyFramework.TransferOwnedProperty(Name, citizenid, Othercitizenid)
		if changed then
			SafeClientEvent("Notify",source,"Propriedades","Transferência concluída.","verde",10000)
		else
			NotifyPlayer(source, "A transferência não pôde ser concluída.")
		end
	end

	Active[citizenid] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CREDENTIALS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Credentials")
AddEventHandler("propertys:Credentials",function(Name)
	local src = source
	if RateLimited(src, "credentials", 2500) or not ValidateExteriorAction(src, Name, true) then return false end
	local citizenid = PropertyFramework.CitizenId(src)
	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })

	if not (citizenid and Consult and Consult.citizenid == citizenid) then
		return false
	end

	SafeClientEvent("propertys:menu:close",src)

	if PropertyFramework.Request(src,"Credenciais","Todos os cartões atuais deixarão de funcionar. Deseja gerar novas credenciais?") then
		if GetPlayerPing(src) <= 0 then return false end

		local Serial = PropertysSerials()
		local updated = PropertyFramework.Update("propertys/Credentials",{ Name = Name, Serial = Serial })
		if not updated or updated < 1 then
			NotifyPlayer(src, "Não foi possível reconfigurar as credenciais.")
			return false
		end

		local amount = math.max(1, tonumber(Consult.Item) or 1)
		local added = PropertyFramework.GiveItem(citizenid,"propertys-"..Serial,amount,true)
		if not added then
			NotifyPlayer(src, "Credenciais atualizadas, mas não couberam no inventário.")
			return false
		end

		SafeClientEvent("Notify",src,"Credenciais","Novos cartões emitidos. Os antigos foram revogados.","verde",8000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Item")
AddEventHandler("propertys:Item",function(Name)
	local src = source
	if RateLimited(src, "item", 2000) or not ValidateExteriorAction(src, Name, true) then return false end
	local citizenid = PropertyFramework.CitizenId(src)
	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })

	if not (citizenid and Consult and Consult.citizenid == citizenid and Consult.Item < 5) then
		return false
	end

	SafeClientEvent("propertys:menu:close",src)

	local currentKeys = tonumber(Consult.Item) or 0
	if currentKeys >= 5 then
		NotifyPlayer(src, "A propriedade já atingiu o limite de 5 cartões.")
		return false
	end

	local Price = 150000
	if PropertyFramework.Request(src,"Cartões","Comprar um cartão adicional por "..Currency..Dotted(Price).."?") then
		if GetPlayerPing(src) <= 0 then return false end

		if PropertyFramework.PaymentFull(citizenid,Price) then
			local updated = PropertyFramework.IncrementKeyIfOwned(Name, citizenid, 5)
			if updated then
				local added = PropertyFramework.GiveItem(citizenid,"propertys-"..Consult.Serial,1,true)
				if added then
					SafeClientEvent("Notify",src,"Cartões","Novo cartão emitido.","verde",7000)
				else
					PropertyFramework.GiveBank(citizenid, Price)
					NotifyPlayer(src, "Inventário cheio. O valor foi devolvido.")
				end
			else
				PropertyFramework.GiveBank(citizenid, Price)
				NotifyPlayer(src, "Não foi possível emitir outro cartão. O valor foi devolvido.")
			end
		else
			SafeClientEvent("Notify",src,"Cartões","Dinheiro insuficiente.","amarelo",7000)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:MORTGAGE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Mortgage")
AddEventHandler("propertys:Mortgage", function(Name)
    local src = source

    if RateLimited(src, "mortgage", 2500) or not ValidateExteriorAction(src, Name, true) then
        return false
    end

    local citizenid = PropertyFramework.CitizenId(src)
    local Consult = PropertyFramework.SingleQuery("propertys/Exist", { Name = Name })

    if not citizenid or not Consult or tostring(Consult.citizenid) ~= tostring(citizenid) then
        NotifyPlayer(src, "Somente o proprietário pode pagar a hipoteca.")
        return false
    end

    local InteriorData = Informations[Consult.Interior]
    if not InteriorData or not tonumber(InteriorData.Price) then
        NotifyPlayer(src, "Não foi possível calcular o valor da hipoteca.")
        return false
    end

    local Price = math.floor(tonumber(InteriorData.Price) * 0.25)
    local CurrentTax = tonumber(Consult.Tax) or 0
    local CurrentTime = os.time()

    local Description
    if CurrentTax > CurrentTime then
        Description = ("A hipoteca ainda possui %s. Deseja renovar por mais 30 dias por %s%s?")
            :format(CompleteTimers(CurrentTax - CurrentTime), Currency, Dotted(Price))
    else
        Description = ("A hipoteca está vencida. Deseja pagar %s%s e renovar por 30 dias?")
            :format(Currency, Dotted(Price))
    end

    SafeClientEvent("propertys:menu:close", src)

    if not PropertyFramework.Request(src, "Hipoteca", Description) then
        return false
    end

    if GetPlayerPing(src) <= 0 then
        return false
    end

    if not PropertyFramework.PaymentFull(citizenid, Price) then
        SafeClientEvent("Notify", src, "Hipoteca", "Dinheiro insuficiente.", "amarelo", 7000)
        return false
    end

    local updated
    if CurrentTax > CurrentTime then
        updated = exports.oxmysql:update_async(
            "UPDATE propertys SET Tax = DATE_ADD(Tax, INTERVAL 30 DAY) WHERE Name = ? AND citizenid = ?",
            { Name, citizenid }
        )
    else
        updated = exports.oxmysql:update_async(
            "UPDATE propertys SET Tax = DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE Name = ? AND citizenid = ?",
            { Name, citizenid }
        )
    end

    if not updated or updated < 1 then
        PropertyFramework.GiveBank(citizenid, Price)
        NotifyPlayer(src, "Não foi possível atualizar a hipoteca. O valor foi devolvido.")
        return false
    end

    SafeClientEvent("Notify", src, "Hipoteca", "Hipoteca renovada por 30 dias.", "verde", 7000)
    return true
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOTHES
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Clothes(source)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid then
		return {}
	end

	CountClothes[citizenid] = 2

	for Permission,Multiplier in pairs({ ["Central Plus"] = 6, ["Central Silver"] = 4, ["Central Basic"] = 2 }) do
		if PropertyFramework.HasBenefit(citizenid,Permission) then
			CountClothes[citizenid] = CountClothes[citizenid] + Multiplier
		end
	end

	local Clothes = {}
	local Consult = PropertyFramework.GetSrvData("Wardrobe:"..citizenid,true)
	for Table in pairs(Consult) do
		table.insert(Clothes,Table)
	end

	return Clothes
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:CLOTHES
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Clothes")
AddEventHandler("propertys:Clothes",function(Mode)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid then
		return false
	end

	local Split = splitString(Mode)
	local Consult = PropertyFramework.GetSrvData("Wardrobe:"..citizenid,true)
	local Action,Name = Split[1],Split[2]

	if Action == "Save" then
		local clothesLimit = CountClothes[citizenid] or 2
		if CountTable(Consult) >= clothesLimit then
			SafeClientEvent("Notify",source,"Armário","Limite atingido de roupas.","amarelo",10000)

			return false
		end

		local Keyboard = PropertyKeyboard.Primary(source,"Nome")
		if Keyboard then
			local Check = sanitizeString(Keyboard[1],"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
			if string.len(Check) >= 4 then
				if not Consult[Check] then
					local appearance = PropertyAppearance.Customization(source)
					if type(appearance) ~= "table" or not next(appearance) then
						SafeClientEvent("Notify",source,"Armário","Não foi possível capturar a roupa atual.","vermelho",10000)
						return false
					end

					Consult[Check] = appearance
					PropertyFramework.SetSrvData("Wardrobe:"..citizenid,Consult,true)
					SafeClientEvent("propertys:menu:addMenu",source,Check,"Informações da vestimenta.",Check,"wardrobe")
					SafeClientEvent("propertys:menu:addButton",source,"Aplicar","Vestir-se com as vestimentas.","propertys:Clothes","Apply-"..Check,Check,true)
					SafeClientEvent("propertys:menu:addButton",source,"Remover","Deletar a vestimenta do armário.","propertys:Clothes","Delete-"..Check,Check,true,true)
				end
			else
				SafeClientEvent("Notify",source,"Armário","Nome escolhido precisa possuir mínimo de 4 letras.","amarelo",10000)
			end
		end
	elseif Action == "Delete" then
		if Consult[Name] then
			Consult[Name] = nil
			PropertyFramework.SetSrvData("Wardrobe:"..citizenid,Consult,true)
		end
	elseif Action == "Apply" then
		if Consult[Name] then
			SafeClientEvent("propertys:client:applyAppearance",source,Consult[Name])
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYSSERIALS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertysSerials()
	local serial, consult
	repeat
		serial = GenerateString("LDLDLDLDLD")
		consult = PropertyFramework.SingleQuery("propertys/Serial",{ Serial = serial })
	until serial and not consult

	return serial
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Permission(source, Name)
	local citizenid = PropertyFramework.CitizenId(source)

	if not citizenid or not ValidPropertyName(Name) or InsideName[citizenid] ~= Name then
		return false
	end

	if Name == "Hotel" then
		return true
	end

	local Consult = PropertyFramework.SingleQuery("propertys/Exist",{ Name = Name })
	if Consult and (PropertyFramework.InventoryFull(citizenid,"propertys-"..Consult.Serial) or Consult.citizenid == citizenid) then
		return true
	end

	return false
end

function PropertyService.OpenStash(source, Name, Mode)
    local citizenid = PropertyFramework.CitizenId(source)
    if not citizenid or not ValidPropertyName(Name) or InsideName[citizenid] ~= Name
        or (Mode ~= "Vault" and Mode ~= "Fridge") then
        return false
    end

    local weight = 25000
    local stashName = Name

    if Name == "Hotel" then
        stashName = ("Hotel:%s"):format(citizenid)
    else
        local consult = PropertyFramework.SingleQuery("propertys/Exist", { Name = Name })
        if not consult then return false end

        local hasAccess = consult.citizenid == citizenid
            or PropertyFramework.InventoryFull(citizenid, "propertys-" .. consult.Serial)

        if not hasAccess then return false end
        weight = math.floor((tonumber(consult[Mode]) or 25) * 1000)
    end

    return PropertyFramework.EnsureStash(("%s:%s"):format(Mode, stashName), 100, weight)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LEGACY INVENTORY RPCS REMOVED
-- Vaults and fridges are handled directly by ox_inventory through PropertyService.OpenStash.
-----------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(citizenid)
	if Inside[citizenid] then
		PropertyFramework.InsidePropertys(citizenid,Inside[citizenid])
		Inside[citizenid] = nil
		InsideName[citizenid] = nil
	end

	CountClothes[citizenid] = nil
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Additional = 1296000
	local CurrentTimer = os.time()
	local Consult = PropertyFramework.Query("propertys/All")
	for _,v in ipairs(Consult) do
		if (v.Tax + Additional) <= CurrentTimer then
			PropertyFramework.RemSrvData("Vault:"..v.Name)
			PropertyFramework.RemSrvData("Fridge:"..v.Name)
			PropertyFramework.Query("propertys/Sell",{ Name = v.Name })

			Wait(100)
		else
			if Propertys[v.Name] then
				Markers[v.Name] = true
				Lock[v.Name] = true
			end
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHARACTERCHOSEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("CharacterChosen",function(citizenid,source)
	local Increments = {}
	if PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) <= 0 then
		table.insert(Increments,Propertys["Hotel"].Coords)
	else
		local Consult = PropertyFramework.Query("propertys/AllUser",{ citizenid = citizenid })
		if Consult and #Consult > 0 then
			for _,v in pairs(Consult) do
				if Propertys[v.Name] then
					table.insert(Increments,Propertys[v.Name].Coords)
				end
			end
		end
	end

	SafeClientEvent("spawn:Increment",source,Increments)

	Wait(1000)

	local HasAccess = PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) <= 0
	SafeClientEvent("propertys:HotelAccess",source,HasAccess)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKERS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.Markers(source)
	return Markers
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MYPROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.MyPropertys(source)
	local citizenid = PropertyFramework.CitizenId(source)
	
	if not citizenid then
		return {}
	end

	local MyPropertys = {}
	local Result = PropertyFramework.Query("propertys/AllUser",{ citizenid = citizenid })
	
	if Result then
		for _,v in pairs(Result) do
			if v.Name and Propertys[v.Name] then
				MyPropertys[v.Name] = true
			end
		end
	end

	return MyPropertys
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKHOTELACCESS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertyService.CheckHotelAccess(source)
	local citizenid = PropertyFramework.CitizenId(source)
	if citizenid then
		local HasAccess = PropertyFramework.Scalar("propertys/Count",{ citizenid = citizenid }) <= 0
		SafeClientEvent("propertys:HotelAccess",source,HasAccess)
	end
end

function PropertyService.OpenGarage(source, Name)
    if not ValidPropertyName(Name) then return false end
    if not IsPlayerNearProperty(source, Name, Config.GarageMaxDistance or 6.0) then return false end
    if not HasPropertyAccess(source, Name, false) then return false end

    local saved = GetSavedGarage(Name)
    if saved then
        return saved
    end

    local configured = Config.PropertyGarages and Config.PropertyGarages[Name]
    if configured and configured.spawn then
        return {
            x = configured.spawn.x,
            y = configured.spawn.y,
            z = configured.spawn.z,
            w = configured.spawn.w or configured.spawn.h or 0.0
        }
    end

    local property = Propertys[Name]
    local offset = Config.GarageFallbackOffset or vec3(4.0, 0.0, 0.0)

    return {
        x = property.Coords.x + offset.x,
        y = property.Coords.y + offset.y,
        z = property.Coords.z + offset.z,
        w = Config.GarageFallbackHeading or 0.0
    }
end

function PropertyService.SaveGarage(source, Name, coords)
    if not ValidPropertyName(Name) or type(coords) ~= "table" then
        return false, "Dados da garagem inválidos."
    end

    local citizenid = PropertyFramework.CitizenId(source)
    if not citizenid then
        return false, "Jogador não identificado."
    end

    local Consult = PropertyFramework.SingleQuery("propertys/Exist", { Name = Name })
    if not Consult or tostring(Consult.citizenid) ~= tostring(citizenid) then
        return false, "Somente o proprietário pode ajustar o spawn."
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    local heading = tonumber(coords.w or coords.heading) or 0.0

    if not x or not y or not z then
        return false, "Coordenadas inválidas."
    end

    local ped = GetPlayerPed(source)
    if ped <= 0 then
        return false, "Ped do jogador inválido."
    end

    local playerCoords = GetEntityCoords(ped)
    local propertyCoords = Propertys[Name].Coords
    local maxDistance = Config.GarageSetupMaxDistance or 45.0

    if #(playerCoords - propertyCoords) > maxDistance then
        return false, ("O spawn deve ficar a no máximo %.0f metros da propriedade."):format(maxDistance)
    end

    if #(playerCoords - vec3(x, y, z)) > 8.0 then
        return false, "A posição enviada está muito distante do jogador."
    end

    local affected = MySQL.update.await([[
        INSERT INTO propertys_garages
            (property_name, x, y, z, heading, updated_by)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading),
            updated_by = VALUES(updated_by)
    ]], {
        Name, x, y, z, heading, citizenid
    })

    if affected == nil then
        return false, "Não foi possível salvar o spawn no banco de dados."
    end

    SafeClientEvent("propertys:client:refreshGarageZone", source, Name)
    return true, "Spawn da garagem salvo."
end

-- Qbox RPC registrations
lib.callback.register("propertys:qbox:Police", function(source, ...)
    return PropertyService.Police(source, ...)
end)
lib.callback.register("propertys:qbox:Propertys", function(source, ...)
    return PropertyService.Propertys(source, ...)
end)
lib.callback.register("propertys:qbox:Toggle", function(source, ...)
    return PropertyService.Toggle(source, ...)
end)
lib.callback.register("propertys:qbox:Clothes", function(source, ...)
    return PropertyService.Clothes(source, ...)
end)
lib.callback.register("propertys:qbox:Permission", function(source, ...)
    return PropertyService.Permission(source, ...)
end)
lib.callback.register("propertys:qbox:OpenStash", function(source, ...)
    return PropertyService.OpenStash(source, ...)
end)
lib.callback.register("propertys:qbox:OpenGarage", function(source, ...)
    return PropertyService.OpenGarage(source, ...)
end)

lib.callback.register("propertys:qbox:SaveGarage", function(source, ...)
    return PropertyService.SaveGarage(source, ...)
end)
lib.callback.register("propertys:qbox:Markers", function(source, ...)
    return PropertyService.Markers(source, ...)
end)
lib.callback.register("propertys:qbox:MyPropertys", function(source, ...)
    return PropertyService.MyPropertys(source, ...)
end)
lib.callback.register("propertys:qbox:CheckHotelAccess", function(source, ...)
    return PropertyService.CheckHotelAccess(source, ...)
end)
