--!strict
export type ZoneDef = {
	id: string,
	name: string,
	rebirthRequired: number,
	color: Color3,
	icon: string,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
}

local ZoneConfig = {}

ZoneConfig.ZONES = {
	Zone1 = {
		id = "Zone1",
		name = "Spawn Meadow",
		rebirthRequired = 0,
		color = Color3.fromRGB(80, 220, 100),
		icon = "🌱",
		bounds = { minX = -130, maxX = 130, minZ = -130, maxZ = 130 },
	},
	Zone2 = {
		id = "Zone2",
		name = "Magma Caverns",
		rebirthRequired = 5,
		color = Color3.fromRGB(255, 80, 20),
		icon = "🌋",
		bounds = { minX = -110, maxX = 110, minZ = -285, maxZ = -155 },
	},
	TrainingQuarry = {
		id = "TrainingQuarry",
		name = "The Power Quarry",
		rebirthRequired = 0,
		color = Color3.fromRGB(255, 205, 30),
		icon = "⚡",
		bounds = { minX = 68, maxX = 148, minZ = -45, maxZ = 45 },
	},
	Zone3 = {
		id = "Zone3",
		name = "The Cosmic Void",
		rebirthRequired = 10,
		color = Color3.fromRGB(190, 60, 255),
		icon = "🌌",
		bounds = { minX = -120, maxX = 120, minZ = 140, maxZ = 300 },
	},
} :: { [string]: ZoneDef }

return ZoneConfig
