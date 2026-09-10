--!strict
local ShopConfig = require(script.Parent.Parent.Config.ShopConfig)

local PickaxeModelBuilder = {}

type PartConfig = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	isWedge: boolean?,
	shape: Enum.PartType?,
}

-- Helper to instantiate a non-colliding, massless welded part on the pickaxe
local function addPart(parentModel: Model, handle: BasePart, cfg: PartConfig): BasePart
	local part: BasePart
	if cfg.isWedge then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if cfg.shape then
			block.Shape = cfg.shape
		end
		part = block
	end

	part.Name = cfg.name
	part.Size = cfg.size
	part.Color = cfg.color
	part.Material = cfg.material or Enum.Material.SmoothPlastic
	part.Transparency = cfg.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = handle.CFrame * cfg.offset
	part.Parent = parentModel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = handle

	return part
end

-- =========================================================================
-- 1. RUSTY MINER'S PICKAXE (shovel_rusty)
-- =========================================================================
local function buildRusty(model: Model, handle: BasePart)
	local H = 3.4
	-- Handle base styling: weathered wood
	handle.Size = Vector3.new(0.36, H, 0.36)
	handle.Color = Color3.fromRGB(112, 75, 45)
	handle.Material = Enum.Material.Wood

	-- 3 Leather grip wraps around lower shaft
	local leatherColor = Color3.fromRGB(72, 48, 28)
	for i = 1, 3 do
		addPart(model, handle, {
			name = "LeatherWrap" .. i,
			size = Vector3.new(0.40, 0.22, 0.40),
			offset = CFrame.new(0, -0.4 - (i * 0.28), 0),
			color = leatherColor,
			material = Enum.Material.Fabric,
		})
	end

	-- Iron Pommel Fitting + Ring
	local ironColor = Color3.fromRGB(130, 95, 75)
	addPart(model, handle, {
		name = "PommelCap",
		size = Vector3.new(0.44, 0.20, 0.44),
		offset = CFrame.new(0, -H * 0.5 - 0.08, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})
	addPart(model, handle, {
		name = "PommelRing",
		size = Vector3.new(0.40, 0.40, 0.20),
		offset = CFrame.new(0, -H * 0.5 - 0.28, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
		shape = Enum.PartType.Ball,
	})

	-- Upper Iron Bolster Collar
	local collarY = H * 0.5 - 0.25
	addPart(model, handle, {
		name = "Collar",
		size = Vector3.new(0.48, 0.50, 0.48),
		offset = CFrame.new(0, collarY, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})

	-- Head Central Hub
	local headY = H * 0.5 + 0.05
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.44, 0.55, 0.60),
		offset = CFrame.new(0, headY, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})

	-- Side reinforcement brackets
	addPart(model, handle, {
		name = "SidePlateL",
		size = Vector3.new(0.08, 0.45, 0.50),
		offset = CFrame.new(0.24, headY, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})
	addPart(model, handle, {
		name = "SidePlateR",
		size = Vector3.new(0.08, 0.45, 0.50),
		offset = CFrame.new(-0.24, headY, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})

	-- Forward Pick Blade (Along -Z)
	-- Neck extending forward
	addPart(model, handle, {
		name = "BladeNeck",
		size = Vector3.new(0.36, 0.48, 0.70),
		offset = CFrame.new(0, headY - 0.04, -0.60),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})
	-- Menacing curved beak tilting downward
	addPart(model, handle, {
		name = "BladeBeak",
		size = Vector3.new(0.32, 0.38, 0.65),
		offset = CFrame.new(0, headY - 0.18, -1.20) * CFrame.Angles(math.rad(-18), 0, 0),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})
	-- Chisel Tip (Sharp wedge penetrator)
	local tip = addPart(model, handle, {
		name = "ChiselTip",
		size = Vector3.new(0.28, 0.32, 0.55),
		offset = CFrame.new(0, headY - 0.42, -1.72) * CFrame.Angles(math.rad(-35), 0, 0),
		color = Color3.fromRGB(150, 115, 90),
		material = Enum.Material.Metal,
		isWedge = true,
	})

	-- Rear Crushing Hammer Block (Along +Z)
	addPart(model, handle, {
		name = "RearHammer",
		size = Vector3.new(0.46, 0.58, 0.60),
		offset = CFrame.new(0, headY - 0.02, 0.55),
		color = ironColor,
		material = Enum.Material.CorrodedMetal,
	})

	-- Grinding rust/dust emitter at tip
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RustDust"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(160, 110, 75))
	emitter.Rate = 5
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(240, 180, 130)
	light.Brightness = 1.2
	light.Range = 6
	light.Parent = tip
end

-- =========================================================================
-- 2. REINFORCED IRON PICKAXE (shovel_iron)
-- =========================================================================
local function buildIron(model: Model, handle: BasePart)
	local H = 3.6
	handle.Size = Vector3.new(0.38, H, 0.38)
	handle.Color = Color3.fromRGB(165, 150, 135)
	handle.Material = Enum.Material.Wood

	local steelColor = Color3.fromRGB(180, 190, 205)
	local darkSteel = Color3.fromRGB(120, 130, 145)

	-- Steel wire grip spiral
	for i = 1, 4 do
		addPart(model, handle, {
			name = "SteelGripRing" .. i,
			size = Vector3.new(0.42, 0.16, 0.42),
			offset = CFrame.new(0, -0.35 - (i * 0.26), 0),
			color = steelColor,
			material = Enum.Material.Metal,
		})
	end

	-- Conical steel spike pommel
	addPart(model, handle, {
		name = "PommelBase",
		size = Vector3.new(0.46, 0.18, 0.46),
		offset = CFrame.new(0, -H * 0.5 - 0.08, 0),
		color = darkSteel,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "PommelSpike",
		size = Vector3.new(0.32, 0.40, 0.32),
		offset = CFrame.new(0, -H * 0.5 - 0.32, 0) * CFrame.Angles(math.rad(180), 0, 0),
		color = steelColor,
		material = Enum.Material.Metal,
		isWedge = true,
	})

	-- Heavy Riveted Bolster Collar
	local collarY = H * 0.5 - 0.25
	addPart(model, handle, {
		name = "Collar",
		size = Vector3.new(0.52, 0.52, 0.52),
		offset = CFrame.new(0, collarY, 0),
		color = darkSteel,
		material = Enum.Material.Metal,
	})

	-- Corner bolt rivets
	for _, sx in ipairs({ -0.22, 0.22 }) do
		for _, sz in ipairs({ -0.22, 0.22 }) do
			addPart(model, handle, {
				name = "BoltRivet",
				size = Vector3.new(0.12, 0.12, 0.12),
				offset = CFrame.new(sx, collarY, sz),
				color = steelColor,
				material = Enum.Material.DiamondPlate,
			})
		end
	end

	-- Pick Head Central Hub
	local headY = H * 0.5 + 0.08
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.48, 0.60, 0.65),
		offset = CFrame.new(0, headY, 0),
		color = darkSteel,
		material = Enum.Material.Metal,
	})

	-- Forward Pick Blade (Dual-flanged, tapered)
	addPart(model, handle, {
		name = "BladeBase",
		size = Vector3.new(0.40, 0.52, 0.80),
		offset = CFrame.new(0, headY - 0.05, -0.68),
		color = steelColor,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "BladeSpine",
		size = Vector3.new(0.34, 0.40, 0.75),
		offset = CFrame.new(0, headY - 0.20, -1.35) * CFrame.Angles(math.rad(-20), 0, 0),
		color = steelColor,
		material = Enum.Material.Metal,
	})
	local tip = addPart(model, handle, {
		name = "SteelPenetratorTip",
		size = Vector3.new(0.30, 0.32, 0.65),
		offset = CFrame.new(0, headY - 0.48, -1.95) * CFrame.Angles(math.rad(-38), 0, 0),
		color = Color3.fromRGB(225, 235, 248),
		material = Enum.Material.Metal,
		isWedge = true,
	})

	-- Rear Rock-Cleaver Wedge
	addPart(model, handle, {
		name = "RearCleaver",
		size = Vector3.new(0.44, 0.54, 0.70),
		offset = CFrame.new(0, headY - 0.04, 0.62),
		color = steelColor,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "RearWedge",
		size = Vector3.new(0.38, 0.44, 0.45),
		offset = CFrame.new(0, headY - 0.06, 1.12),
		color = darkSteel,
		material = Enum.Material.Metal,
		isWedge = true,
	})

	-- Crisp metallic sparks
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SteelSparks"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
	emitter.Rate = 9
	emitter.Speed = NumberRange.new(0.8, 1.8)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.LightEmission = 0.8
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 220, 255)
	light.Brightness = 2.0
	light.Range = 8
	light.Parent = tip
