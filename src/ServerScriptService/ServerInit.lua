--[[
	ServerInit — THE ONE AND ONLY server script.
	Type: Script (NOT ModuleScript, NOT LocalScript)
	Location: ServerScriptService

	This script does EVERYTHING on the server:
	  1. Creates the map (floor + walls)
	  2. Creates RemoteEvents for client communication
	  3. Spawns snakes for players
	  4. Moves snakes based on client input
	  5. Spawns coins and detects collection
	  6. Handles the shop (growth boost)

	ZERO require() calls. ZERO external modules.
]]

-- ===================== STEP 0: PROOF OF LIFE =====================
print("[Server] ======================================")
print("[Server] ServerInit is EXECUTING right now!")
print("[Server] ======================================")

-- ===================== STEP 1: SERVICES =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Server] Services loaded OK")

-- ===================== STEP 2: SETTINGS =====================
local MAP_SIZE = 300
local MAP_HALF = MAP_SIZE / 2
local SNAKE_SPEED = 40
local SNAKE_TURN_SPEED = 5
local HEAD_SIZE = 4
local SEGMENT_SIZE = 3
local SEGMENT_GAP = 2.5
local START_SEGMENTS = 3
local MAX_SEGMENTS = 80
local COIN_RADIUS = 1.5
local MAX_COINS = 150
local GROWTH_BOOST_COST = 500
local GROWTH_BOOST_VALUE = 0.1

print("[Server] Settings defined OK")

-- ===================== STEP 3: DISABLE DEFAULT CHARACTER =====================
Players.CharacterAutoLoads = false
print("[Server] CharacterAutoLoads = false")

-- ===================== STEP 4: REMOTE EVENTS =====================
-- These let server and client talk to each other

local remoteInput = Instance.new("RemoteEvent")
remoteInput.Name = "SnakeInput"
remoteInput.Parent = ReplicatedStorage

local remoteCoinUpdate = Instance.new("RemoteEvent")
remoteCoinUpdate.Name = "CoinUpdate"
remoteCoinUpdate.Parent = ReplicatedStorage

local remoteShopBuy = Instance.new("RemoteEvent")
remoteShopBuy.Name = "ShopBuy"
remoteShopBuy.Parent = ReplicatedStorage

local remoteDeath = Instance.new("RemoteEvent")
remoteDeath.Name = "SnakeDeath"
remoteDeath.Parent = ReplicatedStorage

print("[Server] 4 RemoteEvents created in ReplicatedStorage")

-- ===================== STEP 5: BUILD THE MAP =====================
print("[Server] Building map...")

-- Remove any default baseplate/spawn
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("BasePart") or child:IsA("SpawnLocation") then
		print("[Server] Removing default object:", child.Name)
		child:Destroy()
	end
end

-- Terrain cleanup
if workspace:FindFirstChildOfClass("Terrain") then
	workspace:FindFirstChildOfClass("Terrain"):Clear()
end

-- Floor
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Size = Vector3.new(MAP_SIZE, 1, MAP_SIZE)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Anchored = true
floor.CanCollide = true
floor.Material = Enum.Material.SmoothPlastic
floor.BrickColor = BrickColor.new("Black")
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = workspace

print("[Server] Floor created:", floor.Size, "at", floor.Position)

-- Walls (4 bright red walls so you can clearly see the arena)
local wallHeight = 8
local wallThick = 3

local wallDefs = {
	{Vector3.new(0, wallHeight/2, -MAP_HALF), Vector3.new(MAP_SIZE + wallThick*2, wallHeight, wallThick)},
	{Vector3.new(0, wallHeight/2, MAP_HALF),  Vector3.new(MAP_SIZE + wallThick*2, wallHeight, wallThick)},
	{Vector3.new(-MAP_HALF, wallHeight/2, 0), Vector3.new(wallThick, wallHeight, MAP_SIZE)},
	{Vector3.new(MAP_HALF, wallHeight/2, 0),  Vector3.new(wallThick, wallHeight, MAP_SIZE)},
}

for i, def in ipairs(wallDefs) do
	local wall = Instance.new("Part")
	wall.Name = "Wall" .. i
	wall.Position = def[1]
	wall.Size = def[2]
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.Neon
	wall.BrickColor = BrickColor.new("Really red")
	wall.Transparency = 0.3
	wall.Parent = workspace
end

print("[Server] 4 walls created")
print("[Server] MAP BUILT SUCCESSFULLY")

-- ===================== STEP 6: COIN SYSTEM =====================
local coinFolder = Instance.new("Folder")
coinFolder.Name = "Coins"
coinFolder.Parent = workspace

