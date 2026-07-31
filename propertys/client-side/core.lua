-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Blips = {}
local MyBlips = {}
local HotelBlip = nil
local Inside = false
local function SetPropertyInteriorState(propertyName, interiorName)
    LocalPlayer.state:set("insideProperty", propertyName or false, true)
    LocalPlayer.state:set("propertyInterior", interiorName or false, true)
end
	SetPropertyInteriorState(false, false)
local Opened = false
local Policed = false
local Stealing = false
local Interior = false
local RobbedItems = {}

-- A lockpick foi usada pelo fluxo do qbx_houserobbery. Mantemos o evento
-- servidor original do propertys para que todas as validações permaneçam ativas.
RegisterNetEvent("propertys:client:startRobberyFromQbx", function(name)
	if name then
		TriggerServerEvent("propertys:Robbery", name)
	end
end)

local function TeleportToInterior(coords)
    if not coords then
        PropertyNotify("Propriedades", "Interior sem coordenadas configuradas.", "error")
        return false
    end

    local ped = PlayerPedId()
    local destination = vec3(coords.x, coords.y, coords.z)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(destination.x, destination.y, destination.z)
    SetEntityCoordsNoOffset(ped, destination.x, destination.y, destination.z, false, false, false)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(destination.x, destination.y, destination.z)
        Wait(50)
    end

    -- Corrige uma possível queda durante o streaming do interior.
    SetEntityCoordsNoOffset(ped, destination.x, destination.y, destination.z, false, false, false)
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)

    return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSYSTEM
-----------------------------------------------------------------------------------------------------------------------------------------



local InteriorBlips = {}

