-- Читаем конфигурацию из глобальной таблицы
local config = getgenv().GAG_AutoFarm_Config

if not config then
    warn("❌ Конфигурация не найдена! Убедись, что ты запустил config.lua перед этим скриптом.")
    return
end

-- ПРИМЕНЕНИЕ ЛИМИТА FPS
if config.FPS_CAP then
    if setfpscap then
        pcall(setfpscap, config.FPS_CAP)
        print("🎬 Лимит FPS установлен на: " .. config.FPS_CAP)
    else
        warn("⚠️ Ваш эксплойт не поддерживает функцию setfpscap. Лимит FPS не применен.")
    end
end

-- ОПТИМИЗАЦИЯ ИГРЫ (Визуальная)
if config.OPTIMIZE_GAME then
    local Lighting = game:GetService("Lighting")
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
            end
        end)
    end)
    print("⚡ Игра оптимизирована: текстуры, тени и эффекты отключены!")
end

-- ОПТИМИЗАЦИЯ RAM (ОПЕРАТИВНАЯ ПАМЯТЬ)
if config.OPTIMIZE_RAM then
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- 1. Самое легкое освещение (снижает нагрузку на память рендера)
    Lighting.Technology = Enum.Technology.Compatibility

    -- 2. Выгрузка звуков и анимаций из памяти
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") then
                obj.SoundId = ""
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("Animation") then
                obj.AnimationId = ""
            end
        end
        game.DescendantAdded:Connect(function(obj)
            if obj:IsA("Sound") then
                task.wait()
                pcall(function() obj.SoundId = "" obj:Destroy() end)
            elseif obj:IsA("Animation") then
                pcall(function() obj.AnimationId = "" end)
            end
        end)
    end)

    -- 3. УДАЛЕНИЕ ЧУЖИХ ГРЯДОК (Снижает RAM на сотни мегабайт)
    pcall(function()
        local gardens = Workspace:FindFirstChild("Gardens")
        if gardens then
            for _, plot in ipairs(gardens:GetChildren()) do
                if plot.Name ~= "Plot1" then
                    pcall(function() plot.Parent = nil end) -- Выгружаем из памяти
                end
            end
            gardens.ChildAdded:Connect(function(plot)
                if plot.Name ~= "Plot1" then
                    pcall(function() plot.Parent = nil end)
                end
            end)
        end
        
        -- Удаляем мусор с карты (декорации вне грядок)
        for _, obj in ipairs(Workspace:GetChildren()) do
            if not obj:IsA("Camera") and not obj:IsA("Terrain") and obj.Name ~= "Gardens" and obj.Name ~= "Ignore" and obj.Name ~= "Map" then
                -- Можно удалить, если сильно мешает, но лучше оставить, чтобы не сломать физику
                -- pcall(function() obj.Parent = nil end)
            end
        end
    end)

    -- 4. УДАЛЕНИЕ ДРУГИХ ИГРОКОВ (Снижает RAM и нагрузку на сеть)
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

    print("🧠 Оперативная память оптимизирована: чужие грядки, игроки, звуки выгружены!")
end

if not config["Buy Seed"]["Enable"] and not config["Plant Seed"]["Enable"] then return end

local player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Packet = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))

local PurchaseSeed = Packet("PurchaseSeed")
local PlantSeed = Packet("PlantSeed")
local SellAll = Packet("SellAll")
local UseShovel = Packet("UseShovel")
local CollectFruit = Packet("CollectFruit")

-- ==========================================
-- 1. ТЕЛЕПОРТ В НАЧАЛО СКРИПТА
-- ==========================================
local function teleportToStart()
    local character = player.Character or player.CharacterAdded:Wait()
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

-- ОПТИМИЗИРОВАННАЯ ПРОВЕРКА ЗАНЯТОСТИ (Математика вместо Физики)
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
local totalPurchased = 0
local totalPlanted = 0

-- ==========================================
-- 3. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================
local function getInventorySeeds()
    local seedsToPlant = {}
    local backpack = player:FindFirstChild("Backpack")
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
                table.insert(seedsTo
