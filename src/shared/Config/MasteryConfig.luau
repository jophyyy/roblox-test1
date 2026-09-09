--!strict
export type MasteryMilestone = {
	level: number,
	name: string,
	icon: string,
	description: string,
}

export type MasteryTrackDef = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	description: string,
	actionHint: string,
	maxLevel: number,
	milestones: { [number]: MasteryMilestone },
}

local MasteryConfig = {}

MasteryConfig.MAX_LEVEL = 50

-- Calculate the XP required to advance from (level - 1) to (level)
function MasteryConfig.getXpForLevel(level: number): number
	if level <= 1 then return 0 end
	return math.floor(100 * math.pow(level - 1, 1.45))
end

-- Cumulative XP required to reach a specific level
local cumulativeXpTable: { [number]: number } = { [1] = 0 }
for lvl = 2, MasteryConfig.MAX_LEVEL + 1 do
	cumulativeXpTable[lvl] = cumulativeXpTable[lvl - 1] + MasteryConfig.getXpForLevel(lvl)
end

function MasteryConfig.getCumulativeXp(level: number): number
	local clamped = math.clamp(level, 1, MasteryConfig.MAX_LEVEL + 1)
	return cumulativeXpTable[clamped] or 0
end

-- Returns: currentLevel, currentXpIntoLevel, xpNeededForNextLevel, progressRatio (0.0 to 1.0)
function MasteryConfig.getLevelFromXp(totalXp: number): (number, number, number, number)
	local xp = math.max(0, totalXp or 0)
	for lvl = 1, MasteryConfig.MAX_LEVEL do
		local nextLevelCumulative = cumulativeXpTable[lvl + 1]
		if xp < nextLevelCumulative then
			local currentLevelBase = cumulativeXpTable[lvl]
			local xpIntoLevel = xp - currentLevelBase
			local xpNeeded = nextLevelCumulative - currentLevelBase
			local ratio = if xpNeeded > 0 then math.clamp(xpIntoLevel / xpNeeded, 0, 1) else 1
			return lvl, xpIntoLevel, xpNeeded, ratio
		end
	end
	-- Max level reached
	local maxLevelBase = cumulativeXpTable[MasteryConfig.MAX_LEVEL]
	local maxLevelCap = cumulativeXpTable[MasteryConfig.MAX_LEVEL + 1] - maxLevelBase
	return MasteryConfig.MAX_LEVEL, maxLevelCap, maxLevelCap, 1.0
end