end

-- =========================================================================
-- 3. GILDED ROYAL PICKAXE (shovel_gold)
-- =========================================================================
local function buildGold(model: Model, handle: BasePart)
	local H = 3.8
	-- Polished midnight obsidian ebony shaft
	handle.Size = Vector3.new(0.40, H, 0.40)
	handle.Color = Color3.fromRGB(25, 26, 35)
	handle.Material = Enum.Material.SmoothPlastic

	local goldColor = Color3.fromRGB(255, 215, 0)
	local richGold = Color3.fromRGB(230, 185, 0)
	local rubyColor = Color3.fromRGB(255, 40, 70)

	-- 4 Ornate 24K Gold Filigree Bands
	for i = 1, 4 do
		addPart(model, handle, {
			name = "GoldRing" .. i,
			size = Vector3.new(0.46, 0.15, 0.46),
			offset = CFrame.new(0, -0.30 - (i * 0.28), 0),
			color = goldColor,
			material = Enum.Material.Metal,
		})
	end

	-- Ornate Royal Crown Pommel Casing + Glowing Ruby
	addPart(model, handle, {
		name = "CrownPommelRing",
		size = Vector3.new(0.52, 0.22, 0.52),
		offset = CFrame.new(0, -H * 0.5 - 0.10, 0),
		color = goldColor,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "CrownRuby",
		size = Vector3.new(0.38, 0.38, 0.38),
		offset = CFrame.new(0, -H * 0.5 - 0.32, 0),
		color = rubyColor,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})

	-- Winged Golden Crossguard Collar
	local collarY = H * 0.5 - 0.25
	addPart(model, handle, {
		name = "WingedCollar",
		size = Vector3.new(0.65, 0.55, 0.55),
		offset = CFrame.new(0, collarY, 0),
		color = richGold,
		material = Enum.Material.Metal,
	})

	-- Pick Head Central Hub
	local headY = H * 0.5 + 0.10
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.52, 0.65, 0.70),
		offset = CFrame.new(0, headY, 0),
		color = richGold,
		material = Enum.Material.Metal,
	})

	-- Glowing Royal Topaz Central Gem
	addPart(model, handle, {
		name = "TopazGem",
		size = Vector3.new(0.56, 0.38, 0.38),
		offset = CFrame.new(0, headY, 0),
		color = Color3.fromRGB(255, 235, 60),
		material = Enum.Material.Neon,
	})

	-- Forward Sweeping Golden Eagle-Beak Blade (Along -Z)
	addPart(model, handle, {
		name = "GoldBladeBase",
		size = Vector3.new(0.42, 0.56, 0.85),
		offset = CFrame.new(0, headY - 0.04, -0.72),
		color = goldColor,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "GoldBladeSpine",
		size = Vector3.new(0.36, 0.44, 0.80),
		offset = CFrame.new(0, headY - 0.22, -1.45) * CFrame.Angles(math.rad(-22), 0, 0),
		color = goldColor,
		material = Enum.Material.Metal,
	})
	-- Top Crown Fin
	addPart(model, handle, {
		name = "TopCrownFin",
		size = Vector3.new(0.18, 0.32, 0.75),
		offset = CFrame.new(0, headY + 0.36, -0.75) * CFrame.Angles(math.rad(10), 0, 0),
		color = goldColor,
		material = Enum.Material.Metal,
	})
	-- Razor Golden Fang Tip
	local tip = addPart(model, handle, {
		name = "GoldBeakTip",
		size = Vector3.new(0.32, 0.36, 0.70),
		offset = CFrame.new(0, headY - 0.52, -2.10) * CFrame.Angles(math.rad(-42), 0, 0),
		color = Color3.fromRGB(255, 240, 100),
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Rear Royal Spiked War-Hammer Crusher (Along +Z)
	addPart(model, handle, {
		name = "RearCrusherBase",
		size = Vector3.new(0.48, 0.60, 0.75),
		offset = CFrame.new(0, headY - 0.04, 0.68),
		color = goldColor,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "RearCrusherSpike",
		size = Vector3.new(0.36, 0.42, 0.50),
		offset = CFrame.new(0, headY - 0.06, 1.25),
		color = richGold,
		material = Enum.Material.Metal,
		isWedge = true,
	})

	-- Radiant starlight & golden sparkle motes
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "GoldSparkles"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.30),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 20)),
	})
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(0.6, 1.5)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.LightEmission = 1.0
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 50)
	light.Brightness = 3.0
	light.Range = 12
	light.Parent = tip
