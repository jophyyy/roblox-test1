# Lucky Block Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the legacy Crate/LootBox system into an authentic Lucky Block Subsystem with physical in-world quarry spawns, 3D block-shattering cutscene animations, Mega Jackpots, and a modernized Lucky Block Vault UI.

**Architecture:** A unified server-client architecture featuring `LuckyBlockConfig` for tier and reward definitions (with backward compatibility aliases for legacy crate IDs), `LuckyBlockService` for quarry spawning and pickaxe breaking, `LuckyBlockAnimation` for the cinematic 3D '?' block shatter sequence, and `UIController` for the modernized vault modal.

**Tech Stack:** Luau (Roblox), Rojo, TweenService, Debris, Remotes.

**Spec:** [docs/superpowers/specs/2026-09-29-lucky-block-system-design.md](file:///Users/jophychen/.gemini/antigravity-ide/scratch/roblox-tycoon-simulator/docs/superpowers/specs/2026-09-29-lucky-block-system-design.md)

## Global Constraints
- Target platform: Roblox / Luau (`--!strict`).
- Stud design aesthetic: All physical Lucky Blocks must feature tactile studs on all faces (`Enum.SurfaceType.Studs`) with high-contrast `?` markings.
- Zero Data Loss: Existing player inventories under `data.LootBoxes` must seamlessly map to `data.LuckyBlocks` without losing any owned crates or blocks.
- Mega Jackpot: 10% chance on opening to trigger a 3x multiplier with special celebratory fireworks.

## Review Focus
1. Backward compatibility: Ensure opening a legacy `crate_gold` correctly maps to `block_gold` reward tables and decrements inventory without nil indexing errors.
2. In-world quarry blocks: Multiple players hitting the same quarry block must count hits cleanly and reward the mining player without spawning multiple loot bursts.
3. Rapid clicking during opening cutscene: The "CRACK OPEN" button must disable until the shatter animation concludes to prevent duplicate server invocations.
4. Camera / Viewport safety during animation: The 3D hovering block must position safely relative to the player's Camera without clipping into walls or player character.
5. Cross-system loot consistency: Quests, Dungeon Tower, and Codes that award boxes/blocks must deliver valid Lucky Block IDs.

---

### Task 1: Lucky Block Configuration (`LuckyBlockConfig.luau`)

**Files:**
- Create: `src/shared/Config/LuckyBlockConfig.luau`

**Interfaces:**
- Produces:
  - `LuckyBlockConfig.BLOCKS: { [string]: LuckyBlockDef }`
  - `LuckyBlockConfig.ORDERED_IDS: { string }`
  - `LuckyBlockConfig.getBlock(id: string): LuckyBlockDef?`
  - `LuckyBlockConfig.rollReward(blockId: string): RewardItem`
  - `LuckyBlockConfig.resolveBlockId(id: string): string` (maps `crate_*` to `block_*`)

- [ ] **Step 1: Write `LuckyBlockConfig.luau`**
Implement the configuration module with the 5 Lucky Block tiers, drop tables, color palettes, and ID aliasing:
```lua
--!strict
export type LuckyBlockTier = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type RewardItem = {
	type: "Cash" | "Gems" | "Pet" | "Rebirth" | "MasteryXP",
	name: string,
	amount: number,
	rarity: LuckyBlockTier,
	petId: string?,
	isMegaJackpot: boolean?,
}

export type LuckyBlockDef = {
	id: string,
	name: string,
	tier: LuckyBlockTier,
	description: string,
	cubeColor: Color3,
	questionColor: Color3,
	lightColor: Color3,
	material: Enum.Material,
	priceCash: number,
	priceGems: number,
	rewards: {
		{ weight: number, reward: RewardItem }
	},
}

local LuckyBlockConfig = {}

LuckyBlockConfig.TIER_COLORS = {
	Common = Color3.fromRGB(150, 95, 50),
	Rare = Color3.fromRGB(0, 180, 240),
	Epic = Color3.fromRGB(255, 215, 0),
	Legendary = Color3.fromRGB(0, 240, 255),
	Mythic = Color3.fromRGB(255, 60, 200),
} :: { [LuckyBlockTier]: Color3 }

-- ID Resolver to support legacy crate_* keys
function LuckyBlockConfig.resolveBlockId(rawId: string): string
	local aliases: { [string]: string } = {
		["crate_wood"] = "block_wood",
		["crate_iron"] = "block_iron",
		["crate_gold"] = "block_gold",
		["crate_diamond"] = "block_diamond",
		["crate_cosmic"] = "block_cosmic",
	}
	return aliases[rawId] or rawId
end
```

- [ ] **Step 2: Verify `LuckyBlockConfig.luau` compilation**
Run `rojo build -o place.rbxl`.

- [ ] **Step 3: Commit**
`git add src/shared/Config/LuckyBlockConfig.luau && git commit -m "feat(luckyblock): add LuckyBlockConfig with 5 tiers and legacy aliases"`

---

### Task 2: Server Lucky Block Service (`LuckyBlockService.luau`)

**Files:**
- Create: `src/server/Services/LuckyBlockService.luau`
- Modify: `src/server/Services/DataService.luau` (add alias helper for LuckyBlocks)

**Interfaces:**
- Consumes:
  - `LuckyBlockConfig`
  - `DataService`
  - `Remotes` (`OpenLuckyBlock`, `MineQuarryLuckyBlock`, `LuckyBlockDropped`)
- Produces:
  - `LuckyBlockService.init()`
  - `LuckyBlockService.spawnQuarryBlock()`
  - `LuckyBlockService.hitQuarryBlock(player: Player, blockModel: Model)`
  - `LuckyBlockService.openBlock(player: Player, blockId: string): (boolean, RewardItem?)`

- [ ] **Step 1: Implement `LuckyBlockService.luau`**
Implement the service with:
1. Periodic in-world quarry spawning: Spawns a physical 4×4×4 stud Lucky Block with `?` SurfaceGuis, glowing PointLight, and vertical beacon light in active quarry fields every 75–120 seconds.
2. 3-hit pickaxe mining: When struck by player pickaxes, it springs/shakes, emits wood/gold chips, and on the 3rd strike shatters into physics debris, awards instant Cash/Gems + adds a free Lucky Block to inventory.
3. Inventory opening remote `OpenLuckyBlock`: Validates player inventory, checks for 10% Mega Jackpot multiplier, grants rewards via `DataService`, and returns the rolled reward item to client.
4. Dev cheat remote `DevAddLuckyBlocks`: Grants 5 of each block tier for easy testing.

- [ ] **Step 2: Update `DataService.luau`**
Add helper methods and ensure `data.LootBoxes` and `data.LuckyBlocks` are synchronized so existing crates remain accessible as Lucky Blocks.

- [ ] **Step 3: Verify compilation**
Run `rojo build -o place.rbxl`.

- [ ] **Step 4: Commit**
`git add src/server/Services/LuckyBlockService.luau src/server/Services/DataService.luau && git commit -m "feat(luckyblock): implement LuckyBlockService with quarry spawning and opening remote"`

---

### Task 3: Client 3D Block Shatter Cutscene (`LuckyBlockAnimation.luau`)

**Files:**
- Create: `src/client/Controllers/LuckyBlockAnimation.luau`

**Interfaces:**
- Consumes:
  - `LuckyBlockConfig`
  - `TweenService`
  - `SoundService`
- Produces:
  - `LuckyBlockAnimation.playOpen(blockDef: LuckyBlockConfig.LuckyBlockDef, reward: LuckyBlockConfig.RewardItem, onClaim: () -> ())`

- [ ] **Step 1: Implement `LuckyBlockAnimation.luau`**
Implement the 3D block shattering sequence:
1. Cinematic backdrop: Dim screen with soft vignette.
2. Hovering 3D '?' Block: Procedural 4×4×4 stud cube positioned in front of player Camera with bold `?` on all faces and spinning idle animation.
3. Anticipation charge-up: Block ascends slightly, accelerates vibration shake, and emits bright glowing light rays from seams.
4. Shatter explosion: Splits into 8 debris fragments flying outwards with a glowing shockwave ring, star particles, and celebratory pop sound.
5. Reward card & Mega Jackpot reveal: Displays item icon (Cash, Gems, Pet, Crate), rarity badge, and if `isMegaJackpot`, flashes gold fireworks with "🌟 MEGA JACKPOT (3X) 🌟".
6. Claim button: Dismisses cutscene smoothly and triggers callback.

- [ ] **Step 2: Verify compilation**
Run `rojo build -o place.rbxl`.

- [ ] **Step 3: Commit**
`git add src/client/Controllers/LuckyBlockAnimation.luau && git commit -m "feat(luckyblock): implement 3D block shatter cutscene and jackpot celebration"`

---

### Task 4: UI Modernization & Dock Integration

**Files:**
- Modify: `src/client/Controllers/UIController.luau`
- Modify: `src/client/Controllers/MiningClient.luau` (route pickaxe swings to quarry lucky blocks)

**Interfaces:**
- Consumes: `LuckyBlockConfig`, `LuckyBlockAnimation`, `Remotes`
- Produces: Updated menu button and restyled Lucky Block Vault modal.

- [ ] **Step 1: Update `UIController.luau`**
1. Replace left dock button: `createStudMenuButton("LuckyBlockBtn", "❓ LUCKY BLOCKS", Color3.fromRGB(245, 170, 0), openLuckyBlockModal, sideMenu)`.
2. Restyle the modal: Title `❓ LUCKY BLOCK VAULT`, 3D question-mark block cards with count pills, and `CRACK OPEN` / `CRACK 5X` buttons connected to `LuckyBlockAnimation.playOpen`.
3. Update live badge count reflecting total Lucky Blocks owned.

- [ ] **Step 2: Update `MiningClient.luau`**
Add target detection priority for physical in-world Lucky Blocks so swinging pickaxes near a quarry Lucky Block hits and damages it.

- [ ] **Step 3: Verify compilation**
Run `rojo build -o place.rbxl`.

- [ ] **Step 4: Commit**
`git add src/client/Controllers/UIController.luau src/client/Controllers/MiningClient.luau && git commit -m "feat(luckyblock): modernize UI to Lucky Block Vault and connect pickaxe mining"`

---

### Task 5: System Integration & Verification

**Files:**
- Modify: `src/server/init.server.luau` (replace `LootBoxService` with `LuckyBlockService`)
- Modify: `src/client/init.client.luau`
- Modify: `src/shared/Config/QuestConfig.luau` & `src/shared/Config/DungeonConfig.luau` (replace `crate_*` with `block_*`)
- Binary: `place.rbxl`
- Docs: `walkthrough.md`

- [ ] **Step 1: Wire server & client entrypoints**
Initialize `LuckyBlockService` in `init.server.luau`.

- [ ] **Step 2: Update Quest & Dungeon reward references**
Map crate rewards in `QuestConfig` and `DungeonConfig` to the new `block_*` IDs.

- [ ] **Step 3: Recompile complete place file**
Run `rojo build -o place.rbxl`.

- [ ] **Step 4: Update `walkthrough.md`**
Document all Lucky Block features, quarry mining, opening cutscenes, and testing instructions.

- [ ] **Step 5: Commit and push to origin/main**
`git push origin main`
