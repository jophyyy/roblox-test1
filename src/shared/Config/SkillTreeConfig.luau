--!strict
export type SkillNode = {
	id: string,
	name: string,
	branch: "Root" | "Power" | "Speed" | "Luck",
	tier: number,
	cost: number,
	icon: string,
	color: Color3,
	description: string,
	parent: string?,
	speedBonus: number,
	miningPowerMult: number,
	cashMultiplier: number,
	bonusGems: number,
	bossMultiplier: number,
	position: Vector2, -- Relative coordinates (0.0 to 1.0) inside tree canvas
}

local SkillTreeConfig = {}

SkillTreeConfig.BRANCHES = {
	Root = {
		name = "Awakening",
		color = Color3.fromRGB(255, 220, 80),
		icon = "🌟",
	},
	Power = {
		name = "Might & Boss Slayer",
		color = Color3.fromRGB(255, 80, 60),
		icon = "⚔️",
	},
	Speed = {
		name = "Velocity & Mobility",
		color = Color3.fromRGB(40, 210, 255),
		icon = "⚡",
	},
	Luck = {
		name = "Fortune & Abundance",
		color = Color3.fromRGB(210, 110, 255),
		icon = "👑",
	},
}

SkillTreeConfig.NODES = {
	node_base = {
		id = "node_base",
		name = "Mining Awakening",
		branch = "Root",
		tier = 0,
		cost = 100,
		icon = "🌟",
		color = Color3.fromRGB(255, 215, 80),
		description = "Awaken your latent mining instincts, boosting your base efficiency across all disciplines.",
		parent = nil,
		speedBonus = 2,
		miningPowerMult = 1.10,
		cashMultiplier = 1.10,
		bonusGems = 0,
		bossMultiplier = 1.05,
		position = Vector2.new(0.50, 0.85),
	},

	-- POWER BRANCH (Left Column)
	power_1 = {
		id = "power_1",
		name = "Heavy Impact",
		branch = "Power",
		tier = 1,
		cost = 500,
		icon = "🔨",
		color = Color3.fromRGB(255, 95, 65),
		description = "Channel kinetic force into pickaxe strikes, dealing heavier damage to ores and bosses.",
		parent = "node_base",
		speedBonus = 0,
		miningPowerMult = 1.25,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 1.15,
		position = Vector2.new(0.20, 0.60),
	},
	power_2 = {
		id = "power_2",
		name = "Shatter Force",
		branch = "Power",
		tier = 2,
		cost = 2500,
		icon = "💥",
		color = Color3.fromRGB(255, 60, 60),
		description = "Pulverize dense rock formations and crush boss armor with devastating shockwaves.",
		parent = "power_1",
		speedBonus = 0,
		miningPowerMult = 1.60,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 1.35,
		position = Vector2.new(0.20, 0.36),
	},
	power_3 = {
		id = "power_3",
		name = "Titan Decimator",
		branch = "Power",
		tier = 3,
		cost = 12000,
		icon = "⚔️",
		color = Color3.fromRGB(255, 25, 95),
		description = "Legendary colossus-breaking might granting massive 2.5x ore damage and 2.0x boss damage.",
		parent = "power_2",
		speedBonus = 0,
		miningPowerMult = 2.50,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 2.00,
		position = Vector2.new(0.20, 0.12),
	},

	-- SPEED BRANCH (Center Column)
	speed_1 = {
		id = "speed_1",
		name = "Swift Stride",
		branch = "Speed",
		tier = 1,
		cost = 500,
		icon = "👟",
		color = Color3.fromRGB(50, 200, 255),
		description = "Lighten your movement gear for swift traversal between ore deposits across zones.",
		parent = "node_base",
		speedBonus = 4,
		miningPowerMult = 1.0,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 1.0,
		position = Vector2.new(0.50, 0.60),
	},
	speed_2 = {
		id = "speed_2",
		name = "Wind Dash",
		branch = "Speed",
		tier = 2,
		cost = 2500,
		icon = "💨",
		color = Color3.fromRGB(30, 235, 235),
		description = "Harness atmospheric wind currents to boost both walking speed and sprinting velocity.",
		parent = "speed_1",
		speedBonus = 8,
		miningPowerMult = 1.0,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 1.0,
		position = Vector2.new(0.50, 0.36),
	},
	speed_3 = {
		id = "speed_3",
		name = "Chronos Step",
		branch = "Speed",
		tier = 3,
		cost = 12000,
		icon = "⚡",
		color = Color3.fromRGB(75, 255, 210),
		description = "Warp through the mines with extreme velocity, making long distance traversal instantaneous.",
		parent = "speed_2",
		speedBonus = 16,
		miningPowerMult = 1.0,
		cashMultiplier = 1.0,
		bonusGems = 0,
		bossMultiplier = 1.0,
		position = Vector2.new(0.50, 0.12),
	},

	-- LUCK & FORTUNE BRANCH (Right Column)
	luck_1 = {
		id = "luck_1",
		name = "Crystal Scent",
		branch = "Luck",
		tier = 1,
		cost = 500,
		icon = "💎",
		color = Color3.fromRGB(180, 100, 255),
		description = "Develop keen instincts for hidden crystal geodes, awarding +1 bonus Gem per ore mined.",
		parent = "node_base",
		speedBonus = 0,
		miningPowerMult = 1.0,
		cashMultiplier = 1.25,
		bonusGems = 1,
		bossMultiplier = 1.0,
		position = Vector2.new(0.80, 0.60),
	},
	luck_2 = {
		id = "luck_2",
		name = "Golden Touch",
		branch = "Luck",
		tier = 2,
		cost = 2500,
		icon = "💰",
		color = Color3.fromRGB(220, 130, 255),
		description = "Transmute base rock fragments into pure gold veins, boosting cash earnings and gem yield.",
		parent = "luck_1",
		speedBonus = 0,
		miningPowerMult = 1.0,
		cashMultiplier = 1.75,
		bonusGems = 3,
		bossMultiplier = 1.0,
		position = Vector2.new(0.80, 0.36),
	},
	luck_3 = {
		id = "luck_3",
		name = "Midas Blessing",
		branch = "Luck",
		tier = 3,
		cost = 12000,
		icon = "👑",
		color = Color3.fromRGB(255, 215, 0),
		description = "Supreme royal favor granting triple (3.0x) cash earnings and +8 bonus gems on every ore.",
		parent = "luck_2",
		speedBonus = 0,
		miningPowerMult = 1.0,
		cashMultiplier = 3.00,
		bonusGems = 8,
		bossMultiplier = 1.0,
		position = Vector2.new(0.80, 0.12),
	},
} :: { [string]: SkillNode }

