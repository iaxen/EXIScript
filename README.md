# EXIScript

## Launch

Run this in your Roblox client's executor after joining a supported game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/iaxen/EXIScript/main/EXIScript.lua?exis=" .. tostring(os.time())))()
```

The query refreshes the launcher URL. The launcher also adds a build/time query when downloading the selected game file. Both repositories must contain the merged changes: this repository chooses the game, and [EXIS_Games](https://github.com/iaxen/EXIS_Games) contains its implementation.

**Steal an Egg:** wait for the EXIS panel, choose your filters, click **Enable core automation**, then turn on **Master switch**. Master starts off each session; a visible panel with no movement is not a failed launch.

### If execution stops

The loader displays its build and stage: **Detecting game → Downloading → Compiling → Starting**. A failure stays visible with the actual error. The game then has its own native-module startup panel. Closing a status panel only dismisses the message.

- **No status panel and no console message:** check that the command actually ran, that the environment supports `loadstring` and HTTP requests, and that you copied the current command above.
- **Unsupported game:** copy the displayed PlaceId/GameId. Steal an Egg's known place is `107778070777162`; other places can also be detected through their native EggState/PlotState modules.
- **Download failed:** the message includes the HTTP error or response. Check connectivity and repository access; an empty response never counts as execution.
- **Compile failed:** copy the complete compiler error and build string.
- **Starting / native module error:** copy the exact module path and error from the startup panel. The script waits for late modules, but missing or changed native APIs still need investigation.
- **Panel opens but a task fails:** use **Tools → Copy diagnostics** or **Save diagnostics file**. Include the task, recent log and any unconfirmed/pending request. Do not repeatedly re-execute while a mutation is pending.

A mocked startup and compiler pass do not establish compatibility with every live executor. If it still fails, the displayed error is necessary to distinguish HTTP, compilation, native-module loading and game-specific rejection.

## Games

<details>
<summary><strong>🎮 Fuzzotopia: Cozy Hideaway</strong></summary>

> <details>
> <summary><strong>Farming</strong></summary>
>
> - Auto harvest, plant and water
> - Select plants to grow
> - Plant by normal order or highest price first
> - Dig selected plants and rearrange planted crops
> - Auto tend animals when care is needed
> - Optional return to farm
>
> </details>

> <details>
> <summary><strong>Auto Use Items</strong></summary>
>
> - Fairy Dust when no planted crops are ripe
> - Adjustable Fairy Dust minimum stock before starting a batch
> - Lucky Charm and Rainbow Dew during harvesting
> - Separate 10-minute buff cooldowns
>
> </details>

> <details>
> <summary><strong>Shops</strong></summary>
>
> - Auto buy selected normal seeds, special seeds and gear
> - Restock checks and stock-aware purchasing
> - Seed and gear diagnostics
>
> </details>

> <details>
> <summary><strong>Market</strong></summary>
>
> - Auto sell anytime or during Market Boom
> - Sell selected crops or detect the most expensive offers
> - Sell fitting offers in descending unit-price order
> - Adjustable money limit and cap safeguards
> - Inventory value estimates and selling diagnostics
>
> </details>

> <details>
> <summary><strong>Forest</strong></summary>
>
> - Auto chop selected tree types
> - Walk or teleport between trees
> - Auto collect forest drops
> - Trade Golden Acorns with the mushroom-house fairy
> - Trade Candy for Fairy Dust with regular fairies
>
> </details>

> <details>
> <summary><strong>Progression</strong></summary>
>
> - Auto quests, orders and Mayor tasks
> - Auto house and garden upgrades
>
> </details>

> <details>
> <summary><strong>Fishing</strong></summary>
>
> - Auto fishing
>
> </details>

> <details>
> <summary><strong>Home</strong></summary>
>
> - Import JSON furniture layouts
> - Validate layouts and preview furniture footprints
> - Place or move owned furniture
> - Export house data
> - Stop an active house build
>
> </details>

> <details>
> <summary><strong>Social and Travel</strong></summary>
>
> - Play owned and free emotes
> - Join another player’s emote
> - Coin emote purchase controls
> - Open Photo Mode
> - Travel shortcuts, including Sunset Cove
>
> </details>

> <details>
> <summary><strong>Leaderboards and Events</strong></summary>
>
> - Leaderboard viewer
> - Island Event tracking
> - Saved observed event frequencies
>
> </details>

> <details>
> <summary><strong>Interface and Settings</strong></summary>
>
> - Compact blue-and-black interface
> - Switch toggles and collapsible sections
> - Small square EXIS launcher
> - Resizable panel
> - Save and load config
> - Task priority scheduling and category stop controls
> - Anti-idle
> - Auto execute and reconnect options
> - Optional leave when another player joins
>
> </details>

</details>

---

<details>
<summary><strong>🎮 MrbeastIslandEscape</strong></summary>

> <details>
> <summary><strong>Survival</strong></summary>
>
> - Cook collected food and eat cooked food only
> - Adjustable health and hunger thresholds
> - Native melee/ranged attacks, exact quest material hunts, counterattacks and evasion
>
> </details>

> <details>
> <summary><strong>Gathering</strong></summary>
>
> - Auto gather resources with matching owned tools
> - Select individual resources or gather all when no filter is selected
> - Auto collect selected or all unprotected drops
> - Respect drop-owner protection
> - Select all and clear selection controls
>
> </details>

> <details>
> <summary><strong>Campfire</strong></summary>
>
> - Auto add wood below an adjustable fuel target
> - Auto cook selected food
> - Auto collect cooked food
>
> </details>

> <details>
> <summary><strong>Furnace and Water Maker</strong></summary>
>
> - Auto feed furnace ingredients
> - Auto collect furnace output
> - Auto collect water-maker coconuts
>
> </details>

> <details>
> <summary><strong>Crafting and Construction</strong></summary>
>
> - Auto craft selected missing tools and armour
> - Check recipe materials before crafting
> - Contribute materials to selected unfinished buildings
>
> </details>

> <details>
> <summary><strong>Quests and Rewards</strong></summary>
>
> - Deliver items for the current MrBeast quest
> - Auto claim eligible daily and weekly rewards
> - Auto claim eligible playtime rewards
> - Claim completed daily-quest rewards
>
> </details>

> <details>
> <summary><strong>Exploration and Escape</strong></summary>
>
> - Auto open unlocked chests
> - Auto interact with puzzle props
> - Building travel shortcuts
> - Auto use an available escape-boat prompt
>
> </details>

> <details>
> <summary><strong>Fishing</strong></summary>
>
> - Auto cast while equipped with a rod and facing water
> - Auto reel on a bite
> - Fish minigame remains manual
> - Unavailable fishing yields to other jobs
>
> </details>

> <details>
> <summary><strong>Interface and Settings</strong></summary>
>
> - Compact blue-and-black interface
> - Switch toggles and expandable categories
> - Small square EXIS launcher
> - English labels where available; numbered fallback labels
> - Separate saved config
> - Walk or teleport movement
> - Adjustable action delay
> - Independent task error handling and alternating movement turns
> - Stop all tasks
> - Anti-idle
> - Per-task status and copyable diagnostics
>
> </details>

</details>

---

<details>
<summary><strong>🎮 Zombie Rush Survival — Initial Test Release</strong></summary>

> <details>
> <summary><strong>Classes · Lobby</strong></summary>
>
> - Expandable class list
> - Auto buy selected classes
> - Auto upgrade selected classes' defenses
> - Equip an owned class
>
> </details>

> <details>
> <summary><strong>Weapons</strong></summary>
>
> - Expandable weapon lists by tier
> - Auto buy selected weapons and upgrade their individual levels
> - Choose and apply each tier's weapon loadout
>
> </details>

> <details>
> <summary><strong>Match and Combat</strong></summary>
>
> - Detect equipped class and active map: Skyline or Crystal Cave
> - Auto Skip toggle
> - Auto health, gun-tier and melee upgrades
> - Grounded turret-area evasion, head aiming and native fire-input controls
> - Boss-first targeting
> - Adjustable movement and threat-distance controls
>
> </details>

> <details>
> <summary><strong>Defense and Area Selection</strong></summary>
>
> - Auto place the equipped class's selected structural defenses
> - Select a map floor part or draw a connected dot boundary
> - Save a separate placement area for each map
> - Front barricades and interior turrets
> - Reserve a support gap and place an available Healing Station between defenses
> - Account for existing defenses, grid footprints, currency and placement rejections
> - Adjustable owned-defense limit and cash reserve
>
> </details>

> <details>
> <summary><strong>Interface and Settings</strong></summary>
>
> - Compact blue-and-black EXIS interface
> - Sidebar categories with expanding child sections
> - Switch toggles, draggable square EXIS icon and resizable panel
> - Separate saved configuration
> - Mobile-button and native-mouse fire input options
> - Copyable diagnostics
>
> </details>

</details>


---

<details>
<summary><strong>🎮 Steal an Egg — Initial Native Automation</strong></summary>

- Highest-rarity-first field egg selection; distance breaks ties
- Biome, rarity and pet-category exclusions
- Teleport approach, native pickup timing and walking/pathfinding return to your own base
- Carry-loss and ownership-receipt checks
- Plant inventory eggs and trigger ready eggs' native hatch presentation
- Native equip-best pets and idle treadmill training
- Optional affordable cash base/treadmill upgrades and discovered index rewards
- Optional matching, unequipped, nonfavorite duplicate fusion; consumes pets and cash
- Light vs Darkness rings, Sammy pickups and field event eggs
- **Performance:** hide other players' pen visuals, native hide-other/self-pet preferences, reduced details/shadows/textures/effects and disabled treadmill videos
- **EXIS Tools:** live FPS/task/native-module diagnostics, copy/print/save logs, save/reload settings while paused, snapshot refresh, anti-idle, rejoin, optional teleport execution and connection-loss reconnect
- Reversible visuals; collisions, prompts and native game state are retained
- Settings and saved diagnostics under `EXIGames/StealAnEgg`

Full race driving, obby routes, dimension boss fights and other multi-stage events are not implemented. No code redemption, paid purchases, automatic selling or rebirth is added. Live gameplay and performance gains remain unverified. See the [native audit](https://github.com/iaxen/EXIS_Games/blob/main/Docs/StealAnEgg_Native_Audit.md) for exact coverage and limitations.

</details>
