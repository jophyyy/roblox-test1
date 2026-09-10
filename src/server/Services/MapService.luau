--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local MarketplaceServiceHandler = require(script.Parent.MarketplaceServiceHandler)
local TrainingConfig = require(ReplicatedStorage.Shared.Config.TrainingConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local OreModelBuilder = require(ReplicatedStorage.Shared.Utils.OreModelBuilder)
local TownBuildingBuilder = require(ReplicatedStorage.Shared.Utils.TownBuildingBuilder)

local MapService = {}
local brazierLights: { PointLight } = {}

-- Utility to create authentic retro stud-textured parts
local function createStudPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	canCollide: boolean?,
	topSurface: Enum.SurfaceType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = topSurface or Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.Anchored = true
	part.CanCollide = if canCollide ~= nil then canCollide else true
	part.CanTouch = false -- Optimized for static decorative map geometry
	part.Parent = parent
	return part
end

-- Creates an authentic retro roguelike carved stone brazier with crackling fire and embers
local function createDungeonBrazier(parent: Instance, name: string, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name

	local stoneDark = Color3.fromRGB(48, 52, 58)
	local stoneMid = Color3.fromRGB(64, 68, 76)
	local ironColor = Color3.fromRGB(36, 38, 44)
	local fireGlow = Color3.fromRGB(255, 140, 40)

	-- Step 1: Broad Studded Stone Pedestal Base
	createStudPart(model, "BrazierBase", Vector3.new(3.8, 0.8, 3.8), cf * CFrame.new(0, 0.4, 0), stoneDark)

	-- Step 2: Carved Column Pillar with Studs
	createStudPart(model, "BrazierPillar", Vector3.new(2.4, 4.0, 2.4), cf * CFrame.new(0, 2.8, 0), stoneMid)

	-- Step 3: Flared Stone Basin Capital
	createStudPart(model, "BrazierCapital", Vector3.new(4.2, 0.8, 4.2), cf * CFrame.new(0, 5.2, 0), stoneDark)

	-- Step 4: Dark Cast-Iron Fire Bowl Rim
	local bowl = createStudPart(model, "IronBowl", Vector3.new(4.4, 0.6, 4.4), cf * CFrame.new(0, 5.8, 0), ironColor)
	bowl.Material = Enum.Material.Metal

	-- Step 5: Glowing Ember Core inside bowl
	local coals = createStudPart(model, "GlowingEmbers", Vector3.new(3.2, 0.4, 3.2), cf * CFrame.new(0, 6.1, 0), Color3.fromRGB(255, 80, 20))
	coals.Material = Enum.Material.Neon

	-- Fire & Spark Particle Emitter
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.4, 0)
	attachment.Parent = coals

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "TorchFire"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 130, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 0)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.LightEmission = 0.85
	fire.LightInfluence = 0
	fire.Lifetime = NumberRange.new(0.7, 1.2)
	fire.Rate = 18
	fire.Speed = NumberRange.new(3.5, 6.0)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.Acceleration = Vector3.new(0, 4, 0)
	fire.Parent = attachment

	-- Rising Glowing Ember Sparks
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(1.0, 1.8)
	sparks.Rate = 8
	sparks.Speed = NumberRange.new(5, 9)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Parent = attachment

	-- Dynamic Torch Light casting shadows
	local light = Instance.new("PointLight")
	light.Color = fireGlow
	light.Brightness = 2.2
	light.Range = 32
	light.Shadows = true
	light.Parent = coals

	table.insert(brazierLights, light)

	model.Parent = parent
	return model
end

-- 1. Baseplate & Rolling Green Grass Meadow
function MapService.buildBase(folder: Folder)
	-- Large primary green meadow base sitting flush at ground level (Y = 0)
	createStudPart(
		folder,
		"MeadowGrass",
		Vector3.new(512, 10.0, 512),
		CFrame.new(0, -5.0, 0),
		Color3.fromRGB(72, 148, 72)
	)
end

-- 2. Perimeter Mountains (acting as natural boundaries so players cannot fall off)
function MapService.buildMountains(folder: Folder)
	local mountainsFolder = Instance.new("Folder")
	mountainsFolder.Name = "Mountains"
	mountainsFolder.Parent = folder

	local rockDark = Color3.fromRGB(80, 85, 92)
	local rockMid = Color3.fromRGB(105, 110, 118)
	local rockLight = Color3.fromRGB(130, 135, 145)

	-- Generates a stepped mountain range along a perimeter axis
	local function createRidge(
		startX: number,
		endX: number,
		startZ: number,
		endZ: number,
		isZAxis: boolean
	)
		local count = 8
		for i = 1, count do
			local alpha = (i - 0.5) / count
			local cx = startX + (endX - startX) * alpha
			local cz = startZ + (endZ - startZ) * alpha

			-- Layer 1: Massive rugged base cliff
			createStudPart(
				mountainsFolder,
				"RockBase",
				if isZAxis then Vector3.new(45, 18, 55) else Vector3.new(55, 18, 45),
				CFrame.new(cx, 9, cz),
				rockDark
			)

			-- Layer 2: Mid-tier stone shelf with studs
			local midOffset = if i % 2 == 0 then 4 else -4
			createStudPart(
				mountainsFolder,
				"RockMid",
				if isZAxis then Vector3.new(35, 22, 42) else Vector3.new(42, 22, 35),
				CFrame.new(cx + (if isZAxis then midOffset else 0), 20, cz + (if not isZAxis then midOffset else 0)),
				rockMid
			)

			-- Layer 3: High dramatic mountain peak
			local peakHeight = 24 + ((i * 7) % 20)
			createStudPart(
				mountainsFolder,
				"RockPeak",
				if isZAxis then Vector3.new(24, peakHeight, 28) else Vector3.new(28, peakHeight, 24),
				CFrame.new(cx, 31 + (peakHeight / 2), cz),
				rockLight
			)
		end
	end

	-- Perimeter Mountain Walls for Zone 1 (West and East, leaving North open to Magma Caverns and South open to Cosmic Void)
	createRidge(-210, -210, -140, 140, true)  -- West Wall
	createRidge(210, 210, -140, 140, true)    -- East Wall

	-- Corner Bastions (Grand diagonal corner peaks)
	local corners = {
		Vector3.new(-210, 0, -140),
		Vector3.new(210, 0, -140),
		Vector3.new(-210, 0, 140),
		Vector3.new(210, 0, 140),
	}
	for _, corner in ipairs(corners) do
		createStudPart(mountainsFolder, "CornerPeakL", Vector3.new(50, 45, 50), CFrame.new(corner + Vector3.new(0, 22.5, 0)), rockDark)
		createStudPart(mountainsFolder, "CornerPeakH", Vector3.new(32, 60, 32), CFrame.new(corner + Vector3.new(0, 45, 0)), rockLight)
	end
end

-- 3. Central Lofty Hexagonal Spawn Plaza & Avenues Connecting to Exploration Zones
function MapService.buildPlazaAndPaths(folder: Folder)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "PlazaAndPaths"
	pathsFolder.Parent = folder

	local stoneColor = Color3.fromRGB(80, 85, 92)
	local stoneDark = Color3.fromRGB(48, 52, 58)
	local stoneTrim = Color3.fromRGB(62, 66, 74)
	local goldTrim = Color3.fromRGB(255, 215, 60)

	-- =========================================================================
	-- A. ELEVATED REGULAR HEXAGONAL PLAZA (Floor at Y = 3.0, Radius R = 36 studs)
	-- =========================================================================
	local R = 36
	local d = R * math.cos(math.rad(30)) -- 31.177 studs to each of the 6 flat edges
	local floorY = 3.0
	local floorThickness = 3.0 -- Extends from ground level up to Y = 3.0

	-- 1. Stepped Foundation Sub-Plinth (Y = 0 to 1.5, slightly wider R = 38)
	createStudPart(pathsFolder, "HexSubPlinth1", Vector3.new(38, 1.5, 66), CFrame.new(0, 0.75, 0), stoneDark)
	createStudPart(pathsFolder, "HexSubPlinth2", Vector3.new(22, 1.5, 56), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, math.rad(60), 0), stoneDark)
	createStudPart(pathsFolder, "HexSubPlinth3", Vector3.new(22, 1.5, 56), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, math.rad(-60), 0), stoneDark)

	-- 2. Primary Hexagonal Stone Plaza Floor (Y = 0 to 3.0)
	-- Formed cleanly with 1 broad center slab + 2 angled wing slabs (zero gaps, zero flickering)
	createStudPart(pathsFolder, "HexPlazaCore", Vector3.new(36, floorThickness, 62.4), CFrame.new(0, floorY * 0.5, 0), stoneColor)
	createStudPart(pathsFolder, "HexPlazaWing1", Vector3.new(20, floorThickness, 52.0), CFrame.new(0, floorY * 0.5, 0) * CFrame.Angles(0, math.rad(60), 0), stoneColor)
	createStudPart(pathsFolder, "HexPlazaWing2", Vector3.new(20, floorThickness, 52.0), CFrame.new(0, floorY * 0.5, 0) * CFrame.Angles(0, math.rad(-60), 0), stoneColor)

	-- 3. Decorative Hexagonal Perimeter Kerb Balustrade along all 6 sides
	-- 6 perimeter sides at distance d = 31.18 from origin
	local hexEdges = {
		{ name = "Edge_N",  cf = CFrame.new(0, floorY + 0.5, -d) * CFrame.Angles(0, 0, 0), len = 36 },
		{ name = "Edge_S",  cf = CFrame.new(0, floorY + 0.5, d) * CFrame.Angles(0, 0, 0), len = 36 },
		{ name = "Edge_NE", cf = CFrame.new(d * 0.866, floorY + 0.5, -d * 0.5) * CFrame.Angles(0, math.rad(-60), 0), len = 36 },
		{ name = "Edge_NW", cf = CFrame.new(-d * 0.866, floorY + 0.5, -d * 0.5) * CFrame.Angles(0, math.rad(60), 0), len = 36 },
		{ name = "Edge_SE", cf = CFrame.new(d * 0.866, floorY + 0.5, d * 0.5) * CFrame.Angles(0, math.rad(60), 0), len = 36 },
		{ name = "Edge_SW", cf = CFrame.new(-d * 0.866, floorY + 0.5, d * 0.5) * CFrame.Angles(0, math.rad(-60), 0), len = 36 },
	}
	for _, edge in ipairs(hexEdges) do
		createStudPart(pathsFolder, edge.name, Vector3.new(edge.len, 1.0, 2.4), edge.cf, stoneTrim)
	end

	-- 4. Six Roaring Dungeon Braziers at the 6 Hexagon Vertices (Elevated, Roaring Flame)
	for i = 0, 5 do
		local rad = math.rad(i * 60 + 30) -- vertices at 30, 90, 150, 210, 270, 330 deg
		local vx = R * math.cos(rad)
		local vz = R * math.sin(rad)
		createDungeonBrazier(pathsFolder, "HexBrazier_" .. i, CFrame.new(vx, floorY, vz))
	end

	-- 5. Grand Stepped Stone Stairways leading smoothly down on all 4 Cardinal Paths
	-- Each stairway has 4 wide, low stone steps (step height 0.7, depth 2.6, width 14)
	local stairDirections = {
		{ name = "Stairs_North", dir = Vector3.new(0, 0, -1), startPos = Vector3.new(0, floorY, -d), yaw = 0 },
		{ name = "Stairs_South", dir = Vector3.new(0, 0, 1),  startPos = Vector3.new(0, floorY, d),  yaw = 180 },
		{ name = "Stairs_West",  dir = Vector3.new(-1, 0, 0), startPos = Vector3.new(-d * 0.866, floorY, 0), yaw = 90 },
		{ name = "Stairs_East",  dir = Vector3.new(1, 0, 0),  startPos = Vector3.new(d * 0.866, floorY, 0),  yaw = -90 },
	}

	for _, sDef in ipairs(stairDirections) do
		for stepIdx = 1, 4 do
			local sY = floorY - (stepIdx * 0.7)
			local sDist = (stepIdx - 0.5) * 2.6
			local stepPos = sDef.startPos + (sDef.dir * sDist)
			stepPos = Vector3.new(stepPos.X, sY, stepPos.Z)

			createStudPart(
				pathsFolder,
				sDef.name .. "_Step" .. stepIdx,
				Vector3.new(14, 0.7, 2.6),
				CFrame.new(stepPos) * CFrame.Angles(0, math.rad(sDef.yaw), 0),
				stoneTrim
			)
		end
	end

	-- =========================================================================
	-- B. ELEVATED CENTRAL HEXAGONAL SPAWN DAIS (The Grand Spawn Emblem)
	-- =========================================================================
	local daisY = 3.6
	createStudPart(pathsFolder, "SpawnDaisBase", Vector3.new(18, 0.6, 18), CFrame.new(0, daisY - 0.3, 0), stoneDark)
	local daisTop = createStudPart(pathsFolder, "SpawnDaisTop", Vector3.new(15, 0.4, 15), CFrame.new(0, daisY + 0.2, 0), stoneTrim)
	daisTop.Material = Enum.Material.SmoothPlastic

	-- Inlaid Glowing Golden Sun Compass Star
	local starCore = createStudPart(pathsFolder, "SpawnStarCore", Vector3.new(4.5, 0.15, 4.5), CFrame.new(0, daisY + 0.42, 0), goldTrim)
	starCore.Material = Enum.Material.Neon
	for _, deg in ipairs({ 0, 45, 90, 135 }) do
		local starRay = createStudPart(pathsFolder, "StarRay_" .. deg, Vector3.new(10, 0.12, 2.2), CFrame.new(0, daisY + 0.42, 0) * CFrame.Angles(0, math.rad(deg), 0), goldTrim)
		starRay.Material = Enum.Material.Neon
	end

	-- Ensure Workspace.SpawnLocation sits perfectly on the dais
	local spawnLoc = Workspace:FindFirstChild("SpawnLocation") :: SpawnLocation?
	if spawnLoc then
		spawnLoc.CFrame = CFrame.new(0, daisY + 0.2, 0)
		spawnLoc.Size = Vector3.new(14, 0.4, 14)
		spawnLoc.Transparency = 1
		spawnLoc.CanCollide = false
	end

	-- =========================================================================
	-- C. CONNECTING AVENUES & COURTYARD PAVEMENTS
	-- =========================================================================
	-- 1. North Avenue (leading to Magma Gate & Rebirth Quarry)
	createStudPart(pathsFolder, "Path_North", Vector3.new(12, 0.35, 100), CFrame.new(0, 0.2, -88), stoneColor)
	-- 2. South Avenue (leading to Cosmic Gate & Boss Arena)
	createStudPart(pathsFolder, "Path_South", Vector3.new(12, 0.35, 100), CFrame.new(0, 0.2, 88), stoneColor)
	-- 3. West Town Courtyard (connecting Blacksmith & Trail Artisan)
	createStudPart(pathsFolder, "Courtyard_West", Vector3.new(24, 0.35, 48), CFrame.new(-38, 0.2, 0), stoneColor)
	-- 4. East Sanctuary Courtyard (connecting Hatchery, Fusion Lab, & VIP Pavilion)
	createStudPart(pathsFolder, "Courtyard_East", Vector3.new(24, 0.35, 48), CFrame.new(38, 0.2, 0), stoneColor)

	-- Pathway Braziers along North & South Avenues
	local avenueBraziers = {
		Vector3.new(8, 0, -65),
		Vector3.new(-8, 0, -65),
		Vector3.new(8, 0, -105),
		Vector3.new(-8, 0, -105),
		Vector3.new(8, 0, 65),
		Vector3.new(-8, 0, 65),
		Vector3.new(8, 0, 105),
		Vector3.new(-8, 0, 105),
	}
	for bIdx, bPos in ipairs(avenueBraziers) do
		createDungeonBrazier(pathsFolder, "AvenueBrazier_" .. bIdx, CFrame.new(bPos))
	end
