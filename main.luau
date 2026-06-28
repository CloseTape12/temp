-- Читаем конфигурацию из глобальной таблицы
local config = getgenv().GAG_AutoFarm_Config

if not config then
    warn("❌ Конфигурация не найдена! Убедись, что ты запустил config.lua перед этим скриптом.")
    return
end

-- ==========================================
-- ФИКСИРОВАННЫЕ КООРДИНАТЫ ОГОРОДОВ
-- ==========================================
local PLOT_DATA = {
    ["Plot1"] = {
        C1 = Vector3.new(420.5, 142.35, -180.5),
        C2 = Vector3.new(433.5, 142.35, -83)
    },
    ["Plot2"] = {
        C1 = Vector3.new(406, 142.35, -49),
        C2 = Vector3.new(346.5, 142.35, 29)
    },
    ["Plot3"] = {
        C1 = Vector3.new(303, 142.35, 34),
        C2 = Vector3.new(206.5, 142.35, 47)
    },
    ["Plot4"] = {
        C1 = Vector3.new(172, 142.35, 20),
        C2 = Vector3.new(94, 142.35, -40)
    },
    ["Plot5"] = {
        C1 = Vector3.new(88, 142.35, -83),
        C2 = Vector3.new(76, 142.35, -180.5)
    },
    ["Plot6"] = {
        C1 = Vector3.new(103, 142.35, -215),
        C2 = Vector3.new(163, 142.35, -293)
    },
    ["Plot7"] = {
        C1 = Vector3.new(206, 142.35, -298),
        C2 = Vector3.new(303.5, 142.35, -310)
    },
    ["Plot8"] = {
        C1 = Vector3.new(337.5, 142.35, -284),
        C2 = Vector3.new(416, 142.35, -223.5)
    }
}
-- ==========================================

-- ==========================================
-- 0. ОПРЕДЕЛЕНИЕ ОГОРОДА И ОПТИМИЗАЦИЯ
-- ==========================================
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MyPlotName = "Plot1"

-- 1. Определяем огород игрока
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

-- 2. Лимит FPS
if config.FPS_CAP and setfpscap then
    pcall(setfpscap, config.FPS_CAP)
end

-- 3. Оптимизация освещения
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.Brightness = 0
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.ClockTime = 12

-- 4. Оптимизация визуала
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

-- 5. УДАЛЕНИЕ ЧУЖИХ ОГОРОДОВ
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

-- 6. Удаление других игроков
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

if not config["Buy Seed"]["Enable"] and not config["Plant Seed"]["Enable"] and not (config["Buy Gear"] and config["Buy Gear"]["Enable"]) then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))

local PurchaseSeed = Packet("PurchaseSeed")
local PlantSeed = Packet("PlantSeed")
local SellAll = Packet("SellAll")
local UseShovel = Packet("UseShovel")
local CollectFruit = Packet("CollectFruit")
local PurchaseGear = Packet("PurchaseGear") 

-- ==========================================
-- 1. ТЕЛЕПОРТ В НАЧАЛО СКРИПТА
-- ==========================================
local function teleportToStart()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    
    local targetPart = Workspace:WaitForChild("Gardens"):WaitForChild(MyPlotName):WaitForChild("Visual"):WaitForChild("PRIM")
    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
    print("📍 Телепорт к " .. MyPlotName .. " выполнен!")
end

teleportToStart()

-- ==========================================
-- 2. НАСТРОЙКА СЕТКИ И ПЕРЕМЕННЫЕ
-- ==========================================
local SPACING = config.SPACING or 1
local CORNER_1, CORNER_2

-- Берем фиксированные координаты для текущего огорода
if PLOT_DATA[MyPlotName] then
    CORNER_1 = PLOT_DATA[MyPlotName].C1
    CORNER_2 = PLOT_DATA[MyPlotName].C2
    print("📐 Координаты сетки для " .. MyPlotName .. " загружены: C1=" .. tostring(CORNER_1) .. " C2=" .. tostring(CORNER_2))
