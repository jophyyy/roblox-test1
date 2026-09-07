--!strict
export type OreDef = {
	id: string,
	name: string,
	zone: "Zone1" | "Zone2" | "Zone3",
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

OreConfig.TOTAL_ACTIVE_ORES_ZONE1 = 20
OreConfig.TOTAL_ACTIVE_ORES_ZONE2 = 16
OreConfig.TOTAL_ACTIVE_ORES_ZONE3 = 16
OreConfig.RESPAWN_DELAY = 1.8
OreConfig.MAX_MINE_DISTANCE = 14

OreConfig.ORES = {
	-- ==========================================
	-- ZONE 1: SPAWN MEADOW ORES
	-- ==========================================
	Stone = {
		id = "Stone",
		name = "Stone Boulder",
		zone = "Zone1",
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
		zone = "Zone1",
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
		zone = "Zone1",
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
		zone = "Zone1",
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
		zone = "Zone1",
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
		zone = "Zone1",
		maxHealth = 1800,
		cashReward = 7500,
		gemsReward = 75,
		color = Color3.fromRGB(170, 40, 255),
		accentColor = Color3.fromRGB(255, 120, 255),
		scale = 1.8,
		weight = 2,
		icon = "🌌",
	},

	-- ==========================================
	-- ZONE 2: MAGMA CAVERNS ORES
	-- ==========================================
	MagmaBasalt = {
		id = "MagmaBasalt",
		name = "Magma Basalt Node",
		zone = "Zone2",
		maxHealth = 2500,
		cashReward = 15000,
		gemsReward = 100,
		color = Color3.fromRGB(35, 25, 25),
		accentColor = Color3.fromRGB(255, 80, 10),
		scale = 1.65,
		weight = 35,
		icon = "🌋",
	},
	ThunderQuartz = {
		id = "ThunderQuartz",
		name = "Thunder Quartz Vein",
		zone = "Zone2",
		maxHealth = 6000,
		cashReward = 45000,
		gemsReward = 250,
		color = Color3.fromRGB(255, 225, 60),
		accentColor = Color3.fromRGB(255, 255, 180),
		scale = 1.75,
		weight = 25,
		icon = "⚡",
	},
	MoltenCrystal = {
		id = "MoltenCrystal",
		name = "Molten Core Crystal",
		zone = "Zone2",
		maxHealth = 15000,
		cashReward = 140000,
		gemsReward = 650,
		color = Color3.fromRGB(255, 50, 20),
		accentColor = Color3.fromRGB(255, 170, 40),
		scale = 1.9,
		weight = 15,
		icon = "🔥",
	},
	InfernalGeode = {
		id = "InfernalGeode",
		name = "Infernal Dragon Geode",
		zone = "Zone2",
		maxHealth = 40000,
		cashReward = 500000,
		gemsReward = 2000,
		color = Color3.fromRGB(180, 20, 80),
		accentColor = Color3.fromRGB(255, 215, 0),
		scale = 2.1,
		weight = 5,
		icon = "👑",
	},

	-- ==========================================
	-- ZONE 3: THE COSMIC VOID ORES
	-- ==========================================
	StarlightCrystal = {
		id = "StarlightCrystal",
		name = "Starlight Crystal",
		zone = "Zone3",
		maxHealth = 60000,
		cashReward = 1800000,
		gemsReward = 4000,
		color = Color3.fromRGB(240, 240, 255),
		accentColor = Color3.fromRGB(140, 220, 255),
		scale = 1.8,
		weight = 35,
		icon = "🌟",
	},
	NebulaGeode = {
		id = "NebulaGeode",
		name = "Nebula Geode",
		zone = "Zone3",
		maxHealth = 150000,
		cashReward = 6500000,
		gemsReward = 12000,
		color = Color3.fromRGB(160, 40, 240),
		accentColor = Color3.fromRGB(255, 100, 255),
		scale = 2.0,
		weight = 25,
		icon = "🌌",
	},
	AstralVoidstone = {
		id = "AstralVoidstone",
		name = "Astral Voidstone",
		zone = "Zone3",
		maxHealth = 350000,
		cashReward = 22000000,
		gemsReward = 35000,
		color = Color3.fromRGB(40, 25, 60),
		accentColor = Color3.fromRGB(0, 240, 255),
		scale = 2.2,
		weight = 15,
		icon = "🪐",
	},
	DarkMatterCore = {
		id = "DarkMatterCore",
		name = "Dark Matter Core",
		zone = "Zone3",
		maxHealth = 800000,
		cashReward = 75000000,
		gemsReward = 100000,
		color = Color3.fromRGB(15, 10, 25),
		accentColor = Color3.fromRGB(255, 215, 0),
		scale = 2.5,
		weight = 5,
		icon = "💠",
	},
} :: { [string]: OreDef }

-- Spawning boundaries for Zone 1 (Meadow quadrants surrounding plaza)
OreConfig.SPAWN_ZONES_1 = {
	{ minX = -125, maxX = -28, minZ = -125, maxZ = -28 },
	{ minX = 28, maxX = 125, minZ = -125, maxZ = -28 },
	{ minX = -125, maxX = -28, minZ = 28, maxZ = 125 },
	{ minX = 28, maxX = 125, minZ = 28, maxZ = 125 },
}

-- Spawning boundaries for Zone 2 (Magma Caverns: Z = -165 to -275)
OreConfig.SPAWN_ZONES_2 = {
	{ minX = -100, maxX = -20, minZ = -275, maxZ = -165 },
	{ minX = 20, maxX = 100, minZ = -275, maxZ = -165 },
}

-- Spawning boundaries for Zone 3 (The Cosmic Void: Z = 165 to 275)
OreConfig.SPAWN_ZONES_3 = {
	{ minX = -100, maxX = -20, minZ = 165, maxZ = 275 },
	{ minX = 20, maxX = 100, minZ = 165, maxZ = 275 },
}

function OreConfig.getRandomOreTypeForZone(zone: "Zone1" | "Zone2" | "Zone3"): OreDef
	local pool = {}
	local totalWeight = 0
	for _, ore in OreConfig.ORES do
		if ore.zone == zone then
			table.insert(pool, ore)
			totalWeight += ore.weight
		end
	end

	local roll = math.random() * totalWeight
	local current = 0
	for _, ore in pool do
		current += ore.weight
		if roll <= current then
			return ore
		end
	end

	if zone == "Zone3" then
		return OreConfig.ORES.StarlightCrystal
	elseif zone == "Zone2" then
		return OreConfig.ORES.MagmaBasalt
	else
		return OreConfig.ORES.Stone
	end
end

function OreConfig.getRandomPositionForZone(zone: "Zone1" | "Zone2" | "Zone3"): Vector3
	if zone == "Zone3" then
		local bounds = OreConfig.SPAWN_ZONES_3[math.random(1, #OreConfig.SPAWN_ZONES_3)]
		local x = math.random(bounds.minX, bounds.maxX)
		local z = math.random(bounds.minZ, bounds.maxZ)
		return Vector3.new(x, 0.4, z)
	elseif zone == "Zone2" then
		local bounds = OreConfig.SPAWN_ZONES_2[math.random(1, #OreConfig.SPAWN_ZONES_2)]
		local x = math.random(bounds.minX, bounds.maxX)
		local z = math.random(bounds.minZ, bounds.maxZ)
		return Vector3.new(x, 0.4, z)
	else
		local bounds = OreConfig.SPAWN_ZONES_1[math.random(1, #OreConfig.SPAWN_ZONES_1)]
		local x = math.random(bounds.minX, bounds.maxX)
		local z = math.random(bounds.minZ, bounds.maxZ)
		return Vector3.new(x, 0.4, z)
	end
end

-- Backward compatibility helpers
function OreConfig.getRandomOreType(): OreDef
	return OreConfig.getRandomOreTypeForZone("Zone1")
end

function OreConfig.getRandomPosition(): Vector3
	return OreConfig.getRandomPositionForZone("Zone1")
end

return OreConfig
