-- ServerInit: Entry point for the Loongoliers game server
-- This is the main server script that bootstraps the game

local ServerScriptService = game:GetService("ServerScriptService")
local GameManager = require(ServerScriptService.GameManager)

-- Initialize the game
GameManager.init()

print("[Loongoliers] Server started successfully")
