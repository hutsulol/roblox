--[[
	InputHandler — Client input for snake direction.
	Type: LocalScript (NOT Script, NOT ModuleScript)
	Location: StarterPlayer > StarterPlayerScripts

	Reads mouse position, calculates angle, sends to server.
]]

print("[Client:Input] InputHandler starting...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for the remote event from server
local remoteInput = ReplicatedStorage:WaitForChild("SnakeInput", 30)
if not remoteInput then
	warn("[Client:Input] ERROR: SnakeInput remote not found!")
	return
end

print("[Client:Input] Found SnakeInput remote")

local lastAngle = 0
local sendTimer = 0
local SEND_RATE = 1 / 30 -- send 30 times per second

RunService.RenderStepped:Connect(function(dt)
	sendTimer = sendTimer + dt
	if sendTimer < SEND_RATE then return end
	sendTimer = 0

	-- Get camera
	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Find our snake head
	local head = workspace:FindFirstChild("SnakeHead_" .. player.Name)
	if not head then return end

	-- Raycast from mouse into the world at Y=1.5 (ground plane)
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	-- Intersect ray with Y=1.5 plane
	if math.abs(ray.Direction.Y) < 0.001 then return end
	local t = (1.5 - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return end

	local worldHit = ray.Origin + ray.Direction * t
	local headPos = head.Position

	local dx = worldHit.X - headPos.X
	local dz = worldHit.Z - headPos.Z

	-- Only send if mouse is far enough from head (avoid jitter)
	if dx * dx + dz * dz < 4 then return end

	local angle = math.atan2(dx, dz)

	-- Only send if angle changed meaningfully
	if math.abs(angle - lastAngle) > 0.03 then
		lastAngle = angle
		remoteInput:FireServer(angle)
	end
end)

-- Touch support
if UserInputService.TouchEnabled then
	UserInputService.TouchMoved:Connect(function(input)
		local camera = workspace.CurrentCamera
		if not camera then return end

		local head = workspace:FindFirstChild("SnakeHead_" .. player.Name)
		if not head then return end

		local tp = input.Position
		local ray = camera:ViewportPointToRay(tp.X, tp.Y)
		if math.abs(ray.Direction.Y) < 0.001 then return end
		local t = (1.5 - ray.Origin.Y) / ray.Direction.Y
		if t < 0 then return end

		local worldHit = ray.Origin + ray.Direction * t
		local dx = worldHit.X - head.Position.X
		local dz = worldHit.Z - head.Position.Z

		local angle = math.atan2(dx, dz)
		lastAngle = angle
		remoteInput:FireServer(angle)
	end)
end

print("[Client:Input] InputHandler ready!")
