-- Читаем конфигурацию из глобальной таблицы
local config = getgenv().GAG_AutoFarm_Config

if not config then
    warn("❌ Конфигурация не найдена! Убедись, что ты запустил config.lua перед этим скриптом.")
    return
end

-- ==========================================
-- 0. ЗАКРЫТИЕ ЗАГРУЗОЧНОГО ЭКРАНА
-- ==========================================
print("⏳ Ожидаю загрузки игры 10 секунд...")
task.wait(10)

local viewportSize = workspace.CurrentCamera.ViewportSize
local randomX = math.random(200, math.max(300, viewportSize.X - 200))
local randomY = math.random(200, math.max(300, viewportSize.Y - 200))

print("🖱️ Кликаю по координатам X:" .. randomX .. " Y:" .. randomY .. " для закрытия загрузочного экрана...")

pcall(function()
    local VIM = game:GetService("VirtualInputManager")
    VIM:SendMouseButtonEvent(randomX, randomY, 0, true, game, 1)
    task.wait(0.1)
    VIM:SendMouseButtonEvent(randomX, randomY, 0, false, game, 1)
end)

if mouse1click then
    pcall(function() mouse1click() end)
end

print("✅ Клик выполнен! Жду 10 секунд для полной прогрузки карты...")
task.wait(10)
print("✅ Ожидание завершено. Запускаю основные процессы...")

-- ==========================================
-- 1. ОПРЕДЕЛЕНИЕ ОГОРОДА И ОПТИМИЗАЦИЯ
-- ==========================================
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MyPlotName = "Plot1"

local function detectPlot()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local gardens = Workspace:WaitForChild("Gardens", 15)
    if not gardens then return end

    local closestPlot = nil
    local shortestDistance = math.huge

    for _, plot in ipairs(gardens:GetChildren()) do
        if plot.Name:match("Plot%d+") then
            local spawnPoint = plot:FindFirstChild("SpawnPoint")
            if spawnPoint then
                local dist = (hrp.Position - spawnPoint.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestPlot = plot.Name
                end
            end
        end
    end
    
    if closestPlot then
        MyPlotName = closestPlot
        print("📍 Игрок заспавнился на огороде: " .. MyPlotName)
    end
end

local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart", 5)
if hrp then
    task.wait(2)
    detectPlot()
end

pcall(function()
    local myPlotFolder = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    if myPlotFolder then
        local cam1 = myPlotFolder:FindFirstChild("LoadingScreenCam")
        local cam2 = myPlotFolder:FindFirstChild("LoadingCam")
        if cam1 then cam1:Destroy() print("🎥 Удалена LoadingScreenCam") end
        if cam2 then cam2:Destroy() print("🎥 Удалена LoadingCam") end
        
        -- Удаление папки Visual для экономии RAM
        local visualFolder = myPlotFolder:FindFirstChild("Visual")
        if visualFolder then
            visualFolder:Destroy()
            print("🗑️ Удалена папка Visual для " .. MyPlotName)
        end
    end
end)

if config.FPS_CAP and setfpscap then
    pcall(setfpscap, config.FPS_CAP)
end

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.Brightness = 0
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.ClockTime = 12

pcall(function()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("SpecialMesh") then
            obj.TextureID = ""
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = false
        elseif obj:IsA("Sound") then
            pcall(function() obj.SoundId = "" end)
            pcall(function() obj:Destroy() end)
        end
    end
    workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("SpecialMesh") then
            obj.TextureID = ""
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = false
        elseif obj:IsA("Sound") then
            pcall(function() obj.SoundId = "" end)
            pcall(function() obj:Destroy() end)
        end
    end)
end)

pcall(function()
    local gardens = Workspace:FindFirstChild("Gardens")
    if gardens then
        for _, plot in ipairs(gardens:GetChildren()) do
            if plot.Name ~= MyPlotName then
                pcall(function() plot.Parent = nil end)
            end
        end
        gardens.ChildAdded:Connect(function(plot)
            if plot.Name ~= MyPlotName then
                pcall(function() plot.Parent = nil end)
            end
        end)
    end
end)

pcall(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            pcall(function() p.Character.Parent = nil end)
        end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            p.CharacterAdded:Connect(function(char)
                pcall(function() char.Parent = nil end)
            end)
        end
    end)
end)

print("⚡ Оптимизация применена! Рабочий огород: " .. MyPlotName)

