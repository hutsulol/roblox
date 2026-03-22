# Loongoliers - Slither.io-style Roblox Game

A multiplayer snake game for Roblox where players control snakes, collect PirateCoins, grow in length, and drop coins on death.

## Project Structure

```
src/
├── ReplicatedStorage/              # Shared modules (OPTIONAL, not required)
│   ├── GameConfig.lua              # Config reference (ModuleScript)
│   ├── SnakeTemplate.lua           # Snake factory reference (ModuleScript)
│   └── CoinTemplate.lua            # Coin factory reference (ModuleScript)
├── ServerScriptService/            # Server-side logic
│   └── ServerInit.server.lua       # ALL server logic in one file (Script)
└── StarterPlayerScripts/           # Client-side scripts
    ├── InputHandler.client.lua     # Mouse/touch input (LocalScript)
    └── CameraController.client.lua # Top-down camera (LocalScript)
```

## Setup in Roblox Studio

### CRITICAL: Script types matter!

| File | Location | Script Type |
|------|----------|-------------|
| `ServerInit.server.lua` | ServerScriptService | **Script** |
| `InputHandler.client.lua` | StarterPlayer > StarterPlayerScripts | **LocalScript** |
| `CameraController.client.lua` | StarterPlayer > StarterPlayerScripts | **LocalScript** |
| `GameConfig.lua` | ReplicatedStorage | ModuleScript (optional) |
| `SnakeTemplate.lua` | ReplicatedStorage | ModuleScript (optional) |
| `CoinTemplate.lua` | ReplicatedStorage | ModuleScript (optional) |

### Steps

1. Open Roblox Studio and create a new place (Baseplate is fine, it gets auto-removed)
2. In **ServerScriptService**: Right-click > Insert Object > **Script**. Name it `ServerInit`. Paste contents of `ServerInit.server.lua`
3. In **StarterPlayer > StarterPlayerScripts**: Right-click > Insert Object > **LocalScript**. Name it `InputHandler`. Paste contents of `InputHandler.client.lua`
4. Repeat for `CameraController` as a **LocalScript**
5. The ReplicatedStorage modules are **optional** — all config is inlined in ServerInit
6. Click **Play** to test!

### What you should see

- Output window shows `[Loongoliers] SERVER FULLY INITIALIZED`
- A dark floor (500x500) appears with red boundary walls
- Gold coins scattered across the map
- Your snake spawns after ~2 seconds
- Mouse controls direction, snake auto-moves forward

### Troubleshooting

- **Nothing happens**: Check the Output window (View > Output) for errors
- **No floor/walls**: Make sure ServerInit is a **Script** (not ModuleScript, not LocalScript)
- **Can't move**: Make sure InputHandler is a **LocalScript** in StarterPlayerScripts
- **Camera stuck**: Make sure CameraController is a **LocalScript** in StarterPlayerScripts

## Features

- **Server-authoritative**: All movement, collision, and coin logic runs on the server
- **Smooth snake movement**: Position history system for fluid tail following
- **Coin collection & growth**: Collect PirateCoins to grow longer
- **Death & coin drops**: Dying scatters coins for other players to collect
- **Top-down camera**: Smooth lerp-based camera following the snake head
- **Touch support**: Works on mobile devices
- **Leaderstats**: Coins and Length displayed on the player list