local function RemoveInteriorBlips()
    for _, blip in pairs(InteriorBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    InteriorBlips = {}
end

local function AddInteriorBlip(coords, sprite, colour, label)
    if not coords then return end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.55)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)

    InteriorBlips[#InteriorBlips + 1] = blip
end

local function CreateInteriorBlips(interiorData)
    RemoveInteriorBlips()

    if not interiorData then return end

    AddInteriorBlip(interiorData.Exit, 40, 0, "Saída")
    AddInteriorBlip(interiorData.Vault, 478, 5, "Baú")
    AddInteriorBlip(interiorData.Fridge, 52, 3, "Geladeira")
    AddInteriorBlip(interiorData.Clothes, 73, 47, "Armário")
end

local function DrawInteractionMarker(coords)
    if not coords then return end

    DrawMarker(
        2,
        coords.x, coords.y, coords.z + 0.20,
        0.0, 0.0, 0.0,
        180.0, 0.0, 0.0,
        0.28, 0.28, 0.28,
        255, 255, 255, 230,
        false, true, 2, false,
        nil, nil, false
    )
end

CreateThread(function()
	while true do
		local Pid = PlayerId()
		local TimeDistance = 999
		local Ped = PlayerPedId()
		if not IsPedInAnyVehicle(Ped) then
			local Coords = GetEntityCoords(Ped)

			if not Inside then
				for Name,v in pairs(Propertys) do
					local Distance = #(Coords - v.Coords)
					
					if Distance <= 3.0 then
						TimeDistance = 1
						DrawInteractionMarker(v.Coords)
					end

					if Distance <= 0.75 then
						if IsControlJustPressed(1,38) then
							PropertyMenu.Reset()
							local Consult = vSERVER.Propertys(Name)

							if Consult then
								if Consult == "Nothing" then
									if not Propertys[Name].Galpao then
										PropertyMenu.AddButton("Invadir","Forçar a fechadura.","propertys:Robbery",Name,false,true)
									end

									for Line,v in pairs(Informations) do
										if (Propertys[Name].Galpao and Line == "Galpao") or (not Propertys[Name].Galpao and Line ~= "Galpao") then
											PropertyMenu.AddMenu(Line,"Informações sobre o interior.",Line)

											if v.Vault then
												PropertyMenu.AddButton("Baú","Total de <yellow>"..v.Vault.."Kg</yellow> no compartimento.","","",Line,false)
											end

											if v.Fridge then
												PropertyMenu.AddButton("Geladeira","Total de <yellow>"..v.Fridge.."Kg</yellow> no compartimento.","","",Line,false)
											end

											PropertyMenu.AddButton("Credenciais","Máximo <yellow>1</yellow> proprietário e <yellow>3</yellow> adicionais.","","",Line,false)
											PropertyMenu.AddButton("Comprar com Dinheiro","Custo de <yellow>"..Currency..Dotted(v.Price).."</yellow>.","propertys:Buy",Name.."-"..Line.."-Dollar",Line,true)
											PropertyMenu.AddButton("Comprar com Diamantes","Custo de <yellow>"..Dotted(v.Gemstone).."</yellow>.","propertys:Buy",Name.."-"..Line.."-Gemstone",Line,true)
										end
									end

									PropertyMenu.Open()
								else
									if Consult ~= "Hotel" then
										Interior = Consult.Interior

										PropertyMenu.AddButton("Entrar","Adentrar a propriedade.","propertys:Enter",Name,false,false)
										PropertyMenu.AddButton("Cartões","Comprar um novo cartão de acesso.","propertys:Item",Name,false,true)
										PropertyMenu.AddButton("Fechadura","Trancar/Destrancar a propriedade.","propertys:Lock",Name,false,true)
										PropertyMenu.AddButton("Credenciais","Reconfigurar os cartões de acesso.","propertys:Credentials",Name,false,true)

										if Interior ~= "Galpao" and Interior ~= "Amber" then
											PropertyMenu.AddMenu("Interior","Trocar interior da propriedade.<br><yellow>O peso do baú permanece o mesmo.</yellow>","interior")

											local Valuation = Informations[Interior].Gemstone
											for Line,v in pairs(Informations) do
												local InteriorValuation = Informations[Line].Gemstone
												if Line ~= "Galpao" and InteriorValuation > Valuation then
													PropertyMenu.AddButton(Line,"Custo de <yellow>"..Dotted(InteriorValuation - Valuation).." diamantes</yellow>.","propertys:Interior",Name.."-"..Line,"interior",true)
												end
											end
										end

										PropertyMenu.AddButton("Garagem","Abrir ou guardar veículo na garagem da propriedade.","propertys:client:garage",Name,false,false)
										PropertyMenu.AddButton("Vender","Se desfazer da propriedade.","propertys:Sell",Name,false,true)
										PropertyMenu.AddButton("Transferência","Mudar proprietário.","propertys:Transfer",Name,false,true)
										PropertyMenu.AddButton("Hipoteca",Consult.Tax,"propertys:Mortgage",Name,false,true)

										PropertyMenu.Open()
									else
										Interior = "Hotel"
										TriggerEvent("propertys:Enter",Name,false)
									end
								end
							else
								if Name == "Hotel" then
									TriggerEvent("Notify","Hotel","Você não possui acesso ao hotel pois já possui propriedade(s).","amarelo",10000)
								elseif not Propertys[Name].Galpao then
									PropertyMenu.AddButton("Invadir","Forçar a fechadura.","propertys:Robbery",Name,false,true)
									PropertyMenu.Open()
								end
							end
						end
					end
				end
			elseif Inside and Interior and Propertys[Inside] and Internal[Interior] then
				SetPlayerBlipPositionThisFrame(Propertys[Inside].Coords.x,Propertys[Inside].Coords.y)

				if Internal[Interior] and Internal[Interior].Exit and Coords.z < (Internal[Interior].Exit.z - 25.0) then
					TeleportToInterior(Internal[Interior].Exit)
				end

				if Internal[Interior] and Internal[Interior].Furniture and Policed and Policed <= GetGameTimer() and (GetPedMovementClipset(Ped) ~= -1155413492 or IsPedSprinting(Ped) or MumbleIsPlayerTalking(Pid)) then
					vSERVER.Police(Propertys[Inside].Coords,Coords)
					Policed = GetGameTimer() + 15000
				end

				if Internal[Interior] and Internal[Interior].Exit then
					if #(Coords - Internal[Interior].Exit) <= 3.0 then
						DrawInteractionMarker(Internal[Interior].Exit)
					end

					if #(Coords - Internal[Interior].Exit) <= 1.0 and IsControlJustPressed(1,38) then
						TeleportToInterior(Propertys[Inside].Coords)
						vSERVER.Toggle(Inside,"Exit")
						Interior = false
						Stealing = false
						Policed = false
						Inside = false
	SetPropertyInteriorState(false, false)
						RobbedItems = {}
					end
				end

				if Interior and Internal[Interior] and Internal[Interior].Vault and not Stealing then
					if #(Coords - Internal[Interior].Vault) <= 3.0 then
						DrawInteractionMarker(Internal[Interior].Vault)
					end

					if #(Coords - Internal[Interior].Vault) <= 1.0 and IsControlJustPressed(1,38) and vSERVER.Permission(Inside) then
						Opened = "Vault"
						local stash = vSERVER.OpenStash(Inside, "Vault")
						if stash then
							exports.ox_inventory:openInventory("stash", stash)
						end
					end
				end

				if Interior and Internal[Interior] and Internal[Interior].Fridge and not Stealing then
					if #(Coords - Internal[Interior].Fridge) <= 3.0 then
						DrawInteractionMarker(Internal[Interior].Fridge)
					end

					if #(Coords - Internal[Interior].Fridge) <= 1.0 and IsControlJustPressed(1,38) and vSERVER.Permission(Inside) then
						Opened = "Fridge"
						local stash = vSERVER.OpenStash(Inside, "Fridge")
						if stash then
							exports.ox_inventory:openInventory("stash", stash)
						end
					end
				end

				if Interior and Internal[Interior] and Internal[Interior].Clothes and not Stealing then
					if #(Coords - Internal[Interior].Clothes) <= 3.0 then
						DrawInteractionMarker(Internal[Interior].Clothes)
					end

					if #(Coords - Internal[Interior].Clothes) <= 1.0 and IsControlJustPressed(1,38) then
						PropertyMenu.Reset()
						PropertyMenu.AddMenu("Armário","Abrir lista com todas as vestimentas.","wardrobe")
						PropertyMenu.AddButton("Shopping","Editar roupas no illenium-clothing.","propertys:client:openAppearance","",false,false)
						PropertyMenu.AddButton("Outfits","Abrir outfits salvos no illenium-clothing.","propertys:client:openOutfits","",false,false)
						PropertyMenu.AddButton("Guardar","Salvar a roupa atual no armário da propriedade.","propertys:Clothes","Save","wardrobe",true)

						local Clothes = vSERVER.Clothes()
						if #Clothes > 0 then
							for Index,v in pairs(Clothes) do
								PropertyMenu.AddMenu(v,"Informações da vestimenta.",Index,"wardrobe")
								PropertyMenu.AddButton("Aplicar","Vestir-se com as vestimentas.","propertys:Clothes","Apply-"..v,Index,true)
								PropertyMenu.AddButton("Remover","Deletar a vestimenta do armário.","propertys:Clothes","Delete-"..v,Index,true,true)
							end
						end

					PropertyMenu.Open()
				end
			end

			if Stealing and Internal[Interior] and Internal[Interior].Furniture and Inside then
				for Number,v in pairs(Internal[Interior].Furniture) do
					local Key = Inside..":"..Number
					if not RobbedItems[Key] then
						if #(Coords - v) <= 3.0 then
							DrawInteractionMarker(v)
						end

						if #(Coords - v) <= 1.0 and IsControlJustPressed(1,38) then
							if Inside then
								TriggerServerEvent("propertys:RobberyItem",tostring(Number),Inside)
							end
						end
					end
				end
			end

			TimeDistance = 1
		end
		end

		Wait(TimeDistance)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:ENTER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:Enter")
AddEventHandler("propertys:Enter",function(Name,Theft)
	if Theft then
		Stealing = true
		Interior = Theft
		Policed = GetGameTimer() + 15000
		RobbedItems = {}
		TriggerEvent("player:Residual","Resquício de Línter")
	end

	SetPropertyInteriorState(Name, Interior)

	local interiorData = Interior and Internal[Interior]
	if not interiorData or not interiorData.Exit then
		PropertyNotify("Propriedades", "O interior selecionado não está configurado.", "error")
		Interior = false
		Stealing = false
		Policed = false
		return
	end

	Inside = Name
	PropertyMenu.Close()
	vSERVER.Toggle(Inside,"Enter")

	if not TeleportToInterior(interiorData.Exit) then
		vSERVER.Toggle(Inside,"Exit")
		Inside = false
	SetPropertyInteriorState(false, false)
		Interior = false
		Stealing = false
		Policed = false
	end
end)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEHOTELBLIP
-----------------------------------------------------------------------------------------------------------------------------------------
function UpdateHotelBlip(HasAccess)
	if HasAccess then
		if not HotelBlip and Propertys["Hotel"] then
			HotelBlip = AddBlipForCoord(Propertys["Hotel"].Coords.x, Propertys["Hotel"].Coords.y, Propertys["Hotel"].Coords.z)
			SetBlipSprite(HotelBlip, 475)
			SetBlipDisplay(HotelBlip, 4)
			SetBlipAsShortRange(HotelBlip, true)
			SetBlipColour(HotelBlip, 26)
			SetBlipScale(HotelBlip, 0.6)
			BeginTextCommandSetBlipName("STRING")
			AddTextComponentSubstringPlayerName("Hotel")
			EndTextCommandSetBlipName(HotelBlip)
		end
	else
		if HotelBlip and DoesBlipExist(HotelBlip) then
			RemoveBlip(HotelBlip)
			HotelBlip = nil
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:HOTELACCESS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:HotelAccess")
AddEventHandler("propertys:HotelAccess",function(HasAccess)
	UpdateHotelBlip(HasAccess)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:BLIPS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:Blips")
AddEventHandler("propertys:Blips",function()
	if next(Blips) ~= nil then
		for _,v in pairs(Blips) do
			if DoesBlipExist(v) then
				RemoveBlip(v)
			end
		end

		TriggerEvent("Notify","Propriedades","Marcações desativadas.","default",10000)
		Blips = {}
	else
		local Markers = vSERVER.Markers()
		for Name,v in pairs(Propertys) do
			if Name ~= "Hotel" then
				Blips[Name] = AddBlipForCoord(v.Coords)

				if v.Galpao then
					SetBlipSprite(Blips[Name],473)
				else
					SetBlipSprite(Blips[Name],374)
				end

				SetBlipScale(Blips[Name],0.5)
				SetBlipAsShortRange(Blips[Name],true)
				SetBlipColour(Blips[Name],Markers[Name] and 35 or 43)
			end
		end

		TriggerEvent("Notify","Propriedades","Marcações ativadas.","default",10000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS:MYBLIPS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("propertys:MyBlips")
AddEventHandler("propertys:MyBlips",function()
	if next(MyBlips) ~= nil then
		for _,v in pairs(MyBlips) do
			if DoesBlipExist(v) then
				RemoveBlip(v)
			end
		end

		TriggerEvent("Notify","Propriedades","Suas residências desativadas.","default",10000)
		MyBlips = {}
	else
		local MyPropertys = vSERVER.MyPropertys()

		if MyPropertys and next(MyPropertys) ~= nil then
			for Name,v in pairs(Propertys) do
				if Name ~= "Hotel" and MyPropertys[Name] then
					MyBlips[Name] = AddBlipForCoord(v.Coords)

					if v.Galpao then
						SetBlipSprite(MyBlips[Name], 473)
						BeginTextCommandSetBlipName("STRING")
						AddTextComponentString("Meu Galpão")
						EndTextCommandSetBlipName(MyBlips[Name])
					else
						SetBlipSprite(MyBlips[Name], 374)
						BeginTextCommandSetBlipName("STRING")
						AddTextComponentString("Minha Residência")
						EndTextCommandSetBlipName(MyBlips[Name])
					end

					SetBlipScale(MyBlips[Name], 0.6)
					SetBlipAsShortRange(MyBlips[Name], false)
					SetBlipColour(MyBlips[Name], 2)
					SetBlipDisplay(MyBlips[Name], 4)
				end
			end

			TriggerEvent("Notify","Propriedades","Suas residências ativadas.","default",10000)
		else
			TriggerEvent("Notify","Propriedades","Você não possui propriedades.","amarelo",10000)
		end
	end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetPropertyInteriorState(false, false)
end)


AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveInteriorBlips()
end)
