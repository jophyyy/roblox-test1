--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetModelBuilder = require(ReplicatedStorage.Shared.Utils.PetModelBuilder)
local OreConfig = require(ReplicatedStorage.Shared.Config.OreConfig)
local OreModelBuilder = require(ReplicatedStorage.Shared.Utils.OreModelBuilder)
local LootBoxConfig = require(ReplicatedStorage.Shared.Config.LootBoxConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PickaxeModelBuilder = require(ReplicatedStorage.Shared.Utils.PickaxeModelBuilder)

local ShowroomService = {}

local SHOWROOM_CENTER = Vector3.new(500, 60, 0)
local SHOWROOM_ARRIVAL = Vector3.new(500, 64, -55)
local TOWN_SPAWN = Vector3.new(0, 5, 0)

local lastArrivalTimes: { [Player]: number } = {}

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = if canCollide ~= nil then canCollide else false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Creates an exhibition display pedestal with an informative BillboardGui
local function createPedestal(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	titleText: string,
	subText: string,
	accentColor: Color3
): CFrame
	local baseHeight = size.Y
	-- Base Tier
	createPart(parent, name .. "_PedestalBase", Vector3.new(size.X, baseHeight * 0.7, size.Z), cf * CFrame.new(0, baseHeight * 0.35, 0), Color3.fromRGB(25, 28, 36), Enum.Material.Slate, true)
	-- Top Plinth
	local top = createPart(parent, name .. "_PedestalTop", Vector3.new(size.X - 0.4, baseHeight * 0.3, size.Z - 0.4), cf * CFrame.new(0, baseHeight * 0.85, 0), Color3.fromRGB(36, 40, 52), Enum.Material.SmoothPlastic, true)
	-- Glowing Neon Trim Line
	createPart(parent, name .. "_PedestalTrim", Vector3.new(size.X - 0.2, 0.12, size.Z - 0.2), cf * CFrame.new(0, baseHeight * 0.7, 0), accentColor, Enum.Material.Neon, false)

	-- Overhead Label
	local bb = Instance.new("BillboardGui")
	bb.Name = "ExhibitLabel"
	bb.Size = UDim2.new(0, 180, 0, 48)
	bb.StudsOffset = Vector3.new(0, (size.Y * 0.5) + 3.8, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 55
	bb.Parent = top

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = accentColor
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 13
	title.TextStrokeTransparency = 0.2
	title.Parent = bb

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.Position = UDim2.new(0, 0, 0, 20)
	sub.BackgroundTransparency = 1
	sub.Text = subText
	sub.TextColor3 = Color3.fromRGB(220, 225, 235)
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 11
	sub.TextStrokeTransparency = 0.3
	sub.Parent = bb

	return cf * CFrame.new(0, baseHeight + 0.1, 0)
end

-- =========================================================================
-- 1. SHOWROOM PLATFORM ISLAND
-- =========================================================================
local function buildShowroomIsland(showroomFolder: Folder)
	local islandCenter = SHOWROOM_CENTER

	-- Main Showroom Floor (190 x 4 x 150)
	createPart(showroomFolder, "ShowroomFloor", Vector3.new(190, 4, 150), CFrame.new(islandCenter + Vector3.new(0, -2, 0)), Color3.fromRGB(22, 25, 34), Enum.Material.Slate, true)

	-- Outer Perimeter Glowing Trim
	createPart(showroomFolder, "ShowroomBorder", Vector3.new(192, 0.4, 152), CFrame.new(islandCenter + Vector3.new(0, 0.2, 0)), Color3.fromRGB(0, 215, 255), Enum.Material.Neon, false)

	-- Perimeter Safety Glass Railings
	local halfW = 95
	local halfD = 75
	local railingColor = Color3.fromRGB(180, 240, 255)
	local railingMat = Enum.Material.Glass

	createPart(showroomFolder, "Railing_N", Vector3.new(190, 3.5, 0.8), CFrame.new(islandCenter + Vector3.new(0, 1.75, -halfD)), railingColor, railingMat, true)
	createPart(showroomFolder, "Railing_S", Vector3.new(190, 3.5, 0.8), CFrame.new(islandCenter + Vector3.new(0, 1.75, halfD)), railingColor, railingMat, true)
	createPart(showroomFolder, "Railing_W", Vector3.new(0.8, 3.5, 150), CFrame.new(islandCenter + Vector3.new(-halfW, 1.75, 0)), railingColor, railingMat, true)
	createPart(showroomFolder, "Railing_E", Vector3.new(0.8, 3.5, 150), CFrame.new(islandCenter + Vector3.new(halfW, 1.75, 0)), railingColor, railingMat, true)

	-- Corner Illuminated Pylons with Soft Floodlights
	local cornerOffsets = {
		Vector3.new(-halfW + 2, 0, -halfD + 2),
		Vector3.new(halfW - 2, 0, -halfD + 2),
		Vector3.new(-halfW + 2, 0, halfD - 2),
		Vector3.new(halfW - 2, 0, halfD - 2),
		Vector3.new(0, 0, -halfD + 2),
		Vector3.new(0, 0, halfD - 2),
	}
	for i, cOff in ipairs(cornerOffsets) do
		createPart(showroomFolder, "Pylon_" .. i, Vector3.new(2.4, 10, 2.4), CFrame.new(islandCenter + cOff + Vector3.new(0, 5, 0)), Color3.fromRGB(36, 40, 54), Enum.Material.Metal, true)
		local bulb = createPart(showroomFolder, "PylonBulb_" .. i, Vector3.new(2.0, 1.8, 2.0), CFrame.new(islandCenter + cOff + Vector3.new(0, 10.5, 0)), Color3.fromRGB(0, 230, 255), Enum.Material.Neon, false)

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(220, 245, 255)
		light.Range = 45
		light.Brightness = 2.2
		light.Shadows = false
		light.Parent = bulb
	end

	-- Grand Entrance Archway Banner
	local archCenter = islandCenter + Vector3.new(0, 0, -68)
	createPart(showroomFolder, "ArchPillarL", Vector3.new(2.8, 14, 2.8), CFrame.new(archCenter + Vector3.new(-18, 7, 0)), Color3.fromRGB(32, 36, 48), Enum.Material.Metal, true)
	createPart(showroomFolder, "ArchPillarR", Vector3.new(2.8, 14, 2.8), CFrame.new(archCenter + Vector3.new(18, 7, 0)), Color3.fromRGB(32, 36, 48), Enum.Material.Metal, true)
	local archBeam = createPart(showroomFolder, "ArchBeam", Vector3.new(38.8, 2.8, 3.2), CFrame.new(archCenter + Vector3.new(0, 13.5, 0)), Color3.fromRGB(0, 215, 255), Enum.Material.Neon, true)

	local archBb = Instance.new("BillboardGui")
	archBb.Size = UDim2.new(0, 650, 0, 70)
	archBb.StudsOffset = Vector3.new(0, 2.5, 0)
	archBb.AlwaysOnTop = false
	archBb.MaxDistance = 110
	archBb.Parent = archBeam

	local archTitle = Instance.new("TextLabel")
	archTitle.Size = UDim2.new(1, 0, 0, 36)
	archTitle.BackgroundTransparency = 1
	archTitle.Text = "✨ 3D ASSET SHOWROOM & DEV TEST LAB ✨"
	archTitle.TextColor3 = Color3.fromRGB(255, 225, 80)
	archTitle.Font = Enum.Font.GothamBlack
	archTitle.TextSize = 22
	archTitle.TextStrokeTransparency = 0.2
	archTitle.Parent = archBb

	local archSub = Instance.new("TextLabel")
	archSub.Size = UDim2.new(1, 0, 0, 24)
	archSub.Position = UDim2.new(0, 0, 0, 36)
	archSub.BackgroundTransparency = 1
	archSub.Text = "Bosses • Ores • Lootboxes • Pets • Pickaxes"
	archSub.TextColor3 = Color3.fromRGB(180, 245, 255)
	archSub.Font = Enum.Font.GothamBold
	archSub.TextSize = 14
	archSub.TextStrokeTransparency = 0.3
	archSub.Parent = archBb

	-- Teleport Arrival Landing Pad (Y top = 60.4, player spawns at Y = 64)
	createPart(showroomFolder, "ArrivalPad", Vector3.new(12, 0.4, 12), CFrame.new(SHOWROOM_ARRIVAL + Vector3.new(0, -3.8, 0)), Color3.fromRGB(0, 180, 255), Enum.Material.Neon, true)
	createPart(showroomFolder, "ArrivalRing", Vector3.new(14, 0.2, 14), CFrame.new(SHOWROOM_ARRIVAL + Vector3.new(0, -3.9, 0)), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, false)

	-- Physical Return Teleport Pad (to Town Spawn) - Positioned 18 studs south of arrival pad
	local returnPos = SHOWROOM_ARRIVAL + Vector3.new(0, -3.8, 18)
	local returnPad = createPart(showroomFolder, "ReturnPad", Vector3.new(8, 0.4, 8), CFrame.new(returnPos), Color3.fromRGB(0, 230, 120), Enum.Material.Neon, true)

	local returnBb = Instance.new("BillboardGui")
	returnBb.Size = UDim2.new(0, 160, 0, 40)
	returnBb.StudsOffset = Vector3.new(0, 2.6, 0)
	returnBb.AlwaysOnTop = false
	returnBb.MaxDistance = 55
	returnBb.Parent = returnPad

	local returnLbl = Instance.new("TextLabel")
	returnLbl.Size = UDim2.new(1, 0, 1, 0)
	returnLbl.BackgroundTransparency = 1
	returnLbl.Text = "🏡 Return to Town\n(Step on pad)"
	returnLbl.TextColor3 = Color3.fromRGB(80, 255, 160)
	returnLbl.Font = Enum.Font.GothamBlack
	returnLbl.TextSize = 12
	returnLbl.TextStrokeTransparency = 0.2
	returnLbl.Parent = returnBb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Return to Town"
	prompt.ObjectText = "Teleporter"
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.Parent = returnPad
	prompt.Triggered:Connect(function(player)
		ShowroomService.teleportPlayer(player, "Town")
	end)

	local lastReturnPadTouch: { [Player]: number } = {}
	returnPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local now = os.clock()
			if now - (lastArrivalTimes[player] or 0) < 3.0 then
				return -- Prevent accidental immediate return on arrival
			end
			if now - (lastReturnPadTouch[player] or 0) < 2.0 then
				return -- Debounce return pad touches
			end
			lastReturnPadTouch[player] = now
			ShowroomService.teleportPlayer(player, "Town")
		end
	end)

	-- Catch-All Safety Net Barrier beneath Showroom (Catches falling players and teleports back to platform)
	local safetyNet = createPart(showroomFolder, "SafetyNet", Vector3.new(380, 2, 340), CFrame.new(islandCenter + Vector3.new(0, -18, 0)), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, true)
	safetyNet.Transparency = 1
	safetyNet.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			ShowroomService.teleportPlayer(player, "Showroom")
		end
	end)
