-- Automatic casting, shake-button activation and reel input for the inspected place.
-- F6: start/stop. F7: show/hide. The top bar is draggable.
-- Calls the equipped rod's cast handlers and normal reel input methods.
-- While enabled, sends a balanced F15 input periodically to keep the client active.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Reel = require(RS.client.legacyControllers.ReelController)
local RodState = require(RS.shared.modules.fishing.BiteTypes).RodState
local env = type(getgenv) == "function" and getgenv() or _G
if env.FischAutoFish and type(env.FischAutoFish.destroy) == "function" then env.FischAutoFish.destroy() end
local api = {alive = true, enabled = false, attempts = 0, casts = 0, wins = 0, losses = 0, failedCasts = 0, connections = {}, status = "Готово. Встаньте у воды и нажмите «Старт».", nextCast = 0, lastShake = 0}
env.FischAutoFish = api
local function connect(signal, callback)
	local c = signal:Connect(callback)
	table.insert(api.connections, c)
	return c
end
local function gameCall(callback, ...)
	local identity = type(getthreadidentity) == "function" and getthreadidentity() or nil
	local setter = type(setthreadidentity) == "function" and setthreadidentity or nil
	if identity and setter then setter(2) end
	local result = table.pack(pcall(callback, ...))
	if identity and setter then setter(identity) end
	if not result[1] then error(result[2], 0) end
	return table.unpack(result, 2, result.n)
end
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local gui = make("ScreenGui", {Name = "FischAutoFish", ResetOnSpawn = false, DisplayOrder = 65}, playerGui)
api.gui = gui
local panel = make("Frame", {Name = "AutoFishingPanel", Position = UDim2.new(1, -332, 0, 85), Size = UDim2.fromOffset(320, 210), BackgroundColor3 = Color3.fromRGB(20, 27, 35), BorderSizePixel = 0}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, panel)
local function label(text, y, h)
	return make("TextLabel", {Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, h), BackgroundTransparency = 1, Text = text, TextColor3 = Color3.fromRGB(230, 240, 247), TextSize = 15, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}, panel)
