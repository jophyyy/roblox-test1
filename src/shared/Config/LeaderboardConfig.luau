--!strict
export type LeaderboardCategory = "Cash" | "Power" | "Rebirths"

export type LeaderboardEntry = {
	rank: number,
	userId: number,
	username: string,
	displayName: string,
	value: number,
	formattedValue: string,
	isLocalPlayer: boolean?,
}

export type CategoryDef = {
	id: LeaderboardCategory,
	title: string,
	shortTitle: string,
	icon: string,
	color: Color3,
	dataStoreName: string,
	statName: string,
	prefix: string,
	suffix: string,
}

local LeaderboardConfig = {}

LeaderboardConfig.CATEGORIES = {
	Cash = {
		id = "Cash",
		title = "💰 RICHEST MINERS",
		shortTitle = "Cash",
		icon = "💰",
		color = Color3.fromRGB(255, 215, 0),
		dataStoreName = "GlobalCashLeaderboard_v1",
		statName = "Cash",
		prefix = "$",
		suffix = "",
	},
	Power = {
		id = "Power",
		title = "⚡ STRONGEST CRUSHERS",
		shortTitle = "Power",
		icon = "⚡",
		color = Color3.fromRGB(0, 220, 255),
		dataStoreName = "GlobalPowerLeaderboard_v1",
		statName = "Power",
		prefix = "",
		suffix = " ⚡",
	},
	Rebirths = {
		id = "Rebirths",
		title = "🔄 REBIRTH LEGENDS",
		shortTitle = "Rebirths",
		icon = "🔄",
		color = Color3.fromRGB(210, 80, 255),
		dataStoreName = "GlobalRebirthLeaderboard_v1",
		statName = "Rebirths",
		prefix = "",
		suffix = " 🔄",
	},
} :: { [LeaderboardCategory]: CategoryDef }

LeaderboardConfig.ORDERED_CATEGORIES = {
	LeaderboardConfig.CATEGORIES.Cash,
	LeaderboardConfig.CATEGORIES.Power,
	LeaderboardConfig.CATEGORIES.Rebirths,
}

-- High-level simulated top players for solo/Studio playtesting fullness so boards are never barren
LeaderboardConfig.MOCK_PLAYERS = {
	{ userId = 1, username = "Roblox", displayName = "Roblox", cash = 250000000, power = 1500000, rebirths = 75 },
	{ userId = 261, username = "Shedletsky", displayName = "Telamon", cash = 120000000, power = 850000, rebirths = 50 },
	{ userId = 156, username = "Builderman", displayName = "Builderman", cash = 85000000, power = 620000, rebirths = 38 },
	{ userId = 2, username = "JohnDoe", displayName = "John Doe", cash = 45000000, power = 410000, rebirths = 25 },
	{ userId = 3, username = "JaneDoe", displayName = "Jane Doe", cash = 28000000, power = 290000, rebirths = 18 },
	{ userId = 2042, username = "Clockwork", displayName = "Clockwork", cash = 16000000, power = 180000, rebirths = 12 },
	{ userId = 1242, username = "BrightEyes", displayName = "BrightEyes", cash = 9500000, power = 120000, rebirths = 8 },
	{ userId = 18512, username = "Stickmasterluke", displayName = "Stickmasterluke", cash = 5000000, power = 75000, rebirths = 5 },
	{ userId = 3280, username = "Miked", displayName = "Miked", cash = 2500000, power = 42000, rebirths = 3 },
}

return LeaderboardConfig