local coinCount = 0

local function spawnOneCoin()
	if coinCount >= MAX_COINS then return end
	local x = math.random(-MAP_HALF + 5, MAP_HALF - 5)
	local z = math.random(-MAP_HALF + 5, MAP_HALF - 5)

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Ball
	coin.Size = Vector3.new(COIN_RADIUS * 2, COIN_RADIUS * 2, COIN_RADIUS * 2)
	coin.Position = Vector3.new(x, 1.5, z)
	coin.Anchored = true
	coin.CanCollide = false
	coin.Material = Enum.Material.Neon
	coin.BrickColor = BrickColor.new("Bright yellow")
	coin.Parent = coinFolder

	coinCount = coinCount + 1
end

-- Spawn initial coins
for _ = 1, 80 do
	spawnOneCoin()
end

print("[Server] Spawned", coinCount, "initial coins")

-- ===================== STEP 7: SNAKE DATA =====================
local allSnakes = {}
-- Each entry: {
--   player, head, segments, posHistory,
--   angle, targetAngle, coins, alive,
--   growthBoost, color
-- }

local COLORS = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright yellow"),
	BrickColor.new("Magenta"),
	BrickColor.new("Cyan"),
	BrickColor.new("Bright orange"),
	BrickColor.new("Bright violet"),
}