end

-- 4. Classic Retro Roblox Trees (2-3 tiered foliage blocks with studs)
function MapService.buildTrees(folder: Folder)
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = folder

	local trunkColor = Color3.fromRGB(115, 75, 45)
	local leafColors = {
		Color3.fromRGB(50, 138, 52),
		Color3.fromRGB(42, 122, 44),
		Color3.fromRGB(60, 155, 62),
	}

	local function spawnTree(pos: Vector3, scale: number)
		local s = scale or 1.0
		local treeModel = Instance.new("Model")
		treeModel.Name = "RetroTree"

		-- Brown Wood Trunk
		local trunkH = 10 * s
		createStudPart(
			treeModel,
			"Trunk",
			Vector3.new(2.6 * s, trunkH, 2.6 * s),
			CFrame.new(pos + Vector3.new(0, (trunkH / 2) + 0.5, 0)),
			trunkColor
		)

		-- Tier 1 Foliage (Broad lower canopy with studs)
		local col1 = leafColors[1]
		createStudPart(
			treeModel,
			"LeavesBase",
			Vector3.new(12 * s, 4.5 * s, 12 * s),
			CFrame.new(pos + Vector3.new(0, trunkH + (2 * s), 0)),
			col1
		)

		-- Tier 2 Foliage (Mid tier)
		local col2 = leafColors[2]
		createStudPart(
			treeModel,
			"LeavesMid",
			Vector3.new(9 * s, 4 * s, 9 * s),
			CFrame.new(pos + Vector3.new(0, trunkH + (5.5 * s), 0)),
			col2
		)

		-- Tier 3 Foliage (Top crown with studs)
		local col3 = leafColors[3]
		createStudPart(
			treeModel,
			"LeavesTop",
			Vector3.new(6 * s, 3.5 * s, 6 * s),
			CFrame.new(pos + Vector3.new(0, trunkH + (8.5 * s), 0)),
			col3
		)

		treeModel.Parent = treesFolder
	end

	-- Coordinates chosen strictly in outer buffer greenbelts, with ZERO overlap near buildings or plaza
	local treePositions = {
		-- West Town Outer Garden (behind Blacksmith & Trail Artisan)
		Vector3.new(-60, 0, -35),
		Vector3.new(-65, 0, -18),
		Vector3.new(-62, 0, 0),
		Vector3.new(-65, 0, 18),
		Vector3.new(-60, 0, 35),

		-- East Sanctuary Outer Garden (behind Sanctuary & Fusion Lab)
		Vector3.new(62, 0, -35),
		Vector3.new(65, 0, -18),
		Vector3.new(62, 0, 18),
		Vector3.new(65, 0, 35),

		-- North Avenue Flanking Groves (Spaced >= 20 studs from path)
		Vector3.new(-24, 0, -68),
		Vector3.new(24, 0, -68),
		Vector3.new(-26, 0, -102),
		Vector3.new(26, 0, -102),

		-- South Avenue Flanking Groves (Spaced >= 20 studs from path)
		Vector3.new(-24, 0, 68),
		Vector3.new(24, 0, 68),
		Vector3.new(-26, 0, 102),
		Vector3.new(26, 0, 102),

		-- Foothill groves along North & South borders
		Vector3.new(-120, 0, -125),
		Vector3.new(-70, 0, -128),
		Vector3.new(-20, 0, -125),
		Vector3.new(30, 0, -128),
		Vector3.new(85, 0, -125),
		Vector3.new(130, 0, -128),

		Vector3.new(-120, 0, 145),
		Vector3.new(-70, 0, 150),
		Vector3.new(-20, 0, 145),
		Vector3.new(30, 0, 150),
		Vector3.new(85, 0, 145),
		Vector3.new(130, 0, 150),

		-- Foothill groves along West & East borders
		Vector3.new(-145, 0, -100),
		Vector3.new(-150, 0, -40),
		Vector3.new(-145, 0, 40),
		Vector3.new(-150, 0, 100),

		Vector3.new(145, 0, -100),
		Vector3.new(150, 0, -40),
		Vector3.new(145, 0, 40),
		Vector3.new(150, 0, 100),
	}

	for i, pos in ipairs(treePositions) do
		local scale = 0.85 + (((i * 13) % 4) * 0.12)
		spawnTree(pos, scale)
	end
end

-- 5. Colorful Retro Stud Flowers & Shrub Plants
function MapService.buildFlora(folder: Folder)
	local floraFolder = Instance.new("Folder")
	floraFolder.Name = "Flora"
	floraFolder.Parent = folder

	local stemColor = Color3.fromRGB(55, 140, 55)
	local petalColors = {
		Color3.fromRGB(240, 50, 50),   -- Classic Red Poppy
		Color3.fromRGB(250, 215, 30),  -- Bright Yellow Dandelion
		Color3.fromRGB(55, 145, 245),  -- Vivid Cyan Bluebell
		Color3.fromRGB(245, 245, 250), -- Crisp White Daisy
		Color3.fromRGB(220, 80, 220),  -- Purple Orchid
	}
	local bushGreen = Color3.fromRGB(48, 128, 50)

	-- Function to spawn a cute retro 3-part flower with studs
	local function spawnFlower(pos: Vector3, colorIdx: number)
		local pColor = petalColors[((colorIdx - 1) % #petalColors) + 1]

		-- Stem
		createStudPart(
			floraFolder,
			"FlowerStem",
			Vector3.new(0.6, 1.2, 0.6),
			CFrame.new(pos + Vector3.new(0, 1.1, 0)),
			stemColor,
			false -- non-collidable for silky smooth walking
		)

		-- Flower Petal Head
		createStudPart(
			floraFolder,
			"FlowerPetal",
			Vector3.new(1.8, 0.6, 1.8),
			CFrame.new(pos + Vector3.new(0, 1.8, 0)),
			pColor,
			false
		)

		-- Yellow Center Stud
		local center = createStudPart(
			floraFolder,
			"FlowerCenter",
			Vector3.new(0.8, 0.3, 0.8),
			CFrame.new(pos + Vector3.new(0, 2.15, 0)),
			Color3.fromRGB(255, 220, 0),
			false
		)
		center.Material = Enum.Material.Neon
	end

	-- Function to spawn a small retro stud shrub
	local function spawnBush(pos: Vector3, sizeMultiplier: number)
		local sm = sizeMultiplier or 1.0
		createStudPart(
			floraFolder,
			"BushBase",
			Vector3.new(4 * sm, 2.2 * sm, 4 * sm),
			CFrame.new(pos + Vector3.new(0, (1.1 * sm) + 0.5, 0)),
			bushGreen,
			false
		)
		createStudPart(
			floraFolder,
			"BushTop",
			Vector3.new(2.8 * sm, 1.6 * sm, 2.8 * sm),
			CFrame.new(pos + Vector3.new(0, (2.8 * sm) + 0.5, 0)),
			Color3.fromRGB(60, 148, 62),
			false
		)
	end

	-- Spawn flowerbeds and shrub clusters neatly framing pathways and town corners
	local clusterCenters = {
		Vector3.new(-24, 0, -38),
		Vector3.new(24, 0, -38),
		Vector3.new(-24, 0, 38),
		Vector3.new(24, 0, 38),
		Vector3.new(-18, 0, -52),
		Vector3.new(18, 0, -52),
		Vector3.new(-18, 0, 52),
		Vector3.new(18, 0, 52),
		Vector3.new(-54, 0, 0),
		Vector3.new(54, 0, 0),
	}

	for idx, center in ipairs(clusterCenters) do
		spawnBush(center, 0.85 + ((idx % 3) * 0.15))

		local offsets = {
			Vector3.new(-2.8, 0, -2.4),
			Vector3.new(2.8, 0, -1.8),
			Vector3.new(-2.0, 0, 2.8),
			Vector3.new(2.6, 0, 2.4),
		}
		for fIdx, off in ipairs(offsets) do
			spawnFlower(center + off, idx + fIdx)
		end
	end
end

-- 6. Ancient Crumbling Dungeon Ruins, Mystical Runestones & Gateway Arches (Studs Design)
function MapService.buildDungeonRuins(folder: Folder)
	local ruinsFolder = Instance.new("Folder")
	ruinsFolder.Name = "DungeonRuins"
	ruinsFolder.Parent = folder

	local stoneDark = Color3.fromRGB(50, 54, 60)
	local stoneMid = Color3.fromRGB(68, 72, 80)
	local stoneMoss = Color3.fromRGB(56, 66, 56)
	local runeCyan = Color3.fromRGB(0, 230, 255)
	local runePurple = Color3.fromRGB(210, 60, 255)

	-- Helper to spawn a crumbling ancient studded stone column
	local function spawnRuinPillar(pos: Vector3, totalHeight: number, isBroken: boolean?)
		local pillarModel = Instance.new("Model")
		pillarModel.Name = "RuinPillar"

		-- Heavy Base Plinth with Studs
		createStudPart(pillarModel, "Plinth", Vector3.new(4.5, 1.4, 4.5), CFrame.new(pos + Vector3.new(0, 0.7, 0)), stoneDark)

		-- Shaft segments stacked with visible tactile studs
		local segHeight = 3.6
		local segs = math.floor(totalHeight / segHeight)
		for s = 1, segs do
			local segY = 1.4 + ((s - 0.5) * segHeight)
			local col = if s % 2 == 0 then stoneMid else stoneMoss
			createStudPart(pillarModel, "ShaftSeg", Vector3.new(3.2, segHeight, 3.2), CFrame.new(pos + Vector3.new(0, segY, 0)), col)
		end

		if not isBroken then
			-- Heavy Carved Capital
			local capY = 1.4 + (segs * segHeight) + 0.8
			createStudPart(pillarModel, "Capital", Vector3.new(4.6, 1.6, 4.6), CFrame.new(pos + Vector3.new(0, capY, 0)), stoneDark)
		else
			-- Toppled fallen block resting beside the ruined column
			local fallenY = 1.2
			createStudPart(
				pillarModel,
				"FallenBlock",
				Vector3.new(3.2, 3.6, 3.2),
				CFrame.new(pos + Vector3.new(3.4, fallenY, 1.4)) * CFrame.Angles(math.rad(18), math.rad(35), math.rad(82)),
				stoneDark
			)
		end

		pillarModel.Parent = ruinsFolder
	end

	-- Gateway pillars strictly framing the Avenue portals (No overlap with town buildings!)
	local avenueGatePillars = {
		-- North Avenue Portal
		{ pos = Vector3.new(-14, 0, -44), h = 16, broken = false },
		{ pos = Vector3.new(14, 0, -44), h = 16, broken = false },
		-- South Avenue Portal
		{ pos = Vector3.new(-14, 0, 44), h = 16, broken = false },
		{ pos = Vector3.new(14, 0, 44), h = 16, broken = false },

		-- Distant scenic meadow ruins
		{ pos = Vector3.new(-92, 0, -92), h = 14, broken = true },
		{ pos = Vector3.new(92, 0, -92), h = 16, broken = false },
		{ pos = Vector3.new(-92, 0, 92), h = 16, broken = false },
		{ pos = Vector3.new(92, 0, 92), h = 14, broken = true },
	}
	for _, p in ipairs(avenueGatePillars) do
		spawnRuinPillar(p.pos, p.h, p.broken)
	end

	-- Helper to spawn an Ancient Mystical Runestone with glowing glyphs
	local function spawnRunestone(pos: Vector3, runeColor: Color3, runeName: string)
		local runeModel = Instance.new("Model")
		runeModel.Name = "Runestone_" .. runeName

		-- Stepped plinth with studs
		createStudPart(runeModel, "Base", Vector3.new(4.2, 1.0, 4.2), CFrame.new(pos + Vector3.new(0, 0.5, 0)), stoneDark)
		-- Tapered Obelisk Monolith with Studs
		createStudPart(runeModel, "ObeliskLower", Vector3.new(2.8, 6.0, 2.8), CFrame.new(pos + Vector3.new(0, 4.0, 0)), Color3.fromRGB(32, 34, 40))
		createStudPart(runeModel, "ObeliskUpper", Vector3.new(2.0, 5.0, 2.0), CFrame.new(pos + Vector3.new(0, 9.5, 0)), Color3.fromRGB(36, 38, 45))
		createStudPart(runeModel, "ObeliskTip", Vector3.new(1.2, 2.0, 1.2), CFrame.new(pos + Vector3.new(0, 13.0, 0)), Color3.fromRGB(42, 45, 52))

		-- Glowing Mystic Rune Inlay Bars on 4 faces
		local runeOffsets = {
			Vector3.new(0, 6.5, 1.45),
			Vector3.new(0, 6.5, -1.45),
			Vector3.new(1.45, 6.5, 0),
			Vector3.new(-1.45, 6.5, 0),
		}
		for _, rOff in ipairs(runeOffsets) do
			local isZ = math.abs(rOff.Z) > 0.1
			local runeBar = createStudPart(
				runeModel,
				"RuneInlay",
				if isZ then Vector3.new(1.2, 3.6, 0.2) else Vector3.new(0.2, 3.6, 1.2),
				CFrame.new(pos + rOff),
				runeColor
			)
			runeBar.Material = Enum.Material.Neon
		end

		-- Ambient Rune Light
		local lightPart = runeModel:FindFirstChild("ObeliskUpper") :: Part?
		if lightPart then
			local rLight = Instance.new("PointLight")
			rLight.Color = runeColor
			rLight.Brightness = 1.4
			rLight.Range = 16
			rLight.Parent = lightPart
		end

		runeModel.Parent = ruinsFolder
	end

	-- Runestones placed along the avenues away from all buildings
	spawnRunestone(Vector3.new(0, 0, -60), runeCyan, "NorthAvenue")
	spawnRunestone(Vector3.new(0, 0, 60), runeCyan, "SouthAvenue")
	spawnRunestone(Vector3.new(-75, 0, 0), runePurple, "FarWest")
	spawnRunestone(Vector3.new(75, 0, 0), runePurple, "FarEast")

	-- Northern gateway pillars (Zone 2 Magma approach)
	spawnRuinPillar(Vector3.new(-18, 0, -132), 16, false)
	spawnRuinPillar(Vector3.new(18, 0, -132), 16, false)
end

-- 8. Atmospheric Lighting & Post-Processing Setup (High Visibility Roguelike Mist & Dusk)
function MapService.setupAtmosphere()
	-- Configure Lighting for Clear, High-Visibility Atmospheric Roguelike Mood
	Lighting.ClockTime = 17.5 -- Atmospheric late afternoon / dusk golden-slate hour
	Lighting.Brightness = 2.4 -- Crisp, bright primary sunlight
	Lighting.Ambient = Color3.fromRGB(115, 120, 135) -- Soft cool slate-blue shadows (no pitch-black voids!)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 155) -- Bright, clearly visible terrain and paths
	Lighting.FogStart = 120 -- High clarity across the central plaza, paths, and mining fields
	Lighting.FogEnd = 420 -- Soft pale silver-slate mist gently blanketing the distant mountain ridges
	Lighting.FogColor = Color3.fromRGB(155, 168, 185) -- Pale silver-slate mountain mist
	Lighting.GlobalShadows = true

	-- Clear out existing post-processing and sky instances
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	-- 1. Roguelike Mystical Atmosphere (Translucent mist with soft horizon scattering)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(175, 188, 205)
	atmosphere.Decay = Color3.fromRGB(120, 135, 155)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.8
	atmosphere.Parent = Lighting

	-- 2. Bloom Effect (causes neon crystals, torch flames, and magic runes to radiate softly)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 18
	bloom.Threshold = 1.15
	bloom.Parent = Lighting

	-- 3. ColorCorrection (rich roguelike contrasts while preserving vibrant colors)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.06
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 255, 255)
	cc.Parent = Lighting

	-- 4. SunRays (celestial rays filtering through mountain peaks)
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.15
	sunRays.Spread = 0.75
	sunRays.Parent = Lighting

	-- 5. Dynamic Torchlight Dancing Flicker Loop
	task.spawn(function()
		while true do
			task.wait(0.08)
			for _, pLight in ipairs(brazierLights) do
				if pLight and pLight.Parent then
					-- Subtle organic jitter in torch brightness and range
					local jitter = (math.random() - 0.5) * 0.35
					pLight.Brightness = math.clamp(2.2 + jitter, 1.8, 2.6)
					pLight.Range = math.clamp(32 + (jitter * 4), 28, 36)
				end
			end
		end
	end)
