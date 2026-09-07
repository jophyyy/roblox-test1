--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local MarketplaceServiceHandler = require(script.Parent.MarketplaceServiceHandler)

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

	-- 3 Perimeter Mountain Walls for Zone 1
	createRidge(-210, 210, 210, 210, false)   -- South Wall
	createRidge(-210, -210, -140, 210, true)  -- West Wall
	createRidge(210, 210, -140, 210, true)    -- East Wall

	-- Corner Bastions (Grand diagonal corner peaks)
	local corners = {
		Vector3.new(-210, 0, -140),
		Vector3.new(210, 0, -140),
		Vector3.new(-210, 0, 210),
		Vector3.new(210, 0, 210),
	}
	for _, corner in ipairs(corners) do
		createStudPart(mountainsFolder, "CornerPeakL", Vector3.new(50, 45, 50), CFrame.new(corner + Vector3.new(0, 22.5, 0)), rockDark)
		createStudPart(mountainsFolder, "CornerPeakH", Vector3.new(32, 60, 32), CFrame.new(corner + Vector3.new(0, 45, 0)), rockLight)
	end
end

-- 3. Central Spawn Plaza & Pathways Connecting to Mining Fields
function MapService.buildPlazaAndPaths(folder: Folder)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "PlazaAndPaths"
	pathsFolder.Parent = folder

	local stoneColor = Color3.fromRGB(85, 90, 98)
	local stoneDark = Color3.fromRGB(52, 56, 64)

	-- Central Plaza Roundabout resting at Y = 0.2 (top at Y = 0.4)
	createStudPart(pathsFolder, "PlazaCenter", Vector3.new(28, 0.4, 28), CFrame.new(0, 0.2, 0), stoneColor)
	createStudPart(pathsFolder, "PlazaBorder", Vector3.new(32, 0.3, 32), CFrame.new(0, 0.15, 0), stoneDark)

	-- 4 Carved Dungeon Stone Braziers at Plaza Corners with Real Fire & Embers
	local brazierOffsets = {
		Vector3.new(-12, 0, -12),
		Vector3.new(12, 0, -12),
		Vector3.new(-12, 0, 12),
		Vector3.new(12, 0, 12),
	}
	for bIdx, offset in ipairs(brazierOffsets) do
		createDungeonBrazier(pathsFolder, "PlazaBrazier_" .. bIdx, CFrame.new(offset))
	end

	-- 4 Main Exploration Pathways Leading from Plaza outward into the Mining Fields
	local pathTargets = {
		{ name = "Path_North", target = Vector3.new(0, 0.2, -140) },
		{ name = "Path_South", target = Vector3.new(0, 0.2, 60) },
		{ name = "Path_West", target = Vector3.new(-60, 0.2, 0) },
		{ name = "Path_East", target = Vector3.new(60, 0.2, 0) },
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
			Vector3.new(10, 0.35, length),
			CFrame.new(midpoint) * CFrame.Angles(0, angle, 0),
			stoneColor
		)
	end

	-- Pathway Dungeon Braziers lighting the way to the exploration zones
	local pathMidBraziers = {
		Vector3.new(0, 0, -35),
		Vector3.new(0, 0, -75),
		Vector3.new(0, 0, -110),
		Vector3.new(0, 0, 35),
		Vector3.new(-35, 0, 0),
		Vector3.new(35, 0, 0),
	}
	for pIdx, pPos in ipairs(pathMidBraziers) do
		createDungeonBrazier(pathsFolder, "PathBrazier_" .. pIdx, CFrame.new(pPos))
	end

	-- GOLDEN DEV CHEAT PAD ON PLAZA (Resting on plaza at Y = 0.5)
	local devPad = Instance.new("Part")
	devPad.Name = "DevCheatPad"
	devPad.Size = Vector3.new(7, 0.6, 7)
	devPad.CFrame = CFrame.new(0, 0.7, 10)
	devPad.Color = Color3.fromRGB(255, 215, 0)
	devPad.Material = Enum.Material.Neon
	devPad.TopSurface = Enum.SurfaceType.Studs
	devPad.BottomSurface = Enum.SurfaceType.Inlet
	devPad.Anchored = true
	devPad.CanCollide = true
	devPad.CanTouch = true
	devPad.Parent = pathsFolder

	local padGui = Instance.new("BillboardGui")
	padGui.Name = "DevPadGui"
	padGui.Size = UDim2.new(0, 240, 0, 60)
	padGui.StudsOffset = Vector3.new(0, 4.0, 0)
	padGui.AlwaysOnTop = false
	padGui.MaxDistance = 45

	local padTitle = Instance.new("TextLabel")
	padTitle.Size = UDim2.new(1, 0, 0.5, 0)
	padTitle.BackgroundTransparency = 1
	padTitle.Text = "⚡ DEV CHEAT PAD ⚡"
	padTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	padTitle.Font = Enum.Font.GothamBlack
	padTitle.TextSize = 16
	padTitle.TextStrokeTransparency = 0.2
	padTitle.Parent = padGui

	local padSubtitle = Instance.new("TextLabel")
	padSubtitle.Size = UDim2.new(1, 0, 0.5, 0)
	padSubtitle.Position = UDim2.new(0, 0, 0.5, 0)
	padSubtitle.BackgroundTransparency = 1
	padSubtitle.Text = "Touch for +$10,000,000 & +50K 💎"
	padSubtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	padSubtitle.Font = Enum.Font.GothamBold
	padSubtitle.TextSize = 13
	padSubtitle.TextStrokeTransparency = 0.2
	padSubtitle.Parent = padGui
	padGui.Parent = devPad

	local lastTouched: { [Player]: number } = {}
	devPad.Touched:Connect(function(hit)
		local char = hit.Parent
		if not char then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			local now = os.clock()
			if not lastTouched[player] or (now - lastTouched[player]) > 1.0 then
				lastTouched[player] = now
				DataService.addCash(player, 10_000_000)
				DataService.addGems(player, 50_000)
				print(string.format("⚡ [DevCheatPad] Granted $10,000,000 and 50,000 Gems to %s!", player.Name))
			end
		end
	end)
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

	-- Coordinates chosen to frame the meadow without intruding on ore fields or paths
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

