--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

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

	-- 4 Mid-Pathway Dungeon Braziers lighting the way to each Tycoon plot
	local pathMidBraziers = {
		Vector3.new(-34, 0, -17),
		Vector3.new(34, 0, -17),
		Vector3.new(-34, 0, 17),
		Vector3.new(34, 0, 17),
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
	padGui.AlwaysOnTop = true

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

	-- 7. MONUMENTAL NORTHERN DUNGEON GATE (At North Mountains, Z = -188)
	local gateModel = Instance.new("Model")
	gateModel.Name = "NorthernDungeonGate"

	local gateZ = -188
	-- Flanking Gate Towers with tactile studs
	createStudPart(gateModel, "TowerLeft", Vector3.new(12, 38, 12), CFrame.new(-22, 19, gateZ), stoneDark)
	createStudPart(gateModel, "TowerRight", Vector3.new(12, 38, 12), CFrame.new(22, 19, gateZ), stoneDark)
	createStudPart(gateModel, "TowerCapL", Vector3.new(14, 3, 14), CFrame.new(-22, 39.5, gateZ), stoneMid)
	createStudPart(gateModel, "TowerCapR", Vector3.new(14, 3, 14), CFrame.new(22, 39.5, gateZ), stoneMid)

	-- Spiked Battlements with Studs
	for b = -2, 2 do
		createStudPart(gateModel, "MerlonL", Vector3.new(2.4, 3, 2.4), CFrame.new(-22 + (b * 2.8), 42.5, gateZ + 5), stoneDark)
		createStudPart(gateModel, "MerlonR", Vector3.new(2.4, 3, 2.4), CFrame.new(22 + (b * 2.8), 42.5, gateZ + 5), stoneDark)
	end

	-- Grand Overhead Stone Lintel
	createStudPart(gateModel, "GateArch", Vector3.new(36, 8, 10), CFrame.new(0, 34, gateZ), stoneMid)

	-- Deep Cavern Abyss (Pitch-black dungeon interior behind the iron bars)
	createStudPart(gateModel, "DungeonAbyss", Vector3.new(30, 28, 4), CFrame.new(0, 14, gateZ - 3), Color3.fromRGB(6, 6, 10))

	-- Heavy Iron Portcullis Spiked Bars
	for bar = -5, 5 do
		local ironBar = createStudPart(gateModel, "PortcullisBar", Vector3.new(0.8, 26, 0.8), CFrame.new(bar * 2.6, 14, gateZ + 1), Color3.fromRGB(35, 38, 42))
		ironBar.Material = Enum.Material.Metal
	end
	for hBar = 1, 4 do
		local crossBar = createStudPart(gateModel, "PortcullisCross", Vector3.new(29, 0.8, 0.8), CFrame.new(0, hBar * 6, gateZ + 1.2), Color3.fromRGB(35, 38, 42))
		crossBar.Material = Enum.Material.Metal
	end

	-- Braziers flanking the dungeon gate
	createDungeonBrazier(gateModel, "GateTorchL", CFrame.new(-14, 0, gateZ + 7))
	createDungeonBrazier(gateModel, "GateTorchR", CFrame.new(14, 0, gateZ + 7))

	-- Ominous Stone Plaque: "⚔️ THE FORGOTTEN DEPTHS ⚔️"
	local plaque = createStudPart(gateModel, "GatePlaque", Vector3.new(24, 3.4, 1.2), CFrame.new(0, 34, gateZ + 5.2), stoneDark)
	local plaqueGui = Instance.new("BillboardGui")
	plaqueGui.Name = "DungeonPlaqueGui"
	plaqueGui.Size = UDim2.new(0, 320, 0, 50)
	plaqueGui.StudsOffset = Vector3.new(0, 0, 1)
	plaqueGui.AlwaysOnTop = true

	local plaqueText = Instance.new("TextLabel")
	plaqueText.Size = UDim2.new(1, 0, 1, 0)
	plaqueText.BackgroundTransparency = 1
	plaqueText.Text = "⚔️ THE FORGOTTEN DEPTHS ⚔️"
	plaqueText.TextColor3 = Color3.fromRGB(255, 90, 80)
	plaqueText.Font = Enum.Font.GothamBlack
	plaqueText.TextSize = 17
	plaqueText.TextStrokeTransparency = 0.2
	plaqueText.Parent = plaqueGui
	plaqueGui.Parent = plaque

	gateModel.Parent = ruinsFolder
end

-- 8. Atmospheric Lighting & Post-Processing Setup (High Visibility Roguelike Mist & Dusk)
function MapService.setupAtmosphere()
	-- Configure Lighting for Clear, High-Visibility Atmospheric Roguelike Mood
	Lighting.ClockTime = 17.5 -- Atmospheric late afternoon / dusk golden-slate hour
	Lighting.Brightness = 2.4 -- Crisp, bright primary sunlight
	Lighting.Ambient = Color3.fromRGB(115, 120, 135) -- Soft cool slate-blue shadows (no pitch-black voids!)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 155) -- Bright, clearly visible terrain and paths
	Lighting.FogStart = 120 -- High clarity across the central plaza, paths, and tycoon plots
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
	titleGui.AlwaysOnTop = true

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

	-- Symmetrically opposite Barnaby's stall (Barnaby at X = -13.5, Z = 0)
	local shrineCF = CFrame.new(13.5, 0.4, 0) * CFrame.Angles(0, math.rad(-90), 0)

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
	eggGui.AlwaysOnTop = true

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

	-- Invisible Interaction Part & Proximity Prompts
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "EggInteractionPart"
	interactionPart.Size = Vector3.new(8, 6, 8)
	interactionPart.CFrame = shrineCF * CFrame.new(0, 3.5, 0)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = eggShrine

	-- Prompt 1: [E] Hatch 1x
	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "Hatch1Prompt"
	prompt1.ActionText = "Hatch 1x"
	prompt1.ObjectText = "Prism Egg (100 💎)"
	prompt1.KeyboardKeyCode = Enum.KeyCode.E
	prompt1.HoldDuration = 0
	prompt1.MaxActivationDistance = 14
	prompt1.RequiresLineOfSight = false
	prompt1.ClickablePrompt = true
	prompt1.Parent = interactionPart

	-- Prompt 2: [F] Hatch 3x
	local prompt3 = Instance.new("ProximityPrompt")
	prompt3.Name = "Hatch3Prompt"
	prompt3.ActionText = "Hatch 3x"
	prompt3.ObjectText = "Prism Egg (300 💎)"
	prompt3.KeyboardKeyCode = Enum.KeyCode.F
	prompt3.HoldDuration = 0
	prompt3.MaxActivationDistance = 14
	prompt3.RequiresLineOfSight = false
	prompt3.ClickablePrompt = true
	prompt3.Parent = interactionPart

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
	MapService.buildEggStand(mapFolder)
	MapService.buildDungeonRuins(mapFolder)
	MapService.buildTrees(mapFolder)
	MapService.buildFlora(mapFolder)
	print("✅ [MapService] Retro Roguelike Map Generation Complete! (All parts anchored with Studs)")
end

return MapService
