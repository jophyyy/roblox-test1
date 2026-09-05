--!strict
local Workspace = game:GetService("Workspace")

local MapService = {}

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

	-- 4 Perimeter Mountain Walls
	createRidge(-210, 210, -210, -210, false) -- North Wall
	createRidge(-210, 210, 210, 210, false)   -- South Wall
	createRidge(-210, -210, -210, 210, true)  -- West Wall
	createRidge(210, 210, -210, 210, true)    -- East Wall

	-- Corner Bastions (Grand diagonal corner peaks)
	local corners = {
		Vector3.new(-210, 0, -210),
		Vector3.new(210, 0, -210),
		Vector3.new(-210, 0, 210),
		Vector3.new(210, 0, 210),
	}
	for _, corner in ipairs(corners) do
		createStudPart(mountainsFolder, "CornerPeakL", Vector3.new(50, 45, 50), CFrame.new(corner + Vector3.new(0, 22.5, 0)), rockDark)
		createStudPart(mountainsFolder, "CornerPeakH", Vector3.new(32, 60, 32), CFrame.new(corner + Vector3.new(0, 45, 0)), rockLight)
	end
end

-- 3. Central Spawn Plaza & Pathways Connecting to Tycoon Plots
function MapService.buildPlazaAndPaths(folder: Folder)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "PlazaAndPaths"
	pathsFolder.Parent = folder

	local stoneColor = Color3.fromRGB(168, 172, 178)
	local stoneDark = Color3.fromRGB(120, 125, 132)
	local woodColor = Color3.fromRGB(105, 68, 42)
	local lampGlow = Color3.fromRGB(255, 230, 120)

	-- Central Plaza Roundabout resting at Y = 0.2 (top at Y = 0.4)
	createStudPart(pathsFolder, "PlazaCenter", Vector3.new(28, 0.4, 28), CFrame.new(0, 0.2, 0), stoneColor)
	createStudPart(pathsFolder, "PlazaBorder", Vector3.new(32, 0.3, 32), CFrame.new(0, 0.15, 0), stoneDark)

	-- 4 Retro Wooden Lamp Posts on Plaza Corners
	local lampOffsets = {
		Vector3.new(-12, 0, -12),
		Vector3.new(12, 0, -12),
		Vector3.new(-12, 0, 12),
		Vector3.new(12, 0, 12),
	}
	for _, offset in ipairs(lampOffsets) do
		-- Post
		createStudPart(pathsFolder, "LampPost", Vector3.new(1.4, 9, 1.4), CFrame.new(offset + Vector3.new(0, 4.5, 0)), woodColor)
		-- Glowing Lantern Cube with Studs
		local lamp = createStudPart(pathsFolder, "LampLantern", Vector3.new(2.4, 2.4, 2.4), CFrame.new(offset + Vector3.new(0, 9.5, 0)), lampGlow)
		lamp.Material = Enum.Material.Neon
		
		local light = Instance.new("PointLight")
		light.Color = lampGlow
		light.Brightness = 1.2
		light.Range = 22
		light.Parent = lamp
	end

	-- 4 Connecting Pathways Leading from Plaza Directly to Tycoon Plot Entrances
	local pathTargets = {
		{ name = "Path_Plot1", target = Vector3.new(-60, 0.2, -30) },
		{ name = "Path_Plot2", target = Vector3.new(60, 0.2, -30) },
		{ name = "Path_Plot3", target = Vector3.new(-60, 0.2, 30) },
		{ name = "Path_Plot4", target = Vector3.new(60, 0.2, 30) },
	}

	for _, pt in ipairs(pathTargets) do
		local origin = Vector3.new(0, 0.2, 0)
		local diff = pt.target - origin
		local length = diff.Magnitude
		local midpoint = origin + (diff / 2)
		local angle = math.atan2(diff.X, diff.Z)

		createStudPart(
			pathsFolder,
			pt.name,
			Vector3.new(8, 0.35, length),
			CFrame.new(midpoint) * CFrame.Angles(0, angle, 0),
			stoneColor
		)
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

	-- Coordinates chosen to frame the meadow without intruding on tycoon floors or paths
	local treePositions = {
		-- Central meadow clusters (between the paths)
		Vector3.new(0, 0, -50),
		Vector3.new(-8, 0, -68),
		Vector3.new(8, 0, -68),
		Vector3.new(0, 0, 50),
		Vector3.new(-8, 0, 68),
		Vector3.new(8, 0, 68),
		Vector3.new(-50, 0, 0),
		Vector3.new(-68, 0, -8),
		Vector3.new(-68, 0, 8),
		Vector3.new(50, 0, 0),
		Vector3.new(68, 0, -8),
		Vector3.new(68, 0, 8),

		-- Foothill groves along North & South borders
		Vector3.new(-120, 0, -145),
		Vector3.new(-70, 0, -150),
		Vector3.new(-20, 0, -145),
		Vector3.new(30, 0, -150),
		Vector3.new(85, 0, -145),
		Vector3.new(130, 0, -150),

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

	-- Spawn flower meadows and shrub clusters around the spawn plaza and along tree groves
	local clusterCenters = {
		Vector3.new(-18, 0, -18),
		Vector3.new(18, 0, -18),
		Vector3.new(-18, 0, 18),
		Vector3.new(18, 0, 18),
		Vector3.new(-32, 0, -38),
		Vector3.new(32, 0, -38),
		Vector3.new(-32, 0, 38),
		Vector3.new(32, 0, 38),
		Vector3.new(0, 0, -36),
		Vector3.new(0, 0, 36),
		Vector3.new(-36, 0, 0),
		Vector3.new(36, 0, 0),
	}

	for idx, center in ipairs(clusterCenters) do
		-- Bush in center
		spawnBush(center, 0.85 + ((idx % 3) * 0.15))

		-- Ring of 4 flowers around each bush
		local offsets = {
			Vector3.new(-3, 0, -2.5),
			Vector3.new(3.2, 0, -1.8),
			Vector3.new(-2.2, 0, 3.1),
			Vector3.new(2.8, 0, 2.6),
		}
		for fIdx, off in ipairs(offsets) do
			spawnFlower(center + off, idx + fIdx)
		end
	end
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

	print("🗺️ [MapService] Generating Retro Stud-Textured Environment...")
	MapService.buildBase(mapFolder)
	MapService.buildMountains(mapFolder)
	MapService.buildPlazaAndPaths(mapFolder)
	MapService.buildTrees(mapFolder)
	MapService.buildFlora(mapFolder)
	print("✅ [MapService] Retro Map Generation Complete! (All parts anchored with Studs)")
end

return MapService
