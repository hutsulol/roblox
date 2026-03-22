-- SnakeController: Server-side snake management
-- Handles spawning, movement, collision detection, growth, and death

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local SnakeTemplate = require(ReplicatedStorage.SnakeTemplate)

local SnakeController = {}

-- Store all active snakes keyed by player UserId
-- Each entry: { player, model, head, segments, positionHistory, angle, coinsCollected, color, alive }
local snakes = {}
local remotes = nil
local updateTimer = 0
local CoinSpawner = nil -- Lazy loaded to avoid circular dependency

local function getCoinSpawner()
	if not CoinSpawner then
		CoinSpawner = require(ServerScriptService.CoinSpawner)
	end
	return CoinSpawner
end

function SnakeController.init(remoteEvents)
	remotes = remoteEvents

	-- Listen for player input
	remotes.InputEvent.OnServerEvent:Connect(function(player, angle)
		local snake = snakes[player.UserId]
		if snake and snake.alive then
			-- Validate input: angle must be a number
			if type(angle) == "number" and angle == angle then -- NaN check
				snake.targetAngle = math.clamp(angle, -math.pi, math.pi)
			end
		end
	end)

	-- Create folder for snake models
	local snakeFolder = Instance.new("Folder")
	snakeFolder.Name = "Snakes"
	snakeFolder.Parent = workspace

	print("[SnakeController] Initialized")
end

-- Get a random spawn position away from other snakes
local function getSpawnPosition()
	local half = GameConfig.MAP_HALF - 20
	for _ = 1, 10 do
		local x = math.random(-half, half)
		local z = math.random(-half, half)
		local pos = Vector3.new(x, 1.5, z)

		-- Check distance from other snakes
		local tooClose = false
		for _, snake in pairs(snakes) do
			if snake.alive and snake.head then
				local dist = (snake.head.Position - pos).Magnitude
				if dist < 30 then
					tooClose = true
					break
				end
			end
		end

		if not tooClose then
			return pos
		end
	end

	-- Fallback: random position
	return Vector3.new(math.random(-half, half), 1.5, math.random(-half, half))
end

