--!strict
export type MobDef = {
	name: string,
	count: number,
	maxHealth: number,
	attackDamage: number,
	walkSpeed: number,
	size: Vector3,
	color: Color3,
	eyeColor: Color3,
	material: Enum.Material,
}

export type StageReward = {
	cash: number,
	gems: number,
	crateId: string?,
	masteryXP: { track: string, amount: number }?,
}

export type StageDef = {
	stageNumber: number,
	title: string,
	isBoss: boolean,
	bossId: string?,
	mobs: MobDef?,
	reward: StageReward,
}

local DungeonConfig = {}

DungeonConfig.ARENA_CENTER = Vector3.new(300, 20, 0)
DungeonConfig.PLAYER_SPAWN = Vector3.new(300, 21.5, 30)
DungeonConfig.EXIT_PORTAL = Vector3.new(300, 21.5, 36)
DungeonConfig.TOWN_PORTAL_POS = Vector3.new(-92, 0.5, -92)
DungeonConfig.TOWN_RETURN_POS = Vector3.new(0, 2.5, 0)
DungeonConfig.ARENA_RADIUS = 38

DungeonConfig.STAGES = {
	[1] = {
		stageNumber = 1,
		title = "Cave Imps",
		isBoss = false,
		mobs = {
			name = "Cave Imp",
			count = 3,
			maxHealth = 1000,
			attackDamage = 8,
			walkSpeed = 12,
			size = Vector3.new(3, 3, 3),
			color = Color3.fromRGB(56, 85, 45),
			eyeColor = Color3.fromRGB(120, 255, 60),
			material = Enum.Material.Cobblestone,
		},
		reward = { cash = 15000, gems = 50 },
	},
	[2] = {
		stageNumber = 2,
		title = "Ruin Skeletons",
		isBoss = false,
		mobs = {
			name = "Ruin Skeleton",
			count = 4,
			maxHealth = 2800,
			attackDamage = 14,
			walkSpeed = 14,
			size = Vector3.new(3.2, 4.5, 3.2),
			color = Color3.fromRGB(180, 185, 190),
			eyeColor = Color3.fromRGB(255, 60, 60),
			material = Enum.Material.Plastic,
		},
		reward = { cash = 35000, gems = 120 },
	},
	[3] = {
		stageNumber = 3,
		title = "Obsidian Golemites",
		isBoss = false,
		mobs = {
			name = "Obsidian Golemite",
			count = 4,
			maxHealth = 6500,
			attackDamage = 20,
			walkSpeed = 15,
			size = Vector3.new(4, 4.5, 4),
			color = Color3.fromRGB(25, 28, 35),
			eyeColor = Color3.fromRGB(0, 240, 255),
			material = Enum.Material.Basalt,
		},
		reward = { cash = 75000, gems = 250, crateId = "block_wood" },
	},
	[4] = {
		stageNumber = 4,
		title = "Magma Brutes",
		isBoss = false,
		mobs = {
			name = "Magma Brute",
			count = 3,
			maxHealth = 14000,
			attackDamage = 28,
			walkSpeed = 13,
			size = Vector3.new(5.5, 6.5, 5.5),
			color = Color3.fromRGB(140, 35, 15),
			eyeColor = Color3.fromRGB(255, 200, 30),
			material = Enum.Material.CrackedLava,
		},
		reward = { cash = 150000, gems = 500, crateId = "block_iron" },
	},
	[5] = {
		stageNumber = 5,
		title = "Infernal Magma Golem",
		isBoss = true,
		bossId = "InfernalMagmaGolem",
		reward = {
			cash = 500000,
			gems = 2000,
			crateId = "block_gold",
			masteryXP = { track = "BossSlayer", amount = 500 },
		},
	},
}

function DungeonConfig.getStage(stageNum: number): StageDef?
	return DungeonConfig.STAGES[stageNum]
end

return DungeonConfig