end
local title = label("Авторыбалка · F6 / F7", 5, 29)
title.Size = UDim2.new(1, -55, 0, 29)
title.Font = Enum.Font.SourceSansBold
local close = make("TextButton", {Position = UDim2.new(1, -37, 0, 7), Size = UDim2.fromOffset(25, 24), Text = "×", TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(44, 58, 73), TextSize = 17, BorderSizePixel = 0}, panel)
local toggle = make("TextButton", {Position = UDim2.fromOffset(12, 41), Size = UDim2.new(1, -24, 0, 32), Text = "Старт · F6", TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(36, 119, 91), TextSize = 16, Font = Enum.Font.SourceSansBold, BorderSizePixel = 0}, panel)
local rodButton = make("TextButton", {Position = UDim2.fromOffset(12, 80), Size = UDim2.new(1, -24, 0, 26), Text = "Удочка: выбрать", TextColor3 = Color3.fromRGB(205, 224, 238), BackgroundColor3 = Color3.fromRGB(31, 43, 56), TextSize = 14, Font = Enum.Font.SourceSans, BorderSizePixel = 0}, panel)
local statusLabel = label(api.status, 110, 43)
local totals = label("Забросов: 0 · Поймано: 0", 157, 22)
local idleLabel = label("AFK-защита: выключена", 181, 21)
local handle = make("TextButton", {Position = UDim2.new(), Size = UDim2.new(1, -45, 0, 35), Text = "", BackgroundTransparency = 1, ZIndex = 5}, panel)
local dragInput, dragPoint, dragPosition
connect(handle.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input; dragPoint = input.Position; dragPosition = panel.Position
	end
end)
connect(UIS.InputChanged, function(input)
	if not dragInput then return end
	if input ~= dragInput and not (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
	local delta, size = input.Position - dragPoint, gui.AbsoluteSize
	panel.Position = UDim2.fromOffset(math.clamp(dragPosition.X.Scale * size.X + dragPosition.X.Offset + delta.X, 0, math.max(0, size.X - panel.AbsoluteSize.X)), math.clamp(dragPosition.Y.Scale * size.Y + dragPosition.Y.Offset + delta.Y, 0, math.max(0, size.Y - panel.AbsoluteSize.Y)))
end)
connect(UIS.InputEnded, function(input)
	if input == dragInput or (dragInput and input.UserInputType == Enum.UserInputType.MouseButton1) then dragInput = nil end
end)
connect(UIS.WindowFocusReleased, function() dragInput = nil end)

local syntheticInput = {UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, UserInputState = Enum.UserInputState.Begin, Position = Vector3.zero}
local syntheticEnd = {UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, UserInputState = Enum.UserInputState.End, Position = Vector3.zero}
local function castButton()
	local mobile = playerGui:FindFirstChild("FishButtonMobile")
	local frame = mobile and mobile:FindFirstChild("Frame")
	return frame and frame:FindFirstChild("button")
end
local function rodInputHandler(signal, rod)
	local rodScript = rod:FindFirstChild("rodClient")
	local fallback
	for _, connection in ipairs(getconnections(signal)) do
		local fn = connection.Function
		if connection.Enabled and fn and not connection.ForeignState then
			local ok, owner = pcall(function() return getfenv(fn).script end)
			if ok and owner == rodScript then return fn end
			local sourceOk, source = pcall(debug.info, fn, "s")
			if sourceOk and source:find(rod.Name .. ".rodClient", 1, true) then fallback = fallback or fn end
		end
	end
	if fallback then return fallback end
	error("Не найден обработчик заброса для «" .. rod.Name .. "».")
end
local function value(tool, name)
	local folder = tool and tool:FindFirstChild("values")
	local object = folder and folder:FindFirstChild(name)
	return object and object.Value
end
local function isRod(tool)
	return tool:IsA("Tool") and tool:FindFirstChild("rodClient") and tool:FindFirstChild("values") ~= nil
end
local function rods()
	local result = {}
	for _, container in pairs({player:FindFirstChild("Backpack"), player.Character}) do
		for _, tool in ipairs(container:GetChildren()) do if isRod(tool) then table.insert(result, tool) end end
	end
	table.sort(result, function(a, b) return a.Name < b.Name end)
	return result
end
local function chooseRod()
	local candidates = rods()
	for _, rod in ipairs(candidates) do
		if api.rodName and rod.Name == api.rodName then return rod end
	end
	for _, rod in ipairs(candidates) do
		if rod.Parent == player.Character then api.rodName = rod.Name; return rod end
	end
	if candidates[1] then api.rodName = candidates[1].Name; return candidates[1] end
end
local function render()
	if not api.alive then return end
	toggle.Text = api.enabled and "Стоп · F6" or "Старт · F6"
	toggle.BackgroundColor3 = api.enabled and Color3.fromRGB(147, 65, 58) or Color3.fromRGB(36, 119, 91)
	rodButton.Text = "Удочка: " .. (api.rodName or "выбрать")
	statusLabel.Text = api.status
	totals.Text = string.format("Забросов: %d · Поймано: %d · Сходов: %d", api.casts, api.wins, api.losses)
	if api.idle then api.idle.refresh() end
end
-- BEGIN IDLE KEEPALIVE
local function installIdleKeepAlive(owner, textLabel)
	if owner.idle and owner.idle.destroy then owner.idle.destroy() end
	local state = {pulses = 0, failures = 0, idleEvents = 0, nextAt = 0, pending = false, retired = false, connections = {}, keyDownEvents = 0, keyUpEvents = 0}
	owner.idle = state
	local GuiService = game:GetService("GuiService")
	local function listen(signal, callback)
		table.insert(state.connections, signal:Connect(callback))
	end
	function state.refresh()
		if state.retired or not textLabel.Parent then return end
		local text = "AFK-защита: выключена"
		if owner.enabled then
			if state.failures > 0 then text = "AFK-защита: ошибка ввода, повторяю"
			elseif state.pulses == 0 then text = "AFK-защита: запускается…"
			else text = "AFK-защита: включена · " .. state.pulses end
		end
		textLabel.Text = text
		textLabel.TextColor3 = owner.enabled and state.failures > 0 and Color3.fromRGB(255, 170, 130) or Color3.fromRGB(160, 211, 187)
	end
	local function sendPair(send)
		local downOk, downErr = pcall(send, true)
		if downOk then task.wait(0.05) end
		-- Always release, including if the helper was stopped during the press.
		local upOk, upErr = pcall(send, false)
		return downOk and upOk, downErr or upErr
	end
	local function sendActivity()
		if not state.virtualInput then
			local ok, input = pcall(UIS.CreateVirtualInput, UIS)
			if ok then state.virtualInput = input end
		end
		local ok, err = false, nil
		if state.virtualInput then
			ok, err = sendPair(function(down) state.virtualInput:SendKey(down, Enum.KeyCode.F15, false) end)
			if ok then state.backend = "VirtualInput"; return true end
		end
		local fallbackOk, fallbackErr = pcall(function()
			local manager = game:GetService("VirtualInputManager")
			local accepted, reason = sendPair(function(down) manager:SendKeyEvent(down, Enum.KeyCode.F15, false, game) end)
			if not accepted then error(tostring(reason), 0) end
		end)
		if fallbackOk then state.backend = "VirtualInputManager"; return true end
		return false, tostring(fallbackErr or err)
	end
	function state.pulse(reason)
		if state.retired or not owner.alive or not owner.enabled or state.pending or os.clock() < state.nextAt then return false end
		if UIS:GetFocusedTextBox() or GuiService.MenuIsOpen then
			state.nextAt = os.clock() + 10
			return false
		end
		state.pending = true
		state.nextAt = os.clock() + 60
		task.spawn(function()
			local ran, sent, err = pcall(sendActivity)
			state.pending = false
			if state.retired or not owner.alive then return end
			if ran and sent then
				state.pulses += 1
				state.lastPulse = os.clock()
				state.lastError = nil
				state.failures = 0
				print("[AutoFish AFK] activity=" .. state.pulses .. " reason=" .. tostring(reason) .. " backend=" .. tostring(state.backend))
			else
				state.failures += 1
				state.lastError = tostring(ran and err or sent)
				state.nextAt = os.clock() + 10
				if state.failures == 1 then warn("[AutoFish AFK] Input failed: " .. state.lastError) end
			end
			state.refresh()
		end)
		return true
	end
	function state.tick()
		if state.retired then return end
		if not owner.enabled then state.nextAt = 0; return end
		state.pulse("timer")
	end
	function state.destroy()
		if state.retired then return end
		state.retired = true
		for _, connection in ipairs(state.connections) do connection:Disconnect() end
		table.clear(state.connections)
	end
	listen(UIS.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.F15 then state.keyDownEvents += 1 end
	end)
	listen(UIS.InputEnded, function(input)
		if input.KeyCode == Enum.KeyCode.F15 then state.keyUpEvents += 1 end
	end)
	listen(player.Idled, function(seconds)
		if not owner.enabled or state.retired then return end
		state.idleEvents += 1
		state.lastIdleSeconds = seconds
		-- Idled can arrive before the periodic pulse is due; handle it promptly.
		if not state.lastPulse or os.clock() - state.lastPulse >= 15 then state.nextAt = 0 end
		state.pulse("Idled")
	end)
	listen(owner.gui.Destroying, state.destroy)
	state.refresh()
	return state
end
installIdleKeepAlive(api, idleLabel)
-- END IDLE KEEPALIVE
local function stage(text)
	if api.status ~= text then api.status = text; render() end
end
local function releaseCharge()
	local charge = api.charge
	if charge and not charge.released then
		charge.released = true
		charge.releaseTime = os.clock()
		local ok, err = pcall(gameCall, charge.endInput, syntheticEnd)
		if not ok then api.lastError = tostring(err); warn("[AutoFish] release", err) end
	end
end
local function releaseReel()
	local rod = api.controlledRod
	if rod and rod.current and rod.CurrentInputDirection == 1 then pcall(gameCall, rod.InputEnded, rod) end
	api.controlledRod = nil
	api.previousReel, api.previousFish = nil, nil
end
function api.stop(message)
	api.enabled = false
	releaseCharge(); releaseReel()
	stage(message or "Остановлено. F6 — запустить снова.")
	render()
end
function api.start()
	if not api.alive then return false end
	if type(firesignal) ~= "function" then api.stop("Executor не поддерживает firesignal."); return false end
	if type(getconnections) ~= "function" then api.stop("Executor не поддерживает getconnections для заброса."); return false end
	if not chooseRod() then api.stop("Удочка не найдена в персонаже или рюкзаке."); return false end
	api.enabled = true; api.failedCasts = 0; api.nextCast = os.clock() + 0.25
	api.idle.nextAt = 0
	if api.charge and api.charge.released then api.charge = nil end
	stage("Запускаю цикл…")
	render()
	print("[AutoFish] START rod=" .. tostring(api.rodName))
	return true
end
function api.destroy()
	if not api.alive then return end
	api.stop(); api.alive = false
	api.idle.destroy()
	for _, c in ipairs(api.connections) do c:Disconnect() end
	gui:Destroy()
end

local function tradeOpen()
	local hud = playerGui:FindFirstChild("hud")
	local safe = hud and hud:FindFirstChild("safezone")
	local trade = safe and safe:FindFirstChild("Trade")
	return trade and trade.Visible
end
local function shakeButton()
	local ui = playerGui:FindFirstChild("shakeui")
	if not ui or not ui.Enabled then return end
	local safe = ui:FindFirstChild("safezone")
	if not safe then return end
	for _, button in ipairs(safe:GetChildren()) do
		if button:IsA("GuiButton") and button.Visible then return button end
	end
end
local function beginCast(rod)
	local button = castButton()
	if not button then api.stop("Не найдена штатная кнопка заброса."); return end
	local beginInput = rodInputHandler(button.InputBegan, rod)
	local endInput = rodInputHandler(button.InputEnded, rod)
	local existingPower = {}
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child.Name == "power" or child.Name == "thunderpower" then existingPower[child] = true end
		end
	end
	api.attempts += 1
	local charge = {rod = rod, beginInput = beginInput, endInput = endInput, start = os.clock(), released = false, existingPower = existingPower, attempt = api.attempts}
	api.charge = charge
	stage("Заброс: ожидаю индикатор силы…")
	print("[AutoFish] CAST_ATTEMPT " .. charge.attempt .. " rod=" .. rod.Name)
	task.spawn(function()
		local ok, err = pcall(gameCall, beginInput, syntheticInput)
		if not ok and api.alive and api.enabled and api.charge == charge then
			api.lastError = tostring(err)
			api.stop("Ошибка заброса: " .. tostring(err))
			warn("[AutoFish] cast", err)
		end
	end)
end
local function confirmCast(charge)
	if charge and charge.powerSeen and not charge.confirmed then
		charge.confirmed = true
		api.casts += 1
		print("[AutoFish] CAST_CONFIRMED " .. api.casts .. " attempt=" .. charge.attempt .. " power=" .. tostring(charge.peakPower))
		render()
	end
end
local function tickCycle()
	if not api.enabled then return end
	local now = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then releaseCharge(); releaseReel(); stage("Ожидаю возрождения…"); return end
	if tradeOpen() or player:GetAttribute("TeleportInProgress") or workspace:GetAttribute("ClientCutsceneRunning") then
		releaseCharge(); releaseReel(); stage("Пауза: трейд, перемещение или кат-сцена."); return
	end
	local active = Reel.ActiveReel
	if active then
		confirmCast(api.charge)
		releaseCharge(); api.charge = nil
		api.failedCasts = 0
		stage(active.active and string.format("Вываживание: %d%%", math.clamp(math.floor(active.progress or 0), 0, 100)) or "Ожидаю завершения мини-игры…")
		return
	end
	if api.controlledRod then releaseReel() end
	if api.charge then
		local charge = api.charge
		if not charge.released then
			local root = character:FindFirstChild("HumanoidRootPart")
			local power
			if root then
				for _, child in ipairs(root:GetChildren()) do
					if (child.Name == "power" or child.Name == "thunderpower") and not charge.existingPower[child] then power = child end
				end
			end
			local powerbar = power and power:FindFirstChild("powerbar")
			local bar = powerbar and powerbar:FindFirstChild("bar")
			if bar or (power and power.Name == "thunderpower") then
				if not charge.powerSeen then print("[AutoFish] POWER_VISIBLE attempt=" .. charge.attempt) end
				charge.powerSeen = true
				charge.peakPower = math.max(charge.peakPower or 0, bar and bar.Size.Y.Scale or 1)
				stage("Заброс: набираю силу…")
			end
			if (bar and bar.Size.Y.Scale >= 0.94) or (power and power.Name == "thunderpower") or now - charge.start > 3 then
				releaseCharge()
				if not charge.powerSeen then stage("Индикатор силы не появился; повторю заброс.") end
			end
		end
		if charge.released then
			local state = tonumber(value(charge.rod, "state")) or 0
			if charge.rod:FindFirstChild("bobber") or value(charge.rod, "casted") or (state >= RodState.Searching and state <= RodState.PreReel) then
				confirmCast(charge)
				api.charge = nil; api.failedCasts = 0; api.nextCast = now + 1.5
			elseif now - charge.releaseTime > 3 then
				api.charge = nil; api.failedCasts += 1; api.nextCast = now + 2.2
			end
		end
		if now - charge.start > 12 then api.stop("Заброс не завершился. Проверьте удочку и позицию.") end
		return
	end
	if api.failedCasts >= 3 then api.stop("Заброс не принят. Встаньте у воды и нажмите F6."); return end
	local rod = chooseRod()
	if not rod then stage("Ожидаю удочку в рюкзаке…"); return end
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then stage("Выйдите из воды на берег."); return end
	if rod.Parent ~= character then
		humanoid:EquipTool(rod)
		api.nextCast = now + 1
		stage("Экипирую «" .. rod.Name .. "»…")
		return
	end
	local state = tonumber(value(rod, "state"))
	local shake = shakeButton()
	if shake then
		stage("Поклёвка: нажимаю кнопку…")
		if now - api.lastShake >= 0.28 then
			api.lastShake = now
			gameCall(firesignal, shake.Activated)
		end
		return
	end
	if value(rod, "casted") or (state and state >= RodState.Casting and state < RodState.CatchFinished) then
		stage("Ожидаю поклёвку…")
		return
	end
	if player:GetAttribute("BlockCast") or rod:GetAttribute("BlockCast") or player:GetAttribute("RodEquipInProgress") then stage("Ожидаю разрешения на заброс…"); return end
	if state ~= RodState.Equipped then stage("Ожидаю готовности удочки…"); return end
	if now >= api.nextCast then beginCast(rod) end
end

connect(RunService.PreRender, function(dt)
	if not api.enabled then return end
	local reel = Reel.ActiveReel
	if not reel or not reel.active or reel.isPaused or tradeOpen() then return end
	local rod = reel.core and reel.core.rod
	if not rod or rod.Disabled or rod.Paused then return end
	local ok, err = pcall(function()
		if api.previousReel ~= reel then
			releaseReel()
			api.previousReel = reel
			api.previousFish = reel.fishPosition
		end
		api.controlledRod = rod
		local fish = reel.fishPosition
		local fishVelocity = math.clamp((fish - (api.previousFish or fish)) / math.max(dt, 0.001), -1.5, 1.5)
		api.previousFish = fish
		local half = reel.barSize / 2
		local lower, upper = reel.minBarPosition + half, reel.maxBarPosition - half
		if lower >= upper then return end
		local target = math.clamp(fish + fishVelocity * 0.08, lower, upper)
		local error = target - reel.barPosition - (rod.CurrentVelocity or 0) * 0.23
		local direction = error >= 0 and 1 or -1
		if (reel.accel or 1) < 0 then direction = -direction end
		if math.abs(error) < 0.006 then return end
		if direction ~= rod.CurrentInputDirection then
			if direction == 1 then gameCall(rod.InputBegan, rod) else gameCall(rod.InputEnded, rod) end
		end
	end)
	if not ok then api.lastError = tostring(err); api.stop("Ошибка управления полоской."); warn("[AutoFish] reel", err) end
end)
local finished = RS.events:FindFirstChild("bindable_reel_finished")
if finished and finished:IsA("BindableEvent") then
	connect(finished.Event, function(success)
		if not api.enabled then return end
		if success then api.wins += 1 else api.losses += 1 end
		api.nextCast = os.clock() + 1.75
		print("[AutoFish] RESULT success=" .. tostring(success) .. " wins=" .. api.wins .. " losses=" .. api.losses)
		render()
	end)
end
connect(toggle.Activated, function() if api.enabled then api.stop() else api.start() end end)
connect(rodButton.Activated, function()
	if api.enabled then stage("Для смены удочки сначала остановите цикл."); return end
	local list = rods()
	if #list == 0 then stage("Удочки не найдены."); return end
	local index = 0
	for i, rod in ipairs(list) do if rod.Name == api.rodName then index = i; break end end
	api.rodName = list[index % #list + 1].Name
	render()
end)
connect(close.Activated, function() api.stop(); panel.Visible = false; dragInput = nil end)
connect(UIS.InputBegan, function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F6 then if api.enabled then api.stop() else api.start() end
	elseif input.KeyCode == Enum.KeyCode.F7 then panel.Visible = not panel.Visible; dragInput = nil end
end)
connect(gui.Destroying, api.destroy)
chooseRod(); render()
task.spawn(function()
	while api.alive do
		api.idle.tick()
		if api.enabled then
			local ok, err = pcall(tickCycle)
			if not ok then api.lastError = tostring(err); api.stop("Ошибка цикла: " .. tostring(err)); warn("[AutoFish]", err) end
		end
		task.wait(api.enabled and 0.04 or 0.25)
	end
end)
print("[AutoFish] Ready. F6 start/stop; F7 show/hide. Rod=" .. tostring(api.rodName))
