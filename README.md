# Loongoliers - Slither.io-style Roblox Game

A multiplayer snake game for Roblox where players control snakes, collect PirateCoins, grow in length, and drop coins on death.

## Project Structure

```
src/
├── ReplicatedStorage/          # Shared modules & templates
│   ├── GameConfig.lua          # All configurable game parameters
│   ├── SnakeTemplate.lua       # Snake model/part factory
│   └── CoinTemplate.lua        # PirateCoin part factory
├── ServerScriptService/        # Server-side logic (authoritative)
│   ├── ServerInit.server.lua   # Entry point - bootstraps the game
│   ├── GameManager.lua         # Orchestrator: arena, players, remotes
│   ├── SnakeController.lua     # Snake movement, collision, growth, death
│   └── CoinSpawner.lua         # Coin spawning, collection, death drops
└── StarterPlayerScripts/       # Client-side scripts
    ├── InputHandler.client.lua # Mouse/touch input → server direction
    └── CameraController.client.lua # Top-down camera following snake
```

## Setup in Roblox Studio

1. Open Roblox Studio and create a new Baseplate place
2. Delete all default objects from Workspace (Baseplate, SpawnLocation, etc.)
3. Copy each `.lua` file into the matching Roblox service:
   - `ReplicatedStorage/*.lua` → ModuleScripts in ReplicatedStorage
   - `ServerScriptService/*.lua` → Scripts/ModuleScripts in ServerScriptService
   - `StarterPlayerScripts/*.lua` → LocalScripts in StarterPlayer > StarterPlayerScripts
4. **Important**: `ServerInit.server.lua` must be a **Script** (not ModuleScript). All other server files are **ModuleScripts**. Client files are **LocalScripts**.
5. Play to test!

## Features

- **Server-authoritative**: All movement, collision, and coin logic runs on the server
- **Smooth snake movement**: Position history system for fluid tail following
- **Coin collection & growth**: Collect PirateCoins to grow longer
- **Death & coin drops**: Dying scatters coins for other players to collect
- **Top-down camera**: Smooth lerp-based camera following the snake head
- **Touch support**: Works on mobile devices
- **Leaderstats**: Coins and Length displayed on the player list
- **Configurable**: All parameters in GameConfig.lua

## Configuration

Edit `src/ReplicatedStorage/GameConfig.lua` to tweak:
- Map size, snake speed, turn speed
- Coin spawn rate, max coins
- Initial/max snake length
- Death drop amounts
- Camera height and smoothing