end

---- 9. The Blacksmith Forge (Barnaby the Equipment Merchant)
function MapService.buildShopStall(folder: Folder)
	TownBuildingBuilder.buildBlacksmith(folder)
end

-- 10. The Pet Hatchery Sanctuary (Prism Egg Shrine & Exclusive Robux King Egg Shrine)
function MapService.buildEggStand(folder: Folder)
	TownBuildingBuilder.buildPetSanctuary(folder)
end

-- 11. Exclusive Robux Egg Shrine (Already integrated inside buildPetSanctuary)
function MapService.buildRobuxEggStand(folder: Folder)
	-- Built as part of The Pet Hatchery Sanctuary in buildEggStand
end

-- 12. The Royal VIP Pavilion & Treasury (VIP Throne & Dev Cheat Pad)
function MapService.buildVIPThrone(folder: Folder)
	TownBuildingBuilder.buildVIPPavilion(folder)
end

-- 12b. The Alchemical Fusion Laboratory (Pet Fusion Machine)
function MapService.buildPetFusionMachine(folder: Folder)
	TownBuildingBuilder.buildFusionLab(folder)
end

-- 13. Grand Magma Gate to Zone 2 (At Z = -140, requiring 5 Rebirths)
function MapService.buildMagmaGate(folder: Folder)
	local gateModel = Instance.new("Model")
	gateModel.Name = "MagmaGate"

	local gateZ = -140
	local basaltDark = Color3.fromRGB(28, 22, 24)
	local basaltTrim = Color3.fromRGB(48, 36, 38)
	local magmaGlow = Color3.fromRGB(255, 65, 10)
	local magmaGold = Color3.fromRGB(255, 180, 20)

	-- Flanking Grand Gate Pillars (X = -16 and X = 16)
	createStudPart(gateModel, "GatePillarL", Vector3.new(8, 30, 8), CFrame.new(-16, 15, gateZ), basaltDark)
	createStudPart(gateModel, "GatePillarR", Vector3.new(8, 30, 8), CFrame.new(16, 15, gateZ), basaltDark)
	createStudPart(gateModel, "PillarCapL", Vector3.new(10, 2.5, 10), CFrame.new(-16, 31.25, gateZ), basaltTrim)
	createStudPart(gateModel, "PillarCapR", Vector3.new(10, 2.5, 10), CFrame.new(16, 31.25, gateZ), basaltTrim)

	-- Spiked Horn Finials on Gate Towers
	for s = -1, 1 do
		createStudPart(gateModel, "SpikeL", Vector3.new(1.8, 3.5, 1.8), CFrame.new(-16 + (s * 3.2), 34, gateZ), basaltDark)
		createStudPart(gateModel, "SpikeR", Vector3.new(1.8, 3.5, 1.8), CFrame.new(16 + (s * 3.2), 34, gateZ), basaltDark)
	end

	-- Tower Fire Braziers on top
	createDungeonBrazier(gateModel, "TowerBrazierL", CFrame.new(-16, 32.5, gateZ))
	createDungeonBrazier(gateModel, "TowerBrazierR", CFrame.new(16, 32.5, gateZ))

	-- Grand Overhead Basalt Arch Lintel
	createStudPart(gateModel, "GateArchBase", Vector3.new(40, 6, 8), CFrame.new(0, 28, gateZ), basaltDark)
	local archGlow = createStudPart(gateModel, "GateArchVein", Vector3.new(32, 1.2, 8.2), CFrame.new(0, 28, gateZ), magmaGlow)
	archGlow.Material = Enum.Material.Neon

	-- Overhead Stone Keystone Plaque
	local plaque = createStudPart(gateModel, "GatePlaque", Vector3.new(28, 4.5, 1.6), CFrame.new(0, 34, gateZ + 4.1), basaltDark)
	local plaqueGui = Instance.new("BillboardGui")
	plaqueGui.Name = "MagmaGatePlaqueGui"
	plaqueGui.Size = UDim2.new(0, 360, 0, 70)
	plaqueGui.StudsOffset = Vector3.new(0, 0.5, 1)
	plaqueGui.AlwaysOnTop = false
	plaqueGui.MaxDistance = 85

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🔥 ZONE 2: MAGMA CAVERNS 🔥"
	titleLabel.TextColor3 = magmaGold
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.15
	titleLabel.Parent = plaqueGui

	local reqLabel = Instance.new("TextLabel")
	reqLabel.Size = UDim2.new(1, 0, 0.45, 0)
	reqLabel.Position = UDim2.new(0, 0, 0.55, 0)
	reqLabel.BackgroundTransparency = 1
	reqLabel.Text = "🔒 Requires 5 Rebirths to Enter"
	reqLabel.TextColor3 = Color3.fromRGB(255, 110, 80)
	reqLabel.Font = Enum.Font.GothamBold
	reqLabel.TextSize = 14
	reqLabel.TextStrokeTransparency = 0.2
	reqLabel.Parent = plaqueGui
	plaqueGui.Parent = plaque

	-- PHYSICAL GATEKEEPING BARRIER PART (Toggled client-side based on Rebirths)
	local barrier = Instance.new("Part")
	barrier.Name = "MagmaGateBarrier"
	barrier.Size = Vector3.new(24, 25, 2.5)
	barrier.CFrame = CFrame.new(0, 12.5, gateZ)
	barrier.Color = magmaGlow
	barrier.Material = Enum.Material.ForceField
	barrier.Transparency = 0.35
	barrier.Anchored = true
	barrier.CanCollide = true -- Server default safe, ZoneClient sets to false if Rebirths >= 5
	barrier.CanTouch = true
	barrier.TopSurface = Enum.SurfaceType.Smooth
	barrier.BottomSurface = Enum.SurfaceType.Smooth

	local barrierAttach = Instance.new("Attachment")
	barrierAttach.Parent = barrier

	local barrierSparks = Instance.new("ParticleEmitter")
	barrierSparks.Name = "GateSparks"
	barrierSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 0)),
	})
	barrierSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	barrierSparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	barrierSparks.LightEmission = 0.95
	barrierSparks.Lifetime = NumberRange.new(1.0, 2.0)
	barrierSparks.Rate = 16
	barrierSparks.Speed = NumberRange.new(3, 7)
	barrierSparks.SpreadAngle = Vector2.new(15, 15)
	barrierSparks.Acceleration = Vector3.new(0, 5, 0)
	barrierSparks.Parent = barrierAttach

	local barrierLight = Instance.new("PointLight")
	barrierLight.Color = magmaGlow
	barrierLight.Brightness = 2.4
	barrierLight.Range = 26
	barrierLight.Parent = barrier

	barrier.Parent = gateModel

	-- Flanking Ground Torches
	createDungeonBrazier(gateModel, "PathBrazierL", CFrame.new(-10, 0, gateZ + 6))
	createDungeonBrazier(gateModel, "PathBrazierR", CFrame.new(10, 0, gateZ + 6))

	-- Stone Threshold Road through the gate
	createStudPart(gateModel, "GateThreshold", Vector3.new(18, 0.4, 16), CFrame.new(0, 0.2, gateZ), Color3.fromRGB(60, 50, 52))

	gateModel.Parent = folder
end