MasteryConfig.TRACKS = {
	Eggs = {
		id = "Eggs",
		name = "Egg Hatching",
		icon = "🥚",
		color = Color3.fromRGB(60, 190, 255),
		description = "Hatch eggs to unlock lucky hatch boosts, egg cost discounts, and extra pet slots.",
		actionHint = "Hatch pet eggs (+10 XP each)",
		maxLevel = MasteryConfig.MAX_LEVEL,
		milestones = {
			[5] = {
				level = 5,
				name = "Egg Seeker",
				icon = "🔍",
				description = "+5% Lucky Hatch Chance",
			},
			[10] = {
				level = 10,
				name = "Bargain Breeder",
				icon = "🏷️",
				description = "-10% Egg Hatch Gem Cost",
			},
			[20] = {
				level = 20,
				name = "Swift Hatcher",
				icon = "✨",
				description = "+15% Lucky Hatch Chance",
			},
			[35] = {
				level = 35,
				name = "Golden Shells",
				icon = "💎",
				description = "-20% Egg Hatch Gem Cost",
			},
			[50] = {
				level = 50,
				name = "Master Breeder",
				icon = "👑",
				description = "+1 EXTRA EQUIPPED PET SLOT! • +25% Lucky Hatch Chance",
			},
		},
	},

	BossSlayer = {
		id = "BossSlayer",
		name = "Boss Slayer",
		icon = "👹",
		color = Color3.fromRGB(255, 75, 40),
		description = "Fight and destroy world bosses to increase boss damage, critical strikes, and drop rewards.",
		actionHint = "Hit & slay world bosses (+2 XP hit, +300 XP kill)",
		maxLevel = MasteryConfig.MAX_LEVEL,
		milestones = {
			[5] = {
				level = 5,
				name = "Giant Hunter",
				icon = "🗡️",
				description = "+10% Boss Damage",
			},
			[10] = {
				level = 10,
				name = "Bounty Hunter",
				icon = "💰",
				description = "+15% Cash & Gems from Boss Defeat",
			},
			[20] = {
				level = 20,
				name = "Precision Striker",
				icon = "🎯",
				description = "+10% Boss Critical Hit Chance",
			},
			[35] = {
				level = 35,
				name = "Executioner",
				icon = "⚡",
				description = "+25% Boss Damage • +25% Boss Rewards",
			},
			[50] = {
				level = 50,
				name = "God of War",
				icon = "🔥",
				description = "+50% Boss Damage • +50% Boss Rewards • +2x Power Gain",
			},
		},
	},

	Mining = {
		id = "Mining",
		name = "Ore Mining",
		icon = "⛏️",
		color = Color3.fromRGB(255, 195, 30),
		description = "Mine and pulverize ores to increase mining power, gem yields, and double strike chances.",
		actionHint = "Strike & break ore boulders (+2 XP hit, +15 XP break)",
		maxLevel = MasteryConfig.MAX_LEVEL,
		milestones = {
			[5] = {
				level = 5,
				name = "Sturdy Swing",
				icon = "💪",
				description = "+10% Mining Power",
			},
			[10] = {
				level = 10,
				name = "Gem Prospector",
				icon = "💎",
				description = "+20% Gems from broken ores",
			},
			[20] = {
				level = 20,
				name = "Double Strike",
				icon = "⚔️",
				description = "15% Chance for pickaxe to strike twice",
			},
			[35] = {
				level = 35,
				name = "Vein Breaker",
				icon = "💥",
				description = "+35% Cash from ores",
			},
			[50] = {
				level = 50,
				name = "Bedrock Shatterer",
				icon = "☄️",
				description = "+50% Mining Power • 25% Double Ore Drops",
			},
		},
	},

	PetFusion = {
		id = "PetFusion",
		name = "Pet Fusion",
		icon = "⚗️",
		color = Color3.fromRGB(195, 75, 255),
		description = "Fuse pets into Golden and Rainbow tiers to empower pet stats and unlock extra pet slots.",
		actionHint = "Fuse pets in the fusion station (+50 XP Gold, +150 XP Rainbow)",
		maxLevel = MasteryConfig.MAX_LEVEL,
		milestones = {
			[5] = {
				level = 5,
				name = "Alchemist Apprentice",
				icon = "🧪",
				description = "+5% Pet Damage",
			},
			[10] = {
				level = 10,
				name = "Golden Touch",
				icon = "🌟",
				description = "+10% Cash Multiplier from all equipped pets",
			},
			[20] = {
				level = 20,
				name = "Prismatic Infusion",
				icon = "🌈",
				description = "+25% Extra Multiplier from Rainbow pets",
			},
			[35] = {
				level = 35,
				name = "Grand Alchemist",
				icon = "🐾",
				description = "+1 EXTRA EQUIPPED PET SLOT!",
			},
			[50] = {
				level = 50,
				name = "Philosopher's Stone",
				icon = "🔮",
				description = "+50% Pet Stats • 15% Chance to duplicate fused pet for free",
			},
		},
	},

	Rebirth = {
		id = "Rebirth",
		name = "Rebirth Mastery",
		icon = "⚡",
		color = Color3.fromRGB(0, 230, 140),
		description = "Ascend through rebirths to lower rebirth costs and massively boost global multipliers.",
		actionHint = "Complete rebirths (+250 XP per rebirth)",
		maxLevel = MasteryConfig.MAX_LEVEL,
		milestones = {
			[5] = {
				level = 5,
				name = "Swift Ascension",
				icon = "🚀",
				description = "Start each rebirth with $5,000 Cash and 500 Power",
			},
			[10] = {
				level = 10,
				name = "Rebirth Discount",
				icon = "📉",
				description = "-15% Rebirth Cash Cost",
			},
			[20] = {
				level = 20,
				name = "Overdrive",
				icon = "⚡",
				description = "+25% Global Rebirth Multiplier",
			},
			[35] = {
				level = 35,
				name = "Diamond Rebirth",
				icon = "💎",
				description = "+50% Gem rewards from rebirths",
			},
			[50] = {
				level = 50,
				name = "Cosmic Transcendence",
				icon = "🌌",
				description = "+100% Global Cash & Gem Multipliers",
			},
		},
	},
}

MasteryConfig.TRACK_ORDER = { "Eggs", "BossSlayer", "Mining", "PetFusion", "Rebirth" }

