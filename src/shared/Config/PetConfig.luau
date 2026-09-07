export type PetTier = "Normal" | "Golden" | "Rainbow"

export type PetDef = {
	id: string,
	baseId: string?,
	tier: PetTier?,
	name: string,
	rarity: "Common" | "Rare" | "Epic" | "Legendary" | "Mythic",
	cashMultiplier: number,
	gemMultiplier: number,
	color: Color3,
	meshType: "Sphere" | "Block" | "Diamond",
	icon: string,
	originEgg: string,
}

export type EggDef = {
	id: string,
	name: string,
	cost: number,
	currency: "Gems" | "Robux",
	productId: number?,
	dropPool: { { petId: string, weight: number } },
}

export type PetIndexMilestone = {
	id: string,
	name: string,
	requiredCount: number,
	gemsReward: number,
	powerBoostPct: number,
	icon: string,
}

local PetConfig = {
	MAX_EQUIPPED = 3,

	INDEX_MILESTONES = {
		{
			id = "milestone_3",
			name = "Bronze Collector",
			requiredCount = 3,
			gemsReward = 5000,
			powerBoostPct = 15,
			icon = "🥉",
		},
		{
			id = "milestone_6",
			name = "Silver Zoologist",
			requiredCount = 6,
			gemsReward = 25000,
			powerBoostPct = 35,
			icon = "🥈",
		},
		{
			id = "milestone_9",
			name = "Gold Beastmaster",
			requiredCount = 9,
			gemsReward = 100000,
			powerBoostPct = 75,
			icon = "🥇",
		},
		{
			id = "milestone_11",
			name = "Cosmic Master",
			requiredCount = 11,
			gemsReward = 500000,
			powerBoostPct = 150,
			icon = "👑",
		},
	} :: { PetIndexMilestone },

	PETS = {
		CrystalDoge = {
			id = "CrystalDoge",
			name = "Crystal Pup",
			rarity = "Common",
			cashMultiplier = 1.25,
			gemMultiplier = 1.1,
			color = Color3.fromRGB(240, 200, 80),
			meshType = "Block",
			icon = "🐶",
			originEgg = "BasicEgg",
		},
		SparkleKitty = {
			id = "SparkleKitty",
			name = "Sparkle Kitty",
			rarity = "Common",
			cashMultiplier = 1.35,
			gemMultiplier = 1.15,
			color = Color3.fromRGB(255, 182, 193),
			meshType = "Block",
			icon = "🐱",
			originEgg = "BasicEgg",
		},
		NeonBunny = {
			id = "NeonBunny",
			name = "Neon Bunny",
			rarity = "Rare",
			cashMultiplier = 1.6,
			gemMultiplier = 1.3,
			color = Color3.fromRGB(80, 240, 255),
			meshType = "Sphere",
			icon = "🐰",
			originEgg = "BasicEgg",
		},
		InfernoDragon = {
			id = "InfernoDragon",
			name = "Inferno Drake",
			rarity = "Epic",
			cashMultiplier = 2.2,
			gemMultiplier = 1.75,
			color = Color3.fromRGB(255, 69, 0),
			meshType = "Diamond",
			icon = "🐉",
			originEgg = "RobuxEgg",
		},
		VoidPhoenix = {
			id = "VoidPhoenix",
			name = "Void Phoenix",
			rarity = "Legendary",
			cashMultiplier = 3.5,
			gemMultiplier = 2.5,
			color = Color3.fromRGB(186, 85, 211),
			meshType = "Diamond",
			icon = "🦅",
			originEgg = "RobuxEgg",
		},
		MagmaHound = {
			id = "MagmaHound",
			name = "Magma Hound",
			rarity = "Rare",
			cashMultiplier = 4.5,
			gemMultiplier = 3.0,
			color = Color3.fromRGB(255, 120, 20),
			meshType = "Sphere",
			icon = "🐕",
			originEgg = "MagmaEgg",
		},
		VolcanicGolem = {
			id = "VolcanicGolem",
			name = "Volcanic Golem",
			rarity = "Epic",
			cashMultiplier = 8.0,
			gemMultiplier = 5.5,
			color = Color3.fromRGB(50, 32, 32),
			meshType = "Block",
			icon = "🗿",
			originEgg = "MagmaEgg",
		},
		ElderMagmaDrake = {
			id = "ElderMagmaDrake",
			name = "Elder Magma Drake",
			rarity = "Legendary",
			cashMultiplier = 16.0,
			gemMultiplier = 10.0,
			color = Color3.fromRGB(255, 40, 0),
			meshType = "Diamond",
			icon = "🐲",
			originEgg = "MagmaEgg",
		},
		AstralKitsune = {
			id = "AstralKitsune",
			name = "Astral Kitsune",
			rarity = "Rare",
			cashMultiplier = 25.0,
			gemMultiplier = 15.0,
			color = Color3.fromRGB(170, 110, 255),
			meshType = "Sphere",
			icon = "🦊",
			originEgg = "CosmicEgg",
		},
		VoidLeviathan = {
			id = "VoidLeviathan",
			name = "Void Leviathan",
			rarity = "Epic",
			cashMultiplier = 60.0,
			gemMultiplier = 40.0,
			color = Color3.fromRGB(30, 25, 60),
			meshType = "Block",
			icon = "🐋",
			originEgg = "CosmicEgg",
		},
		ChronosDrake = {
			id = "ChronosDrake",
			name = "Chronos Void Drake",
			rarity = "Mythic",
			cashMultiplier = 180.0,
			gemMultiplier = 100.0,
			color = Color3.fromRGB(0, 240, 255),
			meshType = "Diamond",
			icon = "🌌",
			originEgg = "CosmicEgg",
		},
	} :: { [string]: PetDef },

	EGGS = {
		BasicEgg = {
			id = "BasicEgg",
			name = "Prism Egg",
			cost = 100,
			currency = "Gems",
			dropPool = {
				{ petId = "CrystalDoge", weight = 55 },
				{ petId = "SparkleKitty", weight = 35 },
				{ petId = "NeonBunny", weight = 10 },
			},
		},
		CosmicEgg = {
			id = "CosmicEgg",
			name = "Cosmic Void Egg",
			cost = 25000,
			currency = "Gems",
			dropPool = {
				{ petId = "AstralKitsune", weight = 60 },
				{ petId = "VoidLeviathan", weight = 35 },
				{ petId = "ChronosDrake", weight = 5 },
			},
		},
		MagmaEgg = {
			id = "MagmaEgg",
			name = "Magma Egg",
			cost = 1500,
			currency = "Gems",
			dropPool = {
				{ petId = "MagmaHound", weight = 55 },
				{ petId = "VolcanicGolem", weight = 35 },
				{ petId = "ElderMagmaDrake", weight = 10 },
			},
		},
		RobuxEgg = {
			id = "RobuxEgg",
			name = "Exclusive Robux Egg",
			cost = 1000,
			currency = "Robux",
			productId = 0, -- 0 for dev test fallback; set to real Developer Product ID in production
			dropPool = {
				{ petId = "NeonBunny", weight = 50 },
				{ petId = "InfernoDragon", weight = 35 },
				{ petId = "VoidPhoenix", weight = 15 },
			},
		},
	} :: { [string]: EggDef },

	BASE_PET_IDS = {
		"CrystalDoge",
		"SparkleKitty",
		"NeonBunny",
		"InfernoDragon",
		"VoidPhoenix",
		"MagmaHound",
		"VolcanicGolem",
		"ElderMagmaDrake",
		"AstralKitsune",
		"VoidLeviathan",
		"ChronosDrake",
	} :: { string },
}