-- 14. Zone 2: Magma Caverns Terrain, Molten Lava Rivers, Basalt Spire Columns, and Boundary Mountains
function MapService.buildZone2Terrain(folder: Folder)
	local zone2Folder = Instance.new("Folder")
	zone2Folder.Name = "Zone2_MagmaCaverns"
	zone2Folder.Parent = folder

	local basaltFloor = Color3.fromRGB(32, 26, 28)
	local basaltWall = Color3.fromRGB(40, 32, 36)
	local basaltPeak = Color3.fromRGB(56, 44, 48)
	local lavaColor = Color3.fromRGB(255, 65, 10)
	local basaltTrim = Color3.fromRGB(48, 36, 38)

	-- 1. Main Volcanic Basalt Base Ground (Y = -5 to 0.2, covers Z = -138 to -300)
	createStudPart(
		zone2Folder,
		"BasaltGround",
		Vector3.new(245, 10.2, 162),
		CFrame.new(0, -4.9, -219),
		basaltFloor
	)

	-- 2. Massive Dividing Wall Cliffs at Z = -140 (Connecting the Outer Mountains to Magma Gate)
	-- West Wall: X = -210 to -16 (Width 194)
	createStudPart(zone2Folder, "DividingCliffWest", Vector3.new(194, 28, 18), CFrame.new(-113, 14, -140), basaltWall)
	-- East Wall: X = 16 to 210 (Width 194)
	createStudPart(zone2Folder, "DividingCliffEast", Vector3.new(194, 28, 18), CFrame.new(113, 14, -140), basaltWall)

	-- Jagged peaks on top of the dividing walls
	for i = 1, 6 do
		local xW = -28 - (i * 26)
		local xE = 28 + (i * 26)
		local h = 10 + ((i * 5) % 12)
		createStudPart(zone2Folder, "CliffPeakW_" .. i, Vector3.new(20, h, 14), CFrame.new(xW, 28 + (h / 2), -140), basaltPeak)
		createStudPart(zone2Folder, "CliffPeakE_" .. i, Vector3.new(20, h, 14), CFrame.new(xE, 28 + (h / 2), -140), basaltPeak)
	end

	-- 3. Perimeter Mountain Ridges Enclosing Zone 2
	local function createMagmaRidge(startX: number, endX: number, startZ: number, endZ: number, isZAxis: boolean)
		local count = 6
		for i = 1, count do
			local alpha = (i - 0.5) / count
			local cx = startX + (endX - startX) * alpha
			local cz = startZ + (endZ - startZ) * alpha

			createStudPart(
				zone2Folder,
				"MagmaRockBase",
				if isZAxis then Vector3.new(40, 22, 45) else Vector3.new(45, 22, 40),
				CFrame.new(cx, 11, cz),
				basaltWall
			)

			local midOffset = if i % 2 == 0 then 4 else -4
			createStudPart(
				zone2Folder,
				"MagmaRockMid",
				if isZAxis then Vector3.new(30, 26, 36) else Vector3.new(36, 26, 30),
				CFrame.new(cx + (if isZAxis then midOffset else 0), 24, cz + (if not isZAxis then midOffset else 0)),
				basaltPeak
			)
		end
	end

	-- North Wall of Magma Caverns at Z = -298
	createMagmaRidge(-120, 120, -298, -298, false)
	-- West Wall of Magma Caverns at X = -120 (Z = -140 to -298)
	createMagmaRidge(-120, -120, -140, -298, true)
	-- East Wall of Magma Caverns at X = 120 (Z = -140 to -298)
	createMagmaRidge(120, 120, -140, -298, true)

	-- Magma Corner Bastions
	createStudPart(zone2Folder, "MagmaCornerL", Vector3.new(45, 55, 45), CFrame.new(-120, 27.5, -298), basaltWall)
	createStudPart(zone2Folder, "MagmaCornerR", Vector3.new(45, 55, 45), CFrame.new(120, 27.5, -298), basaltWall)

	-- 4. Molten Lava River Channels with Heat Glow
	local lavaChannels = {
		{ name = "LavaWest", size = Vector3.new(16, 0.45, 75), pos = Vector3.new(-50, 0.25, -215) },
		{ name = "LavaEast", size = Vector3.new(16, 0.45, 75), pos = Vector3.new(50, 0.25, -215) },
		{ name = "LavaNorthCurve", size = Vector3.new(85, 0.45, 14), pos = Vector3.new(0, 0.25, -255) },
	}

	for _, ch in ipairs(lavaChannels) do
		local lavaPart = createStudPart(zone2Folder, ch.name, ch.size, CFrame.new(ch.pos), lavaColor)
		lavaPart.Material = Enum.Material.Neon
		lavaPart.TopSurface = Enum.SurfaceType.Smooth

		local lLight = Instance.new("PointLight")
		lLight.Color = Color3.fromRGB(255, 80, 10)
		lLight.Brightness = 2.0
		lLight.Range = 22
		lLight.Parent = lavaPart

		local lAttach = Instance.new("Attachment")
		lAttach.Parent = lavaPart

		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "LavaSmoke"
		smoke.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 50, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 25, 25)),
		})
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0),
			NumberSequenceKeypoint.new(0.5, 2.5),
			NumberSequenceKeypoint.new(1, 4.0),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Lifetime = NumberRange.new(1.5, 2.8)
		smoke.Rate = 10
		smoke.Speed = NumberRange.new(2, 4.5)
		smoke.SpreadAngle = Vector2.new(20, 20)
		smoke.Acceleration = Vector3.new(0, 3, 0)
		smoke.LightEmission = 0.7
		smoke.Parent = lAttach
	end

	-- Basalt Bridges over Lava Channels (for smooth navigation)
	createStudPart(zone2Folder, "BasaltBridgeW", Vector3.new(22, 0.6, 12), CFrame.new(-50, 0.45, -215), basaltTrim)
	createStudPart(zone2Folder, "BasaltBridgeE", Vector3.new(22, 0.6, 12), CFrame.new(50, 0.45, -215), basaltTrim)

	-- 5. Central Basalt Avenue leading from Gate (Z = -140) to Magma Egg (Z = -210)
	createStudPart(zone2Folder, "MagmaAvenue", Vector3.new(12, 0.35, 68), CFrame.new(0, 0.25, -175), Color3.fromRGB(45, 38, 42))

	-- Avenue Dungeon Braziers lighting the way
	createDungeonBrazier(zone2Folder, "AvenueBrazier_1", CFrame.new(-8, 0.3, -165))
	createDungeonBrazier(zone2Folder, "AvenueBrazier_2", CFrame.new(8, 0.3, -165))
	createDungeonBrazier(zone2Folder, "AvenueBrazier_3", CFrame.new(-8, 0.3, -190))
	createDungeonBrazier(zone2Folder, "AvenueBrazier_4", CFrame.new(8, 0.3, -190))

	-- 6. Hexagonal Basalt Column Formations (Spire clusters)
	local columnSpirePositions = {
		Vector3.new(-75, 0.2, -170),
		Vector3.new(-82, 0.2, -182),
		Vector3.new(-70, 0.2, -260),
		Vector3.new(-80, 0.2, -245),
		Vector3.new(75, 0.2, -170),
		Vector3.new(82, 0.2, -182),
		Vector3.new(70, 0.2, -260),
		Vector3.new(80, 0.2, -245),
	}
	for sIdx, sPos in ipairs(columnSpirePositions) do
		local height = 10 + ((sIdx * 4) % 14)
		local spire = createStudPart(zone2Folder, "BasaltSpire_" .. sIdx, Vector3.new(5.5, height, 5.5), CFrame.new(sPos + Vector3.new(0, height / 2, 0)), basaltWall)
		-- Glowing magma veins on spires
		local vein = createStudPart(zone2Folder, "SpireVein_" .. sIdx, Vector3.new(1.2, height * 0.8, 1.2), CFrame.new(sPos + Vector3.new(0, height / 2, 0)), lavaColor)
		vein.Material = Enum.Material.Neon
		vein.CanCollide = false
	end
end

