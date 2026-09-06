--!strict
export type OreDef = {
	id: string,
	name: string,
	maxHealth: number,
	cashReward: number,
	gemsReward: number,
	color: Color3,
	accentColor: Color3,
	scale: number,
	weight: number,
	icon: string,
}

local OreConfig = {}

OreConfig.TOTAL_ACTIVE_ORES = 24
OreConfig.RESPAWN_DELAY = 1.8
OreConfig.MAX_MINE_DISTANCE = 14

OreConfig.ORES = {
	Stone = {
		id = "Stone",
		name = "Stone Boulder",
		maxHealth = 25,
		cashReward = 25,
		gemsReward = 1,
		color = Color3.fromRGB(115, 120, 130),
		accentColor = Color3.fromRGB(80, 85, 95),
		scale = 1.0,
		weight = 40,
		icon = "🪨",
	},
	Copper = {
		id = "Copper",
		name = "Copper Vein",
		maxHealth = 60,
		cashReward = 80,
		gemsReward = 2,
		color = Color3.fromRGB(195, 115, 50),
		accentColor = Color3.fromRGB(240, 160, 90),
		scale = 1.15,
		weight = 25,
		icon = "🥉",
	},
	Iron = {
		id = "Iron",
		name = "Iron Ore",
		maxHealth = 140,
		cashReward = 240,
		gemsReward = 4,
		color = Color3.fromRGB(165, 175, 190),
		accentColor = Color3.fromRGB(220, 230, 245),
		scale = 1.3,
		weight = 18,
		icon = "⚔️",
	},
	Gold = {
		id = "Gold",
		name = "Gilded Gold Vein",
		maxHealth = 320,
		cashReward = 750,
		gemsReward = 10,
		color = Color3.fromRGB(255, 215, 0),
		accentColor = Color3.fromRGB(255, 245, 160),
		scale = 1.45,
		weight = 10,
		icon = "🪙",
	},
	Diamond = {
		id = "Diamond",
		name = "Diamond Crystal",
		maxHealth = 750,
		cashReward = 2200,
		gemsReward = 25,
		color = Color3.fromRGB(0, 220, 255),
		accentColor = Color3.fromRGB(180, 250, 255),
		scale = 1.6,
		weight = 5,
		icon = "💎",
	},
	CosmicVoid = {
		id = "CosmicVoid",
		name = "Cosmic Void Geode",
		maxHealth = 1800,
		cashReward = 7500,
		gemsReward = 75,
		color = Color3.fromRGB(170, 40, 255),
		accentColor = Color3.fromRGB(255, 120, 255),
		scale = 1.8,
		weight = 2,
		icon = "🌌",
	},
} :: { [string]: OreDef }

-- Spawning boundaries (Meadow quadrants surrounding the central plaza)
-- Baseplate is 320x320 studs: [-130, 130] in X and Z
-- Plaza is [-24, 24] in X and Z
OreConfig.SPAWN_ZONES = {
	-- North-West Quadrant
	{ minX = -125, maxX = -28, minZ = -125, maxZ = -28 },
	-- North-East Quadrant
	{ minX = 28, maxX = 125, minZ = -125, maxZ = -28 },
	-- South-West Quadrant
	{ minX = -125, maxX = -28, minZ = 28, maxZ = 125 },
	-- South-East Quadrant
	{ minX = 28, maxX = 125, minZ = 28, maxZ = 125 },
}

function OreConfig.getRandomOreType(): OreDef
	local totalWeight = 0
	for _, ore in OreConfig.ORES do
		totalWeight += ore.weight
	end

	local roll = math.random() * totalWeight
	local current = 0
	for _, ore in OreConfig.ORES do
		current += ore.weight
		if roll <= current then
			return ore
		end
	end

	return OreConfig.ORES.Stone
end

function OreConfig.getRandomPosition(): Vector3
	local zone = OreConfig.SPAWN_ZONES[math.random(1, #OreConfig.SPAWN_ZONES)]
	local x = math.random(zone.minX, zone.maxX)
	local z = math.random(zone.minZ, zone.maxZ)
	return Vector3.new(x, 0.4, z)
end

return OreConfig
