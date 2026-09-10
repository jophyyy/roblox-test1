--!strict
export type CodeReward = {
	cash: number?,
	gems: number?,
	power: number?,
	freeSpins: number?,
	lootBoxes: { [string]: number }?, -- boxId -> count
	masteryXP: number?,
	petId: string?,
}

export type CodeDef = {
	code: string, -- Uppercase canonical code key
	title: string,
	description: string,
	reward: CodeReward,
	rewardSummary: string,
	badgeColor: Color3,
}

local CodeConfig = {}

CodeConfig.CODES = {
	TEST1 = {
		code = "TEST1",
		title = "🧪 Beta Tester Special",
		description = "Exclusive tester reward! Gives massive cash, gems, crates, power, and mastery XP.",
		reward = {
			cash = 100000,
			gems = 1000,
			power = 500,
			freeSpins = 2,
			lootBoxes = {
				wooden_chest = 3,
				gold_chest = 1,
			},
			masteryXP = 500,
		},
		rewardSummary = "+$100,000 Cash • +1,000 💎 • +4 Crates • +500 Power • +2 Spins",
		badgeColor = Color3.fromRGB(0, 220, 255),
	},
	RELEASE = {
		code = "RELEASE",
		title = "🚀 Launch Celebration",
		description = "Celebration reward for the game release! Free Cash, Gems, and Gold Crates.",
		reward = {
			cash = 50000,
			gems = 500,
			lootBoxes = {
				gold_chest = 2,
			},
		},
		rewardSummary = "+$50,000 Cash • +500 💎 • +2 Gold Crates",
		badgeColor = Color3.fromRGB(255, 180, 0),
	},
	MINING = {
		code = "MINING",
		title = "⛏️ Master Miner",
		description = "A gift for dedicated ore crushers! Grants bonus cash, gems, and instant power.",
		reward = {
			cash = 30000,
			gems = 300,
			power = 1000,
		},
		rewardSummary = "+$30,000 Cash • +300 💎 • +1,000 Power",
		badgeColor = Color3.fromRGB(80, 230, 140),
	},
	FREEPET = {
		code = "FREEPET",
		title = "🐾 Pet Companion Pack",
		description = "Free gems and a high-tier Magma Crate to hatch powerful legendary pets!",
		reward = {
			gems = 750,
			lootBoxes = {
				magma_chest = 1,
			},
		},
		rewardSummary = "+750 💎 • +1 Magma Vault Crate",
		badgeColor = Color3.fromRGB(255, 90, 40),
	},
	LUCKY = {
		code = "LUCKY",
		title = "🍀 High Roller",
		description = "Triple seven lucky bonus with free wheel spins and heaps of riches!",
		reward = {
			cash = 77777,
			gems = 777,
			freeSpins = 3,
		},
		rewardSummary = "+$77,777 Cash • +777 💎 • +3 Free Spins",
		badgeColor = Color3.fromRGB(200, 80, 255),
	},
	SECRET = {
		code = "SECRET",
		title = "🌌 Cosmic Mystery",
		description = "A hidden code tucked away in the shadows. Awards an endgame Void Crate!",
		reward = {
			gems = 2000,
			lootBoxes = {
				void_chest = 1,
			},
		},
		rewardSummary = "+2,000 💎 • +1 Void Relic Crate",
		badgeColor = Color3.fromRGB(160, 50, 255),
	},
} :: { [string]: CodeDef }

-- Ordered array for UI exhibition cards
CodeConfig.ORDERED_CODES = {
	CodeConfig.CODES.TEST1,
	CodeConfig.CODES.RELEASE,
	CodeConfig.CODES.MINING,
	CodeConfig.CODES.FREEPET,
	CodeConfig.CODES.LUCKY,
	CodeConfig.CODES.SECRET,
}

-- Normalizes input code string: strips whitespace, strips leading symbols, uppercase
function CodeConfig.normalize(rawInput: string): string
	if typeof(rawInput) ~= "string" then
		return ""
	end
	-- Strip spaces, leading slashes or exclamation marks
	local cleaned = string.gsub(rawInput, "[%s!/#]", "")
	return string.upper(cleaned)
end

-- Retrieves code definition by raw input
function CodeConfig.getCode(rawInput: string): CodeDef?
	local key = CodeConfig.normalize(rawInput)
	if key == "" then
		return nil
	end
	return CodeConfig.CODES[key]
end

return CodeConfig