-- 15. Zone 2: Ancient Magma Egg Hatching Shrine
function MapService.buildMagmaEggStand(folder: Folder)
	local eggShrine = Instance.new("Model")
	eggShrine.Name = "MagmaEggHatchShrine"

	-- Positioned prominently in the heart of Magma Caverns at Z = -210
	local shrineCF = CFrame.new(0, 0.4, -210)

	local obsidian = Color3.fromRGB(22, 18, 20)
	local basaltMid = Color3.fromRGB(42, 34, 36)
	local magmaGold = Color3.fromRGB(255, 170, 20)
	local magmaRed = Color3.fromRGB(255, 60, 10)

	-- 1. Tiered Carved Basalt Pedestal Base
	createStudPart(eggShrine, "MagmaPedestalBase", Vector3.new(7.5, 0.6, 7.5), shrineCF * CFrame.new(0, 0.3, 0), obsidian)
	createStudPart(eggShrine, "MagmaPedestalStep", Vector3.new(6.0, 0.6, 6.0), shrineCF * CFrame.new(0, 0.9, 0), basaltMid)

	-- 2. Carved Central Pillar Column with Studs
	createStudPart(eggShrine, "MagmaPedestalColumn", Vector3.new(3.8, 2.2, 3.8), shrineCF * CFrame.new(0, 2.3, 0), obsidian)

	-- 3. Inscribed Molten Gold Trim Capital
	local capital = createStudPart(eggShrine, "MagmaPedestalCapital", Vector3.new(5.0, 0.6, 5.0), shrineCF * CFrame.new(0, 3.7, 0), magmaGold)
	capital.Material = Enum.Material.SmoothPlastic

	-- 4. Obsidian Nest Bowl
	local bowl = createStudPart(eggShrine, "MagmaNestBowl", Vector3.new(4.4, 0.4, 4.4), shrineCF * CFrame.new(0, 4.1, 0), Color3.fromRGB(18, 14, 16))
	bowl.Material = Enum.Material.SmoothPlastic

	-- 5. Glowing Magma Rune Core Disc beneath egg
	local runeCore = createStudPart(eggShrine, "MagmaRuneCore", Vector3.new(3.2, 0.25, 3.2), shrineCF * CFrame.new(0, 4.35, 0), magmaRed)
	runeCore.Material = Enum.Material.Neon

	-- 6. 3D Physical Magma Egg
	local eggPart = Instance.new("Part")
	eggPart.Name = "MagmaEggPart"
	eggPart.Size = Vector3.new(2.6, 3.6, 2.6)
	eggPart.CFrame = shrineCF * CFrame.new(0, 6.0, 0)
	eggPart.Color = magmaRed
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = true
	eggPart.CanTouch = true
	eggPart.Parent = eggShrine

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	eggMesh.Parent = eggPart

	-- Molten Gold Neon Waist Band
	local eggBand = Instance.new("Part")
	eggBand.Name = "EggWaistBand"
	eggBand.Size = Vector3.new(2.7, 0.38, 2.7)
	eggBand.CFrame = shrineCF * CFrame.new(0, 5.85, 0)
	eggBand.Color = magmaGold
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = eggShrine

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.02, 0.18, 1.02)
	bandMesh.Parent = eggBand

	-- Fiery PointLight radiating from the Magma Egg
	local eggLight = Instance.new("PointLight")
	eggLight.Color = Color3.fromRGB(255, 120, 20)
	eggLight.Brightness = 2.8
	eggLight.Range = 20
	eggLight.Parent = eggPart

	-- Rising Fire Embers Particles
	local eggAttach = Instance.new("Attachment")
	eggAttach.Parent = eggPart

	local eggSparks = Instance.new("ParticleEmitter")
	eggSparks.Name = "MagmaEggSparks"
	eggSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 90, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 20, 0)),
	})
	eggSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	eggSparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	eggSparks.LightEmission = 0.95
	eggSparks.Lifetime = NumberRange.new(1.0, 1.8)
	eggSparks.Rate = 12
	eggSparks.Speed = NumberRange.new(1.2, 3.0)
	eggSparks.SpreadAngle = Vector2.new(30, 30)
	eggSparks.Acceleration = Vector3.new(0, 3.5, 0)
	eggSparks.Parent = eggAttach

	-- Overhead Info Billboard
	local eggGui = Instance.new("BillboardGui")
	eggGui.Name = "MagmaEggTitleGui"
	eggGui.Size = UDim2.new(0, 280, 0, 78)
	eggGui.StudsOffset = Vector3.new(0, 3.6, 0)
	eggGui.AlwaysOnTop = false
	eggGui.MaxDistance = 60

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.38, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🔥 MAGMA EGG 🔥"
	titleLabel.TextColor3 = magmaGold
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = eggGui

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.32, 0)
	costLabel.Position = UDim2.new(0, 0, 0.36, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "[E] 1x (1,500 💎)  •  [F] 3x (4,500 💎)"
	costLabel.TextColor3 = Color3.fromRGB(255, 120, 60)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 13
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = eggGui

	local chancesLabel = Instance.new("TextLabel")
	chancesLabel.Size = UDim2.new(1, 0, 0.28, 0)
	chancesLabel.Position = UDim2.new(0, 0, 0.68, 0)
	chancesLabel.BackgroundTransparency = 1
	chancesLabel.Text = "🐕 Hound 55%  •  🗿 Golem 35%  •  🐉 Drake 10%"
	chancesLabel.TextColor3 = Color3.fromRGB(255, 230, 200)
	chancesLabel.Font = Enum.Font.GothamMedium
	chancesLabel.TextSize = 12
	chancesLabel.TextStrokeTransparency = 0.25
	chancesLabel.Parent = eggGui

	eggGui.Parent = eggPart

	-- Visual rune indicator pads on pedestal step (Magma Red on Left for 1x, Gold on Right for 3x)
	local padLeft = createStudPart(eggShrine, "HatchPad_Magma1x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(-3.0, 0.45, 1.2), magmaRed)
	padLeft.Material = Enum.Material.Neon
	padLeft.CanCollide = false

	local padRight = createStudPart(eggShrine, "HatchPad_Magma3x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(3.0, 0.45, 1.2), magmaGold)
	padRight.Material = Enum.Material.Neon
	padRight.CanCollide = false

	-- Distinct Interaction Parts to place [E] on LEFT and [F] on RIGHT
	local leftPart = Instance.new("Part")
	leftPart.Name = "MagmaEggInteractionPart_Left"
	leftPart.Size = Vector3.new(3.5, 5, 4.5)
	leftPart.CFrame = shrineCF * CFrame.new(-3.0, 3.0, 1.0)
	leftPart.Transparency = 1
	leftPart.CanCollide = false
	leftPart.CanTouch = true
	leftPart.CanQuery = true
	leftPart.Anchored = true
	leftPart.Parent = eggShrine

	local rightPart = Instance.new("Part")
	rightPart.Name = "MagmaEggInteractionPart_Right"
	rightPart.Size = Vector3.new(3.5, 5, 4.5)
	rightPart.CFrame = shrineCF * CFrame.new(3.0, 3.0, 1.0)
	rightPart.Transparency = 1
	rightPart.CanCollide = false
	rightPart.CanTouch = true
	rightPart.CanQuery = true
	rightPart.Anchored = true
	rightPart.Parent = eggShrine

	-- Prompt 1: [E] Hatch 1x
	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "MagmaHatch1Prompt"
	prompt1.ActionText = "Hatch 1x"
	prompt1.ObjectText = "Magma Egg (1,500 💎)"
	prompt1.KeyboardKeyCode = Enum.KeyCode.E
	prompt1.HoldDuration = 0
	prompt1.MaxActivationDistance = 14
	prompt1.RequiresLineOfSight = false
	prompt1.ClickablePrompt = true
	prompt1.UIOffset = Vector2.new(-25, 0)
	prompt1.Parent = leftPart

	-- Prompt 2: [F] Hatch 3x
	local prompt3 = Instance.new("ProximityPrompt")
	prompt3.Name = "MagmaHatch3Prompt"
	prompt3.ActionText = "Hatch 3x"
	prompt3.ObjectText = "Magma Egg (4,500 💎)"
	prompt3.KeyboardKeyCode = Enum.KeyCode.F
	prompt3.HoldDuration = 0
	prompt3.MaxActivationDistance = 14
	prompt3.RequiresLineOfSight = false
	prompt3.ClickablePrompt = true
	prompt3.UIOffset = Vector2.new(25, 0)
	prompt3.Parent = rightPart

	local lastHatchTime: { [Player]: number } = {}
	prompt1.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then
			return
		end
		lastHatchTime[player] = now

		print("🔥 [MapService] ProximityPrompt 1x Magma Egg Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "MagmaEgg", 1)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched Magma 1x: " .. tostring(petIds[1]))
		else
			print("⚠️ [MapService] Magma 1x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	prompt3.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then
			return
		end
		lastHatchTime[player] = now

		print("🔥 [MapService] ProximityPrompt 3x Magma Egg Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "MagmaEgg", 3)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched Magma 3x: " .. table.concat(petIds, ", "))
		else
			print("⚠️ [MapService] Magma 3x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	-- 4 Dungeon Braziers surrounding the Magma Egg Shrine
	createDungeonBrazier(eggShrine, "MagmaBrazier_1", shrineCF * CFrame.new(-6, 0, -6))
	createDungeonBrazier(eggShrine, "MagmaBrazier_2", shrineCF * CFrame.new(6, 0, -6))
	createDungeonBrazier(eggShrine, "MagmaBrazier_3", shrineCF * CFrame.new(-6, 0, 6))
	createDungeonBrazier(eggShrine, "MagmaBrazier_4", shrineCF * CFrame.new(6, 0, 6))

	eggShrine.Parent = folder
end

-- 16. Zone 2: The Infernal Colosseum Boss Arena (At Z = -260)
function MapService.buildBossArena(folder: Folder)
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "BossArena"
	arenaFolder.Parent = folder

	local center = Vector3.new(0, 0.4, -260)
	local darkObsidian = Color3.fromRGB(22, 16, 18)
	local basaltTrim = Color3.fromRGB(42, 32, 36)
	local basaltDark = Color3.fromRGB(32, 24, 28)
	local magmaRed = Color3.fromRGB(255, 60, 10)
	local magmaOrange = Color3.fromRGB(255, 120, 20)
	local goldAccent = Color3.fromRGB(255, 190, 30)

	-- 1. Colossal 3-Tiered Stepped Battle Dais (126 x 126 studs)
	createStudPart(arenaFolder, "ColosseumBasePlinth", Vector3.new(126, 1.2, 126), CFrame.new(center + Vector3.new(0, 0.6, 0)), darkObsidian)
	createStudPart(arenaFolder, "ColosseumMidTier", Vector3.new(112, 0.8, 112), CFrame.new(center + Vector3.new(0, 1.5, 0)), basaltTrim)
	createStudPart(arenaFolder, "ColosseumInnerDais", Vector3.new(98, 0.6, 98), CFrame.new(center + Vector3.new(0, 2.1, 0)), darkObsidian)

	-- Raised Center Boss Pentagram Pad
	createStudPart(arenaFolder, "ArenaBossPad", Vector3.new(48, 0.4, 48), CFrame.new(center + Vector3.new(0, 2.5, 0)), basaltDark)

	-- Glowing Center Boss Spawn Sigil
	local sigil = createStudPart(arenaFolder, "BossSigil", Vector3.new(22, 0.15, 22), CFrame.new(center + Vector3.new(0, 2.75, 0)), goldAccent)
	sigil.Material = Enum.Material.Neon
	sigil.CanCollide = false

	-- Radial Inset Lava Canals (8 glowing molten channels radiating from center)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local canalLength = 46
		local canalPos = center + Vector3.new(math.sin(angle) * (canalLength / 2 + 10), 2.25, math.cos(angle) * (canalLength / 2 + 10))
		local canal = createStudPart(arenaFolder, "LavaCanal_" .. i, Vector3.new(2.8, 0.15, canalLength), CFrame.new(canalPos) * CFrame.Angles(0, angle, 0), magmaRed)
		canal.Material = Enum.Material.Neon
		canal.CanCollide = false
	end

	-- Concentric Circular Molten Rings
	local outerRing = createStudPart(arenaFolder, "LavaRingOuter", Vector3.new(94, 0.15, 94), CFrame.new(center + Vector3.new(0, 2.2, 0)), magmaOrange)
	outerRing.Material = Enum.Material.Neon
	outerRing.CanCollide = false

	local midRing = createStudPart(arenaFolder, "LavaRingMid", Vector3.new(70, 0.15, 70), CFrame.new(center + Vector3.new(0, 2.25, 0)), magmaRed)
	midRing.Material = Enum.Material.Neon
	midRing.CanCollide = false

	-- 2. 8 Colossal Bastion Spire Towers at Arena Perimeter (Radius = 55 studs)
	local towerRadius = 55
	for tIdx = 1, 8 do
		local angle = math.rad((tIdx - 1) * 45)
		local towerPos = center + Vector3.new(math.sin(angle) * towerRadius, 0, math.cos(angle) * towerRadius)

		-- Tower Shaft
		createStudPart(arenaFolder, "BastionPillar_" .. tIdx, Vector3.new(7.5, 26, 7.5), CFrame.new(towerPos + Vector3.new(0, 13, 0)), darkObsidian)
		createStudPart(arenaFolder, "BastionTrim_" .. tIdx, Vector3.new(8.5, 3, 8.5), CFrame.new(towerPos + Vector3.new(0, 25, 0)), basaltTrim)
		createStudPart(arenaFolder, "BastionCap_" .. tIdx, Vector3.new(9.5, 2, 9.5), CFrame.new(towerPos + Vector3.new(0, 27, 0)), basaltDark)

		-- Brazier on top
		createDungeonBrazier(arenaFolder, "BastionBrazier_" .. tIdx, CFrame.new(towerPos + Vector3.new(0, 28.5, 0)))

		-- Glowing Magma Veins on Pillar Sides
		local vein = createStudPart(arenaFolder, "PillarVein_" .. tIdx, Vector3.new(1.4, 20, 1.4), CFrame.new(towerPos + Vector3.new(0, 11, 0)), magmaRed)
		vein.Material = Enum.Material.Neon
		vein.CanCollide = false

		-- Perimeter Wall Segment connecting to next pillar (except at South entrance, angle near 180)
		if tIdx ~= 5 then
			local nextAngle = math.rad(tIdx * 45)
			local nextPos = center + Vector3.new(math.sin(nextAngle) * towerRadius, 0, math.cos(nextAngle) * towerRadius)
			local midP = (towerPos + nextPos) / 2
			local wallLen = (nextPos - towerPos).Magnitude
			local wallAngle = math.atan2(nextPos.X - towerPos.X, nextPos.Z - towerPos.Z)

			local wall = createStudPart(arenaFolder, "PerimeterWall_" .. tIdx, Vector3.new(3.5, 9, wallLen), CFrame.new(midP + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, wallAngle, 0), basaltTrim)
			-- Wall Crenelations / Battlements
			createStudPart(arenaFolder, "WallCrenel_" .. tIdx, Vector3.new(4.2, 1.8, wallLen), CFrame.new(midP + Vector3.new(0, 10.5, 0)) * CFrame.Angles(0, wallAngle, 0), darkObsidian)
		end
	end

	-- 3. Grand Colosseum Triumphal Entrance Gate (Facing South at Z = -202)
	local archZ = -202
	createStudPart(arenaFolder, "ColosseumGateL", Vector3.new(8, 28, 8), CFrame.new(-16, 14, archZ), darkObsidian)
	createStudPart(arenaFolder, "ColosseumGateR", Vector3.new(8, 28, 8), CFrame.new(16, 14, archZ), darkObsidian)
	createStudPart(arenaFolder, "ColosseumGateArch", Vector3.new(40, 5, 8), CFrame.new(0, 27, archZ), basaltTrim)
	createStudPart(arenaFolder, "ColosseumGateCrest", Vector3.new(16, 4, 9), CFrame.new(0, 31, archZ), basaltDark)

	-- Giant Braziers atop Entrance Pillars
	createDungeonBrazier(arenaFolder, "GateBrazierL", CFrame.new(-16, 29, archZ))
	createDungeonBrazier(arenaFolder, "GateBrazierR", CFrame.new(16, 29, archZ))

	-- Arch Glowing Holographic Sign
	local archSign = createStudPart(arenaFolder, "ColosseumSignPart", Vector3.new(34, 4.5, 1.2), CFrame.new(0, 27, archZ + 4.1), darkObsidian)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ArenaSignGui"
	signGui.Size = UDim2.new(0, 420, 0, 75)
	signGui.StudsOffset = Vector3.new(0, 0.4, 0.8)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 110

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔️ THE INFERNAL COLOSSEUM ⚔️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 90, 20)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 21
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = signGui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "[WORLD BOSS • 50,000 HP • VOLCANIC METEORS • 25 DMG]"
	subLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 12.5
	subLabel.TextStrokeTransparency = 0.2
	subLabel.Parent = signGui
	signGui.Parent = archSign

	-- Fiery Access Avenue from Magma Egg (Z = -210) through Gate (Z = -202) into Arena
	createStudPart(arenaFolder, "ColosseumRoad", Vector3.new(14, 0.35, 16), CFrame.new(0, 0.25, -206), Color3.fromRGB(45, 38, 42))
	createDungeonBrazier(arenaFolder, "RoadTorchL", CFrame.new(-9, 0.3, -206))
	createDungeonBrazier(arenaFolder, "RoadTorchR", CFrame.new(9, 0.3, -206))
end

-- Service Initialization
function MapService.init()
	-- Clean up existing map container if it exists
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	print("🗺️ [MapService] Generating Retro Roguelike Stud Environment...")
	brazierLights = {}
	MapService.setupAtmosphere()
	MapService.buildBase(mapFolder)
	MapService.buildMountains(mapFolder)
	MapService.buildPlazaAndPaths(mapFolder)
	MapService.buildShopStall(mapFolder)
	MapService.buildTrailShopStall(mapFolder)
	MapService.buildEggStand(mapFolder)
	MapService.buildRobuxEggStand(mapFolder)
	MapService.buildVIPThrone(mapFolder)
	MapService.buildPetFusionMachine(mapFolder)
	MapService.buildDungeonRuins(mapFolder)
	MapService.buildZone2Terrain(mapFolder)
	MapService.buildMagmaGate(mapFolder)
	MapService.buildMagmaEggStand(mapFolder)
	MapService.buildBossArena(mapFolder)
	MapService.buildTrainingQuarry(mapFolder)
	MapService.buildZone3Terrain(mapFolder)
	MapService.buildCosmicGate(mapFolder)
	MapService.buildCosmicEggStand(mapFolder)
	MapService.buildCosmicBossArena(mapFolder)
	MapService.buildTrees(mapFolder)
	MapService.buildFlora(mapFolder)
	print("✅ [MapService] Retro Roguelike Map Generation Complete! (Zone 1 Meadow, Zone 2 Magma, Quarry & Zone 3 Cosmic Active)")
end

-- 9b. Mystical Trail Artisan Stall & NPC ("Zephyr")
function MapService.buildTrailShopStall(folder: Folder)
	TownBuildingBuilder.buildTrailArtisan(folder)
end

-- 17. The Power Quarry: Rebirth Training Arena with Multiple Scaling Ores
function MapService.buildTrainingQuarry(folder: Folder)
	local quarryFolder = Instance.new("Folder")
	quarryFolder.Name = "TrainingQuarry"
	quarryFolder.Parent = folder

	-- Clean up existing and create TrainingOres folder in Workspace
	local existingOres = Workspace:FindFirstChild("TrainingOres")
	if existingOres then existingOres:Destroy() end

	local trainingOresFolder = Instance.new("Folder")
	trainingOresFolder.Name = "TrainingOres"
	trainingOresFolder.Parent = Workspace

	local center = TrainingConfig.ARENA_CENTER -- Vector3.new(105, 0.4, 0)
	local stoneDark = Color3.fromRGB(36, 40, 48)
	local stoneMid = Color3.fromRGB(54, 60, 72)
	local goldTrim = Color3.fromRGB(255, 215, 60)
	local runeGold = Color3.fromRGB(255, 185, 30)

	-- 1. Connecting Pathway from Path_East (X = 60) to Quarry Arch (X = 72)
	createStudPart(quarryFolder, "QuarryAccessPath", Vector3.new(14, 0.35, 10), CFrame.new(66, 0.2, 0), Color3.fromRGB(80, 85, 95))

	-- 2. Grand Entrance Archway (At X = 72, Z = 0)
	local archX = 72
	createStudPart(quarryFolder, "QuarryPillarL", Vector3.new(5, 20, 5), CFrame.new(archX, 10, -9), stoneDark)
	createStudPart(quarryFolder, "QuarryPillarR", Vector3.new(5, 20, 5), CFrame.new(archX, 10, 9), stoneDark)
	createStudPart(quarryFolder, "QuarryPillarCapL", Vector3.new(6.5, 1.8, 6.5), CFrame.new(archX, 20.5, -9), goldTrim)
	createStudPart(quarryFolder, "QuarryPillarCapR", Vector3.new(6.5, 1.8, 6.5), CFrame.new(archX, 20.5, 9), goldTrim)
	createDungeonBrazier(quarryFolder, "ArchBrazierL", CFrame.new(archX, 21.5, -9))
	createDungeonBrazier(quarryFolder, "ArchBrazierR", CFrame.new(archX, 21.5, 9))

	-- Arch Lintel Beam
	createStudPart(quarryFolder, "QuarryArchBeam", Vector3.new(6, 4, 23), CFrame.new(archX, 19, 0), stoneMid)

	-- Arch Sign
	local archSign = createStudPart(quarryFolder, "QuarryArchSign", Vector3.new(1.2, 4, 20), CFrame.new(archX - 3.1, 19, 0), stoneDark)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "QuarrySignGui"
	signGui.Size = UDim2.new(0, 360, 0, 70)
	signGui.StudsOffset = Vector3.new(-0.8, 0.2, 0)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 80

	local signTitle = Instance.new("TextLabel")
	signTitle.Size = UDim2.new(1, 0, 0.55, 0)
	signTitle.BackgroundTransparency = 1
	signTitle.Text = "⚡ THE POWER QUARRY ⚡"
	signTitle.TextColor3 = Color3.fromRGB(255, 215, 30)
	signTitle.Font = Enum.Font.GothamBlack
	signTitle.TextSize = 20
	signTitle.TextStrokeTransparency = 0.2
	signTitle.Parent = signGui

	local signSub = Instance.new("TextLabel")
	signSub.Size = UDim2.new(1, 0, 0.45, 0)
	signSub.Position = UDim2.new(0, 0, 0.55, 0)
	signSub.BackgroundTransparency = 1
	signSub.Text = "[REBIRTH TRAINING GROUNDS • FACE ORE TO TRAIN]"
	signSub.TextColor3 = Color3.fromRGB(140, 230, 255)
	signSub.Font = Enum.Font.GothamBold
	signSub.TextSize = 12
	signSub.TextStrokeTransparency = 0.2
	signSub.Parent = signGui
	signGui.Parent = archSign

	-- 3. Circular Training Arena Floor
	createStudPart(quarryFolder, "ArenaFloorPlinth", Vector3.new(58, 0.8, 58), CFrame.new(center + Vector3.new(0, 0.4, 0)), stoneDark)
	createStudPart(quarryFolder, "ArenaFloorTierMid", Vector3.new(50, 0.4, 50), CFrame.new(center + Vector3.new(0, 0.8, 0)), stoneMid)

	-- Glowing Center Training Circle
	local runeDisc = createStudPart(quarryFolder, "RuneDisc", Vector3.new(34, 0.2, 34), CFrame.new(center + Vector3.new(0, 1.0, 0)), runeGold)
	runeDisc.Material = Enum.Material.Neon

	local centerCore = createStudPart(quarryFolder, "CenterCorePad", Vector3.new(22, 0.25, 22), CFrame.new(center + Vector3.new(0, 1.15, 0)), stoneDark)

	-- Center Radiant Beacon Light
	local beacon = Instance.new("PointLight")
	beacon.Color = Color3.fromRGB(255, 200, 50)
	beacon.Brightness = 2.4
	beacon.Range = 40
	beacon.Parent = centerCore

	-- 4 Braziers Surrounding the Center Training Circle
	createDungeonBrazier(quarryFolder, "QuarryBrazier_1", CFrame.new(center + Vector3.new(-18, 0.6, -18)))
	createDungeonBrazier(quarryFolder, "QuarryBrazier_2", CFrame.new(center + Vector3.new(-18, 0.6, 18)))
	createDungeonBrazier(quarryFolder, "QuarryBrazier_3", CFrame.new(center + Vector3.new(18, 0.6, -18)))
	createDungeonBrazier(quarryFolder, "QuarryBrazier_4", CFrame.new(center + Vector3.new(18, 0.6, 18)))

	-- 4. Construct the 6 Training Ore Monoliths
	for oreId, oreDef in pairs(TrainingConfig.ORES) do
		local model = Instance.new("Model")
		model.Name = oreId
		model:SetAttribute("IsTrainingOre", true)
		model:SetAttribute("TrainingOreId", oreId)
		model:SetAttribute("RebirthRequired", oreDef.rebirthRequired)

		local scale = oreDef.scale
		local pos = oreDef.position

		-- Tiered Stone Pedestal Base
		local pedBaseSize = Vector3.new(8.0, 1.0, 8.0) * math.clamp(scale, 1.0, 1.4)
		local pedBase = createStudPart(model, "PedestalBase", pedBaseSize, CFrame.new(pos + Vector3.new(0, pedBaseSize.Y / 2, 0)), stoneDark)

		local pedCapSize = Vector3.new(6.5, 0.6, 6.5) * math.clamp(scale, 1.0, 1.4)
		local pedCap = createStudPart(model, "PedestalCap", pedCapSize, CFrame.new(pos + Vector3.new(0, pedBaseSize.Y + pedCapSize.Y / 2, 0)), oreDef.color)
		pedCap.Material = Enum.Material.Neon

		-- Main Multifaceted Boulder Monolith with Multi-Sided Crystal Spire Clusters
		local baseElevation = pos.Y + pedBaseSize.Y + pedCapSize.Y
		local oreData = OreModelBuilder.buildOreModel(
			oreId,
			oreDef.name,
			oreDef.color,
			oreDef.accentColor,
			scale,
			Vector3.new(pos.X, baseElevation, pos.Z)
		)

		local corePart = oreData.corePart
		corePart.Name = "OreCore"
		corePart:SetAttribute("TrainingOreId", oreId)
		model.PrimaryPart = corePart

		-- Move multifaceted boulder parts and crystal spires into model
		for _, child in ipairs(oreData.model:GetChildren()) do
			child.Parent = model
		end

		local coreSize = corePart.Size

		-- Overhead Holographic Billboard
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "OreBillboard"
		billboard.Size = UDim2.new(0, 220, 0, 64)
		billboard.StudsOffset = Vector3.new(0, (coreSize.Y / 2) + 2.6, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 55

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "OreTitle"
		titleLabel.Size = UDim2.new(1, 0, 0.45, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = string.format("%s %s", oreDef.icon, oreDef.name:upper())
		titleLabel.TextColor3 = oreDef.accentColor
		titleLabel.Font = Enum.Font.GothamBlack
		titleLabel.TextSize = 15
		titleLabel.TextStrokeTransparency = 0.2
		titleLabel.Parent = billboard

		local yieldLabel = Instance.new("TextLabel")
		yieldLabel.Name = "YieldText"
		yieldLabel.Size = UDim2.new(1, 0, 0.30, 0)
		yieldLabel.Position = UDim2.new(0, 0, 0.42, 0)
		yieldLabel.BackgroundTransparency = 1
		yieldLabel.Text = string.format("+%s ⚡ / Click (+%s/Rebirth)", FormatNumber.formatCompact(oreDef.basePower), FormatNumber.formatCompact(oreDef.powerPerRebirth))
		yieldLabel.TextColor3 = Color3.fromRGB(255, 225, 40)
		yieldLabel.Font = Enum.Font.GothamBold
		yieldLabel.TextSize = 12
		yieldLabel.TextStrokeTransparency = 0.2
		yieldLabel.Parent = billboard

		local reqLabel = Instance.new("TextLabel")
		reqLabel.Name = "ReqText"
		reqLabel.Size = UDim2.new(1, 0, 0.28, 0)
		reqLabel.Position = UDim2.new(0, 0, 0.72, 0)
		reqLabel.BackgroundTransparency = 1
		if oreDef.rebirthRequired == 0 then
			reqLabel.Text = "✓ Ready to Train"
			reqLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
		else
			reqLabel.Text = string.format("🔒 Requires %d Rebirths", oreDef.rebirthRequired)
			reqLabel.TextColor3 = Color3.fromRGB(255, 120, 100)
		end
		reqLabel.Font = Enum.Font.GothamBold
		reqLabel.TextSize = 11
		reqLabel.TextStrokeTransparency = 0.2
		reqLabel.Parent = billboard
		billboard.Parent = corePart

		-- ClickDetector for direct mouse clicking
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 16
		clickDetector.Parent = corePart

		model.Parent = trainingOresFolder

		-- Staggered crystal sprout animation on world build
		OreModelBuilder.animateSprout(oreData.sides, 0.10)
	end

	print("⚡ [MapService] The Power Quarry built successfully with 6 Training Ores!")
end

-- Creates an authentic retro roguelike carved obsidian brazier with ethereal cosmic flame and starlight sparks
local function createCosmicBrazier(parent: Instance, name: string, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name

	local voidObsidian = Color3.fromRGB(22, 18, 34)
	local astralTrim = Color3.fromRGB(46, 36, 68)
	local runePurple = Color3.fromRGB(150, 50, 255)

	-- Step 1: Broad Studded Stone Pedestal Base
	createStudPart(model, "BrazierBase", Vector3.new(3.8, 0.8, 3.8), cf * CFrame.new(0, 0.4, 0), voidObsidian)

	-- Step 2: Carved Column Pillar with Studs
	createStudPart(model, "BrazierPillar", Vector3.new(2.4, 4.0, 2.4), cf * CFrame.new(0, 2.8, 0), astralTrim)

	-- Step 3: Flared Basin Capital
	createStudPart(model, "BrazierCapital", Vector3.new(4.2, 0.8, 4.2), cf * CFrame.new(0, 5.2, 0), voidObsidian)

	-- Step 4: Dark Astral Silver Fire Bowl Rim
	local bowl = createStudPart(model, "AstralBowl", Vector3.new(4.4, 0.6, 4.4), cf * CFrame.new(0, 5.8, 0), Color3.fromRGB(35, 30, 50))
	bowl.Material = Enum.Material.Metal

	-- Step 5: Glowing Rune Core inside bowl
	local coals = createStudPart(model, "GlowingVoidCore", Vector3.new(3.2, 0.4, 3.2), cf * CFrame.new(0, 6.1, 0), runePurple)
	coals.Material = Enum.Material.Neon

	-- Ethereal Violet and Cyan Fire Particle Emitter
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.4, 0)
	attachment.Parent = coals

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "CosmicFire"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 160, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 40, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.LightEmission = 0.9
	fire.LightInfluence = 0
	fire.Lifetime = NumberRange.new(0.8, 1.3)
	fire.Rate = 16
	fire.Speed = NumberRange.new(3.5, 6.0)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.Acceleration = Vector3.new(0, 4, 0)
	fire.Parent = attachment

	-- Rising Glowing Stardust Sparks
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "StardustSparks"
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 255)),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.LightEmission = 1.0
	sparks.Lifetime = NumberRange.new(1.2, 2.2)
	sparks.Rate = 10
	sparks.Speed = NumberRange.new(4.0, 7.5)
	sparks.SpreadAngle = Vector2.new(15, 15)
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Parent = attachment

	-- Cosmic PointLight
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 60, 255)
	light.Brightness = 2.2
	light.Range = 22
	light.Shadows = true
	light.Parent = coals

	table.insert(brazierLights, light)
	model.Parent = parent
	return model
end

-- 17. Zone 3 Gate: Grand Cosmic Void Portal (At Z = 140)
function MapService.buildCosmicGate(folder: Folder)
	local gateModel = Instance.new("Model")
	gateModel.Name = "CosmicGate"

	local gateZ = 140
	local obsidianDark = Color3.fromRGB(18, 14, 28)
	local astralTrim = Color3.fromRGB(44, 34, 66)
	local cosmicPurple = Color3.fromRGB(150, 60, 255)
	local stardustCyan = Color3.fromRGB(0, 230, 255)
	local astralGold = Color3.fromRGB(255, 215, 0)

	-- Flanking Grand Gate Pillars (X = -16 and X = 16)
	createStudPart(gateModel, "GatePillarL", Vector3.new(8, 30, 8), CFrame.new(-16, 15, gateZ), obsidianDark)
	createStudPart(gateModel, "GatePillarR", Vector3.new(8, 30, 8), CFrame.new(16, 15, gateZ), obsidianDark)
	createStudPart(gateModel, "PillarCapL", Vector3.new(10, 2.5, 10), CFrame.new(-16, 31.25, gateZ), astralTrim)
	createStudPart(gateModel, "PillarCapR", Vector3.new(10, 2.5, 10), CFrame.new(16, 31.25, gateZ), astralTrim)

	-- Glowing Astral Rune Insets on Pillars
	local runeL = createStudPart(gateModel, "PillarRuneL", Vector3.new(2, 22, 8.2), CFrame.new(-16, 15, gateZ), cosmicPurple)
	runeL.Material = Enum.Material.Neon
	local runeR = createStudPart(gateModel, "PillarRuneR", Vector3.new(2, 22, 8.2), CFrame.new(16, 15, gateZ), cosmicPurple)
	runeR.Material = Enum.Material.Neon

	-- Spired Celestial Finials on Gate Towers
	for s = -1, 1 do
		local finL = createStudPart(gateModel, "SpireL", Vector3.new(1.8, 4.0, 1.8), CFrame.new(-16 + (s * 3.2), 34, gateZ), obsidianDark)
		local finR = createStudPart(gateModel, "SpireR", Vector3.new(1.8, 4.0, 1.8), CFrame.new(16 + (s * 3.2), 34, gateZ), obsidianDark)
		if s == 0 then
			local orbL = createStudPart(gateModel, "OrbL", Vector3.new(2.2, 2.2, 2.2), CFrame.new(-16, 37, gateZ), stardustCyan)
			orbL.Material = Enum.Material.Neon
			local orbR = createStudPart(gateModel, "OrbR", Vector3.new(2.2, 2.2, 2.2), CFrame.new(16, 37, gateZ), stardustCyan)
			orbR.Material = Enum.Material.Neon
		end
	end

	-- Tower Cosmic Braziers on top
	createCosmicBrazier(gateModel, "TowerBrazierL", CFrame.new(-16, 32.5, gateZ))
	createCosmicBrazier(gateModel, "TowerBrazierR", CFrame.new(16, 32.5, gateZ))

	-- Grand Overhead Obsidian Arch Lintel
	createStudPart(gateModel, "GateArchBase", Vector3.new(40, 6, 8), CFrame.new(0, 28, gateZ), obsidianDark)
	local archGlow = createStudPart(gateModel, "GateArchVein", Vector3.new(32, 1.2, 8.2), CFrame.new(0, 28, gateZ), cosmicPurple)
	archGlow.Material = Enum.Material.Neon

	-- Center Apex Star Crystal
	local apexStar = createStudPart(gateModel, "ApexStar", Vector3.new(4, 4, 4), CFrame.new(0, 32, gateZ) * CFrame.Angles(0, 0, math.rad(45)), stardustCyan)
	apexStar.Material = Enum.Material.Neon

	-- Overhead Stone Keystone Plaque (Facing North toward approaching player at Z < 140)
	local plaque = createStudPart(gateModel, "GatePlaque", Vector3.new(28, 4.5, 1.6), CFrame.new(0, 34, gateZ - 4.1), obsidianDark)
	local plaqueGui = Instance.new("BillboardGui")
	plaqueGui.Name = "CosmicGatePlaqueGui"
	plaqueGui.Size = UDim2.new(0, 360, 0, 70)
	plaqueGui.StudsOffset = Vector3.new(0, 0.5, -1)
	plaqueGui.AlwaysOnTop = false
	plaqueGui.MaxDistance = 85

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🌌 ZONE 3: THE COSMIC VOID 🌌"
	titleLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.15
	titleLabel.Parent = plaqueGui

	local reqLabel = Instance.new("TextLabel")
	reqLabel.Size = UDim2.new(1, 0, 0.45, 0)
	reqLabel.Position = UDim2.new(0, 0, 0.55, 0)
	reqLabel.BackgroundTransparency = 1
	reqLabel.Text = "🔒 Requires 10 Rebirths to Enter"
	reqLabel.TextColor3 = Color3.fromRGB(255, 100, 140)
	reqLabel.Font = Enum.Font.GothamBold
	reqLabel.TextSize = 14
	reqLabel.TextStrokeTransparency = 0.2
	reqLabel.Parent = plaqueGui
	plaqueGui.Parent = plaque

	-- PHYSICAL GATEKEEPING BARRIER PART (Toggled client-side based on Rebirths >= 10)
	local barrier = Instance.new("Part")
	barrier.Name = "CosmicGateBarrier"
	barrier.Size = Vector3.new(24, 25, 2.5)
	barrier.CFrame = CFrame.new(0, 12.5, gateZ)
	barrier.Color = cosmicPurple
	barrier.Material = Enum.Material.ForceField
	barrier.Transparency = 0.35
	barrier.Anchored = true
	barrier.CanCollide = true -- Server default safe, ZoneClient sets to false if Rebirths >= 10
	barrier.CanTouch = true
	barrier.CastShadow = false
	barrier.Parent = gateModel

	-- Swirling Stardust Particle Veil on the barrier
	local barrierAttach = Instance.new("Attachment")
	barrierAttach.Parent = barrier

	local barrierDust = Instance.new("ParticleEmitter")
	barrierDust.Name = "BarrierStardust"
	barrierDust.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 240, 255)),
	})
	barrierDust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1.2),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	barrierDust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	barrierDust.Lifetime = NumberRange.new(1.5, 2.5)
	barrierDust.Rate = 24
	barrierDust.Speed = NumberRange.new(1.0, 3.0)
	barrierDust.SpreadAngle = Vector2.new(45, 45)
	barrierDust.LightEmission = 0.95
	barrierDust.Parent = barrierAttach

	gateModel.Parent = folder