end

-- =========================================================================
-- 2. BOSS EXHIBITION MODELS
-- =========================================================================
local function buildBossModels(showroomFolder: Folder)
	local bossFolder = Instance.new("Folder")
	bossFolder.Name = "BossExhibition"
	bossFolder.Parent = showroomFolder

	-- Boss 1: Infernal Magma Golem (Zone 2 Boss)
	local golemCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(-38, 0, 45))
	createPedestal(bossFolder, "MagmaGolem", golemCF, Vector3.new(22, 1.8, 18), "🔥 INFERNAL MAGMA GOLEM", "Zone 2 World Boss • 50,000 HP", Color3.fromRGB(255, 90, 0))

	local golemModel = Instance.new("Model")
	golemModel.Name = "Showroom_InfernalMagmaGolem"
	golemModel.Parent = bossFolder

	local basaltDark = Color3.fromRGB(36, 32, 30)
	local basaltMid = Color3.fromRGB(48, 42, 40)
	local magmaRed = Color3.fromRGB(255, 60, 0)
	local eyeGold = Color3.fromRGB(255, 200, 30)

	local gSpawnCF = golemCF * CFrame.new(0, 9, 0)
	createPart(golemModel, "Torso", Vector3.new(7.2, 7.5, 4.5), gSpawnCF, basaltDark, Enum.Material.Slate, true)
	local core = createPart(golemModel, "MagmaCore", Vector3.new(3.8, 4.5, 1.2), gSpawnCF * CFrame.new(0, 0.4, -2.1), magmaRed, Enum.Material.Neon, false)
	createPart(golemModel, "Head", Vector3.new(4.2, 3.8, 3.8), gSpawnCF * CFrame.new(0, 5.2, 0), basaltMid, Enum.Material.Slate, true)

	createPart(golemModel, "EyeL", Vector3.new(0.8, 0.5, 0.4), gSpawnCF * CFrame.new(-1.1, 5.4, -1.95), eyeGold, Enum.Material.Neon, false)
	createPart(golemModel, "EyeR", Vector3.new(0.8, 0.5, 0.4), gSpawnCF * CFrame.new(1.1, 5.4, -1.95), eyeGold, Enum.Material.Neon, false)
	createPart(golemModel, "HornL", Vector3.new(1.2, 3.2, 1.2), gSpawnCF * CFrame.new(-2.2, 7.2, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(-20)), basaltDark, Enum.Material.Slate, false)
	createPart(golemModel, "HornR", Vector3.new(1.2, 3.2, 1.2), gSpawnCF * CFrame.new(2.2, 7.2, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(20)), basaltDark, Enum.Material.Slate, false)

	createPart(golemModel, "LeftArm", Vector3.new(3.2, 7.2, 3.2), gSpawnCF * CFrame.new(-5.2, 0.5, 0), basaltDark, Enum.Material.Slate, true)
	createPart(golemModel, "RightArm", Vector3.new(3.2, 7.2, 3.2), gSpawnCF * CFrame.new(5.2, 0.5, 0), basaltDark, Enum.Material.Slate, true)
	createPart(golemModel, "FistL", Vector3.new(3.6, 2.2, 3.6), gSpawnCF * CFrame.new(-5.2, -3.2, 0), magmaRed, Enum.Material.Neon, false)
	createPart(golemModel, "FistR", Vector3.new(3.6, 2.2, 3.6), gSpawnCF * CFrame.new(5.2, -3.2, 0), magmaRed, Enum.Material.Neon, false)

	createPart(golemModel, "LeftLeg", Vector3.new(3.0, 5.5, 3.0), gSpawnCF * CFrame.new(-2.0, -5.5, 0), basaltMid, Enum.Material.Slate, true)
	createPart(golemModel, "RightLeg", Vector3.new(3.0, 5.5, 3.0), gSpawnCF * CFrame.new(2.0, -5.5, 0), basaltMid, Enum.Material.Slate, true)

	local fireAtt = Instance.new("Attachment")
	fireAtt.Parent = core
	local fire = Instance.new("ParticleEmitter")
	fire.Size = NumberSequence.new(0.6, 0.2)
	fire.Color = ColorSequence.new(magmaRed, eyeGold)
	fire.Rate = 20
	fire.Speed = NumberRange.new(2, 4)
	fire.Lifetime = NumberRange.new(0.6, 1.2)
	fire.Parent = fireAtt

	-- Boss 2: Void Harbinger Chronos (Zone 3 Boss)
	local voidCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(38, 0, 45))
	createPedestal(bossFolder, "VoidHarbinger", voidCF, Vector3.new(22, 1.8, 18), "🌌 VOID HARBINGER CHRONOS", "Zone 3 World Boss • 250,000 HP", Color3.fromRGB(170, 50, 255))

	local voidModel = Instance.new("Model")
	voidModel.Name = "Showroom_VoidHarbinger"
	voidModel.Parent = bossFolder

	local voidDark = Color3.fromRGB(16, 12, 28)
	local voidMid = Color3.fromRGB(36, 28, 56)
	local astralPurple = Color3.fromRGB(150, 50, 255)
	local stardustCyan = Color3.fromRGB(0, 230, 255)

	local vSpawnCF = voidCF * CFrame.new(0, 10, 0)
	createPart(voidModel, "Torso", Vector3.new(8.0, 8.5, 5.0), vSpawnCF, voidDark, Enum.Material.Slate, true)
	local vCore = createPart(voidModel, "VoidCore", Vector3.new(4.2, 5.0, 1.4), vSpawnCF * CFrame.new(0, 0.4, -2.4), astralPurple, Enum.Material.Neon, false)
	createPart(voidModel, "Head", Vector3.new(4.5, 4.2, 4.2), vSpawnCF * CFrame.new(0, 6.0, 0), voidMid, Enum.Material.Slate, true)

	createPart(voidModel, "EyeL", Vector3.new(0.9, 0.6, 0.4), vSpawnCF * CFrame.new(-1.2, 6.2, -2.15), stardustCyan, Enum.Material.Neon, false)
	createPart(voidModel, "EyeR", Vector3.new(0.9, 0.6, 0.4), vSpawnCF * CFrame.new(1.2, 6.2, -2.15), stardustCyan, Enum.Material.Neon, false)
	createPart(voidModel, "AstralCrown", Vector3.new(5.5, 0.5, 5.5), vSpawnCF * CFrame.new(0, 9.2, 0), stardustCyan, Enum.Material.Neon, false)

	createPart(voidModel, "HornL", Vector3.new(1.4, 4.2, 1.4), vSpawnCF * CFrame.new(-2.6, 8.4, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(-25)), voidDark, Enum.Material.Slate, false)
	createPart(voidModel, "HornR", Vector3.new(1.4, 4.2, 1.4), vSpawnCF * CFrame.new(2.6, 8.4, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(25)), voidDark, Enum.Material.Slate, false)

	createPart(voidModel, "WingL", Vector3.new(2.0, 10.0, 7.0), vSpawnCF * CFrame.new(-6.5, 4.0, 2.5) * CFrame.Angles(0, math.rad(-35), math.rad(25)), voidMid, Enum.Material.Slate, false)
	createPart(voidModel, "WingR", Vector3.new(2.0, 10.0, 7.0), vSpawnCF * CFrame.new(6.5, 4.0, 2.5) * CFrame.Angles(0, math.rad(35), math.rad(-25)), voidMid, Enum.Material.Slate, false)
	createPart(voidModel, "WingFeatherL", Vector3.new(1.0, 8.0, 5.0), vSpawnCF * CFrame.new(-7.0, 4.0, 2.8) * CFrame.Angles(0, math.rad(-35), math.rad(25)), astralPurple, Enum.Material.Neon, false)
	createPart(voidModel, "WingFeatherR", Vector3.new(1.0, 8.0, 5.0), vSpawnCF * CFrame.new(7.0, 4.0, 2.8) * CFrame.Angles(0, math.rad(35), math.rad(-25)), astralPurple, Enum.Material.Neon, false)

	createPart(voidModel, "LeftArm", Vector3.new(3.5, 8.0, 3.5), vSpawnCF * CFrame.new(-5.8, 0.5, 0), voidDark, Enum.Material.Slate, true)
	createPart(voidModel, "RightArm", Vector3.new(3.5, 8.0, 3.5), vSpawnCF * CFrame.new(5.8, 0.5, 0), voidDark, Enum.Material.Slate, true)
	createPart(voidModel, "FistL", Vector3.new(4.0, 2.5, 4.0), vSpawnCF * CFrame.new(-5.8, -3.8, 0), stardustCyan, Enum.Material.Neon, false)
	createPart(voidModel, "FistR", Vector3.new(4.0, 2.5, 4.0), vSpawnCF * CFrame.new(5.8, -3.8, 0), stardustCyan, Enum.Material.Neon, false)

	createPart(voidModel, "LeftLeg", Vector3.new(3.4, 6.2, 3.4), vSpawnCF * CFrame.new(-2.2, -6.0, 0), voidMid, Enum.Material.Slate, true)
	createPart(voidModel, "RightLeg", Vector3.new(3.4, 6.2, 3.4), vSpawnCF * CFrame.new(2.2, -6.0, 0), voidMid, Enum.Material.Slate, true)

	local voidAtt = Instance.new("Attachment")
	voidAtt.Parent = vCore
	local vParticles = Instance.new("ParticleEmitter")
	vParticles.Size = NumberSequence.new(0.8, 0.2)
	vParticles.Color = ColorSequence.new(astralPurple, stardustCyan)
	vParticles.Rate = 22
	vParticles.Speed = NumberRange.new(2, 5)
	vParticles.Lifetime = NumberRange.new(0.8, 1.4)
	vParticles.Parent = voidAtt
