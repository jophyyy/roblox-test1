--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

export type MerchantMood = {
	name: string,
	badge: string,
	color: Color3,
	description: string,
}

local PetMerchantConfig = {}

PetMerchantConfig.CYCLE_DURATION = 60 -- 60 seconds per "Mind Change"
PetMerchantConfig.MIN_MULTIPLIER = 0.50
PetMerchantConfig.MAX_MULTIPLIER = 5.00

-- Base prices for Normal pets (as requested: base cat/pup is 500 bucks)
PetMerchantConfig.BASE_PRICES = {
	CrystalDoge = 500,
	SparkleKitty = 500,
	NeonBunny = 2500,
	InfernoDragon = 15000,
	VoidPhoenix = 100000,
	MagmaHound = 2500,
	VolcanicGolem = 15000,
	ElderMagmaDrake = 100000,
	AstralKitsune = 2500,
	VoidLeviathan = 15000,
	ChronosDrake = 1000000,
} :: { [string]: number }

function PetMerchantConfig.getBasePrice(petId: string): number
	local tier = PetConfig.getPetTier(petId)
	local baseId = PetConfig.getBasePetId(petId)
	local basePrice = PetMerchantConfig.BASE_PRICES[baseId] or 500

	if tier == "Golden" then
		return basePrice * 3
	elseif tier == "Rainbow" then
		return basePrice * 9
	end

	return basePrice
end

function PetMerchantConfig.calculatePrice(petId: string, multiplier: number): number
	local base = PetMerchantConfig.getBasePrice(petId)
	local finalPrice = math.floor(base * multiplier + 0.5)
	return math.max(10, finalPrice)
end

function PetMerchantConfig.getMood(multiplier: number): MerchantMood
	if multiplier < 1.00 then
		return {
			name = "Disinterested Lowballer",
			badge = "📉 LOWBALL",
			color = Color3.fromRGB(231, 76, 60),
			description = "Finneas is stingy and distracted. Save your pets for better rates!",
		}
	elseif multiplier < 1.60 then
		return {
			name = "Fair Trader",
			badge = "⚖️ FAIR",
			color = Color3.fromRGB(52, 152, 219),
			description = "Standard market rates. Decent payouts for common pets.",
		}
	elseif multiplier < 2.50 then
		return {
			name = "Eager Collector",
			badge = "📈 PROFITABLE",
			color = Color3.fromRGB(46, 204, 113),
			description = "Finneas is eager to expand his menagerie! Paying handsome markups.",
		}
	elseif multiplier < 4.00 then
		return {
			name = "Pet Craze Mania",
			badge = "🔥 PET CRAZE",
			color = Color3.fromRGB(241, 196, 15),
			description = "High demand frenzy! Phenomenal rates across all pet breeds.",
		}
	else
		return {
			name = "God-Tier Buyout",
			badge = "🚀 5X WINDFALL",
			color = Color3.fromRGB(255, 100, 220),
			description = "ULTIMATE 5X BUYOUT! Finneas is paying top dollar—dump your inventory!",
		}
	end
end

return PetMerchantConfig
