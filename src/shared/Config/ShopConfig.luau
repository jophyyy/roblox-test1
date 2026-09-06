--!strict
export type ShovelDef = {
	id: string,
	name: string,
	category: "Shovel",
	cost: number,
	clickCash: number,
	clickGems: number,
	description: string,
	color: Color3,
	icon: string,
}

export type BackpackDef = {
	id: string,
	name: string,
	category: "Backpack",
	cost: number,
	multiplier: number, -- e.g. 1.15 = +15% Mining Cash
	bonusGems: number,
	description: string,
	color: Color3,
	icon: string,
}

local ShopConfig = {}

ShopConfig.SHOVELS = {
	{
		id = "shovel_rusty",
		name = "Rusty Trowel",
		category = "Shovel",
		cost = 100,
		clickCash = 8,
		clickGems = 0,
		description = "A modest hand trowel that speeds up surface crystal digging.",
		color = Color3.fromRGB(150, 110, 80),
		icon = "⛏️",
	},
	{
		id = "shovel_iron",
		name = "Reinforced Iron Shovel",
		category = "Shovel",
		cost = 1500,
		clickCash = 35,
		clickGems = 1,
		description = "Forged iron blade capable of unearthing buried gemstones.",
		color = Color3.fromRGB(180, 190, 205),
		icon = "⛏️",
	},
	{
		id = "shovel_gold",
		name = "Gilded Royal Spade",
		category = "Shovel",
		cost = 15000,
		clickCash = 160,
		clickGems = 2,
		description = "Emblazoned in pure gold. Grants substantial mining riches.",
		color = Color3.fromRGB(255, 215, 0),
		icon = "✨",
	},
	{
		id = "shovel_diamond",
		name = "Diamond Crusher",
		category = "Shovel",
		cost = 150000,
		clickCash = 800,
		clickGems = 4,
		description = "Razor-edged diamond point that shatters the toughest bedrock.",
		color = Color3.fromRGB(0, 230, 255),
		icon = "💎",
	},
	{
		id = "shovel_void",
		name = "Cosmic Void Cleaver",
		category = "Shovel",
		cost = 1000000,
		clickCash = 4000,
		clickGems = 10,
		description = "Infused with dark matter. Harvests astronomical wealth.",
		color = Color3.fromRGB(200, 50, 255),
		icon = "🌌",
	},
} :: { ShovelDef }

ShopConfig.BACKPACKS = {
	{
		id = "pack_canvas",
		name = "Worn Canvas Satchel",
		category = "Backpack",
		cost = 250,
		multiplier = 1.15, -- +15%
		bonusGems = 0,
		description = "A light shoulder bag that boosts your overall collector yield.",
		color = Color3.fromRGB(160, 130, 95),
		icon = "🎒",
	},
	{
		id = "pack_miner",
		name = "Miner's Rucksack",
		category = "Backpack",
		cost = 3500,
		multiplier = 1.35, -- +35%
		bonusGems = 0,
		description = "Reinforced leather straps hold extra ore chunks efficiently.",
		color = Color3.fromRGB(120, 85, 60),
		icon = "🎒",
	},
	{
		id = "pack_vault",
		name = "Hardened Vault Pack",
		category = "Backpack",
		cost = 35000,
		multiplier = 1.75, -- +75%
		bonusGems = 1,
		description = "A steel-plated chest pack that preserves rare gems.",
		color = Color3.fromRGB(130, 140, 160),
		icon = "💼",
	},
	{
		id = "pack_abyssal",
		name = "Abyssal Relic Sack",
		category = "Backpack",
		cost = 350000,
		multiplier = 2.50, -- +150%
		bonusGems = 2,
		description = "Enchanted with dungeon runes to multiply mining output dramatically.",
		color = Color3.fromRGB(140, 40, 220),
		icon = "🔮",
	},
	{
		id = "pack_infinite",
		name = "Infinite Dimensional Pack",
		category = "Backpack",
		cost = 2500000,
		multiplier = 4.00, -- +300%
		bonusGems = 5,
		description = "A pocket dimension that bends space to store infinite riches.",
		color = Color3.fromRGB(255, 100, 220),
		icon = "⭐",
	},
} :: { BackpackDef }

function ShopConfig.getShovel(id: string): ShovelDef?
	for _, sh in ipairs(ShopConfig.SHOVELS) do
		if sh.id == id then
			return sh
		end
	end
	return nil
end

function ShopConfig.getBackpack(id: string): BackpackDef?
	for _, bp in ipairs(ShopConfig.BACKPACKS) do
		if bp.id == id then
			return bp
		end
	end
	return nil
end

return ShopConfig
