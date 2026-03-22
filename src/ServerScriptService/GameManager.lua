-- GameManager: Core server-side orchestrator for the Loongoliers game
-- Handles player connections, game state, map setup, and coordinates subsystems

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local SnakeController = require(ServerScriptService.SnakeController)
local CoinSpawner = require(ServerScriptService.CoinSpawner)

local GameManager = {}

-- Remote events for client-server communication
local remotes = {}

function GameManager.init()
	-- Disable default character spawning
	Players.CharacterAutoLoads = false

	-- Create remote events
	GameManager.createRemotes()

	-- Build the arena
	GameManager.createArena()

	-- Initialize subsystems
	CoinSpawner.init()
	SnakeController.init(remotes)

	-- Player connection handlers
	Players.PlayerAdded:Connect(function(player)
		GameManager.onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		GameManager.onPlayerRemoving(player)
	end)

	-- Handle players that joined before this script loaded
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(GameManager.onPlayerAdded, player)
	end

	-- Main game loop
	RunService.Heartbeat:Connect(function(dt)
		SnakeController.update(dt)
		CoinSpawner.update(dt)
	end)

	print("[GameManager] Loongoliers initialized")
end

function GameManager.createRemotes()
	-- Input remote: client sends direction input
	local inputEvent = Instance.new("RemoteEvent")
	inputEvent.Name = "InputEvent"
	inputEvent.Parent = ReplicatedStorage
	remotes.InputEvent = inputEvent

	-- Snake update remote: server broadcasts snake states
	local snakeUpdate = Instance.new("RemoteEvent")
	snakeUpdate.Name = "SnakeUpdate"
	snakeUpdate.Parent = ReplicatedStorage
	remotes.SnakeUpdate = snakeUpdate

	-- Death notification remote
	local deathEvent = Instance.new("RemoteEvent")
	deathEvent.Name = "DeathEvent"
	deathEvent.Parent = ReplicatedStorage
	remotes.DeathEvent = deathEvent

	-- Leaderboard update remote
	local leaderUpdate = Instance.new("RemoteEvent")
	leaderUpdate.Name = "LeaderUpdate"
	leaderUpdate.Parent = ReplicatedStorage
	remotes.LeaderUpdate = leaderUpdate
end

function GameManager.createArena()
	-- Create the arena floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(GameConfig.MAP_SIZE, 1, GameConfig.MAP_SIZE)
	floor.Position = Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(20, 20, 30)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = workspace

	-- Grid pattern using decals or texture
	local texture = Instance.new("Texture")
	texture.Texture = "rbxassetid://6372755229" -- Grid texture
	texture.StudsPerTileU = 10
	texture.StudsPerTileV = 10
	texture.Face = Enum.NormalId.Top
	texture.Transparency = 0.8
	texture.Parent = floor

	-- Arena boundary walls
	local wallHeight = 10
	local wallThickness = 2
	local half = GameConfig.MAP_HALF

	local wallData = {
		{name = "WallNorth", pos = Vector3.new(0, wallHeight/2, -half), size = Vector3.new(GameConfig.MAP_SIZE, wallHeight, wallThickness)},
		{name = "WallSouth", pos = Vector3.new(0, wallHeight/2, half), size = Vector3.new(GameConfig.MAP_SIZE, wallHeight, wallThickness)},
		{name = "WallEast", pos = Vector3.new(half, wallHeight/2, 0), size = Vector3.new(wallThickness, wallHeight, GameConfig.MAP_SIZE)},
		{name = "WallWest", pos = Vector3.new(-half, wallHeight/2, 0), size = Vector3.new(wallThickness, wallHeight, GameConfig.MAP_SIZE)},
	}

	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	arenaFolder.Parent = workspace
	floor.Parent = arenaFolder

	for _, data in ipairs(wallData) do
		local wall = Instance.new("Part")
		wall.Name = data.name
		wall.Size = data.size
		wall.Position = data.pos
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.Neon
		wall.Color = Color3.fromRGB(255, 50, 50)
		wall.Transparency = 0.5
		wall.Parent = arenaFolder
		CollectionService:AddTag(wall, "ArenaBoundary")
	end

	print("[GameManager] Arena created")
end

function GameManager.onPlayerAdded(player)
	-- Set up leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local length = Instance.new("IntValue")
	length.Name = "Length"
	length.Value = GameConfig.INITIAL_SEGMENTS
	length.Parent = leaderstats

	-- Spawn the snake after a short delay to ensure client is ready
	task.delay(1, function()
		if player.Parent then
			SnakeController.spawnSnake(player)
		end
	end)

	print("[GameManager] Player joined:", player.Name)
end

function GameManager.onPlayerRemoving(player)
	SnakeController.removeSnake(player)
	print("[GameManager] Player left:", player.Name)
end

return GameManager
