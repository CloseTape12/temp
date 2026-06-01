-- ================================================================
--  SLIMES — ОБЪЕДИНЁННЫЙ СКРИПТ
--  Модули:  [1] Авто-лутер
--           [2] Килл-аура
--           [3] Авто-покупка локаций
--
--  Все три модуля работают параллельно через task.spawn
-- ================================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── Общий путь до всех ремотов (объявляем один раз) ────────────
local Remotes = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")
    :WaitForChild("_remotes")

local LootRemote     = Remotes:WaitForChild("LootService")    :WaitForChild("RemoteFunction")
local SlimeGunRemote = Remotes:WaitForChild("SlimeGunService"):WaitForChild("RemoteFunction")
local ZonesRemote    = Remotes:WaitForChild("ZonesService")   :WaitForChild("RemoteFunction")

-- ── Папка с лутом (нужна только первому модулю) ─────────────────
local LootFolder = Workspace:WaitForChild("Loot")

print("🚀 Все модули запущены!")

-- ================================================================
--  МОДУЛЬ 1 — АВТОлутер
-- ================================================================
task.spawn(function()
    print("[Лутер] Запущен")

    while task.wait(0.1) do
        local lootItems = LootFolder:GetChildren()

        if #lootItems > 0 then
            for _, lootItem in ipairs(lootItems) do
                local lootId = lootItem.Name

                task.spawn(function()
                    pcall(function()
                        LootRemote:InvokeServer("requestCollect", lootId)
                    end)
                end)
            end
        end
    end
end)

-- ================================================================
--  МОДУЛЬ 2 — КИЛЛ-АУРА
-- ================================================================
task.spawn(function()
    print("[Килл-аура] Запущена")

    local currentTarget = nil

    while task.wait(0.1) do
        -- Проверяем, жива ли текущая цель
        if currentTarget and not currentTarget.Parent then
            currentTarget = nil
        end

        -- Ищем нового врага, если цели нет
        if not currentTarget then
            for _, folder in ipairs(Workspace:GetChildren()) do
                if folder:IsA("Folder") and string.find(folder.Name, "Gameplay") then
                    local enemiesFolder = folder:FindFirstChild("Enemies")

                    if enemiesFolder then
                        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
                            currentTarget = enemy
                            break
                        end
                    end

                    if currentTarget then break end
                end
            end
        end

        -- Стреляем в цель
        if currentTarget then
            local enemyId = tonumber(currentTarget.Name)

            if enemyId then
                task.spawn(function()
                    pcall(function()
                        SlimeGunRemote:InvokeServer("tryFireSlimeGun", enemyId)
                    end)
                end)
            else
                currentTarget = nil -- Имя оказалось не числом — сбрасываем
            end
        end
    end
end)

