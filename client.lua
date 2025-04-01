local RSGCore = exports['rsg-core']:GetCoreObject()


local function getModelName(vehicle)
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
        -- If model name can't be found, use the hash as string
        modelName = tostring(model)
    end
    
    return modelName
end

-- Helper function to check if a value exists in a table
function table.contains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end


local function showWheelSelectionMenu(callback)
    local options = {
        { value = '0', label = 'Front Left Wheel' },
        { value = '1', label = 'Front Right Wheel' },
    }
    
    local input = lib.inputDialog('Select Wheel', {
        { type = 'select', label = 'Which wheel?', options = options }
    })
    
    if input and input[1] then
        callback(tonumber(input[1]))
    else
        -- Handle cancellation gracefully
        RSGCore.Functions.Notify("Wheel selection cancelled", "error")
    end
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerPed = PlayerPedId()
        
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
                -- Player is driving this vehicle
                local modelName = getModelName(vehicle)
                
                -- Register this wagon with the server
                TriggerEvent('rsg-wagon:registerWithServer', vehicle)
                
                -- Mark this wagon as "out" in the database
                --TriggerServerEvent('rsg-wagon:markWagonOut', modelName)
            end
        end
    end
end)


Citizen.CreateThread(function()
    while not exports['ox_target'] do
        Citizen.Wait(500)
    end
    
    local wagonInteractions = {
        {
            name = 'detach_wheel',
            label = 'Detach Wheel',
            icon = 'fa-solid fa-circle-minus',
            onSelect = function(data)
                TriggerEvent('rsg-wagon:detachWheelMenu', data.entity)
            end,
            canInteract = function(entity)
                -- Allow all players to interact if the entity is a vehicle
                return DoesEntityExist(entity) and IsEntityAVehicle(entity)
            end
        },
        {
            name = 'repair_wagon',
            label = 'Repair Wagon',
            icon = 'fa-solid fa-wrench',
            onSelect = function(data)
                TriggerEvent('rsg-wagon:repair', data.entity)
            end,
            canInteract = function(entity)
                return DoesEntityExist(entity) and IsEntityAVehicle(entity)
            end
        },
        {
            name = 'toggle_lock_wagon',
            label = 'Toggle Lock',
            icon = 'fa-solid fa-lock',
            onSelect = function(data)
                TriggerEvent('rsg-wagon:toggleLock', data.entity)
            end,
            canInteract = function(entity)
                return DoesEntityExist(entity) and IsEntityAVehicle(entity)
            end
        }
    }
    
    
    if Config.TargetAllVehicles then
        exports['ox_target']:addGlobalVehicle(wagonInteractions)
    else
        exports['ox_target']:addModel(Config.WagonModels, wagonInteractions)
    end
end)





RegisterNetEvent('rsg-wagon:detachWheelMenu')
AddEventHandler('rsg-wagon:detachWheelMenu', function(vehicle)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        RSGCore.Functions.Notify("Invalid wagon", "error")
        return
    end
    
    
    
    showWheelSelectionMenu(function(wheelIndex)
        TriggerEvent('rsg-wagon:detachWheel', vehicle, wheelIndex)
    end)
end)




