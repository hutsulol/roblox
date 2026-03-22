-- ============================================================================
-- CameraController.client.lua (LOCAL SCRIPT)
-- Top-down camera that smoothly follows the player's snake head
-- ============================================================================

print("[CameraController] Starting...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CAMERA_HEIGHT = 60
local CAMERA_LERP_SPEED = 8

-- Set camera to scriptable
camera.CameraType = Enum.CameraType.Scriptable
print("[CameraController] Camera set to Scriptable")

local currentCameraPos = Vector3.new(0, CAMERA_HEIGHT, 0)

-- Keep camera scriptable (Roblox resets it sometimes)
camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

RunService.RenderStepped:Connect(function(dt)
	-- Re-acquire camera reference if needed
	camera = workspace.CurrentCamera
	if not camera then return end

	-- Ensure scriptable
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- Find our snake head
	local snakeHead = nil
	local snakesFolder = workspace:FindFirstChild("Snakes")
	if snakesFolder then
		local snakeModel = snakesFolder:FindFirstChild("Snake_" .. player.Name)
		if snakeModel then
			snakeHead = snakeModel.PrimaryPart
		end
	end

	if snakeHead then
		-- Follow the snake head
		local headPos = snakeHead.Position
		local targetPos = Vector3.new(headPos.X, headPos.Y + CAMERA_HEIGHT, headPos.Z)

		local alpha = math.clamp(CAMERA_LERP_SPEED * dt, 0, 1)
		currentCameraPos = currentCameraPos:Lerp(targetPos, alpha)
	end

	-- Always update camera (even when dead, keep last position)
	-- Use CFrame.Angles to avoid gimbal lock when looking straight down
	camera.CFrame = CFrame.new(currentCameraPos) * CFrame.Angles(-math.pi / 2, 0, 0)
end)

print("[CameraController] Ready")
