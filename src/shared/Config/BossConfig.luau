--!strict
export type BossPickaxeTrait = {
	pickaxeId: string,
	bossDamageMultiplier: number,
	critChance: number,
	critMultiplier: number,
	specialEffect: "None" | "Stun" | "GoldRush" | "ArmorPierce" | "VoidSiphon" | "MoltenBurn" | "DragonWrath",
	effectDescription: string,
	damageColor: Color3,
}

export type BossDef = {
	id: string,
	name: string,
	title: string,
	maxHealth: number,
	attackDamage: number,
	attackCooldown: number,
	attackRadius: number,
	aggroRadius: number,
	respawnTime: number,
	arenaCenter: Vector3,
	arenaRadius: number,
	rewardCash: number,
	rewardGems: number,
}

local BossConfig = {}

BossConfig.BOSS = {
	id = "InfernalMagmaGolem",
	name = "Infernal Magma Golem",
	title = "World Boss • Zone 2",
	maxHealth = 50000,
	attackDamage = 25,
	attackCooldown = 2.0,
	attackRadius = 12,
	aggroRadius = 45,
	respawnTime = 20,
	arenaCenter = Vector3.new(0, 0.4, -260),
	arenaRadius = 50,
	rewardCash = 1000000,
	rewardGems = 5000,
} :: BossDef

BossConfig.PICKAXE_TRAITS = {
	shovel_rusty = {
		pickaxeId = "shovel_rusty",
		bossDamageMultiplier = 1.0,
		critChance = 0.05,
		critMultiplier = 1.5,
		specialEffect = "None",
		effectDescription = "Standard chipping blows",
		damageColor = Color3.fromRGB(220, 220, 220),
	},
	shovel_iron = {
		pickaxeId = "shovel_iron",
		bossDamageMultiplier = 1.5,
		critChance = 0.12,
		critMultiplier = 1.75,
		specialEffect = "Stun",
		effectDescription = "15% chance to stagger and pause the boss for 0.8s",
		damageColor = Color3.fromRGB(180, 210, 255),
	},
	shovel_gold = {
		pickaxeId = "shovel_gold",
		bossDamageMultiplier = 2.2,
		critChance = 0.15,
		critMultiplier = 2.0,
		specialEffect = "GoldRush",
		effectDescription = "Siphons +$250 bonus Cash directly from the boss on every hit",
		damageColor = Color3.fromRGB(255, 215, 0),
	},
	shovel_diamond = {
		pickaxeId = "shovel_diamond",
		bossDamageMultiplier = 3.5,
		critChance = 0.30,
		critMultiplier = 2.5,
		specialEffect = "ArmorPierce",
		effectDescription = "Armor-piercing diamond facets deliver frequent critical strikes",
		damageColor = Color3.fromRGB(0, 230, 255),
	},
	shovel_void = {
		pickaxeId = "shovel_void",
		bossDamageMultiplier = 5.5,
		critChance = 0.25,
		critMultiplier = 3.0,
		specialEffect = "VoidSiphon",
		effectDescription = "Void explosion siphons dark energy, restoring +10 HP to the player",
		damageColor = Color3.fromRGB(210, 60, 255),
	},
	shovel_magma = {
		pickaxeId = "shovel_magma",
		bossDamageMultiplier = 9.0,
		critChance = 0.35,
		critMultiplier = 3.2,
		specialEffect = "MoltenBurn",
		effectDescription = "Inflicts severe molten burn ticks over time",
		damageColor = Color3.fromRGB(255, 80, 20),
	},
	shovel_infernal = {
		pickaxeId = "shovel_infernal",
		bossDamageMultiplier = 15.0,
		critChance = 0.40,
		critMultiplier = 4.0,
		specialEffect = "DragonWrath",
		effectDescription = "Cataclysmic draconic fury with devastating 4x critical strikes",
		damageColor = Color3.fromRGB(255, 215, 0),
	},
} :: { [string]: BossPickaxeTrait }

function BossConfig.getTrait(shovelId: string?): BossPickaxeTrait
	if shovelId and BossConfig.PICKAXE_TRAITS[shovelId] then
		return BossConfig.PICKAXE_TRAITS[shovelId]
	end
	return BossConfig.PICKAXE_TRAITS.shovel_rusty
end

function BossConfig.calculateDamage(
	playerPower: number,
	shovelId: string?,
	rebirthMultiplier: number,
	petMultiplier: number
): (number, boolean, BossPickaxeTrait)
	local trait = BossConfig.getTrait(shovelId)
	local isCrit = math.random() <= trait.critChance
	local critMult = if isCrit then trait.critMultiplier else 1.0

	local totalDamage = math.max(1, math.floor(playerPower * trait.bossDamageMultiplier * rebirthMultiplier * petMultiplier * critMult))
	return totalDamage, isCrit, trait
end

return BossConfig
