--!strict
export type TrainingOreDef = {
	id: string,
	name: string,
	rebirthRequired: number,
	basePower: number,
	powerPerRebirth: number,
	color: Color3,
	accentColor: Color3,
	scale: number,
	position: Vector3,
	icon: string,
	description: string,
}

local TrainingConfig = {}

TrainingConfig.ARENA_CENTER = Vector3.new(105, 0.4, 0)
TrainingConfig.TRAINING_DISTANCE = 15
TrainingConfig.FACING_MIN_DOT = 0.32

TrainingConfig.ORES = {
	train_bronze = {
		id = "train_bronze",
		name = "Bronze Training Boulder",
		rebirthRequired = 0,
		basePower = 5,
		powerPerRebirth = 3,
		color = Color3.fromRGB(185, 120, 60),
		accentColor = Color3.fromRGB(230, 160, 90),
		scale = 1.0,
		position = Vector3.new(111, 0.4, -21),
		icon = "🥉",
		description = "Starter training rock. Perfect for fresh adventurers.",
	},
	train_iron = {
		id = "train_iron",
		name = "Iron Power Core",
		rebirthRequired = 1,
		basePower = 25,
		powerPerRebirth = 15,
		color = Color3.fromRGB(165, 175, 190),
		accentColor = Color3.fromRGB(220, 230, 250),
		scale = 1.15,
		position = Vector3.new(120, 0.4, -15.5),
		icon = "⚔️",
		description = "Dense iron monolith. Requires 1 Rebirth to train.",
	},
	train_gold = {
		id = "train_gold",
		name = "Gilded Power Monolith",
		rebirthRequired = 2,
		basePower = 100,
		powerPerRebirth = 60,
		color = Color3.fromRGB(255, 215, 0),
		accentColor = Color3.fromRGB(255, 245, 160),
		scale = 1.3,
		position = Vector3.new(126, 0.4, -5.7),
		icon = "🪙",
		description = "Emblazoned in pure gold. Grants immense power gains.",
	},
	train_diamond = {
		id = "train_diamond",
		name = "Diamond Energy Geode",
		rebirthRequired = 4,
		basePower = 400,
		powerPerRebirth = 250,
		color = Color3.fromRGB(0, 220, 255),
		accentColor = Color3.fromRGB(180, 250, 255),
		scale = 1.45,
		position = Vector3.new(126, 0.4, 5.7),
		icon = "💎",
		description = "Crystalline diamond facet vibrating with raw energy.",
	},
	train_magma = {
		id = "train_magma",
		name = "Molten Magma Core",
		rebirthRequired = 6,
		basePower = 1500,
		powerPerRebirth = 1000,
		color = Color3.fromRGB(255, 75, 15),
		accentColor = Color3.fromRGB(255, 170, 40),
		scale = 1.6,
		position = Vector3.new(120, 0.4, 15.5),
		icon = "🔥",
		description = "Forged in ancient magma. Grants cataclysmic power training.",
	},
	train_cosmic = {
		id = "train_cosmic",
		name = "Cosmic Celestial Star",
		rebirthRequired = 10,
		basePower = 6000,
		powerPerRebirth = 4000,
		color = Color3.fromRGB(190, 50, 255),
		accentColor = Color3.fromRGB(255, 120, 255),
		scale = 1.8,
		position = Vector3.new(111, 0.4, 21),
		icon = "🌌",
		description = "Starlight matter from deep space. The ultimate training node.",
	},
} :: { [string]: TrainingOreDef }

function TrainingConfig.getOre(oreId: string): TrainingOreDef?
	return TrainingConfig.ORES[oreId]
end

function TrainingConfig.calculatePower(
	oreDef: TrainingOreDef,
	rebirths: number,
	pickaxeMultiplier: number,
	petMultiplier: number,
	trailMultiplier: number,
	skillMultiplier: number
): number
	local effectiveRebirths = math.max(0, rebirths)
	local oreBaseYield = oreDef.basePower + (effectiveRebirths * oreDef.powerPerRebirth)
	local totalGain = math.max(1, math.floor(oreBaseYield * pickaxeMultiplier * petMultiplier * trailMultiplier * skillMultiplier))
	return totalGain
end

return TrainingConfig
