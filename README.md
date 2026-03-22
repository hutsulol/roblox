# Loongoliers — Slither.io for Roblox

## SETUP (READ CAREFULLY)

You only need **3 scripts**. The script TYPE matters — wrong type = nothing runs.

### Step-by-step in Roblox Studio:

#### 1. ServerInit (SERVER SCRIPT)
- In Explorer, right-click **ServerScriptService**
- Click **Insert Object** > **Script** (the plain one, NOT ModuleScript)
- Rename it to `ServerInit`
- Paste the contents of `src/ServerScriptService/ServerInit.lua`

#### 2. InputHandler (LOCAL SCRIPT)
- In Explorer, expand **StarterPlayer** > right-click **StarterPlayerScripts**
- Click **Insert Object** > **LocalScript**
- Rename it to `InputHandler`
- Paste the contents of `src/StarterPlayerScripts/InputHandler.lua`

#### 3. UIController (LOCAL SCRIPT)
- In same **StarterPlayerScripts** folder
- Click **Insert Object** > **LocalScript**
- Rename it to `UIController`
- Paste the contents of `src/StarterPlayerScripts/UIController.lua`

#### 4. DELETE everything else
- Delete any old scripts from previous attempts
- Delete old ModuleScripts from ReplicatedStorage (GameConfig, SnakeTemplate, CoinTemplate)
- Make sure ServerScriptService has ONLY `ServerInit`
- Make sure StarterPlayerScripts has ONLY `InputHandler` and `UIController`

### How to verify script types by icon:

| Script type | Icon | Runs by itself? |
|-------------|------|-----------------|
| **Script** | Grey scroll icon | YES (on server) |
| **LocalScript** | Blue icon with monitor/screen | YES (on client) |
| ModuleScript | Orange/brown puzzle icon | NO (needs require) |

### What you should see when you press Play:

1. **Output window** (View > Output): lots of `[Server]` messages
2. **Black floor** with 4 red walls
3. **Yellow coins** scattered everywhere
4. **Your snake** (colored ball + white/colored segments) appears after 2 seconds
5. **Mouse** controls snake direction
6. **"Coins: 0"** display top-left
7. **"SHOP"** button top-right
8. Touching coins grows your snake and increases counter

### Architecture

```
ServerScriptService/
  ServerInit          <- Script (ALL server logic, zero require() calls)

StarterPlayer/
  StarterPlayerScripts/
    InputHandler      <- LocalScript (mouse → angle → server)
    UIController      <- LocalScript (camera + coins UI + shop + death screen)
```

That's it. 3 files. No modules. No require(). No chains.
