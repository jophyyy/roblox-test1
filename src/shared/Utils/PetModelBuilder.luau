--!strict
local RunService = game:GetService("RunService")
local PetConfig = require(script.Parent.Parent.Config.PetConfig)

export type PetDef = PetConfig.PetDef
export type PetTier = PetConfig.PetTier

local PetModelBuilder = {}

type PartConfig = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	isWedge: boolean?,
	shape: Enum.PartType?,
	meshType: Enum.MeshType?,
	meshScale: Vector3?,
}

-- Creates a welded or anchored part attached to rootPart
local function addPart(parentModel: Model, rootPart: BasePart, cfg: PartConfig, isFollower: boolean): BasePart
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
	part.Anchored = not isFollower
	part.CFrame = rootPart.CFrame * cfg.offset
	part.Parent = parentModel

	if cfg.meshType then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = cfg.meshType
		if cfg.meshScale then
			mesh.Scale = cfg.meshScale
		end
		mesh.Parent = part
	end

	if isFollower then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = part
		weld.Parent = rootPart
	end

	return part
end

-- Adds adorable glossy eyes with cute sparkle glints
local function addEyes(
	parentModel: Model,
	rootPart: BasePart,
	isFollower: boolean,
	mult: number,
	eyeColor: Color3?,
	isGolden: boolean,
	isRainbow: boolean
)
	local actualEyeColor = if isGolden then Color3.fromRGB(40, 30, 10)
		elseif isRainbow then Color3.fromRGB(20, 20, 40)
		else (eyeColor or Color3.fromRGB(24, 24, 30))

	local eyePositions = {
		Vector3.new(-0.52 * mult, 0.22 * mult, -1.02 * mult),
		Vector3.new(0.52 * mult, 0.22 * mult, -1.02 * mult),
	}

	for i, offsetPos in ipairs(eyePositions) do
		-- Eye base
		addPart(parentModel, rootPart, {
			name = "Eye_" .. i,
			size = Vector3.new(0.36 * mult, 0.42 * mult, 0.14 * mult),
			offset = CFrame.new(offsetPos),
			color = actualEyeColor,
			material = Enum.Material.SmoothPlastic,
			meshType = Enum.MeshType.Sphere,
		}, isFollower)

		-- Primary Sparkle Glint (Top-right of pupil)
		addPart(parentModel, rootPart, {
			name = "GlintPrimary_" .. i,
			size = Vector3.new(0.14 * mult, 0.16 * mult, 0.08 * mult),
			offset = CFrame.new(offsetPos + Vector3.new(0.08 * mult, 0.10 * mult, -0.06 * mult)),
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.Neon,
			meshType = Enum.MeshType.Sphere,
		}, isFollower)

		-- Secondary Tiny Glint (Bottom-left of pupil)
		addPart(parentModel, rootPart, {
			name = "GlintSecondary_" .. i,
			size = Vector3.new(0.07 * mult, 0.07 * mult, 0.06 * mult),
			offset = CFrame.new(offsetPos + Vector3.new(-0.08 * mult, -0.10 * mult, -0.05 * mult)),
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.Neon,
			meshType = Enum.MeshType.Sphere,
		}, isFollower)
	end
end

-- Adds cute 4 paws underneath the pet
local function addPaws(parentModel: Model, rootPart: BasePart, isFollower: boolean, mult: number, pawColor: Color3)
	local pawOffsets = {
		Vector3.new(-0.65 * mult, -1.05 * mult, -0.65 * mult),
		Vector3.new(0.65 * mult, -1.05 * mult, -0.65 * mult),
		Vector3.new(-0.65 * mult, -1.05 * mult, 0.65 * mult),
		Vector3.new(0.65 * mult, -1.05 * mult, 0.65 * mult),
	}
	for i, pOffset in ipairs(pawOffsets) do
		addPart(parentModel, rootPart, {
			name = "Paw_" .. i,
			size = Vector3.new(0.48 * mult, 0.28 * mult, 0.52 * mult),
			offset = CFrame.new(pOffset),
			color = pawColor,
			material = Enum.Material.SmoothPlastic,
			meshType = Enum.MeshType.Sphere,
		}, isFollower)
	end
end