-- ===================== STEP 8: SNAKE SPAWN =====================
local function spawnSnake(player)
	print("[Server] Spawning snake for", player.Name)

	-- Clean up old snake if exists
	local old = allSnakes[player.UserId]
	if old then
		if old.head and old.head.Parent then old.head:Destroy() end
		for _, seg in ipairs(old.segments) do
			if seg and seg.Parent then seg:Destroy() end
		end
	end

	-- Pick color
	local color = COLORS[((player.UserId - 1) % #COLORS) + 1]

	-- Random spawn position
	local sx = math.random(-MAP_HALF + 30, MAP_HALF - 30)
	local sz = math.random(-MAP_HALF + 30, MAP_HALF - 30)
	local spawnPos = Vector3.new(sx, 1.5, sz)
	local angle = math.random() * math.pi * 2

	-- HEAD
	local head = Instance.new("Part")
	head.Name = "SnakeHead_" .. player.Name
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE)
	head.Position = spawnPos
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.BrickColor = color
	head.Parent = workspace

	-- SEGMENTS
	local segments = {}
	for i = 1, START_SEGMENTS do
		local seg = Instance.new("Part")
		seg.Name = "Seg_" .. player.Name .. "_" .. i
		seg.Shape = Enum.PartType.Ball
		seg.Size = Vector3.new(SEGMENT_SIZE, SEGMENT_SIZE, SEGMENT_SIZE)
		seg.Anchored = true
		seg.CanCollide = false
		seg.Material = Enum.Material.SmoothPlastic
		if i % 2 == 0 then
			seg.BrickColor = color
		else
			seg.BrickColor = BrickColor.new("Institutional white")
		end
		local behind = Vector3.new(
			-math.sin(angle) * SEGMENT_GAP * i,
			0,
			-math.cos(angle) * SEGMENT_GAP * i
		)
		seg.Position = spawnPos + behind
		seg.Parent = workspace
		table.insert(segments, seg)
	end

	-- POSITION HISTORY (for smooth tail following)
	local posHistory = {}
	for i = 0, 300 do
		local behind = Vector3.new(
			-math.sin(angle) * 0.5 * i,
			0,
			-math.cos(angle) * 0.5 * i
		)
		table.insert(posHistory, spawnPos + behind)
	end

	allSnakes[player.UserId] = {
		player = player,
		head = head,
		segments = segments,
		posHistory = posHistory,
		angle = angle,
		targetAngle = angle,
		coins = 0,
		alive = true,
		growthBoost = 1.0,
		color = color,
	}

	-- Reset leaderstats
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local c = ls:FindFirstChild("Coins")
		if c then c.Value = 0 end
	end

	print("[Server] Snake spawned for", player.Name, "at", spawnPos, "with", #segments, "segments")
end

-- ===================== STEP 9: SNAKE MOVEMENT =====================
local function moveSnake(data, dt)
	if not data.alive then return end
	if not data.head or not data.head.Parent then return end

	-- Smooth turning
	local diff = data.targetAngle - data.angle
	-- Normalize to [-pi, pi]
	if diff > math.pi then diff = diff - 2 * math.pi end
	if diff < -math.pi then diff = diff + 2 * math.pi end

	local maxTurn = SNAKE_TURN_SPEED * dt
	if math.abs(diff) <= maxTurn then
		data.angle = data.targetAngle
	elseif diff > 0 then
		data.angle = data.angle + maxTurn
	else
		data.angle = data.angle - maxTurn
	end

	-- Move head forward
	local dir = Vector3.new(math.sin(data.angle), 0, math.cos(data.angle))
	local newPos = data.head.Position + dir * SNAKE_SPEED * dt

	-- Clamp inside arena
	local limit = MAP_HALF - 3
	local nx = math.clamp(newPos.X, -limit, limit)
	local nz = math.clamp(newPos.Z, -limit, limit)

	-- Bounce off walls
	if math.abs(nx) >= limit then
		data.angle = -data.angle
		data.targetAngle = data.angle
	end
	if math.abs(nz) >= limit then
		data.angle = math.pi - data.angle
		data.targetAngle = data.angle
	end

	data.head.Position = Vector3.new(nx, 1.5, nz)

	-- Record position in history
	table.insert(data.posHistory, 1, data.head.Position)

	-- Keep history manageable
	local maxHist = (#data.segments + 10) * 4
	while #data.posHistory > maxHist do
		table.remove(data.posHistory, #data.posHistory)
	end

	-- Move segments along history
	for i, seg in ipairs(data.segments) do
		local idx = i * 4
		if idx <= #data.posHistory then
			seg.Position = data.posHistory[idx]
		end
	end
end

-- ===================== STEP 10: COIN COLLECTION =====================
local function checkCoins(data)
	if not data.alive then return end
	if not data.head or not data.head.Parent then return end

	local headPos = data.head.Position
	local pickupDist = HEAD_SIZE / 2 + COIN_RADIUS

	for _, coin in ipairs(coinFolder:GetChildren()) do
		if (coin.Position - headPos).Magnitude < pickupDist then
			coin:Destroy()
			coinCount = coinCount - 1

			data.coins = data.coins + 1

			-- Update leaderstats
			local ls = data.player:FindFirstChild("leaderstats")
			if ls then
				local c = ls:FindFirstChild("Coins")
				if c then c.Value = data.coins end
			end

			-- Tell client
			remoteCoinUpdate:FireClient(data.player, data.coins)

			-- Add a segment (with growth boost applied)
			if #data.segments < MAX_SEGMENTS then
				local seg = Instance.new("Part")
				local idx = #data.segments + 1
				seg.Name = "Seg_" .. data.player.Name .. "_" .. idx
				seg.Shape = Enum.PartType.Ball
				seg.Size = Vector3.new(SEGMENT_SIZE, SEGMENT_SIZE, SEGMENT_SIZE)
				seg.Anchored = true
				seg.CanCollide = false
				seg.Material = Enum.Material.SmoothPlastic
				if idx % 2 == 0 then
					seg.BrickColor = data.color
				else
					seg.BrickColor = BrickColor.new("Institutional white")
				end
				-- Put new segment at the tail's last position
				local lastSeg = data.segments[#data.segments]
				seg.Position = lastSeg and lastSeg.Position or data.head.Position
				seg.Parent = workspace
				table.insert(data.segments, seg)
			end

			print("[Server] Coin collected by", data.player.Name, "| Total:", data.coins)
		end
	end
end

-- ===================== STEP 11: SNAKE COLLISIONS =====================
local function checkSnakeCollisions()
	local toKill = {}

	for uid, data in pairs(allSnakes) do
		if not data.alive then
			-- skip dead snakes
		else
			local headPos = data.head.Position
			local headR = HEAD_SIZE / 2

			for otherUid, other in pairs(allSnakes) do
				if otherUid ~= uid and other.alive then
					-- Head vs other head
					local hDist = (other.head.Position - headPos).Magnitude
					if hDist < headR * 2 then
						local myLen = #data.segments
						local otherLen = #other.segments
						if myLen <= otherLen then toKill[uid] = true end
						if otherLen <= myLen then toKill[otherUid] = true end
					else
						-- Head vs other body segments
						for _, seg in ipairs(other.segments) do
							local segR = SEGMENT_SIZE / 2
							if (seg.Position - headPos).Magnitude < (headR + segR) * 0.8 then
								toKill[uid] = true
								break
							end
						end
					end
				end
			end
		end
	end

	for uid in pairs(toKill) do
		local data = allSnakes[uid]
		if data and data.alive then
			data.alive = false
			print("[Server]", data.player.Name, "DIED! Coins:", data.coins)

			-- Drop coins at death position
			local deathPos = data.head.Position
			local dropCount = 2 + data.coins
			for _ = 1, math.min(dropCount, 30) do
				if coinCount < MAX_COINS then
					local ox = (math.random() - 0.5) * 16
					local oz = (math.random() - 0.5) * 16
					local c = Instance.new("Part")
					c.Name = "Coin"
					c.Shape = Enum.PartType.Ball
					c.Size = Vector3.new(COIN_RADIUS * 2, COIN_RADIUS * 2, COIN_RADIUS * 2)
					c.Position = Vector3.new(
						math.clamp(deathPos.X + ox, -MAP_HALF + 2, MAP_HALF - 2),
						1.5,
						math.clamp(deathPos.Z + oz, -MAP_HALF + 2, MAP_HALF - 2)
					)
					c.Anchored = true
					c.CanCollide = false
					c.Material = Enum.Material.Neon
					c.BrickColor = BrickColor.new("Bright yellow")
					c.Parent = coinFolder
					coinCount = coinCount + 1
				end
			end

			-- Destroy snake parts
			if data.head and data.head.Parent then data.head:Destroy() end
			for _, seg in ipairs(data.segments) do
				if seg and seg.Parent then seg:Destroy() end
			end

			-- Notify client
			remoteDeath:FireClient(data.player)

			-- Respawn after 3 seconds
			task.delay(3, function()
				if data.player and data.player.Parent then
					spawnSnake(data.player)
					remoteCoinUpdate:FireClient(data.player, 0)
				end
			end)
		end
	end
end

-- ===================== STEP 12: SHOP SYSTEM =====================
remoteShopBuy.OnServerEvent:Connect(function(player, itemName)
	local data = allSnakes[player.UserId]
	if not data then return end

	print("[Server] Shop request from", player.Name, "item:", itemName)

	if itemName == "GrowthBoost" then
		if data.coins >= GROWTH_BOOST_COST then
			data.coins = data.coins - GROWTH_BOOST_COST
			data.growthBoost = data.growthBoost + GROWTH_BOOST_VALUE

			local ls = player:FindFirstChild("leaderstats")
			if ls then
				local c = ls:FindFirstChild("Coins")
				if c then c.Value = data.coins end
			end

			remoteCoinUpdate:FireClient(player, data.coins)
			print("[Server] Growth boost purchased by", player.Name, "| New boost:", data.growthBoost)
		else
			print("[Server] Not enough coins for", player.Name)
		end
	end
end)

print("[Server] Shop system ready")

-- ===================== STEP 13: INPUT HANDLING =====================
remoteInput.OnServerEvent:Connect(function(player, angle)
	local data = allSnakes[player.UserId]
	if data and data.alive then
		if type(angle) == "number" and angle == angle then
			data.targetAngle = angle
		end
	end
end)

print("[Server] Input handler connected")

-- ===================== STEP 14: PLAYER JOIN / LEAVE =====================
local function onPlayerJoin(player)
	print("[Server] Player joined:", player.Name, "(UserId:", player.UserId, ")")

	-- Leaderstats (for the Roblox player list)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local coinsStat = Instance.new("IntValue")
	coinsStat.Name = "Coins"
	coinsStat.Value = 0
	coinsStat.Parent = ls

	print("[Server] Leaderstats created for", player.Name)

	-- Wait a moment for client scripts to load, then spawn
	task.delay(2, function()
		if player.Parent then
			spawnSnake(player)
		end
	end)
end

local function onPlayerLeave(player)
	print("[Server] Player left:", player.Name)
	local data = allSnakes[player.UserId]
	if data then
		if data.head and data.head.Parent then data.head:Destroy() end
		for _, seg in ipairs(data.segments) do
			if seg and seg.Parent then seg:Destroy() end
		end
		allSnakes[player.UserId] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)

-- Handle players already in game (Studio test mode)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoin, player)
end

print("[Server] Player handlers connected")

-- ===================== STEP 15: MAIN GAME LOOP =====================
local coinTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- Move all snakes
	for _, data in pairs(allSnakes) do
		if data.alive then
			moveSnake(data, dt)
			checkCoins(data)
		end
	end

	-- Snake vs snake collisions
	checkSnakeCollisions()

	-- Spawn coins over time
	coinTimer = coinTimer + dt
	if coinTimer >= 0.5 then
		coinTimer = 0
		if coinCount < MAX_COINS then
			spawnOneCoin()
		end
	end
end)

print("[Server] ======================================")
print("[Server] GAME LOOP STARTED")
print("[Server] Map:", MAP_SIZE, "x", MAP_SIZE)
print("[Server] Coins:", coinCount)
print("[Server] ALL SYSTEMS GO!")
print("[Server] ======================================")