end

-- 18. Zone 3: The Cosmic Void Terrain, Stardust Rivers, and Floating Asteroids
function MapService.buildZone3Terrain(folder: Folder)
	local zone3Folder = Instance.new("Folder")
	zone3Folder.Name = "Zone3_CosmicVoid"
	zone3Folder.Parent = folder

	local voidObsidian = Color3.fromRGB(16, 14, 28)
	local voidWall = Color3.fromRGB(28, 22, 42)
	local voidPeak = Color3.fromRGB(44, 34, 62)
	local nebulaCyan = Color3.fromRGB(0, 215, 255)
	local nebulaMagenta = Color3.fromRGB(210, 45, 225)
	local astralTrim = Color3.fromRGB(38, 30, 56)

	-- 1. Main Cosmic Obsidian Base Ground (Y = -5 to 0.2, covers Z = 138 to 300)
	createStudPart(
		zone3Folder,
		"CosmicGround",
		Vector3.new(245, 10.2, 162),
		CFrame.new(0, -4.9, 219),
		voidObsidian
	)

	-- 2. Massive Dividing Wall Cliffs at Z = 140 (Connecting Outer Mountains to Cosmic Gate)
	-- West Wall: X = -210 to -16 (Width 194)
	createStudPart(zone3Folder, "DividingCliffWest3", Vector3.new(194, 28, 18), CFrame.new(-113, 14, 140), voidWall)
	-- East Wall: X = 16 to 210 (Width 194)
	createStudPart(zone3Folder, "DividingCliffEast3", Vector3.new(194, 28, 18), CFrame.new(113, 14, 140), voidWall)

	-- Jagged crystal peaks on top of the dividing walls
	for i = 1, 6 do
		local xW = -28 - (i * 26)
		local xE = 28 + (i * 26)
		local h = 10 + ((i * 5) % 12)
		createStudPart(zone3Folder, "CosmicCliffPeakW_" .. i, Vector3.new(20, h, 14), CFrame.new(xW, 28 + (h / 2), 140), voidPeak)
		createStudPart(zone3Folder, "CosmicCliffPeakE_" .. i, Vector3.new(20, h, 14), CFrame.new(xE, 28 + (h / 2), 140), voidPeak)
	end

	-- 3. Perimeter Mountain Ridges Enclosing Zone 3
	local function createCosmicRidge(startX: number, endX: number, startZ: number, endZ: number, isZAxis: boolean)
		local count = 6
		for i = 1, count do
			local alpha = (i - 0.5) / count
			local cx = startX + (endX - startX) * alpha
			local cz = startZ + (endZ - startZ) * alpha

			createStudPart(
				zone3Folder,
				"CosmicRockBase",
				if isZAxis then Vector3.new(40, 22, 45) else Vector3.new(45, 22, 40),
				CFrame.new(cx, 11, cz),
				voidWall
			)

			local midOffset = if i % 2 == 0 then 4 else -4
			createStudPart(
				zone3Folder,
				"CosmicRockMid",
				if isZAxis then Vector3.new(30, 26, 36) else Vector3.new(36, 26, 30),
				CFrame.new(cx + (if isZAxis then midOffset else 0), 24, cz + (if not isZAxis then midOffset else 0)),
				voidPeak
			)
		end
	end

	-- South Wall of Cosmic Void at Z = 298
	createCosmicRidge(-120, 120, 298, 298, false)
	-- West Wall of Cosmic Void at X = -120 (Z = 140 to 298)
	createCosmicRidge(-120, -120, 140, 298, true)
	-- East Wall of Cosmic Void at X = 120 (Z = 140 to 298)
	createCosmicRidge(120, 120, 140, 298, true)

	-- Cosmic Corner Bastions
	createStudPart(zone3Folder, "CosmicCornerL", Vector3.new(45, 55, 45), CFrame.new(-120, 27.5, 298), voidWall)
	createStudPart(zone3Folder, "CosmicCornerR", Vector3.new(45, 55, 45), CFrame.new(120, 27.5, 298), voidWall)

	-- 4. Central Cosmic Avenue leading from Gate (Z = 140) to Cosmic Egg (Z = 210)
	createStudPart(zone3Folder, "CosmicAvenue", Vector3.new(12, 0.35, 68), CFrame.new(0, 0.25, 175), Color3.fromRGB(28, 24, 45))

	-- Avenue Cosmic Braziers lighting the way
	createCosmicBrazier(zone3Folder, "AvenueBrazier_1", CFrame.new(-8, 0.3, 165))
	createCosmicBrazier(zone3Folder, "AvenueBrazier_2", CFrame.new(8, 0.3, 165))
	createCosmicBrazier(zone3Folder, "AvenueBrazier_3", CFrame.new(-8, 0.3, 190))
	createCosmicBrazier(zone3Folder, "AvenueBrazier_4", CFrame.new(8, 0.3, 190))

	-- 5. Luminous Stardust / Nebula Rivers (Glowing channels cut through obsidian ground)
	local riverSegments = {
		{ name = "RiverWest_1", size = Vector3.new(80, 0.3, 10), cf = CFrame.new(-50, 0.15, 185) * CFrame.Angles(0, math.rad(-15), 0), col = nebulaCyan },
		{ name = "RiverWest_2", size = Vector3.new(65, 0.3, 12), cf = CFrame.new(-55, 0.15, 225) * CFrame.Angles(0, math.rad(20), 0), col = nebulaMagenta },
		{ name = "RiverEast_1", size = Vector3.new(80, 0.3, 10), cf = CFrame.new(50, 0.15, 185) * CFrame.Angles(0, math.rad(15), 0), col = nebulaMagenta },
		{ name = "RiverEast_2", size = Vector3.new(65, 0.3, 12), cf = CFrame.new(55, 0.15, 225) * CFrame.Angles(0, math.rad(-20), 0), col = nebulaCyan },
	}

	for _, riv in ipairs(riverSegments) do
		local rPart = createStudPart(zone3Folder, riv.name, riv.size, riv.cf, riv.col)
		rPart.Material = Enum.Material.Neon
		rPart.CanCollide = false

		-- Rising nebula particles
		local rAttach = Instance.new("Attachment")
		rAttach.Position = Vector3.new(0, 0.2, 0)
		rAttach.Parent = rPart

		local mist = Instance.new("ParticleEmitter")
		mist.Name = "NebulaMist"
		mist.Color = ColorSequence.new(riv.col)
		mist.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 3.5),
		})
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		mist.Lifetime = NumberRange.new(2.0, 3.5)
		mist.Rate = 8
		mist.Speed = NumberRange.new(1.0, 2.5)
		mist.SpreadAngle = Vector2.new(25, 25)
		mist.Acceleration = Vector3.new(0, 1.5, 0)
		mist.LightEmission = 0.85
		mist.Parent = rAttach
	end

	-- Astral Bridges over Nebula Channels (for smooth navigation)
	createStudPart(zone3Folder, "AstralBridgeW", Vector3.new(22, 0.6, 12), CFrame.new(-50, 0.45, 215), astralTrim)
	createStudPart(zone3Folder, "AstralBridgeE", Vector3.new(22, 0.6, 12), CFrame.new(50, 0.45, 215), astralTrim)

	-- 6. Hexagonal Obsidian Spire Formations (Crystal Spire Clusters)
	local spirePositions = {
		Vector3.new(-75, 0.2, 170),
		Vector3.new(-82, 0.2, 182),
		Vector3.new(-70, 0.2, 260),
		Vector3.new(-80, 0.2, 245),
		Vector3.new(75, 0.2, 170),
		Vector3.new(82, 0.2, 182),
		Vector3.new(70, 0.2, 260),
		Vector3.new(80, 0.2, 245),
	}
	for sIdx, sPos in ipairs(spirePositions) do
		local height = 12 + ((sIdx * 4) % 16)
		local spire = createStudPart(zone3Folder, "CosmicSpire_" .. sIdx, Vector3.new(5.5, height, 5.5), CFrame.new(sPos + Vector3.new(0, height / 2, 0)), voidWall)
		-- Glowing crystal veins on spires
		local vein = createStudPart(zone3Folder, "SpireVein_" .. sIdx, Vector3.new(1.4, height * 0.85, 1.4), CFrame.new(sPos + Vector3.new(0, height / 2, 0)), if sIdx % 2 == 0 then nebulaCyan else nebulaMagenta)
		vein.Material = Enum.Material.Neon
		vein.CanCollide = false
	end

	-- 7. Floating Asteroid Chunks Hovering Above the Void Floor
	local asteroidConfigs = {
		{ pos = Vector3.new(-45, 26, 170), size = Vector3.new(12, 8, 11), col = voidPeak },
		{ pos = Vector3.new(50, 30, 175), size = Vector3.new(14, 9, 13), col = voidWall },
		{ pos = Vector3.new(-60, 32, 240), size = Vector3.new(15, 10, 14), col = voidPeak },
		{ pos = Vector3.new(55, 28, 245), size = Vector3.new(13, 8, 12), col = voidWall },
		{ pos = Vector3.new(-30, 35, 275), size = Vector3.new(11, 7, 10), col = voidPeak },
		{ pos = Vector3.new(35, 34, 270), size = Vector3.new(12, 8, 11), col = voidWall },
	}
	for aIdx, aConf in ipairs(asteroidConfigs) do
		local rock = createStudPart(zone3Folder, "FloatingAsteroid_" .. aIdx, aConf.size, CFrame.new(aConf.pos) * CFrame.Angles(math.rad(aIdx * 25), math.rad(aIdx * 40), 0), aConf.col)
		-- Embedded glowing starlight crystal on asteroid
		local crystal = createStudPart(zone3Folder, "AsteroidCrystal_" .. aIdx, Vector3.new(2.5, 4.0, 2.5), CFrame.new(aConf.pos + Vector3.new(0, aConf.size.Y * 0.4, 0)), nebulaCyan)
		crystal.Material = Enum.Material.Neon
	end