-- ================================================================
--  МОДУЛЬ 3 — АВТО-ПОКУПКА ЛОКАЦИЙ
-- ================================================================
task.spawn(function()
    print("[Локации] Запущен")

    -- ── База данных локаций ─────────────────────────────────────
    local ZonesList = {
        {id = 1,  cost = 0},        {id = 2,  cost = 400},      {id = 3,  cost = 5e3},
        {id = 4,  cost = 5e4},      {id = 5,  cost = 4e5},      {id = 6,  cost = 2e6},
        {id = 7,  cost = 12e6},     {id = 8,  cost = 54e6},     {id = 9,  cost = 216e6},
        {id = 10, cost = 936e6},    {id = 11, cost = 3.8e9},    {id = 12, cost = 15.6e9},
        {id = 13, cost = 75e9},     {id = 14, cost = 250e9},    {id = 15, cost = 1e12},
        {id = 16, cost = 3.5e12},   {id = 17, cost = 11e12},    {id = 18, cost = 31e12},
        {id = 19, cost = 94e12},    {id = 20, cost = 282e12},   {id = 21, cost = 846e12},
        {id = 22, cost = 2.5e15},   {id = 23, cost = 8e15},     {id = 24, cost = 26e15},
        {id = 25, cost = 80e15},    {id = 26, cost = 300e15},   {id = 27, cost = 1e18},
        {id = 28, cost = 3.5e18},   {id = 29, cost = 10e18},    {id = 30, cost = 60e18},
        {id = 31, cost = 250e18},   {id = 32, cost = 1e21},     {id = 33, cost = 4e21},
        {id = 34, cost = 16e21},    {id = 35, cost = 64e21},    {id = 36, cost = 256e21},
        {id = 37, cost = 1.02e24},  {id = 38, cost = 4e24}
    }

    local ZoneNamesToNextIndex = {
        ["Grasslands"]       = 2,  ["Desert"]           = 3,  ["Polar"]          = 4,
        ["Volcano"]          = 5,  ["Islands"]          = 6,  ["Cave"]           = 7,
        ["Heaven"]           = 8,  ["Jungle"]           = 9,  ["Canyon"]         = 10,
        ["Mushroom Forest"]  = 11, ["Moon"]             = 12, ["Redwood Forest"] = 13,
        ["Meteor"]           = 14, ["Candyland"]        = 15, ["Cherry Grove"]   = 16,
        ["Crystal Cavern"]   = 17, ["Pumpkin Patch"]    = 18, ["Atlantis"]       = 19,
        ["River"]            = 20, ["Pyramid"]          = 21, ["Graveyard"]      = 22,
        ["Hot Springs"]      = 23, ["Tribe"]            = 24, ["Toxic Wasteland"]= 25,
        ["Steampunk"]        = 26, ["Winter Wonderland"]= 27, ["Farm"]           = 28,
        ["Jungle Temple"]    = 29, ["Underworld"]       = 30, ["Swamp"]          = 31,
        ["Mushroom Village"] = 32, ["The Void"]         = 33, ["Honeycomb"]      = 34,
        ["Glow Mine"]        = 35, ["Alien Planet"]     = 36, ["Haunted House"]  = 37,
        ["Skull Island"]     = 38, ["Slime Inc."]       = 39
    }

    -- ── Вспомогательные функции ─────────────────────────────────

    -- Парсим текст вида "1.5M", "300K", "26B" и т.д. в число
    local function parseCoins(text)
        if not text then return 0 end
        text = string.gsub(text, ",", "")
        local numWithSuffix = string.match(text, "([%d%.]+%a+)") or string.match(text, "([%d%.]+)")
        if not numWithSuffix then return 0 end

        local multipliers = {
            {"Sp", 1e24}, {"Sx", 1e21}, {"Qn", 1e18}, {"Qd", 1e15},
            {"T",  1e12}, {"B",  1e9},  {"M",  1e6},  {"K",  1e3}
        }

        for _, data in ipairs(multipliers) do
            local suffix, mult = data[1], data[2]
            if string.sub(numWithSuffix, -#suffix) == suffix then
                local num = tonumber(string.sub(numWithSuffix, 1, -#suffix - 1))
                if num then return num * mult end
            end
        end

        return tonumber(numWithSuffix) or 0
    end

    -- Читаем монеты из UI
    local function getCoins()
        local ok, text = pcall(function()
            return player.PlayerGui.Root.LeftSideBar.CounterStack
                .CoinCounter.CounterRow.Amount.TextLabel.Text
        end)
        return ok and parseCoins(text) or 0
    end

    -- Рекурсивный поиск текста в UI-дереве
    local function getZoneTextFromUI(parent)
        if not parent then return nil end
        if parent:IsA("TextLabel") or parent:IsA("TextButton") then
            if parent.Text and parent.Text ~= "" then return parent.Text end
        end
        for _, child in ipairs(parent:GetChildren()) do
            local found = getZoneTextFromUI(child)
            if found then return found end
        end
        return nil
    end

    -- Определяем, в какой зоне сейчас находится игрок
    local function determineCurrentZone()
        local ok, zoneNameEl = pcall(function()
            return player.PlayerGui.Root.ZonesRoot.Content.ZoneName
        end)
        if ok and zoneNameEl then
            local uiText = getZoneTextFromUI(zoneNameEl)
            if uiText then
                for zoneName, nextIndex in pairs(ZoneNamesToNextIndex) do
                    if string.find(uiText, zoneName) then return nextIndex end
                end
            end
        end
        return 2 -- Fallback: начинаем со второй зоны
    end

    -- ── Запуск цикла покупки ────────────────────────────────────
    local currentZoneIndex = determineCurrentZone()
    print("[Локации] Следующая зона для покупки: #" .. ZonesList[currentZoneIndex].id)

    local isProcessing = false

    while task.wait(0.1) do
        if currentZoneIndex > #ZonesList then
            print("🎉 [Локации] ВСЕ ЛОКАЦИИ КУПЛЕНЫ! Модуль завершён.")
            break
        end

        if isProcessing then continue end

        local targetZone = ZonesList[currentZoneIndex]
        local myMoney    = getCoins()

        if myMoney >= targetZone.cost then
            isProcessing = true
            print("💰 [Локации] Денег достаточно! Покупаем зону #" .. targetZone.id)

            local buyOk, buyResp = pcall(function()
                return ZonesRemote:InvokeServer("requestPurchaseZone", targetZone.id)
            end)

            if buyOk then
                print("✅ [Локации] Зона #" .. targetZone.id .. " куплена! Ответ: " .. tostring(buyResp))
                task.wait(1.5)

                local tpOk, tpResp = pcall(function()
                    return ZonesRemote:InvokeServer("requestTeleportZone", targetZone.id)
                end)

                if tpOk then
                    print("🚀 [Локации] Телепортация в зону #" .. targetZone.id .. " успешна!")
                    currentZoneIndex += 1
                    print("⏳ [Локации] Копим на следующую зону...")
                else
                    warn("❌ [Локации] Ошибка телепортации: " .. tostring(tpResp))
                end
            else
                warn("❌ [Локации] Ошибка покупки: " .. tostring(buyResp))
                task.wait(3)
            end

            isProcessing = false
        end
    end
end)