-- 6. Ancient Crumbling Dungeon Ruins, Mystical Runestones & Northern Dungeon Gate (Studs Design)
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

	-- Pillar groupings around the plaza outskirts and path crossroads
	local pillarLocations = {
		{ pos = Vector3.new(-24, 0, -24), h = 18, broken = false },
		{ pos = Vector3.new(24, 0, -24), h = 14, broken = true },
		{ pos = Vector3.new(-24, 0, 24), h = 14, broken = true },
		{ pos = Vector3.new(24, 0, 24), h = 18, broken = false },

		-- Ancient gateway pillars framing path crossroads
		{ pos = Vector3.new(-32, 0, -6), h = 12, broken = false },
		{ pos = Vector3.new(-32, 0, 6), h = 10, broken = true },
		{ pos = Vector3.new(32, 0, -6), h = 10, broken = true },
		{ pos = Vector3.new(32, 0, 6), h = 12, broken = false },
	}
	for _, p in ipairs(pillarLocations) do
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

	spawnRunestone(Vector3.new(0, 0, -32), runeCyan, "North")
	spawnRunestone(Vector3.new(0, 0, 32), runeCyan, "South")
	spawnRunestone(Vector3.new(-32, 0, 0), runePurple, "West")
	spawnRunestone(Vector3.new(32, 0, 0), runePurple, "East")

	-- Northern gateway pillars
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

-- 9. Merchant Market Stall & Interactive Shopkeeper NPC ("Barnaby")
function MapService.buildShopStall(folder: Folder)
	local stallModel = Instance.new("Model")
	stallModel.Name = "MerchantStall"

	local stallCF = CFrame.new(-13.5, 0.4, 0) * CFrame.Angles(0, math.rad(90), 0)

	local woodDark = Color3.fromRGB(85, 55, 35)
	local woodLight = Color3.fromRGB(115, 75, 45)
	local clothRed = Color3.fromRGB(180, 45, 45)
	local clothCream = Color3.fromRGB(235, 225, 200)

	-- Counter Table (Front desk)
	createStudPart(stallModel, "CounterBase", Vector3.new(8, 2.6, 2.4), stallCF * CFrame.new(0, 1.3, 0), woodDark)
	createStudPart(stallModel, "CounterTop", Vector3.new(9, 0.6, 3.2), stallCF * CFrame.new(0, 2.8, 0), woodLight)

	-- 4 Canopy Support Corner Posts
	local postOffsets = {
		Vector3.new(-3.8, 0, -2.4),
		Vector3.new(3.8, 0, -2.4),
		Vector3.new(-3.8, 0, 1.2),
		Vector3.new(3.8, 0, 1.2),
	}
	for _, pOff in ipairs(postOffsets) do
		createStudPart(stallModel, "Post", Vector3.new(0.8, 8, 0.8), stallCF * CFrame.new(pOff.X, 4.4, pOff.Z), woodDark)
	end

	-- Overhead Striped Canopy Roof (Alternating Red and Cream Slats with Studs)
	for s = -3, 3 do
		local slatCol = if s % 2 == 0 then clothRed else clothCream
		createStudPart(stallModel, "CanopySlat", Vector3.new(1.4, 0.5, 5.0), stallCF * CFrame.new(s * 1.35, 8.4, -0.6) * CFrame.Angles(math.rad(-8), 0, 0), slatCol)
	end

	-- Back display shelf
	createStudPart(stallModel, "BackShelf", Vector3.new(8, 4.5, 1.0), stallCF * CFrame.new(0, 2.25, -2.6), woodDark)

	-- Display props on counter
	local spadeProp = createStudPart(stallModel, "DisplaySpade", Vector3.new(0.5, 1.6, 0.5), stallCF * CFrame.new(-2.6, 3.8, 0) * CFrame.Angles(math.rad(25), 0, math.rad(15)), Color3.fromRGB(0, 210, 255))
	spadeProp.Material = Enum.Material.Neon
	local packProp = createStudPart(stallModel, "DisplayPack", Vector3.new(1.2, 1.4, 0.9), stallCF * CFrame.new(2.6, 3.7, 0), Color3.fromRGB(150, 90, 50))
	packProp.Material = Enum.Material.SmoothPlastic

	-- Hanging Lantern under canopy
	local lantern = createStudPart(stallModel, "StallLantern", Vector3.new(1.0, 1.2, 1.0), stallCF * CFrame.new(0, 7.2, 0.8), Color3.fromRGB(255, 200, 100))
	lantern.Material = Enum.Material.Neon

	local stallLight = Instance.new("PointLight")
	stallLight.Color = Color3.fromRGB(255, 190, 90)
	stallLight.Brightness = 2.0
	stallLight.Range = 20
	stallLight.Parent = lantern

	-- SHOPKEEPER NPC ("Barnaby the Merchant")
	local npcModel = Instance.new("Model")
	npcModel.Name = "BarnabyMerchant"

	local npcCF = stallCF * CFrame.new(0, 1.2, -1.2) -- Standing behind the counter

	-- Torso (Interactive root part for ProximityPrompt)
	local torso = createStudPart(npcModel, "Torso", Vector3.new(2, 2, 1), npcCF * CFrame.new(0, 2.0, 0), Color3.fromRGB(45, 70, 115))

	-- Legs
	createStudPart(npcModel, "LeftLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(-0.5, 0.0, 0), Color3.fromRGB(38, 42, 50))
	createStudPart(npcModel, "RightLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(0.5, 0.0, 0), Color3.fromRGB(38, 42, 50))

	-- Head & Face
	local head = createStudPart(npcModel, "Head", Vector3.new(1.25, 1.25, 1.25), npcCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 215, 175), true, Enum.SurfaceType.Smooth)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Merchant Fedora / Wide-Brimmed Hat
	createStudPart(npcModel, "HatBrim", Vector3.new(2.4, 0.35, 2.4), npcCF * CFrame.new(0, 4.0, 0), Color3.fromRGB(80, 45, 25))
	createStudPart(npcModel, "HatCrown", Vector3.new(1.5, 0.75, 1.5), npcCF * CFrame.new(0, 4.4, 0), Color3.fromRGB(95, 55, 30))

	-- Arms (Resting on counter)
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(45, 70, 115))
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(45, 70, 115))

	-- Overhead Title Billboard
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "MerchantTitleGui"
	titleGui.Size = UDim2.new(0, 200, 0, 50)
	titleGui.StudsOffset = Vector3.new(0, 3.2, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 60

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🛒 BARNABY 🛒"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.Antique
	titleLabel.TextSize = 19
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "[Equipment Merchant]"
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	subtitleLabel.Font = Enum.Font.Antique
	subtitleLabel.TextSize = 14
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- INVISIBLE INTERACTION PART & PROXIMITY PROMPT
	-- Placed right at the front counter facing the player plaza for 100% reliable prompt detection
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "BarnabyInteractionPart"
	interactionPart.Size = Vector3.new(9, 5, 4)
	interactionPart.CFrame = stallCF * CFrame.new(0, 2.8, 1.2)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = stallModel

	-- PROXIMITY PROMPT: "Press E to Talk"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Barnaby (Merchant)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0 -- Instantaneous on tap / press
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		print("🗣️ [MapService] Server ProximityPrompt triggered by " .. player.Name)
		local dialogueEvent = Remotes.getEvent("OpenShopDialogue")
		dialogueEvent:FireClient(player, "Barnaby")
	end)

	npcModel.Parent = stallModel
	stallModel.Parent = folder
