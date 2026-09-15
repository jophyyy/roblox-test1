--!strict
-- QuestConfig: Comprehensive configuration for Main Quests, Daily Bounties, and Board Quests

export type QuestCategory = "Main" | "Daily" | "Bounty"

export type QuestTargetType =
	| "MineOres"
	| "HatchPets"
	| "FusePets"
	| "Rebirth"
	| "DefeatBoss"
	| "SpinWheel"
	| "SellPets"
	| "EarnCash"

export type QuestReward = {
	Cash: number,
	Gems: number,
	Crates: { [string]: number }?,
	MasteryXP: { track: string, amount: number }?,
}

export type QuestDef = {
	id: string,
	title: string,
	description: string,
	category: QuestCategory,
	targetType: QuestTargetType,
	targetCount: number,
	icon: string,
	badge: string,
	rewards: QuestReward,
	order: number,
}

local QuestConfig = {}

-- Main Progression Storyline Quests (Completed sequentially or unlocked as players progress)
QuestConfig.MAIN_QUESTS = {
	{
		id = "quest_first_mine",
		title = "Rookie Excavator",
		description = "Mine 10 Ore Veins across the town and quarry.",
		category = "Main",
		targetType = "MineOres",
		targetCount = 10,
		icon = "⛏️",
		badge = "MAIN #1",
		rewards = { Cash = 5000, Gems = 150 },
		order = 1,
	},
	{
		id = "quest_pet_companion",
		title = "Loyal Menagerie",
		description = "Hatch 3 Pets from the Prism Shrine or sanctuary.",
		category = "Main",
		targetType = "HatchPets",
		targetCount = 3,
		icon = "🐾",
		badge = "MAIN #2",
		rewards = { Cash = 15000, Gems = 300, Crates = { ["crate_wood"] = 1 } },
		order = 2,
	},
	{
		id = "quest_lucky_spin",
		title = "Wheel of Fortune",
		description = "Spin the Lucky Wheel 1 time in the town square.",
		category = "Main",
		targetType = "SpinWheel",
		targetCount = 1,
		icon = "🎡",
		badge = "MAIN #3",
		rewards = { Cash = 20000, Gems = 250 },
		order = 3,
	},
	{
		id = "quest_pet_fusion",
		title = "Alchemical Fusion",
		description = "Fuse duplicate pets at the Pet Fusion Lab to upgrade them.",
		category = "Main",
		targetType = "FusePets",
		targetCount = 1,
		icon = "⚗️",
		badge = "MAIN #4",
		rewards = { Cash = 40000, Gems = 500, MasteryXP = { track = "PetFusion", amount = 100 } },
		order = 4,
	},
	{
		id = "quest_deep_quarry",
		title = "Quarry Veteran",
		description = "Mine 35 Ore Veins to prove your mining prowess.",
		category = "Main",
		targetType = "MineOres",
		targetCount = 35,
		icon = "💎",
		badge = "MAIN #5",
		rewards = { Cash = 75000, Gems = 800, Crates = { ["crate_iron"] = 1 } },
		order = 5,
	},
	{
		id = "quest_pet_trader",
		title = "Finneas's Deal",
		description = "Sell 2 unused pets to Finneas the Pet Merchant.",
		category = "Main",
		targetType = "SellPets",
		targetCount = 2,
		icon = "💰",
		badge = "MAIN #6",
		rewards = { Cash = 100000, Gems = 600 },
		order = 6,
	},
	{
		id = "quest_first_rebirth",
		title = "Prestige Ascension",
		description = "Complete 1 Rebirth to ascend to new power heights.",
		category = "Main",
		targetType = "Rebirth",
		targetCount = 1,
		icon = "⚡",
		badge = "MAIN #7",
		rewards = { Cash = 300000, Gems = 2000, Crates = { ["crate_gold"] = 2 }, MasteryXP = { track = "Rebirth", amount = 200 } },
		order = 7,
	},
	{
		id = "quest_boss_slayer",
		title = "Colosseum Champion",
		description = "Deal 500 damage to the Magma Golem or Boss in the Arena.",
		category = "Main",
		targetType = "DefeatBoss",
		targetCount = 500,
		icon = "👹",
		badge = "MAIN #8",
		rewards = { Cash = 750000, Gems = 3500, Crates = { ["crate_diamond"] = 1 }, MasteryXP = { track = "BossSlayer", amount = 300 } },
		order = 8,
	},
} :: { QuestDef }