if not config["Buy Seed"]["Enable"] and not config["Plant Seed"]["Enable"] and not (config["Buy Gear"] and config["Buy Gear"]["Enable"]) and not config["Pets"] then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))

local PurchaseSeed = Packet("PurchaseSeed")
local PlantSeed = Packet("PlantSeed")
local SellAll = Packet("SellAll")
local UseShovel = Packet("UseShovel")
local CollectFruit = Packet("CollectFruit")
local PurchaseGear = Packet("PurchaseGear") 
local WildPetTame = Packet("WildPetTame")
local ToggleFollower = Packet("PetRequestToggleFollower")
local ExpandGarden = Packet("ExpandGarden")

-- ==========================================
-- 3. НАСТРОЙКА СЕТКИ
-- ==========================================
local SPACING = config.SPACING or 1
local GRID_WIDTH = config.GRID_WIDTH or 13
local GRID_DEPTH = config.GRID_DEPTH or 97
local GRID_ROTATION = config.GRID_ROTATION or 0

local primPart = Workspace:WaitForChild("Gardens"):WaitForChild(MyPlotName):WaitForChild("SpawnPoint")
local primCFrame = primPart.CFrame * CFrame.Angles(0, math.rad(GRID_ROTATION), 0)

local startX = -(GRID_WIDTH / 2) + (SPACING / 2)
local endX = (GRID_WIDTH / 2)
local startZ = -(GRID_DEPTH / 2) + (SPACING / 2)
local endZ = (GRID_DEPTH / 2)
local targetY = 0

local MAX_COLS = math.floor((endZ - startZ) / SPACING) + 1
local MAX_ROWS = math.floor((endX - startX) / SPACING) + 1

local currentX = startX
local currentZ = startZ
local colCount = 0
local rowCount = 0

local dynamicBlacklist = {}
local recentlyPlantedCache = {} 

local function advanceGrid()
    currentZ = currentZ + SPACING
    colCount = colCount + 1
    if colCount >= MAX_COLS then
        colCount = 0
        currentZ = startZ
        currentX = currentX - SPACING 
        rowCount = rowCount + 1
        if rowCount >= MAX_ROWS then
            rowCount = 0
            currentX = startX
        end
    end
end

local function isPositionOccupied(worldPos, localX, localZ)
    for _, cachedPos in ipairs(recentlyPlantedCache) do
        if (cachedPos - worldPos).Magnitude < (SPACING * 0.8) then return true end
    end

    local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
    if not plantsFolder then return false end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local plantPos = plant:GetPivot().Position
        local localOffset = primCFrame:ToObjectSpace(CFrame.new(plantPos)).Position
        if math.abs(localOffset.X - localX) < (SPACING / 2) and math.abs(localOffset.Z - localZ) < (SPACING / 2) then
            return true
        end
    end
    return false
end

local function getNextPlantPosition()
    local localX, localZ = currentX, currentZ
    local worldPos = (primCFrame * CFrame.new(localX, targetY, localZ)).Position
    local skips = 0
    
    while isPositionOccupied(worldPos, localX, localZ) and skips < 100 do
        skips += 1
        advanceGrid()
        localX, localZ = currentX, currentZ
        worldPos = (primCFrame * CFrame.new(localX, targetY, localZ)).Position
    end
    advanceGrid()
    
    table.insert(recentlyPlantedCache, worldPos)
    return worldPos
end

local buyList = (config["Buy Seed"] and config["Buy Seed"]["Seed"]) or {}
local plantList = (config["Plant Seed"] and config["Plant Seed"]["Seed"]) or {}
local buyGearList = (config["Buy Gear"] and config["Buy Gear"]["Gear"]) or {}
local petsBuyList = (config["Pets"] and config["Pets"]["ToBuy"]) or {}
local petsEquipList = (config["Pets"] and config["Pets"]["ToEquip"]) or {}

-- ==========================================
-- 4. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================
local function getInventorySeeds()
    local seedsToPlant = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return seedsToPlant end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local mainCat = item:GetAttribute("MainCategory")
            local seedName = item:GetAttribute("SeedTool")
            local count = item:GetAttribute("Count")
            if not mainCat then
                local mcObj = item:FindFirstChild("MainCategory")
                if mcObj and mcObj:IsA("StringValue") then mainCat = mcObj.Value end
            end
            if not seedName then
                local stObj = item:FindFirstChild("SeedTool")
                if stObj and stObj:IsA("StringValue") then seedName = stObj.Value end
            end
            if not count then
                local cObj = item:FindFirstChild("Count")
                if cObj and (cObj:IsA("IntValue") or cObj:IsA("NumberValue")) then count = cObj.Value end
            end
            if mainCat == "Seed" and seedName and count and count > 0 then
                table.insert(seedsToPlant, {tool = item, name = seedName, count = count})
            end
        end
    end
    return seedsToPlant
