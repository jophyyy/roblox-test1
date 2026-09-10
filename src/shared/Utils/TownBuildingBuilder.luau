--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
local PetService = require(game:GetService("ServerScriptService").Server.Services.PetService)
local MarketplaceServiceHandler = require(game:GetService("ServerScriptService").Server.Services.MarketplaceServiceHandler)

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
	local bCF = CFrame.new(-38, 0, -18) * CFrame.Angles(0, math.rad(90), 0)

	local stoneDark = Color3.fromRGB(52, 55, 62)
	local stoneWall = Color3.fromRGB(74, 78, 86)
	local woodDark = Color3.fromRGB(72, 46, 26)
	local woodLight = Color3.fromRGB(110, 72, 42)
	local roofSlate = Color3.fromRGB(44, 46, 52)
	local fireGlow = Color3.fromRGB(255, 80, 15)

	-- 1. Heavy Cobblestone Plinth Foundation
	createStudPart(buildingModel, "Foundation", Vector3.new(20, 1.2, 22), bCF * CFrame.new(0, 0.6, 0), stoneDark)

	-- 2. Heavy Timber Frame Columns at 4 Corners
	local colOffsets = {
		Vector3.new(-8.8, 6.6, -9.8),
		Vector3.new(8.8, 6.6, -9.8),
		Vector3.new(-8.8, 6.6, 9.8),
		Vector3.new(8.8, 6.6, 9.8),
	}
	for _, cOff in ipairs(colOffsets) do
		local col = createStudPart(buildingModel, "TimberColumn", Vector3.new(2.0, 11, 2.0), bCF * CFrame.new(cOff.X, cOff.Y, cOff.Z), woodDark)
		col.Material = Enum.Material.Wood
	end

	-- 3. Masonry Stone Walls (Back & Sides)
	createStudPart(buildingModel, "BackWall", Vector3.new(1.4, 10, 18), bCF * CFrame.new(0, 6.2, -9.8), stoneWall)
	createStudPart(buildingModel, "LeftWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(-8.8, 6.2, 0), stoneWall)
	createStudPart(buildingModel, "RightWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(8.8, 6.2, 0), stoneWall)

	-- Front facade side piers (leaving open 10-stud forge archway)
	createStudPart(buildingModel, "FrontPierL", Vector3.new(4.5, 10, 1.4), bCF * CFrame.new(-6.5, 6.2, 9.8), stoneWall)
	createStudPart(buildingModel, "FrontPierR", Vector3.new(4.5, 10, 1.4), bCF * CFrame.new(6.5, 6.2, 9.8), stoneWall)
	createStudPart(buildingModel, "FrontArchLintel", Vector3.new(18, 2.0, 1.6), bCF * CFrame.new(0, 10.2, 9.8), woodDark)

	-- 4. Pitched Slate Roof with Front Porch Overhang
	createStudPart(buildingModel, "RoofRidge", Vector3.new(21, 1.6, 2.2), bCF * CFrame.new(0, 14.5, 1.5), woodDark)
	-- Slanted Roof Slabs
	createStudPart(buildingModel, "RoofSlopeBack", Vector3.new(21, 0.8, 14), bCF * CFrame.new(0, 12.8, -5.5) * CFrame.Angles(math.rad(-26), 0, 0), roofSlate)
	createStudPart(buildingModel, "RoofSlopeFront", Vector3.new(21, 0.8, 16), bCF * CFrame.new(0, 12.5, 7.5) * CFrame.Angles(math.rad(24), 0, 0), roofSlate)

	-- 5. Tall Stone Brick Forge Chimney with Smoke
	local chimney = createStudPart(buildingModel, "Chimney", Vector3.new(3.8, 18, 3.8), bCF * CFrame.new(-6.5, 9.0, -7.5), stoneDark)
	local chimneyTop = createStudPart(buildingModel, "ChimneyCap", Vector3.new(4.6, 1.2, 4.6), bCF * CFrame.new(-6.5, 18.2, -7.5), Color3.fromRGB(36, 38, 44))

	local chimAtt = Instance.new("Attachment")
	chimAtt.Position = Vector3.new(0, 0.8, 0)
	chimAtt.Parent = chimneyTop

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ChimneySmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 72, 78))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 2.4),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(3, 6)
	smoke.Lifetime = NumberRange.new(2.5, 4.0)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Parent = chimAtt

	-- 6. Outdoor Covered Forge Porch & Blacksmith Equipment
	-- Forge Furnace Hearth
	local forgeHearth = createStudPart(buildingModel, "ForgeHearth", Vector3.new(4.5, 2.8, 4.0), bCF * CFrame.new(-5.0, 2.6, 7.0), stoneDark)
	local glowingCoals = createStudPart(buildingModel, "ForgeCoals", Vector3.new(3.5, 0.5, 3.0), bCF * CFrame.new(-5.0, 3.8, 7.0), fireGlow)
	glowingCoals.Material = Enum.Material.Neon

	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = Color3.fromRGB(255, 130, 25)
	forgeLight.Brightness = 2.8
	forgeLight.Range = 24
	forgeLight.Shadows = true
	forgeLight.Parent = glowingCoals

	local fireAtt = Instance.new("Attachment")
	fireAtt.Position = Vector3.new(0, 0.4, 0)
	fireAtt.Parent = glowingCoals

	local forgeFire = Instance.new("ParticleEmitter")
	forgeFire.Name = "ForgeFire"
	forgeFire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 0)),
	})
	forgeFire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 1.4),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	forgeFire.Rate = 16
	forgeFire.Speed = NumberRange.new(2, 4.5)
	forgeFire.Lifetime = NumberRange.new(0.6, 1.0)
	forgeFire.SpreadAngle = Vector2.new(10, 10)
	forgeFire.LightEmission = 0.9
	forgeFire.Parent = fireAtt

	-- Heavy Cast-Iron Anvil on Wood Stump
	createStudPart(buildingModel, "AnvilStump", Vector3.new(2.4, 1.8, 2.4), bCF * CFrame.new(-4.8, 2.1, 12.0), woodDark)
	local anvilBase = createStudPart(buildingModel, "AnvilBase", Vector3.new(2.6, 0.6, 1.8), bCF * CFrame.new(-4.8, 3.2, 12.0), Color3.fromRGB(120, 130, 145))
	anvilBase.Material = Enum.Material.Metal
	local anvilHorn = createStudPart(buildingModel, "AnvilHorn", Vector3.new(3.4, 0.8, 1.4), bCF * CFrame.new(-4.8, 3.8, 12.0), Color3.fromRGB(160, 170, 185))
	anvilHorn.Material = Enum.Material.Metal

	-- Quenching Water Barrel
	createStudPart(buildingModel, "WaterBarrel", Vector3.new(2.4, 2.6, 2.4), bCF * CFrame.new(-7.8, 2.5, 11.5), woodLight)
	local water = createStudPart(buildingModel, "BarrelWater", Vector3.new(2.0, 0.2, 2.0), bCF * CFrame.new(-7.8, 3.6, 11.5), Color3.fromRGB(0, 170, 230))
	water.Material = Enum.Material.Glass

	-- Pickaxe Display Rack (Weapon Stand)
	createStudPart(buildingModel, "WeaponRack", Vector3.new(1.0, 4.2, 4.8), bCF * CFrame.new(7.5, 3.3, 7.0), woodDark)
	local displayPick1 = createStudPart(buildingModel, "DisplayPick1", Vector3.new(0.4, 2.6, 0.4), bCF * CFrame.new(7.5, 3.6, 6.0) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(255, 215, 0))
	displayPick1.Material = Enum.Material.Neon
	local displayPick2 = createStudPart(buildingModel, "DisplayPick2", Vector3.new(0.4, 2.6, 0.4), bCF * CFrame.new(7.5, 3.6, 8.0) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(0, 230, 255))
	displayPick2.Material = Enum.Material.Neon

	-- 7. Front Service Counter Desk (Outside Porch)
	createStudPart(buildingModel, "CounterBase", Vector3.new(9.0, 2.6, 2.4), bCF * CFrame.new(1.5, 2.5, 12.2), woodDark)
	createStudPart(buildingModel, "CounterTop", Vector3.new(10.0, 0.6, 3.2), bCF * CFrame.new(1.5, 4.0, 12.2), woodLight)

	-- 8. BARNABY THE BLACKSMITH NPC (Standing outside on porch behind counter)
	local npcModel = Instance.new("Model")
	npcModel.Name = "BarnabyMerchant"

	local npcCF = bCF * CFrame.new(1.5, 2.4, 10.0) -- Facing forward toward customer side (+Z local)

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
	titleGui.Size = UDim2.new(0, 240, 0, 56)
	titleGui.StudsOffset = Vector3.new(0, 3.6, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 65

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⚒️ THE BLACKSMITH ⚒️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.Font = Enum.Font.Antique
	titleLabel.TextSize = 20
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Barnaby [Equipment Merchant]"
	subtitleLabel.TextColor3 = Color3.fromRGB(210, 235, 255)
	subtitleLabel.Font = Enum.Font.Antique
	subtitleLabel.TextSize = 14
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- Invisible Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "BarnabyInteractionPart"
	interactionPart.Size = Vector3.new(10, 6, 5)
	interactionPart.CFrame = bCF * CFrame.new(1.5, 3.6, 14.5)
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
	local bCF = CFrame.new(-38, 0, 18) * CFrame.Angles(0, math.rad(90), 0)

	local woodDark = Color3.fromRGB(46, 28, 56)
	local woodLight = Color3.fromRGB(78, 48, 96)
	local clothCyan = Color3.fromRGB(0, 210, 255)
	local clothViolet = Color3.fromRGB(175, 45, 235)
	local goldTrim = Color3.fromRGB(255, 215, 60)
	local stoneDark = Color3.fromRGB(48, 42, 54)

	-- 1. Polished Stone Plinth Foundation
	createStudPart(buildingModel, "Foundation", Vector3.new(20, 1.2, 20), bCF * CFrame.new(0, 0.6, 0), stoneDark)

	-- 2. Celestial Timber Frame Columns
	local colOffsets = {
		Vector3.new(-8.8, 6.6, -8.8),
		Vector3.new(8.8, 6.6, -8.8),
		Vector3.new(-8.8, 6.6, 8.8),
		Vector3.new(8.8, 6.6, 8.8),
	}
	for _, cOff in ipairs(colOffsets) do
		local col = createStudPart(buildingModel, "BoutiqueCol", Vector3.new(2.0, 11, 2.0), bCF * CFrame.new(cOff.X, cOff.Y, cOff.Z), woodDark)
		col.Material = Enum.Material.Wood
	end

	-- 3. Walls with Arched Bay Windows
	createStudPart(buildingModel, "BackWall", Vector3.new(1.4, 10, 16), bCF * CFrame.new(0, 6.2, -8.8), woodLight)
	createStudPart(buildingModel, "LeftWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(-8.8, 6.2, 0), woodLight)
	createStudPart(buildingModel, "RightWall", Vector3.new(16, 10, 1.4), bCF * CFrame.new(8.8, 6.2, 0), woodLight)

	-- Front facade piers
	createStudPart(buildingModel, "FrontPierL", Vector3.new(4.5, 10, 1.4), bCF * CFrame.new(-6.5, 6.2, 8.8), woodLight)
	createStudPart(buildingModel, "FrontPierR", Vector3.new(4.5, 10, 1.4), bCF * CFrame.new(6.5, 6.2, 8.8), woodLight)
	createStudPart(buildingModel, "FrontArchLintel", Vector3.new(18, 2.0, 1.6), bCF * CFrame.new(0, 10.2, 8.8), woodDark)

	-- 4. Striped Arched Fabric Canopy Roof (Violet & Cyan with Gold Fringe)
	createStudPart(buildingModel, "CanopyRidge", Vector3.new(21, 1.4, 2.2), bCF * CFrame.new(0, 13.5, 1.0), woodDark)
	for s = -7, 7 do
		local slatCol = if s % 2 == 0 then clothViolet else clothCyan
		createStudPart(buildingModel, "CanopySlatFront", Vector3.new(1.4, 0.5, 12.0), bCF * CFrame.new(s * 1.35, 11.8, 6.5) * CFrame.Angles(math.rad(18), 0, 0), slatCol)
		createStudPart(buildingModel, "CanopySlatBack", Vector3.new(1.4, 0.5, 10.0), bCF * CFrame.new(s * 1.35, 12.2, -4.5) * CFrame.Angles(math.rad(-20), 0, 0), slatCol)
	end

	-- 5. Outdoor Artisan Porch & Magic Displays
	-- Floating Crystal Trail Orb on Mystical Pedestal
	createStudPart(buildingModel, "PedestalBase", Vector3.new(3.0, 2.2, 3.0), bCF * CFrame.new(-5.5, 2.3, 10.5), woodDark)
	local orb = createStudPart(buildingModel, "TrailOrb", Vector3.new(1.8, 1.8, 1.8), bCF * CFrame.new(-5.5, 4.5, 10.5), clothViolet)
	orb.Material = Enum.Material.Neon
	orb.Shape = Enum.PartType.Ball

	local orbAtt = Instance.new("Attachment")
	orbAtt.Parent = orb

	local orbSparks = Instance.new("ParticleEmitter")
	orbSparks.Name = "OrbSparks"
	orbSparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 60, 255)),
	})
	orbSparks.Size = NumberSequence.new(0.3, 0.05)
	orbSparks.Rate = 12
	orbSparks.Speed = NumberRange.new(0.8, 1.8)
	orbSparks.LightEmission = 1.0
	orbSparks.Parent = orbAtt

	local orbLight = Instance.new("PointLight")
	orbLight.Color = clothCyan
	orbLight.Brightness = 2.5
	orbLight.Range = 18
	orbLight.Parent = orb

	-- Enchanted Trail Essence Bottles Shelf
	createStudPart(buildingModel, "PotionShelf", Vector3.new(1.0, 4.0, 4.5), bCF * CFrame.new(7.5, 3.2, 6.5), woodDark)
	for p = 1, 3 do
		local bottle = createStudPart(buildingModel, "PotionBottle" .. p, Vector3.new(0.6, 1.2, 0.6), bCF * CFrame.new(7.5, 4.2, 5.0 + (p * 1.0)), if p == 1 then Color3.fromRGB(255, 60, 20) elseif p == 2 then Color3.fromRGB(255, 220, 0) else Color3.fromRGB(0, 230, 255))
		bottle.Material = Enum.Material.Neon
	end

	-- 6. Front Service Counter Desk
	createStudPart(buildingModel, "TrailCounterBase", Vector3.new(9.0, 2.6, 2.4), bCF * CFrame.new(1.5, 2.5, 11.2), woodDark)
	createStudPart(buildingModel, "TrailCounterTop", Vector3.new(10.0, 0.6, 3.2), bCF * CFrame.new(1.5, 4.0, 11.2), woodLight)

	-- 7. ZEPHYR THE TRAIL ARTISAN NPC
	local npcModel = Instance.new("Model")
	npcModel.Name = "ZephyrArtisan"

	local npcCF = bCF * CFrame.new(1.5, 2.4, 9.0)

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

	-- Arms resting on counter
	createStudPart(npcModel, "LeftArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(-1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(55, 30, 75))
	createStudPart(npcModel, "RightArm", Vector3.new(1, 2, 1), npcCF * CFrame.new(1.4, 2.0, 0.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(55, 30, 75))

	-- Signboard Overhead Title Billboard
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "ArtisanTitleGui"
	titleGui.Size = UDim2.new(0, 240, 0, 56)
	titleGui.StudsOffset = Vector3.new(0, 3.6, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 65

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "✨ THE TRAIL WEAVER ✨"
	titleLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	titleLabel.Font = Enum.Font.Antique
	titleLabel.TextSize = 20
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Zephyr [Trail Artisan]"
	subtitleLabel.TextColor3 = Color3.fromRGB(235, 185, 255)
	subtitleLabel.Font = Enum.Font.Antique
	subtitleLabel.TextSize = 14
	subtitleLabel.TextStrokeTransparency = 0.2
	subtitleLabel.Parent = titleGui
	titleGui.Parent = head

	-- Invisible Interaction Part & Proximity Prompt
	local interactionPart = Instance.new("Part")
	interactionPart.Name = "ZephyrInteractionPart"
	interactionPart.Size = Vector3.new(10, 6, 5)
	interactionPart.CFrame = bCF * CFrame.new(1.5, 3.6, 13.5)
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

	-- Positioned due East, facing -X (facing central spawn plaza)
	local bCF = CFrame.new(46, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)

	local goldMetal = Color3.fromRGB(255, 215, 60)
	local royalPurple = Color3.fromRGB(110, 25, 180)
	local marbleWhite = Color3.fromRGB(245, 246, 250)
	local marbleGrey = Color3.fromRGB(210, 215, 225)

	-- 1. Raised Gilded Marble Terrace
	createStudPart(buildingModel, "PavilionPlinth1", Vector3.new(18, 1.2, 20), bCF * CFrame.new(0, 0.6, 0), marbleGrey)
	createStudPart(buildingModel, "PavilionPlinth2", Vector3.new(16, 0.6, 18), bCF * CFrame.new(0, 1.5, 0), marbleWhite)

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

	buildingModel.Parent = parent
	return buildingModel
end

return TownBuildingBuilder