-- Daily Bounties Available on the Town Quest Board
QuestConfig.DAILY_BOUNTIES = {
	{
		id = "daily_mine_25",
		title = "Daily Quota: 25 Ores",
		description = "Excavate 25 Ore Veins across the quarry.",
		category = "Daily",
		targetType = "MineOres",
		targetCount = 25,
		icon = "⛏️",
		badge = "DAILY",
		rewards = { Cash = 60000, Gems = 350 },
		order = 1,
	},
	{
		id = "daily_mine_60",
		title = "Heavy Quarry Duty",
		description = "Excavate 60 Ore Veins in deep stone fields.",
		category = "Daily",
		targetType = "MineOres",
		targetCount = 60,
		icon = "⛏️",
		badge = "DAILY",
		rewards = { Cash = 180000, Gems = 900, Crates = { ["crate_iron"] = 1 } },
		order = 2,
	},
	{
		id = "daily_hatch_4",
		title = "Daily Hatchery",
		description = "Hatch 4 Pets from any egg shrine.",
		category = "Daily",
		targetType = "HatchPets",
		targetCount = 4,
		icon = "🥚",
		badge = "DAILY",
		rewards = { Cash = 90000, Gems = 500, Crates = { ["crate_wood"] = 2 } },
		order = 3,
	},
	{
		id = "daily_earn_cash",
		title = "Bounty: 250k Cash",
		description = "Earn a total of $250,000 Cash from mining or trading.",
		category = "Daily",
		targetType = "EarnCash",
		targetCount = 250000,
		icon = "💵",
		badge = "DAILY",
		rewards = { Cash = 50000, Gems = 700 },
		order = 4,
	},
	{
		id = "daily_sell_pets",
		title = "Menagerie Liquidator",
		description = "Sell 3 unused pets to Finneas at his shop.",
		category = "Daily",
		targetType = "SellPets",
		targetCount = 3,
		icon = "🐾",
		badge = "DAILY",
		rewards = { Cash = 140000, Gems = 550 },
		order = 5,
	},
	{
		id = "daily_boss_strike",
		title = "Arena Skirmish",
		description = "Deal 300 damage to the Arena Boss.",
		category = "Daily",
		targetType = "DefeatBoss",
		targetCount = 300,
		icon = "⚔️",
		badge = "DAILY",
		rewards = { Cash = 250000, Gems = 1200, MasteryXP = { track = "BossSlayer", amount = 150 } },
		order = 6,
	},
} :: { QuestDef }

-- Fast lookup by Quest ID
local questLookup: { [string]: QuestDef } = {}
for _, q in ipairs(QuestConfig.MAIN_QUESTS) do
	questLookup[q.id] = q
end
for _, q in ipairs(QuestConfig.DAILY_BOUNTIES) do
	questLookup[q.id] = q
end

function QuestConfig.getQuest(id: string): QuestDef?
	return questLookup[id]
end

function QuestConfig.getAllQuests(): { QuestDef }
	local all: { QuestDef } = {}
	for _, q in ipairs(QuestConfig.MAIN_QUESTS) do
		table.insert(all, q)
	end
	for _, q in ipairs(QuestConfig.DAILY_BOUNTIES) do
		table.insert(all, q)
	end
	return all
end

-- Default active quests for brand new players (first main quest automatically ready)
function QuestConfig.getDefaultAcceptedQuests(): { string }
	return { "quest_first_mine" }
end

return QuestConfig
