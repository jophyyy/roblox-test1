--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

export type LootBoxTier = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type RewardCategory = "Cash" | "Gems" | "Power" | "Pet"

export type RewardItem = {
	category: RewardCategory,
	name: string,
	icon: string,
	rarity: LootBoxTier,
	weight: number,
	amount: number?,       -- For Cash, Gems, Power
	petId: string?,        -- For Pets
	description: string,
}

export type LootBoxDef = {
	id: string,
	name: string,
	title: string,
	tier: LootBoxTier,
	description: string,
	sourceDescription: string,
	color: Color3,
	accentColor: Color3,
	icon: string,
	modelType: "Wood" | "Gold" | "Magma" | "Void" | "Cyber",
	rewards: { RewardItem },
}

local LootBoxConfig = {}

LootBoxConfig.TIER_COLORS = {
	Common = Color3.fromRGB(180, 140, 90),
	Rare = Color3.fromRGB(0, 215, 255),
	Epic = Color3.fromRGB(255, 90, 30),
	Legendary = Color3.fromRGB(180, 50, 255),
	Mythic = Color3.fromRGB(255, 215, 0),
} :: { [LootBoxTier]: Color3 }

LootBoxConfig.BOXES = {
	wooden_chest = {
		id = "wooden_chest",
		name = "Miner's Wooden Chest",
		title = "Common Miner's Supply",
		tier = "Common",
		description = "A sturdy oak chest with brass fittings discarded by early meadow miners.",
		sourceDescription = "Found while mining Zone 1 Stone, Copper & Iron ores.",
		color = Color3.fromRGB(150, 100, 50),
		accentColor = Color3.fromRGB(210, 160, 90),
		icon = "📦",
		modelType = "Wood",
		rewards = {
			{ category = "Cash", name = "$5,000 Cash", icon = "💰", rarity = "Common", weight = 40, amount = 5000, description = "A quick pouch of shiny miner coins" },
			{ category = "Cash", name = "$20,000 Cash", icon = "💰", rarity = "Rare", weight = 25, amount = 20000, description = "Substantial cash payout" },
			{ category = "Gems", name = "25 Gems", icon = "💎", rarity = "Common", weight = 20, amount = 25, description = "Shiny blue gems" },
			{ category = "Gems", name = "75 Gems", icon = "💎", rarity = "Rare", weight = 8, amount = 75, description = "Cluster of refined gems" },
			{ category = "Power", name = "+30 Power", icon = "⚡", rarity = "Common", weight = 5, amount = 30, description = "Permanent mining power boost" },
			{ category = "Pet", name = "Crystal Doge", icon = "🐶", rarity = "Common", weight = 2, petId = "CrystalDoge", description = "Faithful companion (+20% Cash/Gems)" },
		},
	},

	gold_chest = {
		id = "gold_chest",
		name = "Gilded Geode Strongbox",
		title = "Rare Geode Vault",
		tier = "Rare",
		description = "A gleaming golden strongbox reinforced with crystalline quartz latches.",
		sourceDescription = "Found from Zone 1 Gold, Diamond & Cosmic ores, or Zone 2 veins.",
		color = Color3.fromRGB(240, 185, 30),
		accentColor = Color3.fromRGB(255, 240, 130),
		icon = "🪙",
		modelType = "Gold",
		rewards = {
			{ category = "Cash", name = "$100,000 Cash", icon = "💰", rarity = "Common", weight = 35, amount = 100000, description = "A hefty stack of cash" },
			{ category = "Cash", name = "$500,000 Cash", icon = "💰", rarity = "Rare", weight = 25, amount = 500000, description = "A fortune in gold bullion" },
			{ category = "Gems", name = "250 Gems", icon = "💎", rarity = "Common", weight = 20, amount = 250, description = "Pure faceted diamonds" },
			{ category = "Gems", name = "750 Gems", icon = "💎", rarity = "Rare", weight = 10, amount = 750, description = "Lustrous gem cache" },
			{ category = "Power", name = "+150 Power", icon = "⚡", rarity = "Rare", weight = 6, amount = 150, description = "Permanent mining power surge" },
			{ category = "Pet", name = "Neon Bunny", icon = "🐰", rarity = "Rare", weight = 4, petId = "NeonBunny", description = "High-speed companion (+150% Cash/Gems)" },
		},
	},

	magma_chest = {
		id = "magma_chest",
		name = "Infernal Magma Vault",
		title = "Epic Volcanic Relic",
		tier = "Epic",
		description = "Forged in the heart of the volcano with molten basalt and glowing lava veins.",
		sourceDescription = "Guaranteed drop from the Infernal Magma Golem Boss; rare in Zone 2 ores.",
		color = Color3.fromRGB(255, 65, 20),
		accentColor = Color3.fromRGB(255, 180, 50),
		icon = "🔥",
		modelType = "Magma",
		rewards = {
			{ category = "Cash", name = "$3,000,000 Cash", icon = "💰", rarity = "Rare", weight = 35, amount = 3000000, description = "Millions in molten gold" },
			{ category = "Cash", name = "$12,000,000 Cash", icon = "💰", rarity = "Epic", weight = 20, amount = 12000000, description = "Enormous volcanic treasury" },
			{ category = "Gems", name = "2,000 Gems", icon = "💎", rarity = "Rare", weight = 22, amount = 2000, description = "Hot magma crystals" },
			{ category = "Gems", name = "6,000 Gems", icon = "💎", rarity = "Epic", weight = 12, amount = 6000, description = "Glowing ruby hoard" },
			{ category = "Power", name = "+600 Power", icon = "⚡", rarity = "Epic", weight = 6, amount = 600, description = "Massive volcanic power infusion" },
			{ category = "Pet", name = "Magma Hound", icon = "🐕", rarity = "Epic", weight = 3, petId = "MagmaHound", description = "Fiery predator (+250% Cash/Gems)" },
			{ category = "Pet", name = "Volcanic Golem", icon = "🗿", rarity = "Epic", weight = 2, petId = "VolcanicGolem", description = "Stone titan pet (+350% Cash/Gems)" },
		},
	},

	void_chest = {
		id = "void_chest",
		name = "Void Cosmic Relic",
		title = "Legendary Cosmic Artifact",
		tier = "Legendary",
		description = "Pulsing with dark matter and temporal energy from beyond the galactic boundary.",
		sourceDescription = "Guaranteed drop from Void Harbinger Chronos Boss; found in Zone 3 Cosmic ores.",
		color = Color3.fromRGB(175, 45, 255),
		accentColor = Color3.fromRGB(80, 240, 255),
		icon = "🌌",
		modelType = "Void",
		rewards = {
			{ category = "Cash", name = "$25,000,000 Cash", icon = "💰", rarity = "Epic", weight = 30, amount = 25000000, description = "Galactic credit payload" },
			{ category = "Cash", name = "$100,000,000 Cash", icon = "💰", rarity = "Legendary", weight = 18, amount = 100000000, description = "Colossal cosmic fortune" },
			{ category = "Gems", name = "12,000 Gems", icon = "💎", rarity = "Epic", weight = 25, amount = 12000, description = "Deep cosmos void diamonds" },
			{ category = "Gems", name = "35,000 Gems", icon = "💎", rarity = "Legendary", weight = 12, amount = 35000, description = "Astral gem singularity" },
			{ category = "Power", name = "+2,500 Power", icon = "⚡", rarity = "Legendary", weight = 8, amount = 2500, description = "Temporal reality-bending power" },
			{ category = "Pet", name = "Void Phoenix", icon = "🦅", rarity = "Legendary", weight = 4, petId = "VoidPhoenix", description = "Nebula sovereign (+650% Cash/Gems)" },
			{ category = "Pet", name = "Astral Kitsune", icon = "🦊", rarity = "Legendary", weight = 3, petId = "AstralKitsune", description = "Nine-tailed celestial (+700% Cash/Gems)" },
		},
	},

	cyber_chest = {
		id = "cyber_chest",
		name = "Cyber Matrix Jackpot Crate",
		title = "Mythic Quantum Singularity",
		tier = "Mythic",
		description = "An experimental holographic hyper-cube loaded with maximum jackpot payouts.",
		sourceDescription = "Ultra-rare jackpot drop from World Bosses, Cosmic Voids & Diamond geodes.",
		color = Color3.fromRGB(0, 255, 220),
		accentColor = Color3.fromRGB(255, 70, 220),
		icon = "⚡",
		modelType = "Cyber",
		rewards = {
			{ category = "Cash", name = "$75,000,000 Cash", icon = "💰", rarity = "Legendary", weight = 25, amount = 75000000, description = "Matrix cash overflow" },
			{ category = "Cash", name = "$250,000,000 Cash", icon = "💰", rarity = "Mythic", weight = 15, amount = 250000000, description = "Ultimate mega jackpot cash" },
			{ category = "Gems", name = "40,000 Gems", icon = "💎", rarity = "Legendary", weight = 25, amount = 40000, description = "Quantum gem cache" },
			{ category = "Gems", name = "100,000 Gems", icon = "💎", rarity = "Mythic", weight = 15, amount = 100000, description = "Infinite quantum singularity" },
			{ category = "Power", name = "+10,000 Power", icon = "⚡", rarity = "Mythic", weight = 10, amount = 10000, description = "Transcendental hyper-power boost" },
			{ category = "Pet", name = "Chronos Drake", icon = "🐲", rarity = "Mythic", weight = 6, petId = "ChronosDrake", description = "Time-bending dragon (+1000% Cash/Gems)" },
			{ category = "Pet", name = "Void Leviathan", icon = "🐉", rarity = "Mythic", weight = 4, petId = "VoidLeviathan", description = "Abyssal space serpent (+900% Cash/Gems)" },
		},
	},
} :: { [string]: LootBoxDef }

LootBoxConfig.ORDERED_IDS = {
	"wooden_chest",
	"gold_chest",
	"magma_chest",
	"void_chest",
	"cyber_chest",
}

function LootBoxConfig.getBox(boxId: string): LootBoxDef?
	return LootBoxConfig.BOXES[boxId]
end

function LootBoxConfig.rollReward(boxId: string): RewardItem
	local box = LootBoxConfig.BOXES[boxId]
	if not box or #box.rewards == 0 then
		return {
			category = "Cash",
			name = "$1,000 Cash",
			icon = "💰",
			rarity = "Common",
			weight = 100,
			amount = 1000,
			description = "Standard cash drop",
		}
	end

	local totalWeight = 0
	for _, reward in ipairs(box.rewards) do
		totalWeight += reward.weight
	end

	local rand = math.random() * totalWeight
	local runningWeight = 0
	for _, reward in ipairs(box.rewards) do
		runningWeight += reward.weight
		if rand <= runningWeight then
			return reward
		end
	end

	return box.rewards[#box.rewards]
end

return LootBoxConfig