RegisterNetEvent('rsg-wagon:detachWheel')
AddEventHandler('rsg-wagon:detachWheel', function(vehicle, wheelIndex)
    local playerPed = PlayerPedId()

    -- Start animation before progress bar
    TaskStartScenarioInPlace(playerPed, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 0, true, false, false, false)

    -- Using ox_lib progressbar
    if lib.progressBar({
        duration = 3000,
        label = 'Detaching Wheel',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
    }) then
        
        local vehicleCoords = GetEntityCoords(vehicle)
        local vehicleHeading = GetEntityHeading(vehicle)
        
        
        local wheelOffset = {x = 0, y = 0, z = 0}
        if wheelIndex == 0 then -- Front Left
            -- Adjust these values based on testing
            wheelOffset = {x = -1.0, y = 1.5, z = -0.5}
        elseif wheelIndex == 1 then -- Front Right
            wheelOffset = {x = 1.0, y = 1.5, z = -0.5}
        end
        
        
        local rad = math.rad(vehicleHeading)
        local rotatedX = wheelOffset.x * math.cos(rad) - wheelOffset.y * math.sin(rad)
        local rotatedY = wheelOffset.x * math.sin(rad) + wheelOffset.y * math.cos(rad)
        
        local expectedWheelPos = vector3(
            vehicleCoords.x + rotatedX,
            vehicleCoords.y + rotatedY,
            vehicleCoords.z + wheelOffset.z
        )
        
        
        Citizen.InvokeNative(0xD4F5EFB55769D272, vehicle, wheelIndex)
        
        
        Citizen.Wait(1000)
        
       
        local wheelDeleted = false
        
       
        local radius = 5.0
        local objects = GetGamePool('CObject')
        for _, object in ipairs(objects) do
            local objCoords = GetEntityCoords(object)
            local distance = #(objCoords - expectedWheelPos)
            
            if distance < radius then
                -- Delete the entity and all network references
                NetworkRequestControlOfEntity(object)
                local timeout = 0
                while not NetworkHasControlOfEntity(object) and timeout < 5000 do
                    timeout = timeout + 100
                    Wait(100)
                end
                
                if NetworkHasControlOfEntity(object) then
                    -- Force detach before deleting
                    DetachEntity(object, true, true)
                    SetEntityAsNoLongerNeeded(object)
                    DeleteEntity(object)
                    wheelDeleted = true
                    print("Wheel deleted - Method 1")
                end
            end
        end
        
       
        if not wheelDeleted then
            Citizen.Wait(200)
            local newObjects = GetGamePool('CObject')
            for _, object in ipairs(newObjects) do
                local objCoords = GetEntityCoords(object)
                local distance = #(objCoords - vehicleCoords)
                
                if distance < 10.0 then
                    NetworkRequestControlOfEntity(object)
                    DetachEntity(object, true, true)
                    SetEntityAsNoLongerNeeded(object)
                    DeleteEntity(object)
                    print("Wheel deleted - Method 2")
                    wheelDeleted = true
                end
            end
        end
        
        
        if not wheelDeleted then
            -- This is a last resort approach
            local entityHandle, closestEntity = FindFirstObject()
            local success = true
            
            repeat
                local pos = GetEntityCoords(closestEntity)
                local dist = #(pos - expectedWheelPos)
                
                if dist < 2.0 then
                    NetworkRequestControlOfEntity(closestEntity)
                    DeleteEntity(closestEntity)
                    print("Wheel deleted - Method 3")
                    wheelDeleted = true
                end
                
                success, closestEntity = FindNextObject(entityHandle)
            until not success
            
            EndFindObject(entityHandle)
        end
        
        
        TriggerServerEvent('rsg-wagon:addWheelToInventory', wheelIndex)
        
        if wheelDeleted then
            
			TriggerEvent('rNotify:NotifyLeft', "Nice", "Wheel detached and collected ", "generic_textures", "tick", 4000)
        else
            
        end
    end

    -- Clear player animation tasks after progress
    ClearPedTasks(playerPed)
end)




RegisterNetEvent('rsg-wagon:toggleLock')
AddEventHandler('rsg-wagon:toggleLock', function(vehicle)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        RSGCore.Functions.Notify(Config.Texts.InvalidWagon, "error")
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    
    
    if #(playerCoords - vehicleCoords) > 3.0 then
        
        return
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    
    TriggerServerEvent('rsg-wagon:checkOwnership', netId)
end)

RegisterNetEvent('rsg-wagon:setLockStatus')
AddEventHandler('rsg-wagon:setLockStatus', function(netId, lockStatus)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, lockStatus and 2 or 1) -- 2 means locked, 1 means unlocked
        
        local statusText = lockStatus and "locked" or "unlocked"
        TriggerEvent('rNotify:NotifyLeft', "Vehicle " .. statusText, "successfully", "generic_textures", "tick", 4000)
    end
end)

RegisterNetEvent('rsg-wagon:ownershipResult')
AddEventHandler('rsg-wagon:ownershipResult', function(netId, isOwner)
    if not isOwner then
        TriggerEvent('rNotify:NotifyLeft', "Not Your Wagon", "You can't lock/unlock this wagon", "generic_textures", "tick", 4000)
    end
end)


