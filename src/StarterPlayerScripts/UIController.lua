--[[
	UIController — Client UI: camera, coin display, shop, death screen.
	Type: LocalScript (NOT Script, NOT ModuleScript)
	Location: StarterPlayer > StarterPlayerScripts

	Creates ALL UI elements from code (no StarterGui prefabs needed).
	Handles:
	  - Top-down camera following snake head
	  - Coin counter display (top-left)
	  - Shop button + shop panel
	  - Death screen overlay
]]

print("[Client:UI] UIController starting...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes
local remoteCoinUpdate = ReplicatedStorage:WaitForChild("CoinUpdate", 30)
local remoteShopBuy = ReplicatedStorage:WaitForChild("ShopBuy", 30)
local remoteDeath = ReplicatedStorage:WaitForChild("SnakeDeath", 30)

print("[Client:UI] Remotes found")

-- ===================== CAMERA SETUP =====================
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
print("[Client:UI] Camera set to Scriptable")

local CAMERA_HEIGHT = 55
local CAMERA_LERP = 8
local camPos = Vector3.new(0, CAMERA_HEIGHT, 0)

-- Keep camera scriptable (Roblox likes to reset it)
camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

-- ===================== CREATE UI =====================

-- Main ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- === COIN DISPLAY (top-left) ===
local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "CoinDisplay"
coinLabel.Size = UDim2.new(0, 220, 0, 50)
coinLabel.Position = UDim2.new(0, 15, 0, 15)
coinLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
coinLabel.BackgroundTransparency = 0.4
coinLabel.BorderSizePixel = 0
coinLabel.Text = "Coins: 0"
coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinLabel.TextScaled = true
coinLabel.Font = Enum.Font.GothamBold
coinLabel.Parent = gui

-- Round corners
local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0, 10)
coinCorner.Parent = coinLabel

print("[Client:UI] Coin display created")

-- === SHOP BUTTON (top-right) ===
local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.new(0, 120, 0, 45)
shopBtn.Position = UDim2.new(1, -135, 0, 15)
shopBtn.BackgroundColor3 = Color3.fromRGB(80, 170, 80)
shopBtn.BorderSizePixel = 0
shopBtn.Text = "SHOP"
shopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
shopBtn.TextScaled = true
shopBtn.Font = Enum.Font.GothamBold
shopBtn.Parent = gui

local shopBtnCorner = Instance.new("UICorner")
shopBtnCorner.CornerRadius = UDim.new(0, 10)
shopBtnCorner.Parent = shopBtn

-- === SHOP PANEL (centered, hidden by default) ===
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Size = UDim2.new(0, 350, 0, 300)
shopPanel.Position = UDim2.new(0.5, -175, 0.5, -150)
shopPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
shopPanel.BackgroundTransparency = 0.1
shopPanel.BorderSizePixel = 0
shopPanel.Visible = false
shopPanel.Parent = gui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopPanel

-- Shop title
local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0, 50)
shopTitle.Position = UDim2.new(0, 0, 0, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "SHOP"
shopTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
shopTitle.TextScaled = true
shopTitle.Font = Enum.Font.GothamBold
shopTitle.Parent = shopPanel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = shopPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

-- Growth Boost item
local boostBtn = Instance.new("TextButton")
boostBtn.Name = "GrowthBoostBtn"
boostBtn.Size = UDim2.new(0.8, 0, 0, 70)
boostBtn.Position = UDim2.new(0.1, 0, 0, 80)
boostBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
boostBtn.BorderSizePixel = 0
boostBtn.Text = "Growth Boost +10%\nCost: 500 coins"
boostBtn.TextColor3 = Color3.new(1, 1, 1)
boostBtn.TextScaled = true
boostBtn.Font = Enum.Font.GothamBold
boostBtn.Parent = shopPanel

local boostCorner = Instance.new("UICorner")
boostCorner.CornerRadius = UDim.new(0, 8)
boostCorner.Parent = boostBtn

-- Shop result message
local shopMsg = Instance.new("TextLabel")
shopMsg.Name = "ShopMessage"
shopMsg.Size = UDim2.new(0.8, 0, 0, 40)
shopMsg.Position = UDim2.new(0.1, 0, 0, 170)
shopMsg.BackgroundTransparency = 1
shopMsg.Text = ""
shopMsg.TextColor3 = Color3.fromRGB(200, 200, 200)
shopMsg.TextScaled = true
shopMsg.Font = Enum.Font.Gotham
shopMsg.Parent = shopPanel

print("[Client:UI] Shop panel created")

-- === DEATH SCREEN (fullscreen overlay, hidden) ===
local deathFrame = Instance.new("Frame")
deathFrame.Name = "DeathScreen"
deathFrame.Size = UDim2.new(1, 0, 1, 0)
deathFrame.BackgroundColor3 = Color3.new(0, 0, 0)
deathFrame.BackgroundTransparency = 0.5
deathFrame.BorderSizePixel = 0
deathFrame.Visible = false
deathFrame.Parent = gui

local deathLabel = Instance.new("TextLabel")
deathLabel.Size = UDim2.new(0.6, 0, 0.2, 0)
deathLabel.Position = UDim2.new(0.2, 0, 0.4, 0)
deathLabel.BackgroundTransparency = 1
deathLabel.Text = "YOU DIED!\nRespawning in 3s..."
deathLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
deathLabel.TextScaled = true
deathLabel.Font = Enum.Font.GothamBold
deathLabel.Parent = deathFrame

print("[Client:UI] Death screen created")

-- ===================== UI LOGIC =====================

local myCoins = 0
local shopOpen = false

-- Update coins display
local function updateCoinDisplay(amount)
	myCoins = amount
	coinLabel.Text = "Coins: " .. tostring(amount)
end

-- Toggle shop
shopBtn.MouseButton1Click:Connect(function()
	shopOpen = not shopOpen
	shopPanel.Visible = shopOpen
end)

closeBtn.MouseButton1Click:Connect(function()
	shopOpen = false
	shopPanel.Visible = false
end)

-- Buy growth boost
boostBtn.MouseButton1Click:Connect(function()
	if myCoins >= 500 then
		remoteShopBuy:FireServer("GrowthBoost")
		shopMsg.Text = "Purchased! +10% growth"
		shopMsg.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		shopMsg.Text = "Not enough coins! Need 500"
		shopMsg.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
	-- Clear message after 2s
	task.delay(2, function()
		shopMsg.Text = ""
	end)
end)

-- Listen for coin updates from server
if remoteCoinUpdate then
	remoteCoinUpdate.OnClientEvent:Connect(function(amount)
		updateCoinDisplay(amount)
	end)
end

-- Listen for death
if remoteDeath then
	remoteDeath.OnClientEvent:Connect(function()
		deathFrame.Visible = true
		task.delay(3, function()
			deathFrame.Visible = false
		end)
	end)
end

-- Also track leaderstats for initial value
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 10)
	if ls then
		local c = ls:WaitForChild("Coins", 10)
		if c then
			updateCoinDisplay(c.Value)
			c.Changed:Connect(function(val)
				updateCoinDisplay(val)
			end)
		end
	end
end)

print("[Client:UI] UI logic connected")

-- ===================== CAMERA LOOP =====================

RunService.RenderStepped:Connect(function(dt)
	-- Re-acquire camera
	camera = workspace.CurrentCamera
	if not camera then return end

	-- Force scriptable
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- Find snake head
	local head = workspace:FindFirstChild("SnakeHead_" .. player.Name)

	if head then
		local target = Vector3.new(head.Position.X, CAMERA_HEIGHT, head.Position.Z)
		local alpha = math.clamp(CAMERA_LERP * dt, 0, 1)
		camPos = camPos:Lerp(target, alpha)
	end

	-- Top-down camera: position above, rotated to look straight down
	-- Using CFrame.Angles avoids gimbal lock (CFrame.new(pos, lookAt) breaks when looking straight down)
	camera.CFrame = CFrame.new(camPos) * CFrame.Angles(-math.pi / 2, 0, 0)
end)

print("[Client:UI] Camera loop started")
print("[Client:UI] UIController fully ready!")
