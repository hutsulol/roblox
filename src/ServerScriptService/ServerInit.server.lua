-- ============================================================================
-- ServerInit.server.lua (SCRIPT - not ModuleScript!)
-- Loongoliers: Complete server-side game logic in a single file.
-- This eliminates require() issues with server modules.
-- ============================================================================

print("==============================================")
print("[Loongoliers] ServerInit script is RUNNING")
print("==============================================")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- CONFIGURATION (inline — no external require needed)
-- ============================================================================
local Config = {
	MAP_SIZE = 500,
	MAP_HALF = 250,

	SNAKE_SPEED = 30,
	SNAKE_TURN_SPEED = 4,
	HEAD_SIZE = 3,
	SEGMENT_SIZE = 2.6,
	SEGMENT_SPACING = 2.2,
	INITIAL_SEGMENTS = 3,
	MAX_SEGMENTS = 100,
	POSITION_HISTORY_MULTIPLIER = 3,

	COIN_SIZE = 1.5,
	COIN_SPAWN_INTERVAL = 1,
	MAX_COINS = 200,
	COIN_SPAWN_HEIGHT = 1.5,

	DEATH_DROP_BASE = 2,
	DEATH_DROP_SPREAD = 8,
	RESPAWN_DELAY = 2,

	SNAKE_UPDATE_RATE = 1 / 20,
}

local SNAKE_COLORS = {
	Color3.fromRGB(255, 50, 50),
	Color3.fromRGB(50, 255, 50),
	Color3.fromRGB(50, 50, 255),
	Color3.fromRGB(255, 255, 50),
	Color3.fromRGB(255, 50, 255),
	Color3.fromRGB(50, 255, 255),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(150, 50, 255),
}

-- ============================================================================
-- STEP 1: Disable default character
-- ============================================================================
Players.CharacterAutoLoads = false
print("[Loongoliers] CharacterAutoLoads disabled")

-- ============================================================================
-- STEP 2: Create Remote Events
-- ============================================================================
local function createRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	print("[Loongoliers] Created RemoteEvent:", name)
	return remote
end

local InputEvent = createRemote("InputEvent")
local SnakeUpdate = createRemote("SnakeUpdate")
local DeathEvent = createRemote("DeathEvent")

-- ============================================================================
-- STEP 3: Create Arena
-- ============================================================================
local function createArena()
	print("[Loongoliers] Creating arena...")

	-- Clean workspace of default objects
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") or (obj:IsA("Part") and obj.Name == "Baseplate") then
			obj:Destroy()
			print("[Loongoliers] Removed default object:", obj.Name)
		end
	end

	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	arenaFolder.Parent = workspace

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(Config.MAP_SIZE, 1, Config.MAP_SIZE)
	floor.Position = Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(20, 20, 30)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = arenaFolder

	print("[Loongoliers] Floor created at", floor.Position, "size", floor.Size)

	-- Boundary walls
	local half = Config.MAP_HALF
	local wallHeight = 10
	local wallThickness = 2
	local walls = {
		{name = "WallNorth", pos = Vector3.new(0, wallHeight/2, -half), size = Vector3.new(Config.MAP_SIZE + wallThickness*2, wallHeight, wallThickness)},
		{name = "WallSouth", pos = Vector3.new(0, wallHeight/2, half), size = Vector3.new(Config.MAP_SIZE + wallThickness*2, wallHeight, wallThickness)},
		{name = "WallEast", pos = Vector3.new(half, wallHeight/2, 0), size = Vector3.new(wallThickness, wallHeight, Config.MAP_SIZE)},
		{name = "WallWest", pos = Vector3.new(-half, wallHeight/2, 0), size = Vector3.new(wallThickness, wallHeight, Config.MAP_SIZE)},
	}
	for _, w in ipairs(walls) do
		local wall = Instance.new("Part")
		wall.Name = w.name
		wall.Size = w.size
		wall.Position = w.pos
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.Neon
		wall.Color = Color3.fromRGB(255, 50, 50)
		wall.Transparency = 0.5
		wall.Parent = arenaFolder
	end

	print("[Loongoliers] Arena created with 4 walls")
	return arenaFolder