end

-- 10. Ancient Pet Egg Hatching Shrine ("Prism Egg")
function MapService.buildEggStand(folder: Folder)
	local eggShrine = Instance.new("Model")
	eggShrine.Name = "EggHatchShrine"

	-- Positioned on the East side of the plaza (Z = 4.5)
	local shrineCF = CFrame.new(13.5, 0.4, 4.5) * CFrame.Angles(0, math.rad(-90), 0)

	local stoneDark = Color3.fromRGB(48, 52, 58)
	local stoneMid = Color3.fromRGB(68, 72, 80)
	local goldAccent = Color3.fromRGB(240, 190, 60)
	local runeCyan = Color3.fromRGB(0, 220, 255)

	-- 1. Tiered Carved Stone Pedestal Base
	createStudPart(eggShrine, "PedestalBase", Vector3.new(7.0, 0.6, 7.0), shrineCF * CFrame.new(0, 0.3, 0), stoneDark)
	createStudPart(eggShrine, "PedestalStep", Vector3.new(5.6, 0.6, 5.6), shrineCF * CFrame.new(0, 0.9, 0), stoneMid)

	-- 2. Carved Central Pillar Column with Studs
	createStudPart(eggShrine, "PedestalColumn", Vector3.new(3.6, 2.2, 3.6), shrineCF * CFrame.new(0, 2.3, 0), stoneDark)

	-- 3. Inscribed Gold Trim Capital
	local capital = createStudPart(eggShrine, "PedestalCapital", Vector3.new(4.8, 0.6, 4.8), shrineCF * CFrame.new(0, 3.7, 0), goldAccent)
	capital.Material = Enum.Material.SmoothPlastic

	-- 4. Dark Obsidian Nest Bowl
	local bowl = createStudPart(eggShrine, "NestBowl", Vector3.new(4.2, 0.4, 4.2), shrineCF * CFrame.new(0, 4.1, 0), Color3.fromRGB(28, 30, 36))
	bowl.Material = Enum.Material.SmoothPlastic

	-- 5. Glowing Cyan Rune Core Disc beneath the egg
	local runeCore = createStudPart(eggShrine, "RuneCore", Vector3.new(3.0, 0.25, 3.0), shrineCF * CFrame.new(0, 4.35, 0), runeCyan)
	runeCore.Material = Enum.Material.Neon

	-- 6. 3D Physical Egg
	local eggPart = Instance.new("Part")
	eggPart.Name = "PrismEggPart"
	eggPart.Size = Vector3.new(2.4, 3.45, 2.4)
	eggPart.CFrame = shrineCF * CFrame.new(0, 5.9, 0)
	eggPart.Color = Color3.fromRGB(245, 248, 255)
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = true
	eggPart.CanTouch = true
	eggPart.Parent = eggShrine

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	eggMesh.Parent = eggPart

	-- Luminous decorative waist band around the egg
	local eggBand = Instance.new("Part")
	eggBand.Name = "EggWaistBand"
	eggBand.Size = Vector3.new(2.5, 0.35, 2.5)
	eggBand.CFrame = shrineCF * CFrame.new(0, 5.75, 0)
	eggBand.Color = runeCyan
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = eggShrine

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.02, 0.18, 1.02)
	bandMesh.Parent = eggBand

	-- PointLight radiating from the egg
	local eggLight = Instance.new("PointLight")
	eggLight.Color = runeCyan
	eggLight.Brightness = 2.2
	eggLight.Range = 16
	eggLight.Parent = eggPart

	-- Soft mystical sparkles
	local eggAttach = Instance.new("Attachment")
	eggAttach.Parent = eggPart

	local eggSparkles = Instance.new("ParticleEmitter")
	eggSparkles.Name = "EggSparkles"
	eggSparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 235, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255)),
	})
	eggSparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	eggSparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	eggSparkles.LightEmission = 0.9
	eggSparkles.Lifetime = NumberRange.new(1.0, 1.8)
	eggSparkles.Rate = 7
	eggSparkles.Speed = NumberRange.new(0.8, 2.0)
	eggSparkles.SpreadAngle = Vector2.new(30, 30)
	eggSparkles.Acceleration = Vector3.new(0, 2.0, 0)
	eggSparkles.Parent = eggAttach

	-- Overhead Info Billboard
	local eggGui = Instance.new("BillboardGui")
	eggGui.Name = "EggTitleGui"
	eggGui.Size = UDim2.new(0, 260, 0, 75)
	eggGui.StudsOffset = Vector3.new(0, 3.4, 0)
	eggGui.AlwaysOnTop = false
	eggGui.MaxDistance = 60

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.38, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "✨ PRISM EGG ✨"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = eggGui

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.32, 0)
	costLabel.Position = UDim2.new(0, 0, 0.36, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "[E] 1x (100 💎)  •  [F] 3x (300 💎)"
	costLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 13
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = eggGui

	local chancesLabel = Instance.new("TextLabel")
	chancesLabel.Size = UDim2.new(1, 0, 0.28, 0)
	chancesLabel.Position = UDim2.new(0, 0, 0.68, 0)
	chancesLabel.BackgroundTransparency = 1
	chancesLabel.Text = "🐶 55%  •  🐱 35%  •  🐰 10%"
	chancesLabel.TextColor3 = Color3.fromRGB(220, 230, 245)
	chancesLabel.Font = Enum.Font.GothamMedium
	chancesLabel.TextSize = 12
	chancesLabel.TextStrokeTransparency = 0.25
	chancesLabel.Parent = eggGui

	eggGui.Parent = eggPart

	-- Visual rune indicator pads on the pedestal step (Cyan for 1x on Left, Gold for 3x on Right)
	local padLeft = createStudPart(eggShrine, "HatchPad_1x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(-3.0, 0.45, 1.2), Color3.fromRGB(0, 200, 255))
	padLeft.Material = Enum.Material.Neon
	padLeft.CanCollide = false

	local padRight = createStudPart(eggShrine, "HatchPad_3x", Vector3.new(2.2, 0.1, 2.2), shrineCF * CFrame.new(3.0, 0.45, 1.2), Color3.fromRGB(255, 215, 0))
	padRight.Material = Enum.Material.Neon
	padRight.CanCollide = false

	-- Distinct Interaction Parts to place [E] on the LEFT and [F] on the RIGHT with zero overlap
	local leftPart = Instance.new("Part")
	leftPart.Name = "EggInteractionPart_Left"
	leftPart.Size = Vector3.new(3.5, 5, 4.5)
	leftPart.CFrame = shrineCF * CFrame.new(-3.0, 3.0, 1.0)
	leftPart.Transparency = 1
	leftPart.CanCollide = false
	leftPart.CanTouch = true
	leftPart.CanQuery = true
	leftPart.Anchored = true
	leftPart.Parent = eggShrine

	local rightPart = Instance.new("Part")
	rightPart.Name = "EggInteractionPart_Right"
	rightPart.Size = Vector3.new(3.5, 5, 4.5)
	rightPart.CFrame = shrineCF * CFrame.new(3.0, 3.0, 1.0)
	rightPart.Transparency = 1
	rightPart.CanCollide = false
	rightPart.CanTouch = true
	rightPart.CanQuery = true
	rightPart.Anchored = true
	rightPart.Parent = eggShrine

	-- Prompt 1: [E] Hatch 1x (Anchored on the LEFT)
	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "Hatch1Prompt"
	prompt1.ActionText = "Hatch 1x"
	prompt1.ObjectText = "Prism Egg (100 💎)"
	prompt1.KeyboardKeyCode = Enum.KeyCode.E
	prompt1.HoldDuration = 0
	prompt1.MaxActivationDistance = 14
	prompt1.RequiresLineOfSight = false
	prompt1.ClickablePrompt = true
	prompt1.UIOffset = Vector2.new(-25, 0)
	prompt1.Parent = leftPart

	-- Prompt 2: [F] Hatch 3x (Anchored on the RIGHT)
	local prompt3 = Instance.new("ProximityPrompt")
	prompt3.Name = "Hatch3Prompt"
	prompt3.ActionText = "Hatch 3x"
	prompt3.ObjectText = "Prism Egg (300 💎)"
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

		print("🥚 [MapService] ProximityPrompt 1x Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "BasicEgg", 1)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched 1x: " .. tostring(petIds[1]))
		else
			print("⚠️ [MapService] 1x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	prompt3.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then
			return
		end
		lastHatchTime[player] = now

		print("🥚 [MapService] ProximityPrompt 3x Hatch triggered by " .. player.Name)
		local ok, petIds, errReason = PetService.hatchEgg(player, "BasicEgg", 3)
		if ok and petIds then
			print("✨ [MapService] " .. player.Name .. " hatched 3x: " .. table.concat(petIds, ", "))
		else
			print("⚠️ [MapService] 3x Hatch failed for " .. player.Name .. ": " .. tostring(errReason))
		end
	end)

	eggShrine.Parent = folder
end

-- 11. Exclusive 1,000 Robux Egg Hatching Shrine ("Exclusive Robux Egg")
function MapService.buildRobuxEggStand(folder: Folder)
	local eggShrine = Instance.new("Model")
	eggShrine.Name = "RobuxEggHatchShrine"

	-- Positioned adjacent on the East side of the plaza (Z = -4.5)
	local shrineCF = CFrame.new(13.5, 0.4, -4.5) * CFrame.Angles(0, math.rad(-90), 0)

	local obsidian = Color3.fromRGB(25, 26, 32)
	local goldMetal = Color3.fromRGB(255, 215, 60)
	local cosmicPurple = Color3.fromRGB(180, 50, 255)

	-- 1. Tiered Gilded Obsidian Pedestal Base
	createStudPart(eggShrine, "RobuxPedestalBase", Vector3.new(7.0, 0.6, 7.0), shrineCF * CFrame.new(0, 0.3, 0), obsidian)
	createStudPart(eggShrine, "RobuxPedestalStep", Vector3.new(5.6, 0.6, 5.6), shrineCF * CFrame.new(0, 0.9, 0), Color3.fromRGB(40, 42, 50))

	-- 2. Carved Central Pillar with Gold Studs
	createStudPart(eggShrine, "RobuxPedestalColumn", Vector3.new(3.6, 2.2, 3.6), shrineCF * CFrame.new(0, 2.3, 0), obsidian)

	-- 3. Solid Gold Capital
	local capital = createStudPart(eggShrine, "RobuxPedestalCapital", Vector3.new(4.8, 0.6, 4.8), shrineCF * CFrame.new(0, 3.7, 0), goldMetal)
	capital.Material = Enum.Material.SmoothPlastic

	-- 4. Obsidian Nest Bowl
	local bowl = createStudPart(eggShrine, "RobuxNestBowl", Vector3.new(4.2, 0.4, 4.2), shrineCF * CFrame.new(0, 4.1, 0), obsidian)
	bowl.Material = Enum.Material.SmoothPlastic

	-- 5. Glowing Cosmic Purple Rune Core Disc
	local runeCore = createStudPart(eggShrine, "RobuxRuneCore", Vector3.new(3.0, 0.25, 3.0), shrineCF * CFrame.new(0, 4.35, 0), cosmicPurple)
	runeCore.Material = Enum.Material.Neon

	-- 6. Gilded 3D Egg
	local eggPart = Instance.new("Part")
	eggPart.Name = "RobuxEggPart"
	eggPart.Size = Vector3.new(2.4, 3.45, 2.4)
	eggPart.CFrame = shrineCF * CFrame.new(0, 5.9, 0)
	eggPart.Color = goldMetal
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = true
	eggPart.CanTouch = true
	eggPart.Parent = eggShrine

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	eggMesh.Parent = eggPart

	-- Cosmic Magenta Neon Waist Band
	local eggBand = Instance.new("Part")
	eggBand.Name = "EggWaistBand"
	eggBand.Size = Vector3.new(2.5, 0.35, 2.5)
	eggBand.CFrame = shrineCF * CFrame.new(0, 5.75, 0)
	eggBand.Color = cosmicPurple
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = eggShrine

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.02, 0.18, 1.02)
	bandMesh.Parent = eggBand

	-- Radiant PointLight
	local eggLight = Instance.new("PointLight")
	eggLight.Color = Color3.fromRGB(255, 220, 80)
	eggLight.Brightness = 2.8
	eggLight.Range = 18
	eggLight.Parent = eggPart

	-- Sparkling Star Particles
	local eggAttach = Instance.new("Attachment")
	eggAttach.Parent = eggPart

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "RobuxSparkles"
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 50, 255)),
	})
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.LightEmission = 0.95
	sparkles.Lifetime = NumberRange.new(1.0, 1.8)
	sparkles.Rate = 10
	sparkles.Speed = NumberRange.new(1.0, 2.5)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.Acceleration = Vector3.new(0, 2.5, 0)
	sparkles.Parent = eggAttach

	-- Overhead Info Billboard
	local eggGui = Instance.new("BillboardGui")
	eggGui.Name = "RobuxEggTitleGui"
	eggGui.Size = UDim2.new(0, 280, 0, 80)
	eggGui.StudsOffset = Vector3.new(0, 3.4, 0)
	eggGui.AlwaysOnTop = false
	eggGui.MaxDistance = 60

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.38, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "👑 EXCLUSIVE EGG 👑"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = eggGui

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.32, 0)
	costLabel.Position = UDim2.new(0, 0, 0.36, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "Cost: 1,000 Robux R$"
	costLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 14
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = eggGui

	local chancesLabel = Instance.new("TextLabel")
	chancesLabel.Size = UDim2.new(1, 0, 0.28, 0)
	chancesLabel.Position = UDim2.new(0, 0, 0.68, 0)
	chancesLabel.BackgroundTransparency = 1
	chancesLabel.Text = "🐰 Bunny 50%  •  🔥 Drake 35%  •  🌌 Phoenix 15%"
	chancesLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	chancesLabel.Font = Enum.Font.GothamMedium
	chancesLabel.TextSize = 11
	chancesLabel.TextStrokeTransparency = 0.25
	chancesLabel.Parent = eggGui

	eggGui.Parent = eggPart

	-- Visual Rune Pad on Pedestal Step
	local pad = createStudPart(eggShrine, "HatchPad_Robux", Vector3.new(3.0, 0.1, 3.0), shrineCF * CFrame.new(0, 0.45, 1.2), Color3.fromRGB(255, 215, 0))
	pad.Material = Enum.Material.Neon
	pad.CanCollide = false

	-- Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "RobuxEggInteractionPart"
	interactionPart.Size = Vector3.new(6, 6, 6)
	interactionPart.CFrame = shrineCF * CFrame.new(0, 3.2, 1.0)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = eggShrine

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RobuxHatchPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = "Exclusive Egg (R$ 1,000)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	local lastHatchTime: { [Player]: number } = {}
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.4 then
			return
		end
		lastHatchTime[player] = now

		print("👑 [MapService] Robux Egg ProximityPrompt triggered by " .. player.Name)
		local openModalEvent = Remotes.getEvent("OpenRobuxPurchaseModal")
		openModalEvent:FireClient(player)
	end)

	eggShrine.Parent = folder
