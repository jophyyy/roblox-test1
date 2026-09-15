--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local TownBuildingBuilder = {}

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
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- =========================================================================
-- 1. THE BLACKSMITH FORGE (Barnaby the Equipment Merchant)
-- =========================================================================
function TownBuildingBuilder.buildBlacksmith(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "BlacksmithForge"

	-- Positioned on West/Northwest courtyard, facing +X (toward central spawn plaza)
	local bCF = CFrame.new(-40, 0, -18) * CFrame.Angles(0, math.rad(90), 0)

	local stoneDark = Color3.fromRGB(48, 52, 60)
	local stoneWall = Color3.fromRGB(72, 76, 84)
	local stoneTrim = Color3.fromRGB(58, 62, 70)
	local woodDark = Color3.fromRGB(68, 42, 24)
	local woodLight = Color3.fromRGB(110, 72, 42)
	local woodPlank = Color3.fromRGB(92, 58, 34)
	local roofSlate = Color3.fromRGB(42, 44, 50)
	local roofRidge = Color3.fromRGB(30, 32, 38)
	local fireGlow = Color3.fromRGB(255, 80, 15)
	local ironMetal = Color3.fromRGB(45, 48, 55)

	-- 1. Raised Heavy Stone Plinth Foundation (28 x 1.4 x 30)
	createStudPart(buildingModel, "Foundation", Vector3.new(28, 1.4, 30), bCF * CFrame.new(0, 0.7, 0), stoneDark)
	createStudPart(buildingModel, "StoneDeck", Vector3.new(26.4, 0.4, 28.4), bCF * CFrame.new(0, 1.4, 0), stoneTrim)

	-- Stepped stone entrance threshold
	for s = 1, 2 do
		createStudPart(buildingModel, "Step_" .. s, Vector3.new(14, 0.35, 2.0), bCF * CFrame.new(0, 0.35 * s, 14.5 + (2.0 * (2 - s))), stoneDark)
	end

	-- 2. Heavy Timber Columns & Stone Buttresses at Corners
	local colOffsets = {
		Vector3.new(-12.5, 7.0, -13.5),
		Vector3.new(12.5, 7.0, -13.5),
		Vector3.new(-12.5, 7.0, 13.5),
		Vector3.new(12.5, 7.0, 13.5),
	}
	for _, cOff in ipairs(colOffsets) do
		-- Ashlar stone buttress base
		createStudPart(buildingModel, "CornerButtress", Vector3.new(3.2, 4.0, 3.2), bCF * CFrame.new(cOff.X, 3.4, cOff.Z), stoneDark)
		-- Chamfered timber pillar
		local col = createStudPart(buildingModel, "TimberColumn", Vector3.new(2.4, 12.0, 2.4), bCF * CFrame.new(cOff.X, 8.4, cOff.Z), woodDark)
		col.Material = Enum.Material.Wood
	end

	-- 3. Ground Floor Stone Masonry Walls (Back, Sides & Front Piers)
	-- Back Wall
	createStudPart(buildingModel, "BackWall", Vector3.new(24, 11.0, 1.6), bCF * CFrame.new(0, 7.1, -13.5), stoneWall)
	-- Left Wall with Small High Forge Window
	createStudPart(buildingModel, "LeftWall", Vector3.new(1.6, 11.0, 18), bCF * CFrame.new(-12.5, 7.1, -4.5), stoneWall)
	createStudPart(buildingModel, "LeftWindowLintel", Vector3.new(2.0, 0.6, 3.6), bCF * CFrame.new(-12.5, 9.8, -4.5), woodDark)
	local lWinGlow = createStudPart(buildingModel, "LeftWinGlow", Vector3.new(1.2, 2.0, 2.8), bCF * CFrame.new(-12.5, 8.5, -4.5), Color3.fromRGB(255, 170, 60))
	lWinGlow.Material = Enum.Material.Neon

	-- Right Wall
	createStudPart(buildingModel, "RightWall", Vector3.new(1.6, 11.0, 18), bCF * CFrame.new(12.5, 7.1, -4.5), stoneWall)

	-- Front Facade Piers & Heavy Header Beam (creating grand 15-stud open covered workshop arch)
	createStudPart(buildingModel, "FrontPierL", Vector3.new(5.5, 11.0, 1.6), bCF * CFrame.new(-9.5, 7.1, 4.5), stoneWall)
	createStudPart(buildingModel, "FrontPierR", Vector3.new(5.5, 11.0, 1.6), bCF * CFrame.new(9.5, 7.1, 4.5), stoneWall)
	local archBeam = createStudPart(buildingModel, "ArchLintel", Vector3.new(27, 2.2, 2.0), bCF * CFrame.new(0, 12.2, 4.5), woodDark)
	archBeam.Material = Enum.Material.Wood

	-- 4. Jetted Second-Story Timber Loft (Overhanging by 1.5 studs on all sides)
	local loftY = 17.0
	createStudPart(buildingModel, "LoftFloorPlate", Vector3.new(27.4, 1.2, 23.4), bCF * CFrame.new(0, 13.0, -1.5), woodDark)

	-- Decorative Carved Wooden Corbel Brackets supporting the overhang
	for bx = -11, 11, 5.5 do
		local bracket = createStudPart(buildingModel, "CorbelFront_" .. bx, Vector3.new(1.4, 2.0, 1.8), bCF * CFrame.new(bx, 12.0, 5.0) * CFrame.Angles(math.rad(25), 0, 0), woodDark)
		bracket.Material = Enum.Material.Wood
	end

	-- Upper Floor Walls (Tudor Half-Timber Infill)
	createStudPart(buildingModel, "LoftBackWall", Vector3.new(26, 7.5, 1.4), bCF * CFrame.new(0, loftY, -13.0), Color3.fromRGB(235, 228, 215))
	createStudPart(buildingModel, "LoftLeftWall", Vector3.new(1.4, 7.5, 22), bCF * CFrame.new(-13.0, loftY, -2.0), Color3.fromRGB(235, 228, 215))
	createStudPart(buildingModel, "LoftRightWall", Vector3.new(1.4, 7.5, 22), bCF * CFrame.new(13.0, loftY, -2.0), Color3.fromRGB(235, 228, 215))
	createStudPart(buildingModel, "LoftFrontWall", Vector3.new(26, 7.5, 1.4), bCF * CFrame.new(0, loftY, 9.0), Color3.fromRGB(235, 228, 215))

	-- Exposed Tudor Half-Timber Cross-Beams on Front Facade
	createStudPart(buildingModel, "LoftTrimTop", Vector3.new(27, 1.0, 1.8), bCF * CFrame.new(0, loftY + 3.4, 9.1), woodDark)
	createStudPart(buildingModel, "LoftTrimBot", Vector3.new(27, 1.0, 1.8), bCF * CFrame.new(0, loftY - 3.4, 9.1), woodDark)
	for tx = -10, 10, 5 do
		createStudPart(buildingModel, "LoftStud_" .. tx, Vector3.new(1.0, 6.8, 1.6), bCF * CFrame.new(tx, loftY, 9.1), woodDark)
	end
	-- Diagonal X-Braces
	createStudPart(buildingModel, "LoftBrace1", Vector3.new(1.0, 7.2, 1.5), bCF * CFrame.new(-7.5, loftY, 9.15) * CFrame.Angles(0, 0, math.rad(42)), woodDark)
	createStudPart(buildingModel, "LoftBrace2", Vector3.new(1.0, 7.2, 1.5), bCF * CFrame.new(7.5, loftY, 9.15) * CFrame.Angles(0, 0, math.rad(-42)), woodDark)

	-- Twin 3D Leaded Glass Attic Windows with Wooden Shutters
	for wx = -5, 5, 10 do
		local winGlow = createStudPart(buildingModel, "AtticWinGlow_" .. wx, Vector3.new(2.4, 3.2, 1.6), bCF * CFrame.new(wx, loftY, 9.2), Color3.fromRGB(255, 210, 100))
		winGlow.Material = Enum.Material.Neon
		createStudPart(buildingModel, "WinShutterL_" .. wx, Vector3.new(0.8, 3.2, 1.7), bCF * CFrame.new(wx - 1.6, loftY, 9.2), woodLight)
		createStudPart(buildingModel, "WinShutterR_" .. wx, Vector3.new(0.8, 3.2, 1.7), bCF * CFrame.new(wx + 1.6, loftY, 9.2), woodLight)
	end

	-- Hoisting Crane Winch with Suspended Anvil over Street
	createStudPart(buildingModel, "CraneBeam", Vector3.new(1.6, 1.6, 8.5), bCF * CFrame.new(0, loftY + 3.8, 11.5), woodDark)
	createStudPart(buildingModel, "CraneBrace", Vector3.new(1.2, 4.2, 1.2), bCF * CFrame.new(0, loftY + 1.8, 12.0) * CFrame.Angles(math.rad(45), 0, 0), woodDark)
	local rope = createStudPart(buildingModel, "CraneRope", Vector3.new(0.2, 5.5, 0.2), bCF * CFrame.new(0, loftY + 0.8, 15.0), Color3.fromRGB(180, 150, 110))
	rope.Material = Enum.Material.Fabric
	local suspendedAnvil = createStudPart(buildingModel, "CraneAnvil", Vector3.new(1.8, 1.2, 1.2), bCF * CFrame.new(0, loftY - 2.2, 15.0), ironMetal)
	suspendedAnvil.Material = Enum.Material.Metal

	-- 5. Multi-Tier Steep Pitched Slate Roof with Front Porch Awning
	local roofPeakY = 24.5
	createStudPart(buildingModel, "RoofRidgeBeam", Vector3.new(28.5, 1.8, 2.4), bCF * CFrame.new(0, roofPeakY, -1.0), roofRidge)

	-- Main Slanted Roof Slabs with 3D Overhangs
	createStudPart(buildingModel, "RoofSlopeBack", Vector3.new(28.5, 1.0, 16.5), bCF * CFrame.new(0, 21.0, -8.5) * CFrame.Angles(math.rad(-34), 0, 0), roofSlate)
	createStudPart(buildingModel, "RoofSlopeFront", Vector3.new(28.5, 1.0, 16.5), bCF * CFrame.new(0, 21.0, 6.5) * CFrame.Angles(math.rad(34), 0, 0), roofSlate)

	-- Front Porch Overhang Canopy
	createStudPart(buildingModel, "PorchCanopy", Vector3.new(26.0, 0.8, 8.5), bCF * CFrame.new(0, 13.8, 9.8) * CFrame.Angles(math.rad(16), 0, 0), roofSlate)

	-- Two 3D Gabled Dormer Windows Protruding from Front Roof
	for dx = -8, 8, 16 do
		createStudPart(buildingModel, "DormerGable_" .. dx, Vector3.new(4.5, 4.0, 4.5), bCF * CFrame.new(dx, 22.0, 4.0), stoneWall)
		createStudPart(buildingModel, "DormerRoofL_" .. dx, Vector3.new(3.0, 0.6, 5.0), bCF * CFrame.new(dx - 1.5, 24.2, 4.0) * CFrame.Angles(0, 0, math.rad(38)), roofRidge)
		createStudPart(buildingModel, "DormerRoofR_" .. dx, Vector3.new(3.0, 0.6, 5.0), bCF * CFrame.new(dx + 1.5, 24.2, 4.0) * CFrame.Angles(0, 0, math.rad(-38)), roofRidge)
		local dWin = createStudPart(buildingModel, "DormerWin_" .. dx, Vector3.new(2.4, 2.4, 0.8), bCF * CFrame.new(dx, 22.5, 6.3), Color3.fromRGB(255, 200, 80))
		dWin.Material = Enum.Material.Neon
	end

	-- 6. Colossal Stepped Industrial Stone Forge Chimney with Smoke & Sparks
	local chimX = -10.5
	local chimZ = -10.5
	createStudPart(buildingModel, "ChimneyBase", Vector3.new(5.8, 12.0, 5.8), bCF * CFrame.new(chimX, 7.0, chimZ), stoneDark)
	createStudPart(buildingModel, "ChimneyMid", Vector3.new(4.6, 12.0, 4.6), bCF * CFrame.new(chimX, 18.0, chimZ), stoneWall)
	local chimneyTop = createStudPart(buildingModel, "ChimneyCap", Vector3.new(5.4, 1.8, 5.4), bCF * CFrame.new(chimX, 24.5, chimZ), Color3.fromRGB(36, 38, 44))

	-- Cast Iron Reinforcement Straps on Chimney
	for cy = 6, 22, 6 do
		createStudPart(buildingModel, "ChimneyStrap_" .. cy, Vector3.new(5.0, 0.4, 5.0), bCF * CFrame.new(chimX, cy, chimZ), ironMetal)
	end

	local chimAtt = Instance.new("Attachment")
	chimAtt.Position = Vector3.new(0, 1.0, 0)
	chimAtt.Parent = chimneyTop

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ChimneySmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(65, 68, 75))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.5, 3.4),
		NumberSequenceKeypoint.new(1, 6.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	smoke.Rate = 18
	smoke.Speed = NumberRange.new(3.5, 7.0)
	smoke.Lifetime = NumberRange.new(3.0, 5.0)
	smoke.SpreadAngle = Vector2.new(16, 16)
	smoke.Acceleration = Vector3.new(0, 3.5, 0)
	smoke.Parent = chimAtt

	local ember = Instance.new("ParticleEmitter")
	ember.Name = "ChimneyEmbers"
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 120, 20))
	ember.Size = NumberSequence.new(0.4, 0.1)
	ember.Rate = 8
	ember.Speed = NumberRange.new(4, 8)
	ember.Lifetime = NumberRange.new(1.5, 2.5)
	ember.LightEmission = 1.0
	ember.Acceleration = Vector3.new(0, 4, 0)
	ember.Parent = chimAtt

	-- 7. Deep Outdoor Covered Forge Patio & Blacksmith Machinery
	-- Heavy Forge Furnace Hearth with Glowing Pit
	local forgeHearth = createStudPart(buildingModel, "ForgeHearth", Vector3.new(6.0, 3.2, 5.5), bCF * CFrame.new(-7.5, 2.8, 8.5), stoneDark)
	local glowingCoals = createStudPart(buildingModel, "ForgeCoals", Vector3.new(4.8, 0.6, 4.2), bCF * CFrame.new(-7.5, 4.2, 8.5), fireGlow)
	glowingCoals.Material = Enum.Material.Neon

	-- Forge Bellows with Timber Lever
	createStudPart(buildingModel, "BellowsBody", Vector3.new(3.2, 1.4, 2.6), bCF * CFrame.new(-11.0, 3.5, 8.5), Color3.fromRGB(140, 80, 40))
	createStudPart(buildingModel, "BellowsNozzle", Vector3.new(1.6, 0.4, 0.4), bCF * CFrame.new(-9.0, 3.5, 8.5), ironMetal)

	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = Color3.fromRGB(255, 140, 30)
	forgeLight.Brightness = 3.2
	forgeLight.Range = 26
	forgeLight.Shadows = true
	forgeLight.Parent = glowingCoals

	local fireAtt = Instance.new("Attachment")
	fireAtt.Position = Vector3.new(0, 0.5, 0)
	fireAtt.Parent = glowingCoals

	local forgeFire = Instance.new("ParticleEmitter")
	forgeFire.Name = "ForgeFire"
	forgeFire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 140)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 130, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 0)),
	})
	forgeFire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.0),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	forgeFire.Rate = 22
	forgeFire.Speed = NumberRange.new(2.5, 5.0)
	forgeFire.Lifetime = NumberRange.new(0.7, 1.2)
	forgeFire.SpreadAngle = Vector2.new(12, 12)
	forgeFire.LightEmission = 1.0
	forgeFire.Parent = fireAtt

	-- Heavy Cast-Iron Anvil on Massive Carved Oak Stump
	createStudPart(buildingModel, "AnvilStump", Vector3.new(3.2, 2.0, 3.2), bCF * CFrame.new(-7.5, 2.2, 13.5), woodDark)
	local anvilBase = createStudPart(buildingModel, "AnvilBase", Vector3.new(3.4, 0.8, 2.2), bCF * CFrame.new(-7.5, 3.4, 13.5), Color3.fromRGB(115, 125, 140))
	anvilBase.Material = Enum.Material.Metal
	local anvilHorn = createStudPart(buildingModel, "AnvilHorn", Vector3.new(4.4, 1.0, 1.6), bCF * CFrame.new(-7.5, 4.2, 13.5), Color3.fromRGB(150, 160, 175))
	anvilHorn.Material = Enum.Material.Metal

	-- Quenching Water Trough with Steaming Water
	createStudPart(buildingModel, "WaterTrough", Vector3.new(4.5, 2.2, 2.6), bCF * CFrame.new(-11.5, 2.3, 13.5), woodPlank)
	local water = createStudPart(buildingModel, "TroughWater", Vector3.new(4.0, 0.2, 2.2), bCF * CFrame.new(-11.5, 3.2, 13.5), Color3.fromRGB(0, 170, 230))
	water.Material = Enum.Material.Glass

	local steamAtt = Instance.new("Attachment")
	steamAtt.Position = Vector3.new(0, 0.2, 0)
	steamAtt.Parent = water
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "QuenchSteam"
	steam.Color = ColorSequence.new(Color3.fromRGB(230, 235, 245))
	steam.Size = NumberSequence.new(0.4, 1.8)
	steam.Transparency = NumberSequence.new(0.3, 1.0)
	steam.Rate = 6
	steam.Speed = NumberRange.new(1.0, 2.2)
	steam.Lifetime = NumberRange.new(1.2, 2.0)
	steam.Parent = steamAtt

	-- Pedal-Operated Tool Grinding Wheel with Sparks
	createStudPart(buildingModel, "GrindTrestle", Vector3.new(1.8, 2.4, 2.4), bCF * CFrame.new(11.5, 2.4, 8.5), woodDark)
	local grindStone = createStudPart(buildingModel, "GrindWheel", Vector3.new(0.6, 2.6, 2.6), bCF * CFrame.new(11.5, 3.6, 8.5), stoneWall)
	grindStone.Material = Enum.Material.Slate

	local grindAtt = Instance.new("Attachment")
	grindAtt.Position = Vector3.new(0, 0.8, 0.4)
	grindAtt.Parent = grindStone
	local grindSparks = Instance.new("ParticleEmitter")
	grindSparks.Name = "GrindSparks"
	grindSparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
	grindSparks.Size = NumberSequence.new(0.25, 0.05)
	grindSparks.Rate = 14
	grindSparks.Speed = NumberRange.new(3, 7)
	grindSparks.SpreadAngle = Vector2.new(20, 20)
	grindSparks.LightEmission = 1.0
	grindSparks.Acceleration = Vector3.new(0, -12, 0)
	grindSparks.Parent = grindAtt

	-- Pyramids of Stacked Metal Ingots on Timber Pallet
	createStudPart(buildingModel, "IngotPallet", Vector3.new(3.5, 0.4, 3.5), bCF * CFrame.new(11.5, 1.4, 13.5), woodLight)
	local ingotColors = { Color3.fromRGB(170, 175, 185), Color3.fromRGB(255, 215, 0), Color3.fromRGB(230, 45, 60) }
	for layer = 1, 3 do
		for ix = 1, (4 - layer) do
			local ing = createStudPart(buildingModel, "Ingot_" .. layer .. "_" .. ix, Vector3.new(0.7, 0.4, 1.6), bCF * CFrame.new(10.2 + (ix * 0.7), 1.6 + (layer * 0.4), 13.5), ingotColors[layer])
			ing.Material = Enum.Material.Metal
		end
	end

	-- Pickaxe & Shovel Weapon Rack along Right Wall
	createStudPart(buildingModel, "WeaponRack", Vector3.new(1.2, 5.0, 5.5), bCF * CFrame.new(9.5, 3.7, 8.5), woodDark)
	local pick1 = createStudPart(buildingModel, "DisplayPick1", Vector3.new(0.4, 3.2, 0.4), bCF * CFrame.new(9.5, 4.0, 7.2) * CFrame.Angles(math.rad(22), 0, 0), Color3.fromRGB(255, 215, 0))
	pick1.Material = Enum.Material.Neon
	local pick2 = createStudPart(buildingModel, "DisplayPick2", Vector3.new(0.4, 3.2, 0.4), bCF * CFrame.new(9.5, 4.0, 9.8) * CFrame.Angles(math.rad(22), 0, 0), Color3.fromRGB(0, 230, 255))
	pick2.Material = Enum.Material.Neon

	-- Hanging 3D Forged Iron Shop Sign on Wrought Iron Wall Bracket
	createStudPart(buildingModel, "SignBracket", Vector3.new(4.5, 0.4, 0.4), bCF * CFrame.new(11.5, 11.5, 5.5), ironMetal)
	createStudPart(buildingModel, "SignChainL", Vector3.new(0.15, 1.2, 0.15), bCF * CFrame.new(10.2, 10.8, 5.5), ironMetal)
	createStudPart(buildingModel, "SignChainR", Vector3.new(0.15, 1.2, 0.15), bCF * CFrame.new(12.8, 10.8, 5.5), ironMetal)
	local signBoard = createStudPart(buildingModel, "SignBoard", Vector3.new(4.0, 2.2, 0.6), bCF * CFrame.new(11.5, 9.6, 5.5), woodDark)
	signBoard.Material = Enum.Material.WoodPlanks

	local signBb = Instance.new("BillboardGui")
	signBb.Size = UDim2.new(0, 160, 0, 60)
	signBb.StudsOffset = Vector3.new(0, 0, 0)
	signBb.AlwaysOnTop = false
	signBb.MaxDistance = 45
	signBb.Parent = signBoard
	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, 0, 1, 0)
	sLbl.BackgroundTransparency = 1
	sLbl.Text = "⚒️ FORGE"
	sLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
	sLbl.Font = Enum.Font.GothamBlack
	sLbl.TextSize = 18
	sLbl.Parent = signBb

	-- 8. Front Service Counter Desk (Outside Porch)
	createStudPart(buildingModel, "CounterBase", Vector3.new(11.0, 2.8, 2.6), bCF * CFrame.new(1.5, 2.6, 12.8), woodDark)
	createStudPart(buildingModel, "CounterTop", Vector3.new(12.2, 0.5, 3.4), bCF * CFrame.new(1.5, 4.2, 12.8), woodLight)
	createStudPart(buildingModel, "CounterIronTrim", Vector3.new(12.4, 0.15, 3.6), bCF * CFrame.new(1.5, 4.45, 12.8), ironMetal)

	-- 9. BARNABY THE BLACKSMITH NPC (Behind the Counter)
	local npcModel = Instance.new("Model")
	npcModel.Name = "BarnabyMerchant"

	local npcCF = bCF * CFrame.new(1.5, 2.4, 10.5) -- Facing forward toward customer side (+Z local)

	local torso = createStudPart(npcModel, "Torso", Vector3.new(2, 2, 1), npcCF * CFrame.new(0, 2.0, 0), Color3.fromRGB(48, 72, 115))
	createStudPart(npcModel, "LeftLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(-0.5, 0.0, 0), Color3.fromRGB(38, 42, 50))
	createStudPart(npcModel, "RightLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(0.5, 0.0, 0), Color3.fromRGB(38, 42, 50))

	local head = createStudPart(npcModel, "Head", Vector3.new(1.25, 1.25, 1.25), npcCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 215, 175), true, Enum.SurfaceType.Smooth)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Leather Blacksmith Fedora Hat
	createStudPart(npcModel, "HatBrim", Vector3.new(2.4, 0.35, 2.4), npcCF * CFrame.new(0, 4.0, 0), Color3.fromRGB(80, 45, 25))
	createStudPart(npcModel, "HatCrown", Vector3.new(1.5, 0.75, 1.5), npcCF * CFrame.new(0, 4.4, 0), Color3.fromRGB(95, 55, 30))

	-- Arms resting on the counter
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(48, 72, 115))
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(48, 72, 115))

	-- Signboard Overhead Title Billboard
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "MerchantTitleGui"
	titleGui.Size = UDim2.new(0, 260, 0, 58)
	titleGui.StudsOffset = Vector3.new(0, 3.8, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 70

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚒️ THE MASTER BLACKSMITH ⚒️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Barnaby [Pickaxes • Shovels • Packs]"
	subtitleLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.TextSize = 12
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- Invisible Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "BarnabyInteractionPart"
	interactionPart.Size = Vector3.new(12, 6, 6)
	interactionPart.CFrame = bCF * CFrame.new(1.5, 3.6, 14.8)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = buildingModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Barnaby (Blacksmith)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		print("🗣️ [TownBuildingBuilder] Barnaby triggered by " .. player.Name)
		local dialogueEvent = Remotes.getEvent("OpenShopDialogue")
		dialogueEvent:FireClient(player, "Barnaby")
	end)

	npcModel.Parent = buildingModel
	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 2. THE TRAIL ARTISAN BOUTIQUE (Zephyr the Trail Artisan)
