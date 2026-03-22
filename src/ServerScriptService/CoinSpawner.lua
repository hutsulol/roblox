-- CoinSpawner: Server-side coin management system
-- Handles spawning, tracking, collection, and death-drop coins

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local CoinTemplate = require(ReplicatedStorage.CoinTemplate)

local CoinSpawner = {}

local activeCoinCount = 0
local spawnTimer = 0
local coinFolder = nil

function CoinSpawner.init()
	-- Create a folder in workspace for all coins
	coinFolder = Instance.new("Folder")
	coinFolder.Name = "Coins"
	coinFolder.Parent = workspace

	-- Spawn initial batch of coins
	for _ = 1, math.floor(GameConfig.MAX_COINS / 2) do
		CoinSpawner.spawnCoin()
	end

	print("[CoinSpawner] Initialized with", activeCoinCount, "coins")
end

function CoinSpawner.update(dt)
	spawnTimer = spawnTimer + dt
	if spawnTimer >= GameConfig.COIN_SPAWN_INTERVAL then
		spawnTimer = 0
		if activeCoinCount < GameConfig.MAX_COINS then
			CoinSpawner.spawnCoin()
		end
	end
end

-- Spawn a single coin at a random position within the arena
function CoinSpawner.spawnCoin()
	local half = GameConfig.MAP_HALF - 5 -- Slight margin from walls
	local x = math.random(-half, half)
	local z = math.random(-half, half)

	local coin = CoinTemplate.create()
	coin.Position = Vector3.new(x, GameConfig.COIN_SPAWN_HEIGHT, z)
	coin.Parent = coinFolder
	CollectionService:AddTag(coin, "PirateCoin")

	activeCoinCount = activeCoinCount + 1
	return coin
end

-- Spawn multiple coins at a specific position (used for death drops)
function CoinSpawner.spawnCoinsAtPosition(position, count)
	for _ = 1, count do
		if activeCoinCount >= GameConfig.MAX_COINS then
			break
		end

		local spread = GameConfig.DEATH_DROP_SPREAD
		local offsetX = (math.random() - 0.5) * 2 * spread
		local offsetZ = (math.random() - 0.5) * 2 * spread
		local pos = Vector3.new(
			math.clamp(position.X + offsetX, -GameConfig.MAP_HALF + 2, GameConfig.MAP_HALF - 2),
			GameConfig.COIN_SPAWN_HEIGHT,
			math.clamp(position.Z + offsetZ, -GameConfig.MAP_HALF + 2, GameConfig.MAP_HALF - 2)
		)

		local coin = CoinTemplate.create()
		coin.Position = pos
		coin.Parent = coinFolder
		CollectionService:AddTag(coin, "PirateCoin")

		activeCoinCount = activeCoinCount + 1
	end
end

-- Remove a coin (called when a snake collects it)
function CoinSpawner.removeCoin(coin)
	if coin and coin.Parent then
		CollectionService:RemoveTag(coin, "PirateCoin")
		coin:Destroy()
		activeCoinCount = math.max(0, activeCoinCount - 1)
	end
end

function CoinSpawner.getCoinFolder()
	return coinFolder
end

function CoinSpawner.getActiveCoinCount()
	return activeCoinCount
end

return CoinSpawner
