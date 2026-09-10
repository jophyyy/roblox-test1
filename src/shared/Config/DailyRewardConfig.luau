--!strict
export type CrateReward = {
	boxId: string,
	count: number,
}

export type PetReward = {
	petId: string,
	count: number,
}

export type DayReward = {
	day: number,
	title: string,
	icon: string,
	description: string,
	cash: number?,
	gems: number?,
	power: number?,
	spins: number?,
	crates: { CrateReward }?,
	pets: { PetReward }?,
	isJackpot: boolean?,
}

export type WeekDef = {
	weekNumber: number,
	name: string,
	tagline: string,
	icon: string,
	themeColor: Color3,
	accentColor: Color3,
	days: { DayReward },
}

local DailyRewardConfig = {}

DailyRewardConfig.COOLDOWN_SECONDS = 86400 -- 24 hours in seconds
DailyRewardConfig.TOTAL_WEEKS = 7
DailyRewardConfig.DAYS_PER_WEEK = 7

DailyRewardConfig.WEEKS = {
	-- =========================================================================
	-- WEEK 1: 🌲 NOVICE PROSPECTOR
	-- =========================================================================
	{
		weekNumber = 1,
		name = "Novice Prospector",
		tagline = "Begin your mining legacy with essential survival tools & starter pet!",
		icon = "🌲",
		themeColor = Color3.fromRGB(46, 204, 113),
		accentColor = Color3.fromRGB(26, 188, 156),
		days = {
			{
				day = 1,
				title = "$10,000 Cash",
				icon = "💰",
				description = "Starter purse for early pickaxe upgrades",
				cash = 10000,
			},
			{
				day = 2,
				title = "100 Gems",
				icon = "💎",
				description = "Shiny gems for hatching your first eggs",
				gems = 100,
			},
			{
				day = 3,
				title = "+50 Power",
				icon = "⚡",
				description = "Permanent click power boost",
				power = 50,
			},
			{
				day = 4,
				title = "1x Wooden Chest",
				icon = "📦",
				description = "Common supply chest with cash & gem drops",
				crates = { { boxId = "wooden_chest", count = 1 } },
			},
			{
				day = 5,
				title = "250 Gems + 1 Spin",
				icon = "🎯",
				description = "Free Lucky Wheel spin & bonus gems",
				gems = 250,
				spins = 1,
			},
			{
				day = 6,
				title = "$50,000 Cash",
				icon = "💰",
				description = "Hefty gold bullion for meadow expansion",
				cash = 50000,
			},
			{
				day = 7,
				title = "Golden Crystal Pup + Gold Crate",
				icon = "🐶",
				description = "GRAND JACKPOT: 🌟 Golden Crystal Pup Pet, 1x Gilded Geode Chest & 500 Gems!",
				isJackpot = true,
				gems = 500,
				crates = { { boxId = "gold_chest", count = 1 } },
				pets = { { petId = "CrystalDoge_Golden", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 2: ⛏️ IRON VANGUARD
	-- =========================================================================
	{
		weekNumber = 2,
		name = "Iron Vanguard",
		tagline = "Reinforce your drills and excavate deeper vein deposits!",
		icon = "⛏️",
		themeColor = Color3.fromRGB(52, 152, 219),
		accentColor = Color3.fromRGB(41, 128, 185),
		days = {
			{
				day = 1,
				title = "$100,000 Cash",
				icon = "💰",
				description = "Strong capital injection for heavy tools",
				cash = 100000,
			},
			{
				day = 2,
				title = "500 Gems",
				icon = "💎",
				description = "Refined mineral gems for rare hatches",
				gems = 500,
			},
			{
				day = 3,
				title = "+250 Power",
				icon = "⚡",
				description = "Substantial click power increase",
				power = 250,
			},
			{
				day = 4,
				title = "2x Gold Chests",
				icon = "🪙",
				description = "Two Gilded Geode Strongboxes packed with loot",
				crates = { { boxId = "gold_chest", count = 2 } },
			},
			{
				day = 5,
				title = "1,000 Gems + 2 Spins",
				icon = "🎯",
				description = "Double wheel spins and 1,000 sparkling gems",
				gems = 1000,
				spins = 2,
			},
			{
				day = 6,
				title = "$350,000 Cash + 500 Power",
				icon = "⚡",
				description = "Cash jackpot and permanent power surge",
				cash = 350000,
				power = 500,
			},
			{
				day = 7,
				title = "Golden Neon Bunny + Magma Chest",
				icon = "🐰",
				description = "GRAND JACKPOT: 🌟 Golden Neon Bunny Pet, 1x Magma Chest & 1,500 Gems!",
				isJackpot = true,
				gems = 1500,
				crates = { { boxId = "magma_chest", count = 1 } },
				pets = { { petId = "NeonBunny_Golden", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 3: 🌋 MAGMA CONQUEROR
	-- =========================================================================
	{
		weekNumber = 3,
		name = "Magma Conqueror",
		tagline = "Brave volcanic caverns and extract molten treasures!",
		icon = "🌋",
		themeColor = Color3.fromRGB(230, 126, 34),
		accentColor = Color3.fromRGB(211, 84, 0),
		days = {
			{
				day = 1,
				title = "$1,000,000 Cash",
				icon = "💰",
				description = "A clean million in molten gold",
				cash = 1000000,
			},
			{
				day = 2,
				title = "2,000 Gems",
				icon = "💎",
				description = "Hot ruby crystal deposit",
				gems = 2000,
			},
			{
				day = 3,
				title = "+1,000 Power",
				icon = "⚡",
				description = "Volcanic core energy infusion",
				power = 1000,
			},
			{
				day = 4,
				title = "2x Magma Chests",
				icon = "🔥",
				description = "Two Infernal Magma Vaults forged in lava",
				crates = { { boxId = "magma_chest", count = 2 } },
			},
			{
				day = 5,
				title = "3,500 Gems + 3 Spins",
				icon = "🎯",
				description = "Triple lucky wheel spins and high-tier gems",
				gems = 3500,
				spins = 3,
			},
			{
				day = 6,
				title = "$5,000,000 Cash + 2k Power",
				icon = "💰",
				description = "5 Million Cash and huge power boost",
				cash = 5000000,
				power = 2000,
			},
			{
				day = 7,
				title = "Volcanic Golem + Void Chest",
				icon = "🗿",
				description = "GRAND JACKPOT: 🗿 Volcanic Golem Pet, 1x Void Chest & 5,000 Gems!",
				isJackpot = true,
				gems = 5000,
				crates = { { boxId = "void_chest", count = 1 } },
				pets = { { petId = "VolcanicGolem", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 4: 🔮 MYSTIC ALCHEMIST
	-- =========================================================================
	{
		weekNumber = 4,
		name = "Mystic Alchemist",
		tagline = "Transmute ancient geode elements into raw power!",
		icon = "🔮",
		themeColor = Color3.fromRGB(155, 89, 182),
		accentColor = Color3.fromRGB(142, 68, 173),
		days = {
			{
				day = 1,
				title = "$15,000,000 Cash",
				icon = "💰",
				description = "15 Million Cash for high-end mastery upgrades",
				cash = 15000000,
			},
			{
				day = 2,
				title = "6,000 Gems",
				icon = "💎",
				description = "Transmuted amethyst gem cache",
				gems = 6000,
			},
			{
				day = 3,
				title = "+4,000 Power",
				icon = "⚡",
				description = "Deep mystic power infusion",
				power = 4000,
			},
			{
				day = 4,
				title = "2x Void Chests",
				icon = "🌌",
				description = "Two Legendary Void Cosmic Relics",
				crates = { { boxId = "void_chest", count = 2 } },
			},
			{
				day = 5,
				title = "8,000 Gems + 4 Spins",
				icon = "🎯",
				description = "Four lucky spins and substantial gem hoard",
				gems = 8000,
				spins = 4,
			},
			{
				day = 6,
				title = "$30,000,000 Cash + 6k Power",
				icon = "⚡",
				description = "30 Million Cash and devastating power boost",
				cash = 30000000,
				power = 6000,
			},
			{
				day = 7,
				title = "Golden Magma Drake + 2x Void Chests",
				icon = "🐲",
				description = "GRAND JACKPOT: 🌟 Golden Elder Magma Drake Pet, 2x Void Chests & 10,000 Gems!",
				isJackpot = true,
				gems = 10000,
				crates = { { boxId = "void_chest", count = 2 } },
				pets = { { petId = "ElderMagmaDrake_Golden", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 5: 🌌 ASTRAL WANDERER
	-- =========================================================================
	{
		weekNumber = 5,
		name = "Astral Wanderer",
		tagline = "Harness starlight energy from cosmic meteor fragments!",
		icon = "🌌",
		themeColor = Color3.fromRGB(39, 174, 96),
		accentColor = Color3.fromRGB(0, 180, 216),
		days = {
			{
				day = 1,
				title = "$50,000,000 Cash",
				icon = "💰",
				description = "50 Million Cash cosmic bounty",
				cash = 50000000,
			},
			{
				day = 2,
				title = "12,000 Gems",
				icon = "💎",
				description = "Deep space diamond cluster",
				gems = 12000,
			},
			{
				day = 3,
				title = "+10,000 Power",
				icon = "⚡",
				description = "Subatomic power surge",
				power = 10000,
			},
			{
				day = 4,
				title = "1x Cyber Jackpot Crate",
				icon = "⚡",
				description = "Mythic Quantum Singularity crate",
				crates = { { boxId = "cyber_chest", count = 1 } },
			},
			{
				day = 5,
				title = "18,000 Gems + 5 Spins",
				icon = "🎯",
				description = "Five wheel spins and cosmic diamonds",
				gems = 18000,
				spins = 5,
			},
			{
				day = 6,
				title = "$100,000,000 Cash + 15k Power",
				icon = "💰",
				description = "100 Million Cash and +15k Power",
				cash = 100000000,
				power = 15000,
			},
			{
				day = 7,
				title = "Astral Kitsune + 2x Cyber Crates",
				icon = "🦊",
				description = "GRAND JACKPOT: 🦊 Astral Kitsune Pet, 2x Cyber Crates & 25,000 Gems!",
				isJackpot = true,
				gems = 25000,
				crates = { { boxId = "cyber_chest", count = 2 } },
				pets = { { petId = "AstralKitsune", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 6: 👑 VOID OVERLORD
	-- =========================================================================
	{
		weekNumber = 6,
		name = "Void Overlord",
		tagline = "Rule the dark dimensions and summon abyssal guardians!",
		icon = "👑",
		themeColor = Color3.fromRGB(142, 68, 173),
		accentColor = Color3.fromRGB(241, 196, 15),
		days = {
			{
				day = 1,
				title = "$150,000,000 Cash",
				icon = "💰",
				description = "150 Million Cash treasury",
				cash = 150000000,
			},
			{
				day = 2,
				title = "30,000 Gems",
				icon = "💎",
				description = "Abyssal singularity gems",
				gems = 30000,
			},
			{
				day = 3,
				title = "+25,000 Power",
				icon = "⚡",
				description = "Void dimension power attunement",
				power = 25000,
			},
			{
				day = 4,
				title = "2x Cyber Jackpot Crates",
				icon = "⚡",
				description = "Two Mythic Quantum Singularity crates",
				crates = { { boxId = "cyber_chest", count = 2 } },
			},
			{
				day = 5,
				title = "45,000 Gems + 6 Spins",
				icon = "🎯",
				description = "Six lucky wheel spins and vast gem cache",
				gems = 45000,
				spins = 6,
			},
			{
				day = 6,
				title = "$300,000,000 Cash + 40k Power",
				icon = "⚡",
				description = "300 Million Cash and catastrophic power",
				cash = 300000000,
				power = 40000,
			},
			{
				day = 7,
				title = "Golden Void Phoenix + 3x Cyber Crates",
				icon = "🦅",
				description = "GRAND JACKPOT: 🌟 Golden Void Phoenix Pet, 3x Cyber Crates & 50,000 Gems!",
				isJackpot = true,
				gems = 50000,
				crates = { { boxId = "cyber_chest", count = 3 } },
				pets = { { petId = "VoidPhoenix_Golden", count = 1 } },
			},
		},
	},

	-- =========================================================================
	-- WEEK 7: ⏳ CHRONOS TRANSCENDENCE (THE GOD TIER FINALE)
	-- =========================================================================
	{
		weekNumber = 7,
		name = "Chronos Transcendence",
		tagline = "The pinnacle of miner destiny. Bend time and claim the ultimate rainbow pet!",
		icon = "⏳",
		themeColor = Color3.fromRGB(241, 196, 15),
		accentColor = Color3.fromRGB(231, 76, 60),
		days = {
			{
				day = 1,
				title = "$500,000,000 Cash",
				icon = "💰",
				description = "Half a Billion Cash for supreme prestige",
				cash = 500000000,
			},
			{
				day = 2,
				title = "60,000 Gems",
				icon = "💎",
				description = "Prismatic chronological diamonds",
				gems = 60000,
			},
			{
				day = 3,
				title = "+60,000 Power",
				icon = "⚡",
				description = "Reality-warping power surge",
				power = 60000,
			},
			{
				day = 4,
				title = "3x Cyber Jackpot Crates",
				icon = "⚡",
				description = "Three Mythic Quantum Singularity crates",
				crates = { { boxId = "cyber_chest", count = 3 } },
			},
			{
				day = 5,
				title = "80,000 Gems + 7 Spins",
				icon = "🎯",
				description = "Seven lucky spins and immense diamond treasury",
				gems = 80000,
				spins = 7,
			},
			{
				day = 6,
				title = "$1,000,000,000 Cash + 100k Power",
				icon = "👑",
				description = "ONE BILLION CASH and +100k Power",
				cash = 1000000000,
				power = 100000,
			},
			{
				day = 7,
				title = "Rainbow Chronos Void Drake + $2.5B Cash",
				icon = "🌌",
				description = "ULTIMATE 7-WEEK FINALE: 🌈 Rainbow Chronos Void Drake, 5x Cyber Crates, 150,000 Gems & $2.5 Billion Cash!",
				isJackpot = true,
				cash = 2500000000,
				gems = 150000,
				crates = { { boxId = "cyber_chest", count = 5 } },
				pets = { { petId = "ChronosDrake_Rainbow", count = 1 } },
			},
		},
	},
} :: { WeekDef }

function DailyRewardConfig.getWeek(weekNumber: number): WeekDef?
	for _, w in ipairs(DailyRewardConfig.WEEKS) do
		if w.weekNumber == weekNumber then
			return w
		end
	end
	return nil
end

function DailyRewardConfig.getReward(weekNumber: number, dayNumber: number): DayReward?
	local week = DailyRewardConfig.getWeek(weekNumber)
	if not week then return nil end
	for _, d in ipairs(week.days) do
		if d.day == dayNumber then
			return d
		end
	end
	return nil
end

function DailyRewardConfig.canClaim(lastClaimTime: number?): boolean
	local last = lastClaimTime or 0
	if last <= 0 then return true end
	return (os.time() - last) >= DailyRewardConfig.COOLDOWN_SECONDS
end

function DailyRewardConfig.getTimeRemaining(lastClaimTime: number?): number
	local last = lastClaimTime or 0
	if last <= 0 then return 0 end
	local elapsed = os.time() - last
	return math.max(0, DailyRewardConfig.COOLDOWN_SECONDS - elapsed)
end

function DailyRewardConfig.formatTimeRemaining(seconds: number): string
	if seconds <= 0 then return "Ready!" end
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02dh %02dm %02ds", hours, mins, secs)
end

return DailyRewardConfig