-- =========================================================================
function TownBuildingBuilder.buildTrailArtisan(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "TrailArtisanBoutique"

	-- Positioned on West/Southwest courtyard, facing +X (toward central spawn plaza)
	local bCF = CFrame.new(-40, 0, 18) * CFrame.Angles(0, math.rad(90), 0)

	local woodDark = Color3.fromRGB(42, 24, 52)
	local woodLight = Color3.fromRGB(72, 44, 90)
	local woodTrim = Color3.fromRGB(56, 32, 70)
	local clothCyan = Color3.fromRGB(0, 220, 255)
	local clothViolet = Color3.fromRGB(165, 40, 230)
	local royalIndigo = Color3.fromRGB(28, 20, 48)
	local goldTrim = Color3.fromRGB(255, 215, 60)
	local stoneDark = Color3.fromRGB(42, 38, 50)
	local stonePlinth = Color3.fromRGB(60, 52, 72)
	local runeGlow = Color3.fromRGB(0, 240, 255)

	-- 1. Raised Celestial Amethyst & Slate Foundation (28 x 1.4 x 28)
	createStudPart(buildingModel, "Foundation", Vector3.new(28, 1.4, 28), bCF * CFrame.new(0, 0.7, 0), stoneDark)
	createStudPart(buildingModel, "CelestialDeck", Vector3.new(26.4, 0.4, 26.4), bCF * CFrame.new(0, 1.4, 0), stonePlinth)

	-- Stepped stone entrance threshold with inlaid glowing rune line
	for s = 1, 2 do
		createStudPart(buildingModel, "Step_" .. s, Vector3.new(14, 0.35, 2.0), bCF * CFrame.new(0, 0.35 * s, 13.5 + (2.0 * (2 - s))), stoneDark)
	end
	local stepGlow = createStudPart(buildingModel, "StepRuneGlow", Vector3.new(12, 0.05, 0.4), bCF * CFrame.new(0, 1.42, 13.0), runeGlow)
	stepGlow.Material = Enum.Material.Neon

	-- 2. Heavy Fluted Amethyst Columns at 4 Corners
	local colOffsets = {
		Vector3.new(-12.5, 7.0, -12.5),
		Vector3.new(12.5, 7.0, -12.5),
		Vector3.new(-12.5, 7.0, 12.5),
		Vector3.new(12.5, 7.0, 12.5),
	}
	for _, cOff in ipairs(colOffsets) do
		createStudPart(buildingModel, "ColBase", Vector3.new(3.0, 3.2, 3.0), bCF * CFrame.new(cOff.X, 3.0, cOff.Z), stoneDark)
		local col = createStudPart(buildingModel, "CelestialCol", Vector3.new(2.4, 12.0, 2.4), bCF * CFrame.new(cOff.X, 8.4, cOff.Z), woodDark)
		col.Material = Enum.Material.Wood
		local colCap = createStudPart(buildingModel, "ColCapital", Vector3.new(2.8, 0.8, 2.8), bCF * CFrame.new(cOff.X, 14.0, cOff.Z), goldTrim)
		colCap.Material = Enum.Material.SmoothPlastic
	end

	-- 3. Ground Floor Walls with Diamond Bay Windows
	-- Back Wall
	createStudPart(buildingModel, "BackWall", Vector3.new(24, 11.0, 1.6), bCF * CFrame.new(0, 7.1, -12.5), royalIndigo)
	-- Left Wall with Mystical Arched Window
	createStudPart(buildingModel, "LeftWall", Vector3.new(1.6, 11.0, 16), bCF * CFrame.new(-12.5, 7.1, -3.5), royalIndigo)
	local lWin = createStudPart(buildingModel, "LeftWinGlow", Vector3.new(1.8, 4.2, 3.2), bCF * CFrame.new(-12.5, 8.0, -3.5), clothCyan)
	lWin.Material = Enum.Material.Neon

	-- Right Wall
	createStudPart(buildingModel, "RightWall", Vector3.new(1.6, 11.0, 16), bCF * CFrame.new(12.5, 7.1, -3.5), royalIndigo)
	local rWin = createStudPart(buildingModel, "RightWinGlow", Vector3.new(1.8, 4.2, 3.2), bCF * CFrame.new(12.5, 8.0, -3.5), clothViolet)
	rWin.Material = Enum.Material.Neon

	-- Front Facade Piers & Arched Header Beam (leaving 15-stud open porch archway)
	createStudPart(buildingModel, "FrontPierL", Vector3.new(5.5, 11.0, 1.6), bCF * CFrame.new(-9.5, 7.1, 4.5), royalIndigo)
	createStudPart(buildingModel, "FrontPierR", Vector3.new(5.5, 11.0, 1.6), bCF * CFrame.new(9.5, 7.1, 4.5), royalIndigo)
	local archLintel = createStudPart(buildingModel, "FrontArchLintel", Vector3.new(27, 2.2, 2.0), bCF * CFrame.new(0, 12.2, 4.5), woodDark)
	archLintel.Material = Enum.Material.Wood

	-- 4. Jetted Second-Story Starlight Observatory & Balcony
	local loftY = 17.5
	createStudPart(buildingModel, "ObservatoryDeck", Vector3.new(27.4, 1.2, 23.4), bCF * CFrame.new(0, 13.0, -0.5), woodDark)

	-- Overhanging Starlight Balcony at Front
	createStudPart(buildingModel, "BalconyFloor", Vector3.new(18, 0.8, 5.0), bCF * CFrame.new(0, 13.2, 7.5), woodLight)
	-- Golden Balustrade Railing
	createStudPart(buildingModel, "BalconyRailFront", Vector3.new(18.4, 2.2, 0.4), bCF * CFrame.new(0, 14.5, 9.8), goldTrim)
	createStudPart(buildingModel, "BalconyRailL", Vector3.new(0.4, 2.2, 5.0), bCF * CFrame.new(-9.0, 14.5, 7.5), goldTrim)
	createStudPart(buildingModel, "BalconyRailR", Vector3.new(0.4, 2.2, 5.0), bCF * CFrame.new(9.0, 14.5, 7.5), goldTrim)

	-- Second Floor Walls (Deep Astral Purple with Inlaid Gold Stars)
	createStudPart(buildingModel, "ObsBackWall", Vector3.new(26, 8.0, 1.4), bCF * CFrame.new(0, loftY, -12.0), royalIndigo)
	createStudPart(buildingModel, "ObsLeftWall", Vector3.new(1.4, 8.0, 20), bCF * CFrame.new(-12.8, loftY, -2.0), royalIndigo)
	createStudPart(buildingModel, "ObsRightWall", Vector3.new(1.4, 8.0, 20), bCF * CFrame.new(12.8, loftY, -2.0), royalIndigo)
	createStudPart(buildingModel, "ObsFrontWall", Vector3.new(26, 8.0, 1.4), bCF * CFrame.new(0, loftY, 5.0), royalIndigo)

	-- Dual Grand Stained-Glass Rose Windows on Upper Floor
	for rx = -6, 6, 12 do
		local roseWin = createStudPart(buildingModel, "RoseWin_" .. rx, Vector3.new(3.8, 3.8, 1.6), bCF * CFrame.new(rx, loftY + 0.8, 5.1), clothViolet)
		roseWin.Material = Enum.Material.Neon
		roseWin.Shape = Enum.PartType.Cylinder
		roseWin.CFrame = bCF * CFrame.new(rx, loftY + 0.8, 5.1) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- 5. Multi-Tier Curved Pagoda Celestial Roof with Gold Trim
	local roofPeakY = 25.5
	createStudPart(buildingModel, "CanopyRidge", Vector3.new(28.5, 1.8, 2.4), bCF * CFrame.new(0, roofPeakY, -1.0), goldTrim)

	-- Curved Roof Slopes (Tier 1: Royal Violet Slates with Flared Eaves)
	createStudPart(buildingModel, "RoofSlopeBack", Vector3.new(28.5, 0.9, 16.0), bCF * CFrame.new(0, 21.8, -8.0) * CFrame.Angles(math.rad(-32), 0, 0), clothViolet)
	createStudPart(buildingModel, "RoofSlopeFront", Vector3.new(28.5, 0.9, 16.0), bCF * CFrame.new(0, 21.8, 6.0) * CFrame.Angles(math.rad(32), 0, 0), clothViolet)

	-- Upward Curved Eaves Flanges
	createStudPart(buildingModel, "EaveFlangeBack", Vector3.new(29.0, 0.5, 3.5), bCF * CFrame.new(0, 18.2, -15.5) * CFrame.Angles(math.rad(-14), 0, 0), clothCyan)
	createStudPart(buildingModel, "EaveFlangeFront", Vector3.new(29.0, 0.5, 3.5), bCF * CFrame.new(0, 18.2, 13.5) * CFrame.Angles(math.rad(14), 0, 0), clothCyan)

	-- Glowing Gold Neon Roof Perimeter Trim
	local neonTrimF = createStudPart(buildingModel, "NeonTrimFront", Vector3.new(29.2, 0.3, 0.6), bCF * CFrame.new(0, 18.2, 14.8), goldTrim)
	neonTrimF.Material = Enum.Material.Neon
	local neonTrimB = createStudPart(buildingModel, "NeonTrimBack", Vector3.new(29.2, 0.3, 0.6), bCF * CFrame.new(0, 18.2, -16.8), goldTrim)
	neonTrimB.Material = Enum.Material.Neon

	-- Central Roof Spire with Slowly Spinning Brass Astrolabe
	local spireBase = createStudPart(buildingModel, "SpireBase", Vector3.new(2.8, 3.5, 2.8), bCF * CFrame.new(0, roofPeakY + 2.2, -1.0), goldTrim)
	spireBase.Material = Enum.Material.SmoothPlastic
	local astrolabe = createStudPart(buildingModel, "SpinningAstrolabe", Vector3.new(2.4, 2.4, 2.4), bCF * CFrame.new(0, roofPeakY + 4.8, -1.0), goldTrim)
	astrolabe.Material = Enum.Material.Neon
	astrolabe.Shape = Enum.PartType.Ball

	task.spawn(function()
		local rot = 0
		while astrolabe and astrolabe.Parent do
			rot += 0.02
			astrolabe.CFrame = bCF * CFrame.new(0, roofPeakY + 4.8, -1.0) * CFrame.Angles(rot * 0.7, rot, 0)
			task.wait(0.03)
		end
	end)

	-- 6. Outdoor Arcane Porch & Four Floating Elemental Trail Orbs
	-- Glowing Inlaid Summoning Circle on Deck
	local magicCircle = createStudPart(buildingModel, "MagicCircleRune", Vector3.new(8.0, 0.05, 8.0), bCF * CFrame.new(-4.5, 1.42, 10.0), clothCyan)
	magicCircle.Material = Enum.Material.Neon
	magicCircle.Shape = Enum.PartType.Cylinder
	magicCircle.CFrame = bCF * CFrame.new(-4.5, 1.42, 10.0) * CFrame.Angles(0, 0, math.rad(90))

	-- Four Floating Elemental Trail Orbs on Runic Pedestals
	local elementalOrbs = {
		{ name = "CosmicFire", offset = Vector3.new(-10.5, 8.5), color = Color3.fromRGB(255, 80, 20), light = Color3.fromRGB(255, 120, 40) },
		{ name = "FrostBreeze", offset = Vector3.new(-6.5, 13.5), color = Color3.fromRGB(0, 220, 255), light = Color3.fromRGB(100, 240, 255) },
		{ name = "VoidShadow", offset = Vector3.new(6.5, 13.5), color = Color3.fromRGB(175, 45, 235), light = Color3.fromRGB(200, 80, 255) },
		{ name = "SparkBurst", offset = Vector3.new(10.5, 8.5), color = Color3.fromRGB(255, 220, 0), light = Color3.fromRGB(255, 235, 60) },
	}

	for _, orbDef in ipairs(elementalOrbs) do
		-- Carved Runic Stone Pedestal
		createStudPart(buildingModel, "OrbPedestal_" .. orbDef.name, Vector3.new(2.4, 2.2, 2.4), bCF * CFrame.new(orbDef.offset.X, 2.3, orbDef.offset.Y), woodDark)
		createStudPart(buildingModel, "OrbPedCapital_" .. orbDef.name, Vector3.new(2.8, 0.4, 2.8), bCF * CFrame.new(orbDef.offset.X, 3.4, orbDef.offset.Y), goldTrim)

		-- Levitating Elemental Orb
		local eOrb = createStudPart(buildingModel, "Orb_" .. orbDef.name, Vector3.new(1.6, 1.6, 1.6), bCF * CFrame.new(orbDef.offset.X, 4.6, orbDef.offset.Y), orbDef.color)
		eOrb.Material = Enum.Material.Neon
		eOrb.Shape = Enum.PartType.Ball

		local oAtt = Instance.new("Attachment")
		oAtt.Parent = eOrb
		local oSparks = Instance.new("ParticleEmitter")
		oSparks.Name = "OrbSparks"
		oSparks.Color = ColorSequence.new(orbDef.color)
		oSparks.Size = NumberSequence.new(0.3, 0.05)
		oSparks.Rate = 12
		oSparks.Speed = NumberRange.new(0.6, 1.6)
		oSparks.LightEmission = 1.0
		oSparks.Parent = oAtt

		local oLight = Instance.new("PointLight")
		oLight.Color = orbDef.light
		oLight.Brightness = 2.2
		oLight.Range = 14
		oLight.Parent = eOrb

		-- Smooth bobbing animation
		task.spawn(function()
			local startY = eOrb.Position.Y
			local timeAcc = (orbDef.offset.X * 0.3)
			while eOrb and eOrb.Parent do
				timeAcc += 0.04
				local bob = math.sin(timeAcc * 2) * 0.25
				eOrb.CFrame = CFrame.new(eOrb.Position.X, startY + bob, eOrb.Position.Z)
				task.wait(0.03)
			end
		end)
	end

	-- Enchanted Apothecary Potion Cabinet against Right Wall
	createStudPart(buildingModel, "PotionCabinet", Vector3.new(1.4, 6.0, 5.0), bCF * CFrame.new(11.5, 4.2, 7.0), woodDark)
	for p = 1, 4 do
		local botCol = if p == 1 then Color3.fromRGB(255, 60, 20)
			elseif p == 2 then Color3.fromRGB(0, 230, 255)
			elseif p == 3 then Color3.fromRGB(210, 50, 255)
			else Color3.fromRGB(46, 204, 113)
		local bottle = createStudPart(buildingModel, "PotionBottle" .. p, Vector3.new(0.6, 1.2, 0.6), bCF * CFrame.new(11.5, 4.8, 5.2 + (p * 0.9)), botCol)
		bottle.Material = Enum.Material.Neon
	end

	-- Hanging 3D Celestial Crescent Moon Shop Sign
	createStudPart(buildingModel, "MoonBracket", Vector3.new(4.5, 0.4, 0.4), bCF * CFrame.new(11.5, 11.5, 5.0), goldTrim)
	createStudPart(buildingModel, "MoonChainL", Vector3.new(0.15, 1.2, 0.15), bCF * CFrame.new(10.2, 10.8, 5.0), goldTrim)
	createStudPart(buildingModel, "MoonChainR", Vector3.new(0.15, 1.2, 0.15), bCF * CFrame.new(12.8, 10.8, 5.0), goldTrim)
	local signBoard = createStudPart(buildingModel, "TrailSignBoard", Vector3.new(4.0, 2.2, 0.6), bCF * CFrame.new(11.5, 9.6, 5.0), royalIndigo)
	signBoard.Material = Enum.Material.SmoothPlastic

	local signBb = Instance.new("BillboardGui")
	signBb.Size = UDim2.new(0, 160, 0, 60)
	signBb.AlwaysOnTop = false
	signBb.MaxDistance = 45
	signBb.Parent = signBoard
	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(1, 0, 1, 0)
	sLbl.BackgroundTransparency = 1
	sLbl.Text = "✨ TRAILS"
	sLbl.TextColor3 = Color3.fromRGB(0, 240, 255)
	sLbl.Font = Enum.Font.GothamBlack
	sLbl.TextSize = 18
	sLbl.Parent = signBb

	-- 7. Front Service Counter Desk
	createStudPart(buildingModel, "TrailCounterBase", Vector3.new(11.0, 2.8, 2.6), bCF * CFrame.new(1.5, 2.6, 12.0), woodDark)
	createStudPart(buildingModel, "TrailCounterTop", Vector3.new(12.2, 0.5, 3.4), bCF * CFrame.new(1.5, 4.2, 12.0), clothViolet)
	local counterTrim = createStudPart(buildingModel, "TrailCounterTrim", Vector3.new(12.4, 0.15, 3.6), bCF * CFrame.new(1.5, 4.45, 12.0), goldTrim)
	counterTrim.Material = Enum.Material.Neon

	-- 8. ZEPHYR THE TRAIL ARTISAN NPC
	local npcModel = Instance.new("Model")
	npcModel.Name = "ZephyrArtisan"

	local npcCF = bCF * CFrame.new(1.5, 2.4, 9.8)

	local torso = createStudPart(npcModel, "Torso", Vector3.new(2, 2, 1), npcCF * CFrame.new(0, 2.0, 0), Color3.fromRGB(55, 30, 75))
	createStudPart(npcModel, "LeftLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(-0.5, 0.0, 0), Color3.fromRGB(40, 25, 55))
	createStudPart(npcModel, "RightLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(0.5, 0.0, 0), Color3.fromRGB(40, 25, 55))

	local head = createStudPart(npcModel, "Head", Vector3.new(1.25, 1.25, 1.25), npcCF * CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 225, 195), true, Enum.SurfaceType.Smooth)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Celestial Wizard Cowl / Headdress
	createStudPart(npcModel, "Cowl", Vector3.new(1.8, 1.2, 1.8), npcCF * CFrame.new(0, 4.2, 0), clothViolet)
	createStudPart(npcModel, "CowlGem", Vector3.new(0.4, 0.4, 0.4), npcCF * CFrame.new(0, 4.4, 0.95), clothCyan)

	-- Wizard Staff in Hand
	createStudPart(npcModel, "StaffShaft", Vector3.new(0.3, 5.0, 0.3), npcCF * CFrame.new(1.8, 2.5, 0.6), woodDark)
	local staffOrb = createStudPart(npcModel, "StaffOrb", Vector3.new(0.9, 0.9, 0.9), npcCF * CFrame.new(1.8, 5.1, 0.6), clothCyan)
	staffOrb.Material = Enum.Material.Neon
	staffOrb.Shape = Enum.PartType.Ball

	-- Arms resting on counter
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(55, 30, 75))
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(55, 30, 75))

	-- Signboard Overhead Title Billboard
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "ArtisanTitleGui"
	titleGui.Size = UDim2.new(0, 260, 0, 58)
	titleGui.StudsOffset = Vector3.new(0, 3.8, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 70

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "✨ THE TRAIL WEAVER ✨"
	titleLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Zephyr [Aura & Particle Boutique]"
	subtitleLabel.TextColor3 = Color3.fromRGB(235, 185, 255)
	subtitleLabel.Font = Enum.Font.GothamBold
	subtitleLabel.TextSize = 12
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- Invisible Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "ZephyrInteractionPart"
	interactionPart.Size = Vector3.new(12, 6, 6)
	interactionPart.CFrame = bCF * CFrame.new(1.5, 3.6, 14.0)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = buildingModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Zephyr (Trail Artisan)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		print("🗣️ [TownBuildingBuilder] Zephyr triggered by " .. player.Name)
		local dialogueEvent = Remotes.getEvent("OpenShopDialogue")
		dialogueEvent:FireClient(player, "Zephyr")
	end)

	npcModel.Parent = buildingModel
	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 3. THE PET HATCHERY SANCTUARY (Prism Egg & Robux King Egg Shrines)
