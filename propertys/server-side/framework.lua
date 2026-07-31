
function PropertyBankHasDebts(citizenId)
    if GetResourceState("bank") ~= "started" then return false end
    local okTax, hasTax = pcall(function() return exports.bank:CheckTaxs(citizenId) end)
    local okFine, hasFine = pcall(function() return exports.bank:CheckFines(citizenId) end)
    return (okTax and hasTax) or (okFine and hasFine) or false
end

function PropertyBankAddTax(citizenId, src, amount)
    if GetResourceState("bank") ~= "started" then return end
    pcall(function()
        exports.bank:AddTaxs(citizenId, src, "Propriedades", amount, "Compra de propriedade.", false)
    end)
end

local ox_inventory = exports.ox_inventory
local qbx = exports.qbx_core

-- Never send an ox_lib callback to an invalid or disconnected player.
local function getActivePlayerId(src)
    local playerId = tonumber(src)
    if not playerId or playerId <= 0 or not DoesPlayerExist(tostring(playerId)) then
        return nil
    end

    return playerId
end

local function getPlayerByCitizenId(citizenid)
    for _, src in ipairs(GetPlayers()) do
        local player = qbx:GetPlayer(tonumber(src))
        if player and player.PlayerData.citizenid == tostring(citizenid) then
            return player, tonumber(src)
        end
    end
end

local function playerFromCitizenId(citizenId)
    local player, src = getPlayerByCitizenId(citizenId)
    return player, src
end

PropertyFramework = {}

local registeredStashes = {}

local function getStashLabel(key)
    key = tostring(key or "")

    if key:find("^Vault:") then
        local propertyName = key:match("^Vault:(.+)$") or "Propriedade"
        return ("Baú da propriedade %s"):format(propertyName)
    end

    if key:find("^Fridge:") then
        local propertyName = key:match("^Fridge:(.+)$") or "Propriedade"
        return ("Geladeira da propriedade %s"):format(propertyName)
    end

    return key
end



function PropertyFramework.EnsureStash(key, slots, maxWeight)
    local id = "propertys_" .. tostring(key):gsub("[^%w_]", "_")
    if not registeredStashes[id] then
        exports.ox_inventory:RegisterStash(
            id,
            getStashLabel(key),
            tonumber(slots) or 100,
            tonumber(maxWeight) or 100000,
            false
        )
        registeredStashes[id] = true
    end
    return id
end


function PropertyFramework.CitizenId(src)
    local player = qbx:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

function PropertyFramework.Source(citizenId)
    local _, src = playerFromCitizenId(citizenId)
    return src
end

function PropertyFramework.Identity(citizenId)
    local player = playerFromCitizenId(citizenId)
    if player then
        local info = player.PlayerData.charinfo or {}
        return {
            name = info.firstname,
            name2 = info.lastname,
            phone = info.phone,
            firstname = info.firstname,
            lastname = info.lastname
        }
    end

    local row = MySQL.single.await(
        "SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1",
        { tostring(citizenId) }
    )
    if not row then return nil end

    local info = json.decode(row.charinfo or "{}")
    return {
        name = info.firstname,
        name2 = info.lastname,
        phone = info.phone,
        firstname = info.firstname,
        lastname = info.lastname
    }
end

function PropertyFramework.FullName(citizenId)
    local identity = PropertyFramework.Identity(citizenId)
    if not identity then return tostring(citizenId) end
    return (identity.firstname or identity.name or "").." "..(identity.lastname or identity.name2 or "")
end

function PropertyFramework.HasService(citizenId, jobName)
    local player = playerFromCitizenId(citizenId)
    if not player then return false end
    local job = player.PlayerData.job or {}
    return job.name == string.lower(jobName) or job.name == jobName
end

function PropertyFramework.HasPermission(citizenId, permission)
    local player = playerFromCitizenId(citizenId)
    if not player then return false end
    local job = player.PlayerData.job or {}
    local gang = player.PlayerData.gang or {}
    local normalized = string.lower(permission)
    return string.lower(job.name or "") == normalized
        or string.lower(gang.name or "") == normalized
        or IsPlayerAceAllowed(player.PlayerData.source, permission)