-- Calculates all active numerical multipliers for a track at a specific level
function MasteryConfig.getTrackBoosts(trackId: string, level: number)
	local lvl = math.clamp(level, 1, MasteryConfig.MAX_LEVEL)
	local boosts = {
		bossDamageMultiplier = 1.0,
		bossRewardsMultiplier = 1.0,
		bossCritChanceBonus = 0.0,
		miningPowerMultiplier = 1.0,
		gemOreBonusMultiplier = 1.0,
		doubleStrikeChance = 0.0,
		cashOreMultiplier = 1.0,
		luckyEggBonus = 0.0,
		eggCostDiscount = 0.0,
		extraPetSlots = 0,
		petStatsMultiplier = 1.0,
		cashPetMultiplier = 1.0,
		rainbowPetExtraMultiplier = 1.0,
		rebirthCostDiscount = 0.0,
		rebirthGlobalMultiplier = 1.0,
		rebirthGemsBonusMultiplier = 1.0,
		globalCashMultiplier = 1.0,
		globalGemMultiplier = 1.0,
	}

	if trackId == "Eggs" then
		-- Passive: +0.5% Lucky per level
		boosts.luckyEggBonus += (lvl * 0.005)
		if lvl >= 5 then boosts.luckyEggBonus += 0.05 end
		if lvl >= 10 then boosts.eggCostDiscount += 0.10 end
		if lvl >= 20 then boosts.luckyEggBonus += 0.15 end
		if lvl >= 35 then boosts.eggCostDiscount += 0.20 end
		if lvl >= 50 then
			boosts.extraPetSlots += 1
			boosts.luckyEggBonus += 0.25
		end
	elseif trackId == "BossSlayer" then
		-- Passive: +1.0% Boss Damage per level
		boosts.bossDamageMultiplier += (lvl * 0.01)
		if lvl >= 5 then boosts.bossDamageMultiplier += 0.10 end
		if lvl >= 10 then boosts.bossRewardsMultiplier += 0.15 end
		if lvl >= 20 then boosts.bossCritChanceBonus += 0.10 end
		if lvl >= 35 then
			boosts.bossDamageMultiplier += 0.25
			boosts.bossRewardsMultiplier += 0.25
		end
		if lvl >= 50 then
			boosts.bossDamageMultiplier += 0.50
			boosts.bossRewardsMultiplier += 0.50
		end
	elseif trackId == "Mining" then
		-- Passive: +1.0% Mining Power per level
		boosts.miningPowerMultiplier += (lvl * 0.01)
		if lvl >= 5 then boosts.miningPowerMultiplier += 0.10 end
		if lvl >= 10 then boosts.gemOreBonusMultiplier += 0.20 end
		if lvl >= 20 then boosts.doubleStrikeChance += 0.15 end
		if lvl >= 35 then boosts.cashOreMultiplier += 0.35 end
		if lvl >= 50 then boosts.miningPowerMultiplier += 0.50 end
	elseif trackId == "PetFusion" then
		-- Passive: +0.5% Pet Damage per level
		boosts.petStatsMultiplier += (lvl * 0.005)
		if lvl >= 5 then boosts.petStatsMultiplier += 0.05 end
		if lvl >= 10 then boosts.cashPetMultiplier += 0.10 end
		if lvl >= 20 then boosts.rainbowPetExtraMultiplier += 0.25 end
		if lvl >= 35 then boosts.extraPetSlots += 1 end
		if lvl >= 50 then boosts.petStatsMultiplier += 0.50 end
	elseif trackId == "Rebirth" then
		-- Passive: +1.0% Cash & Gem per level
		boosts.globalCashMultiplier += (lvl * 0.01)
		boosts.globalGemMultiplier += (lvl * 0.01)
		if lvl >= 10 then boosts.rebirthCostDiscount += 0.15 end
		if lvl >= 20 then boosts.rebirthGlobalMultiplier += 0.25 end
		if lvl >= 35 then boosts.rebirthGemsBonusMultiplier += 0.50 end
		if lvl >= 50 then
			boosts.globalCashMultiplier += 1.00
			boosts.globalGemMultiplier += 1.00
		end
	end

	return boosts
end

-- Gets the next upcoming milestone for a track above current level
function MasteryConfig.getNextMilestone(trackId: string, currentLevel: number): MasteryMilestone?
	local track = MasteryConfig.TRACKS[trackId]
	if not track then return nil end

	local milestoneLevels = { 5, 10, 20, 35, 50 }
	for _, ml in ipairs(milestoneLevels) do
		if ml > currentLevel then
			return track.milestones[ml]
		end
	end
	return nil
end

return MasteryConfig
