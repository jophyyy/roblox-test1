--!strict
export type GamepassDef = {
	id: string,
	name: string,
	passId: number, -- Set your real Pass ID from https://create.roblox.com/dashboard/creations
	cost: number,
	description: string,
	icon: string,
	gemMultiplier: number,
}

local GamepassConfig = {}

GamepassConfig.PASSES = {
	VIP = {
		id = "VIP",
		name = "VIP Membership",
		passId = 0, -- Set your Gamepass ID here when published to Roblox!
		cost = 400,
		description = "Permanent 2x Gem Multiplier on all mining & ore harvesting, plus a Golden [VIP] crown tag!",
		icon = "👑",
		gemMultiplier = 2.0,
	},
} :: { [string]: GamepassDef }

return GamepassConfig