-- =========================================================================
function TownBuildingBuilder.buildPetSanctuary(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "PetHatcherySanctuary"

	-- Positioned on East/Northeast courtyard, facing -X (toward central spawn plaza)
	local bCF = CFrame.new(38, 0, -18) * CFrame.Angles(0, math.rad(-90), 0)

	local marbleWhite = Color3.fromRGB(242, 245, 250)
	local marbleGrey = Color3.fromRGB(215, 220, 228)
	local goldMetal = Color3.fromRGB(255, 215, 60)
	local obsidian = Color3.fromRGB(26, 28, 34)
	local runeCyan = Color3.fromRGB(0, 220, 255)
	local cosmicPurple = Color3.fromRGB(180, 50, 255)

	-- 1. Tiered Marble Foundation Plinth
	createStudPart(buildingModel, "TemplePlinth1", Vector3.new(22, 1.2, 28), bCF * CFrame.new(0, 0.6, 0), marbleGrey)
	createStudPart(buildingModel, "TemplePlinth2", Vector3.new(20, 0.6, 26), bCF * CFrame.new(0, 1.5, 0), marbleWhite)

	-- 2. Six Fluted Marble Pillars Supporting Open Portico
	local pillarOffsets = {
		Vector3.new(-8.5, 7.5, -11.5),
		Vector3.new(0, 7.5, -11.5),
		Vector3.new(8.5, 7.5, -11.5),
		Vector3.new(-8.5, 7.5, 11.5),
		Vector3.new(0, 7.5, 11.5),
		Vector3.new(8.5, 7.5, 11.5),
	}
	for _, pOff in ipairs(pillarOffsets) do
		createStudPart(buildingModel, "PillarBase", Vector3.new(2.8, 1.2, 2.8), bCF * CFrame.new(pOff.X, 2.4, pOff.Z), marbleGrey)
		local shaft = createStudPart(buildingModel, "PillarShaft", Vector3.new(2.2, 10.0, 2.2), bCF * CFrame.new(pOff.X, 8.0, pOff.Z), marbleWhite)
		shaft.Material = Enum.Material.SmoothPlastic
		createStudPart(buildingModel, "PillarCap", Vector3.new(2.8, 1.2, 2.8), bCF * CFrame.new(pOff.X, 13.6, pOff.Z), goldMetal)
	end

	-- Back & Side Enclosure Walls
	createStudPart(buildingModel, "SanctuaryBackWall", Vector3.new(1.4, 11, 24), bCF * CFrame.new(0, 7.5, -11.5), marbleGrey)
	createStudPart(buildingModel, "SanctuaryWallL", Vector3.new(18, 11, 1.4), bCF * CFrame.new(-8.5, 7.5, 0), marbleGrey)
	createStudPart(buildingModel, "SanctuaryWallR", Vector3.new(18, 11, 1.4), bCF * CFrame.new(8.5, 7.5, 0), marbleGrey)

	-- 3. Classical Triangular Pediment Roof
	createStudPart(buildingModel, "Architrave", Vector3.new(22, 1.4, 28), bCF * CFrame.new(0, 14.8, 0), marbleGrey)
	createStudPart(buildingModel, "PedimentRidge", Vector3.new(22, 1.6, 2.4), bCF * CFrame.new(0, 17.5, 0), goldMetal)
	createStudPart(buildingModel, "RoofSlopeL", Vector3.new(22, 0.8, 15), bCF * CFrame.new(0, 16.2, -7) * CFrame.Angles(math.rad(-20), 0, 0), marbleWhite)
	createStudPart(buildingModel, "RoofSlopeR", Vector3.new(22, 0.8, 15), bCF * CFrame.new(0, 16.2, 7) * CFrame.Angles(math.rad(20), 0, 0), marbleWhite)

	-- Floating Ethereal Sanctuary Crystal atop Roof
	local topCrystal = createStudPart(buildingModel, "SanctuaryCrystal", Vector3.new(2.2, 4.0, 2.2), bCF * CFrame.new(0, 20.5, 0), runeCyan)
	topCrystal.Material = Enum.Material.Neon

	local cryAtt = Instance.new("Attachment")
	cryAtt.Parent = topCrystal

	local crySparks = Instance.new("ParticleEmitter")
	crySparks.Name = "SanctuarySparks"
	crySparks.Color = ColorSequence.new(Color3.fromRGB(180, 245, 255))
	crySparks.Size = NumberSequence.new(0.35, 0.05)
	crySparks.Rate = 12
	crySparks.Speed = NumberRange.new(0.8, 2.0)
	crySparks.LightEmission = 1.0
	crySparks.Parent = cryAtt

	-- Grand Entrance Signboard
	local signPart = createStudPart(buildingModel, "SanctuarySignPart", Vector3.new(16, 2.2, 1.0), bCF * CFrame.new(0, 14.8, 12.0), marbleWhite)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "SanctuaryTitleGui"
	signGui.Size = UDim2.new(0, 320, 0, 60)
	signGui.StudsOffset = Vector3.new(0, 1.5, 0)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 75

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "🥚 PET HATCHERY SANCTUARY 🥚"
	signLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	signLabel.Font = Enum.Font.Antique
	signLabel.TextSize = 22
	signLabel.TextStrokeTransparency = 0.2
	signLabel.Parent = signGui
	signGui.Parent = signPart

	-- =========================================================================
	-- ALCOVE 1: PRISM EGG SHRINE (Left Wing: Z = -5.5 local)
	-- =========================================================================
	local prismCF = bCF * CFrame.new(0, 1.8, -5.5)

	createStudPart(buildingModel, "PrismPedBase", Vector3.new(6.5, 0.6, 6.5), prismCF * CFrame.new(0, 0.3, 0), obsidian)
	createStudPart(buildingModel, "PrismPedCol", Vector3.new(3.6, 2.2, 3.6), prismCF * CFrame.new(0, 1.7, 0), stoneDark)
	createStudPart(buildingModel, "PrismPedCap", Vector3.new(4.8, 0.6, 4.8), prismCF * CFrame.new(0, 3.1, 0), goldMetal)
	local prismBowl = createStudPart(buildingModel, "PrismNestBowl", Vector3.new(4.2, 0.4, 4.2), prismCF * CFrame.new(0, 3.5, 0), obsidian)
	prismBowl.Material = Enum.Material.SmoothPlastic
	local prismCore = createStudPart(buildingModel, "PrismRuneCore", Vector3.new(3.0, 0.25, 3.0), prismCF * CFrame.new(0, 3.75, 0), runeCyan)
	prismCore.Material = Enum.Material.Neon

	-- 3D Prism Egg Part
	local eggPart = Instance.new("Part")
	eggPart.Name = "PrismEggPart"
	eggPart.Size = Vector3.new(2.4, 3.45, 2.4)
	eggPart.CFrame = prismCF * CFrame.new(0, 5.3, 0)
	eggPart.Color = Color3.fromRGB(245, 248, 255)
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = true
	eggPart.CanTouch = true
	eggPart.Parent = buildingModel

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	eggMesh.Parent = eggPart

	local eggLight = Instance.new("PointLight")
	eggLight.Color = runeCyan
	eggLight.Brightness = 2.4
	eggLight.Range = 16
	eggLight.Parent = eggPart

	-- Floating Billboard UI
	local eggGui = Instance.new("BillboardGui")
	eggGui.Name = "EggShrineGui"
	eggGui.Size = UDim2.new(0, 240, 0, 80)
	eggGui.StudsOffset = Vector3.new(0, 3.5, 0)
	eggGui.AlwaysOnTop = false
	eggGui.MaxDistance = 45

	local eggTitle = Instance.new("TextLabel")
	eggTitle.Size = UDim2.new(1, 0, 0.38, 0)
	eggTitle.BackgroundTransparency = 1
	eggTitle.Text = "✨ PRISM EGG ✨"
	eggTitle.TextColor3 = Color3.fromRGB(0, 230, 255)
	eggTitle.Font = Enum.Font.GothamBlack
	eggTitle.TextSize = 16
	eggTitle.TextStrokeTransparency = 0.2
	eggTitle.Parent = eggGui

	local eggSub = Instance.new("TextLabel")
	eggSub.Size = UDim2.new(1, 0, 0.32, 0)
	eggSub.Position = UDim2.new(0, 0, 0.38, 0)
	eggSub.BackgroundTransparency = 1
	eggSub.Text = "[E] 1x (100 💎)  •  [F] 3x (300 💎)"
	eggSub.TextColor3 = Color3.fromRGB(255, 255, 255)
	eggSub.Font = Enum.Font.GothamBold
	eggSub.TextSize = 13
	eggSub.TextStrokeTransparency = 0.2
	eggSub.Parent = eggGui

	local eggChances = Instance.new("TextLabel")
	eggChances.Size = UDim2.new(1, 0, 0.30, 0)
	eggChances.Position = UDim2.new(0, 0, 0.70, 0)
	eggChances.BackgroundTransparency = 1
	eggChances.Text = "🐶 Dog 40% • 🐱 Cat 35% • 🦊 Fox 20% • 🐉 Dragon 5%"
	eggChances.TextColor3 = Color3.fromRGB(210, 230, 255)
	eggChances.Font = Enum.Font.GothamMedium
	eggChances.TextSize = 10
	eggChances.TextStrokeTransparency = 0.25
	eggChances.Parent = eggGui
	eggGui.Parent = eggPart

	-- Prompts for 1x and 3x Hatch
	local leftPart = Instance.new("Part")
	leftPart.Name = "EggInteractionPart_Left"
	leftPart.Size = Vector3.new(3.2, 5, 4)
	leftPart.CFrame = prismCF * CFrame.new(-2.2, 2.8, 1.2)
	leftPart.Transparency = 1
	leftPart.CanCollide = false
	leftPart.CanTouch = true
	leftPart.CanQuery = true
	leftPart.Anchored = true
	leftPart.Parent = buildingModel

	local rightPart = Instance.new("Part")
	rightPart.Name = "EggInteractionPart_Right"
	rightPart.Size = Vector3.new(3.2, 5, 4)
	rightPart.CFrame = prismCF * CFrame.new(2.2, 2.8, 1.2)
	rightPart.Transparency = 1
	rightPart.CanCollide = false
	rightPart.CanTouch = true
	rightPart.CanQuery = true
	rightPart.Anchored = true
	rightPart.Parent = buildingModel

	local prompt1 = Instance.new("ProximityPrompt")
	prompt1.Name = "Hatch1Prompt"
	prompt1.ActionText = "Hatch 1x"
	prompt1.ObjectText = "Prism Egg (100 💎)"
	prompt1.KeyboardKeyCode = Enum.KeyCode.E
	prompt1.HoldDuration = 0
	prompt1.MaxActivationDistance = 14
	prompt1.RequiresLineOfSight = false
	prompt1.ClickablePrompt = true
	prompt1.Parent = leftPart

	local prompt3 = Instance.new("ProximityPrompt")
	prompt3.Name = "Hatch3Prompt"
	prompt3.ActionText = "Hatch 3x"
	prompt3.ObjectText = "Prism Egg (300 💎)"
	prompt3.KeyboardKeyCode = Enum.KeyCode.F
	prompt3.HoldDuration = 0
	prompt3.MaxActivationDistance = 14
	prompt3.RequiresLineOfSight = false
	prompt3.ClickablePrompt = true
	prompt3.Parent = rightPart

	local lastHatchTime: { [Player]: number } = {}
	prompt1.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then return end
		lastHatchTime[player] = now
		PetService.hatchEgg(player, "BasicEgg", 1)
	end)

	prompt3.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.35 then return end
		lastHatchTime[player] = now
		PetService.hatchEgg(player, "BasicEgg", 3)
	end)

	-- =========================================================================
	-- ALCOVE 2: ROBUX KING EGG SHRINE (Right Wing: Z = +5.5 local)
	-- =========================================================================
	local robuxCF = bCF * CFrame.new(0, 1.8, 5.5)

	createStudPart(buildingModel, "RobuxPedBase", Vector3.new(6.5, 0.6, 6.5), robuxCF * CFrame.new(0, 0.3, 0), obsidian)
	createStudPart(buildingModel, "RobuxPedCol", Vector3.new(3.6, 2.2, 3.6), robuxCF * CFrame.new(0, 1.7, 0), obsidian)
	createStudPart(buildingModel, "RobuxPedCap", Vector3.new(4.8, 0.6, 4.8), robuxCF * CFrame.new(0, 3.1, 0), goldMetal)
	local robuxBowl = createStudPart(buildingModel, "RobuxNestBowl", Vector3.new(4.2, 0.4, 4.2), robuxCF * CFrame.new(0, 3.5, 0), obsidian)
	robuxBowl.Material = Enum.Material.SmoothPlastic
	local robuxCore = createStudPart(buildingModel, "RobuxRuneCore", Vector3.new(3.0, 0.25, 3.0), robuxCF * CFrame.new(0, 3.75, 0), cosmicPurple)
	robuxCore.Material = Enum.Material.Neon

	-- 3D Robux King Egg Part
	local rEggPart = Instance.new("Part")
	rEggPart.Name = "RobuxEggPart"
	rEggPart.Size = Vector3.new(2.4, 3.45, 2.4)
	rEggPart.CFrame = robuxCF * CFrame.new(0, 5.3, 0)
	rEggPart.Color = Color3.fromRGB(255, 215, 60)
	rEggPart.Material = Enum.Material.SmoothPlastic
	rEggPart.Anchored = true
	rEggPart.CanCollide = true
	rEggPart.CanTouch = true
	rEggPart.Parent = buildingModel

	local rMesh = Instance.new("SpecialMesh")
	rMesh.MeshType = Enum.MeshType.Sphere
	rMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	rMesh.Parent = rEggPart

	local rLight = Instance.new("PointLight")
	rLight.Color = cosmicPurple
	rLight.Brightness = 2.8
	rLight.Range = 16
	rLight.Parent = rEggPart

	-- Robux Billboard UI
	local rEggGui = Instance.new("BillboardGui")
	rEggGui.Name = "RobuxEggGui"
	rEggGui.Size = UDim2.new(0, 250, 0, 80)
	rEggGui.StudsOffset = Vector3.new(0, 3.5, 0)
	rEggGui.AlwaysOnTop = false
	rEggGui.MaxDistance = 45

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(1, 0, 0.38, 0)
	rTitle.BackgroundTransparency = 1
	rTitle.Text = "👑 EXCLUSIVE KING EGG 👑"
	rTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	rTitle.Font = Enum.Font.GothamBlack
	rTitle.TextSize = 16
	rTitle.TextStrokeTransparency = 0.2
	rTitle.Parent = rEggGui

	local rSub = Instance.new("TextLabel")
	rSub.Size = UDim2.new(1, 0, 0.32, 0)
	rSub.Position = UDim2.new(0, 0, 0.38, 0)
	rSub.BackgroundTransparency = 1
	rSub.Text = "[E] Hatch for R$ 1,000"
	rSub.TextColor3 = Color3.fromRGB(255, 255, 255)
	rSub.Font = Enum.Font.GothamBold
	rSub.TextSize = 13
	rSub.TextStrokeTransparency = 0.2
	rSub.Parent = rEggGui

	local rChances = Instance.new("TextLabel")
	rChances.Size = UDim2.new(1, 0, 0.30, 0)
	rChances.Position = UDim2.new(0, 0, 0.70, 0)
	rChances.BackgroundTransparency = 1
	rChances.Text = "🐰 Bunny 50% • 🔥 Drake 35% • 🌌 Phoenix 15%"
	rChances.TextColor3 = Color3.fromRGB(255, 235, 180)
	rChances.Font = Enum.Font.GothamMedium
	rChances.TextSize = 10
	rChances.TextStrokeTransparency = 0.25
	rChances.Parent = rEggGui
	rEggGui.Parent = rEggPart

	local rInteract = Instance.new("Part")
	rInteract.Name = "RobuxEggInteractionPart"
	rInteract.Size = Vector3.new(5, 5, 5)
	rInteract.CFrame = robuxCF * CFrame.new(0, 2.8, 1.2)
	rInteract.Transparency = 1
	rInteract.CanCollide = false
	rInteract.CanTouch = true
	rInteract.CanQuery = true
	rInteract.Anchored = true
	rInteract.Parent = buildingModel

	local rPrompt = Instance.new("ProximityPrompt")
	rPrompt.Name = "RobuxHatchPrompt"
	rPrompt.ActionText = "Hatch"
	rPrompt.ObjectText = "Exclusive Egg (R$ 1,000)"
	rPrompt.KeyboardKeyCode = Enum.KeyCode.E
	rPrompt.HoldDuration = 0
	rPrompt.MaxActivationDistance = 14
	rPrompt.RequiresLineOfSight = false
	rPrompt.ClickablePrompt = true
	rPrompt.Parent = rInteract

	rPrompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastHatchTime[player] and (now - lastHatchTime[player]) < 0.4 then return end
		lastHatchTime[player] = now
		local robuxModalEvent = Remotes.getEvent("OpenRobuxPurchaseModal")
		robuxModalEvent:FireClient(player, "Pet_King")
	end)

	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 4. THE ALCHEMICAL FUSION LABORATORY (Pet Fusion Machine)