end

-- =========================================================================
-- 4. DIAMOND CRUSHER PICKAXE (shovel_diamond)
-- =========================================================================
local function buildDiamond(model: Model, handle: BasePart)
	local H = 4.0
	-- Brushed chrome/titanium shaft
	handle.Size = Vector3.new(0.42, H, 0.42)
	handle.Color = Color3.fromRGB(215, 230, 248)
	handle.Material = Enum.Material.Metal

	local cyanNeon = Color3.fromRGB(0, 240, 255)
	local crystalGlass = Color3.fromRGB(180, 245, 255)
	local darkChrome = Color3.fromRGB(130, 150, 175)

	-- Glowing Cyan Energy Conduit Sleeve embedded in the shaft
	addPart(model, handle, {
		name = "EnergySleeve",
		size = Vector3.new(0.44, 1.6, 0.44),
		offset = CFrame.new(0, -0.65, 0),
		color = cyanNeon,
		material = Enum.Material.Neon,
	})

	-- Diamond Crystal Prism Pommel
	addPart(model, handle, {
		name = "PommelPrism",
		size = Vector3.new(0.50, 0.50, 0.50),
		offset = CFrame.new(0, -H * 0.5 - 0.22, 0),
		color = crystalGlass,
		material = Enum.Material.Glass,
	})
	addPart(model, handle, {
		name = "PommelCore",
		size = Vector3.new(0.30, 0.30, 0.30),
		offset = CFrame.new(0, -H * 0.5 - 0.22, 0),
		color = cyanNeon,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})

	-- Crystalline Prism Collar
	local collarY = H * 0.5 - 0.25
	addPart(model, handle, {
		name = "Collar",
		size = Vector3.new(0.60, 0.58, 0.60),
		offset = CFrame.new(0, collarY, 0),
		color = darkChrome,
		material = Enum.Material.Metal,
	})

	-- Head Central Hub
	local headY = H * 0.5 + 0.12
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.54, 0.70, 0.75),
		offset = CFrame.new(0, headY, 0),
		color = darkChrome,
		material = Enum.Material.Metal,
	})

	-- Pulsating Diamond Resonator Gem
	addPart(model, handle, {
		name = "ResonatorCore",
		size = Vector3.new(0.60, 0.44, 0.44),
		offset = CFrame.new(0, headY, 0),
		color = cyanNeon,
		material = Enum.Material.Neon,
	})

	-- Dual-Layered Diamond Pick Blade (Along -Z)
	-- Inner energy core
	addPart(model, handle, {
		name = "BladeCoreBase",
		size = Vector3.new(0.32, 0.48, 0.90),
		offset = CFrame.new(0, headY - 0.05, -0.78),
		color = cyanNeon,
		material = Enum.Material.Neon,
	})
	-- Outer diamond crystal scythe sheath
	addPart(model, handle, {
		name = "BladeCrystalSheath",
		size = Vector3.new(0.44, 0.60, 0.95),
		offset = CFrame.new(0, headY - 0.05, -0.78),
		color = crystalGlass,
		material = Enum.Material.Glass,
		transparency = 0.25,
	})

	-- Mid curved diamond blade
	addPart(model, handle, {
		name = "BladeMidSpine",
		size = Vector3.new(0.38, 0.46, 0.85),
		offset = CFrame.new(0, headY - 0.24, -1.55) * CFrame.Angles(math.rad(-22), 0, 0),
		color = cyanNeon,
		material = Enum.Material.Neon,
	})
	-- Top diamond crystal crest
	addPart(model, handle, {
		name = "TopCrystalCrest",
		size = Vector3.new(0.20, 0.42, 0.80),
		offset = CFrame.new(0, headY + 0.42, -0.80) * CFrame.Angles(math.rad(12), 0, 0),
		color = crystalGlass,
		material = Enum.Material.Glass,
		transparency = 0.2,
	})

	-- Needle-Sharp Diamond Chisel Apex
	local tip = addPart(model, handle, {
		name = "DiamondApexTip",
		size = Vector3.new(0.32, 0.38, 0.75),
		offset = CFrame.new(0, headY - 0.56, -2.25) * CFrame.Angles(math.rad(-42), 0, 0),
		color = cyanNeon,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Rear Diamond Crystalline Counter-Spike (Along +Z)
	addPart(model, handle, {
		name = "RearSpikeBase",
		size = Vector3.new(0.46, 0.62, 0.75),
		offset = CFrame.new(0, headY - 0.04, 0.72),
		color = darkChrome,
		material = Enum.Material.Metal,
	})
	addPart(model, handle, {
		name = "RearDiamondSpike",
		size = Vector3.new(0.36, 0.46, 0.65),
		offset = CFrame.new(0, headY - 0.06, 1.35),
		color = cyanNeon,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Shimmering cyan diamond sparkle motes
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DiamondSparkles"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255)),
	})
	emitter.Rate = 16
	emitter.Speed = NumberRange.new(0.7, 1.6)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.LightEmission = 1.0
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = cyanNeon
	light.Brightness = 3.6
	light.Range = 14
	light.Parent = tip
end

-- =========================================================================
-- 5. COSMIC VOID CLEAVER PICKAXE (shovel_void)
-- =========================================================================
local function buildVoid(model: Model, handle: BasePart)
	local H = 4.2
	-- Void-forged cosmic obsidian shaft
	handle.Size = Vector3.new(0.44, H, 0.44)
	handle.Color = Color3.fromRGB(20, 12, 32)
	handle.Material = Enum.Material.SmoothPlastic

	local plasmaColor = Color3.fromRGB(200, 50, 255)
	local brightPlasma = Color3.fromRGB(235, 90, 255)
	local darkObsidian = Color3.fromRGB(28, 16, 44)

	-- Pulsing Violet Cosmic Plasma Conduits
	for i = 1, 4 do
		addPart(model, handle, {
			name = "VoidConduit" .. i,
			size = Vector3.new(0.48, 0.16, 0.48),
			offset = CFrame.new(0, -0.30 - (i * 0.30), 0),
			color = plasmaColor,
			material = Enum.Material.Neon,
		})
	end

	-- Gravitational Singularity Core: Floating Void Sphere + Outer Ring
	addPart(model, handle, {
		name = "SingularitySphere",
		size = Vector3.new(0.52, 0.52, 0.52),
		offset = CFrame.new(0, -H * 0.5 - 0.28, 0),
		color = brightPlasma,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})
	addPart(model, handle, {
		name = "SingularityRing",
		size = Vector3.new(0.70, 0.12, 0.70),
		offset = CFrame.new(0, -H * 0.5 - 0.28, 0) * CFrame.Angles(math.rad(25), 0, math.rad(20)),
		color = plasmaColor,
		material = Enum.Material.Neon,
	})

	-- Void-Rift Manifold Collar
	local collarY = H * 0.5 - 0.26
	addPart(model, handle, {
		name = "Collar",
		size = Vector3.new(0.66, 0.60, 0.66),
		offset = CFrame.new(0, collarY, 0),
		color = darkObsidian,
		material = Enum.Material.SmoothPlastic,
	})

	-- Head Central Hub
	local headY = H * 0.5 + 0.14
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.58, 0.74, 0.80),
		offset = CFrame.new(0, headY, 0),
		color = darkObsidian,
		material = Enum.Material.SmoothPlastic,
	})

	-- Black Hole Singularity Eye Core
	addPart(model, handle, {
		name = "VoidEyeCore",
		size = Vector3.new(0.64, 0.48, 0.48),
		offset = CFrame.new(0, headY, 0),
		color = brightPlasma,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})

	-- Colossal Curved Void Plasma Scythe-Pick (Along -Z)
	addPart(model, handle, {
		name = "VoidBladeBase",
		size = Vector3.new(0.46, 0.62, 0.95),
		offset = CFrame.new(0, headY - 0.05, -0.84),
		color = darkObsidian,
		material = Enum.Material.SmoothPlastic,
	})
	addPart(model, handle, {
		name = "VoidPlasmaEdge",
		size = Vector3.new(0.38, 0.50, 0.90),
		offset = CFrame.new(0, headY - 0.26, -1.65) * CFrame.Angles(math.rad(-24), 0, 0),
		color = plasmaColor,
		material = Enum.Material.Neon,
	})
	-- Top Void Spikes
	for j = 1, 2 do
		addPart(model, handle, {
			name = "TopVoidSpike" .. j,
			size = Vector3.new(0.18, 0.38, 0.38),
			offset = CFrame.new(0, headY + 0.44 + (j * 0.05), -0.60 - (j * 0.35)) * CFrame.Angles(math.rad(15), 0, 0),
			color = brightPlasma,
			material = Enum.Material.Neon,
		})
	end
	-- Abyss Piercing Horn Tip
	local tip = addPart(model, handle, {
		name = "AbyssHornTip",
		size = Vector3.new(0.34, 0.40, 0.80),
		offset = CFrame.new(0, headY - 0.60, -2.42) * CFrame.Angles(math.rad(-44), 0, 0),
		color = brightPlasma,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Rear Dark-Matter War Spike (Along +Z)
	addPart(model, handle, {
		name = "RearVoidBase",
		size = Vector3.new(0.50, 0.66, 0.80),
		offset = CFrame.new(0, headY - 0.05, 0.78),
		color = darkObsidian,
		material = Enum.Material.SmoothPlastic,
	})
	addPart(model, handle, {
		name = "RearVoidHorn",
		size = Vector3.new(0.38, 0.48, 0.72),
		offset = CFrame.new(0, headY - 0.08, 1.48),
		color = plasmaColor,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Cosmic void smoke & galaxy particles
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VoidParticles"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 120, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 20, 220)),
	})
	emitter.Rate = 18
	emitter.Speed = NumberRange.new(0.8, 1.8)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.LightEmission = 0.95
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = plasmaColor
	light.Brightness = 4.0
	light.Range = 16
	light.Parent = tip
end

-- =========================================================================
-- 6. MOLTEN MAGMA PICKAXE (shovel_magma)
-- =========================================================================
local function buildMagma(model: Model, handle: BasePart)
	local H = 4.4
	-- Charred volcanic basalt rock shaft
	handle.Size = Vector3.new(0.46, H, 0.46)
	handle.Color = Color3.fromRGB(40, 36, 36)
	handle.Material = Enum.Material.Slate

	local lavaOrange = Color3.fromRGB(255, 90, 15)
	local brightLava = Color3.fromRGB(255, 170, 30)
	local whiteHot = Color3.fromRGB(255, 230, 110)
	local volcanicRock = Color3.fromRGB(32, 28, 28)

	-- Glowing Molten Copper / Lava Wire Wraps
	for i = 1, 5 do
		addPart(model, handle, {
			name = "LavaWrap" .. i,
			size = Vector3.new(0.50, 0.16, 0.50),
			offset = CFrame.new(0, -0.30 - (i * 0.28), 0),
			color = lavaOrange,
			material = Enum.Material.Neon,
		})
	end

	-- Boiling Magma Geode Orb Pommel
	addPart(model, handle, {
		name = "MagmaOrbPommel",
		size = Vector3.new(0.56, 0.56, 0.56),
		offset = CFrame.new(0, -H * 0.5 - 0.28, 0),
		color = brightLava,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})
	-- Volcanic claw prongs retaining the magma orb
	for _, a in ipairs({ 0, 90, 180, 270 }) do
		addPart(model, handle, {
			name = "PommelProng",
			size = Vector3.new(0.12, 0.32, 0.12),
			offset = CFrame.new(0, -H * 0.5 - 0.24, 0) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0.24, 0, 0),
			color = volcanicRock,
			material = Enum.Material.Slate,
		})
	end

	-- Subterranean Blast Furnace Collar + Glowing Lava Vents
	local collarY = H * 0.5 - 0.28
	addPart(model, handle, {
		name = "Collar",
		size = Vector3.new(0.72, 0.65, 0.72),
		offset = CFrame.new(0, collarY, 0),
		color = volcanicRock,
		material = Enum.Material.Slate,
	})
	addPart(model, handle, {
		name = "CollarLavaVent",
		size = Vector3.new(0.76, 0.22, 0.76),
		offset = CFrame.new(0, collarY, 0),
		color = lavaOrange,
		material = Enum.Material.Neon,
	})

	-- Head Central Hub
	local headY = H * 0.5 + 0.15
	addPart(model, handle, {
		name = "HeadHub",
		size = Vector3.new(0.62, 0.80, 0.85),
		offset = CFrame.new(0, headY, 0),
		color = volcanicRock,
		material = Enum.Material.Slate,
	})

	-- Roaring Volcanic Magma Heart Chamber
	addPart(model, handle, {
		name = "MagmaHeart",
		size = Vector3.new(0.68, 0.54, 0.54),
		offset = CFrame.new(0, headY, 0),
		color = brightLava,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})

	-- Jagged Volcanic Rock Spine + Searing Magma Blade (Along -Z)
	addPart(model, handle, {
		name = "VolcanicBladeBase",
		size = Vector3.new(0.50, 0.70, 1.05),
		offset = CFrame.new(0, headY - 0.06, -0.92),
		color = volcanicRock,
		material = Enum.Material.Slate,
	})
	-- Blazing lava cutting edge
	addPart(model, handle, {
		name = "LavaCuttingEdge",
		size = Vector3.new(0.42, 0.54, 1.00),
		offset = CFrame.new(0, headY - 0.28, -1.80) * CFrame.Angles(math.rad(-25), 0, 0),
		color = lavaOrange,
		material = Enum.Material.Neon,
	})
	-- 3 Erupting Volcanic Ridge Spikes along top spine
	for k = 1, 3 do
		addPart(model, handle, {
			name = "RidgeSpike" .. k,
			size = Vector3.new(0.20, 0.44, 0.35),
			offset = CFrame.new(0, headY + 0.48 + (k * 0.04), -0.55 - (k * 0.35)) * CFrame.Angles(math.rad(18), 0, 0),
			color = brightLava,
			material = Enum.Material.Neon,
		})
	end
	-- Searing White-Hot Chisel Penetrator Tip
	local tip = addPart(model, handle, {
		name = "WhiteHotPenetratorTip",
		size = Vector3.new(0.36, 0.44, 0.85),
		offset = CFrame.new(0, headY - 0.65, -2.60) * CFrame.Angles(math.rad(-45), 0, 0),
		color = whiteHot,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Heavy Jagged Volcanic Rock-Crusher War Hammer (Along +Z)
	addPart(model, handle, {
		name = "RearMagmaHammer",
		size = Vector3.new(0.56, 0.72, 0.85),
		offset = CFrame.new(0, headY - 0.05, 0.85),
		color = volcanicRock,
		material = Enum.Material.Slate,
	})
	addPart(model, handle, {
		name = "RearLavaFissure",
		size = Vector3.new(0.44, 0.52, 0.75),
		offset = CFrame.new(0, headY - 0.08, 1.60),
		color = lavaOrange,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Rising fire embers, burning sparks, and lava smoke plumes
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MagmaEmbers"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 0)),
	})
	emitter.Rate = 22
	emitter.Speed = NumberRange.new(1.0, 2.2)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.LightEmission = 1.0
	emitter.Parent = att

	local light = Instance.new("PointLight")
	light.Color = lavaOrange
	light.Brightness = 4.5
	light.Range = 17
	light.Parent = tip
end

-- =========================================================================
-- 7. INFERNAL DRAGON CLEAVER (shovel_infernal)
-- =========================================================================
local function buildInfernal(model: Model, handle: BasePart)
	local H = 4.6
	-- Ancient ivory dragon-bone shaft
	handle.Size = Vector3.new(0.50, H, 0.50)
	handle.Color = Color3.fromRGB(246, 238, 220)
	handle.Material = Enum.Material.SmoothPlastic

	local dragonGold = Color3.fromRGB(255, 210, 30)
	local solarFire = Color3.fromRGB(255, 150, 20)
	local crimsonRuby = Color3.fromRGB(255, 25, 25)
	local elderBone = Color3.fromRGB(225, 215, 195)

	-- Dragon-Scale Gold Bands + Crimson Silk Bindings
	for i = 1, 5 do
		addPart(model, handle, {
			name = "DragonGoldBand" .. i,
			size = Vector3.new(0.55, 0.14, 0.55),
			offset = CFrame.new(0, -0.30 - (i * 0.32), 0),
			color = dragonGold,
			material = Enum.Material.Metal,
		})
		addPart(model, handle, {
			name = "DragonCrimsonWrap" .. i,
			size = Vector3.new(0.53, 0.10, 0.53),
			offset = CFrame.new(0, -0.42 - (i * 0.32), 0),
			color = Color3.fromRGB(160, 20, 30),
			material = Enum.Material.Fabric,
		})
	end

	-- Golden Dragon Claw Pommel clutching an Eternal Sun Ruby
	addPart(model, handle, {
		name = "SunRubyPommel",
		size = Vector3.new(0.60, 0.60, 0.60),
		offset = CFrame.new(0, -H * 0.5 - 0.30, 0),
		color = crimsonRuby,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})
	-- 4 Golden dragon claws gripping the ruby
	for _, a in ipairs({ 0, 90, 180, 270 }) do
		addPart(model, handle, {
			name = "DragonClaw",
			size = Vector3.new(0.14, 0.38, 0.14),
			offset = CFrame.new(0, -H * 0.5 - 0.26, 0) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0.26, 0, 0),
			color = dragonGold,
			material = Enum.Material.Metal,
		})
	end

	-- Sculpted Dragon Jaws Collar + Crimson Eyes
	local collarY = H * 0.5 - 0.30
	addPart(model, handle, {
		name = "DragonJawsCollar",
		size = Vector3.new(0.78, 0.70, 0.78),
		offset = CFrame.new(0, collarY, 0),
		color = dragonGold,
		material = Enum.Material.Metal,
	})
	-- Glowing Dragon Eyes
	for _, side in ipairs({ -0.38, 0.38 }) do
		addPart(model, handle, {
			name = "DragonEye",
			size = Vector3.new(0.10, 0.18, 0.24),
			offset = CFrame.new(side, collarY + 0.10, -0.25),
			color = crimsonRuby,
			material = Enum.Material.Neon,
		})
	end

	-- Head Central Dragon Skull Hub
	local headY = H * 0.5 + 0.18
	addPart(model, handle, {
		name = "DragonSkullHub",
		size = Vector3.new(0.68, 0.88, 0.95),
		offset = CFrame.new(0, headY, 0),
		color = elderBone,
		material = Enum.Material.SmoothPlastic,
	})

	-- Blazing Dragon Heart Solar Core
	addPart(model, handle, {
		name = "SolarHeartCore",
		size = Vector3.new(0.74, 0.60, 0.60),
		offset = CFrame.new(0, headY, 0),
		color = solarFire,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	})

	-- Colossal Serrated Dragon Crystal Cleaver-Pick (Along -Z)
	addPart(model, handle, {
		name = "DragonBladeBase",
		size = Vector3.new(0.54, 0.76, 1.15),
		offset = CFrame.new(0, headY - 0.06, -1.02),
		color = elderBone,
		material = Enum.Material.SmoothPlastic,
	})
	-- Searing Golden Solar Razor Edge
	addPart(model, handle, {
		name = "SolarRazorBlade",
		size = Vector3.new(0.46, 0.60, 1.10),
		offset = CFrame.new(0, headY - 0.30, -2.00) * CFrame.Angles(math.rad(-26), 0, 0),
		color = dragonGold,
		material = Enum.Material.Neon,
	})
	-- Serrated Dragon Tooth Insets
	for t = 1, 3 do
		addPart(model, handle, {
			name = "DragonTooth" .. t,
			size = Vector3.new(0.24, 0.28, 0.28),
			offset = CFrame.new(0, headY - 0.48, -0.80 - (t * 0.40)),
			color = crimsonRuby,
			material = Enum.Material.Neon,
		})
	end
	-- Golden Dragon Wing-Blade Fins along top
	for w = 1, 3 do
		addPart(model, handle, {
			name = "DragonWingFin" .. w,
			size = Vector3.new(0.22, 0.50, 0.42),
			offset = CFrame.new(0, headY + 0.54 + (w * 0.05), -0.60 - (w * 0.40)) * CFrame.Angles(math.rad(22), 0, 0),
			color = dragonGold,
			material = Enum.Material.Metal,
		})
	end
	-- Sun-Forged Dragon Horn Penetrator Tip
	local tip = addPart(model, handle, {
		name = "DragonHornTip",
		size = Vector3.new(0.40, 0.48, 0.95),
		offset = CFrame.new(0, headY - 0.72, -2.90) * CFrame.Angles(math.rad(-46), 0, 0),
		color = solarFire,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Rear Spiked Dragon Tail War-Crusher Hammer (Along +Z)
	addPart(model, handle, {
		name = "RearDragonTailBase",
		size = Vector3.new(0.60, 0.78, 0.95),
		offset = CFrame.new(0, headY - 0.06, 0.95),
		color = elderBone,
		material = Enum.Material.SmoothPlastic,
	})
	addPart(model, handle, {
		name = "RearDragonTailSpike",
		size = Vector3.new(0.48, 0.58, 0.85),
		offset = CFrame.new(0, headY - 0.10, 1.80),
		color = dragonGold,
		material = Enum.Material.Neon,
		isWedge = true,
	})

	-- Imperial dragon flame aura particle emitter
	local att = Instance.new("Attachment")
	att.Parent = tip

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DragonFlameAura"
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.48),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 20, 20)),
	})
	emitter.Rate = 28
	emitter.Speed = NumberRange.new(1.2, 2.4)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.LightEmission = 1.0
	emitter.Parent = att

	-- Dual High-Intensity PointLights: Golden Sun Light + Crimson Wrath Light
	local sunLight = Instance.new("PointLight")
	sunLight.Name = "SunLight"
	sunLight.Color = dragonGold
	sunLight.Brightness = 4.8
	sunLight.Range = 18
	sunLight.Parent = tip

	local wrathLight = Instance.new("PointLight")
	wrathLight.Name = "WrathLight"
	wrathLight.Color = crimsonRuby
	wrathLight.Brightness = 3.5
	wrathLight.Range = 12
	wrathLight.Parent = handle
end

-- =========================================================================
-- Main Builder Interface
-- =========================================================================
function PickaxeModelBuilder.buildPickaxe(toolDef: ShopConfig.ShovelDef): Model
	local pickaxeModel = Instance.new("Model")
	pickaxeModel.Name = "EquippedPickaxe"

	-- Handle Part (Primary Part)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.Parent = pickaxeModel
	pickaxeModel.PrimaryPart = handle

	local id = toolDef.id
	if id == "shovel_rusty" then
		buildRusty(pickaxeModel, handle)
	elseif id == "shovel_iron" then
		buildIron(pickaxeModel, handle)
	elseif id == "shovel_gold" then
		buildGold(pickaxeModel, handle)
	elseif id == "shovel_diamond" then
		buildDiamond(pickaxeModel, handle)
	elseif id == "shovel_void" then
		buildVoid(pickaxeModel, handle)
	elseif id == "shovel_magma" then
		buildMagma(pickaxeModel, handle)
	elseif id == "shovel_infernal" then
		buildInfernal(pickaxeModel, handle)
	else
		-- Fallback to rusty style if custom ID
		buildRusty(pickaxeModel, handle)
	end

	return pickaxeModel
end

return PickaxeModelBuilder