end

function PropertyFramework.HasBenefit(citizenId, benefit)
    local player = playerFromCitizenId(citizenId)
    if not player then return false end

    local ace = Config.BenefitAces and Config.BenefitAces[benefit]
    if ace and IsPlayerAceAllowed(player.PlayerData.source, ace) then
        return true
    end

    local metadata = player.PlayerData.metadata or {}
    local benefits = metadata.propertyBenefits
    return type(benefits) == "table" and benefits[benefit] == true
end

function PropertyFramework.IsPolice(citizenId)
    local player = playerFromCitizenId(citizenId)
    if not player then return false end
    local job = player.PlayerData.job or {}
    return Config.PoliceJobs[job.name] == true
        and (not Config.RequirePoliceDuty or job.onduty == true)
end

function PropertyFramework.CountPolice()
    local count = 0
    for _, src in ipairs(GetPlayers()) do
        local player = qbx:GetPlayer(tonumber(src))
        local job = player and player.PlayerData.job or {}
        if Config.PoliceJobs[job.name] == true
            and (not Config.RequirePoliceDuty or job.onduty == true) then
            count = count + 1
        end
    end
    return count
end

function PropertyFramework.IsNearCoords(src, target, maxDistance)
    local ped = GetPlayerPed(src)
    if ped <= 0 or not target then return false end
    return #(GetEntityCoords(ped) - vector3(target.x, target.y, target.z)) <= (maxDistance or 2.0)
end

function PropertyFramework.ConsultItem(citizenId, item)
    local _, src = playerFromCitizenId(citizenId)
    if not src then return false end

    local parts = splitString(item)
    local itemName = parts[1]
    if itemName == Config.PropertyKeyItem and #parts > 1 then
        local expectedSerial = table.concat(parts, "-", 2)
        local slots = ox_inventory:Search(src, "slots", itemName) or {}
        for _, slot in pairs(slots) do
            if slot.metadata and tostring(slot.metadata.serial or "") == expectedSerial then
                return true
            end
        end
        return false
    end

    return (ox_inventory:GetItemCount(src, itemName) or 0) > 0
end

function PropertyFramework.InventoryFull(citizenId, item)
    return PropertyFramework.ConsultItem(citizenId, item)
end

function PropertyFramework.RemoveItem(citizenId, item, amount)
    local _, src = playerFromCitizenId(citizenId)
    return src and ox_inventory:RemoveItem(src, splitString(item)[1], amount, nil, nil, true) or false
end

function PropertyFramework.TakeItem(citizenId, item, amount, _, slot)
    local _, src = playerFromCitizenId(citizenId)
    return src and ox_inventory:RemoveItem(src, splitString(item)[1], amount, nil, slot, true) or false
end

function PropertyFramework.GiveItem(citizenId, item, amount)
    local _, src = playerFromCitizenId(citizenId)
    if not src then return false end
    local parts = splitString(item)
    local metadata = #parts > 1 and { serial = table.concat(parts, "-", 2) } or nil
    return ox_inventory:AddItem(src, parts[1], amount, metadata)
end

function PropertyFramework.PaymentFull(citizenId, amount)
    local player = playerFromCitizenId(citizenId)
    if not player then return false end
    amount = tonumber(amount) or 0
    if player.PlayerData.money.cash >= amount then
        return player.Functions.RemoveMoney("cash", amount, "property-purchase")
    end
    return player.Functions.RemoveMoney("bank", amount, "property-purchase")
end

function PropertyFramework.GiveBank(citizenId, amount)
    local player = playerFromCitizenId(citizenId)
    return player and player.Functions.AddMoney("bank", tonumber(amount) or 0, "property-sale") or false
end