-- =========================================================================
function TownBuildingBuilder.buildFusionLab(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "AlchemicalFusionLab"

	-- Positioned on East/Southeast courtyard, facing -X (toward central spawn plaza)
	local bCF = CFrame.new(38, 0, 18) * CFrame.Angles(0, math.rad(-90), 0)

	local stoneDark = Color3.fromRGB(38, 42, 52)
	local stoneWall = Color3.fromRGB(64, 68, 78)
	local goldMetal = Color3.fromRGB(255, 215, 60)
	local copperPipes = Color3.fromRGB(205, 120, 50)
	local runeCyan = Color3.fromRGB(0, 220, 255)
	local rainbowMagenta = Color3.fromRGB(255, 90, 210)

	-- 1. Stepped Alchemical Foundation
	createStudPart(buildingModel, "Foundation", Vector3.new(22, 1.2, 22), bCF * CFrame.new(0, 0.6, 0), stoneDark)
	createStudPart(buildingModel, "PlinthStep", Vector3.new(20, 0.6, 20), bCF * CFrame.new(0, 1.5, 0), stoneWall)

	-- 2. Massive Reinforced Stone Columns & Laboratory Walls
	local colOffsets = {
		Vector3.new(-8.8, 6.6, -8.8),
		Vector3.new(8.8, 6.6, -8.8),
		Vector3.new(-8.8, 6.6, 8.8),
		Vector3.new(8.8, 6.6, 8.8),
	}
	for _, cOff in ipairs(colOffsets) do
		createStudPart(buildingModel, "LabCol", Vector3.new(2.4, 11, 2.4), bCF * CFrame.new(cOff.X, cOff.Y, cOff.Z), stoneDark)
	end

	createStudPart(buildingModel, "BackWall", Vector3.new(1.4, 10, 16), bCF * CFrame.new(0, 6.2, -8.8), stoneWall)
	createStudPart(buildingModel, "LeftWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(-8.8, 6.2, 0), stoneWall)
	createStudPart(buildingModel, "RightWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(8.8, 6.2, 0), stoneWall)

	-- Brass / Copper Alchemical Pipes on Walls
	createStudPart(buildingModel, "CopperPipe1", Vector3.new(14, 0.8, 0.8), bCF * CFrame.new(0, 8.5, -8.0), copperPipes)
	createStudPart(buildingModel, "CopperPipe2", Vector3.new(0.8, 0.8, 14), bCF * CFrame.new(-8.0, 8.5, 0), copperPipes)

	-- 3. Slanted Laboratory Roof with Central Mana Dome
	createStudPart(buildingModel, "RoofRidge", Vector3.new(22, 1.4, 2.2), bCF * CFrame.new(0, 13.5, 0), stoneDark)
	createStudPart(buildingModel, "RoofSlopeBack", Vector3.new(22, 0.8, 12), bCF * CFrame.new(0, 12.2, -5.5) * CFrame.Angles(math.rad(-20), 0, 0), stoneDark)
	createStudPart(buildingModel, "RoofSlopeFront", Vector3.new(22, 0.8, 12), bCF * CFrame.new(0, 12.2, 5.5) * CFrame.Angles(math.rad(20), 0, 0), stoneDark)

	-- Glowing Mana Dome Spire
	local manaDome = createStudPart(buildingModel, "ManaDome", Vector3.new(4.5, 2.5, 4.5), bCF * CFrame.new(0, 15.0, 0), runeCyan)
	manaDome.Material = Enum.Material.Neon
	manaDome.Shape = Enum.PartType.Ball

	-- Grand Overhead Signboard
	local signPart = createStudPart(buildingModel, "LabSignPart", Vector3.new(16, 2.2, 1.0), bCF * CFrame.new(0, 11.5, 9.5), stoneDark)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "LabTitleGui"
	signGui.Size = UDim2.new(0, 300, 0, 60)
	signGui.StudsOffset = Vector3.new(0, 1.5, 0)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 75

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "⚗️ ALCHEMY LAB ⚗️"
	signLabel.TextColor3 = Color3.fromRGB(0, 240, 180)
	signLabel.Font = Enum.Font.Antique
	signLabel.TextSize = 22
	signLabel.TextStrokeTransparency = 0.2
	signLabel.Parent = signGui
	signGui.Parent = signPart

	-- 4. THE PET FUSION MACHINE (Center of Chamber)
	local fusionCF = bCF * CFrame.new(0, 1.8, 0)

	-- Concentric Glowing Rune Circles
	local baseDais = createStudPart(buildingModel, "FusionBaseDais", Vector3.new(9.0, 0.6, 9.0), fusionCF * CFrame.new(0, 0.3, 0), stoneDark)
	local goldRing = createStudPart(buildingModel, "GoldRuneRing", Vector3.new(6.8, 0.15, 6.8), fusionCF * CFrame.new(0, 0.68, 0), goldMetal)
	goldRing.Material = Enum.Material.Neon
	goldRing.CanCollide = false
	local cyanRing = createStudPart(buildingModel, "CyanRuneRing", Vector3.new(4.8, 0.18, 4.8), fusionCF * CFrame.new(0, 0.70, 0), runeCyan)
	cyanRing.Material = Enum.Material.Neon
	cyanRing.CanCollide = false

	-- 4 Corner Tesla / Mana Coils
	local coilOffsets = {
		Vector3.new(-3.4, 2.0, -3.4),
		Vector3.new(3.4, 2.0, -3.4),
		Vector3.new(-3.4, 2.0, 3.4),
		Vector3.new(3.4, 2.0, 3.4),
	}
	for _, cOff in ipairs(coilOffsets) do
		createStudPart(buildingModel, "CoilBase", Vector3.new(1.2, 2.8, 1.2), fusionCF * CFrame.new(cOff.X, 1.4, cOff.Z), stoneDark)
		local coilTop = createStudPart(buildingModel, "CoilTop", Vector3.new(1.4, 1.4, 1.4), fusionCF * CFrame.new(cOff.X, 3.2, cOff.Z), runeCyan)
		coilTop.Material = Enum.Material.Neon
		coilTop.Shape = Enum.PartType.Ball
	end

	-- Floating Transmutation Flask Sphere
	local reactorCore = createStudPart(buildingModel, "ReactorCore", Vector3.new(2.4, 2.4, 2.4), fusionCF * CFrame.new(0, 3.6, 0), rainbowMagenta)
	reactorCore.Material = Enum.Material.Neon
	reactorCore.Shape = Enum.PartType.Ball

	local rAtt = Instance.new("Attachment")
	rAtt.Parent = reactorCore

	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "FusionRainbowSparks"
	sparkEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 220)),
	})
	sparkEmitter.Size = NumberSequence.new(0.35, 0.05)
	sparkEmitter.Rate = 18
	sparkEmitter.Speed = NumberRange.new(1.0, 2.5)
	sparkEmitter.LightEmission = 1.0
	sparkEmitter.Parent = rAtt

	local coreLight = Instance.new("PointLight")
	coreLight.Color = rainbowMagenta
	coreLight.Brightness = 3.0
	coreLight.Range = 20
	coreLight.Parent = reactorCore

	-- Billboard UI
	local fusionGui = Instance.new("BillboardGui")
	fusionGui.Name = "FusionBillboard"
	fusionGui.Size = UDim2.new(0, 260, 0, 75)
	fusionGui.StudsOffset = Vector3.new(0, 3.5, 0)
	fusionGui.AlwaysOnTop = false
	fusionGui.MaxDistance = 45

	local fTitle = Instance.new("TextLabel")
	fTitle.Size = UDim2.new(1, 0, 0.40, 0)
	fTitle.BackgroundTransparency = 1
	fTitle.Text = "🌟 PET FUSION STATION 🌟"
	fTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	fTitle.Font = Enum.Font.GothamBlack
	fTitle.TextSize = 16
	fTitle.TextStrokeTransparency = 0.2
	fTitle.Parent = fusionGui

	local fSub = Instance.new("TextLabel")
	fSub.Size = UDim2.new(1, 0, 0.32, 0)
	fSub.Position = UDim2.new(0, 0, 0.40, 0)
	fSub.BackgroundTransparency = 1
	fSub.Text = "[E] Open Fusion Station"
	fSub.TextColor3 = Color3.fromRGB(0, 240, 180)
	fSub.Font = Enum.Font.GothamBold
	fSub.TextSize = 13
	fSub.TextStrokeTransparency = 0.2
	fSub.Parent = fusionGui

	local fDesc = Instance.new("TextLabel")
	fDesc.Size = UDim2.new(1, 0, 0.28, 0)
	fDesc.Position = UDim2.new(0, 0, 0.72, 0)
	fDesc.BackgroundTransparency = 1
	fDesc.Text = "3 Pets ➔ Golden (3x)  •  3 Gold ➔ Rainbow (9x)"
	fDesc.TextColor3 = Color3.fromRGB(230, 235, 250)
	fDesc.Font = Enum.Font.GothamMedium
	fDesc.TextSize = 10
	fDesc.TextStrokeTransparency = 0.25
	fDesc.Parent = fusionGui
	fusionGui.Parent = reactorCore

	-- Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "FusionInteractionPart"
	interactionPart.Size = Vector3.new(8, 6, 8)
	interactionPart.CFrame = fusionCF * CFrame.new(0, 2.8, 1.5)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = buildingModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FusionPrompt"
	prompt.ActionText = "Fuse Pets"
	prompt.ObjectText = "Pet Fusion Machine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	local lastTriggerTime: { [Player]: number } = {}
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastTriggerTime[player] and (now - lastTriggerTime[player]) < 0.4 then return end
		lastTriggerTime[player] = now

		print("⚗️ [TownBuildingBuilder] Fusion ProximityPrompt triggered by " .. player.Name)
		local openFusionEvent = Remotes.getEvent("OpenFusionModal")
		openFusionEvent:FireClient(player)
	end)

	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 5. THE ROYAL VIP PAVILION & TREASURY (VIP Throne + Dev Cheat Pad)