end

-- 19. Zone 3: Ancient Cosmic Egg Hatching Shrine (At Z = 210)
function MapService.buildCosmicEggStand(folder: Folder)
	local eggShrine = Instance.new("Model")
	eggShrine.Name = "CosmicEggHatchShrine"

	-- Positioned prominently in the heart of The Cosmic Void at Z = 210
	local shrineCF = CFrame.new(0, 0.4, 210)

	local obsidian = Color3.fromRGB(18, 14, 28)
	local astralMid = Color3.fromRGB(40, 30, 62)
	local cosmicGold = Color3.fromRGB(255, 215, 0)
	local astralPurple = Color3.fromRGB(160, 60, 255)
	local stardustCyan = Color3.fromRGB(0, 230, 255)

	-- 1. Tiered Carved Obsidian Pedestal Base
	createStudPart(eggShrine, "CosmicPedestalBase", Vector3.new(8.0, 0.6, 8.0), shrineCF * CFrame.new(0, 0.3, 0), obsidian)
	createStudPart(eggShrine, "CosmicPedestalStep", Vector3.new(6.4, 0.6, 6.4), shrineCF * CFrame.new(0, 0.9, 0), astralMid)

	-- 2. Carved Central Pillar Column with Studs
	createStudPart(eggShrine, "CosmicPedestalColumn", Vector3.new(4.0, 2.2, 4.0), shrineCF * CFrame.new(0, 2.3, 0), obsidian)

	-- 3. Inscribed Celestial Gold Trim Capital
	local capital = createStudPart(eggShrine, "CosmicPedestalCapital", Vector3.new(5.2, 0.6, 5.2), shrineCF * CFrame.new(0, 3.7, 0), cosmicGold)
	capital.Material = Enum.Material.SmoothPlastic

	-- 4. Obsidian Nest Bowl
	local bowl = createStudPart(eggShrine, "CosmicNestBowl", Vector3.new(4.6, 0.4, 4.6), shrineCF * CFrame.new(0, 4.1, 0), Color3.fromRGB(14, 10, 22))
	bowl.Material = Enum.Material.SmoothPlastic

	-- 5. Glowing Astral Rune Core Disc beneath egg
	local runeCore = createStudPart(eggShrine, "CosmicRuneCore", Vector3.new(3.4, 0.25, 3.4), shrineCF * CFrame.new(0, 4.35, 0), astralPurple)
	runeCore.Material = Enum.Material.Neon

	-- 6. 3D Physical Cosmic Egg
	local eggPart = Instance.new("Part")
	eggPart.Name = "CosmicEggPart"
	eggPart.Size = Vector3.new(2.8, 3.8, 2.8)
	eggPart.CFrame = shrineCF * CFrame.new(0, 6.0, 0)
	eggPart.Color = Color3.fromRGB(25, 18, 55)
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = true
	eggPart.CanTouch = true
	eggPart.Parent = eggShrine

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	eggMesh.Parent = eggPart

	-- Luminous Astral Neon Waist Band
	local eggBand = Instance.new("Part")
	eggBand.Name = "CosmicEggWaistBand"
	eggBand.Size = Vector3.new(2.9, 0.4, 2.9)
	eggBand.CFrame = shrineCF * CFrame.new(0, 5.85, 0)
	eggBand.Color = stardustCyan
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = eggShrine

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.03, 0.18, 1.03)
	bandMesh.Parent = eggBand

	-- Celestial PointLight radiating from the Cosmic Egg
	local eggLight = Instance.new("PointLight")
	eggLight.Color = Color3.fromRGB(160, 60, 255)
	eggLight.Brightness = 2.8
	eggLight.Range = 22
	eggLight.Parent = eggPart

	-- Swirling Stardust Particle Emitter
	local eggAttach = Instance.new("Attachment")
	eggAttach.Parent = eggPart

	local eggSparks = Instance.new("ParticleEmitter")
	eggSparks.Name = "CosmicEggSparks"
	eggSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 40, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 255)),
	})
	eggSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	eggSparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	eggSparks.LightEmission = 0.95
	eggSparks.Lifetime = NumberRange.new(1.2, 2.0)
	eggSparks.Rate = 14
	eggSparks.Speed = NumberRange.new(1.2, 3.2)
	eggSparks.SpreadAngle = Vector2.new(30, 30)
	eggSparks.Acceleration = Vector3.new(0, 3.5, 0)
	eggSparks.Parent = eggAttach

	-- Overhead Info Billboard (AlwaysOnTop = false)
	local eggGui = Instance.new("BillboardGui")
	eggGui.Name = "CosmicEggTitleGui"
	eggGui.Size = UDim2.new(0, 300, 0, 78)
	eggGui.StudsOffset = Vector3.new(0, 3.8, 0)
	eggGui.AlwaysOnTop = false
	eggGui.MaxDistance = 65

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.38, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🌌 COSMIC EGG 🌌"
	titleLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = eggGui

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.32, 0)
	costLabel.Position = UDim2.new(0, 0, 0.36, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "[E] 1x (25,000 💎)  •  [F] 3x (75,000 💎)"
	costLabel.TextColor3 = stardustCyan
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 13
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = eggGui

	local chancesLabel = Instance.new("TextLabel")
	chancesLabel.Size = UDim2.new(1, 0, 0.28, 0)
	chancesLabel.Position = UDim2.new(0, 0, 0.68, 0)
	chancesLabel.BackgroundTransparency = 1
	chancesLabel.Text = "🦊 Kitsune 60%  •  🐋 Leviathan 32%  •  🐲 Chronos 8%"
	chancesLabel.TextColor3 = Color3.fromRGB(235, 230, 255)
	chancesLabel.Font = Enum.Font.GothamMedium
	chancesLabel.TextSize = 12
	chancesLabel.TextStrokeTransparency = 0.25
	chancesLabel.Parent = eggGui

	eggGui.Parent = eggPart

	-- Visual rune indicator pads on pedestal step
	local padLeft = createStudPart(eggShrine, "HatchPad_Cosmic1x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(-3.0, 0.45, 1.2), astralPurple)
	padLeft.Material = Enum.Material.Neon
	padLeft.CanCollide = false

	local padRight = createStudPart(eggShrine, "HatchPad_Cosmic3x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(3.0, 0.45, 1.2), stardustCyan)
	padRight.Material = Enum.Material.Neon
	padRight.CanCollide = false

	-- Distinct Interaction Parts to place [E] on LEFT and [F] on RIGHT
	local leftPart = Instance.new("Part")
	leftPart.Name = "CosmicEggInteractionPart_Left"
	leftPart.Size = Vector3.new(3.5, 5, 4.5)
	leftPart.CFrame = shrineCF * CFrame.new(-3.0, 3.0, 1.0)
	leftPart.Transparency = 1
	leftPart.CanCollide = false
	leftPart.CanTouch = true
	leftPart.CanQuery = true
	leftPart.Anchored = true
	leftPart.Parent = eggShrine

	local rightPart = Instance.new("Part")
	rightPart.Name = "CosmicEggInteractionPart_Right"
	rightPart.Size = Vector3.new(3.5, 5, 4.5)
	rightPart.CFrame = shrineCF * CFrame.new(3.0, 3.0, 1.0)
	rightPart.Transparency = 1
	rightPart.CanCollide = false
	rightPart.CanTouch = true
	rightPart.CanQuery = true
	rightPart.Anchored = true
	rightPart.Parent = eggShrine

	-- Prompt 1: [E] Hatch 1x
	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "CosmicHatch1Prompt"
	prompt1.ActionText = "Hatch 1x"
	prompt1.ObjectText = "Cosmic Egg (25,000 💎)"
	prompt1.KeyboardKeyCode = Enum.KeyCode.E
	prompt1.HoldDuration = 0
	prompt1.MaxActivationDistance = 14
	prompt1.RequiresLineOfSight = false
	prompt1.ClickablePrompt = true
	prompt1.UIOffset = Vector2.new(-25, 0)
	prompt1.Parent = leftPart

	-- Prompt 2: [F] Hatch 3x
	local prompt3 = Instance.new("ProximityPrompt")
	prompt3.Name = "CosmicHatch3Prompt"
	prompt3.ActionText = "Hatch 3x"
	prompt3.ObjectText = "Cosmic Egg (75,000 💎)"
	prompt3.KeyboardKeyCode = Enum.KeyCode.F
	prompt3.HoldDuration = 0
	prompt3.MaxActivationDistance = 14
	prompt3.RequiresLineOfSight = false
	prompt3.ClickablePrompt = true
	prompt3.UIOffset = Vector2.new(25, 0)
	prompt3.Parent = rightPart

	local lastHatchTime: { [Player]: number } = {}
	prompt1.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then
			return
		end
		lastHatchTime[player] = now

		print("🌌 [MapService] ProximityPrompt 1x Cosmic Egg Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "CosmicEgg", 1)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched Cosmic 1x: " .. tostring(petIds[1]))
		else
			print("⚠️ [MapService] Cosmic 1x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	prompt3.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then
			return
		end
		lastHatchTime[player] = now

		print("🌌 [MapService] ProximityPrompt 3x Cosmic Egg Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "CosmicEgg", 3)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched Cosmic 3x: " .. table.concat(petIds, ", "))
		else
			print("⚠️ [MapService] Cosmic 3x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	-- 4 Corner Cosmic Braziers around shrine
	createCosmicBrazier(eggShrine, "CosmicBrazier_1", shrineCF * CFrame.new(-6, 0, -6))
	createCosmicBrazier(eggShrine, "CosmicBrazier_2", shrineCF * CFrame.new(6, 0, -6))
	createCosmicBrazier(eggShrine, "CosmicBrazier_3", shrineCF * CFrame.new(-6, 0, 6))
	createCosmicBrazier(eggShrine, "CosmicBrazier_4", shrineCF * CFrame.new(6, 0, 6))

	eggShrine.Parent = folder
end

-- 20. Zone 3: The Astral Citadel Boss Arena (At Z = 260)
function MapService.buildCosmicBossArena(folder: Folder)
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "CosmicBossArena"
	arenaFolder.Parent = folder

	local center = Vector3.new(0, 0.4, 260)
	local darkObsidian = Color3.fromRGB(18, 14, 28)
	local astralTrim = Color3.fromRGB(44, 34, 66)
	local cosmicPurple = Color3.fromRGB(150, 60, 255)
	local stardustCyan = Color3.fromRGB(0, 230, 255)

	-- 1. Main Octagonal/Stepped Battle Dais
	createStudPart(arenaFolder, "ArenaBasePlinth", Vector3.new(64, 0.8, 64), CFrame.new(center + Vector3.new(0, 0.4, 0)), darkObsidian)
	createStudPart(arenaFolder, "ArenaTierMid", Vector3.new(56, 0.5, 56), CFrame.new(center + Vector3.new(0, 0.85, 0)), astralTrim)

	-- Astral Rune Ring Inset
	local runeRing = createStudPart(arenaFolder, "RuneRing", Vector3.new(48, 0.2, 48), CFrame.new(center + Vector3.new(0, 1.1, 0)), cosmicPurple)
	runeRing.Material = Enum.Material.Neon

	-- Raised Center Boss Pentagram Pad
	createStudPart(arenaFolder, "ArenaBossPad", Vector3.new(38, 0.35, 38), CFrame.new(center + Vector3.new(0, 1.25, 0)), darkObsidian)

	-- Glowing Center Boss Spawn Sigil
	local sigil = createStudPart(arenaFolder, "BossSigil", Vector3.new(18, 0.1, 18), CFrame.new(center + Vector3.new(0, 1.45, 0)), stardustCyan)
	sigil.Material = Enum.Material.Neon
	sigil.CanCollide = false

	-- 2. 4 Grand Astral Citadel Towers at Arena Perimeter
	local towerOffsets = {
		Vector3.new(-24, 0, -24),
		Vector3.new(24, 0, -24),
		Vector3.new(-24, 0, 24),
		Vector3.new(24, 0, 24),
	}
	for tIdx, tOff in ipairs(towerOffsets) do
		local towerPos = center + tOff
		createStudPart(arenaFolder, "CitadelPillar_" .. tIdx, Vector3.new(6, 20, 6), CFrame.new(towerPos + Vector3.new(0, 10, 0)), darkObsidian)
		createStudPart(arenaFolder, "CitadelCap_" .. tIdx, Vector3.new(8, 2, 8), CFrame.new(towerPos + Vector3.new(0, 20.5, 0)), astralTrim)
		createCosmicBrazier(arenaFolder, "CitadelBrazier_" .. tIdx, CFrame.new(towerPos + Vector3.new(0, 21.5, 0)))
	end

	-- 3. Entrance Portal Archway (Facing North at Z = 232)
	local archZ = 232
	createStudPart(arenaFolder, "ArenaGatePillarL", Vector3.new(6, 22, 6), CFrame.new(-12, 11, archZ), darkObsidian)
	createStudPart(arenaFolder, "ArenaGatePillarR", Vector3.new(6, 22, 6), CFrame.new(12, 11, archZ), darkObsidian)
	createStudPart(arenaFolder, "ArenaGateArch", Vector3.new(30, 4, 6), CFrame.new(0, 21, archZ), astralTrim)

	-- Arch Glowing Sign (AlwaysOnTop = false)
	local archSign = createStudPart(arenaFolder, "ArenaGateSign", Vector3.new(26, 4, 1.2), CFrame.new(0, 21, archZ - 3.1), darkObsidian)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ArenaSignGui"
	signGui.Size = UDim2.new(0, 360, 0, 65)
	signGui.StudsOffset = Vector3.new(0, 0.4, -0.8)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 85

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔️ THE ASTRAL CITADEL ⚔️"
	titleLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = signGui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "[WORLD BOSS: 250,000 HP • 40 DMG]"
	subLabel.TextColor3 = stardustCyan
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 13
	subLabel.TextStrokeTransparency = 0.2
	subLabel.Parent = signGui
	signGui.Parent = archSign

	-- Road connecting Cosmic Egg (Z = 210) to Arena Gate (Z = 232)
	createStudPart(arenaFolder, "ArenaAccessRoad", Vector3.new(10, 0.35, 22), CFrame.new(0, 0.25, 221), Color3.fromRGB(35, 28, 50))
	createCosmicBrazier(arenaFolder, "RoadBrazierL", CFrame.new(-7, 0.3, 221))
	createCosmicBrazier(arenaFolder, "RoadBrazierR", CFrame.new(7, 0.3, 221))
end

return MapService

