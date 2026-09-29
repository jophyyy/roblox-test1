# Stage-Based Dungeon Tower (Stages 1–5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 5-stage Dungeon Tower system where players enter an ancient trial arena from the Town Ruins, defeat increasingly strong waves of mobs on Stages 1–4, and face an Infernal Magma Golem boss on Stage 5 with scaling rewards.

**Architecture:** A modular server-client architecture featuring `DungeonConfig` for stage and reward specifications, `DungeonService` for arena building, wave management, mob procedural assembly, and hit detection, and `DungeonClient` for the real-time HUD (stage counter, mob counter, countdowns, and boss health bar).

**Tech Stack:** Luau (Roblox), Rojo, TweenService, RunService, Remotes.

**Spec:** [docs/superpowers/specs/2026-09-29-dungeon-tower-design.md](file:///Users/jophychen/.gemini/antigravity-ide/scratch/roblox-tycoon-simulator/docs/superpowers/specs/2026-09-29-dungeon-tower-design.md)

## Global Constraints
- Target platform: Roblox / Luau (`--!strict`).
- Stud design aesthetic: All spawned mobs, arena structures, and portals must feature authentic tactile Roblox studs (`Enum.SurfaceType.Studs`).
- Pickaxe Combat: Players damage mobs and bosses using their equipped pickaxe (`PickaxeService`) and receive buffs from equipped pets (`PetService`).
- Safety & Persistence: Players leaving or dying in the dungeon must respawn safely in town at the spawn dais without losing character data or previously cleared stage rewards.

## Review Focus
1. Player disconnecting or resetting character mid-stage: Arena must safely reset to Idle without leaking threads, orphaned mobs, or blocking future runs.
2. Multiple players entering portal simultaneously: Arena must gracefully accommodate co-op participants or handle queue state without desyncing stage counters.
3. Mob pathfinding when player jumps onto arena perimeter walls: Mobs must not get permanently stuck; fallback aggro checks ensure hitboxes remain targetable.
4. Boss defeat timing race condition: When Magma Golem reaches 0 HP, attack loops must terminate immediately before victory rewards and confetti fire.
5. Pickaxe damage calculation: Ensure critical hits and pickaxe special traits (*GoldRush*, *Stun*, *MoltenBurn*) correctly register on dungeon mobs as they do on world bosses.

---

### Task 1: Dungeon Configuration (`DungeonConfig.luau`)

**Files:**
- Create: `src/shared/Config/DungeonConfig.luau`

**Interfaces:**
- Produces:
  - `DungeonConfig.ARENA_CENTER: Vector3`
  - `DungeonConfig.PLAYER_SPAWN: Vector3`
  - `DungeonConfig.TOWN_PORTAL_POS: Vector3`
  - `DungeonConfig.STAGES: { [number]: StageDef }`
  - `DungeonConfig.getStage(stageNum: number): StageDef?`

- [ ] **Step 1: Write `DungeonConfig.luau`**
Create `src/shared/Config/DungeonConfig.luau` with complete types, stage mob statistics, rewards, colors, and coordinates:
```lua
--!strict
export type MobDef = {
	name: string,
	count: number,
	maxHealth: number,
	attackDamage: number,
	walkSpeed: number,
	size: Vector3,
	color: Color3,
	eyeColor: Color3,
	material: Enum.Material,
}

export type StageReward = {
	cash: number,
	gems: number,
	crateId: string?,
	masteryXP: { track: string, amount: number }?,
}

export type StageDef = {
	stageNumber: number,
	title: string,
	isBoss: boolean,
	bossId: string?,
	mobs: MobDef?,
	reward: StageReward,
}

local DungeonConfig = {}

DungeonConfig.ARENA_CENTER = Vector3.new(300, 20, 0)
DungeonConfig.PLAYER_SPAWN = Vector3.new(300, 21.5, 30)
DungeonConfig.EXIT_PORTAL = Vector3.new(300, 21.5, 36)
DungeonConfig.TOWN_PORTAL_POS = Vector3.new(-92, 0.5, -92)
DungeonConfig.ARENA_RADIUS = 38

DungeonConfig.STAGES = {
	[1] = {
		stageNumber = 1,
		title = "Cave Imps",
		isBoss = false,
		mobs = {
			name = "Cave Imp",
			count = 3,
			maxHealth = 1000,
			attackDamage = 8,
			walkSpeed = 12,
			size = Vector3.new(3, 3, 3),
			color = Color3.fromRGB(56, 85, 45),
			eyeColor = Color3.fromRGB(120, 255, 60),
			material = Enum.Material.Cobblestone,
		},
		reward = { cash = 15000, gems = 50 },
	},
	[2] = {
		stageNumber = 2,
		title = "Ruin Skeletons",
		isBoss = false,
		mobs = {
			name = "Ruin Skeleton",
			count = 4,
			maxHealth = 2800,
			attackDamage = 14,
			walkSpeed = 14,
			size = Vector3.new(3.2, 4.5, 3.2),
			color = Color3.fromRGB(180, 185, 190),
			eyeColor = Color3.fromRGB(255, 60, 60),
			material = Enum.Material.Plastic,
		},
		reward = { cash = 35000, gems = 120 },
	},
	[3] = {
		stageNumber = 3,
		title = "Obsidian Golemites",
		isBoss = false,
		mobs = {
			name = "Obsidian Golemite",
			count = 4,
			maxHealth = 6500,
			attackDamage = 20,
			walkSpeed = 15,
			size = Vector3.new(4, 4.5, 4),
			color = Color3.fromRGB(25, 28, 35),
			eyeColor = Color3.fromRGB(0, 240, 255),
			material = Enum.Material.Basalt,
		},
		reward = { cash = 75000, gems = 250, crateId = "crate_wood" },
	},
	[4] = {
		stageNumber = 4,
		title = "Magma Brutes",
		isBoss = false,
		mobs = {
			name = "Magma Brute",
			count = 3,
			maxHealth = 14000,
			attackDamage = 28,
			walkSpeed = 13,
			size = Vector3.new(5.5, 6.5, 5.5),
			color = Color3.fromRGB(140, 35, 15),
			eyeColor = Color3.fromRGB(255, 200, 30),
			material = Enum.Material.CrackedLava,
		},
		reward = { cash = 150000, gems = 500, crateId = "crate_iron" },
	},
	[5] = {
		stageNumber = 5,
		title = "Infernal Magma Golem",
		isBoss = true,
		bossId = "InfernalMagmaGolem",
		reward = {
			cash = 500000,
			gems = 2000,
			crateId = "crate_gold",
			masteryXP = { track = "BossSlayer", amount = 500 },
		},
	},
}

function DungeonConfig.getStage(stageNum: number): StageDef?
	return DungeonConfig.STAGES[stageNum]
end

return DungeonConfig
```

- [ ] **Step 2: Verify `DungeonConfig.luau` compiles**
Run `rojo build -o place.rbxl` and ensure zero errors.

- [ ] **Step 3: Commit**
`git add src/shared/Config/DungeonConfig.luau && git commit -m "feat: add DungeonConfig with stages 1-5 definitions"`

---

### Task 2: Server Dungeon Service (`DungeonService.luau`)

**Files:**
- Create: `src/server/Services/DungeonService.luau`

**Interfaces:**
- Consumes:
  - `DungeonConfig` (stages, coordinates, rewards)
  - `BossService` (for spawning Stage 5 Infernal Magma Golem model)
  - `DataService` (for awarding Cash, Gems, Crates, Mastery XP)
  - `Remotes` (`DungeonStateUpdated`, `EnterDungeon`, `LeaveDungeon`, `DamageDungeonMob`)
- Produces:
  - `DungeonService.init()`
  - `DungeonService.buildArena()`
  - `DungeonService.startDungeonRun(player: Player)`
  - `DungeonService.damageMob(player: Player, mobModel: Model)`

- [ ] **Step 1: Implement `DungeonService.luau`**
Implement the service with:
1. `buildArena()`: Procedural 3D studded stone arena at `(300, 20, 0)` with pillars, braziers, runic floor, safety walls, and return portal.
2. `buildTownPortal()`: Portal at Town Ruins `(-92, 0.5, -92)` with ProximityPrompt `Enter Dungeon Tower`.
3. `startDungeonRun(player)`: Teleports player, initializes Stage 1 countdown, and connects player health / disconnect hooks.
4. `spawnStage(stageNum)`:
   - Stages 1–4: Spawns mob models with custom stud bodies, glowing eyes, Humanoids, overhead Billboard health bars, and an active aggro pursuit loop.
   - Stage 5: Spawns the Stage 5 Infernal Magma Golem with 35,000 HP and fires the boss bar event to clients.
5. Combat listener: Listens for pickaxe swings (`MiningClient.performSwing` / weapon hits) against dungeon mobs, calculates player damage with pickaxe traits, and emits floating damage popups.
6. Stage completion & Victory: Awards stage rewards via `DataService`, updates quest progress if applicable, transitions to next stage after 4-second breather, and spawns the Victory Portal on Stage 5 clear.

- [ ] **Step 2: Verify syntax & build**
Run `rojo build -o place.rbxl` and ensure clean exit code.

- [ ] **Step 3: Commit**
`git add src/server/Services/DungeonService.luau && git commit -m "feat: implement DungeonService with wave state machine and mob combat"`

---

### Task 3: Client Dungeon Controller & HUD (`DungeonClient.luau`)

**Files:**
- Create: `src/client/Controllers/DungeonClient.luau`

**Interfaces:**
- Consumes:
  - `Remotes.getEvent("DungeonStateUpdated")`
  - `Remotes.getEvent("DungeonBossUpdated")`
  - `Remotes.getFunction("LeaveDungeon")`
- Produces:
  - `DungeonClient.init()`
  - `DungeonClient.showStageBanner(stageNum: number, stageTitle: string)`
  - `DungeonClient.updateHUD(stateInfo: any)`

- [ ] **Step 1: Implement `DungeonClient.luau`**
Create a retro-stud styled client controller:
1. **Top Center HUD**:
   - `🏰 DUNGEON TOWER • STAGE [X] / 5`
   - `💀 Mobs Remaining: [N]` (switches dynamically to Boss Health Bar on Stage 5).
2. **Countdown Banner**: Dramatic 3-second animated countdown (`STAGE [X] IN 3... 2... 1...`) with audio chimes.
3. **Stage Clear Banner**: Pop-in victory card displaying stage rewards earned.
4. **Boss Health Bar**: Chunky gold/crimson health bar on top of screen for Stage 5 Infernal Magma Golem.
5. **Exit Button**: `🚪 Leave Tower` button at top-right allowing voluntary forfeit / return to town.

- [ ] **Step 2: Verify compilation**
Run `rojo build -o place.rbxl`.

- [ ] **Step 3: Commit**
`git add src/client/Controllers/DungeonClient.luau && git commit -m "feat: implement DungeonClient HUD and stage announcements"`

---

### Task 4: System Integration & Wiring

**Files:**
- Modify: `src/server/init.server.luau` (initialize `DungeonService`)
- Modify: `src/client/init.client.luau` (initialize `DungeonClient`)
- Modify: `src/server/Services/MapService.luau` (trigger dungeon town portal creation)
- Modify: `src/client/Controllers/MiningClient.luau` (route pickaxe swings to dungeon mobs when in dungeon arena)

**Interfaces:**
- Consumes: `DungeonService`, `DungeonClient`
- Produces: End-to-end operational flow from town portal to stage 5 victory.

- [ ] **Step 1: Wire `init.server.luau`**
Add `DungeonService` to `services` table in `src/server/init.server.luau`.

- [ ] **Step 2: Wire `init.client.luau`**
Add `DungeonClient` to client initialization list in `src/client/init.client.luau`.

- [ ] **Step 3: Connect hit-testing in `MiningClient.luau` or `DungeonService`**
Ensure that when a player swings in the Dungeon Arena, hits register against active dungeon mobs and call `DamageDungeonMob`.

- [ ] **Step 4: Verify complete build**
Run `rojo build -o place.rbxl`.

- [ ] **Step 5: Commit**
`git add src/server/init.server.luau src/client/init.client.luau src/server/Services/MapService.luau && git commit -m "feat: wire DungeonService and DungeonClient into game loop"`

---

### Task 5: End-to-End Verification & Place Delivery

**Files:**
- Binary: `place.rbxl`
- Docs: `walkthrough.md`

- [ ] **Step 1: Compile full place file**
Run `rojo build -o place.rbxl`.

- [ ] **Step 2: Update `walkthrough.md` with complete testing steps**
Document coordinates, how to enter the portal, wave progression 1–5, mob stats, and Stage 5 Magma Golem battle.

- [ ] **Step 3: Commit and push to origin/main**
`git push origin main`