-- =========================================================================
function TownBuildingBuilder.buildVIPPavilion(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "RoyalVIPPavilion"

	-- Positioned due East on Royal Hilltop Terrace, facing -X (facing central spawn plaza)
	local bCF = CFrame.new(62, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)

	local goldMetal = Color3.fromRGB(255, 215, 60)
	local royalPurple = Color3.fromRGB(110, 25, 180)
	local marbleWhite = Color3.fromRGB(245, 246, 250)
	local marbleGrey = Color3.fromRGB(210, 215, 225)
	local royalRed = Color3.fromRGB(185, 25, 45)

	-- Royal Red Carpet Walkway Approach from East Courtyard
	local carpet = createStudPart(buildingModel, "VIPRedCarpet", Vector3.new(12, 0.1, 4.0), bCF * CFrame.new(0, 0.45, 12.0), royalRed)
	carpet.Material = Enum.Material.Fabric
	createStudPart(buildingModel, "VIPCarpetTrimL", Vector3.new(12, 0.15, 0.4), bCF * CFrame.new(0, 0.48, 14.1), goldMetal)
	createStudPart(buildingModel, "VIPCarpetTrimR", Vector3.new(12, 0.15, 0.4), bCF * CFrame.new(0, 0.48, 9.9), goldMetal)

	-- 1. Raised Gilded Marble Terrace
	createStudPart(buildingModel, "PavilionPlinth1", Vector3.new(20, 1.2, 22), bCF * CFrame.new(0, 0.6, 0), marbleGrey)
	createStudPart(buildingModel, "PavilionPlinth2", Vector3.new(18, 0.6, 20), bCF * CFrame.new(0, 1.5, 0), marbleWhite)

	-- 2. Four Golden Roman Columns
	local colOffsets = {
		Vector3.new(-6.8, 6.5, -7.8),
		Vector3.new(6.8, 6.5, -7.8),
		Vector3.new(-6.8, 6.5, 7.8),
		Vector3.new(6.8, 6.5, 7.8),
	}
	for _, cOff in ipairs(colOffsets) do
		local col = createStudPart(buildingModel, "GoldenCol", Vector3.new(2.2, 10.0, 2.2), bCF * CFrame.new(cOff.X, cOff.Y, cOff.Z), goldMetal)
		col.Material = Enum.Material.SmoothPlastic
	end

	-- 3. Royal Purple Velvet Canopy Roof with Golden Crest
	createStudPart(buildingModel, "CanopyBase", Vector3.new(18, 1.2, 20), bCF * CFrame.new(0, 12.0, 0), royalPurple)
	createStudPart(buildingModel, "CanopyDome", Vector3.new(12, 2.5, 14), bCF * CFrame.new(0, 13.5, 0), goldMetal)

	-- Signboard
	local signPart = createStudPart(buildingModel, "VIPSignPart", Vector3.new(14, 2.0, 0.8), bCF * CFrame.new(0, 11.5, 8.8), goldMetal)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "VIPTitleGui"
	signGui.Size = UDim2.new(0, 280, 0, 56)
	signGui.StudsOffset = Vector3.new(0, 1.5, 0)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 65

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "👑 ROYAL VIP PAVILION 👑"
	signLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	signLabel.Font = Enum.Font.Antique
	signLabel.TextSize = 22
	signLabel.TextStrokeTransparency = 0.2
	signLabel.Parent = signGui
	signGui.Parent = signPart

	-- =========================================================================
	-- THE VIP GOLDEN THRONE
	-- =========================================================================
	local throneCF = bCF * CFrame.new(0, 1.8, -1.5)

	createStudPart(buildingModel, "VIPPedBase", Vector3.new(7.0, 0.6, 7.0), throneCF * CFrame.new(0, 0.3, 0), marbleGrey)
	createStudPart(buildingModel, "VIPPedStep", Vector3.new(5.8, 0.5, 5.8), throneCF * CFrame.new(0, 0.85, 0), goldMetal)
	local velvetRune = createStudPart(buildingModel, "VIPVelvetRune", Vector3.new(4.6, 0.2, 4.6), throneCF * CFrame.new(0, 1.2, 0), royalPurple)
	velvetRune.Material = Enum.Material.SmoothPlastic

	-- Golden Royal Throne
	local throneSeat = createStudPart(buildingModel, "ThroneSeat", Vector3.new(3.0, 1.2, 2.6), throneCF * CFrame.new(0, 1.9, -0.2), goldMetal)
	throneSeat.Material = Enum.Material.SmoothPlastic
	local cushion = createStudPart(buildingModel, "ThroneCushion", Vector3.new(2.6, 0.4, 2.2), throneCF * CFrame.new(0, 2.6, -0.2), Color3.fromRGB(180, 40, 160))
	cushion.Material = Enum.Material.Fabric

	-- High Golden Crown Backrest
	local backrest = createStudPart(buildingModel, "ThroneBackrest", Vector3.new(3.0, 4.5, 0.8), throneCF * CFrame.new(0, 4.4, -1.1), goldMetal)
	backrest.Material = Enum.Material.SmoothPlastic
	local crownTop = createStudPart(buildingModel, "ThroneCrown", Vector3.new(3.4, 1.4, 0.9), throneCF * CFrame.new(0, 6.8, -1.1), goldMetal)
	crownTop.Material = Enum.Material.Neon

	-- Throne Sparkle particles
	local tAtt = Instance.new("Attachment")
	tAtt.Parent = crownTop

	local tSparks = Instance.new("ParticleEmitter")
	tSparks.Name = "ThroneSparks"
	tSparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80))
	tSparks.Size = NumberSequence.new(0.3, 0.05)
	tSparks.Rate = 10
	tSparks.Speed = NumberRange.new(0.6, 1.8)
	tSparks.LightEmission = 1.0
	tSparks.Parent = tAtt

	local tLight = Instance.new("PointLight")
	tLight.Color = goldMetal
	tLight.Brightness = 2.4
	tLight.Range = 16
	tLight.Parent = crownTop

	-- VIP Billboard
	local vipGui = Instance.new("BillboardGui")
	vipGui.Name = "VIPShrineGui"
	vipGui.Size = UDim2.new(0, 240, 0, 75)
	vipGui.StudsOffset = Vector3.new(0, 4.2, 0)
	vipGui.AlwaysOnTop = false
	vipGui.MaxDistance = 45

	local vTitle = Instance.new("TextLabel")
	vTitle.Size = UDim2.new(1, 0, 0.38, 0)
	vTitle.BackgroundTransparency = 1
	vTitle.Text = "👑 VIP THRONE 👑"
	vTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	vTitle.Font = Enum.Font.GothamBlack
	vTitle.TextSize = 16
	vTitle.TextStrokeTransparency = 0.2
	vTitle.Parent = vipGui

	local vCost = Instance.new("TextLabel")
	vCost.Size = UDim2.new(1, 0, 0.32, 0)
	vCost.Position = UDim2.new(0, 0, 0.38, 0)
	vCost.BackgroundTransparency = 1
	vCost.Text = "[E] View VIP Perks (400 R$)"
	vCost.TextColor3 = Color3.fromRGB(255, 255, 255)
	vCost.Font = Enum.Font.GothamBold
	vCost.TextSize = 13
	vCost.TextStrokeTransparency = 0.2
	vCost.Parent = vipGui

	local vPerks = Instance.new("TextLabel")
	vPerks.Size = UDim2.new(1, 0, 0.30, 0)
	vPerks.Position = UDim2.new(0, 0, 0.70, 0)
	vPerks.BackgroundTransparency = 1
	vPerks.Text = "💎 2x Gems Forever  •  👑 Golden [VIP] Tag"
	vPerks.TextColor3 = Color3.fromRGB(255, 235, 180)
	vPerks.Font = Enum.Font.GothamMedium
	vPerks.TextSize = 10
	vPerks.TextStrokeTransparency = 0.25
	vPerks.Parent = vipGui
	vipGui.Parent = throneSeat

	-- Interaction Part & Proximity Prompt
	local vInteract = Instance.new("Part")
	vInteract.Name = "VIPInteractionPart"
	vInteract.Size = Vector3.new(6, 6, 6)
	vInteract.CFrame = throneCF * CFrame.new(0, 2.8, 1.2)
	vInteract.Transparency = 1
	vInteract.CanCollide = false
	vInteract.CanTouch = true
	vInteract.CanQuery = true
	vInteract.Anchored = true
	vInteract.Parent = buildingModel

	local vPrompt = Instance.new("ProximityPrompt")
	vPrompt.Name = "VIPPurchasePrompt"
	vPrompt.ActionText = "View Perks"
	vPrompt.ObjectText = "VIP Pass (400 R$)"
	vPrompt.KeyboardKeyCode = Enum.KeyCode.E
	vPrompt.HoldDuration = 0
	vPrompt.MaxActivationDistance = 14
	vPrompt.RequiresLineOfSight = false
	vPrompt.ClickablePrompt = true
	vPrompt.Parent = vInteract

	local lastPromptTime: { [Player]: number } = {}
	vPrompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastPromptTime[player] and (now - lastPromptTime[player]) < 0.4 then return end
		lastPromptTime[player] = now

		print("👑 [TownBuildingBuilder] VIP ProximityPrompt triggered by " .. player.Name)
		local openVipEvent = Remotes.getEvent("OpenVIPModal")
		openVipEvent:FireClient(player)
	end)

	-- =========================================================================
	-- THE GOLDEN DEV CHEAT PAD (Beside the VIP Pavilion)
	-- =========================================================================
	local devPadDais = createStudPart(buildingModel, "DevDais", Vector3.new(8.5, 0.6, 8.5), bCF * CFrame.new(0, 0.4, 7.5), marbleGrey)

	local devPad = Instance.new("Part")
	devPad.Name = "DevCheatPad"
	devPad.Size = Vector3.new(6.5, 0.5, 6.5)
	devPad.CFrame = bCF * CFrame.new(0, 0.95, 7.5)
	devPad.Color = goldMetal
	devPad.Material = Enum.Material.Neon
	devPad.TopSurface = Enum.SurfaceType.Studs
	devPad.BottomSurface = Enum.SurfaceType.Inlet
	devPad.Anchored = true
	devPad.CanCollide = true
	devPad.CanTouch = true
	devPad.Parent = buildingModel

	local padGui = Instance.new("BillboardGui")
	padGui.Name = "DevPadGui"
	padGui.Size = UDim2.new(0, 240, 0, 56)
	padGui.StudsOffset = Vector3.new(0, 3.5, 0)
	padGui.AlwaysOnTop = false
	padGui.MaxDistance = 45

	local padTitle = Instance.new("TextLabel")
	padTitle.Size = UDim2.new(1, 0, 0.5, 0)
	padTitle.BackgroundTransparency = 1
	padTitle.Text = "⚡ DEV CHEAT PAD ⚡"
	padTitle.TextColor3 = goldMetal
	padTitle.Font = Enum.Font.GothamBlack
	padTitle.TextSize = 15
	padTitle.TextStrokeTransparency = 0.2
	padTitle.Parent = padGui

	local padSubtitle = Instance.new("TextLabel")
	padSubtitle.Size = UDim2.new(1, 0, 0.5, 0)
	padSubtitle.Position = UDim2.new(0, 0, 0.5, 0)
	padSubtitle.BackgroundTransparency = 1
	padSubtitle.Text = "Touch for +$10,000,000 & +50K 💎"
	padSubtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	padSubtitle.Font = Enum.Font.GothamBold
	padSubtitle.TextSize = 12
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

	-- =========================================================================
	-- PHYSICAL DEV METEOR SUMMONER CONSOLE
	-- =========================================================================
	local meteorConsoleCF = bCF * CFrame.new(0, 0.4, 12.0)
	createStudPart(buildingModel, "MeteorConsoleBase", Vector3.new(4.0, 0.6, 4.0), meteorConsoleCF * CFrame.new(0, 0.3, 0), marbleGrey)
	createStudPart(buildingModel, "MeteorConsoleCol", Vector3.new(2.2, 3.2, 2.2), meteorConsoleCF * CFrame.new(0, 2.2, 0), Color3.fromRGB(36, 32, 40))

	-- Glowing Fiery Meteor Core Sphere
	local meteorOrb = Instance.new("Part")
	meteorOrb.Name = "DevMeteorOrb"
	meteorOrb.Size = Vector3.new(2.4, 2.4, 2.4)
	meteorOrb.Shape = Enum.PartType.Ball
	meteorOrb.CFrame = meteorConsoleCF * CFrame.new(0, 4.8, 0)
	meteorOrb.Color = Color3.fromRGB(255, 80, 15)
	meteorOrb.Material = Enum.Material.Neon
	meteorOrb.Anchored = true
	meteorOrb.CanCollide = false
	meteorOrb.Parent = buildingModel

	local mLight = Instance.new("PointLight")
	mLight.Color = Color3.fromRGB(255, 120, 30)
	mLight.Brightness = 3.0
	mLight.Range = 16
	mLight.Parent = meteorOrb

	local mAtt = Instance.new("Attachment")
	mAtt.Parent = meteorOrb

	local mSparks = Instance.new("ParticleEmitter")
	mSparks.Name = "OrbFlames"
	mSparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60))
	mSparks.Size = NumberSequence.new(0.35, 0.05)
	mSparks.Rate = 12
	mSparks.Speed = NumberRange.new(1.0, 2.5)
	mSparks.Parent = mAtt

	local mGui = Instance.new("BillboardGui")
	mGui.Name = "MeteorConsoleGui"
	mGui.Size = UDim2.new(0, 240, 0, 56)
	mGui.StudsOffset = Vector3.new(0, 2.6, 0)
	mGui.AlwaysOnTop = false
	mGui.MaxDistance = 50

	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(1, 0, 0.5, 0)
	mTitle.BackgroundTransparency = 1
	mTitle.Text = "☄️ DEV METEOR CONSOLE ☄️"
	mTitle.TextColor3 = Color3.fromRGB(255, 110, 40)
	mTitle.Font = Enum.Font.GothamBlack
	mTitle.TextSize = 14
	mTitle.TextStrokeTransparency = 0.2
	mTitle.Parent = mGui

	local mSub = Instance.new("TextLabel")
	mSub.Size = UDim2.new(1, 0, 0.5, 0)
	mSub.Position = UDim2.new(0, 0, 0.5, 0)
	mSub.BackgroundTransparency = 1
	mSub.Text = "[E] Summon Meteor Event"
	mSub.TextColor3 = Color3.fromRGB(255, 255, 255)
	mSub.Font = Enum.Font.GothamBold
	mSub.TextSize = 12
	mSub.TextStrokeTransparency = 0.2
	mSub.Parent = mGui
	mGui.Parent = meteorOrb

	local mPrompt = Instance.new("ProximityPrompt")
	mPrompt.Name = "SummonMeteorPrompt"
	mPrompt.ActionText = "Summon Meteor"
	mPrompt.ObjectText = "Dev World Event"
	mPrompt.KeyboardKeyCode = Enum.KeyCode.E
	mPrompt.HoldDuration = 0
	mPrompt.MaxActivationDistance = 14
	mPrompt.RequiresLineOfSight = false
	mPrompt.ClickablePrompt = true
	mPrompt.Parent = meteorOrb

	local lastSummonTime: { [Player]: number } = {}
	mPrompt.Triggered:Connect(function(player)
		local now = os.clock()
		if lastSummonTime[player] and (now - lastSummonTime[player]) < 1.0 then return end
		lastSummonTime[player] = now

		print(string.format("☄️ [TownBuildingBuilder] Dev Meteor Summoner triggered by %s!", player.Name))
		local ok, MeteorService = pcall(function()
			return require(script.Parent.MeteorService)
		end)
		if ok and MeteorService then
			MeteorService.startCountdown()
		end
	end)

	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 6. THE PET EXCHANGE (Finneas the Eccentric Pet Merchant)