end

-- 12. Royal VIP Gamepass Dais & Throne
function MapService.buildVIPThrone(folder: Folder)
	local vipModel = Instance.new("Model")
	vipModel.Name = "VIPGamepassShrine"

	-- Positioned at East plaza (Z = -13.5)
	local shrineCF = CFrame.new(13.5, 0.4, -13.5) * CFrame.Angles(0, math.rad(-90), 0)

	local goldMetal = Color3.fromRGB(255, 215, 60)
	local royalPurple = Color3.fromRGB(110, 25, 180)
	local darkStone = Color3.fromRGB(28, 30, 38)

	-- 1. Tiered Pedestal with Royal Purple Velvet Inset
	createStudPart(vipModel, "VIPPedestalBase", Vector3.new(7.5, 0.6, 7.5), shrineCF * CFrame.new(0, 0.3, 0), darkStone)
	createStudPart(vipModel, "VIPPedestalStep", Vector3.new(6.2, 0.6, 6.2), shrineCF * CFrame.new(0, 0.9, 0), goldMetal)
	createStudPart(vipModel, "VIPVelvetRune", Vector3.new(5.0, 0.2, 5.0), shrineCF * CFrame.new(0, 1.25, 0), royalPurple)

	-- 2. Golden Royal Throne
	local throneSeat = createStudPart(vipModel, "ThroneSeat", Vector3.new(3.0, 1.2, 2.6), shrineCF * CFrame.new(0, 2.0, -0.2), goldMetal)
	throneSeat.Material = Enum.Material.SmoothPlastic

	-- Velvet Cushion
	local cushion = createStudPart(vipModel, "ThroneCushion", Vector3.new(2.6, 0.4, 2.2), shrineCF * CFrame.new(0, 2.7, -0.2), Color3.fromRGB(180, 40, 160))
	cushion.Material = Enum.Material.Neon

	-- Throne High Backrest
	local backrest = createStudPart(vipModel, "ThroneBack", Vector3.new(3.2, 4.4, 0.6), shrineCF * CFrame.new(0, 4.3, -1.3), goldMetal)
	backrest.Material = Enum.Material.SmoothPlastic

	-- Crown Finial on Top
	local crownTop = createStudPart(vipModel, "ThroneCrown", Vector3.new(2.4, 1.0, 0.8), shrineCF * CFrame.new(0, 6.8, -1.3), goldMetal)
	crownTop.Material = Enum.Material.Neon

	-- 3. Sparkling Golden Aura
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 2.5, 0)
	attach.Parent = throneSeat

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "VIPSparkles"
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0)),
	})
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparkles.Lifetime = NumberRange.new(1.2, 2.0)
	sparkles.Rate = 12
	sparkles.Speed = NumberRange.new(1.0, 2.5)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.Acceleration = Vector3.new(0, 3.0, 0)
	sparkles.LightEmission = 0.95
	sparkles.Parent = attach

	-- 4. Overhead Billboard Gui
	local vipGui = Instance.new("BillboardGui")
	vipGui.Name = "VIPTitleGui"
	vipGui.Size = UDim2.new(0, 280, 0, 80)
	vipGui.StudsOffset = Vector3.new(0, 8.2, -1.3)
	vipGui.AlwaysOnTop = false
	vipGui.MaxDistance = 70

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.38, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "👑 VIP MEMBERSHIP 👑"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = vipGui

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.32, 0)
	costLabel.Position = UDim2.new(0, 0, 0.36, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "Cost: 400 Robux R$"
	costLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 14
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = vipGui

	local perksLabel = Instance.new("TextLabel")
	perksLabel.Size = UDim2.new(1, 0, 0.28, 0)
	perksLabel.Position = UDim2.new(0, 0, 0.68, 0)
	perksLabel.BackgroundTransparency = 1
	perksLabel.Text = "💎 2x Gems Forever  •  👑 Golden [VIP] Tag"
	perksLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	perksLabel.Font = Enum.Font.GothamMedium
	perksLabel.TextSize = 11
	perksLabel.TextStrokeTransparency = 0.25
	perksLabel.Parent = vipGui

	vipGui.Parent = throneSeat

	-- 5. Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "VIPInteractionPart"
	interactionPart.Size = Vector3.new(6, 6, 6)
	interactionPart.CFrame = shrineCF * CFrame.new(0, 2.8, 1.2)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = vipModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VIPPurchasePrompt"
	prompt.ActionText = "View Perks"
	prompt.ObjectText = "VIP Pass (400 R$)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	local lastPromptTime: { [Player]: number } = {}
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastPromptTime[player] and (now - lastPromptTime[player]) < 0.4 then
			return
		end
		lastPromptTime[player] = now

		print("👑 [MapService] VIP ProximityPrompt triggered by " .. player.Name)
		local openVipEvent = Remotes.getEvent("OpenVIPModal")
		openVipEvent:FireClient(player)
	end)

	vipModel.Parent = folder
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

