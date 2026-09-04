--!strict
local RebirthConfig = {}

RebirthConfig.BASE_COST = 10000
RebirthConfig.COST_EXPONENT = 2.2
RebirthConfig.MULTIPLIER_PER_REBIRTH = 0.5 -- +50% earnings per rebirth
RebirthConfig.GEMS_PER_REBIRTH = 100

function RebirthConfig.getCostForRebirth(currentRebirths: number): number
	return math.floor(RebirthConfig.BASE_COST * ((currentRebirths + 1) ^ RebirthConfig.COST_EXPONENT))
end

function RebirthConfig.getMultiplier(currentRebirths: number): number
	return 1 + (currentRebirths * RebirthConfig.MULTIPLIER_PER_REBIRTH)
end

function RebirthConfig.getRewardGems(currentRebirths: number): number
	return math.floor(RebirthConfig.GEMS_PER_REBIRTH * (currentRebirths + 1))
end

return RebirthConfig