end

local function getInventorySeedCount(seedName)
    local totalCount = 0
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local mainCat = item:GetAttribute("MainCategory")
            if not mainCat then
                local mcObj = item:FindFirstChild("MainCategory")
                if mcObj and mcObj:IsA("StringValue") then mainCat = mcObj.Value end
            end
            if mainCat == "Seed" then
                local name = item:GetAttribute("SeedTool")
                if not name then
                    local stObj = item:FindFirstChild("SeedTool")
                    if stObj and stObj:IsA("StringValue") then name = stObj.Value end
                end
                if name == seedName then
                    local c = item:GetAttribute("Count")
                    if not c then
                        local cObj = item:FindFirstChild("Count")
                        if cObj and (cObj:IsA("IntValue") or cObj:IsA("NumberValue")) then c = cObj.Value end
                    end
                    totalCount = totalCount + (c or 0)
                end
            end
        end
    end
    return totalCount
end

local function getPlantedCount(seedName)
    local count = 0
    local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
    if not plantsFolder then return 0 end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local sName = plant:GetAttribute("SeedName")
        if not sName then
            local val = plant:FindFirstChild("SeedName")
            if val and val:IsA("StringValue") then sName = val.Value end
        end
        if sName == seedName then
            count = count + 1
        end
    end
    return count
end

local function getCoins()
    local success, result = pcall(function()
        local goal = LocalPlayer.PlayerGui.HUD.Currencies.CoinsCounter.Goal
        if goal and goal:IsA("ValueBase") then return goal.Value end
    end)
    return success and result or 0
end

local function getActiveFruits()
    local fruits = {}
    local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
    if not plantsFolder then return fruits end

    for _, obj in ipairs(plantsFolder:GetDescendants()) do
        if obj.Name == "HarvestPrompt" and obj:IsA("ProximityPrompt") and obj.Enabled then
            local harvestPart = obj.Parent
            if harvestPart then
                local fruit = harvestPart.Parent
                if fruit then table.insert(fruits, fruit) end
            end
        end
    end
    return fruits
end

local function parseFruitUUIDs(fruitName)
    local parts = {}
    for part in string.gmatch(fruitName, "[^_]+") do table.insert(parts, part) end
    return parts[2], parts[3] or ""
end

-- ====== ФИЗИКА И ПОЛЁТ ДЛЯ ПЕТОВ ======
local WALK_SPEED = 16

local function setCharacterCollisions(state)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = state end
    end
end

local function smoothFlyTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    local targetPos = targetCFrame.Position
    local distance = (hrp.Position - targetPos).Magnitude
    if distance <= 5 then return true end

    setCharacterCollisions(false)
    hum.PlatformStand = true
    hum.AutoRotate = false

    local attachment = Instance.new("Attachment")
    attachment.Parent = hrp

    local alignPos = Instance.new("AlignPosition")
    alignPos.Attachment0 = attachment
    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    alignPos.Position = targetPos
    alignPos.MaxForce = 99999999
    alignPos.MaxVelocity = WALK_SPEED
    alignPos.Responsiveness = 50 
    alignPos.Parent = hrp

    local alignOri = Instance.new("AlignOrientation")
    alignOri.Attachment0 = attachment
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.CFrame = CFrame.lookAt(hrp.Position, targetPos)
    alignOri.MaxTorque = 99999999
    alignOri.Responsiveness = 50 
    alignOri.Parent = hrp

    local timeout = tick() + (distance / WALK_SPEED) + 10 

    while (hrp.Position - targetPos).Magnitude > 5 and tick() < timeout do
        alignPos.MaxVelocity = math.max(16, hum.WalkSpeed)
        alignOri.CFrame = CFrame.lookAt(hrp.Position, targetPos)
        task.wait(0.1)
    end

    alignPos:Destroy()
    alignOri:Destroy()
    attachment:Destroy()
    
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- ИСПРАВЛЕНО: Возврат на SpawnPoint вместо PRIM
local function teleportToBaseSmooth()
    local plot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    local spawnPoint = plot and plot:FindFirstChild("SpawnPoint")
    if spawnPoint then
        smoothFlyTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
        end
        setCharacterCollisions(true)
    end
