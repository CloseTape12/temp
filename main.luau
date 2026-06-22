-- Читаем конфигурацию из глобальной таблицы
local config = getgenv().GAG_AutoFarm_Config

if not config then
    warn("❌ Конфигурация не найдена! Убедись, что ты запустил config.lua перед этим скриптом.")
    return
end

-- ==========================================
-- 0. СТАБИЛЬНАЯ ОПТИМИЗАЦИЯ ИГРЫ
-- ==========================================
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if config.FPS_CAP then
    if setfpscap then
        pcall(setfpscap, config.FPS_CAP)
        print("🎬 Лимит FPS установлен на: " .. config.FPS_CAP)
    end
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
            if plot.Name ~= "Plot1" then
                pcall(function() plot.Parent = nil end)
            end
        end
        gardens.ChildAdded:Connect(function(plot)
            if plot.Name ~= "Plot1" then
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

print("⚡ Оптимизация применена (стабильная версия)!")

if not config["Buy Seed"]["Enable"] and not config["Plant Seed"]["Enable"] and not (config["Buy Gear"] and config["Buy Gear"]["Enable"]) then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))

local PurchaseSeed = Packet("PurchaseSeed")
local PlantSeed = Packet("PlantSeed")
local SellAll = Packet("SellAll")
local UseShovel = Packet("UseShovel")
local CollectFruit = Packet("CollectFruit")
-- Если покупка гира не работает, измени "PurchaseGear" на правильное имя пакета (например, "BuyGear")
local PurchaseGear = Packet("PurchaseGear") 

-- ==========================================
-- 1. ТЕЛЕПОРТ В НАЧАЛО СКРИПТА
-- ==========================================
local function teleportToStart()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    
    local targetPart = Workspace:WaitForChild("Gardens"):WaitForChild("Plot1"):WaitForChild("Visual"):WaitForChild("PRIM")
    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
    print("📍 Телепорт к Plot1 выполнен!")
end

teleportToStart()

-- ==========================================
-- 2. НАСТРОЙКА СЕТКИ И ПЕРЕМЕННЫЕ
-- ==========================================
local CORNER_1 = config.CORNER_1
local CORNER_2 = config.CORNER_2
local SPACING = config.SPACING or 0.1

local startX = math.min(CORNER_1.X, CORNER_2.X)
local endX = math.max(CORNER_1.X, CORNER_2.X)
local startZ = math.min(CORNER_1.Z, CORNER_2.Z)
local endZ = math.max(CORNER_1.Z, CORNER_2.Z)
local targetY = CORNER_1.Y 

local MAX_COLS = math.floor((endZ - startZ) / SPACING) + 1
local MAX_ROWS = math.floor((endX - startX) / SPACING) + 1

local currentX = startX
local currentZ = startZ
local colCount = 0
local rowCount = 0

local dynamicBlacklist = {}

local function advanceGrid()
    currentZ = currentZ + SPACING
    colCount = colCount + 1
    if colCount >= MAX_COLS then
        colCount = 0
        currentZ = startZ
        currentX = currentX + SPACING
        rowCount = rowCount + 1
        if rowCount >= MAX_ROWS then
            rowCount = 0
            currentX = startX
            print("♻️ Зона посадки заполнена. Начинаем заново.")
        end
    end
end

local function isPositionOccupied(pos)
    local plot1 = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild("Plot1")
    local plantsFolder = plot1 and plot1:FindFirstChild("Plants")
    if not plantsFolder then return false end

    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local plantPos = plant:GetPivot().Position
        if math.abs(plantPos.X - pos.X) < (SPACING / 2) and math.abs(plantPos.Z - pos.Z) < (SPACING / 2) then
            return true
        end
    end
    return false
end

local function getNextPlantPosition()
    local pos = Vector3.new(currentX, targetY, currentZ)
    local skips = 0
    while isPositionOccupied(pos) and skips < 100 do
        skips += 1
        advanceGrid()
        pos = Vector3.new(currentX, targetY, currentZ)
    end
    advanceGrid()
    return pos
end

local buyList = (config["Buy Seed"] and config["Buy Seed"]["Seed"]) or {}
local plantList = (config["Plant Seed"] and config["Plant Seed"]["Seed"]) or {}
local buyGearList = (config["Buy Gear"] and config["Buy Gear"]["Gear"]) or {}
local totalPurchased = 0
local totalPlanted = 0

-- ==========================================
-- 3. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
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

local function getFruitCount()
    local success, result = pcall(function()
        return LocalPlayer.PlayerGui.BackpackGui.Backpack.Inventory.FruitInventory.Text
    end)
    if success and result then
        local countStr = string.match(result, "(%d+)")
        if countStr then return tonumber(countStr) end
    end
    return 0