else
    warn("⚠️ Координаты для " .. MyPlotName .. " не прописаны в PLOT_DATA! Посадка отключена.")
    CORNER_1 = nil
    CORNER_2 = nil
end

local startX, endX, startZ, endZ, targetY
if CORNER_1 and CORNER_2 then
    startX = math.min(CORNER_1.X, CORNER_2.X)
    endX = math.max(CORNER_1.X, CORNER_2.X)
    startZ = math.min(CORNER_1.Z, CORNER_2.Z)
    endZ = math.max(CORNER_1.Z, CORNER_2.Z)
    targetY = CORNER_1.Y -- Строго твоя высота
end

local MAX_COLS = (endX and startZ) and (math.floor((endZ - startZ) / SPACING) + 1) or 0
local MAX_ROWS = (endX and startX) and (math.floor((endX - startX) / SPACING) + 1) or 0

local currentX = startX or 0
local currentZ = startZ or 0
local colCount = 0
local rowCount = 0

local dynamicBlacklist = {}
local recentlyPlantedCache = {} 

local function advanceGrid()
    if not CORNER_1 then return end
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
    -- 1. Проверяем кэш (защита от рассинхрона)
    for _, cachedPos in ipairs(recentlyPlantedCache) do
        if math.abs(cachedPos.X - pos.X) < (SPACING / 2) and math.abs(cachedPos.Z - pos.Z) < (SPACING / 2) then
            return true
        end
    end

    -- 2. Проверяем реальную папку с растениями
    local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
    local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
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
    if not CORNER_1 then return nil end
    local pos = Vector3.new(currentX, targetY, currentZ)
    local skips = 0
    while isPositionOccupied(pos) and skips < 100 do
        skips += 1
        advanceGrid()
        pos = Vector3.new(currentX, targetY, currentZ)
    end
    advanceGrid()
    
    -- Добавляем позицию в кэш, чтобы не посадить туда снова до отрисовки сервером
    table.insert(recentlyPlantedCache, pos)
    
    return pos
end

local buyList = (config["Buy Seed"] and config["Buy Seed"]["Seed"]) or {}
local plantList = (config["Plant Seed"] and config["Plant Seed"]["Seed"]) or {}
local buyGearList = (config["Buy Gear"] and config["Buy Gear"]["Gear"]) or {}

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

-- ==========================================
-- 4. ПАРАЛЛЕЛЬНЫЕ ПРОЦЕССЫ
-- ==========================================

-- ПРОЦЕСС 1: ПОСАДКА
task.spawn(function()
    if not (config["Plant Seed"] and config["Plant Seed"]["Enable"]) then return end
    if not CORNER_1 then 
        print("❌ Авто-посадка отключена (нет координат для " .. MyPlotName .. ").")
        return 
    end
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
                    if pos then
                        -- ВЫВОД КООРДИНАТ В КОНСОЛЬ ДЛЯ ОТЛАДКИ
                        print(string.format("🌱 Сажаю %s в X:%.2f Y:%.2f Z:%.2f", seedData.name, pos.X, pos.Y, pos.Z))
                        
                        PlantSeed:Fire(pos, seedData.name, seedData.tool)
                        
                        -- Очищаем кэш через 2 секунды, чтобы сервер успел создать объект
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
            SellAll:Fire()
            task.wait(0.5) 
        elseif fruitCount > 0 and (currentTime - lastSellTime >= 5) then
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

        local myPlot = Workspace:FindFirstChild("Gardens") and Workspace.Gardens:FindFirstChild(MyPlotName)
        local plantsFolder = myPlot and myPlot:FindFirstChild("Plants")
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
        if harvested > 0 then print("🍎 Собрано плодов: " .. harvested) end
        task.wait(1) 
    end
end)

-- ПРОЦЕСС 6: ПОКУПКА СНАРЯЖЕНИЯ (GEAR SHOP)
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