-- =========================================================================
-- 1. CRYSTAL DOGE (Crystal Pup)
-- =========================================================================
local function buildCrystalDoge(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local earColor = if isGold then Color3.fromRGB(225, 175, 20) elseif isRb then Color3.fromRGB(255, 130, 210) else Color3.fromRGB(205, 155, 50)
	local muzzleColor = if isGold then Color3.fromRGB(255, 235, 130) elseif isRb then Color3.fromRGB(255, 220, 245) else Color3.fromRGB(255, 235, 175)
	local collarColor = if isGold then Color3.fromRGB(180, 20, 30) elseif isRb then Color3.fromRGB(80, 240, 255) else Color3.fromRGB(220, 40, 40)
	local gemColor = if isGold then Color3.fromRGB(255, 245, 140) elseif isRb then Color3.fromRGB(255, 100, 230) else Color3.fromRGB(0, 240, 255)

	-- Floppy Puppy Ears (Left & Right)
	local earConfigs = {
		{ pos = Vector3.new(-1.15 * mult, 0.85 * mult, -0.15 * mult), rotZ = -30 },
		{ pos = Vector3.new(1.15 * mult, 0.85 * mult, -0.15 * mult), rotZ = 30 },
	}
	for i, cfg in ipairs(earConfigs) do
		addPart(model, root, {
			name = "DogeEar_" .. i,
			size = Vector3.new(0.48 * mult, 0.95 * mult, 0.55 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(0, 0, math.rad(cfg.rotZ)),
			color = earColor,
			material = Enum.Material.SmoothPlastic,
			meshType = Enum.MeshType.Sphere,
		}, isFollower)
	end

	-- Dog Snout / Muzzle
	addPart(model, root, {
		name = "Muzzle",
		size = Vector3.new(0.85 * mult, 0.52 * mult, 0.40 * mult),
		offset = CFrame.new(0, -0.16 * mult, -1.15 * mult),
		color = muzzleColor,
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Black Dog Nose
	addPart(model, root, {
		name = "DogeNose",
		size = Vector3.new(0.26 * mult, 0.18 * mult, 0.16 * mult),
		offset = CFrame.new(0, -0.05 * mult, -1.32 * mult),
		color = Color3.fromRGB(35, 25, 25),
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Puppy Collar
	addPart(model, root, {
		name = "Collar",
		size = Vector3.new(2.15 * mult, 0.22 * mult, 2.15 * mult),
		offset = CFrame.new(0, -0.80 * mult, 0),
		color = collarColor,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	-- Sparkling Crystal Gem Pendant on Collar
	addPart(model, root, {
		name = "CollarGem",
		size = Vector3.new(0.36 * mult, 0.36 * mult, 0.36 * mult),
		offset = CFrame.new(0, -0.82 * mult, -1.16 * mult) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		color = gemColor,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Wagging Puppy Tail
	addPart(model, root, {
		name = "Tail",
		size = Vector3.new(0.32 * mult, 0.70 * mult, 0.32 * mult),
		offset = CFrame.new(0, -0.30 * mult, 1.15 * mult) * CFrame.Angles(math.rad(40), 0, 0),
		color = earColor,
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	addPaws(model, root, isFollower, mult, earColor)
end

-- =========================================================================
-- 2. SPARKLE KITTY (Sparkle Kitty)
-- =========================================================================
local function buildSparkleKitty(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local innerEarColor = if isGold then Color3.fromRGB(255, 160, 40) elseif isRb then Color3.fromRGB(255, 100, 200) else Color3.fromRGB(255, 110, 150)
	local earOuterColor = if isGold then Color3.fromRGB(240, 200, 40) elseif isRb then Color3.fromRGB(255, 180, 240) else Color3.fromRGB(255, 175, 195)
	local noseColor = if isGold then Color3.fromRGB(255, 150, 40) elseif isRb then Color3.fromRGB(255, 90, 190) else Color3.fromRGB(255, 100, 140)

	-- Pointed Cat Ears (Left & Right)
	local earConfigs = {
		{ pos = Vector3.new(-0.75 * mult, 1.25 * mult, -0.20 * mult), rotZ = 18 },
		{ pos = Vector3.new(0.75 * mult, 1.25 * mult, -0.20 * mult), rotZ = -18 },
	}
	for i, cfg in ipairs(earConfigs) do
		addPart(model, root, {
			name = "KittyEar_" .. i,
			size = Vector3.new(0.55 * mult, 0.75 * mult, 0.45 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(8), 0, math.rad(cfg.rotZ)),
			color = earOuterColor,
			material = Enum.Material.SmoothPlastic,
			isWedge = true,
		}, isFollower)

		-- Pink Inner Ear Triangle
		addPart(model, root, {
			name = "InnerEar_" .. i,
			size = Vector3.new(0.32 * mult, 0.50 * mult, 0.15 * mult),
			offset = CFrame.new(cfg.pos + Vector3.new(0, -0.05 * mult, -0.16 * mult)) * CFrame.Angles(math.rad(8), 0, math.rad(cfg.rotZ)),
			color = innerEarColor,
			material = Enum.Material.SmoothPlastic,
			isWedge = true,
		}, isFollower)
	end

	-- Kitty Muzzle & Nose
	addPart(model, root, {
		name = "KittyMuzzle",
		size = Vector3.new(0.65 * mult, 0.36 * mult, 0.30 * mult),
		offset = CFrame.new(0, -0.15 * mult, -1.08 * mult),
		color = Color3.fromRGB(255, 245, 250),
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	addPart(model, root, {
		name = "KittyNose",
		size = Vector3.new(0.18 * mult, 0.14 * mult, 0.14 * mult),
		offset = CFrame.new(0, -0.08 * mult, -1.22 * mult),
		color = noseColor,
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Whisker lines (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		for wIdx = 1, 2 do
			addPart(model, root, {
				name = "Whisker_" .. (side < 0 and "L" or "R") .. "_" .. wIdx,
				size = Vector3.new(0.45 * mult, 0.04 * mult, 0.04 * mult),
				offset = CFrame.new(side * 0.65 * mult, (-0.12 + (wIdx * 0.08)) * mult, -1.10 * mult) * CFrame.Angles(0, 0, math.rad(side * (wIdx == 1 and 10 or -8))),
				color = Color3.fromRGB(80, 70, 75),
				material = Enum.Material.SmoothPlastic,
			}, isFollower)
		end
	end

	-- Golden Bell Collar
	addPart(model, root, {
		name = "KittyCollar",
		size = Vector3.new(2.10 * mult, 0.18 * mult, 2.10 * mult),
		offset = CFrame.new(0, -0.80 * mult, 0),
		color = Color3.fromRGB(160, 40, 180),
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	addPart(model, root, {
		name = "KittyBell",
		size = Vector3.new(0.28 * mult, 0.28 * mult, 0.28 * mult),
		offset = CFrame.new(0, -0.82 * mult, -1.12 * mult),
		color = Color3.fromRGB(255, 215, 0),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Ball,
	}, isFollower)

	-- Sleek Curving Cat Tail
	addPart(model, root, {
		name = "TailBase",
		size = Vector3.new(0.26 * mult, 0.70 * mult, 0.26 * mult),
		offset = CFrame.new(0, -0.30 * mult, 1.15 * mult) * CFrame.Angles(math.rad(40), 0, 0),
		color = earOuterColor,
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)
	addPart(model, root, {
		name = "TailTip",
		size = Vector3.new(0.24 * mult, 0.50 * mult, 0.24 * mult),
		offset = CFrame.new(0, 0.22 * mult, 1.40 * mult) * CFrame.Angles(math.rad(-25), 0, 0),
		color = innerEarColor,
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	addPaws(model, root, isFollower, mult, earOuterColor)
end

-- =========================================================================
-- 3. NEON BUNNY (Neon Bunny)
-- =========================================================================
local function buildNeonBunny(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local earColor = if isGold then Color3.fromRGB(255, 220, 60) elseif isRb then Color3.fromRGB(80, 240, 255) else Color3.fromRGB(80, 240, 255)
	local innerColor = if isGold then Color3.fromRGB(255, 170, 40) elseif isRb then Color3.fromRGB(255, 120, 220) else Color3.fromRGB(0, 180, 220)

	-- Tall Upright Bunny Ears
	local earConfigs = {
		{ pos = Vector3.new(-0.52 * mult, 1.65 * mult, -0.10 * mult), rotZ = -8 },
		{ pos = Vector3.new(0.52 * mult, 1.65 * mult, -0.10 * mult), rotZ = 8 },
	}
	for i, cfg in ipairs(earConfigs) do
		addPart(model, root, {
			name = "BunnyEar_" .. i,
			size = Vector3.new(0.44 * mult, 1.45 * mult, 0.38 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(-8), 0, math.rad(cfg.rotZ)),
			color = earColor,
			material = Enum.Material.Neon,
			meshType = Enum.MeshType.Sphere,
			meshScale = Vector3.new(1.0, 1.7, 0.9),
		}, isFollower)

		-- Inner Ear Glow Groove
		addPart(model, root, {
			name = "BunnyInnerEar_" .. i,
			size = Vector3.new(0.24 * mult, 1.10 * mult, 0.18 * mult),
			offset = CFrame.new(cfg.pos + Vector3.new(0, -0.1 * mult, -0.12 * mult)) * CFrame.Angles(math.rad(-8), 0, math.rad(cfg.rotZ)),
			color = innerColor,
			material = Enum.Material.SmoothPlastic,
			meshType = Enum.MeshType.Sphere,
			meshScale = Vector3.new(0.9, 1.6, 0.8),
		}, isFollower)
	end

	-- Fluffy Bunny Cheeks
	addPart(model, root, {
		name = "BunnyCheeks",
		size = Vector3.new(0.70 * mult, 0.34 * mult, 0.32 * mult),
		offset = CFrame.new(0, -0.14 * mult, -1.05 * mult),
		color = Color3.fromRGB(220, 250, 255),
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Bunny Button Nose
	addPart(model, root, {
		name = "BunnyNose",
		size = Vector3.new(0.18 * mult, 0.14 * mult, 0.14 * mult),
		offset = CFrame.new(0, -0.06 * mult, -1.20 * mult),
		color = Color3.fromRGB(255, 120, 160),
		material = Enum.Material.Neon,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Fluffy Cotton-ball Tail
	addPart(model, root, {
		name = "CottonTail",
		size = Vector3.new(0.55 * mult, 0.55 * mult, 0.55 * mult),
		offset = CFrame.new(0, -0.45 * mult, 1.12 * mult),
		color = Color3.fromRGB(235, 250, 255),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
	}, isFollower)

	addPaws(model, root, isFollower, mult, earColor)
end

-- =========================================================================
-- 4. INFERNO DRAGON (Inferno Drake)
-- =========================================================================
local function buildInfernoDragon(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local hornColor = if isGold then Color3.fromRGB(255, 235, 120) elseif isRb then Color3.fromRGB(255, 90, 230) else Color3.fromRGB(255, 90, 0)
	local wingColor = if isGold then Color3.fromRGB(255, 195, 20) elseif isRb then Color3.fromRGB(255, 140, 90) else Color3.fromRGB(180, 25, 0)
	local spineColor = if isGold then Color3.fromRGB(255, 240, 100) elseif isRb then Color3.fromRGB(80, 255, 200) else Color3.fromRGB(255, 140, 0)

	-- Swept-Back Curved Magma Horns (Left & Right)
	local hornConfigs = {
		{ pos = Vector3.new(-0.75 * mult, 1.25 * mult, 0.15 * mult), rotZ = -26 },
		{ pos = Vector3.new(0.75 * mult, 1.25 * mult, 0.15 * mult), rotZ = 26 },
	}
	for i, cfg in ipairs(hornConfigs) do
		addPart(model, root, {
			name = "DragonHornBase_" .. i,
			size = Vector3.new(0.42 * mult, 0.95 * mult, 0.42 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(-28), 0, math.rad(cfg.rotZ)),
			color = hornColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Angled Dragon Bat Wings (Left & Right)
	local wingConfigs = {
		{ pos = Vector3.new(-1.25 * mult, 0.35 * mult, 0.55 * mult), rotY = -28, rotZ = 25 },
		{ pos = Vector3.new(1.25 * mult, 0.35 * mult, 0.55 * mult), rotY = 28, rotZ = -25 },
	}
	for i, cfg in ipairs(wingConfigs) do
		-- Wing Main Bone
		addPart(model, root, {
			name = "WingBone_" .. i,
			size = Vector3.new(0.18 * mult, 0.90 * mult, 0.85 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(15), math.rad(cfg.rotY), math.rad(cfg.rotZ)),
			color = wingColor,
			material = Enum.Material.SmoothPlastic,
			isWedge = true,
		}, isFollower)

		-- Wing Membrane
		addPart(model, root, {
			name = "WingMembrane_" .. i,
			size = Vector3.new(0.08 * mult, 0.75 * mult, 0.70 * mult),
			offset = CFrame.new(cfg.pos + Vector3.new(cfg.rotZ > 0 and -0.35 * mult or 0.35 * mult, -0.15 * mult, 0.15 * mult)) * CFrame.Angles(math.rad(20), math.rad(cfg.rotY), math.rad(cfg.rotZ)),
			color = hornColor,
			material = Enum.Material.Neon,
			transparency = 0.15,
		}, isFollower)
	end

	-- Spiky Dorsal Ridge along spine
	for sIdx = 1, 3 do
		addPart(model, root, {
			name = "SpineSpike_" .. sIdx,
			size = Vector3.new(0.18 * mult, 0.45 * mult, 0.35 * mult),
			offset = CFrame.new(0, 1.05 * mult - (sIdx * 0.12 * mult), -0.45 * mult + (sIdx * 0.65 * mult)) * CFrame.Angles(math.rad(-15), 0, 0),
			color = spineColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Dragon Tail with Flame Barb Tip
	addPart(model, root, {
		name = "DragonTail",
		size = Vector3.new(0.38 * mult, 0.38 * mult, 1.05 * mult),
		offset = CFrame.new(0, -0.35 * mult, 1.35 * mult) * CFrame.Angles(math.rad(18), 0, 0),
		color = wingColor,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	addPart(model, root, {
		name = "TailFlameBarb",
		size = Vector3.new(0.48 * mult, 0.48 * mult, 0.48 * mult),
		offset = CFrame.new(0, -0.22 * mult, 1.95 * mult) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		color = hornColor,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Dragon Snout
	addPart(model, root, {
		name = "DragonSnout",
		size = Vector3.new(0.95 * mult, 0.45 * mult, 0.50 * mult),
		offset = CFrame.new(0, -0.20 * mult, -1.18 * mult),
		color = wingColor,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	addPaws(model, root, isFollower, mult, wingColor)
end

-- =========================================================================
-- 5. VOID PHOENIX (Void Phoenix)
-- =========================================================================
local function buildVoidPhoenix(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local beakColor = if isGold then Color3.fromRGB(255, 235, 120) elseif isRb then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 195, 40)
	local featherColor = if isGold then Color3.fromRGB(255, 215, 0) elseif isRb then Color3.fromRGB(180, 80, 255) else Color3.fromRGB(220, 90, 240)
	local deepFeather = if isGold then Color3.fromRGB(210, 160, 20) elseif isRb then Color3.fromRGB(120, 40, 220) else Color3.fromRGB(130, 40, 180)

	-- Golden Avian Beak
	addPart(model, root, {
		name = "PhoenixBeak",
		size = Vector3.new(0.38 * mult, 0.32 * mult, 0.65 * mult),
		offset = CFrame.new(0, -0.10 * mult, -1.25 * mult) * CFrame.Angles(math.rad(10), 0, 0),
		color = beakColor,
		material = Enum.Material.Metal,
		isWedge = true,
	}, isFollower)

	-- Majestic 3-Feather Head Crest
	local crestConfigs = {
		{ pos = Vector3.new(-0.35 * mult, 1.40 * mult, -0.10 * mult), rotZ = 20, rotX = -20 },
		{ pos = Vector3.new(0, 1.55 * mult, -0.05 * mult), rotZ = 0, rotX = -25 },
		{ pos = Vector3.new(0.35 * mult, 1.40 * mult, -0.10 * mult), rotZ = -20, rotX = -20 },
	}
	for i, cCfg in ipairs(crestConfigs) do
		addPart(model, root, {
			name = "HeadCrest_" .. i,
			size = Vector3.new(0.20 * mult, 0.85 * mult, 0.35 * mult),
			offset = CFrame.new(cCfg.pos) * CFrame.Angles(math.rad(cCfg.rotX), 0, math.rad(cCfg.rotZ)),
			color = featherColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Sweeping Arched Feather Wings (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		for wLayer = 1, 3 do
			addPart(model, root, {
				name = "PhoenixWing_" .. (side < 0 and "L" or "R") .. "_" .. wLayer,
				size = Vector3.new(0.12 * mult, 1.15 * mult, 0.65 * mult),
				offset = CFrame.new(side * (1.15 + (wLayer * 0.25)) * mult, (0.45 - (wLayer * 0.18)) * mult, (0.20 + (wLayer * 0.25)) * mult) * CFrame.Angles(math.rad(15), math.rad(side * 25), math.rad(-side * 28)),
				color = (wLayer == 2 and deepFeather or featherColor),
				material = Enum.Material.Neon,
				isWedge = true,
			}, isFollower)
		end
	end

	-- Triple Flowing Phoenix Tail Plumes trailing behind
	local tailConfigs = {
		{ pos = Vector3.new(-0.35 * mult, -0.30 * mult, 1.45 * mult), rotY = 15, rotX = 25 },
		{ pos = Vector3.new(0, -0.22 * mult, 1.65 * mult), rotY = 0, rotX = 18 },
		{ pos = Vector3.new(0.35 * mult, -0.30 * mult, 1.45 * mult), rotY = -15, rotX = 25 },
	}
	for i, tCfg in ipairs(tailConfigs) do
		addPart(model, root, {
			name = "PhoenixTailPlume_" .. i,
			size = Vector3.new(0.22 * mult, 0.22 * mult, 1.40 * mult),
			offset = CFrame.new(tCfg.pos) * CFrame.Angles(math.rad(tCfg.rotX), math.rad(tCfg.rotY), 0),
			color = featherColor,
			material = Enum.Material.Neon,
			meshType = Enum.MeshType.Sphere,
			meshScale = Vector3.new(1.0, 0.5, 2.0),
		}, isFollower)
	end
end

-- =========================================================================
-- 6. MAGMA HOUND (Magma Hound)
-- =========================================================================
local function buildMagmaHound(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local rockColor = if isGold then Color3.fromRGB(130, 95, 25) elseif isRb then Color3.fromRGB(45, 25, 60) else Color3.fromRGB(45, 25, 25)
	local lavaColor = if isGold then Color3.fromRGB(255, 220, 70) elseif isRb then Color3.fromRGB(255, 100, 220) else Color3.fromRGB(255, 120, 20)

	-- Jagged Basalt Ear Tufts (Left & Right)
	local earConfigs = {
		{ pos = Vector3.new(-0.85 * mult, 1.25 * mult, -0.15 * mult), rotZ = 24 },
		{ pos = Vector3.new(0.85 * mult, 1.25 * mult, -0.15 * mult), rotZ = -24 },
	}
	for i, cfg in ipairs(earConfigs) do
		addPart(model, root, {
			name = "HoundEarRock_" .. i,
			size = Vector3.new(0.48 * mult, 0.85 * mult, 0.45 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(-10), 0, math.rad(cfg.rotZ)),
			color = rockColor,
			material = Enum.Material.Slate,
			isWedge = true,
		}, isFollower)
		addPart(model, root, {
			name = "HoundEarLava_" .. i,
			size = Vector3.new(0.28 * mult, 0.55 * mult, 0.25 * mult),
			offset = CFrame.new(cfg.pos + Vector3.new(0, 0.05 * mult, -0.12 * mult)) * CFrame.Angles(math.rad(-10), 0, math.rad(cfg.rotZ)),
			color = lavaColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Heavy Basalt Snout with Molten Lower Jaw
	addPart(model, root, {
		name = "HoundSnout",
		size = Vector3.new(0.85 * mult, 0.48 * mult, 0.55 * mult),
		offset = CFrame.new(0, -0.15 * mult, -1.18 * mult),
		color = rockColor,
		material = Enum.Material.Slate,
	}, isFollower)

	addPart(model, root, {
		name = "HoundLavaJaw",
		size = Vector3.new(0.72 * mult, 0.22 * mult, 0.45 * mult),
		offset = CFrame.new(0, -0.38 * mult, -1.16 * mult),
		color = lavaColor,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Molten Shoulder Spikes
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ShoulderSpike_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.35 * mult, 0.65 * mult, 0.35 * mult),
			offset = CFrame.new(side * 1.18 * mult, 0.45 * mult, 0.20 * mult) * CFrame.Angles(0, 0, math.rad(-side * 35)),
			color = lavaColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Blazing Jagged Lava Tail
	addPart(model, root, {
		name = "MagmaTail",
		size = Vector3.new(0.32 * mult, 0.85 * mult, 0.32 * mult),
		offset = CFrame.new(0, -0.22 * mult, 1.25 * mult) * CFrame.Angles(math.rad(45), 0, 0),
		color = lavaColor,
		material = Enum.Material.Neon,
		isWedge = true,
	}, isFollower)

	addPaws(model, root, isFollower, mult, rockColor)
end

-- =========================================================================
-- 7. VOLCANIC GOLEM (Volcanic Golem)
-- =========================================================================
local function buildVolcanicGolem(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local stoneColor = if isGold then Color3.fromRGB(150, 115, 40) elseif isRb then Color3.fromRGB(50, 45, 65) else Color3.fromRGB(48, 42, 42)
	local magmaRuneColor = if isGold then Color3.fromRGB(255, 235, 100) elseif isRb then Color3.fromRGB(255, 90, 220) else Color3.fromRGB(255, 85, 10)

	-- Heavy Craggy Shoulder Pauldrons (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ShoulderBolder_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.85 * mult, 0.85 * mult, 0.85 * mult),
			offset = CFrame.new(side * 1.35 * mult, 0.45 * mult, 0),
			color = stoneColor,
			material = Enum.Material.Slate,
		}, isFollower)
	end

	-- Glowing Molten Magma Core (Chest Rune)
	addPart(model, root, {
		name = "ChestMagmaCore",
		size = Vector3.new(0.85 * mult, 0.85 * mult, 0.22 * mult),
		offset = CFrame.new(0, -0.15 * mult, -1.02 * mult),
		color = magmaRuneColor,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Cross Rune Inscription
	addPart(model, root, {
		name = "RuneBarH",
		size = Vector3.new(1.10 * mult, 0.22 * mult, 0.26 * mult),
		offset = CFrame.new(0, -0.15 * mult, -1.02 * mult),
		color = magmaRuneColor,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Heavy Golem Brow
	addPart(model, root, {
		name = "GolemBrow",
		size = Vector3.new(1.60 * mult, 0.35 * mult, 0.40 * mult),
		offset = CFrame.new(0, 0.55 * mult, -0.98 * mult),
		color = stoneColor,
		material = Enum.Material.Slate,
	}, isFollower)

	-- Stone Fist Appendages
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "GolemFist_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.55 * mult, 0.55 * mult, 0.65 * mult),
			offset = CFrame.new(side * 1.35 * mult, -0.65 * mult, -0.20 * mult),
			color = stoneColor,
			material = Enum.Material.Slate,
		}, isFollower)
	end
end

-- =========================================================================
-- 8. ELDER MAGMA DRAKE (Elder Magma Drake)
-- =========================================================================
local function buildElderMagmaDrake(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local hornColor = if isGold then Color3.fromRGB(255, 235, 120) elseif isRb then Color3.fromRGB(255, 90, 240) else Color3.fromRGB(255, 40, 0)
	local obsidianColor = if isGold then Color3.fromRGB(120, 90, 20) elseif isRb then Color3.fromRGB(35, 20, 45) else Color3.fromRGB(28, 16, 16)
	local magmaGlow = if isGold then Color3.fromRGB(255, 215, 60) elseif isRb then Color3.fromRGB(255, 140, 255) else Color3.fromRGB(255, 120, 0)

	-- Massive Colossal Dual-Pronged Magma Horns (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ColossalHorn_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.52 * mult, 1.45 * mult, 0.52 * mult),
			offset = CFrame.new(side * 0.90 * mult, 1.40 * mult, 0.20 * mult) * CFrame.Angles(math.rad(-25), 0, math.rad(-side * 28)),
			color = obsidianColor,
			material = Enum.Material.Slate,
			isWedge = true,
		}, isFollower)

		-- Glowing Lava Tip on Horn
		addPart(model, root, {
			name = "HornLavaTip_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.36 * mult, 0.65 * mult, 0.36 * mult),
			offset = CFrame.new(side * 1.25 * mult, 1.95 * mult, 0.45 * mult) * CFrame.Angles(math.rad(-25), 0, math.rad(-side * 28)),
			color = hornColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Heavy Volcanic Wings (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ElderWingMain_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.20 * mult, 1.35 * mult, 1.20 * mult),
			offset = CFrame.new(side * 1.45 * mult, 0.45 * mult, 0.65 * mult) * CFrame.Angles(math.rad(18), math.rad(side * 25), math.rad(-side * 30)),
			color = obsidianColor,
			material = Enum.Material.Slate,
			isWedge = true,
		}, isFollower)

		addPart(model, root, {
			name = "ElderWingVein_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.12 * mult, 1.15 * mult, 0.95 * mult),
			offset = CFrame.new(side * 1.50 * mult, 0.40 * mult, 0.70 * mult) * CFrame.Angles(math.rad(18), math.rad(side * 25), math.rad(-side * 30)),
			color = magmaGlow,
			material = Enum.Material.Neon,
			transparency = 0.2,
		}, isFollower)
	end

	-- Spiked Magma Mace Tail
	addPart(model, root, {
		name = "ElderTailShaft",
		size = Vector3.new(0.45 * mult, 0.45 * mult, 1.35 * mult),
		offset = CFrame.new(0, -0.35 * mult, 1.45 * mult) * CFrame.Angles(math.rad(20), 0, 0),
		color = obsidianColor,
		material = Enum.Material.Slate,
	}, isFollower)

	addPart(model, root, {
		name = "ElderMaceClub",
		size = Vector3.new(0.75 * mult, 0.75 * mult, 0.75 * mult),
		offset = CFrame.new(0, -0.20 * mult, 2.25 * mult) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		color = hornColor,
		material = Enum.Material.Neon,
	}, isFollower)

	addPaws(model, root, isFollower, mult, obsidianColor)
end

-- =========================================================================
-- 9. ASTRAL KITSUNE (Astral Kitsune)
-- =========================================================================
local function buildAstralKitsune(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local furColor = if isGold then Color3.fromRGB(255, 235, 140) elseif isRb then Color3.fromRGB(240, 220, 255) else Color3.fromRGB(245, 240, 255)
	local markColor = if isGold then Color3.fromRGB(255, 180, 20) elseif isRb then Color3.fromRGB(255, 90, 210) else Color3.fromRGB(180, 110, 255)
	local celestialGlow = if isGold then Color3.fromRGB(255, 245, 150) elseif isRb then Color3.fromRGB(0, 240, 255) else Color3.fromRGB(140, 210, 255)

	-- Slender Kitsune Muzzle
	addPart(model, root, {
		name = "KitsuneMuzzle",
		size = Vector3.new(0.70 * mult, 0.40 * mult, 0.55 * mult),
		offset = CFrame.new(0, -0.16 * mult, -1.20 * mult) * CFrame.Angles(math.rad(10), 0, 0),
		color = furColor,
		material = Enum.Material.SmoothPlastic,
		isWedge = true,
	}, isFollower)

	-- Black Fox Button Nose
	addPart(model, root, {
		name = "KitsuneNose",
		size = Vector3.new(0.18 * mult, 0.14 * mult, 0.14 * mult),
		offset = CFrame.new(0, -0.06 * mult, -1.35 * mult),
		color = Color3.fromRGB(25, 20, 30),
		material = Enum.Material.SmoothPlastic,
		meshType = Enum.MeshType.Sphere,
	}, isFollower)

	-- Tall Pointed Kitsune Ears (Left & Right)
	local earConfigs = {
		{ pos = Vector3.new(-0.70 * mult, 1.35 * mult, -0.15 * mult), rotZ = 16 },
		{ pos = Vector3.new(0.70 * mult, 1.35 * mult, -0.15 * mult), rotZ = -16 },
	}
	for i, cfg in ipairs(earConfigs) do
		addPart(model, root, {
			name = "KitsuneEar_" .. i,
			size = Vector3.new(0.50 * mult, 0.95 * mult, 0.42 * mult),
			offset = CFrame.new(cfg.pos) * CFrame.Angles(math.rad(10), 0, math.rad(cfg.rotZ)),
			color = furColor,
			material = Enum.Material.SmoothPlastic,
			isWedge = true,
		}, isFollower)

		-- Sacred Spirit Ear Tip
		addPart(model, root, {
			name = "KitsuneEarTip_" .. i,
			size = Vector3.new(0.32 * mult, 0.48 * mult, 0.28 * mult),
			offset = CFrame.new(cfg.pos + Vector3.new(0, 0.28 * mult, -0.04 * mult)) * CFrame.Angles(math.rad(10), 0, math.rad(cfg.rotZ)),
			color = markColor,
			material = Enum.Material.Neon,
			isWedge = true,
		}, isFollower)
	end

	-- Forehead Celestial Third-Eye Spirit Gem
	addPart(model, root, {
		name = "SpiritForeheadGem",
		size = Vector3.new(0.24 * mult, 0.36 * mult, 0.12 * mult),
		offset = CFrame.new(0, 0.50 * mult, -1.04 * mult) * CFrame.Angles(0, 0, math.rad(45)),
		color = celestialGlow,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Triple Fanned Celestial Fox Tails floating behind
	local tailAngles = { -32, 0, 32 }
	for tIdx, ang in ipairs(tailAngles) do
		addPart(model, root, {
			name = "KitsuneTail_" .. tIdx,
			size = Vector3.new(0.42 * mult, 1.35 * mult, 0.42 * mult),
			offset = CFrame.new(0, -0.15 * mult, 1.25 * mult) * CFrame.Angles(math.rad(35), math.rad(ang), math.rad(-ang * 0.4)),
			color = furColor,
			material = Enum.Material.SmoothPlastic,
			meshType = Enum.MeshType.Sphere,
			meshScale = Vector3.new(1.0, 1.6, 1.0),
		}, isFollower)

		-- Glowing Tail Tip
		addPart(model, root, {
			name = "KitsuneTailTip_" .. tIdx,
			size = Vector3.new(0.35 * mult, 0.65 * mult, 0.35 * mult),
			offset = CFrame.new(0, -0.15 * mult, 1.25 * mult) * CFrame.Angles(math.rad(35), math.rad(ang), math.rad(-ang * 0.4)) * CFrame.new(0, 0.65 * mult, 0),
			color = markColor,
			material = Enum.Material.Neon,
			meshType = Enum.MeshType.Sphere,
			meshScale = Vector3.new(1.0, 1.4, 1.0),
		}, isFollower)
	end

	addPaws(model, root, isFollower, mult, markColor)
end

-- =========================================================================
-- 10. VOID LEVIATHAN (Void Leviathan)
-- =========================================================================
local function buildVoidLeviathan(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local deepColor = if isGold then Color3.fromRGB(140, 105, 30) elseif isRb then Color3.fromRGB(35, 20, 60) else Color3.fromRGB(24, 20, 48)
	local biolumColor = if isGold then Color3.fromRGB(255, 235, 120) elseif isRb then Color3.fromRGB(80, 240, 255) else Color3.fromRGB(140, 80, 255)

	-- Whale Underbelly
	addPart(model, root, {
		name = "WhaleBelly",
		size = Vector3.new(1.85 * mult, 0.35 * mult, 2.10 * mult),
		offset = CFrame.new(0, -0.92 * mult, 0),
		color = biolumColor,
		material = Enum.Material.Neon,
		transparency = 0.25,
	}, isFollower)

	-- Dorsal Fin on Top
	addPart(model, root, {
		name = "DorsalFin",
		size = Vector3.new(0.22 * mult, 0.85 * mult, 0.85 * mult),
		offset = CFrame.new(0, 1.25 * mult, 0.20 * mult) * CFrame.Angles(math.rad(15), 0, 0),
		color = deepColor,
		material = Enum.Material.SmoothPlastic,
		isWedge = true,
	}, isFollower)

	-- Dual Sweeping Pectoral Flippers (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "Flipper_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(1.20 * mult, 0.16 * mult, 0.65 * mult),
			offset = CFrame.new(side * 1.55 * mult, -0.45 * mult, -0.15 * mult) * CFrame.Angles(0, math.rad(-side * 20), math.rad(side * 15)),
			color = deepColor,
			material = Enum.Material.SmoothPlastic,
		}, isFollower)
	end

	-- Angler Lure Stem arching over forehead
	addPart(model, root, {
		name = "AnglerStem",
		size = Vector3.new(0.12 * mult, 0.65 * mult, 0.65 * mult),
		offset = CFrame.new(0, 1.25 * mult, -0.95 * mult) * CFrame.Angles(math.rad(-35), 0, 0),
		color = deepColor,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	-- Glowing Void Angler Orb
	addPart(model, root, {
		name = "VoidLureOrb",
		size = Vector3.new(0.48 * mult, 0.48 * mult, 0.48 * mult),
		offset = CFrame.new(0, 1.45 * mult, -1.35 * mult),
		color = biolumColor,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	}, isFollower)

	-- Broad Horizontal Whale Tail Fluke at rear
	addPart(model, root, {
		name = "TailShaft",
		size = Vector3.new(0.45 * mult, 0.45 * mult, 1.15 * mult),
		offset = CFrame.new(0, -0.15 * mult, 1.45 * mult),
		color = deepColor,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	addPart(model, root, {
		name = "TailFluke",
		size = Vector3.new(1.85 * mult, 0.16 * mult, 0.75 * mult),
		offset = CFrame.new(0, -0.15 * mult, 2.10 * mult),
		color = biolumColor,
		material = Enum.Material.Neon,
	}, isFollower)
end

-- =========================================================================
-- 11. CHRONOS DRAKE (Chronos Void Drake - Mythic)
-- =========================================================================
local function buildChronosDrake(model: Model, root: BasePart, isFollower: boolean, mult: number, tier: PetTier)
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local cosmicBody = if isGold then Color3.fromRGB(160, 125, 30) elseif isRb then Color3.fromRGB(30, 20, 50) else Color3.fromRGB(15, 25, 45)
	local chronosGold = if isGold then Color3.fromRGB(255, 235, 120) elseif isRb then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 215, 0)
	local temporalCyan = if isGold then Color3.fromRGB(255, 245, 160) elseif isRb then Color3.fromRGB(255, 90, 230) else Color3.fromRGB(0, 245, 255)

	-- Floating Clockwork Gear Halo hovering behind head
	addPart(model, root, {
		name = "ClockworkHaloRing",
		size = Vector3.new(2.40 * mult, 2.40 * mult, 0.14 * mult),
		offset = CFrame.new(0, 0.65 * mult, 0.95 * mult) * CFrame.Angles(math.rad(18), 0, 0),
		color = chronosGold,
		material = Enum.Material.Metal,
		meshType = Enum.MeshType.Cylinder,
	}, isFollower)

	-- Halo Gear Teeth (8 prongs around halo)
	for i = 1, 8 do
		local rotAng = (i / 8) * math.pi * 2
		addPart(model, root, {
			name = "HaloTooth_" .. i,
			size = Vector3.new(0.22 * mult, 0.45 * mult, 0.16 * mult),
			offset = CFrame.new(0, 0.65 * mult, 0.95 * mult) * CFrame.Angles(math.rad(18), 0, rotAng) * CFrame.new(0, 1.25 * mult, 0),
			color = temporalCyan,
			material = Enum.Material.Neon,
		}, isFollower)
	end

	-- Curved Temporal Chronos Horns (Left & Right)
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ChronosHorn_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.44 * mult, 1.35 * mult, 0.44 * mult),
			offset = CFrame.new(side * 0.85 * mult, 1.35 * mult, 0.10 * mult) * CFrame.Angles(math.rad(-22), 0, math.rad(-side * 25)),
			color = chronosGold,
			material = Enum.Material.Metal,
			isWedge = true,
		}, isFollower)
	end

	-- Cosmic Temporal Wings with Glowing Star Edges
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, root, {
			name = "ChronosWingBone_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.18 * mult, 1.45 * mult, 1.25 * mult),
			offset = CFrame.new(side * 1.45 * mult, 0.50 * mult, 0.65 * mult) * CFrame.Angles(math.rad(18), math.rad(side * 28), math.rad(-side * 30)),
			color = cosmicBody,
			material = Enum.Material.SmoothPlastic,
			isWedge = true,
		}, isFollower)

		addPart(model, root, {
			name = "ChronosWingFeathers_" .. (side < 0 and "L" or "R"),
			size = Vector3.new(0.10 * mult, 1.30 * mult, 1.10 * mult),
			offset = CFrame.new(side * 1.50 * mult, 0.45 * mult, 0.70 * mult) * CFrame.Angles(math.rad(18), math.rad(side * 28), math.rad(-side * 30)),
			color = temporalCyan,
			material = Enum.Material.Neon,
			transparency = 0.15,
		}, isFollower)
	end

	-- Glowing Hourglass Crystal Core in Chest
	addPart(model, root, {
		name = "HourglassCrystal",
		size = Vector3.new(0.55 * mult, 0.75 * mult, 0.35 * mult),
		offset = CFrame.new(0, -0.15 * mult, -1.05 * mult),
		color = temporalCyan,
		material = Enum.Material.Neon,
	}, isFollower)

	-- Spiked Chronos Tail
	addPart(model, root, {
		name = "ChronosTail",
		size = Vector3.new(0.42 * mult, 0.42 * mult, 1.35 * mult),
		offset = CFrame.new(0, -0.30 * mult, 1.35 * mult) * CFrame.Angles(math.rad(22), 0, 0),
		color = cosmicBody,
		material = Enum.Material.SmoothPlastic,
	}, isFollower)

	addPart(model, root, {
		name = "ChronosTailDiamond",
		size = Vector3.new(0.65 * mult, 0.65 * mult, 0.65 * mult),
		offset = CFrame.new(0, -0.15 * mult, 2.15 * mult) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		color = chronosGold,
		material = Enum.Material.Neon,
	}, isFollower)

	addPaws(model, root, isFollower, mult, chronosGold)
end

-- =========================================================================
-- MASTER BUILD FUNCTION
-- =========================================================================
function PetModelBuilder.createModel(petDef: PetDef, scaleMult: number?, isFollower: boolean?): Model
	local mult = scaleMult or 1.0
	local follower = isFollower or false
	local tier = petDef.tier or "Normal"
	local isGold = tier == "Golden"
	local isRb = tier == "Rainbow"

	local baseId = petDef.baseId or petDef.id
	baseId = string.gsub(baseId, "_Golden$", "")
	baseId = string.gsub(baseId, "_Rainbow$", "")

	local model = Instance.new("Model")
	model.Name = "Pet3D_" .. petDef.id

	-- Primary Body
	local body = Instance.new("Part")
	body.Name = "PrimaryPart"
	body.Size = Vector3.new(2.0 * mult, 2.0 * mult, 2.0 * mult)
	body.CFrame = CFrame.new(0, 0, 0)
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	body.Anchored = not follower
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth

	if isGold then
		body.Color = Color3.fromRGB(255, 215, 0)
		body.Material = Enum.Material.Metal
	elseif isRb then
		body.Color = Color3.fromRGB(255, 105, 180)
		body.Material = Enum.Material.Neon
	else
		body.Color = petDef.color
		body.Material = Enum.Material.SmoothPlastic
	end

	if petDef.meshType == "Sphere" then
		body.Shape = Enum.PartType.Ball
	elseif petDef.meshType == "Diamond" then
		local dMesh = Instance.new("SpecialMesh")
		dMesh.MeshType = Enum.MeshType.Sphere
		dMesh.Scale = Vector3.new(1.05, 1.35, 1.05)
		dMesh.Parent = body
	end

	body.Parent = model
	model.PrimaryPart = body

	-- Eyes
	local eyeColor = if baseId == "InfernoDragon" or baseId == "MagmaHound" or baseId == "ElderMagmaDrake" then Color3.fromRGB(255, 120, 0)
		elseif baseId == "ChronosDrake" or baseId == "VoidLeviathan" then Color3.fromRGB(0, 240, 255)
		else nil
	addEyes(model, body, follower, mult, eyeColor, isGold, isRb)

	-- Breed Specific 3D Assembly
	if baseId == "CrystalDoge" then
		buildCrystalDoge(model, body, follower, mult, tier)
	elseif baseId == "SparkleKitty" then
		buildSparkleKitty(model, body, follower, mult, tier)
	elseif baseId == "NeonBunny" then
		buildNeonBunny(model, body, follower, mult, tier)
	elseif baseId == "InfernoDragon" then
		buildInfernoDragon(model, body, follower, mult, tier)
	elseif baseId == "VoidPhoenix" then
		buildVoidPhoenix(model, body, follower, mult, tier)
	elseif baseId == "MagmaHound" then
		buildMagmaHound(model, body, follower, mult, tier)
	elseif baseId == "VolcanicGolem" then
		buildVolcanicGolem(model, body, follower, mult, tier)
	elseif baseId == "ElderMagmaDrake" then
		buildElderMagmaDrake(model, body, follower, mult, tier)
	elseif baseId == "AstralKitsune" then
		buildAstralKitsune(model, body, follower, mult, tier)
	elseif baseId == "VoidLeviathan" then
		buildVoidLeviathan(model, body, follower, mult, tier)
	elseif baseId == "ChronosDrake" then
		buildChronosDrake(model, body, follower, mult, tier)
	end

	-- Particle Effects for Golden / Rainbow tiers
	if isGold or isRb then
		local att = Instance.new("Attachment")
		att.Name = "TierParticlesAtt"
		att.Parent = body

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "TierSparkles"
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25 * mult),
			NumberSequenceKeypoint.new(1, 0.05 * mult),
		})
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Rate = if isRb then 24 else 16
		emitter.Speed = NumberRange.new(0.8, 1.8)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.LightEmission = 1.0

		if isGold then
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 140)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 185, 20)),
			})
		else
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 240)),
			})
		end
		emitter.Parent = att
	end

	return model
end

-- =========================================================================
-- VIEWPORT FRAME SETUP HELPER
-- =========================================================================
function PetModelBuilder.setupViewport(viewport: ViewportFrame, petDef: PetDef, autoRotate: boolean?): () -> ()
	-- Clear prior contents
	for _, ch in ipairs(viewport:GetChildren()) do
		if ch:IsA("Model") or ch:IsA("Camera") then
			ch:Destroy()
		end
	end

	local model = PetModelBuilder.createModel(petDef, 1.0, false)
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 45
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Focus on center of model
	local primPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	local centerPos = if primPart then primPart.Position else Vector3.zero
	local camDist = 5.2

	local currentAngle = math.rad(-25)
	local function updateCam()
		local eyePos = centerPos + Vector3.new(math.sin(currentAngle) * camDist, 1.2, math.cos(currentAngle) * camDist)
		camera.CFrame = CFrame.new(eyePos, centerPos + Vector3.new(0, 0.1, 0))
	end
	updateCam()

	local conn: RBXScriptConnection? = nil
	if autoRotate then
		conn = RunService.RenderStepped:Connect(function(dt)
			if not viewport or not viewport.Parent then
				if conn then
					conn:Disconnect()
					conn = nil
				end
				return
			end
			currentAngle += dt * 1.4
			updateCam()
		end)

		viewport.Destroying:Connect(function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end)
	end

	return function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end
end

return PetModelBuilder
