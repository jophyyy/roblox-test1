--!strict
local MeteorConfig = {}

export type CrashLocation = {
	id: string,
	zoneName: string,
	zoneIcon: string,
	position: Vector3,
	color: Color3,
}

MeteorConfig.COUNTDOWN_DURATION = 15 -- seconds from alert to crash
MeteorConfig.EVENT_DURATION = 120 -- seconds to mine before meteor dissipates
MeteorConfig.AUTO_INTERVAL_MIN = 360 -- 6 minutes
MeteorConfig.AUTO_INTERVAL_MAX = 480 -- 8 minutes

MeteorConfig.BASE_HEALTH = 3000 -- Base HP for the meteor monolith
MeteorConfig.HEALTH_PER_PLAYER = 2000 -- Extra HP per player on server

MeteorConfig.CRASH_LOCATIONS = {
	{
		id = "MeadowNorthwest",
		zoneName = "Zone 1: Meadow Fields (NW)",
		zoneIcon = "🌿",
		position = Vector3.new(-65, 0.4, -65),
		color = Color3.fromRGB(0, 240, 180),
	},
	{
		id = "MeadowSoutheast",
		zoneName = "Zone 1: Meadow Fields (SE)",
		zoneIcon = "🌿",
		position = Vector3.new(65, 0.4, 65),
		color = Color3.fromRGB(0, 240, 180),
	},
	{
		id = "MeadowSouthwest",
		zoneName = "Zone 1: Meadow Fields (SW)",
		zoneIcon = "🌿",
		position = Vector3.new(-65, 0.4, 65),
		color = Color3.fromRGB(0, 240, 180),
	},
	{
		id = "MagmaCaverns",
		zoneName = "Zone 2: Magma Caverns",
		zoneIcon = "🔥",
		position = Vector3.new(0, 0.4, -200),
		color = Color3.fromRGB(255, 100, 20),
	},
	{
		id = "CosmicVoid",
		zoneName = "Zone 3: Cosmic Void",
		zoneIcon = "🌌",
		position = Vector3.new(0, 0.4, 200),
		color = Color3.fromRGB(180, 60, 255),
	},
} :: { CrashLocation }

-- Multipliers and payouts
MeteorConfig.REWARDS = {
	-- Instant reward per pickaxe strike
	PerHit = {
		CashBase = 5000,
		GemsBase = 25,
		PowerBase = 15,
	},
	-- Server-wide jackpot granted to all miners upon 0 HP
	Jackpot = {
		CashBase = 25_000_000, -- $25,000,000 base
		GemsBase = 15_000, -- 15,000 gems
		PowerBase = 5_000,
		MasteryXP = 500, -- granted to all tracks
		CratesCount = 3, -- 3 guaranteed loot boxes
		CrateTypes = { "Obsidian", "Celestial", "Prismatic" },
	},
}

return MeteorConfig