-- 16. Zone 2: The Infernal Crucible Boss Arena (At Z = -260)
function MapService.buildBossArena(folder: Folder)
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "BossArena"
	arenaFolder.Parent = folder

	local center = Vector3.new(0, 0.4, -260)
	local darkObsidian = Color3.fromRGB(24, 18, 20)
	local basaltTrim = Color3.fromRGB(45, 34, 38)
	local magmaRed = Color3.fromRGB(255, 60, 10)
	local goldAccent = Color3.fromRGB(255, 190, 30)

	-- 1. Main Octagonal/Stepped Battle Dais
	createStudPart(arenaFolder, "ArenaBasePlinth", Vector3.new(62, 0.8, 62), CFrame.new(center + Vector3.new(0, 0.4, 0)), darkObsidian)
	createStudPart(arenaFolder, "ArenaTierMid", Vector3.new(54, 0.5, 54), CFrame.new(center + Vector3.new(0, 0.85, 0)), basaltTrim)

	-- Molten Rune Ring Inset
	local runeRing = createStudPart(arenaFolder, "RuneRing", Vector3.new(46, 0.2, 46), CFrame.new(center + Vector3.new(0, 1.1, 0)), magmaRed)
	runeRing.Material = Enum.Material.Neon

	-- Raised Center Boss Pentagram Pad
	createStudPart(arenaFolder, "ArenaBossPad", Vector3.new(38, 0.35, 38), CFrame.new(center + Vector3.new(0, 1.25, 0)), darkObsidian)

	-- Glowing Center Boss Spawn Sigil
	local sigil = createStudPart(arenaFolder, "BossSigil", Vector3.new(16, 0.1, 16), CFrame.new(center + Vector3.new(0, 1.45, 0)), goldAccent)
	sigil.Material = Enum.Material.Neon
	sigil.CanCollide = false

	-- 2. 4 Grand Flaming Crucible Towers at Arena Perimeter
	local towerOffsets = {
		Vector3.new(-24, 0, -24),
		Vector3.new(24, 0, -24),
		Vector3.new(-24, 0, 24),
		Vector3.new(24, 0, 24),
	}
	for tIdx, tOff in ipairs(towerOffsets) do
		local towerPos = center + tOff
		createStudPart(arenaFolder, "CruciblePillar_" .. tIdx, Vector3.new(6, 18, 6), CFrame.new(towerPos + Vector3.new(0, 9, 0)), darkObsidian)
		createStudPart(arenaFolder, "CrucibleCap_" .. tIdx, Vector3.new(8, 2, 8), CFrame.new(towerPos + Vector3.new(0, 18.5, 0)), basaltTrim)
		createDungeonBrazier(arenaFolder, "CrucibleBrazier_" .. tIdx, CFrame.new(towerPos + Vector3.new(0, 19.5, 0)))
	end

	-- 3. Entrance Portal Archway (Facing South at Z = -232)
	local archZ = -232
	createStudPart(arenaFolder, "ArenaGatePillarL", Vector3.new(6, 22, 6), CFrame.new(-12, 11, archZ), darkObsidian)
	createStudPart(arenaFolder, "ArenaGatePillarR", Vector3.new(6, 22, 6), CFrame.new(12, 11, archZ), darkObsidian)
	createStudPart(arenaFolder, "ArenaGateArch", Vector3.new(30, 4, 6), CFrame.new(0, 21, archZ), basaltTrim)

	-- Arch Glowing Sign
	local archSign = createStudPart(arenaFolder, "ArenaGateSign", Vector3.new(26, 4, 1.2), CFrame.new(0, 21, archZ + 3.1), darkObsidian)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ArenaSignGui"
	signGui.Size = UDim2.new(0, 340, 0, 65)
	signGui.StudsOffset = Vector3.new(0, 0.4, 0.8)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 85

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚔️ THE INFERNAL CRUCIBLE ⚔️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 80, 20)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = signGui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "[WORLD BOSS: 50,000 HP • 25 DMG]"
	subLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 13
	subLabel.TextStrokeTransparency = 0.2
	subLabel.Parent = signGui
	signGui.Parent = archSign

	-- Road connecting Magma Egg (Z = -210) to Arena Gate (Z = -232)
	createStudPart(arenaFolder, "ArenaAccessRoad", Vector3.new(10, 0.35, 22), CFrame.new(0, 0.25, -221), Color3.fromRGB(45, 38, 42))
	createDungeonBrazier(arenaFolder, "RoadBrazierL", CFrame.new(-7, 0.3, -221))
	createDungeonBrazier(arenaFolder, "RoadBrazierR", CFrame.new(7, 0.3, -221))
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
	MapService.buildDungeonRuins(mapFolder)
	MapService.buildZone2Terrain(mapFolder)
	MapService.buildMagmaGate(mapFolder)
	MapService.buildMagmaEggStand(mapFolder)
	MapService.buildBossArena(mapFolder)
	MapService.buildTrees(mapFolder)
	MapService.buildFlora(mapFolder)
	print("✅ [MapService] Retro Roguelike Map Generation Complete! (Zone 1 Meadow & Zone 2 Magma Caverns Active)")