function PropertyFramework.PaymentGems(citizenId, amount)
    local _, src = playerFromCitizenId(citizenId)
    return src and ox_inventory:RemoveItem(src, Config.GemItem or "gemstone", tonumber(amount) or 0, nil, nil, true) or false
end

function PropertyFramework.Request(src, title, message)
    local playerId = getActivePlayerId(src)
    if not playerId then return false end

    return lib.callback.await("propertys:qbox:confirm", playerId, title, message) == true
end

function PropertyFramework.Task(src, stages)
    local playerId = getActivePlayerId(src)
    if not playerId then return false end

    return lib.callback.await("propertys:qbox:skillcheck", playerId, stages or 3) == true
end

function PropertyFramework.Safecrack(src, stages)
    local playerId = getActivePlayerId(src)
    if not playerId then return false end

    return lib.callback.await("propertys:qbox:skillcheck", playerId, stages or 5) == true
end

PropertyClient = {}
function PropertyClient.playAnim(src, upper, dictAndAnim, loop)
    TriggerClientEvent("propertys:qbox:playAnim", src, upper, dictAndAnim, loop)
end
function PropertyClient.Destroy(src)
    TriggerClientEvent("propertys:qbox:stopAnim", src)
end

PropertyKeyboard = {}
function PropertyKeyboard.Primary(src, label)
    local playerId = getActivePlayerId(src)
    if not playerId then return nil end

    local result = lib.callback.await("propertys:qbox:input", playerId, label)
    return result and { result } or nil
end

PropertyAppearance = {}
function PropertyAppearance.Customization(src)
    local playerId = getActivePlayerId(src)
    if not playerId then return nil end

    return lib.callback.await("propertys:qbox:appearance", playerId)
end


function PropertyFramework.RefundPayment(citizenId, mode, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then return false end
    if mode == "Dollar" then
        return PropertyFramework.GiveBank(citizenId, amount)
    elseif mode == "Gemstone" then
        return PropertyFramework.GiveItem(citizenId, Config.GemItem or "gemstone", amount)
    end
    return false
end

function PropertyFramework.DeleteOwnedProperty(name, citizenId)
    local affected = MySQL.update.await(
        "DELETE FROM propertys WHERE Name = ? AND citizenid = ?",
        { name, tostring(citizenId) }
    )
    return (affected or 0) > 0
end

function PropertyFramework.TransferOwnedProperty(name, currentOwner, newOwner)
    local affected = MySQL.update.await(
        "UPDATE propertys SET citizenid = ? WHERE Name = ? AND citizenid = ?",
        { tostring(newOwner), name, tostring(currentOwner) }
    )
    return (affected or 0) > 0
end

function PropertyFramework.IncrementKeyIfOwned(name, citizenId, maximum)
    local affected = MySQL.update.await(
        "UPDATE propertys SET Item = Item + 1 WHERE Name = ? AND citizenid = ? AND Item < ?",
        { name, tostring(citizenId), tonumber(maximum) or 5 }
    )
    return (affected or 0) > 0
end

local queryMap = {
    ["propertys/Exist"] = "SELECT *, UNIX_TIMESTAMP(Tax) AS Tax FROM propertys WHERE Name = ? LIMIT 1",
    ["propertys/Serial"] = "SELECT *, UNIX_TIMESTAMP(Tax) AS Tax FROM propertys WHERE Serial = ? LIMIT 1",
    ["propertys/Count"] = "SELECT COUNT(*) AS amount FROM propertys WHERE citizenid = ?",
    ["propertys/All"] = "SELECT *, UNIX_TIMESTAMP(Tax) AS Tax FROM propertys",
    ["propertys/AllUser"] = "SELECT *, UNIX_TIMESTAMP(Tax) AS Tax FROM propertys WHERE citizenid = ?"
}

function PropertyFramework.SingleQuery(name, params)
    if name == "propertys/Exist" then return MySQL.single.await(queryMap[name], { params.Name }) end
    if name == "propertys/Serial" then return MySQL.single.await(queryMap[name], { params.Serial }) end
    return nil
end

function PropertyFramework.Scalar(name, params)
    if name == "propertys/Count" then
        return MySQL.scalar.await("SELECT COUNT(*) FROM propertys WHERE citizenid = ?", { tostring(params.citizenid) }) or 0
    end
    return 0
end

function PropertyFramework.Query(name, params)
    params = params or {}
    if name == "propertys/All" then return MySQL.query.await(queryMap[name]) or {} end
    if name == "propertys/AllUser" then
        return MySQL.query.await(queryMap[name], { tostring(params.citizenid) }) or {}
    end
    if name == "propertys/Buy" then
        return MySQL.insert.await([[
            INSERT IGNORE INTO propertys (Name, Interior, citizenid, Serial, Vault, Fridge, Tax, Item)
            VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY), 3)
        ]], { params.Name, params.Interior, tostring(params.citizenid), params.Serial, params.Vault, params.Fridge })
    end
    if name == "propertys/Sell" then
        return MySQL.update.await("DELETE FROM propertys WHERE Name = ?", { params.Name })
    end
    return PropertyFramework.Update(name, params)
