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

-- Resolves legacy crate_* keys to modern block_* keys
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

LuckyBlockConfig.BLOCKS = {
	block_wood = {
		id = "block_wood",
		name = "Wooden Lucky Block",
		tier = "Common",
		description = "A rustic oak question-mark block. Great for aspiring excavators!",
		cubeColor = Color3.fromRGB(145, 95, 50),
		questionColor = Color3.fromRGB(255, 220, 60),
		lightColor = Color3.fromRGB(255, 210, 120),
		material = Enum.Material.WoodPlanks,
		priceCash = 25000,
		priceGems = 50,
		rewards = {
			{ weight = 40, reward = { type = "Cash", name = "$15,000 Cash", amount = 15000, rarity = "Common" } },
			{ weight = 25, reward = { type = "Cash", name = "$35,000 Cash", amount = 35000, rarity = "Common" } },
			{ weight = 25, reward = { type = "Gems", name = "50 Gems", amount = 50, rarity = "Common" } },
			{ weight = 10, reward = { type = "Pet", name = "Forest Bunny", amount = 1, rarity = "Rare", petId = "pet_bunny" } },
		},
	},
	block_iron = {
		id = "block_iron",
		name = "Iron Lucky Block",
		tier = "Rare",
		description = "Reinforced industrial steel lucky cube with energetic cyan energy!",
		cubeColor = Color3.fromRGB(180, 185, 195),
		questionColor = Color3.fromRGB(0, 230, 255),
		lightColor = Color3.fromRGB(0, 230, 255),
		material = Enum.Material.Metal,
		priceCash = 100000,
		priceGems = 200,
		rewards = {
			{ weight = 35, reward = { type = "Cash", name = "$80,000 Cash", amount = 80000, rarity = "Rare" } },
			{ weight = 25, reward = { type = "Cash", name = "$150,000 Cash", amount = 150000, rarity = "Rare" } },
			{ weight = 25, reward = { type = "Gems", name = "200 Gems", amount = 200, rarity = "Rare" } },
			{ weight = 15, reward = { type = "Pet", name = "Iron Hound", amount = 1, rarity = "Epic", petId = "pet_dog" } },
		},
	},
	block_gold = {
		id = "block_gold",
		name = "Golden Lucky Block",
		tier = "Epic",
		description = "The iconic gleaming gold lucky cube! High chance of massive jackpots!",
		cubeColor = Color3.fromRGB(255, 215, 0),
		questionColor = Color3.fromRGB(255, 255, 255),
		lightColor = Color3.fromRGB(255, 215, 60),
		material = Enum.Material.Neon,
		priceCash = 500000,
		priceGems = 800,
		rewards = {
			{ weight = 35, reward = { type = "Cash", name = "$450,000 Cash", amount = 450000, rarity = "Epic" } },
			{ weight = 25, reward = { type = "Cash", name = "$1,000,000 Cash", amount = 1000000, rarity = "Epic" } },
			{ weight = 25, reward = { type = "Gems", name = "1,000 Gems", amount = 1000, rarity = "Epic" } },
			{ weight = 15, reward = { type = "Pet", name = "Golden Phoenix", amount = 1, rarity = "Legendary", petId = "pet_dragon" } },
		},
	},
	block_diamond = {
		id = "block_diamond",
		name = "Diamond Lucky Block",
		tier = "Legendary",
		description = "Crystalline diamond mystery cube. Emits dazzling prismatic rays!",
		cubeColor = Color3.fromRGB(0, 220, 255),
		questionColor = Color3.fromRGB(255, 255, 255),
		lightColor = Color3.fromRGB(0, 240, 255),
		material = Enum.Material.Neon,
		priceCash = 2500000,
		priceGems = 3500,
		rewards = {
			{ weight = 30, reward = { type = "Cash", name = "$2,500,000 Cash", amount = 2500000, rarity = "Legendary" } },
			{ weight = 25, reward = { type = "Cash", name = "$5,000,000 Cash", amount = 5000000, rarity = "Legendary" } },
			{ weight = 25, reward = { type = "Gems", name = "5,000 Gems", amount = 5000, rarity = "Legendary" } },
			{ weight = 20, reward = { type = "Pet", name = "Diamond Golem", amount = 1, rarity = "Mythic", petId = "pet_golem" } },
		},
	},
	block_cosmic = {
		id = "block_cosmic",
		name = "Rainbow Cosmic Lucky Block",
		tier = "Mythic",
		description = "The ultimate celestial prize! Contains astronomical jackpots and cosmic companions.",
		cubeColor = Color3.fromRGB(255, 60, 220),
		questionColor = Color3.fromRGB(255, 255, 255),
		lightColor = Color3.fromRGB(255, 100, 255),
		material = Enum.Material.Neon,
		priceCash = 15000000,
		priceGems = 20000,
		rewards = {
			{ weight = 30, reward = { type = "Cash", name = "$20,000,000 Cash", amount = 20000000, rarity = "Mythic" } },
			{ weight = 25, reward = { type = "Cash", name = "$50,000,000 Cash", amount = 50000000, rarity = "Mythic" } },
			{ weight = 25, reward = { type = "Gems", name = "35,000 Gems", amount = 35000, rarity = "Mythic" } },
			{ weight = 20, reward = { type = "Pet", name = "Cosmic Star Titan", amount = 1, rarity = "Mythic", petId = "pet_pegasus" } },
		},
	},
} :: { [string]: LuckyBlockDef }

LuckyBlockConfig.ORDERED_IDS = {
	"block_wood",
	"block_iron",
	"block_gold",
	"block_diamond",
	"block_cosmic",
}

function LuckyBlockConfig.getBlock(rawId: string): LuckyBlockDef?
	local resolvedId = LuckyBlockConfig.resolveBlockId(rawId)
	return LuckyBlockConfig.BLOCKS[resolvedId]
end

-- Rolls a random reward from block pool with 10% chance for 3x Mega Jackpot
function LuckyBlockConfig.rollReward(rawId: string): RewardItem
	local block = LuckyBlockConfig.getBlock(rawId)
	if not block then
		return { type = "Cash", name = "$10,000 Cash", amount = 10000, rarity = "Common" }
	end

	local totalWeight = 0
	for _, entry in ipairs(block.rewards) do
		totalWeight += entry.weight
	end

	local rand = math.random() * totalWeight
	local cumulative = 0
	local chosenReward: RewardItem? = nil

	for _, entry in ipairs(block.rewards) do
		cumulative += entry.weight
		if rand <= cumulative then
			chosenReward = entry.reward
			break
		end
	end

	if not chosenReward then
		chosenReward = block.rewards[1].reward
	end

	-- 10% Chance of Mega Jackpot (Triples Cash & Gems)
	local isMegaJackpot = (math.random(1, 10) == 1)
	local finalAmount = chosenReward.amount
	local finalName = chosenReward.name

	if isMegaJackpot and (chosenReward.type == "Cash" or chosenReward.type == "Gems") then
		finalAmount *= 3
		finalName = string.format("🌟 MEGA JACKPOT: %s!", chosenReward.name:gsub("%d+", tostring(finalAmount)))
	end

	return {
		type = chosenReward.type,
		name = finalName,
		amount = finalAmount,
		rarity = chosenReward.rarity,
		petId = chosenReward.petId,
		isMegaJackpot = isMegaJackpot,
	}
end

return LuckyBlockConfig