end

-- 9b. Mystical Trail Artisan Stall & NPC ("Zephyr")
function MapService.buildTrailShopStall(folder: Folder)
	local stallModel = Instance.new("Model")
	stallModel.Name = "TrailArtisanStall"

	local stallCF = CFrame.new(-13.5, 0.4, -14.0) * CFrame.Angles(0, math.rad(90), 0)

	local woodDark = Color3.fromRGB(45, 30, 55)
	local woodLight = Color3.fromRGB(75, 45, 95)
	local clothCyan = Color3.fromRGB(0, 210, 255)
	local clothViolet = Color3.fromRGB(180, 50, 240)
	local goldTrim = Color3.fromRGB(255, 215, 60)

	-- Counter Table
	createStudPart(stallModel, "TrailCounterBase", Vector3.new(8, 2.6, 2.4), stallCF * CFrame.new(0, 1.3, 0), woodDark)
	createStudPart(stallModel, "TrailCounterTop", Vector3.new(9, 0.6, 3.2), stallCF * CFrame.new(0, 2.8, 0), woodLight)

	-- 4 Canopy Support Corner Posts
	local postOffsets = {
		Vector3.new(-3.8, 0, -2.4),
		Vector3.new(3.8, 0, -2.4),
		Vector3.new(-3.8, 0, 1.2),
		Vector3.new(3.8, 0, 1.2),
	}
	for _, pOff in ipairs(postOffsets) do
		createStudPart(stallModel, "Post", Vector3.new(0.8, 8, 0.8), stallCF * CFrame.new(pOff.X, 4.4, pOff.Z), woodDark)
	end

	-- Overhead Striped Canopy Roof (Alternating Violet and Celestial Cyan)
	for s = -3, 3 do
		local slatCol = if s % 2 == 0 then clothViolet else clothCyan
		createStudPart(stallModel, "CanopySlat", Vector3.new(1.4, 0.5, 5.0), stallCF * CFrame.new(s * 1.35, 8.4, -0.6) * CFrame.Angles(math.rad(-8), 0, 0), slatCol)
	end

	-- Display props on counter: Glowing floating trail ribbon crystals
	local crystalProp = createStudPart(stallModel, "DisplayCrystal", Vector3.new(0.9, 1.8, 0.9), stallCF * CFrame.new(-2.6, 3.8, 0) * CFrame.Angles(math.rad(15), 0, math.rad(15)), Color3.fromRGB(0, 240, 255))
	crystalProp.Material = Enum.Material.Neon
	local orbProp = createStudPart(stallModel, "DisplayOrb", Vector3.new(1.4, 1.4, 1.4), stallCF * CFrame.new(2.6, 3.8, 0), Color3.fromRGB(240, 50, 255))
	orbProp.Material = Enum.Material.Neon

	-- Hanging Celestial Lantern under canopy
	local lantern = createStudPart(stallModel, "TrailLantern", Vector3.new(1.0, 1.2, 1.0), stallCF * CFrame.new(0, 7.2, 0.8), Color3.fromRGB(180, 100, 255))
	lantern.Material = Enum.Material.Neon

	local stallLight = Instance.new("PointLight")
	stallLight.Color = Color3.fromRGB(200, 120, 255)
	stallLight.Brightness = 2.2
	stallLight.Range = 22
	stallLight.Parent = lantern

	-- Sparkling Wind Particles around the stall
	local windAttach = Instance.new("Attachment")
	windAttach.Position = Vector3.new(0, 5, 0)
	windAttach.Parent = lantern

	local windSparkles = Instance.new("ParticleEmitter")
	windSparkles.Name = "WindSparkles"
	windSparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 240, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)),
	})
	windSparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	windSparkles.Lifetime = NumberRange.new(1.0, 1.8)
	windSparkles.Rate = 14
	windSparkles.Speed = NumberRange.new(1.5, 3.5)
	windSparkles.SpreadAngle = Vector2.new(30, 30)
	windSparkles.LightEmission = 0.95
	windSparkles.Parent = windAttach

	-- NPC: "Zephyr the Trail Artisan"
	local npcModel = Instance.new("Model")
	npcModel.Name = "ZephyrArtisan"

	local npcCF = stallCF * CFrame.new(0, 1.2, -1.2)

	-- Torso
	local torso = createStudPart(npcModel, "Torso", Vector3.new(2, 2, 1), npcCF * CFrame.new(0, 2.0, 0), Color3.fromRGB(70, 35, 110))

	-- Legs
	createStudPart(npcModel, "LeftLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(-0.5, 0.0, 0), Color3.fromRGB(35, 25, 50))
	createStudPart(npcModel, "RightLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(0.5, 0.0, 0), Color3.fromRGB(35, 25, 50))

	-- Head & Face
	local head = createStudPart(npcModel, "Head", Vector3.new(1.25, 1.25, 1.25), npcCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 220, 185), true, Enum.SurfaceType.Smooth)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Artisan Feather Hat
	createStudPart(npcModel, "HatBrim", Vector3.new(2.5, 0.35, 2.5), npcCF * CFrame.new(0, 4.0, 0), Color3.fromRGB(45, 20, 75))
	createStudPart(npcModel, "HatCrown", Vector3.new(1.6, 0.8, 1.6), npcCF * CFrame.new(0, 4.45, 0), Color3.fromRGB(60, 30, 95))
	local star = createStudPart(npcModel, "HatStar", Vector3.new(0.5, 0.5, 0.5), npcCF * CFrame.new(0, 4.5, -0.9), goldTrim)
	star.Material = Enum.Material.Neon

	-- Arms
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(70, 35, 110))
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(70, 35, 110))

	-- Title Billboard
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "ZephyrTitleGui"
	titleGui.Size = UDim2.new(0, 200, 0, 50)
	titleGui.StudsOffset = Vector3.new(0, 3.2, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 60

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "✨ ZEPHYR ✨"
	titleLabel.TextColor3 = Color3.fromRGB(240, 100, 255)
	titleLabel.Font = Enum.Font.Antique
	titleLabel.TextSize = 19
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "[Trail Artisan]"
	subtitleLabel.TextColor3 = Color3.fromRGB(160, 240, 255)
	subtitleLabel.Font = Enum.Font.Antique
	subtitleLabel.TextSize = 14
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- Invisible Interaction Part & ProximityPrompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "ZephyrInteractionPart"
	interactionPart.Size = Vector3.new(9, 5, 4)
	interactionPart.CFrame = stallCF * CFrame.new(0, 2.8, 1.2)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = stallModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Zephyr (Trails Shop)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		print("🗣️ [MapService] Zephyr ProximityPrompt triggered by " .. player.Name)
		local dialogueEvent = Remotes.getEvent("OpenShopDialogue")
		dialogueEvent:FireClient(player, "Zephyr")
	end)

	npcModel.Parent = stallModel
	stallModel.Parent = folder
end

return MapService