end

local arena = createArena()

-- ============================================================================
-- STEP 4: Create Workspace Folders
-- ============================================================================
local snakesFolder = Instance.new("Folder")
snakesFolder.Name = "Snakes"
snakesFolder.Parent = workspace
print("[Loongoliers] Created Snakes folder in workspace")

local coinsFolder = Instance.new("Folder")
coinsFolder.Name = "Coins"
coinsFolder.Parent = workspace
print("[Loongoliers] Created Coins folder in workspace")

-- ============================================================================
-- COIN SYSTEM
-- ============================================================================
local activeCoinCount = 0
local coinSpawnTimer = 0

local function createCoin(position)
	local coin = Instance.new("Part")
	coin.Name = "PirateCoin"
	coin.Size = Vector3.new(Config.COIN_SIZE, Config.COIN_SIZE, Config.COIN_SIZE)
	coin.Shape = Enum.PartType.Ball
	coin.Material = Enum.Material.Neon
	coin.Color = Color3.fromRGB(255, 215, 0)
	coin.Anchored = true
	coin.CanCollide = false
	coin.Position = position

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 0)
	light.Brightness = 0.5
	light.Range = 6
	light.Parent = coin

	coin.Parent = coinsFolder
	CollectionService:AddTag(coin, "PirateCoin")
	activeCoinCount = activeCoinCount + 1
	return coin
end

local function spawnRandomCoin()
	local half = Config.MAP_HALF - 5
	local x = math.random(-half, half)
	local z = math.random(-half, half)
	return createCoin(Vector3.new(x, Config.COIN_SPAWN_HEIGHT, z))
end

local function removeCoin(coin)
	if coin and coin.Parent then
		CollectionService:RemoveTag(coin, "PirateCoin")
		coin:Destroy()
		activeCoinCount = math.max(0, activeCoinCount - 1)
	end
end

local function spawnCoinsAtPosition(position, count)
	for _ = 1, count do
		if activeCoinCount >= Config.MAX_COINS then break end
		local spread = Config.DEATH_DROP_SPREAD
		local ox = (math.random() - 0.5) * 2 * spread
		local oz = (math.random() - 0.5) * 2 * spread
		local pos = Vector3.new(
			math.clamp(position.X + ox, -Config.MAP_HALF + 2, Config.MAP_HALF - 2),
			Config.COIN_SPAWN_HEIGHT,
			math.clamp(position.Z + oz, -Config.MAP_HALF + 2, Config.MAP_HALF - 2)
		)
		createCoin(pos)
	end
end

-- Spawn initial coins
for _ = 1, math.floor(Config.MAX_COINS / 2) do
	spawnRandomCoin()
end
print("[Loongoliers] Spawned", activeCoinCount, "initial coins")

-- ============================================================================
-- SNAKE SYSTEM
-- ============================================================================
local snakes = {} -- keyed by player.UserId

local function createHeadPart(color)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(Config.HEAD_SIZE, Config.HEAD_SIZE * 0.67, Config.HEAD_SIZE)
	head.Shape = Enum.PartType.Ball
	head.Material = Enum.Material.SmoothPlastic
	head.Color = color
	head.Anchored = true
	head.CanCollide = false
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth

	-- Eyes
	for _, eyeName in ipairs({"LeftEye", "RightEye"}) do
		local eye = Instance.new("Part")
		eye.Name = eyeName
		eye.Size = Vector3.new(0.6, 0.6, 0.6)
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.SmoothPlastic
		eye.Color = Color3.new(1, 1, 1)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = head
	end

	return head
end

local function createSegmentPart(color, index)
	local segment = Instance.new("Part")
	segment.Name = "Segment_" .. index
	segment.Size = Vector3.new(Config.SEGMENT_SIZE, Config.SEGMENT_SIZE * 0.7, Config.SEGMENT_SIZE)
	segment.Shape = Enum.PartType.Ball
	segment.Material = Enum.Material.SmoothPlastic
	segment.Anchored = true
	segment.CanCollide = false
	segment.TopSurface = Enum.SurfaceType.Smooth
	segment.BottomSurface = Enum.SurfaceType.Smooth

	-- Alternating colors
	if index % 2 == 0 then
		segment.Color = color
	else
		segment.Color = Color3.new(
			math.clamp(color.R * 0.7, 0, 1),
			math.clamp(color.G * 0.7, 0, 1),
			math.clamp(color.B * 0.7, 0, 1)
		)
	end
	return segment