-- Assign a color to the player based on their index
local function getSnakeColor(player)
	local colors = GameConfig.SNAKE_COLORS
	local index = (player.UserId % #colors) + 1
	return colors[index]
end

function SnakeController.spawnSnake(player)
	-- Remove existing snake if any
	SnakeController.removeSnake(player)

	local color = getSnakeColor(player)
	local spawnPos = getSpawnPosition()
	local spawnAngle = math.random() * math.pi * 2

	-- Create the snake model
	local model = SnakeTemplate.createSnakeModel(color)
	model.Name = "Snake_" .. player.Name
	model.Parent = workspace.Snakes

	local head = model.PrimaryPart
	head.Position = spawnPos
	head.Color = color

	-- Position eyes
	SnakeController.updateEyes(head, spawnAngle)

	-- Create initial body segments
	local segments = {}
	for i = 1, GameConfig.INITIAL_SEGMENTS do
		local segment = SnakeTemplate.createSegmentPart()
		segment.Name = "Segment_" .. i
		segment.Color = (i % 2 == 0) and color or Color3.new(
			math.clamp(color.R * 0.7, 0, 1),
			math.clamp(color.G * 0.7, 0, 1),
			math.clamp(color.B * 0.7, 0, 1)
		)
		-- Place segment behind the head
		local offset = Vector3.new(
			-math.sin(spawnAngle) * GameConfig.SEGMENT_SPACING * i,
			0,
			-math.cos(spawnAngle) * GameConfig.SEGMENT_SPACING * i
		)
		segment.Position = spawnPos + offset
		segment.Parent = model
		table.insert(segments, segment)
	end

	-- Build initial position history
	local positionHistory = {}
	local maxHistory = GameConfig.MAX_SEGMENTS * GameConfig.POSITION_HISTORY_MULTIPLIER
	for i = 0, maxHistory - 1 do
		local offset = Vector3.new(
			-math.sin(spawnAngle) * (GameConfig.SEGMENT_SPACING / GameConfig.POSITION_HISTORY_MULTIPLIER) * i,
			0,
			-math.cos(spawnAngle) * (GameConfig.SEGMENT_SPACING / GameConfig.POSITION_HISTORY_MULTIPLIER) * i
		)
		table.insert(positionHistory, spawnPos + offset)
	end

	-- Store snake data
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
		leaderstats.Coins.Value = 0
		leaderstats.Length.Value = GameConfig.INITIAL_SEGMENTS
	end

	print("[SnakeController] Snake spawned for", player.Name)
end

function SnakeController.removeSnake(player)
	local snake = snakes[player.UserId]
	if snake then
		if snake.model and snake.model.Parent then
			snake.model:Destroy()
		end
		snakes[player.UserId] = nil
	end
end

-- Update eye positions relative to head direction
function SnakeController.updateEyes(head, angle)
	local leftEye = head:FindFirstChild("LeftEye")
	local rightEye = head:FindFirstChild("RightEye")
	if not leftEye or not rightEye then return end

	local forward = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local right = Vector3.new(math.cos(angle), 0, -math.sin(angle))

	leftEye.Position = head.Position + forward * 1.0 + right * 0.6 + Vector3.new(0, 0.5, 0)
	rightEye.Position = head.Position + forward * 1.0 - right * 0.6 + Vector3.new(0, 0.5, 0)
end

-- Main update loop called every Heartbeat
function SnakeController.update(dt)
	-- Move all snakes
	for userId, snake in pairs(snakes) do
		if snake.alive then
			SnakeController.moveSnake(snake, dt)
		end
	end

	-- Check coin collisions
	SnakeController.checkCoinCollisions()

	-- Check snake-to-snake collisions
	SnakeController.checkSnakeCollisions()

	-- Broadcast snake positions to clients
	updateTimer = updateTimer + dt
	if updateTimer >= GameConfig.SNAKE_UPDATE_RATE then
		updateTimer = 0
		SnakeController.broadcastState()
	end
end

function SnakeController.moveSnake(snake, dt)
	-- Smoothly turn toward target angle
	local angleDiff = snake.targetAngle - snake.angle

	-- Normalize angle difference to [-pi, pi]
	while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
	while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

	local turnAmount = GameConfig.SNAKE_TURN_SPEED * dt
	if math.abs(angleDiff) < turnAmount then
		snake.angle = snake.targetAngle
	else
		snake.angle = snake.angle + math.sign(angleDiff) * turnAmount
	end

	-- Move head forward
	local direction = Vector3.new(math.sin(snake.angle), 0, math.cos(snake.angle))
	local newPos = snake.head.Position + direction * GameConfig.SNAKE_SPEED * dt

	-- Clamp to arena bounds
	local half = GameConfig.MAP_HALF - 2
	newPos = Vector3.new(
		math.clamp(newPos.X, -half, half),
		1.5,
		math.clamp(newPos.Z, -half, half)
	)

	-- Check if snake hit the boundary (optional death on boundary)
	local hitBoundary = math.abs(newPos.X) >= half or math.abs(newPos.Z) >= half
	if hitBoundary then
		-- Bounce the angle instead of killing
		if math.abs(newPos.X) >= half then
			snake.angle = -snake.angle
			snake.targetAngle = snake.angle
		end
		if math.abs(newPos.Z) >= half then
			snake.angle = math.pi - snake.angle
			snake.targetAngle = snake.angle
		end
	end

	snake.head.Position = newPos
	SnakeController.updateEyes(snake.head, snake.angle)

	-- Update position history (insert at front)
	table.insert(snake.positionHistory, 1, newPos)

	-- Trim history to max length
	local maxHistory = (#snake.segments + 5) * GameConfig.POSITION_HISTORY_MULTIPLIER
	while #snake.positionHistory > maxHistory do
		table.remove(snake.positionHistory)
	end

	-- Update segment positions from history
	for i, segment in ipairs(snake.segments) do
		local historyIndex = i * GameConfig.POSITION_HISTORY_MULTIPLIER
		if historyIndex <= #snake.positionHistory then
			segment.Position = snake.positionHistory[historyIndex]
		end
	end
end

function SnakeController.checkCoinCollisions()
	local spawner = getCoinSpawner()
	local coinFolder = spawner.getCoinFolder()
	if not coinFolder then return end

	for _, snake in pairs(snakes) do
		if not snake.alive then continue end

		local headPos = snake.head.Position
		local collectRadius = GameConfig.HEAD_SIZE.X / 2 + GameConfig.COIN_SIZE.X / 2

		for _, coin in ipairs(CollectionService:GetTagged("PirateCoin")) do
			if coin.Parent and (coin.Position - headPos).Magnitude < collectRadius then
				-- Collect the coin
				spawner.removeCoin(coin)
				snake.coinsCollected = snake.coinsCollected + 1

				-- Update leaderstats
				local leaderstats = snake.player:FindFirstChild("leaderstats")
				if leaderstats then
					leaderstats.Coins.Value = snake.coinsCollected
				end

				-- Grow the snake
				SnakeController.addSegment(snake)
			end
		end
	end
end

function SnakeController.addSegment(snake)
	if #snake.segments >= GameConfig.MAX_SEGMENTS then return end

	local segment = SnakeTemplate.createSegmentPart()
	local index = #snake.segments + 1
	segment.Name = "Segment_" .. index
	segment.Color = (index % 2 == 0) and snake.color or Color3.new(
		math.clamp(snake.color.R * 0.7, 0, 1),
		math.clamp(snake.color.G * 0.7, 0, 1),
		math.clamp(snake.color.B * 0.7, 0, 1)
	)

	-- Place at the last known position
	local lastSegment = snake.segments[#snake.segments]
	if lastSegment then
		segment.Position = lastSegment.Position
	else
		segment.Position = snake.head.Position
	end

	segment.Parent = snake.model
	table.insert(snake.segments, segment)

	-- Update leaderstats
	local leaderstats = snake.player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Length.Value = #snake.segments
	end
end

function SnakeController.checkSnakeCollisions()
	local deadSnakes = {}

	for userId, snake in pairs(snakes) do
		if not snake.alive then continue end

		local headPos = snake.head.Position
		local headRadius = GameConfig.HEAD_SIZE.X / 2

		-- Check collision with other snakes' bodies
		for otherUserId, otherSnake in pairs(snakes) do
			if otherUserId == userId or not otherSnake.alive then continue end

			-- Check against other snake's head (head-to-head collision)
			local otherHeadDist = (otherSnake.head.Position - headPos).Magnitude
			if otherHeadDist < headRadius * 2 then
				-- Both snakes die in head-to-head collision
				-- Smaller snake dies, or both if equal
				local myLength = #snake.segments
				local otherLength = #otherSnake.segments
				if myLength <= otherLength then
					deadSnakes[userId] = true
				end
				if otherLength <= myLength then
					deadSnakes[otherUserId] = true
				end
				continue
			end

			-- Check against other snake's body segments
			for _, segment in ipairs(otherSnake.segments) do
				local segRadius = GameConfig.SEGMENT_SIZE.X / 2
				local dist = (segment.Position - headPos).Magnitude
				if dist < (headRadius + segRadius) * 0.8 then
					deadSnakes[userId] = true
					break
				end
			end
		end
	end

	-- Process deaths
	for userId in pairs(deadSnakes) do
		local snake = snakes[userId]
		if snake and snake.alive then
			SnakeController.killSnake(snake)
		end
	end
end

function SnakeController.killSnake(snake)
	snake.alive = false
	local player = snake.player
	local headPos = snake.head.Position

	-- Calculate coin drop
	local dropCount = GameConfig.DEATH_DROP_BASE + snake.coinsCollected

	-- Spawn coins at death position
	local spawner = getCoinSpawner()
	spawner.spawnCoinsAtPosition(headPos, dropCount)

	-- Notify the player
	if remotes and remotes.DeathEvent then
		remotes.DeathEvent:FireClient(player)
	end

	-- Destroy the snake model
	if snake.model and snake.model.Parent then
		snake.model:Destroy()
	end

	print("[SnakeController]", player.Name, "died. Dropped", dropCount, "coins")

	-- Respawn after delay
	task.delay(GameConfig.RESPAWN_DELAY, function()
		if player.Parent then -- Player still in game
			SnakeController.spawnSnake(player)
		end
	end)
end

-- Broadcast all snake states to all clients for interpolation
function SnakeController.broadcastState()
	local stateData = {}

	for userId, snake in pairs(snakes) do
		if snake.alive and snake.head then
			local segmentPositions = {}
			for i, segment in ipairs(snake.segments) do
				segmentPositions[i] = segment.Position
			end

			stateData[userId] = {
				headPosition = snake.head.Position,
				angle = snake.angle,
				segmentPositions = segmentPositions,
				color = {snake.color.R, snake.color.G, snake.color.B},
				playerName = snake.player.Name,
			}
		end
	end

	-- Send to all players
	for _, player in ipairs(Players:GetPlayers()) do
		if remotes and remotes.SnakeUpdate then
			remotes.SnakeUpdate:FireClient(player, stateData)
		end
	end
end

-- Get snake data for a specific player (used by other modules)
function SnakeController.getSnake(player)
	return snakes[player.UserId]
end

-- Get all active snakes
function SnakeController.getAllSnakes()
	return snakes
end

return SnakeController
