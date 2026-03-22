-- InputHandler: Client-side input capture
-- Sends the player's target direction (angle) to the server based on mouse/touch position

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.GameConfig)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Wait for remote events to be created by the server
local inputEvent = ReplicatedStorage:WaitForChild("InputEvent", 30)

if not inputEvent then
	warn("[InputHandler] Could not find InputEvent remote")
	return
end

local sendTimer = 0
local lastSentAngle = 0
local isDead = false

-- Listen for death events
local deathEvent = ReplicatedStorage:WaitForChild("DeathEvent", 30)
if deathEvent then
	deathEvent.OnClientEvent:Connect(function()
		isDead = true
		-- Show death UI
		InputHandler_showDeathScreen()

		task.delay(GameConfig.RESPAWN_DELAY, function()
			isDead = false
			InputHandler_hideDeathScreen()
		end)
	end)
end

-- Simple death screen UI
local deathGui = nil

function InputHandler_showDeathScreen()
	if deathGui then return end

	deathGui = Instance.new("ScreenGui")
	deathGui.Name = "DeathScreen"
	deathGui.Parent = player.PlayerGui

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

function InputHandler_hideDeathScreen()
	if deathGui then
		deathGui:Destroy()
		deathGui = nil
	end
end

-- Calculate the angle from the snake head toward the mouse cursor position
local function getTargetAngle()
	-- Cast a ray from the camera through the mouse position onto the ground plane
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	-- Intersect with the Y=1.5 plane (snake head height)
	local planeY = 1.5
	if ray.Direction.Y == 0 then return lastSentAngle end

	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return lastSentAngle end

	local worldPos = ray.Origin + ray.Direction * t

	-- Find the snake head in the workspace
	local snakeModel = workspace.Snakes:FindFirstChild("Snake_" .. player.Name)
	if not snakeModel or not snakeModel.PrimaryPart then
		return lastSentAngle
	end

	local headPos = snakeModel.PrimaryPart.Position
	local dx = worldPos.X - headPos.X
	local dz = worldPos.Z - headPos.Z

	-- Calculate angle (atan2 gives us the angle from the Z axis)
	local angle = math.atan2(dx, dz)
	return angle
end

-- Send input to server at a fixed rate
RunService.RenderStepped:Connect(function(dt)
	if isDead then return end

	sendTimer = sendTimer + dt
	if sendTimer >= GameConfig.INPUT_SEND_RATE then
		sendTimer = 0

		local angle = getTargetAngle()

		-- Only send if the angle has changed meaningfully
		if math.abs(angle - lastSentAngle) > 0.02 then
			lastSentAngle = angle
			inputEvent:FireServer(angle)
		end
	end
end)

-- Touch input support: use touch position instead of mouse
if UserInputService.TouchEnabled then
	local touchAngle = 0
	UserInputService.TouchMoved:Connect(function(input)
		local touchPos = input.Position
		local ray = camera:ViewportPointToRay(touchPos.X, touchPos.Y)
		local planeY = 1.5
		if ray.Direction.Y == 0 then return end
		local t = (planeY - ray.Origin.Y) / ray.Direction.Y
		if t < 0 then return end
		local worldPos = ray.Origin + ray.Direction * t

		local snakeModel = workspace.Snakes:FindFirstChild("Snake_" .. player.Name)
		if not snakeModel or not snakeModel.PrimaryPart then return end

		local headPos = snakeModel.PrimaryPart.Position
		touchAngle = math.atan2(worldPos.X - headPos.X, worldPos.Z - headPos.Z)
		lastSentAngle = touchAngle
		inputEvent:FireServer(touchAngle)
	end)
end

print("[InputHandler] Client input system ready")