end

local function updateEyes(head, angle)
	local leftEye = head:FindFirstChild("LeftEye")
	local rightEye = head:FindFirstChild("RightEye")
	if not leftEye or not rightEye then return end

	local forward = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local right = Vector3.new(math.cos(angle), 0, -math.sin(angle))

	leftEye.Position = head.Position + forward * 1.0 + right * 0.6 + Vector3.new(0, 0.5, 0)
	rightEye.Position = head.Position + forward * 1.0 - right * 0.6 + Vector3.new(0, 0.5, 0)
end

local function getSpawnPosition()
	local half = Config.MAP_HALF - 30
	for _ = 1, 10 do
		local x = math.random(-half, half)
		local z = math.random(-half, half)
		local pos = Vector3.new(x, 1.5, z)
		local tooClose = false
		for _, snake in pairs(snakes) do
			if snake.alive and snake.head and (snake.head.Position - pos).Magnitude < 30 then
				tooClose = true
				break
			end
		end
		if not tooClose then return pos end
	end
	return Vector3.new(math.random(-half, half), 1.5, math.random(-half, half))
end

local function getSnakeColor(player)
	return SNAKE_COLORS[(player.UserId % #SNAKE_COLORS) + 1]
end

-- Forward declaration
local spawnSnake
local killSnake

function spawnSnake(player)
	-- Remove existing snake
	local existing = snakes[player.UserId]
	if existing and existing.model and existing.model.Parent then
		existing.model:Destroy()
	end
	snakes[player.UserId] = nil

	local color = getSnakeColor(player)
	local spawnPos = getSpawnPosition()
	local spawnAngle = math.random() * math.pi * 2

	-- Create model
	local model = Instance.new("Model")
	model.Name = "Snake_" .. player.Name
	model.Parent = snakesFolder

	-- Create head
	local head = createHeadPart(color)
	head.Position = spawnPos
	head.Parent = model
	model.PrimaryPart = head

	updateEyes(head, spawnAngle)

	-- Create initial segments
	local segments = {}
	for i = 1, Config.INITIAL_SEGMENTS do
		local segment = createSegmentPart(color, i)
		local offset = Vector3.new(
			-math.sin(spawnAngle) * Config.SEGMENT_SPACING * i,
			0,
			-math.cos(spawnAngle) * Config.SEGMENT_SPACING * i
		)
		segment.Position = spawnPos + offset
		segment.Parent = model
		table.insert(segments, segment)
	end

	-- Build position history
	local positionHistory = {}
	local maxHistory = Config.MAX_SEGMENTS * Config.POSITION_HISTORY_MULTIPLIER
	for i = 0, maxHistory - 1 do
		local offset = Vector3.new(
			-math.sin(spawnAngle) * (Config.SEGMENT_SPACING / Config.POSITION_HISTORY_MULTIPLIER) * i,
			0,
			-math.cos(spawnAngle) * (Config.SEGMENT_SPACING / Config.POSITION_HISTORY_MULTIPLIER) * i
		)
		table.insert(positionHistory, spawnPos + offset)
	end

	snakes[player.UserId] = {
		player = player,
		model = model,
		head = head,
		segments = segments,
		positionHistory = positionHistory,
		angle = spawnAngle,
		targetAngle = spawnAngle,
		coinsCollected = 0,
		color = color,
		alive = true,
	}

	-- Reset leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coinsVal = leaderstats:FindFirstChild("Coins")
		if coinsVal then coinsVal.Value = 0 end
		local lengthVal = leaderstats:FindFirstChild("Length")
		if lengthVal then lengthVal.Value = Config.INITIAL_SEGMENTS end
	end

	print("[Loongoliers] Snake spawned for", player.Name, "at", spawnPos)
end

function killSnake(snake)
	snake.alive = false
	local player = snake.player
	local headPos = snake.head.Position

	local dropCount = Config.DEATH_DROP_BASE + snake.coinsCollected
	spawnCoinsAtPosition(headPos, dropCount)

	DeathEvent:FireClient(player)

	if snake.model and snake.model.Parent then
		snake.model:Destroy()
	end

	print("[Loongoliers]", player.Name, "died. Dropped", dropCount, "coins")

	task.delay(Config.RESPAWN_DELAY, function()
		if player.Parent then
			spawnSnake(player)
		end
	end)
end

local function addSegment(snake)
	if #snake.segments >= Config.MAX_SEGMENTS then return end

	local index = #snake.segments + 1
	local segment = createSegmentPart(snake.color, index)

	local lastSegment = snake.segments[#snake.segments]
	segment.Position = lastSegment and lastSegment.Position or snake.head.Position
	segment.Parent = snake.model
	table.insert(snake.segments, segment)

	local leaderstats = snake.player:FindFirstChild("leaderstats")
	if leaderstats then
		local lengthVal = leaderstats:FindFirstChild("Length")
		if lengthVal then lengthVal.Value = #snake.segments end
	end
end

-- ============================================================================
-- SNAKE MOVEMENT
-- ============================================================================
local function moveSnake(snake, dt)
	-- Turn toward target angle
	local angleDiff = snake.targetAngle - snake.angle
	while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
	while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

	local turnAmount = Config.SNAKE_TURN_SPEED * dt
	if math.abs(angleDiff) < turnAmount then
		snake.angle = snake.targetAngle
	else
		if angleDiff > 0 then
			snake.angle = snake.angle + turnAmount
		else
			snake.angle = snake.angle - turnAmount
		end
	end

	-- Move head
	local direction = Vector3.new(math.sin(snake.angle), 0, math.cos(snake.angle))
	local newPos = snake.head.Position + direction * Config.SNAKE_SPEED * dt

	-- Clamp to arena
	local half = Config.MAP_HALF - 2
	newPos = Vector3.new(
		math.clamp(newPos.X, -half, half),
		1.5,
		math.clamp(newPos.Z, -half, half)
	)

	-- Bounce off walls
	if math.abs(newPos.X) >= half then
		snake.angle = -snake.angle
		snake.targetAngle = snake.angle
	end
	if math.abs(newPos.Z) >= half then
		snake.angle = math.pi - snake.angle
		snake.targetAngle = snake.angle
	end

	snake.head.Position = newPos
	updateEyes(snake.head, snake.angle)

	-- Update position history
	table.insert(snake.positionHistory, 1, newPos)
	local maxHistory = (#snake.segments + 5) * Config.POSITION_HISTORY_MULTIPLIER
	while #snake.positionHistory > maxHistory do
		table.remove(snake.positionHistory)
	end

	-- Move segments
	for i, segment in ipairs(snake.segments) do
		local histIndex = i * Config.POSITION_HISTORY_MULTIPLIER
		if histIndex <= #snake.positionHistory then
			segment.Position = snake.positionHistory[histIndex]
		end
	end
end

-- ============================================================================
-- COLLISION DETECTION
-- ============================================================================
local function checkCoinCollisions()
	local coins = CollectionService:GetTagged("PirateCoin")

	for _, snake in pairs(snakes) do
		if snake.alive then
			local headPos = snake.head.Position
			local collectRadius = Config.HEAD_SIZE / 2 + Config.COIN_SIZE / 2

			for _, coin in ipairs(coins) do
				if coin.Parent and (coin.Position - headPos).Magnitude < collectRadius then
					removeCoin(coin)
					snake.coinsCollected = snake.coinsCollected + 1

					local leaderstats = snake.player:FindFirstChild("leaderstats")
					if leaderstats then
						local coinsVal = leaderstats:FindFirstChild("Coins")
						if coinsVal then coinsVal.Value = snake.coinsCollected end
					end

					addSegment(snake)
				end
			end
		end
	end
end

local function checkSnakeCollisions()
	local deadSnakes = {}

	for userId, snake in pairs(snakes) do
		if snake.alive then
			local headPos = snake.head.Position
			local headRadius = Config.HEAD_SIZE / 2

			for otherUserId, otherSnake in pairs(snakes) do
				if otherUserId ~= userId and otherSnake.alive then
					-- Head-to-head
					local headDist = (otherSnake.head.Position - headPos).Magnitude
					if headDist < headRadius * 2 then
						local myLen = #snake.segments
						local otherLen = #otherSnake.segments
						if myLen <= otherLen then deadSnakes[userId] = true end
						if otherLen <= myLen then deadSnakes[otherUserId] = true end
					else
						-- Head-to-body
						for _, segment in ipairs(otherSnake.segments) do
							local segRadius = Config.SEGMENT_SIZE / 2
							if (segment.Position - headPos).Magnitude < (headRadius + segRadius) * 0.8 then
								deadSnakes[userId] = true
								break
							end
						end
					end
				end
			end
		end
	end

	for userId in pairs(deadSnakes) do
		local snake = snakes[userId]
		if snake and snake.alive then
			killSnake(snake)
		end
	end
end

-- ============================================================================
-- NETWORK: Broadcast snake states
-- ============================================================================
local updateTimer = 0

local function broadcastState()
	local stateData = {}

	for userId, snake in pairs(snakes) do
		if snake.alive and snake.head then
			local segPos = {}
			for i, seg in ipairs(snake.segments) do
				segPos[i] = seg.Position
			end
			stateData[userId] = {
				headPosition = snake.head.Position,
				angle = snake.angle,
				segmentPositions = segPos,
				color = {snake.color.R, snake.color.G, snake.color.B},
				playerName = snake.player.Name,
			}
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		SnakeUpdate:FireClient(player, stateData)
	end
end

-- ============================================================================
-- INPUT HANDLING (from clients)
-- ============================================================================
InputEvent.OnServerEvent:Connect(function(player, angle)
	local snake = snakes[player.UserId]
	if snake and snake.alive then
		if type(angle) == "number" and angle == angle then
			snake.targetAngle = angle
		end
	end
end)

-- ============================================================================
-- PLAYER CONNECTION
-- ============================================================================
local function onPlayerAdded(player)
	print("[Loongoliers] Player joined:", player.Name)

	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local length = Instance.new("IntValue")
	length.Name = "Length"
	length.Value = Config.INITIAL_SEGMENTS
	length.Parent = leaderstats

	-- Spawn snake after client has loaded
	task.delay(2, function()
		if player.Parent then
			spawnSnake(player)
		end
	end)
end

local function onPlayerRemoving(player)
	print("[Loongoliers] Player leaving:", player.Name)
	local snake = snakes[player.UserId]
	if snake then
		if snake.model and snake.model.Parent then
			snake.model:Destroy()
		end
		snakes[player.UserId] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ============================================================================
-- MAIN GAME LOOP
-- ============================================================================
RunService.Heartbeat:Connect(function(dt)
	-- Move snakes
	for _, snake in pairs(snakes) do
		if snake.alive then
			moveSnake(snake, dt)
		end
	end

	-- Check collisions
	checkCoinCollisions()
	checkSnakeCollisions()

	-- Spawn coins
	coinSpawnTimer = coinSpawnTimer + dt
	if coinSpawnTimer >= Config.COIN_SPAWN_INTERVAL then
		coinSpawnTimer = 0
		if activeCoinCount < Config.MAX_COINS then
			spawnRandomCoin()
		end
	end

	-- Broadcast state to clients
	updateTimer = updateTimer + dt
	if updateTimer >= Config.SNAKE_UPDATE_RATE then
		updateTimer = 0
		broadcastState()
	end
end)

print("==============================================")
print("[Loongoliers] SERVER FULLY INITIALIZED")
print("[Loongoliers] Arena: " .. Config.MAP_SIZE .. "x" .. Config.MAP_SIZE)
print("[Loongoliers] Coins: " .. activeCoinCount)
print("[Loongoliers] Waiting for players...")
print("==============================================")