end

function PropertyFramework.Update(name, params)
    if name == "propertys/Tax" then
        return MySQL.update.await("UPDATE propertys SET Tax = DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE Name = ?", { params.Name })
    elseif name == "propertys/Transfer" then
        return MySQL.update.await("UPDATE propertys SET citizenid = ? WHERE Name = ?", { tostring(params.citizenid), params.Name })
    elseif name == "propertys/Credentials" then
        return MySQL.update.await("UPDATE propertys SET Serial = ?, Item = 3 WHERE Name = ?", { params.Serial, params.Name })
    elseif name == "propertys/Item" then
        return MySQL.update.await("UPDATE propertys SET Item = Item + 1 WHERE Name = ?", { params.Name })
    elseif name == "propertys/Vault" then
        return MySQL.update.await("UPDATE propertys SET Vault = Vault + ? WHERE Name = ?", { params.Weight, params.Name })
    elseif name == "propertys/Fridge" then
        return MySQL.update.await("UPDATE propertys SET Fridge = Fridge + ? WHERE Name = ?", { params.Weight, params.Name })
    end
    return false
end

-- Legacy server data is persisted as JSON for wardrobe and other lightweight state.
function PropertyFramework.SetSrvData(key, value)
    MySQL.prepare.await([[
        INSERT INTO propertys_data (id, data) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]], { key, json.encode(value or {}) })
end

function PropertyFramework.RemSrvData(key)
    MySQL.update.await("DELETE FROM propertys_data WHERE id = ?", { key })
end

-- ox_inventory-backed inventories.
local function inventoryTable(inventory)
    local items = ox_inventory:GetInventoryItems(inventory) or {}
    local result = {}
    for _, item in pairs(items) do
        result[item.slot] = {
            item = item.name,
            amount = item.count,
            slot = item.slot,
            name = item.label,
            weight = item.weight,
            desc = item.description
        }
    end
    return result
end

function PropertyFramework.Inventory(citizenId)
    local _, src = playerFromCitizenId(citizenId)
    return src and inventoryTable(src) or {}
end

function PropertyFramework.GetWeight(citizenId)
    local _, src = playerFromCitizenId(citizenId)
    local inv = src and ox_inventory:GetInventory(src)
    return inv and inv.weight or 0
end

function PropertyFramework.GetSrvData(key)
    if key:find("^Vault:") or key:find("^Fridge:") then
        local stash = "propertys_"..key:gsub("[^%w_]", "_")
        ox_inventory:RegisterStash(stash, getStashLabel(key), 100, 100000, false)
        return inventoryTable(stash)
    end
    local value = MySQL.scalar.await("SELECT data FROM propertys_data WHERE id = ?", { key })
    return value and json.decode(value) or {}
end

local function stashId(key)
    return PropertyFramework.EnsureStash(key, 100, 100000)