-- =========================================================================
function TownBuildingBuilder.buildPetMerchantStall(parent: Instance): Model
	local buildingModel = Instance.new("Model")
	buildingModel.Name = "PetMerchantStall"

	-- Positioned on East courtyard at (38, 0, 0), facing -X (toward Town Plaza / Spawn)
	local bCF = CFrame.new(38, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)

	local stoneDark = Color3.fromRGB(45, 48, 55)
	local stonePaving = Color3.fromRGB(72, 75, 84)
	local tudorWood = Color3.fromRGB(58, 36, 20)
	local tudorPlaster = Color3.fromRGB(238, 230, 214)
	local mahoganyCounter = Color3.fromRGB(98, 52, 28)
	local roofEmerald = Color3.fromRGB(28, 105, 65)
	local roofGold = Color3.fromRGB(235, 185, 40)
	local goldBrass = Color3.fromRGB(255, 215, 60)
	local velvetRed = Color3.fromRGB(160, 32, 45)
	local windowGlow = Color3.fromRGB(255, 205, 110)
	local crystalCyan = Color3.fromRGB(0, 230, 255)

	-- 1. Raised Heavy Stone Plinth & Stepped Terrace (28 x 1.4 x 26)
	createStudPart(buildingModel, "Foundation", Vector3.new(28, 1.4, 26), bCF * CFrame.new(0, 0.7, 0), stoneDark)
	createStudPart(buildingModel, "PavedDeck", Vector3.new(26.4, 0.4, 24.4), bCF * CFrame.new(0, 1.4, 0), stonePaving)

	-- Stepped stone entrance threshold leading to the courtyard
	for s = 1, 2 do
		createStudPart(buildingModel, "EntranceStep_" .. s, Vector3.new(14, 0.35, 2.0), bCF * CFrame.new(0, 0.35 * s, 12.5 + (2.0 * (2 - s))), stoneDark)
	end

	-- Flanking Porch Stone Balustrades with Polished Railing
	for _, side in ipairs({ -1, 1 }) do
		local balustrade = createStudPart(buildingModel, "PorchBalustrade_" .. side, Vector3.new(1.4, 2.6, 7.0), bCF * CFrame.new(side * 12.5, 2.7, 8.5), stoneDark)
		balustrade.Material = Enum.Material.Cobblestone
		local balCap = createStudPart(buildingModel, "BalustradeCap_" .. side, Vector3.new(1.8, 0.5, 7.4), bCF * CFrame.new(side * 12.5, 4.15, 8.5), stonePaving)
		balCap.Material = Enum.Material.SmoothPlastic
		local newelPost = createStudPart(buildingModel, "NewelPost_" .. side, Vector3.new(2.0, 3.2, 2.0), bCF * CFrame.new(side * 12.5, 3.0, 12.0), stoneDark)
		newelPost.Material = Enum.Material.Cobblestone
		local postBall = createStudPart(buildingModel, "NewelFinial_" .. side, Vector3.new(1.5, 1.5, 1.5), bCF * CFrame.new(side * 12.5, 5.0, 12.0), goldBrass)
		postBall.Shape = Enum.PartType.Ball
		postBall.Material = Enum.Material.SmoothPlastic
	end

	-- 2. Heavy Timber Columns & Stone Buttresses at 4 Corners
	local colOffsets = {
		Vector3.new(-12.5, 7.0, -11.5),
		Vector3.new(12.5, 7.0, -11.5),
		Vector3.new(-12.5, 7.0, 11.5),
		Vector3.new(12.5, 7.0, 11.5),
	}
	for _, cOff in ipairs(colOffsets) do
		local buttress = createStudPart(buildingModel, "CornerButtress", Vector3.new(3.2, 4.0, 3.2), bCF * CFrame.new(cOff.X, 3.4, cOff.Z), stoneDark)
		buttress.Material = Enum.Material.Cobblestone
		local col = createStudPart(buildingModel, "TudorCornerPost", Vector3.new(2.4, 12.0, 2.4), bCF * CFrame.new(cOff.X, 8.4, cOff.Z), tudorWood)
		col.Material = Enum.Material.Wood
	end

	-- 3. Ground Floor Tudor Masonry Walls & Projecting Bay Windows
	-- Back Wall
	createStudPart(buildingModel, "BackWall", Vector3.new(24, 11.0, 1.6), bCF * CFrame.new(0, 7.1, -11.5), stoneDark)
	-- Left Wall with Projecting Bay Window
	createStudPart(buildingModel, "LeftWall", Vector3.new(1.6, 11.0, 16), bCF * CFrame.new(-12.5, 7.1, -2.5), stoneDark)
	local lBayWindow = createStudPart(buildingModel, "LeftBayWindow", Vector3.new(2.4, 4.2, 4.5), bCF * CFrame.new(-13.0, 7.5, -2.5), windowGlow)
	lBayWindow.Material = Enum.Material.Neon
	local lBayRoof = createStudPart(buildingModel, "LeftBayRoof", Vector3.new(2.8, 0.8, 5.2), bCF * CFrame.new(-13.0, 9.8, -2.5), tudorWood)
	lBayRoof.Material = Enum.Material.Wood

	-- Right Wall with Projecting Bay Window
	createStudPart(buildingModel, "RightWall", Vector3.new(1.6, 11.0, 16), bCF * CFrame.new(12.5, 7.1, -2.5), stoneDark)
	local rBayWindow = createStudPart(buildingModel, "RightBayWindow", Vector3.new(2.4, 4.2, 4.5), bCF * CFrame.new(13.0, 7.5, -2.5), windowGlow)
	rBayWindow.Material = Enum.Material.Neon
	local rBayRoof = createStudPart(buildingModel, "RightBayRoof", Vector3.new(2.8, 0.8, 5.2), bCF * CFrame.new(13.0, 9.8, -2.5), tudorWood)
	rBayRoof.Material = Enum.Material.Wood

	-- Front Ground Facade: Stately Double Entrance Door behind Counter
	createStudPart(buildingModel, "BackEntryWall", Vector3.new(24, 11.0, 1.6), bCF * CFrame.new(0, 7.1, 0), stoneDark)
	local doorFrame = createStudPart(buildingModel, "DoorFrame", Vector3.new(5.0, 8.2, 2.0), bCF * CFrame.new(0, 5.7, 0.1), tudorWood)
	doorFrame.Material = Enum.Material.Wood
	local doorPanel = createStudPart(buildingModel, "DoorPanel", Vector3.new(4.2, 7.6, 0.4), bCF * CFrame.new(0, 5.5, 0.8), Color3.fromRGB(42, 25, 15))
	doorPanel.Material = Enum.Material.WoodPlanks
	-- Brass Door Knocker Rings
	for _, dx in ipairs({ -1.0, 1.0 }) do
		local knocker = createStudPart(buildingModel, "Knocker", Vector3.new(0.5, 0.8, 0.3), bCF * CFrame.new(dx, 5.5, 1.1), goldBrass)
		knocker.Material = Enum.Material.SmoothPlastic
	end

	-- Flanking Front Lanterns
	for _, lx in ipairs({ -3.6, 3.6 }) do
		createStudPart(buildingModel, "LanternBracket", Vector3.new(0.4, 0.4, 1.4), bCF * CFrame.new(lx, 7.5, 1.0), Color3.fromRGB(30, 30, 35))
		local lLamp = createStudPart(buildingModel, "LanternGlass", Vector3.new(0.9, 1.4, 0.9), bCF * CFrame.new(lx, 7.2, 1.8), Color3.fromRGB(255, 200, 100))
		lLamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 120)
		light.Brightness = 1.8
		light.Range = 16
		light.Parent = lLamp
	end

	-- 4. Jetted Second-Story (Tudor Timber Framing & Balcony)
	-- Decorative Carved Wooden Corbels supporting the cantilevered second floor
	local corbelX = { -11.5, -6.5, 0, 6.5, 11.5 }
	for _, cx in ipairs(corbelX) do
		local corbel = createStudPart(buildingModel, "CorbelFront", Vector3.new(1.2, 2.2, 2.0), bCF * CFrame.new(cx, 12.0, 2.0), tudorWood)
		corbel.Material = Enum.Material.Wood
	end
	for _, cz in ipairs({ -9.0, -3.0, 3.0, 9.0 }) do
		local corbelL = createStudPart(buildingModel, "CorbelLeft", Vector3.new(2.0, 2.2, 1.2), bCF * CFrame.new(-12.0, 12.0, cz), tudorWood)
		corbelL.Material = Enum.Material.Wood
		local corbelR = createStudPart(buildingModel, "CorbelRight", Vector3.new(2.0, 2.2, 1.2), bCF * CFrame.new(12.0, 12.0, cz), tudorWood)
		corbelR.Material = Enum.Material.Wood
	end

	-- Jetted Floor Overhang Beam (29.6 x 1.4 x 28.0)
	local jettedBeam = createStudPart(buildingModel, "JettedBeam", Vector3.new(29.6, 1.4, 27.6), bCF * CFrame.new(0, 13.2, 0), tudorWood)
	jettedBeam.Material = Enum.Material.Wood

	-- Second Story Plaster Core Walls (loftY = 17.5)
	local loftY = 17.5
	local loftCore = createStudPart(buildingModel, "LoftCore", Vector3.new(26.4, 7.5, 24.4), bCF * CFrame.new(0, loftY, 0), tudorPlaster)
	loftCore.Material = Enum.Material.SmoothPlastic

	-- Tudor Half-Timber Framing (Vertical Studs & Mid-Rail Belt)
	local midRail = createStudPart(buildingModel, "TudorMidRail", Vector3.new(27.2, 0.8, 25.2), bCF * CFrame.new(0, loftY, 0), tudorWood)
	midRail.Material = Enum.Material.Wood

	-- 4 Corner Posts on 2nd floor
	for _, cOff in ipairs(colOffsets) do
		local upperPost = createStudPart(buildingModel, "UpperCornerPost", Vector3.new(2.0, 8.0, 2.0), bCF * CFrame.new(cOff.X * 1.04, loftY, cOff.Z * 1.04), tudorWood)
		upperPost.Material = Enum.Material.Wood
	end

	-- Front Tudor Timber X-Braces (authentic medieval motif)
	local xOffsets = { -7.0, 7.0 }
	for _, xx in ipairs(xOffsets) do
		local brace1 = createStudPart(buildingModel, "TudorBrace1", Vector3.new(0.6, 7.2, 0.6), bCF * CFrame.new(xx, loftY, 12.3) * CFrame.Angles(0, 0, math.rad(38)), tudorWood)
		brace1.Material = Enum.Material.Wood
		local brace2 = createStudPart(buildingModel, "TudorBrace2", Vector3.new(0.6, 7.2, 0.6), bCF * CFrame.new(xx, loftY, 12.3) * CFrame.Angles(0, 0, math.rad(-38)), tudorWood)
		brace2.Material = Enum.Material.Wood
	end

	-- Second Story Front Guild Balcony (overhanging the front veranda)
	local balDeck = createStudPart(buildingModel, "BalconyDeck", Vector3.new(12.0, 0.6, 4.2), bCF * CFrame.new(0, 14.0, 13.8), tudorWood)
	balDeck.Material = Enum.Material.WoodPlanks
	local balRailF = createStudPart(buildingModel, "BalconyRailF", Vector3.new(12.0, 2.2, 0.6), bCF * CFrame.new(0, 15.2, 15.6), tudorWood)
	balRailF.Material = Enum.Material.Wood
	local balRailL = createStudPart(buildingModel, "BalconyRailL", Vector3.new(0.6, 2.2, 3.8), bCF * CFrame.new(-5.7, 15.2, 13.8), tudorWood)
	balRailL.Material = Enum.Material.Wood
	local balRailR = createStudPart(buildingModel, "BalconyRailR", Vector3.new(0.6, 2.2, 3.8), bCF * CFrame.new(5.7, 15.2, 13.8), tudorWood)
	balRailR.Material = Enum.Material.Wood

	-- Balcony Flower Planters with Blooming Flowers
	local flowerBox = createStudPart(buildingModel, "FlowerBox", Vector3.new(10.0, 0.8, 1.0), bCF * CFrame.new(0, 15.2, 16.0), Color3.fromRGB(110, 65, 35))
	flowerBox.Material = Enum.Material.Wood
	local foliage = createStudPart(buildingModel, "BalconyFoliage", Vector3.new(9.6, 0.6, 0.8), bCF * CFrame.new(0, 15.8, 16.0), Color3.fromRGB(45, 140, 50))
	foliage.Material = Enum.Material.Grass
	-- Colorful flower blossom studs
	local flowerColors = { Color3.fromRGB(255, 100, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(180, 100, 240), Color3.fromRGB(255, 140, 40) }
	for fx = -4, 4, 2 do
		local flower = createStudPart(buildingModel, "Blossom", Vector3.new(0.7, 0.5, 0.7), bCF * CFrame.new(fx, 16.3, 16.0), flowerColors[(math.abs(fx) % 4) + 1])
		flower.Material = Enum.Material.SmoothPlastic
	end

	-- Hanging Brass Birdcage suspended beneath balcony with tiny golden canary
	createStudPart(buildingModel, "CageRod", Vector3.new(0.2, 2.0, 0.2), bCF * CFrame.new(0, 12.5, 13.5), goldBrass)
	local cageDome = createStudPart(buildingModel, "CageDome", Vector3.new(1.8, 2.2, 1.8), bCF * CFrame.new(0, 10.5, 13.5), goldBrass)
	cageDome.Material = Enum.Material.Glass
	cageDome.Transparency = 0.4
	local canary = createStudPart(buildingModel, "GoldenCanary", Vector3.new(0.6, 0.6, 0.8), bCF * CFrame.new(0, 10.5, 13.5), Color3.fromRGB(255, 225, 40))
	canary.Material = Enum.Material.SmoothPlastic

	-- Second Story Windows (Triple Leaded Casement Windows)
	for _, wx in ipairs({ -2.6, 0, 2.6 }) do
		local win = createStudPart(buildingModel, "UpperWindow_" .. wx, Vector3.new(1.8, 3.4, 0.4), bCF * CFrame.new(wx, 17.5, 12.3), windowGlow)
		win.Material = Enum.Material.Neon
		local winFrame = createStudPart(buildingModel, "UpperWinFrame_" .. wx, Vector3.new(2.2, 3.8, 0.6), bCF * CFrame.new(wx, 17.5, 12.3), tudorWood)
		winFrame.Material = Enum.Material.Wood
	end

	-- 5. Steep Tudor Emerald & Gold Gable Roof Structure
	-- Roof Gables (Front & Back Triangular Peaks)
	for _, gz in ipairs({ -12.3, 12.3 }) do
		for tier = 1, 4 do
			local gw = 26 - (tier * 5.8)
			local gy = 21.0 + (tier * 1.3)
			local gable = createStudPart(buildingModel, "GableTier", Vector3.new(gw, 1.4, 1.0), bCF * CFrame.new(0, gy, gz), tudorPlaster)
			gable.Material = Enum.Material.SmoothPlastic
		end
		-- Carved Dark Wood Bargeboard Trim
		createStudPart(buildingModel, "GableTrimL", Vector3.new(1.0, 10.0, 1.4), bCF * CFrame.new(-7.0, 24.0, gz) * CFrame.Angles(0, 0, math.rad(-42)), tudorWood)
		createStudPart(buildingModel, "GableTrimR", Vector3.new(1.0, 10.0, 1.4), bCF * CFrame.new(7.0, 24.0, gz) * CFrame.Angles(0, 0, math.rad(42)), tudorWood)
	end

	-- Main Sloped Roof Pitches (Emerald Green Slate Tiles)
	local roofSlopeL = createStudPart(buildingModel, "RoofSlopeL", Vector3.new(1.4, 16.2, 28.0), bCF * CFrame.new(-7.8, 24.5, 0) * CFrame.Angles(0, 0, math.rad(-44)), roofEmerald)
	roofSlopeL.Material = Enum.Material.Slate
	local roofSlopeR = createStudPart(buildingModel, "RoofSlopeR", Vector3.new(1.4, 16.2, 28.0), bCF * CFrame.new(7.8, 24.5, 0) * CFrame.Angles(0, 0, math.rad(44)), roofEmerald)
	roofSlopeR.Material = Enum.Material.Slate

	-- Heavy Gold Ridge Cap Beam
	local ridgeCap = createStudPart(buildingModel, "RoofRidgeCap", Vector3.new(2.8, 1.2, 29.0), bCF * CFrame.new(0, 29.8, 0), roofGold)
	ridgeCap.Material = Enum.Material.SmoothPlastic

	-- Roof Ridge Finials (Front and Back brass finials)
	for _, fz in ipairs({ -14.2, 14.2 }) do
		local finial = createStudPart(buildingModel, "RidgeFinial", Vector3.new(1.0, 3.2, 1.0), bCF * CFrame.new(0, 31.2, fz), goldBrass)
		finial.Material = Enum.Material.SmoothPlastic
	end

	-- Center Front Attic Dormer with Diamond Light
	createStudPart(buildingModel, "DormerBase", Vector3.new(6.0, 3.5, 4.0), bCF * CFrame.new(0, 24.8, 8.0), tudorPlaster)
	createStudPart(buildingModel, "DormerRoofL", Vector3.new(0.8, 4.2, 4.6), bCF * CFrame.new(-2.2, 26.8, 8.0) * CFrame.Angles(0, 0, math.rad(-38)), roofEmerald)
	createStudPart(buildingModel, "DormerRoofR", Vector3.new(0.8, 4.2, 4.6), bCF * CFrame.new(2.2, 26.8, 8.0) * CFrame.Angles(0, 0, math.rad(38)), roofEmerald)
	local dormerWin = createStudPart(buildingModel, "DormerWindow", Vector3.new(2.4, 2.2, 0.4), bCF * CFrame.new(0, 25.0, 10.1), windowGlow)
	dormerWin.Material = Enum.Material.Neon

	-- 3D Golden Weathervane atop Center Roof Ridge Spire
	createStudPart(buildingModel, "WV_Spire", Vector3.new(0.4, 4.2, 0.4), bCF * CFrame.new(0, 32.2, 0), goldBrass)
	local wvOrb = createStudPart(buildingModel, "WV_Orb", Vector3.new(1.2, 1.2, 1.2), bCF * CFrame.new(0, 33.6, 0), goldBrass)
	wvOrb.Shape = Enum.PartType.Ball
	-- Compass Directional Cross Arms
	createStudPart(buildingModel, "WV_ArmNS", Vector3.new(0.25, 0.25, 3.6), bCF * CFrame.new(0, 33.6, 0), goldBrass)
	createStudPart(buildingModel, "WV_ArmEW", Vector3.new(3.6, 0.25, 0.25), bCF * CFrame.new(0, 33.6, 0), goldBrass)
	-- Golden Silhouette Mascot (Finneas's Proud Golden Rooster)
	local wvMascot = createStudPart(buildingModel, "WV_Mascot", Vector3.new(0.3, 1.8, 2.4), bCF * CFrame.new(0, 35.0, 0), goldBrass)
	wvMascot.Material = Enum.Material.SmoothPlastic

	-- Side Red Brick / Fieldstone Chimney
	createStudPart(buildingModel, "ChimneyBase", Vector3.new(3.6, 28.0, 3.6), bCF * CFrame.new(13.4, 15.0, -3.5), Color3.fromRGB(130, 52, 42))
	local chimCap = createStudPart(buildingModel, "ChimneyCap", Vector3.new(4.2, 0.8, 4.2), bCF * CFrame.new(13.4, 29.4, -3.5), stoneDark)
	chimCap.Material = Enum.Material.Cobblestone
	local chimPot = createStudPart(buildingModel, "ChimneyPot", Vector3.new(1.6, 2.0, 1.6), bCF * CFrame.new(13.4, 30.6, -3.5), Color3.fromRGB(160, 68, 52))
	local chimSmoke = Instance.new("Smoke")
	chimSmoke.Color = Color3.fromRGB(225, 225, 230)
	chimSmoke.Size = 1.4
	chimSmoke.RiseVelocity = 3.5
	chimSmoke.Opacity = 0.25
	chimSmoke.Parent = chimPot

	-- 6. Front Covered Veranda & Grand Pet Exchange Counter
	-- Front Porch Canopy (Striped Emerald & Gold scalloped valence trim)
	for s = -9, 9 do
		local stripeColor = (math.abs(s) % 2 == 0) and roofEmerald or roofGold
		local val = createStudPart(buildingModel, "Valence_" .. s, Vector3.new(1.1, 1.2, 0.4), bCF * CFrame.new(s * 1.15, 12.8, 11.8), stripeColor)
		val.Material = Enum.Material.Fabric
	end

	-- Grand Curved Mahogany Exchange Counter (Vector3.new(15, 3.2, 2.6))
	local counter = createStudPart(buildingModel, "Counter", Vector3.new(15.0, 3.2, 2.6), bCF * CFrame.new(0, 2.8, 5.2), mahoganyCounter)
	counter.Material = Enum.Material.WoodPlanks
	local counterTop = createStudPart(buildingModel, "CounterTop", Vector3.new(16.4, 0.5, 3.4), bCF * CFrame.new(0, 4.5, 5.2), tudorWood)
	counterTop.Material = Enum.Material.Wood

	-- Counter Props:
	-- A. 3D Dual-Pan Brass Balance Scale
	createStudPart(buildingModel, "ScaleBase", Vector3.new(1.4, 0.35, 1.4), bCF * CFrame.new(-4.2, 4.8, 5.2), goldBrass)
	createStudPart(buildingModel, "ScalePillar", Vector3.new(0.35, 1.8, 0.35), bCF * CFrame.new(-4.2, 5.7, 5.2), goldBrass)
	createStudPart(buildingModel, "ScaleBeam", Vector3.new(2.8, 0.25, 0.25), bCF * CFrame.new(-4.2, 6.5, 5.2), goldBrass)
	for _, pX in ipairs({ -5.4, -3.0 }) do
		createStudPart(buildingModel, "ScaleCord", Vector3.new(0.1, 0.8, 0.1), bCF * CFrame.new(pX, 6.0, 5.2), goldBrass)
		local pan = createStudPart(buildingModel, "ScalePan", Vector3.new(1.0, 0.15, 1.0), bCF * CFrame.new(pX, 5.5, 5.2), goldBrass)
		pan.Shape = Enum.PartType.Cylinder
	end

	-- B. Rich Leather Gold Coin Pouches & Stacked Gold Coins
	local coinBag1 = createStudPart(buildingModel, "CoinBag1", Vector3.new(1.4, 1.2, 1.4), bCF * CFrame.new(-1.8, 5.2, 5.2), Color3.fromRGB(160, 110, 45))
	coinBag1.Material = Enum.Material.Fabric
	local coinBag2 = createStudPart(buildingModel, "CoinBag2", Vector3.new(1.0, 0.9, 1.0), bCF * CFrame.new(-2.6, 5.0, 5.4), Color3.fromRGB(180, 130, 55))
	coinBag2.Material = Enum.Material.Fabric
	-- Gold coin stack studs
	for ci = 1, 3 do
		local coin = createStudPart(buildingModel, "GoldCoin_" .. ci, Vector3.new(0.7, 0.2, 0.7), bCF * CFrame.new(-1.4, 4.7 + (ci * 0.2), 5.5), goldBrass)
		coin.Shape = Enum.PartType.Cylinder
	end

	-- C. Merchant's Open Ledger Register Book on Wooden Easel
	createStudPart(buildingModel, "LedgerEasel", Vector3.new(1.6, 0.4, 1.4), bCF * CFrame.new(2.2, 4.9, 5.2) * CFrame.Angles(math.rad(22), 0, 0), tudorWood)
	createStudPart(buildingModel, "LedgerPageL", Vector3.new(0.9, 0.15, 1.2), bCF * CFrame.new(1.8, 5.1, 5.2) * CFrame.Angles(math.rad(22), math.rad(-10), 0), Color3.fromRGB(245, 240, 225))
	createStudPart(buildingModel, "LedgerPageR", Vector3.new(0.9, 0.15, 1.2), bCF * CFrame.new(2.6, 5.1, 5.2) * CFrame.Angles(math.rad(22), math.rad(10), 0), Color3.fromRGB(245, 240, 225))
	createStudPart(buildingModel, "QuillPen", Vector3.new(0.15, 0.9, 0.15), bCF * CFrame.new(3.2, 5.2, 5.1) * CFrame.Angles(math.rad(-15), 0, math.rad(25)), Color3.fromRGB(230, 230, 240))

	-- D. Glass Jars with Colorful Pet Treats
	local jar1 = createStudPart(buildingModel, "TreatJar1", Vector3.new(1.0, 1.4, 1.0), bCF * CFrame.new(4.5, 5.3, 5.2), Color3.fromRGB(200, 240, 255))
	jar1.Material = Enum.Material.Glass
	jar1.Transparency = 0.4
	createStudPart(buildingModel, "DogBoneTreat", Vector3.new(0.7, 0.3, 0.3), bCF * CFrame.new(4.5, 5.1, 5.2), Color3.fromRGB(240, 230, 210))

	-- 7. Porch Pet Amenities & Props
	-- A. Deluxe Multi-Tier Cat Scratching Tree (Left Porch)
	local catTreeBase = createStudPart(buildingModel, "CatTreeBase", Vector3.new(3.2, 0.4, 3.2), bCF * CFrame.new(-9.5, 1.8, 6.0), Color3.fromRGB(120, 80, 45))
	catTreeBase.Material = Enum.Material.Wood
	local catPost1 = createStudPart(buildingModel, "CatPost1", Vector3.new(0.9, 5.2, 0.9), bCF * CFrame.new(-9.5, 4.4, 6.0), Color3.fromRGB(190, 170, 130))
	catPost1.Material = Enum.Material.Fabric -- Sisal rope look
	local perch1 = createStudPart(buildingModel, "Perch1", Vector3.new(2.4, 0.4, 2.4), bCF * CFrame.new(-9.5, 5.2, 6.0), Color3.fromRGB(35, 135, 125))
	perch1.Material = Enum.Material.Fabric
	local catPost2 = createStudPart(buildingModel, "CatPost2", Vector3.new(0.7, 3.2, 0.7), bCF * CFrame.new(-9.5, 7.0, 6.0), Color3.fromRGB(190, 170, 130))
	catPost2.Material = Enum.Material.Fabric
	local perch2 = createStudPart(buildingModel, "Perch2", Vector3.new(2.0, 0.4, 2.0), bCF * CFrame.new(-9.5, 8.7, 6.0), Color3.fromRGB(35, 135, 125))
	perch2.Material = Enum.Material.Fabric
	-- Dangling Cat Toy Ball
	local toyBall = createStudPart(buildingModel, "ToyBall", Vector3.new(0.6, 0.6, 0.6), bCF * CFrame.new(-8.6, 7.8, 6.0), Color3.fromRGB(255, 90, 90))
	toyBall.Shape = Enum.PartType.Ball

	-- B. Luxury Wicker Pet Bed with Sleeping Golden Pup (Right Porch)
	local petBedRing = createStudPart(buildingModel, "PetBedRing", Vector3.new(3.4, 0.8, 3.4), bCF * CFrame.new(9.5, 1.9, 6.0), Color3.fromRGB(150, 100, 55))
	petBedRing.Material = Enum.Material.Wood
	local cushion = createStudPart(buildingModel, "BedCushion", Vector3.new(2.8, 0.5, 2.8), bCF * CFrame.new(9.5, 2.1, 6.0), velvetRed)
	cushion.Material = Enum.Material.Fabric
	local sleepingPup = createStudPart(buildingModel, "SleepingPup", Vector3.new(1.6, 1.0, 1.8), bCF * CFrame.new(9.5, 2.7, 6.0), Color3.fromRGB(240, 195, 80))
	sleepingPup.Material = Enum.Material.SmoothPlastic
	local pupEars = createStudPart(buildingModel, "PupEars", Vector3.new(1.8, 0.4, 0.6), bCF * CFrame.new(9.5, 3.2, 5.7), Color3.fromRGB(210, 160, 60))
	pupEars.Material = Enum.Material.SmoothPlastic

	-- C. Stack of Exotic Wooden Pet Travel Crates & Burlap Kibble Sacks
	local cratePositions = {
		{ pos = Vector3.new(-9.5, 2.4, 2.0), sz = Vector3.new(2.8, 2.4, 2.8), col = Color3.fromRGB(140, 95, 55) },
		{ pos = Vector3.new(-9.5, 4.6, 2.0), sz = Vector3.new(2.4, 2.0, 2.4), col = Color3.fromRGB(160, 110, 65) },
		{ pos = Vector3.new(9.5, 2.4, 2.0), sz = Vector3.new(2.8, 2.4, 2.8), col = Color3.fromRGB(130, 85, 48) },
	}
	for _, cr in ipairs(cratePositions) do
		local crate = createStudPart(buildingModel, "PetTravelCrate", cr.sz, bCF * CFrame.new(cr.pos.X, cr.pos.Y, cr.pos.Z), cr.col)
		crate.Material = Enum.Material.Wood
		local bracket = createStudPart(buildingModel, "CrateBracket", Vector3.new(cr.sz.X + 0.1, 0.3, cr.sz.Z + 0.1), bCF * CFrame.new(cr.pos.X, cr.pos.Y, cr.pos.Z), goldBrass)
		bracket.Material = Enum.Material.SmoothPlastic
	end
	-- Burlap Kibble Sacks tied with string
	for _, sx in ipairs({ 8.0, 9.5 }) do
		local sack = createStudPart(buildingModel, "KibbleSack", Vector3.new(1.6, 1.8, 1.6), bCF * CFrame.new(sx, 2.2, 9.5), Color3.fromRGB(190, 160, 115))
		sack.Material = Enum.Material.Fabric
	end

	-- 8. THE LIVE "MARKET MOOD CRYSTAL" MONUMENT
	-- A magnificent magical attraction indicating Finneas's fluctuating market mind!
	createStudPart(buildingModel, "CrystalPedestalBase", Vector3.new(2.8, 0.8, 2.8), bCF * CFrame.new(-6.2, 1.8, 10.5), stoneDark)
	local pedShaft = createStudPart(buildingModel, "CrystalPedestalShaft", Vector3.new(2.0, 2.4, 2.0), bCF * CFrame.new(-6.2, 3.2, 10.5), stonePaving)
	pedShaft.Material = Enum.Material.Cobblestone
	local pedCap = createStudPart(buildingModel, "CrystalPedestalCap", Vector3.new(2.4, 0.5, 2.4), bCF * CFrame.new(-6.2, 4.6, 10.5), goldBrass)
	pedCap.Material = Enum.Material.SmoothPlastic

	-- 3D Faceted Glowing Mood Crystal hovering above the pedestal
	local moodCrystal = createStudPart(buildingModel, "MarketMoodCrystal", Vector3.new(1.6, 2.4, 1.6), bCF * CFrame.new(-6.2, 6.2, 10.5), crystalCyan)
	moodCrystal.Material = Enum.Material.Neon
	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = crystalCyan
	crystalLight.Brightness = 2.2
	crystalLight.Range = 14
	crystalLight.Parent = moodCrystal

	local crystalSparkles = Instance.new("Sparkles")
	crystalSparkles.SparkleColor = crystalCyan
	crystalSparkles.Parent = moodCrystal

	-- Gentle Bobbing / Rotation script for the Mood Crystal
	task.spawn(function()
		local originCF = bCF * CFrame.new(-6.2, 6.2, 10.5)
		local t = 0
		while moodCrystal and moodCrystal.Parent do
			t += 0.03
			moodCrystal.CFrame = originCF * CFrame.new(0, math.sin(t * 2.0) * 0.25, 0) * CFrame.Angles(0, t * 1.5, math.sin(t) * 0.1)
			task.wait(0.03)
		end
	end)

	-- 9. 3D ORNATE HANGING GUILD SIGN (Extending from front-left post)
	local signArm = createStudPart(buildingModel, "SignBracket", Vector3.new(0.4, 0.4, 4.2), bCF * CFrame.new(-12.5, 11.2, 13.6), Color3.fromRGB(35, 38, 45))
	signArm.Material = Enum.Material.Metal
	local signBoard = createStudPart(buildingModel, "GuildSignBoard", Vector3.new(0.4, 3.2, 4.0), bCF * CFrame.new(-12.5, 9.2, 13.6), Color3.fromRGB(52, 32, 18))
	signBoard.Material = Enum.Material.Wood
	local signBorder = createStudPart(buildingModel, "GuildSignBorder", Vector3.new(0.5, 3.4, 4.2), bCF * CFrame.new(-12.5, 9.2, 13.6), goldBrass)
	signBorder.Material = Enum.Material.SmoothPlastic
	-- 3D Golden Paw Emblem in relief on the sign
	for _, sFace in ipairs({ -0.28, 0.28 }) do
		local pawPad = createStudPart(buildingModel, "SignPawPad", Vector3.new(0.15, 1.0, 1.2), bCF * CFrame.new(-12.5 + sFace, 8.9, 13.6), goldBrass)
		pawPad.Shape = Enum.PartType.Cylinder
		pawPad.Material = Enum.Material.SmoothPlastic
		for _, tx in ipairs({ -0.5, 0, 0.5 }) do
			local toe = createStudPart(buildingModel, "SignPawToe", Vector3.new(0.12, 0.45, 0.45), bCF * CFrame.new(-12.5 + sFace, 9.8, 13.6 + tx), goldBrass)
			toe.Shape = Enum.PartType.Ball
			toe.Material = Enum.Material.SmoothPlastic
		end
	end

	-- 10. FINNEAS THE PET MERCHANT NPC (Behind the Counter)
	local npcModel = Instance.new("Model")
	npcModel.Name = "FinneasMerchant"

	local npcCF = bCF * CFrame.new(0, 1.4, 2.5) -- Standing behind counter facing +Z local

	local torso = createStudPart(npcModel, "Torso", Vector3.new(2, 2, 1), npcCF * CFrame.new(0, 3.0, 0), roofEmerald)
	createStudPart(npcModel, "LeftLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(-0.5, 1.0, 0), Color3.fromRGB(35, 38, 46))
	createStudPart(npcModel, "RightLeg", Vector3.new(1, 2, 1), npcCF * CFrame.new(0.5, 1.0, 0), Color3.fromRGB(35, 38, 46))

	-- Crisp White Cravat / Collar & Golden Vest Buttons
	local cravat = createStudPart(npcModel, "Cravat", Vector3.new(0.9, 0.7, 0.15), npcCF * CFrame.new(0, 3.6, 0.52), Color3.fromRGB(248, 248, 252))
	cravat.Material = Enum.Material.SmoothPlastic
	for bi = 1, 3 do
		local btn = createStudPart(npcModel, "VestButton_" .. bi, Vector3.new(0.2, 0.2, 0.1), npcCF * CFrame.new(0, 3.2 - (bi * 0.4), 0.52), goldBrass)
		btn.Shape = Enum.PartType.Ball
		btn.Material = Enum.Material.SmoothPlastic
	end

	local head = createStudPart(npcModel, "Head", Vector3.new(1.25, 1.25, 1.25), npcCF * CFrame.new(0, 4.4, 0), Color3.fromRGB(255, 215, 175), true, Enum.SurfaceType.Smooth)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Aristocratic Monocle on Finneas's Right Eye
	local monocleRing = createStudPart(npcModel, "MonocleRing", Vector3.new(0.45, 0.45, 0.15), npcCF * CFrame.new(0.32, 4.45, 0.65), goldBrass)
	monocleRing.Material = Enum.Material.SmoothPlastic
	local monocleLens = createStudPart(npcModel, "MonocleLens", Vector3.new(0.35, 0.35, 0.1), npcCF * CFrame.new(0.32, 4.45, 0.65), Color3.fromRGB(200, 240, 255))
	monocleLens.Material = Enum.Material.Glass
	monocleLens.Transparency = 0.3

	-- Stylish Merchant Top Hat with Gold Band
	createStudPart(npcModel, "HatBrim", Vector3.new(2.6, 0.35, 2.6), npcCF * CFrame.new(0, 5.15, 0), Color3.fromRGB(28, 32, 40))
	createStudPart(npcModel, "HatBand", Vector3.new(1.7, 0.4, 1.7), npcCF * CFrame.new(0, 5.45, 0), roofGold)
	createStudPart(npcModel, "HatCrown", Vector3.new(1.6, 1.4, 1.6), npcCF * CFrame.new(0, 6.15, 0), Color3.fromRGB(28, 32, 40))

	-- Arms resting eagerly on counter
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 3.0, 0.5) * CFrame.Angles(math.rad(28), 0, 0), roofEmerald)
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 3.0, 0.5) * CFrame.Angles(math.rad(28), 0, 0), roofEmerald)

	-- 11. Signboard Overhead Title Billboard (With Live "Mind Changes" Counter)
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "FinneasBillboard"
	titleGui.Size = UDim2.new(0, 320, 0, 90)
	titleGui.StudsOffset = Vector3.new(0, 5.2, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 80

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 28)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🐾 FINNEAS THE PET MERCHANT 🐾"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 16
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, 0, 0, 26)
	timerLabel.Position = UDim2.new(0, 0, 0, 28)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "🧠 Mind changes in: 60s"
	timerLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = 13
	timerLabel.TextStrokeTransparency = 0.2
	timerLabel.Parent = titleGui

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Size = UDim2.new(1, 0, 0, 24)
	rateLabel.Position = UDim2.new(0, 0, 0, 54)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = "Market: ⚖️ 1.00x FAIR RATES"
	rateLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
	rateLabel.Font = Enum.Font.GothamBlack
	rateLabel.TextSize = 13
	rateLabel.TextStrokeTransparency = 0.2
	rateLabel.Parent = titleGui

	titleGui.Parent = head
	npcModel.Parent = buildingModel

	-- 12. Invisible Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "FinneasInteractionPart"
	interactionPart.Size = Vector3.new(16, 7, 7)
	interactionPart.CFrame = bCF * CFrame.new(0, 3.8, 7.2)
	interactionPart.Transparency = 1
	interactionPart.CanCollide = false
	interactionPart.CanTouch = true
	interactionPart.CanQuery = true
	interactionPart.Anchored = true
	interactionPart.Parent = buildingModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Sell Pets"
	prompt.ObjectText = "Finneas's Pet Exchange"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = interactionPart

	prompt.Triggered:Connect(function(player)
		print(string.format("🐾 [TownBuildingBuilder] Finneas triggered by %s", player.Name))
		local openEvent = Remotes.getEvent("OpenPetMerchantModal")
		openEvent:FireClient(player)
	end)

	buildingModel.Parent = parent
	return buildingModel
