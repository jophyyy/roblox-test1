--!strict
export type TrailDef = {
	id: string,
	name: string,
	cost: number,
	currency: "Gems",
	colorSequence: ColorSequence,
	speedBonus: number,
	cashMultiplier: number,
	bonusGems: number,
	bossMultiplier: number,
	description: string,
	icon: string,
	lifetime: number,
	widthScale: NumberSequence,
}

local TrailConfig = {}

TrailConfig.TRAILS = {
	trail_spark = {
		id = "trail_spark",
		name = "Sparkler Ribbon",
		cost = 500,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 225, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 0)),
		}),
		speedBonus = 3,
		cashMultiplier = 1.15,
		bonusGems = 0,
		bossMultiplier = 1.0,
		description = "Crackling golden embers follow your steps with light speed and +15% Cash.",
		icon = "✨",
		lifetime = 0.55,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
	},
	trail_rainbow = {
		id = "trail_rainbow",
		name = "Prismatic Rainbow",
		cost = 2500,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 240, 80)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 210, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 60, 255)),
		}),
		speedBonus = 6,
		cashMultiplier = 1.35,
		bonusGems = 1,
		bossMultiplier = 1.0,
		description = "A radiant ribbon of spectral colors with +6 Speed, +35% Cash, and +1 bonus Gem.",
		icon = "🌈",
		lifetime = 0.65,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
	},
	trail_lightning = {
		id = "trail_lightning",
		name = "Thunderflash Surge",
		cost = 8000,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 90, 255)),
		}),
		speedBonus = 10,
		cashMultiplier = 1.75,
		bonusGems = 2,
		bossMultiplier = 1.10,
		description = "High-voltage electric arcs with +10 Speed, +75% Cash, and +2 bonus Gems.",
		icon = "⚡",
		lifetime = 0.70,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
	},
	trail_void = {
		id = "trail_void",
		name = "Abyssal Shadowrift",
		cost = 25000,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 30, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 10, 45)),
		}),
		speedBonus = 14,
		cashMultiplier = 2.50,
		bonusGems = 4,
		bossMultiplier = 1.25,
		description = "Cosmic rift tear with +14 Speed, +150% Cash, +4 Gems, and +25% Boss Dmg.",
		icon = "🌌",
		lifetime = 0.75,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.7),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
	},
	trail_magma = {
		id = "trail_magma",
		name = "Molten Magma Stream",
		cost = 75000,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 75, 10)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 20)),
		}),
		speedBonus = 18,
		cashMultiplier = 4.00,
		bonusGems = 8,
		bossMultiplier = 1.50,
		description = "Blistering river of molten rock with +18 Speed, +300% Cash, +8 Gems, and +50% Boss Dmg.",
		icon = "🌋",
		lifetime = 0.80,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.9),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
	},
	trail_celestial = {
		id = "trail_celestial",
		name = "Celestial Starlight",
		cost = 250000,
		currency = "Gems",
		colorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(120, 245, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
		}),
		speedBonus = 24,
		cashMultiplier = 8.00,
		bonusGems = 15,
		bossMultiplier = 2.00,
		description = "Supreme starlight aurora granting legendary +24 Speed, +700% Cash, +15 Gems, and +100% Boss Dmg.",
		icon = "👑",
		lifetime = 0.90,
		widthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2.2),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
	},
} :: { [string]: TrailDef }

TrailConfig.TRAIL_ORDER = {
	"trail_spark",
	"trail_rainbow",
	"trail_lightning",
	"trail_void",
	"trail_magma",
	"trail_celestial",
}

function TrailConfig.getTrail(id: string?): TrailDef?
	if id and TrailConfig.TRAILS[id] then
		return TrailConfig.TRAILS[id]
	end
	return nil
end

function TrailConfig.getSpeedBonus(id: string?): number
	local def = TrailConfig.getTrail(id)
	return if def then def.speedBonus else 0
end

function TrailConfig.getCashMultiplier(id: string?): number
	local def = TrailConfig.getTrail(id)
	return if def then def.cashMultiplier else 1.0
end

function TrailConfig.getBonusGems(id: string?): number
	local def = TrailConfig.getTrail(id)
	return if def then def.bonusGems else 0
end

function TrailConfig.getBossMultiplier(id: string?): number
	local def = TrailConfig.getTrail(id)
	return if def then def.bossMultiplier else 1.0
end

return TrailConfig