RegisterNetEvent('rsg-wagon:wagonSpawned')
AddEventHandler('rsg-wagon:wagonSpawned', function(vehicle, modelName)
    TriggerServerEvent('rsg-wagon:markWagonOut', modelName)
end)

RegisterNetEvent('rsg-wagon:registerWithServer')
AddEventHandler('rsg-wagon:registerWithServer', function(vehicle)
    if DoesEntityExist(vehicle) then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local modelName = getModelName(vehicle)
        TriggerServerEvent('rsg-wagon:registerSpawnedWagon', netId, modelName)
    end
end)




RegisterNetEvent('rsg-wagon:repair')
AddEventHandler('rsg-wagon:repair', function(wagon)
    if not wagon or not DoesEntityExist(wagon) or not IsEntityAVehicle(wagon) then
        RSGCore.Functions.Notify(Config.Texts.InvalidWagon, "error")
        return
    end
    
    TriggerServerEvent('rsg-wagon:checkRepairRequirements', wagon)
end)

RegisterNetEvent('rsg-wagon:startRepair')
AddEventHandler('rsg-wagon:startRepair', function(wagon)
    local playerPed = PlayerPedId() -- Define playerPed

    -- Using ox_lib progressbar with animation
    if lib.progressBar({
        duration = Config.RepairTime,
        label = Config.Texts.Repairing,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = "script_rc@cldn@ig@rsc2_ig1_questionshopkeeper",
            clip = "inspectfloor_player"
        },
    }) then
        
        

        
        TriggerServerEvent('rsg-wagon:finishRepair', wagon)
		TriggerServerEvent('rsg-wagon:removeWheelFromInventory')
    end

    
    ClearPedTasks(playerPed)
end)


RegisterNetEvent('rsg-wagon:completeRepair')
AddEventHandler('rsg-wagon:completeRepair', function(wagon)
    if DoesEntityExist(wagon) and IsEntityAVehicle(wagon) then
        local bodyHealth = GetVehicleBodyHealth(wagon)
        if bodyHealth <= 0.0 then
            -- If the vehicle is completely destroyed, replace it
            local coords = GetEntityCoords(wagon)
            local heading = GetEntityHeading(wagon)
            local model = GetEntityModel(wagon)
            local modelName = getModelName(wagon)

            -- Delete the old vehicle
            DeleteEntity(wagon)

            -- Load the model
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(500)
            end

            
            local newVehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
            
            -- Set the new vehicle's properties
            SetVehicleFixed(newVehicle)
            SetVehicleDirtLevel(newVehicle, 0.0)
            SetVehicleBodyHealth(newVehicle, 1000.0)
            SetVehicleEngineHealth(newVehicle, 1000.0)
            SetVehiclePetrolTankHealth(newVehicle, 1000.0)
            SetVehicleLights(newVehicle, 0)
            SetVehicleEngineOn(newVehicle, true, true)

           
            SetVehicleDoorsLocked(newVehicle, 1) -- 1 means unlocked
            
           
            Entity(newVehicle).state:set('locked', false, true)
            
           
           -- TriggerServerEvent('rsg-wagon:markWagonOut', modelName)
            
            RSGCore.Functions.Notify(Config.Texts.ReplaceSuccess, "success")
        else
            -- If the vehicle is not completely destroyed, just repair it
            SetVehicleFixed(wagon)
            SetVehicleDirtLevel(wagon, 0.0)
            SetVehicleBodyHealth(wagon, 1000.0)
            SetVehicleEngineHealth(wagon, 1000.0)
            SetVehiclePetrolTankHealth(wagon, 1000.0)
            SetVehicleLights(wagon, 0)
            SetVehicleEngineOn(wagon, true, true)

            -- Unlock the vehicle
            SetVehicleDoorsLocked(wagon, 1) -- 1 means unlocked
            
            -- Make sure the vehicle is not locked in the state
            Entity(wagon).state:set('locked', false, true)

            TriggerEvent('rNotify:NotifyLeft', "Repair was a ", "success", "generic_textures", "tick", 4000)
        end
    else
        TriggerEvent('rNotify:NotifyLeft', "Repair was a ", "success", "generic_textures", "tick", 4000)
    end
end)