end

-- =========================================================================
-- 7. THE ADVENTURE QUEST BOARD (Town Plaza Bounty & Quest Board)
-- =========================================================================
function TownBuildingBuilder.buildQuestBoard(parent: Instance): Model
	local boardModel = Instance.new("Model")
	boardModel.Name = "TownQuestBoard"

	-- Positioned at Town Plaza southwest edge at (-16, 0, 16), angled at 45 degrees towards spawn dais
	local bCF = CFrame.new(-16, 0, 16) * CFrame.Angles(0, math.rad(45), 0)

	local stoneDark = Color3.fromRGB(45, 48, 55)
	local stonePaving = Color3.fromRGB(72, 75, 84)
	local woodDark = Color3.fromRGB(62, 38, 22)
	local woodPlank = Color3.fromRGB(88, 56, 34)
	local goldTrim = Color3.fromRGB(255, 215, 60)
	local parchmentColor = Color3.fromRGB(246, 238, 218)
	local agedParchment = Color3.fromRGB(235, 222, 195)
	local roofShingle = Color3.fromRGB(50, 32, 20)
	local waxRed = Color3.fromRGB(195, 35, 45)

	-- 1. Raised Stone Plinth Foundation & Cobble Steps
	createStudPart(boardModel, "Foundation", Vector3.new(16, 0.9, 8), bCF * CFrame.new(0, 0.45, 0), stoneDark)
	createStudPart(boardModel, "StoneDeck", Vector3.new(14.8, 0.35, 7.0), bCF * CFrame.new(0, 1.0, 0), stonePaving)
	createStudPart(boardModel, "Step_1", Vector3.new(12, 0.35, 2.0), bCF * CFrame.new(0, 0.35, 4.2), stoneDark)

	-- 2. Heavy Timber Pillars at Left and Right
	for _, px in ipairs({ -5.8, 5.8 }) do
		local bBase = createStudPart(boardModel, "PillarBase", Vector3.new(2.4, 3.2, 2.4), bCF * CFrame.new(px, 2.4, 0), stoneDark)
		bBase.Material = Enum.Material.Cobblestone

		local post = createStudPart(boardModel, "TimberPillar", Vector3.new(1.8, 14.0, 1.8), bCF * CFrame.new(px, 8.4, 0), woodDark)
		post.Material = Enum.Material.Wood

		for _, py in ipairs({ 3.8, 8.0, 12.5 }) do
			local strap = createStudPart(boardModel, "IronStrap", Vector3.new(2.0, 0.4, 2.0), bCF * CFrame.new(px, py, 0), Color3.fromRGB(35, 38, 45))
			strap.Material = Enum.Material.Metal
		end

		local braceDir = if px < 0 then 1 else -1
		local brace = createStudPart(boardModel, "KneeBrace", Vector3.new(0.8, 3.6, 0.8), bCF * CFrame.new(px + (braceDir * 1.5), 13.5, 0) * CFrame.Angles(0, 0, math.rad(braceDir * 38)), woodDark)
		brace.Material = Enum.Material.Wood
	end

	-- 3. Heavy Timber Framing & Notice Board Backing
	createStudPart(boardModel, "LowerBeam", Vector3.new(12.4, 1.2, 1.4), bCF * CFrame.new(0, 4.2, 0), woodDark)
	local headerBeam = createStudPart(boardModel, "HeaderBeam", Vector3.new(14.6, 1.4, 1.6), bCF * CFrame.new(0, 13.8, 0), woodDark)
	headerBeam.Material = Enum.Material.Wood

	local boardBack = createStudPart(boardModel, "NoticeBoardBack", Vector3.new(10.8, 8.2, 0.8), bCF * CFrame.new(0, 8.9, 0), woodPlank)
	boardBack.Material = Enum.Material.WoodPlanks

	createStudPart(boardModel, "FrameL", Vector3.new(0.8, 8.6, 1.1), bCF * CFrame.new(-5.0, 8.9, 0), woodDark)
	createStudPart(boardModel, "FrameR", Vector3.new(0.8, 8.6, 1.1), bCF * CFrame.new(5.0, 8.9, 0), woodDark)

	-- 4. Pinned Parchment Bounty Posters & Wanted Notices
	local posterDefs = {
		{ pos = Vector3.new(-3.4, 10.4, 0.48), sz = Vector3.new(2.6, 3.2, 0.12), rot = -3, col = parchmentColor, seal = waxRed },
		{ pos = Vector3.new(0, 10.6, 0.48), sz = Vector3.new(2.8, 3.0, 0.12), rot = 2, col = agedParchment, seal = waxRed },
		{ pos = Vector3.new(3.4, 10.3, 0.48), sz = Vector3.new(2.6, 3.3, 0.12), rot = -4, col = parchmentColor, seal = Color3.fromRGB(40, 40, 45) },
		{ pos = Vector3.new(-3.4, 7.1, 0.48), sz = Vector3.new(2.5, 2.6, 0.12), rot = 4, col = agedParchment, seal = waxRed },
		{ pos = Vector3.new(0, 7.0, 0.48), sz = Vector3.new(3.2, 2.7, 0.12), rot = 0, col = parchmentColor, seal = waxRed },
		{ pos = Vector3.new(3.4, 7.2, 0.48), sz = Vector3.new(2.5, 2.5, 0.12), rot = -2, col = agedParchment, seal = waxRed },
	}

	for pIdx, pDef in ipairs(posterDefs) do
		local poster = createStudPart(boardModel, "BountyPoster_" .. pIdx, pDef.sz, bCF * CFrame.new(pDef.pos.X, pDef.pos.Y, pDef.pos.Z) * CFrame.Angles(0, 0, math.rad(pDef.rot)), pDef.col)
		poster.Material = Enum.Material.Fabric

		local pGui = Instance.new("SurfaceGui")
		pGui.Face = Enum.NormalId.Front
		pGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		pGui.PixelsPerStud = 40
		pGui.AlwaysOnTop = false
		pGui.Parent = poster

		local posterTitles = { "⚔️ BOUNTY", "⛏️ ORE QUOTA", "🐾 BEAST TAMER", "⚡ ASCENSION", "👹 GOLEM SLAYER", "💎 TREASURE" }
		local pTitle = Instance.new("TextLabel")
		pTitle.Size = UDim2.new(1, 0, 0, 24)
		pTitle.Position = UDim2.new(0, 0, 0, 12)
		pTitle.BackgroundTransparency = 1
		pTitle.Text = posterTitles[pIdx] or "📜 BOUNTY"
		pTitle.TextColor3 = Color3.fromRGB(60, 30, 10)
		pTitle.Font = Enum.Font.FredokaOne
		pTitle.TextSize = 14
		pTitle.Parent = pGui

		local pSub = Instance.new("TextLabel")
		pSub.Size = UDim2.new(1, -12, 1, -42)
		pSub.Position = UDim2.new(0, 6, 0, 36)
		pSub.BackgroundTransparency = 1
		pSub.Text = "REWARD: CASH & GEMS\n[Press E to Accept]"
		pSub.TextColor3 = Color3.fromRGB(115, 80, 50)
		pSub.Font = Enum.Font.FredokaOne
		pSub.TextSize = 10
		pSub.TextWrapped = true
		pSub.Parent = pGui

		local tack = createStudPart(boardModel, "WaxSeal_" .. pIdx, Vector3.new(0.45, 0.45, 0.18), bCF * CFrame.new(pDef.pos.X, pDef.pos.Y + (pDef.sz.Y * 0.44), pDef.pos.Z + 0.1), pDef.seal)
		tack.Shape = Enum.PartType.Ball
		tack.Material = Enum.Material.SmoothPlastic

		if pIdx % 2 == 0 then
			local twine = createStudPart(boardModel, "TwineRibbon_" .. pIdx, Vector3.new(0.12, 0.9, 0.1), bCF * CFrame.new(pDef.pos.X, pDef.pos.Y - (pDef.sz.Y * 0.45), pDef.pos.Z + 0.08), waxRed)
			twine.Material = Enum.Material.Fabric
		end
	end

	-- 5. Rustic Weathered Shingle Roof Canopy
	local roofL = createStudPart(boardModel, "RoofSlopeL", Vector3.new(1.0, 5.8, 6.5), bCF * CFrame.new(-3.8, 16.0, 0) * CFrame.Angles(0, 0, math.rad(-34)), roofShingle)
	roofL.Material = Enum.Material.Wood
	local roofR = createStudPart(boardModel, "RoofSlopeR", Vector3.new(1.0, 5.8, 6.5), bCF * CFrame.new(3.8, 16.0, 0) * CFrame.Angles(0, 0, math.rad(34)), roofShingle)
	roofR.Material = Enum.Material.Wood

	local rCap = createStudPart(boardModel, "RoofRidgeCap", Vector3.new(15.2, 0.8, 1.2), bCF * CFrame.new(0, 17.6, 0), goldTrim)
	rCap.Material = Enum.Material.SmoothPlastic

	for _, gz in ipairs({ -2.4, 2.4 }) do
		local gable = createStudPart(boardModel, "RoofGableInfill", Vector3.new(7.5, 2.4, 0.6), bCF * CFrame.new(0, 15.6, gz), woodDark)
		gable.Material = Enum.Material.WoodPlanks
	end

	-- 6. Twin Wrought-Iron Hanging Lanterns
	for _, lx in ipairs({ -7.2, 7.2 }) do
		local arm = createStudPart(boardModel, "LanternArm", Vector3.new(1.4, 0.35, 0.35), bCF * CFrame.new(lx * 0.9, 12.8, 0.6), Color3.fromRGB(35, 38, 45))
		arm.Material = Enum.Material.Metal
		local chain = createStudPart(boardModel, "LanternChain", Vector3.new(0.2, 1.4, 0.2), bCF * CFrame.new(lx, 12.0, 0.6), Color3.fromRGB(35, 38, 45))
		chain.Material = Enum.Material.Metal
		local lamp = createStudPart(boardModel, "LanternLamp", Vector3.new(1.2, 1.6, 1.2), bCF * CFrame.new(lx, 10.6, 0.6), Color3.fromRGB(255, 195, 80))
		lamp.Material = Enum.Material.Neon

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 120)
		light.Brightness = 1.8
		light.Range = 16
		light.Parent = lamp
	end

	-- 7. 3D Carved Title Plaque
	local plaque = createStudPart(boardModel, "TitlePlaque", Vector3.new(13.8, 2.2, 1.4), bCF * CFrame.new(0, 13.8, 0.4), woodDark)
	plaque.Material = Enum.Material.Wood
	local plaqueGoldBorder = createStudPart(boardModel, "PlaqueBorder", Vector3.new(14.2, 2.4, 0.2), bCF * CFrame.new(0, 13.8, 1.1), goldTrim)
	plaqueGoldBorder.Material = Enum.Material.SmoothPlastic

	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "BoardTitleGui"
	sGui.Face = Enum.NormalId.Front
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 50
	sGui.AlwaysOnTop = false
	sGui.Parent = plaqueGoldBorder

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 1, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "⚔️ ADVENTURE QUEST BOARD ⚔️"
	titleLbl.TextColor3 = Color3.fromRGB(255, 225, 60)
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextSize = 28
	titleLbl.TextStrokeTransparency = 0.2
	titleLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLbl.Parent = sGui

	-- 8. Floating Rotating Golden Exclamation Mark (!)
	local exMarkStem = createStudPart(boardModel, "ExMarkStem", Vector3.new(0.8, 2.4, 0.8), bCF * CFrame.new(0, 20.2, 0), goldTrim)
	exMarkStem.Material = Enum.Material.Neon
	local exMarkDot = createStudPart(boardModel, "ExMarkDot", Vector3.new(0.8, 0.8, 0.8), bCF * CFrame.new(0, 18.5, 0), goldTrim)
	exMarkDot.Material = Enum.Material.Neon

	local exSparkles = Instance.new("Sparkles")
	exSparkles.SparkleColor = Color3.fromRGB(255, 220, 60)
	exSparkles.Parent = exMarkStem

	local exLight = Instance.new("PointLight")
	exLight.Color = Color3.fromRGB(255, 220, 80)
	exLight.Brightness = 2.4
	exLight.Range = 14
	exLight.Parent = exMarkStem

	task.spawn(function()
		local t = 0
		local stemOrigin = bCF * CFrame.new(0, 20.2, 0)
		local dotOrigin = bCF * CFrame.new(0, 18.5, 0)
		while exMarkStem and exMarkStem.Parent do
			t += 0.03
			local yBob = math.sin(t * 2.5) * 0.3
			local rot = CFrame.Angles(0, t * 1.5, 0)
			exMarkStem.CFrame = (stemOrigin + Vector3.new(0, yBob, 0)) * rot
			exMarkDot.CFrame = (dotOrigin + Vector3.new(0, yBob, 0)) * rot
			task.wait(0.03)
		end
	end)

	-- 9. Interaction Part & ProximityPrompt
	local promptPart = Instance.new("Part")
	promptPart.Name = "QuestBoardInteractionPart"
	promptPart.Size = Vector3.new(14, 8, 8)
	promptPart.CFrame = bCF * CFrame.new(0, 4.5, 3.2)
	promptPart.Transparency = 1
	promptPart.CanCollide = false
	promptPart.CanTouch = true
	promptPart.CanQuery = true
	promptPart.Anchored = true
	promptPart.Parent = boardModel

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "View Quests"
	prompt.ObjectText = "Adventure Quest Board"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		print(string.format("📜 [TownBuildingBuilder] Quest Board triggered by %s", player.Name))
		local openEvent = Remotes.getEvent("OpenQuestModal")
		openEvent:FireClient(player)
	end)

	boardModel.Parent = parent
	return boardModel
end

return TownBuildingBuilder