end

local function getOwnedPetCount(petName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local count = 0
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local name = item:GetAttribute("PetName") or item.Name
            if name == petName then count = count + 1 end
        end
    end
    return count
end

local function equipPets()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end
    local equippedCounts = {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local petId = item:GetAttribute("PetId")
            if petId then
                local petName = item:GetAttribute("PetName") or item.Name
                local targetCount = petsEquipList[petName]
                if targetCount then
                    local currentCount = equippedCounts[petName] or 0
                    if currentCount < targetCount then
                        ToggleFollower:Fire(petId)
                        equippedCounts[petName] = currentCount + 1
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end

-- ==========================================
-- 5. ПАРАЛЛЕЛЬНЫЕ ПРОЦЕССЫ
-- ==========================================

-- ПРОЦЕСС 1: ПОСАДКА
task.spawn(function()
    if not (config["Plant Seed"] and config["Plant Seed"]["Enable"]) then return end
    print("🌱 Авто-посадка запущена...")
    while true do
        local seeds = getInventorySeeds()
        for _, seedData in ipairs(seeds) do
            local maxPlants = plantList[seedData.name]
            if maxPlants and maxPlants > 0 and not dynamicBlacklist[seedData.name] then
                local plantedCount = getPlantedCount(seedData.name)
                local canPlant = maxPlants - plantedCount
                
                if canPlant > 0 then
                    for i = 1, math.min(canPlant, seedData.count) do
                        if not seedData.tool or not seedData.tool.Parent then break end
                        local liveCount = 0
                        local cObj = seedData.tool:FindFirstChild("Count")
                        if cObj and (cObj:IsA("IntValue") or cObj:IsA("NumberValue")) then
                            liveCount = cObj.Value
                        else
                            local attr = seedData.tool:GetAttribute("Count")
                            if attr then liveCount = attr end
                        end
                        if liveCount <= 0 then break end

                        local pos = getNextPlantPosition()
                        if pos then
                            PlantSeed:Fire(pos, seedData.name, seedData.tool)
                            task.delay(2, function()
                                for i, cachedPos in ipairs(recentlyPlantedCache) do
                                    if cachedPos == pos then
                                        table.remove(recentlyPlantedCache, i)
                                        break
                                    end
                                end
                            end)
                        end
                        task.wait(0.3)
                    end
                end
            end
        end
        task.wait(2) 
    end
end)

-- ПРОЦЕСС 2: ПОКУПКА СЕМЯН
task.spawn(function()
    if not (config["Buy Seed"] and config["Buy Seed"]["Enable"]) then return end
    local function getNormalShop()
        local seedShop = LocalPlayer.PlayerGui:FindFirstChild("SeedShop")
        if seedShop then
            local frame = seedShop:FindFirstChild("Frame")
            if frame then return frame:FindFirstChild("NormalShop") end
        end
        return nil
    end

    print("🔍 Сканер магазина семян запущен...")
    while true do
        local normalShop = getNormalShop()
        if normalShop then
            for _, seedFrame in ipairs(normalShop:GetChildren()) do
                if seedFrame:IsA("Frame") then 
                    local seedName = seedFrame.Name
                    local maxBuy = buyList[seedName]
                    
                    if maxBuy and maxBuy > 0 and not dynamicBlacklist[seedName] then
                        local currentCount = getInventorySeedCount(seedName)
                        local canBuy = maxBuy - currentCount
                        
                        if canBuy > 0 then
                            local mainFrame = seedFrame:FindFirstChild("Main_Frame")
                            if mainFrame then
                                local stockText = mainFrame:FindFirstChild("Stock_Text")
                                if stockText and stockText:IsA("TextLabel") then
                                    local qtyInShop = tonumber(string.match(stockText.Text, "x(%d+)")) or 0
                                    if qtyInShop > 0 then
                                        local toBuy = math.min(qtyInShop, canBuy)
                                        for i = 1, toBuy do
                                            PurchaseSeed:Fire(seedName)
                                            task.wait(0.2)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(5) 
    end
end)

-- ПРОЦЕСС 3: АВТО-ПРОДАЖА
task.spawn(function()
    print("💰 Авто-продажа запущена...")
    while true do
        pcall(function() SellAll:Fire() end)
        task.wait(5)
    end
end)

-- ПРОЦЕСС 4: ДИНАМИЧЕСКОЕ УДАЛЕНИЕ
task.spawn(function()
    print("🗑️ Система удаления запущена...")
    local function equipShovel()
        local char = LocalPlayer.Character
        if not char then return nil end
        local hum = char:FindFirstChild("Humanoid")
        local shovel = char:FindFirstChild("Shovel")
        if shovel and shovel:IsA("Tool") then return shovel end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack and hum then
            shovel = backpack:FindFirstChild("Shovel")
            if shovel and shovel:IsA("Tool") then
                hum:EquipTool(shovel)
                local start = tick()
                while tick() - start < 3 do
                    if char:FindFirstChild("Shovel") then return shovel end
                    task.wait(0.2)
                end
            end
        end
        return nil
    end

    while true do
        local coins = getCoins()
        dynamicBlacklist = {}
        if config.Blacklist then
            for threshold, seeds in pairs(config.Blacklist) do
                if coins > tonumber(threshold) then
                    for _, seedName in ipairs(seeds) do
                        dynamicBlacklist[seedName] = true
                    end
                end
            end
        end

        local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
        local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
        if plantsFolder then
            local plantedCounts = {}
            for _, plant in ipairs(plantsFolder:GetChildren()) do
                local sName = plant:GetAttribute("SeedName")
                if not sName then
                    local val = plant:FindFirstChild("SeedName")
                    if val and val:IsA("StringValue") then sName = val.Value end
                end
                if sName then
                    plantedCounts[sName] = (plantedCounts[sName] or 0) + 1
                end
            end

            for _, plant in ipairs(plantsFolder:GetChildren()) do
                local seedName = plant:GetAttribute("SeedName")
                if not seedName then
                    local val = plant:FindFirstChild("SeedName")
                    if val and val:IsA("StringValue") then seedName = val.Value end
                end

                local shouldDelete = false
                
                if seedName and dynamicBlacklist[seedName] then
                    shouldDelete = true
                end

                if seedName and plantList[seedName] then
                    local limit = plantList[seedName]
                    if plantedCounts[seedName] > limit then
                        shouldDelete = true
                        plantedCounts[seedName] = plantedCounts[seedName] - 1
                    end
                end

                if shouldDelete then
                    local shovel = equipShovel()
                    if shovel then
                        local parts = {}
                        for part in string.gmatch(plant.Name, "[^_]+") do table.insert(parts, part) end
                        if #parts >= 2 then
                            local plantId = parts[1] .. "_" .. parts[2]
                            UseShovel:Fire(plantId, "", "Shovel", shovel)
                            task.wait(2)
                        end
                    else
                        break
                    end
                end
            end
        end
        task.wait(3) 
    end
end)

-- ПРОЦЕСС 5: АВТО-СБОР ПЛОДОВ
task.spawn(function()
    print("🍎 Авто-сборщик плодов запущен...")
    while true do
        local fruits = getActiveFruits()
        local harvested = 0
        for _, fruit in ipairs(fruits) do
            local plantUUID, fruitUUID = parseFruitUUIDs(fruit.Name)
            if plantUUID then
                CollectFruit:Fire(plantUUID, fruitUUID)
                harvested = harvested + 1
                task.wait(0.1)
            end
        end
        task.wait(1) 
    end
end)

-- ПРОЦЕСС 6: ПОКУПКА СНАРЯЖЕНИЯ
task.spawn(function()
    if not (config["Buy Gear"] and config["Buy Gear"]["Enable"]) then return end
    local function getGearScroller()
        local gearShop = LocalPlayer.PlayerGui:FindFirstChild("GearShop")
        if gearShop then
            local frame = gearShop:FindFirstChild("Frame")
            if frame then return frame:FindFirstChild("ScrollingFrame") end
        end
        return nil
    end

    print("🛠️ Сканер магазина снаряжения запущен...")
    while true do
        local scroller = getGearScroller()
        if scroller then
            for _, gearFrame in ipairs(scroller:GetChildren()) do
                if gearFrame:IsA("Frame") then 
                    local gearName = gearFrame.Name
                    if buyGearList[gearName] == true then
                        local mainFrame = gearFrame:FindFirstChild("Main_Frame")
                        if mainFrame then
                            local stockText = mainFrame:FindFirstChild("Stock_Text")
                            if stockText and stockText:IsA("TextLabel") then
                                local qty = tonumber(string.match(stockText.Text, "x(%d+)")) or 0
                                if qty > 0 then
                                    for i = 1, qty do
                                        PurchaseGear:Fire(gearName)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(5) 
    end
end)

-- ПРОЦЕСС 7: АВТО-ПОКУПКА ПИТОМЦЕВ
task.spawn(function()
    if not config["Pets"] then return end
    print("🐾 Скрипт авто-покупки питомцев запущен...")
    
    local wildPetSpawns = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
    local wildPetRef = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetRef")
    
    if not wildPetSpawns or not wildPetRef then return end

    task.spawn(function()
        task.wait(3)
        equipPets()
    end)

    while true do
        local boughtSomething = false
        for _, petModel in ipairs(wildPetSpawns:GetChildren()) do
            if petModel:IsA("Model") and petModel.Name:find("WildPet_") then
                local petName = petModel.Name:match("WildPet_([^_]+)_WildPet_")
                if petName and petsBuyList[petName] then
                    local maxLimit = petsBuyList[petName]
                    local ownedCount = getOwnedPetCount(petName)
                    if ownedCount >= maxLimit then continue end

                    local rootPart = petModel:FindFirstChild("RootPart")
                    if rootPart then
                        local prompt = rootPart:FindFirstChild("BuyPrompt")
                        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local uuid = petModel.Name:match("([^_]+)$")
                            local petPart = wildPetRef:FindFirstChild("WildPet_" .. uuid)
                            if petPart and petPart:IsA("BasePart") then
                                smoothFlyTo(rootPart.CFrame + Vector3.new(0, 3, 0))
                                task.wait(0.3)
                                WildPetTame:Fire(petPart)
                                task.wait(0.3)
                                teleportToBaseSmooth()
                                boughtSomething = true
                                break
                            end
                        end
                    end
                end
            end
        end
        if boughtSomething then
            task.wait(1)
            equipPets()
        end
        task.wait(2)
    end
end)

-- ПРОЦЕСС 8: ДИНАМИЧЕСКАЯ ПРОКАЧКА ГРЯДКИ
task.spawn(function()
    local upgradeCount = config.UPGRADE_COUNT or 0
    if upgradeCount <= 0 then return end

    -- Функция перевода текста цены (напр. "40M¢") в число
    local function parsePrice(text)
        if not text then return math.huge end
        text = text:gsub("¢", "")
        local mult = 1
        if text:match("K$") then mult = 1000; text = text:gsub("K", "")
        elseif text:match("M$") then mult = 1000000; text = text:gsub("M", "") end
        return tonumber(text) * mult
    end

    local function getCurrentPrice()
        local sign = LocalPlayer.PlayerGui:FindFirstChild("ExpandSignGui")
        if not sign then return nil end
        for _, label in ipairs(sign:GetDescendants()) do
            if label:IsA("TextLabel") then
                local text = label.Text:gsub("%s+", "")
                if text:match("¢$") or text:match("K¢$") or text:match("M¢$") then
                    return text
                end
            end
        end
        return nil
    end

    print("🚜 Динамическая прокачка грядки запущена...")
    local upgradedTimes = 0

    while upgradedTimes < upgradeCount do
        local currentPriceText = getCurrentPrice()
        
        -- Если таблички нет, значит грядка уже максимального уровня
        if not currentPriceText then
            print("🚜 Грядка уже максимального уровня!")
            break
        end

        local priceNum = parsePrice(currentPriceText)
        local coins = getCoins() -- Используем функцию получения баланса из основного скрипта

        if coins >= priceNum then
            -- Денег хватает, покупаем
            pcall(function() ExpandGarden:Fire() end)
            task.wait(1.5) -- Ждем обновления UI
            
            local newPriceText = getCurrentPrice()
            if newPriceText ~= currentPriceText then
                upgradedTimes = upgradedTimes + 1
                print(string.format("🚜 Грядка улучшена! (%d/%d)", upgradedTimes, upgradeCount))
            else
                -- Если цена не изменилась, хоть денег и хватало, возможно сервер тупит. Ждем.
                task.wait(5)
            end
        else
            -- Денег не хватает, ждем 5 секунд и проверяем снова
            task.wait(5)
        end
    end

    print("🚜 Прокачка грядки завершена!")
end)
