-- ============================================================================
-- InputHandler.client.lua (LOCAL SCRIPT)
-- Captures mouse/touch position and sends direction angle to server
-- ============================================================================

print("[InputHandler] Starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Wait for remote events
local inputEvent = ReplicatedStorage:WaitForChild("InputEvent", 30)
local deathEvent = ReplicatedStorage:WaitForChild("DeathEvent", 30)

if not inputEvent then
	warn("[InputHandler] InputEvent not found! Server may not be running.")
	return
end

print("[InputHandler] Found InputEvent remote")

-- State
local sendTimer = 0
local lastSentAngle = 0
local isDead = false
local deathGui = nil

local INPUT_SEND_RATE = 1 / 30

-- ============================================================================
-- Death screen UI
-- ============================================================================
local function showDeathScreen()
	if deathGui then return end

	deathGui = Instance.new("ScreenGui")
	deathGui.Name = "DeathScreen"
	deathGui.ResetOnSpawn = false
	deathGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = deathGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, 0, 0.2, 0)
	label.Position = UDim2.new(0.25, 0, 0.4, 0)
	label.BackgroundTransparency = 1
	label.Text = "You Died!\nRespawning..."
	label.TextColor3 = Color3.new(1, 0.2, 0.2)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame
end

local function hideDeathScreen()
	if deathGui then
		deathGui:Destroy()
		deathGui = nil
	end
end

if deathEvent then
	deathEvent.OnClientEvent:Connect(function()
		isDead = true
		showDeathScreen()
		task.delay(2, function()
			isDead = false
			hideDeathScreen()
		end)
	end)
end

-- ============================================================================
-- Input: calculate angle from snake head to mouse cursor
-- ============================================================================
local function getTargetAngle()
	local camera = workspace.CurrentCamera
	if not camera then return lastSentAngle end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	-- Intersect with the Y=1.5 plane
	if ray.Direction.Y == 0 then return lastSentAngle end
	local t = (1.5 - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return lastSentAngle end

	local worldPos = ray.Origin + ray.Direction * t

	-- Find our snake head
	local snakesFolder = workspace:FindFirstChild("Snakes")
	if not snakesFolder then return lastSentAngle end

	local snakeModel = snakesFolder:FindFirstChild("Snake_" .. player.Name)
	if not snakeModel then return lastSentAngle end

	local head = snakeModel.PrimaryPart
	if not head then return lastSentAngle end

	local dx = worldPos.X - head.Position.X
	local dz = worldPos.Z - head.Position.Z
	return math.atan2(dx, dz)
end

-- ============================================================================
-- Send input at fixed rate
-- ============================================================================
RunService.RenderStepped:Connect(function(dt)
	if isDead then return end

	sendTimer = sendTimer + dt
	if sendTimer >= INPUT_SEND_RATE then
		sendTimer = 0

		local angle = getTargetAngle()
		if math.abs(angle - lastSentAngle) > 0.02 then
			lastSentAngle = angle
			inputEvent:FireServer(angle)
		end
	end
end)

-- Touch support
if UserInputService.TouchEnabled then
	UserInputService.TouchMoved:Connect(function(input)
		if isDead then return end

		local camera = workspace.CurrentCamera
		if not camera then return end

		local touchPos = input.Position
		local ray = camera:ViewportPointToRay(touchPos.X, touchPos.Y)
		if ray.Direction.Y == 0 then return end
		local t = (1.5 - ray.Origin.Y) / ray.Direction.Y
		if t < 0 then return end
		local worldPos = ray.Origin + ray.Direction * t

		local snakesFolder = workspace:FindFirstChild("Snakes")
		if not snakesFolder then return end
		local snakeModel = snakesFolder:FindFirstChild("Snake_" .. player.Name)
		if not snakeModel or not snakeModel.PrimaryPart then return end

		local headPos = snakeModel.PrimaryPart.Position
		local angle = math.atan2(worldPos.X - headPos.X, worldPos.Z - headPos.Z)
		lastSentAngle = angle
		inputEvent:FireServer(angle)
	end)
end

print("[InputHandler] Ready")
