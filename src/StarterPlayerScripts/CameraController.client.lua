-- CameraController: Client-side top-down camera that follows the player's snake head
-- Uses smooth interpolation (lerp) for a polished feel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.GameConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Set camera to Scriptable mode so we have full control
camera.CameraType = Enum.CameraType.Scriptable

local currentCameraPos = Vector3.new(0, GameConfig.CAMERA_HEIGHT, 0)
local targetCameraPos = currentCameraPos

-- Wait for the snake to be created
local function findSnakeHead()
	local snakesFolder = workspace:WaitForChild("Snakes", 30)
	if not snakesFolder then return nil end

	local snakeModel = snakesFolder:FindFirstChild("Snake_" .. player.Name)
	if snakeModel and snakeModel.PrimaryPart then
		return snakeModel.PrimaryPart
	end
	return nil
end

-- Watch for snake creation/recreation (respawning)
local function waitForSnake()
	while true do
		local head = findSnakeHead()
		if head then
			return head
		end
		task.wait(0.1)
	end
end

-- Camera update loop
local snakeHead = nil

RunService.RenderStepped:Connect(function(dt)
	-- Try to find the snake head if we don't have a reference
	if not snakeHead or not snakeHead.Parent then
		snakeHead = findSnakeHead()
		if not snakeHead then
			-- Keep camera at last known position while dead/respawning
			camera.CFrame = CFrame.new(currentCameraPos) * CFrame.Angles(-math.pi / 2, 0, 0)
			return
		end
	end

	-- Calculate target camera position (directly above snake head)
	local headPos = snakeHead.Position
	targetCameraPos = Vector3.new(headPos.X, headPos.Y + GameConfig.CAMERA_HEIGHT, headPos.Z)

	-- Smooth interpolation toward target
	local lerpAlpha = math.clamp(GameConfig.CAMERA_LERP_SPEED * dt, 0, 1)
	currentCameraPos = currentCameraPos:Lerp(targetCameraPos, lerpAlpha)

	-- Set camera to look straight down at the snake
	camera.CFrame = CFrame.new(currentCameraPos, Vector3.new(currentCameraPos.X, 0, currentCameraPos.Z))
end)

-- Ensure camera stays scriptable (Roblox can sometimes reset it)
camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

print("[CameraController] Top-down camera system ready")
