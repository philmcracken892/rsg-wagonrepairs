local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedWagons = {}

RegisterNetEvent('rsg-wagon:registerSpawnedWagon')
AddEventHandler('rsg-wagon:registerSpawnedWagon', function(netId, modelName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        local charId = Player.PlayerData.citizenid
        spawnedWagons[netId] = {
            owner = charId,
            model = modelName
        }
        
    end
end)


-- Replace the isWagonOwnedByPlayer function
local function isWagonOwnedByPlayer(model, charId)
    -- Remove the "isOut = 1" requirement completely
    local result = MySQL.Sync.fetchAll('SELECT * FROM kd_wagons WHERE model = ? AND charid = ?', {model, charId})
    
    -- Debug logging to see what's happening
    
    
    if result and #result > 0 then
        for _, wagon in pairs(result) do
            
        end
    else
        
    end
    
    return result and #result > 0
end

-- Update the canAccessWagon function
local function canAccessWagon(src, model)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        
        return false 
    end

    local citizenid = Player.PlayerData.citizenid
    

    
	

    -- Check if the player owns this wagon
    local hasAccess = isWagonOwnedByPlayer(model, citizenid)
   
    return hasAccess
end

RegisterNetEvent('rsg-wagon:checkOwnership')
AddEventHandler('rsg-wagon:checkOwnership', function(netId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if not DoesEntityExist(vehicle) then
        
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        
        return 
    end
    
    local citizenid = Player.PlayerData.citizenid
    local model = GetEntityModel(vehicle)
    local modelName = nil
    
    -- Get the model name from the hash
    for k, v in pairs(Config.WagonModels) do
        if GetHashKey(v) == model then
            modelName = v
            break
        end
    end
    
    if not modelName then
        modelName = tostring(model)
    end
    
    
    
    -- First check in our cache
    local hasAccess = false
    if spawnedWagons[netId] and spawnedWagons[netId].owner == citizenid then
        
        hasAccess = true
    elseif Player.PlayerData.job.name == Config.RepairJob then
       
        hasAccess = true
    else
        -- If not in cache, check database
        hasAccess = isWagonOwnedByPlayer(modelName, citizenid)
        
        if hasAccess then
            -- Add to cache for future checks
            spawnedWagons[netId] = {
                owner = citizenid,
                model = modelName
            }
        end
    end
    
    
    
    if hasAccess then
        -- Toggle the lock status
        local currentLockStatus = Entity(vehicle).state.locked or false
        local newLockStatus = not currentLockStatus
        
        
        
        -- Update the lock status on all clients
        Entity(vehicle).state:set('locked', newLockStatus, true)
        TriggerClientEvent('rsg-wagon:setLockStatus', -1, netId, newLockStatus)
    else
        
        TriggerClientEvent('rsg-wagon:ownershipResult', src, netId, false)
    end
end)



-- Add these to your server.lua file
RegisterNetEvent('rsg-wagon:checkWheelPermission')
AddEventHandler('rsg-wagon:checkWheelPermission', function(vehicle, wheelIndex, isReattach)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    
    
    -- If all checks pass, allow the wheel operation
    if isReattach then
        TriggerClientEvent('rsg-wagon:allowWheelReattach', src, vehicle, wheelIndex)
    else
        TriggerClientEvent('rsg-wagon:allowWheelDetach', src, vehicle, wheelIndex)
    end
end)

RegisterNetEvent('rsg-wagon:checkRepairRequirements')
AddEventHandler('rsg-wagon:checkRepairRequirements', function(wagon)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Removed job requirement check
    
    TriggerClientEvent('rsg-wagon:startRepair', src, wagon)
    TriggerClientEvent('rNotify:NotifyLeft', src, "Repair Started", "Success", "generic_textures", "tick", 4000)
end)



RegisterNetEvent('rsg-wagon:finishRepair')
AddEventHandler('rsg-wagon:finishRepair', function(wagon)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        -- Directly trigger the repair event without checking for the item
        TriggerClientEvent('rsg-wagon:completeRepair', src, wagon)
        TriggerClientEvent('rNotify:NotifyLeft', src, "Wagon repaired successfully!", "success", "generic_textures", "tick", 4000)
    end
end)


-- Modify this to ensure it properly marks wagons as "out"
RegisterNetEvent('rsg-wagon:markWagonOut')
AddEventHandler('rsg-wagon:markWagonOut', function(modelName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        local charId = Player.PlayerData.citizenid
        -- Check if this wagon exists for this player first
        local wagon = MySQL.Sync.fetchAll('SELECT * FROM kd_wagons WHERE model = ? AND charid = ?', {modelName, charId})
        
        if wagon and #wagon > 0 then
            MySQL.Async.execute('UPDATE kd_wagons SET isOut = 1 WHERE model = ? AND charid = ?', {modelName, charId})
           
        else
            
        end
    end
end)

-- Function to mark a wagon as "in" (not out) in the database
RegisterNetEvent('rsg-wagon:markWagonIn')
AddEventHandler('rsg-wagon:markWagonIn', function(modelName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        local charId = Player.PlayerData.citizenid
        MySQL.Async.execute('UPDATE kd_wagons SET isOut = 0 WHERE model = ? AND charid = ?', {modelName, charId})
    end
end)

RegisterServerEvent('rsg-wagon:addWheelToInventory')
AddEventHandler('rsg-wagon:addWheelToInventory', function(wheelIndex)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        -- Add wheel item to inventory
        Player.Functions.AddItem('wagon_wheel', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['wagon_wheel'], "add")
    end
end)

-- Remove wheel from player inventory
RegisterServerEvent('rsg-wagon:removeWheelFromInventory')
AddEventHandler('rsg-wagon:removeWheelFromInventory', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if Player then
        -- Remove wheel item from inventory
        Player.Functions.RemoveItem('wagon_wheel', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['wagon_wheel'], "remove")
    end
end)

-- Callback to check if player has a wheel in inventory
RSGCore.Functions.CreateCallback('rsg-wagon:checkWheelInventory', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    local hasWheel = false
    
    if Player then
        local item = Player.Functions.GetItemByName('wagon_wheel')
        if item and item.amount > 0 then
            hasWheel = true
        end
    end
    
    cb(hasWheel)
end)