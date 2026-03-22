-- CoinTemplate: Creates the PirateCoin part template
-- Used by CoinSpawner to instantiate coins efficiently

local GameConfig = require(script.Parent.GameConfig)

local CoinTemplate = {}

function CoinTemplate.create()
	local coin = Instance.new("Part")
	coin.Name = "PirateCoin"
	coin.Size = GameConfig.COIN_SIZE
	coin.Shape = Enum.PartType.Ball
	coin.Material = Enum.Material.Neon
	coin.Color = Color3.fromRGB(255, 215, 0) -- Gold
	coin.Anchored = true
	coin.CanCollide = false
	coin.Position = Vector3.new(0, GameConfig.COIN_SPAWN_HEIGHT, 0)

	-- Glow effect
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 0)
	light.Brightness = 0.5
	light.Range = 6
	light.Parent = coin

	return coin
end

return CoinTemplate