SkillTreeConfig.NODE_ORDER = {
	"node_base",
	"power_1",
	"power_2",
	"power_3",
	"speed_1",
	"speed_2",
	"speed_3",
	"luck_1",
	"luck_2",
	"luck_3",
}

function SkillTreeConfig.getNode(id: string?): SkillNode?
	if id and SkillTreeConfig.NODES[id] then
		return SkillTreeConfig.NODES[id]
	end
	return nil
end

-- A node is unlocked if it's in the unlockedMap
function SkillTreeConfig.isUnlocked(id: string, unlockedMap: { [string]: boolean }?): boolean
	if not unlockedMap then return false end
	return unlockedMap[id] == true
end

-- A node can be unlocked if:
-- 1. It is not already unlocked
-- 2. It has no parent (Root), OR its parent IS unlocked
function SkillTreeConfig.canUnlock(id: string, unlockedMap: { [string]: boolean }?): boolean
	if SkillTreeConfig.isUnlocked(id, unlockedMap) then
		return false
	end
	local node = SkillTreeConfig.getNode(id)
	if not node then return false end
	if not node.parent then
		return true
	end
	return SkillTreeConfig.isUnlocked(node.parent, unlockedMap)
end

-- Fog of War check:
-- A node is revealed/visible if:
-- 1. It is the Root node, OR
-- 2. Its parent is already unlocked (it is the next discovered talent in line!), OR
-- 3. It is itself already unlocked
function SkillTreeConfig.isRevealed(id: string, unlockedMap: { [string]: boolean }?): boolean
	local node = SkillTreeConfig.getNode(id)
	if not node then return false end
	if not node.parent then return true end
	if SkillTreeConfig.isUnlocked(id, unlockedMap) then return true end
	return SkillTreeConfig.isUnlocked(node.parent, unlockedMap)
end

-- Aggregator calculations across all unlocked nodes
function SkillTreeConfig.getTotalSpeedBonus(unlockedMap: { [string]: boolean }?): number
	if not unlockedMap then return 0 end
	local total = 0
	for id, unlocked in pairs(unlockedMap) do
		if unlocked then
			local node = SkillTreeConfig.getNode(id)
			if node then
				total += node.speedBonus
			end
		end
	end
	return total
end

function SkillTreeConfig.getTotalMiningPowerMult(unlockedMap: { [string]: boolean }?): number
	if not unlockedMap then return 1.0 end
	local mult = 1.0
	for id, unlocked in pairs(unlockedMap) do
		if unlocked then
			local node = SkillTreeConfig.getNode(id)
			if node and node.miningPowerMult > 1.0 then
				mult *= node.miningPowerMult
			end
		end
	end
	return mult
end

function SkillTreeConfig.getTotalCashMult(unlockedMap: { [string]: boolean }?): number
	if not unlockedMap then return 1.0 end
	local mult = 1.0
	for id, unlocked in pairs(unlockedMap) do
		if unlocked then
			local node = SkillTreeConfig.getNode(id)
			if node and node.cashMultiplier > 1.0 then
				mult *= node.cashMultiplier
			end
		end
	end
	return mult
end

function SkillTreeConfig.getTotalBonusGems(unlockedMap: { [string]: boolean }?): number
	if not unlockedMap then return 0 end
	local total = 0
	for id, unlocked in pairs(unlockedMap) do
		if unlocked then
			local node = SkillTreeConfig.getNode(id)
			if node then
				total += node.bonusGems
			end
		end
	end
	return total
end

function SkillTreeConfig.getTotalBossMult(unlockedMap: { [string]: boolean }?): number
	if not unlockedMap then return 1.0 end
	local mult = 1.0
	for id, unlocked in pairs(unlockedMap) do
		if unlocked then
			local node = SkillTreeConfig.getNode(id)
			if node and node.bossMultiplier > 1.0 then
				mult *= node.bossMultiplier
			end
		end
	end
	return mult
end

return SkillTreeConfig
