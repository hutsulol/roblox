-- GameConfig: Shared configuration for the Loongoliers game
-- Both server and client reference these values

local GameConfig = {}

-- Map settings
GameConfig.MAP_SIZE = 500 -- studs (square arena)
GameConfig.MAP_HALF = GameConfig.MAP_SIZE / 2

-- Snake settings
GameConfig.SNAKE_SPEED = 30 -- studs per second
GameConfig.SNAKE_TURN_SPEED = 4 -- radians per second
GameConfig.HEAD_SIZE = Vector3.new(3, 2, 3)
GameConfig.SEGMENT_SIZE = Vector3.new(2.6, 1.8, 2.6)
GameConfig.SEGMENT_SPACING = 2.2 -- studs between segments
GameConfig.INITIAL_SEGMENTS = 3
GameConfig.MAX_SEGMENTS = 100
GameConfig.POSITION_HISTORY_MULTIPLIER = 3 -- positions stored per segment

-- Coin settings
GameConfig.COIN_SIZE = Vector3.new(1.5, 1.5, 1.5)
GameConfig.COIN_SPAWN_INTERVAL = 1 -- seconds
GameConfig.MAX_COINS = 200
GameConfig.COIN_SPAWN_HEIGHT = 1.5

-- Death settings
GameConfig.DEATH_DROP_BASE = 2 -- base coins dropped on death
GameConfig.DEATH_DROP_SPREAD = 8 -- studs radius for coin scatter
GameConfig.RESPAWN_DELAY = 2 -- seconds before respawn

-- Camera settings
GameConfig.CAMERA_HEIGHT = 60 -- studs above snake head
GameConfig.CAMERA_LERP_SPEED = 8

-- Network settings
GameConfig.INPUT_SEND_RATE = 1 / 30 -- 30 times per second
GameConfig.SNAKE_UPDATE_RATE = 1 / 20 -- server broadcast rate

-- Colors
GameConfig.SNAKE_COLORS = {
	Color3.fromRGB(255, 50, 50),   -- Red
	Color3.fromRGB(50, 255, 50),   -- Green
	Color3.fromRGB(50, 50, 255),   -- Blue
	Color3.fromRGB(255, 255, 50),  -- Yellow
	Color3.fromRGB(255, 50, 255),  -- Magenta
	Color3.fromRGB(50, 255, 255),  -- Cyan
	Color3.fromRGB(255, 150, 50),  -- Orange
	Color3.fromRGB(150, 50, 255),  -- Purple
}

return GameConfig