-- Populate Golden (3x multiplier bonus) and Rainbow (9x multiplier bonus) pet variants
for _, baseId in ipairs(PetConfig.BASE_PET_IDS) do
	local base = PetConfig.PETS[baseId]
	if base then
		base.tier = "Normal"
		base.baseId = baseId

		-- 🌟 Golden Variant (Crafted from 3 Normal pets)
		local goldenId = baseId .. "_Golden"
		local goldCashMult = 1.0 + (base.cashMultiplier - 1.0) * 3.0
		local goldGemMult = 1.0 + (base.gemMultiplier - 1.0) * 3.0
		PetConfig.PETS[goldenId] = {
			id = goldenId,
			baseId = baseId,
			tier = "Golden",
			name = "Golden " .. base.name,
			rarity = base.rarity,
			cashMultiplier = math.floor(goldCashMult * 100 + 0.5) / 100,
			gemMultiplier = math.floor(goldGemMult * 100 + 0.5) / 100,
			color = Color3.fromRGB(255, 215, 0),
			meshType = base.meshType,
			icon = "🌟 " .. base.icon,
			originEgg = base.originEgg,
		}

		-- 🌈 Rainbow Variant (Crafted from 3 Golden pets)
		local rainbowId = baseId .. "_Rainbow"
		local rbCashMult = 1.0 + (base.cashMultiplier - 1.0) * 9.0
		local rbGemMult = 1.0 + (base.gemMultiplier - 1.0) * 9.0
		PetConfig.PETS[rainbowId] = {
			id = rainbowId,
			baseId = baseId,
			tier = "Rainbow",
			name = "Rainbow " .. base.name,
			rarity = base.rarity,
			cashMultiplier = math.floor(rbCashMult * 100 + 0.5) / 100,
			gemMultiplier = math.floor(rbGemMult * 100 + 0.5) / 100,
			color = Color3.fromRGB(255, 100, 220),
			meshType = base.meshType,
			icon = "🌈 " .. base.icon,
			originEgg = base.originEgg,
		}
	end
end

function PetConfig.getBasePetId(petId: string): string
	local baseId = string.gsub(petId, "_Golden$", "")
	baseId = string.gsub(baseId, "_Rainbow$", "")
	return baseId
end

function PetConfig.getPetTier(petId: string): PetTier
	if string.find(petId, "_Rainbow$") then
		return "Rainbow"
	elseif string.find(petId, "_Golden$") then
		return "Golden"
	end
	return "Normal"
end

function PetConfig.getGoldenId(baseId: string): string
	return PetConfig.getBasePetId(baseId) .. "_Golden"
end

function PetConfig.getRainbowId(baseId: string): string
	return PetConfig.getBasePetId(baseId) .. "_Rainbow"
end

function PetConfig.getTotalBasePetsCount(): number
	return #PetConfig.BASE_PET_IDS
end

function PetConfig.getTotalPetsCount(): number
	return #PetConfig.BASE_PET_IDS
end

function PetConfig.getTierColor(tier: PetTier): Color3
	if tier == "Golden" then
		return Color3.fromRGB(255, 215, 0)
	elseif tier == "Rainbow" then
		return Color3.fromRGB(255, 100, 220)
	end
	return Color3.fromRGB(200, 210, 225)
end

function PetConfig.getRarityColor(rarity: string): Color3
	if rarity == "Common" then
		return Color3.fromRGB(180, 190, 205)
	elseif rarity == "Rare" then
		return Color3.fromRGB(0, 200, 255)
	elseif rarity == "Epic" then
		return Color3.fromRGB(190, 70, 255)
	elseif rarity == "Legendary" then
		return Color3.fromRGB(255, 140, 20)
	elseif rarity == "Mythic" then
		return Color3.fromRGB(255, 215, 0)
	end
	return Color3.fromRGB(200, 200, 200)
end

return PetConfig