end

-- =========================================================================
-- 3. ALL 11 PETS EXHIBITION (+ SPECIAL GOLDEN/RAINBOW SHOWCASE)
-- =========================================================================
local function buildPetModels(showroomFolder: Folder)
	local petFolder = Instance.new("Folder")
	petFolder.Name = "PetExhibition"
	petFolder.Parent = showroomFolder

	local petList = PetConfig.BASE_PET_IDS
	local totalPets = #petList

	local spacingX = 14
	local startX = -((totalPets - 1) * spacingX) / 2

	for i, petId in ipairs(petList) do
		local petDef = PetConfig.PETS[petId]
		if petDef then
			local posX = startX + (i - 1) * spacingX
			local pedCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(posX, 0, -18))
			local rarityColor = PetConfig.getRarityColor(petDef.rarity)
			local topCF = createPedestal(
				petFolder,
				petDef.id,
				pedCF,
				Vector3.new(8.5, 1.4, 8.5),
				petDef.icon .. " " .. petDef.name:upper(),
				string.format("%s • +%.0f%% Cash • +%.0f%% Gems", petDef.rarity, (petDef.cashMultiplier - 1) * 100, (petDef.gemMultiplier - 1) * 100),
				rarityColor
			)

			local model = PetModelBuilder.createModel(petDef, 1.05, false)
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
				end
			end
			model:PivotTo(topCF * CFrame.new(0, 1.6, 0))
			model.Parent = petFolder

			task.spawn(function()
				local basePivot = model:GetPivot()
				local angle = (i * 0.5)
				while model and model.Parent do
					angle += 0.03
					local bob = math.sin(angle * 2) * 0.2
					model:PivotTo(basePivot * CFrame.new(0, bob, 0) * CFrame.Angles(0, angle, 0))
					task.wait(0.03)
				end
			end)
		end
	end

	-- Special Tier Transformations Showcase (Golden & Rainbow variants)
	local tierShowcases = {
		{ id = "CrystalDoge_Golden", title = "🌟 GOLDEN CRYSTAL PUP", sub = "3x Boost • Crafted from 3 Normal", col = Color3.fromRGB(255, 215, 0) },
		{ id = "SparkleKitty_Rainbow", title = "🌈 RAINBOW SPARKLE KITTY", sub = "9x Boost • Crafted from 3 Golden", col = Color3.fromRGB(255, 100, 220) },
		{ id = "InfernoDragon_Golden", title = "🌟 GOLDEN INFERNO DRAKE", sub = "3x Boost • Pure Gold Plating", col = Color3.fromRGB(255, 215, 0) },
		{ id = "ChronosDrake_Rainbow", title = "🌈 RAINBOW CHRONOS DRAKE", sub = "9x Boost • Mythic Cosmic Stardust", col = Color3.fromRGB(0, 240, 255) },
	}
	local tierStartX = -((#tierShowcases - 1) * 24) / 2
	for i, showcase in ipairs(tierShowcases) do
		local petDef = PetConfig.PETS[showcase.id]
		if petDef then
			local posX = tierStartX + (i - 1) * 24
			local pedCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(posX, 0, -36))
			local topCF = createPedestal(
				petFolder,
				showcase.id,
				pedCF,
				Vector3.new(12, 1.6, 12),
				showcase.title,
				showcase.sub,
				showcase.col
			)

			local model = PetModelBuilder.createModel(petDef, 1.25, false)
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
				end
			end
			model:PivotTo(topCF * CFrame.new(0, 2.0, 0))
			model.Parent = petFolder

			task.spawn(function()
				local basePivot = model:GetPivot()
				local angle = (i * 0.8)
				while model and model.Parent do
					angle += 0.025
					local bob = math.sin(angle * 2) * 0.25
					model:PivotTo(basePivot * CFrame.new(0, bob, 0) * CFrame.Angles(0, angle, 0))
					task.wait(0.03)
				end
			end)
		end
	end
end

-- =========================================================================
-- 4. ALL 12 ORE MODELS EXHIBITION
-- =========================================================================
local function buildOreModels(showroomFolder: Folder)
	local oreFolder = Instance.new("Folder")
	oreFolder.Name = "OreExhibition"
	oreFolder.Parent = showroomFolder

	local oreOrder = {
		-- Zone 1
		"Stone", "Copper", "Iron", "Gold", "Diamond", "CosmicVoid",
		-- Zone 2
		"MagmaBasalt", "ThunderQuartz", "MoltenCrystal", "InfernalGeode",
		-- Zone 3
		"StarlightCrystal", "NebulaGeode", "AstralVoidstone", "DarkMatterCore",
	}

	local spacingX = 14
	local startX = -((#oreOrder - 1) * spacingX) / 2

	for i, oreKey in ipairs(oreOrder) do
		local oreDef = OreConfig.ORES[oreKey]
		if oreDef then
			local posX = startX + (i - 1) * spacingX
			local pedCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(posX, 0, 5))
			local topCF = createPedestal(
				oreFolder,
				oreDef.id,
				pedCF,
				Vector3.new(9, 1.2, 9),
				oreDef.icon .. " " .. oreDef.name:upper(),
				string.format("%s • %d HP • +$%s", oreDef.zone or "Ore", oreDef.maxHealth, tostring(oreDef.cashReward or 0)),
				oreDef.accentColor
			)

			local oreData = OreModelBuilder.buildOreModel(
				"ShowroomOre_" .. oreDef.id,
				oreDef.name,
				oreDef.color,
				oreDef.accentColor,
				math.clamp(oreDef.scale, 0.9, 1.35),
				topCF.Position + Vector3.new(0, 0.2, 0),
				oreDef.zone
			)
			for _, desc in ipairs(oreData.model:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
				end
			end
			oreData.model.Parent = oreFolder
		end
	end
end

-- =========================================================================
-- 5. ALL 5 3D LOOTBOX / CRATE MODELS
-- =========================================================================
local function buildLootBoxModels(showroomFolder: Folder)
	local boxFolder = Instance.new("Folder")
	boxFolder.Name = "LootBoxExhibition"
	boxFolder.Parent = showroomFolder

	local boxOrder = LootBoxConfig.ORDERED_IDS or {
		"wooden_chest",
		"gold_chest",
		"magma_chest",
		"void_chest",
		"cyber_chest",
	}

	local spacingX = 20
	local startX = -((#boxOrder - 1) * spacingX) / 2

	for i, boxKey in ipairs(boxOrder) do
		local boxDef = LootBoxConfig.BOXES[boxKey]
		if boxDef then
			local posX = startX + (i - 1) * spacingX
			local pedCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(posX, 0, 25))
			local tierColor = LootBoxConfig.TIER_COLORS[boxDef.tier] or Color3.fromRGB(255, 215, 0)
			local topCF = createPedestal(
				boxFolder,
				boxDef.id,
				pedCF,
				Vector3.new(12, 1.4, 10),
				boxDef.icon .. " " .. boxDef.name:upper(),
				string.format("%s Tier • %s", boxDef.tier, boxDef.title),
				tierColor
			)

			local chestModel = Instance.new("Model")
			chestModel.Name = "ShowroomChest_" .. boxDef.id
			chestModel.Parent = boxFolder

			local baseMaterial = if boxDef.modelType == "Wood" then Enum.Material.WoodPlanks
				elseif boxDef.modelType == "Gold" then Enum.Material.Glass
				elseif boxDef.modelType == "Magma" then Enum.Material.CrackedLava
				elseif boxDef.modelType == "Void" then Enum.Material.ForceField
				else Enum.Material.Glass

			local trimMaterial = if (boxDef.modelType == "Cyber" or boxDef.modelType == "Void" or boxDef.modelType == "Magma") then Enum.Material.Neon else Enum.Material.Metal

			local chestBase = createPart(chestModel, "Base", Vector3.new(4.2, 2.2, 3.0), topCF * CFrame.new(0, 1.1, 0), boxDef.color, baseMaterial, true)
			createPart(chestModel, "BandL", Vector3.new(0.35, 2.25, 3.06), topCF * CFrame.new(-1.8, 1.1, 0), boxDef.accentColor, trimMaterial, false)
			createPart(chestModel, "BandR", Vector3.new(0.35, 2.25, 3.06), topCF * CFrame.new(1.8, 1.1, 0), boxDef.accentColor, trimMaterial, false)
			createPart(chestModel, "Lid", Vector3.new(4.3, 1.2, 3.1), topCF * CFrame.new(0, 2.6, 0), boxDef.color, baseMaterial, true)
			createPart(chestModel, "LidCrown", Vector3.new(4.0, 0.45, 2.8), topCF * CFrame.new(0, 3.3, 0), boxDef.accentColor, trimMaterial, false)
			createPart(chestModel, "Latch", Vector3.new(0.9, 1.0, 0.4), topCF * CFrame.new(0, 2.0, -1.6), boxDef.accentColor, Enum.Material.Neon, false)

			local pLight = Instance.new("PointLight")
			pLight.Color = boxDef.accentColor
			pLight.Range = 12
			pLight.Brightness = 2.0
			pLight.Parent = chestBase
		end
	end
end

-- =========================================================================
-- 6. ALL 6 3D PICKAXES WEAPON GALLERY
-- =========================================================================
local function buildPickaxeModels(showroomFolder: Folder)
	local pickFolder = Instance.new("Folder")
	pickFolder.Name = "PickaxeExhibition"
	pickFolder.Parent = showroomFolder

	local pickaxes = {
		"shovel_rusty",
		"shovel_iron",
		"shovel_gold",
		"shovel_diamond",
		"shovel_void",
		"shovel_magma",
	}

	local spacingZ = 13
	local startZ = -45

	for i, pickId in ipairs(pickaxes) do
		local toolDef = ShopConfig.getShovel(pickId)
		if toolDef then
			local posZ = startZ + (i - 1) * spacingZ
			local pedCF = CFrame.new(SHOWROOM_CENTER + Vector3.new(-72, 0, posZ))
			local topCF = createPedestal(
				pickFolder,
				toolDef.id,
				pedCF,
				Vector3.new(9, 1.2, 8),
				toolDef.icon .. " " .. toolDef.name:upper(),
				string.format("%.1fx Power • +$%d/click", toolDef.powerMultiplier or 1, toolDef.clickCash or 0),
				toolDef.color
			)

			local pickModel = PickaxeModelBuilder.buildPickaxe(toolDef)
			for _, desc in ipairs(pickModel:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
				end
			end
			pickModel:PivotTo(topCF * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-15)))
			pickModel.Parent = pickFolder

			task.spawn(function()
				local basePivot = pickModel:GetPivot()
				local angle = (i * 0.6)
				while pickModel and pickModel.Parent do
					angle += 0.025
					local bob = math.sin(angle * 2) * 0.15
					pickModel:PivotTo(basePivot * CFrame.new(0, bob, 0) * CFrame.Angles(0, angle, 0))
					task.wait(0.03)
				end
			end)
		end
	end
end

-- =========================================================================
-- PUBLIC TELEPORT HANDLER
-- =========================================================================
function ShowroomService.teleportPlayer(player: Player, requestedTarget: string?): (boolean, string)
	local char = player.Character
	if not char then
		local ok, c = pcall(function()
			return player.CharacterAdded:Wait()
		end)
		char = if ok then c else nil
	end
	if not char then return false, "NoCharacter" end

	local root = char:WaitForChild("HumanoidRootPart", 4) :: BasePart?
	if not root then return false, "NoRootPart" end
	local humanoid = char:FindFirstChildOfClass("Humanoid")

	local distToShowroom = (root.Position - SHOWROOM_CENTER).Magnitude
	local targetCF: CFrame
	local destinationName: string

	if requestedTarget == "Showroom" then
		targetCF = CFrame.new(SHOWROOM_ARRIVAL)
		destinationName = "Showroom"
	elseif requestedTarget == "Town" then
		targetCF = CFrame.new(TOWN_SPAWN)
		destinationName = "Town"
	else
		-- Auto-toggle fallback only when no explicit destination is requested
		if distToShowroom < 140 then
			targetCF = CFrame.new(TOWN_SPAWN)
			destinationName = "Town"
		else
			targetCF = CFrame.new(SHOWROOM_ARRIVAL)
			destinationName = "Showroom"
		end
	end

	-- Stream around destination first if streaming is enabled to prevent falling through unstreamed parts
	if destinationName == "Showroom" and Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(targetCF.Position)
		end)
	end

	-- Unseat humanoid if seated
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
	end

	-- Zero out momentum so player doesn't fly off pad
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(targetCF)

	if destinationName == "Showroom" then
		lastArrivalTimes[player] = os.clock()
	end

	print(string.format("🚀 [ShowroomService] Teleported %s to %s at %s", player.Name, destinationName, tostring(targetCF.Position)))
	return true, destinationName
end

function ShowroomService.init()
	print("🧪 [ShowroomService] Initializing 3D Model Showroom Service...")

	-- 1. Register and bind RemoteFunction FIRST so player teleports work immediately
	local tpFn = Remotes.getFunction("DevTeleportToShowroom")
	tpFn.OnServerInvoke = function(player: Player, requestedTarget: any)
		local targetStr = if typeof(requestedTarget) == "string" then requestedTarget else nil
		return ShowroomService.teleportPlayer(player, targetStr)
	end

	-- 2. Bind chat commands for easy testing (/showroom, /dev, /town)
	local function hookPlayerChat(player: Player)
		player.Chatted:Connect(function(msg: string)
			local lower = string.lower(msg)
			if lower == "/showroom" or lower == "/devshowroom" or lower == "/tp showroom" or lower == "/dev" then
				ShowroomService.teleportPlayer(player, "Showroom")
			elseif lower == "/town" or lower == "/spawn" or lower == "/tp town" then
				ShowroomService.teleportPlayer(player, "Town")
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayerChat(p)
	end
	Players.PlayerAdded:Connect(hookPlayerChat)

	-- 3. Build or rebuild Showroom Platform in Workspace
	local existing = Workspace:FindFirstChild("DevShowroom")
	if existing then
		existing:Destroy()
	end

	local showroomFolder = Instance.new("Folder")
	showroomFolder.Name = "DevShowroom"
	showroomFolder.Parent = Workspace

	local sections = {
		{ name = "Island", fn = function() buildShowroomIsland(showroomFolder) end },
		{ name = "Bosses", fn = function() buildBossModels(showroomFolder) end },
		{ name = "Pets", fn = function() buildPetModels(showroomFolder) end },
		{ name = "Ores", fn = function() buildOreModels(showroomFolder) end },
		{ name = "LootBoxes", fn = function() buildLootBoxModels(showroomFolder) end },
		{ name = "Pickaxes", fn = function() buildPickaxeModels(showroomFolder) end },
	}

	for _, sec in ipairs(sections) do
		local ok, err = pcall(sec.fn)
		if ok then
			print(string.format("  ✓ [ShowroomService] Built %s", sec.name))
		else
			warn(string.format("  ❌ [ShowroomService] Failed to build %s: %s", sec.name, tostring(err)))
		end
	end

	print("✅ [ShowroomService] 3D Model Showroom Platform online at (500, 60, 0)!")
end

return ShowroomService