end

function PropertyFramework.StoreChest(citizenId, key, amount, _, slot, target)
    local _, src = playerFromCitizenId(citizenId)
    if not src then return false end
    local item = ox_inventory:GetSlot(src, tonumber(slot))
    if not item then return false end
    amount = math.min(tonumber(amount) or item.count, item.count)
    local removed = ox_inventory:RemoveItem(src, item.name, amount, item.metadata, item.slot, true)
    if not removed then return false end
    local added = ox_inventory:AddItem(stashId(key), item.name, amount, item.metadata, tonumber(target))
    if not added then ox_inventory:AddItem(src, item.name, amount, item.metadata, item.slot) end
    return added and true or false
end

function PropertyFramework.TakeChest(citizenId, key, amount, slot, target)
    local _, src = playerFromCitizenId(citizenId)
    if not src then return false end
    local stash = stashId(key)
    local item = ox_inventory:GetSlot(stash, tonumber(slot))
    if not item then return false end
    amount = math.min(tonumber(amount) or item.count, item.count)
    local removed = ox_inventory:RemoveItem(stash, item.name, amount, item.metadata, item.slot, true)
    if not removed then return false end
    local added = ox_inventory:AddItem(src, item.name, amount, item.metadata, tonumber(target))
    if not added then ox_inventory:AddItem(stash, item.name, amount, item.metadata, item.slot) end
    return added and true or false
end

function PropertyFramework.UpdateChest(_, key, slot, target, amount)
    local stash = stashId(key)
    local item = ox_inventory:GetSlot(stash, tonumber(slot))
    if not item then return false end
    amount = math.min(tonumber(amount) or item.count, item.count)
    if not ox_inventory:RemoveItem(stash, item.name, amount, item.metadata, item.slot, true) then return false end
    return ox_inventory:AddItem(stash, item.name, amount, item.metadata, tonumber(target)) and true or false
end

function PropertyFramework.CleanSlot() return true end
function PropertyFramework.CleanSlotChest() return true end
function PropertyFramework.PopulateRobberyStash(key, lootTable, rolls, isLocker)
    local stash = PropertyFramework.EnsureStash(
        key,
        Config.RobberyStashSlots or 100,
        isLocker and (Config.LockerStashWeight or 675000) or (Config.RobberyStashWeight or 775000)
    )

    local availableItems = ox_inventory:Items() or {}
    local added = 0
    local attempts = math.max(1, tonumber(rolls) or 1)

    for _ = 1, attempts do
        local candidates = {}
        for _, entry in ipairs(lootTable or {}) do
            if availableItems[entry.Item] and math.random(1000) <= (tonumber(entry.Chance) or 0) then
                candidates[#candidates + 1] = entry
            end
        end

        local selected = candidates[math.random(#candidates > 0 and #candidates or 1)]
        if selected then
            local amount = math.random(tonumber(selected.Min) or 1, tonumber(selected.Max) or 1)
            if amount > 0 and ox_inventory:AddItem(stash, selected.Item, amount) then
                added = added + 1
            end
        end
    end

    return added > 0
end

function PropertyFramework.MountContainer(citizenId, key, lootTable, rolls, _, weight)
    return PropertyFramework.PopulateRobberyStash(key, lootTable, rolls, weight == 675)
end
function PropertyFramework.InsidePropertys() return true end

AddEventHandler("playerDropped", function()
    local citizenId = PropertyFramework.CitizenId(source)
    if citizenId then TriggerEvent("Disconnect", citizenId) end
end)


CreateThread(function()
    Wait(1000)
    local items = ox_inventory:Items() or {}
    for _, itemName in ipairs({
        Config.PropertyKeyItem or "propertys",
        Config.LockpickItem or "lockpick",
        Config.GemItem or "gemstone"
    }) do
        if not items[itemName] then
            print(("[propertys] AVISO: item '%s' não está cadastrado no ox_inventory."):format(itemName))
        end
    end
end)