end

local function getCoins()
    local success, result = pcall(function()
        local goal = LocalPlayer.PlayerGui.HUD.Currencies.CoinsCounter.Goal
        if goal and goal:IsA("ValueBase") then
            return goal.Value
        end
    end)
    return success and result or 0
end

local function getActiveFruits()
    local fruits = {}
    local plot1 = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild("Plot1")
    local plantsFolder = plot1 and plot1:FindFirstChild("Plants")
    
    if not plantsFolder then return fruits end

    for _, obj in ipairs(plantsFolder:GetDescendants()) do
        if obj.Name == "HarvestPrompt" and obj:IsA("ProximityPrompt") and obj.Enabled then
            local harvestPart = obj.Parent
            if harvestPart then
                local fruit = harvestPart.Parent
                if fruit then
                    table.insert(fruits, fruit)
                end
            end
        end
    end
    return fruits
end

local function parseFruitUUIDs(fruitName)
    local parts = {}
    for part in string.gmatch(fruitName, "[^_]+") do
        table.insert(parts, part)
    end
    return parts[2], parts[3] or ""
end

-- ==========================================
-- 4. ПАРАЛЛЕЛЬНЫЕ ПРОЦЕССЫ
-- ==========================================

-- ПРОЦЕСС 1: ПОСАДКА
task.spawn(function()
    if not (config["Plant Seed"] and config["Plant Seed"]["Enable"]) then return end
    print("🌱 Авто-посадка запущена...")
    while true do
        local seeds = getInventorySeeds()
        for _, seedData in ipairs(seeds) do
            if plantList[seedData.name] == true and not dynamicBlacklist[seedData.name] then
                for i = 1, seedData.count do
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
                    PlantSeed:Fire(pos, seedData.name, seedData.tool)
                    totalPlanted = totalPlanted + 1
                    task.wait(0.3)
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
                    if buyList[seedName] == true then
                        local mainFrame = seedFrame:FindFirstChild("Main_Frame")
                        if mainFrame then
                            local stockText = mainFrame:FindFirstChild("Stock_Text")
                            if stockText and stockText:IsA("TextLabel") then
                                local qty = tonumber(string.match(stockText.Text, "x(%d+)")) or 0
                                if qty > 0 then
                                    for i = 1, qty do
                                        PurchaseSeed:Fire(seedName)
                                        totalPurchased = totalPurchased + 1
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

-- ПРОЦЕСС 3: АВТО-ПРОДАЖА
task.spawn(function()
    print("💰 Авто-продажа запущена...")
    local lastSellTime = 0
    while true do
        local fruitCount = getFruitCount()
        local currentTime = os.clock()
        
        if fruitCount >= 100 then
            print("🚨 Инвентарь заполнен. Экстренная продажа!")
            SellAll:Fire()
            task.wait(0.5) 
        elseif fruitCount > 0 and (currentTime - lastSellTime >= 5) then
            print("💰 Периодическая продажа...")
            SellAll:Fire()
            lastSellTime = currentTime
            task.wait(1)
        else
            task.wait(1)
        end
    end
end)

-- ПРОЦЕСС 4: ДИНАМИЧЕСКОЕ УДАЛЕНИЕ ПО БАЛАНСУ
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

        local plot1 = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild("Plot1")
        local plantsFolder = plot1 and plot1:FindFirstChild("Plants")
        
        if plantsFolder then
            for _, plant in ipairs(plantsFolder:GetChildren()) do
                local seedName = plant:GetAttribute("SeedName")
                if not seedName then
                    local val = plant:FindFirstChild("SeedName")
                    if val and val:IsA("StringValue") then seedName = val.Value end
                end

                if seedName and dynamicBlacklist[seedName] then
                    local shovel = equipShovel()
                    if shovel then
                        local parts = {}
                        for part in string.gmatch(plant.Name, "[^_]+") do
                            table.insert(parts, part)
                        end
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

        if harvested > 0 then
            print("🍎 Собрано плодов: " .. harvested)
        end

        task.wait(1) 
    end
end)

-- НОВЫЙ ПРОЦЕСС 6: ПОКУПКА СНАРЯЖЕНИЯ (GEAR SHOP)
task.spawn(function()
    if not (config["Buy Gear"] and config["Buy Gear"]["Enable"]) then return end

    local function getGearScroller()
        local gearShop = LocalPlayer.PlayerGui:FindFirstChild("GearShop")
        if gearShop then
            local frame = gearShop:FindFirstChild("Frame")
            if frame then
                return frame:FindFirstChild("ScrollingFrame")
            end
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
                                -- Парсим наличие, например "x1 in Stock" -> 1
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
