--!strict
export type WheelRewardType = "Cash" | "GemsFlat" | "GemsPercent" | "Pet" | "Jackpot"

export type WheelSlice = {
	index: number,
	name: string,
	label: string,
	icon: string,
	rewardType: WheelRewardType,
	value: any,
	color: Color3,
	textColor: Color3,
	rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic",
	weight: number,
}

local WheelConfig = {
	COOLDOWN_SECONDS = 120, -- 2 minutes between free spins
	GEM_SPIN_COST = 50, -- Optional gem spin cost to bypass cooldown

	SLICES = {
		{
			index = 1,
			name = "Cash Bounty",
			label = "+$75,000",
			icon = "💵",
			rewardType = "Cash",
			value = 75000,
			color = Color3.fromRGB(46, 204, 113),
			textColor = Color3.fromRGB(255, 255, 255),
			rarity = "Common",
			weight = 28,
		},
		{
			index = 2,
			name = "Gem Stash",
			label = "+150 Gems",
			icon = "💎",
			rewardType = "GemsFlat",
			value = 150,
			color = Color3.fromRGB(52, 152, 219),
			textColor = Color3.fromRGB(255, 255, 255),
			rarity = "Common",
			weight = 24,
		},
		{
			index = 3,
			name = "Gems Boost",
			label = "+25% Gems",
			icon = "💎⚡",
			rewardType = "GemsPercent",
			value = { percent = 0.25, min = 75 },
			color = Color3.fromRGB(155, 89, 182),
			textColor = Color3.fromRGB(255, 255, 255),
			rarity = "Uncommon",
			weight = 18,
		},
		{
			index = 4,
			name = "Mega Cash",
			label = "+$500,000",
			icon = "💰",
			rewardType = "Cash",
			value = 500000,
			color = Color3.fromRGB(241, 196, 15),
			textColor = Color3.fromRGB(30, 30, 30),
			rarity = "Uncommon",
			weight = 14,
		},
		{
			index = 5,
			name = "Super Gems",
			label = "+50% Gems",
			icon = "💎🔥",
			rewardType = "GemsPercent",
			value = { percent = 0.50, min = 150 },
			color = Color3.fromRGB(230, 126, 34),
			textColor = Color3.fromRGB(255, 255, 255),
			rarity = "Rare",
			weight = 9,
		},
		{
			index = 6,
			name = "Neon Bunny",
			label = "🐾 Neon Bunny",
			icon = "🐰",
			rewardType = "Pet",
			value = "NeonBunny",
			color = Color3.fromRGB(0, 220, 255),
			textColor = Color3.fromRGB(20, 30, 50),
			rarity = "Epic",
			weight = 5,
		},
		{
			index = 7,
			name = "Inferno Drake",
			label = "🐾 Inferno Drake",
			icon = "🐲",
			rewardType = "Pet",
			value = "InfernoDragon",
			color = Color3.fromRGB(231, 76, 60),
			textColor = Color3.fromRGB(255, 255, 255),
			rarity = "Legendary",
			weight = 1.8,
		},
		{
			index = 8,
			name = "JACKPOT!",
			label = "2x Gems + Phoenix",
			icon = "👑",
			rewardType = "Jackpot",
			value = { gemMultiplier = 2.0, minGems = 500, petId = "VoidPhoenix" },
			color = Color3.fromRGB(255, 215, 0),
			textColor = Color3.fromRGB(50, 20, 0),
			rarity = "Mythic",
			weight = 0.2,
		},
	} :: { WheelSlice },
}

function WheelConfig.getTotalWeight(): number
	local total = 0
	for _, slice in ipairs(WheelConfig.SLICES) do
		total += slice.weight
	end
	return total
end

function WheelConfig.rollSlice(): (WheelSlice, number)
	local total = WheelConfig.getTotalWeight()
	local roll = math.random() * total
	local cumulative = 0

	for i, slice in ipairs(WheelConfig.SLICES) do
		cumulative += slice.weight
		if roll <= cumulative then
			return slice, i
		end
	end

	return WheelConfig.SLICES[1], 1
end

return WheelConfig
