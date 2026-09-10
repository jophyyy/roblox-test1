--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local LootBoxConfig = require(ReplicatedStorage.Shared.Config.LootBoxConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetModelBuilder = require(ReplicatedStorage.Shared.Utils.PetModelBuilder)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local LootBoxAnimation = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local camera = workspace.CurrentCamera

local SOUNDS = {
	Thud = "rbxassetid://6895079853",      -- Heavy chest landing thud
	Click = "rbxassetid://6895079853",     -- Mechanism ratchet click
	Creak = "rbxassetid://9114223170",     -- Slow authentic chest lid creak
	Pop = "rbxassetid://6026985055",       -- Whoosh / item pop burst
	Fanfare = "rbxassetid://5153737200",   -- Victorious fanfare chime
	Chime = "rbxassetid://131886985",      -- Collect chime
}

local function playSound(soundId: string, volume: number?, pitch: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1.0
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
	return sound
end

local function weldParts(part0: BasePart, part1: BasePart)
	part1.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end

local function getFXFolder(): Folder
	local folder = workspace:FindFirstChild("LootBoxWorldFX")
	if not folder or not folder:IsA("Folder") then
		folder = Instance.new("Folder")
		folder.Name = "LootBoxWorldFX"
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- ====================================================================
-- 3D PHYSICAL CHEST BUILDER (In-World Workspace)
-- ====================================================================
local function buildPhysicalChest(
	boxDef: LootBoxConfig.LootBoxDef,
	rootCF: CFrame
): (Model, BasePart, BasePart, BasePart, BasePart?, PointLight, ParticleEmitter)
	local model = Instance.new("Model")
	model.Name = "PhysicalChest_" .. boxDef.id

	local isNeon = (boxDef.modelType == "Cyber" or boxDef.modelType == "Void" or boxDef.modelType == "Magma")
	local baseMaterial = if boxDef.modelType == "Wood" then Enum.Material.WoodPlanks
		elseif boxDef.modelType == "Gold" then Enum.Material.Glass
		elseif boxDef.modelType == "Magma" then Enum.Material.CrackedLava
		elseif boxDef.modelType == "Void" then Enum.Material.ForceField
		else Enum.Material.Glass

	local trimMaterial = if isNeon then Enum.Material.Neon else Enum.Material.Metal

	-- 1. Chest Base (PrimaryPart, Anchored)
	local base = Instance.new("Part")
	base.Name = "ChestBase"
	base.Size = Vector3.new(3.8, 2.0, 2.7)
	base.CFrame = rootCF
	base.Color = boxDef.color
	base.Material = baseMaterial
	base.Anchored = true
	base.CanCollide = false
	base.Parent = model

	-- Corner Reinforcement Straps (Left & Right)
	for _, xOffset in ipairs({ -1.75, 1.75 }) do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.32, 2.06, 2.76)
		band.CFrame = base.CFrame * CFrame.new(xOffset, 0, 0)
		band.Color = boxDef.accentColor
		band.Material = trimMaterial
		band.CanCollide = false
		band.Parent = model
		weldParts(base, band)
	end

	-- Center Base Band
	local centerBand = Instance.new("Part")
	centerBand.Name = "CenterBand"
	centerBand.Size = Vector3.new(0.32, 2.06, 2.76)
	centerBand.CFrame = base.CFrame * CFrame.new(0, 0, 0)
	centerBand.Color = boxDef.accentColor
	centerBand.Material = trimMaterial
	centerBand.CanCollide = false
	centerBand.Parent = model
	weldParts(base, centerBand)

	-- 2. Chest Lid (Rotates on rear hinge)
	local initialHingeCF = rootCF * CFrame.new(0, 1.0, 1.35)

	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(3.88, 1.15, 2.78)
	lid.CFrame = initialHingeCF * CFrame.new(0, 0.575, -1.39)
	lid.Color = boxDef.color
	lid.Material = baseMaterial
	lid.Anchored = true
	lid.CanCollide = false
	lid.Parent = model

	-- Lid Top Arched Crown (Welded to Lid)
	local lidCrown = Instance.new("Part")
	lidCrown.Name = "LidCrown"
	lidCrown.Size = Vector3.new(3.7, 0.45, 2.5)
	lidCrown.CFrame = lid.CFrame * CFrame.new(0, 0.7, 0)
	lidCrown.Color = boxDef.accentColor
	lidCrown.Material = trimMaterial
	lidCrown.CanCollide = false
	lidCrown.Parent = model
	weldParts(lid, lidCrown)

	-- 3. Front Lock Latch
	local latch = Instance.new("Part")
	latch.Name = "LockLatch"
	latch.Size = Vector3.new(0.85, 0.95, 0.35)
	latch.CFrame = base.CFrame * CFrame.new(0, 0.5, -1.5)
	latch.Color = boxDef.accentColor
	latch.Material = Enum.Material.Neon
	latch.Anchored = true
	latch.CanCollide = false
	latch.Parent = model

	-- 4. Glowing Internal Core Part + Real PointLight
	local core = Instance.new("Part")
	core.Name = "CoreGlow"
	core.Size = Vector3.new(3.0, 0.8, 2.0)
	core.CFrame = base.CFrame * CFrame.new(0, 0.4, 0)
	core.Color = boxDef.accentColor
	core.Material = Enum.Material.Neon
	core.Transparency = 1
	core.CanCollide = false
	core.Parent = model
	weldParts(base, core)

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "ChestPointLight"
	pointLight.Color = boxDef.accentColor
	pointLight.Range = 24
	pointLight.Brightness = 0
	pointLight.Shadows = true
	pointLight.Parent = core

	-- Interior Floating Magic Embers
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "InternalParticles"
	particles.Texture = "rbxassetid://244199991"
	particles.Color = ColorSequence.new(boxDef.accentColor, boxDef.color)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.65),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Lifetime = NumberRange.new(1.2, 2.4)
	particles.Rate = 0
	particles.Speed = NumberRange.new(2.5, 5.5)
	particles.SpreadAngle = Vector2.new(25, 25)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Parent = core

	model.PrimaryPart = base
	return model, base, lid, lidCrown, latch, pointLight, particles
end

-- ====================================================================
-- 3D PHYSICAL REWARD PROP BUILDER
-- ====================================================================
local function buildPhysicalRewardProp(
	reward: LootBoxConfig.RewardItem,
	spawnCF: CFrame
): Model
	local model = Instance.new("Model")
	model.Name = "RewardProp_" .. reward.category

	local rarityColor = LootBoxConfig.TIER_COLORS[reward.rarity] or Color3.fromRGB(255, 215, 0)

	if reward.category == "Cash" then
		-- 3D Stack of Gleaming Gold Ingots
		local root = Instance.new("Part")
		root.Name = "PrimaryPart"
		root.Size = Vector3.new(2.4, 0.8, 1.4)
		root.CFrame = spawnCF
		root.Color = Color3.fromRGB(255, 215, 0)
		root.Material = Enum.Material.Metal
		root.Reflectance = 0.45
		root.Anchored = true
		root.CanCollide = false
		root.Parent = model
		model.PrimaryPart = root

		-- Top stacked gold ingot
		local topBar = Instance.new("Part")
		topBar.Name = "TopBar"
		topBar.Size = Vector3.new(1.8, 0.75, 1.0)
		topBar.CFrame = root.CFrame * CFrame.new(0, 0.75, 0)
		topBar.Color = Color3.fromRGB(255, 225, 50)
		topBar.Material = Enum.Material.Metal
		topBar.Reflectance = 0.5
		topBar.CanCollide = false
		topBar.Parent = model
		weldParts(root, topBar)

		-- Sparkling Gold Dust Emitter
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxassetid://244199991"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 180, 0))
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Lifetime = NumberRange.new(0.6, 1.4)
		sparks.Rate = 22
		sparks.Speed = NumberRange.new(1.5, 3.5)
		sparks.Parent = root

	elseif reward.category == "Gems" then
		-- 3D Faceted Diamond / Radiant Gem Crystal
		local root = Instance.new("Part")
		root.Name = "PrimaryPart"
		root.Size = Vector3.new(1.8, 2.4, 1.8)
		root.CFrame = spawnCF
		root.Color = Color3.fromRGB(0, 230, 255)
		root.Material = Enum.Material.Neon
		root.Anchored = true
		root.CanCollide = false
		root.Parent = model
		model.PrimaryPart = root

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1.0, 1.5, 1.0)
		mesh.Parent = root

		-- Outer Crystal Shards
		for i = 1, 3 do
			local angle = (i - 1) * (math.pi * 2 / 3)
			local shard = Instance.new("Part")
			shard.Name = "Shard_" .. i
			shard.Size = Vector3.new(0.6, 1.6, 0.6)
			shard.CFrame = root.CFrame * CFrame.Angles(0, angle, math.rad(22)) * CFrame.new(0.8, 0, 0)
			shard.Color = Color3.fromRGB(120, 245, 255)
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.2
			shard.CanCollide = false
			shard.Parent = model
			weldParts(root, shard)
		end

		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(0, 230, 255)
		pLight.Range = 14
		pLight.Brightness = 2.5
		pLight.Parent = root

		local gemSparks = Instance.new("ParticleEmitter")
		gemSparks.Texture = "rbxassetid://244199991"
		gemSparks.Color = ColorSequence.new(Color3.fromRGB(0, 240, 255), Color3.fromRGB(200, 100, 255))
		gemSparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		gemSparks.Lifetime = NumberRange.new(0.8, 1.6)
		gemSparks.Rate = 26
		gemSparks.Speed = NumberRange.new(2, 4)
		gemSparks.Parent = root

	elseif reward.category == "Power" then
		-- 3D Pulsing Energy Plasma Sphere + Orbiting Ring
		local root = Instance.new("Part")
		root.Name = "PrimaryPart"
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.new(2.2, 2.2, 2.2)
		root.CFrame = spawnCF
		root.Color = Color3.fromRGB(255, 60, 220)
		root.Material = Enum.Material.Neon
		root.Anchored = true
		root.CanCollide = false
		root.Parent = model
		model.PrimaryPart = root

		-- Orbiting energy cylinder disc
		local ring = Instance.new("Part")
		ring.Name = "EnergyRing"
		ring.Size = Vector3.new(3.2, 0.15, 3.2)
		ring.CFrame = root.CFrame * CFrame.Angles(math.rad(45), math.rad(25), 0)
		ring.Color = Color3.fromRGB(180, 50, 255)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.3
		ring.CanCollide = false
		ring.Parent = model
		weldParts(root, ring)

		local ringMesh = Instance.new("SpecialMesh")
		ringMesh.MeshType = Enum.MeshType.Cylinder
		ringMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
		ringMesh.Parent = ring

		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(255, 80, 240)
		pLight.Range = 16
		pLight.Brightness = 3.0
		pLight.Parent = root

	elseif reward.category == "Pet" then
		-- 3D Stylized Pet Companion
		local petDef = if reward.petId and PetConfig.PETS then PetConfig.PETS[reward.petId] else PetConfig.PETS.CrystalDoge
		local pModel = PetModelBuilder.createModel(petDef or PetConfig.PETS.CrystalDoge, 1.0, true)
		pModel.Name = "RewardProp_Pet"
		pModel:PivotTo(spawnCF)
		return pModel
	end

	return model
end

-- ====================================================================
-- MAIN PUBLIC ENTRYPOINT: Physical In-World Unboxing
-- ====================================================================
function LootBoxAnimation.playOpen(
	boxDef: LootBoxConfig.LootBoxDef,
	reward: LootBoxConfig.RewardItem,
	remainingCount: number,
	onFinished: (() -> ())?,
	onOpenAnother: (() -> ())?
)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = char:FindFirstChildOfClass("Humanoid")

	local origWalkSpeed = if humanoid then humanoid.WalkSpeed else 16
	local origJumpPower = if humanoid then humanoid.JumpPower else 50
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end

	local fxFolder = getFXFolder()
	-- Clear any leftover FX models
	for _, child in ipairs(fxFolder:GetChildren()) do
		child:Destroy()
	end

	-- 1. Calculate Ground Position Directly in front of Player
	local rootCF = hrp.CFrame
	local lookVec = rootCF.LookVector
	local targetXZ = rootCF.Position + (lookVec * 6.5)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { char, fxFolder }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(targetXZ + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
	local floorY = if hit then hit.Position.Y else (rootCF.Position.Y - 2.8)
	local chestBaseY = floorY + 1.0 -- half base height
	local chestPos = Vector3.new(targetXZ.X, chestBaseY, targetXZ.Z)
	-- Orient chest to face back directly towards the player
	local chestFinalCF = CFrame.lookAt(chestPos, Vector3.new(rootCF.Position.X, chestPos.Y, rootCF.Position.Z))

	-- 2. Build Physical Chest in Workspace
	local chestModel, base, lid, lidCrown, latch, pointLight, particles = buildPhysicalChest(boxDef, chestFinalCF)
	chestModel.Parent = fxFolder

	-- Helper to update lid rotation cleanly on rear hinge
	local function setLidAngle(angleDeg: number)
		local currentHingeCF = base.CFrame * CFrame.new(0, 1.0, 1.35)
		local rotCF = currentHingeCF * CFrame.Angles(-math.rad(angleDeg), 0, 0)
		lid.CFrame = rotCF * CFrame.new(0, 0.575, -1.39)
		lidCrown.CFrame = lid.CFrame * CFrame.new(0, 0.7, 0)
		if latch and latch.Parent then
			latch.CFrame = lid.CFrame * CFrame.new(0, -0.5, -1.45)
		end
	end

	-- 3. Cinematic Camera Transition (Scriptable Over-the-Shoulder / Focal)
	local origCameraType = camera.CameraType
	local origCameraSubject = camera.CameraSubject
	local origCameraCF = camera.CFrame

	camera.CameraType = Enum.CameraType.Scriptable

	local camPos = rootCF.Position + (rootCF.RightVector * 2.8) + (rootCF.UpVector * 2.4) - (lookVec * 2.4)
	local camLookTarget = chestPos + Vector3.new(0, 1.8, 0)
	local cinematicCamCF = CFrame.lookAt(camPos, camLookTarget)

	TweenService:Create(camera, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = cinematicCamCF,
	}):Play()

	-- 4. Screen Overlay HUD (Minimal, Non-obtrusive controls)
	local existingGui = playerGui:FindFirstChild("LootBoxPhysicalGui")
	if existingGui then
		existingGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LootBoxPhysicalGui"
	screenGui.DisplayOrder = 170
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Skip / Fast-Forward Button (Top Right)
	local isSkipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Size = UDim2.new(0, 120, 0, 38)
	skipBtn.Position = UDim2.new(1, -140, 0, 24)
	skipBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	skipBtn.Text = "⚡ SKIP ❯❯"
	skipBtn.TextColor3 = Color3.fromRGB(210, 225, 255)
	skipBtn.Font = Enum.Font.GothamBlack
	skipBtn.TextSize = 13
	skipBtn.BorderSizePixel = 0
	skipBtn.Parent = screenGui

	local skCorner = Instance.new("UICorner")
	skCorner.CornerRadius = UDim.new(0, 9)
	skCorner.Parent = skipBtn

	local skStroke = Instance.new("UIStroke")
	skStroke.Color = Color3.fromRGB(70, 85, 120)
	skStroke.Thickness = 1.2
	skStroke.Parent = skipBtn

	skipBtn.MouseButton1Click:Connect(function()
		isSkipped = true
		skipBtn.Visible = false
	end)

	-- ================================================================
	-- PHASE 1: CHEST DROP & IMPACT
	-- ================================================================
	-- Position chest high initially
	local dropHeight = 8
	base.CFrame = chestFinalCF * CFrame.new(0, dropHeight, 0)
	setLidAngle(0)

	playSound(SOUNDS.Thud, 0.4, 0.7)
	local dropTween = TweenService:Create(base, TweenInfo.new(0.48, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		CFrame = chestFinalCF,
	})
	dropTween:Play()

	-- Keep lid attached during drop
	local dropConn: RBXScriptConnection? = nil
	dropConn = RunService.RenderStepped:Connect(function()
		setLidAngle(0)
	end)

	dropTween.Completed:Wait()
	if dropConn then
		dropConn:Disconnect()
		dropConn = nil
	end
	base.CFrame = chestFinalCF
	setLidAngle(0)

	playSound(SOUNDS.Thud, 0.8, 1.0)

	-- ================================================================
	-- PHASE 2: ANTICIPATION RATTLE & LIGHT SEEP
	-- ================================================================
	local rattleDuration = 0.85
	local rattleStart = os.clock()
	local lastClickTime = 0
	local rattleConn: RBXScriptConnection? = nil

	rattleConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - rattleStart
		if elapsed >= rattleDuration or isSkipped then
			if rattleConn then
				rattleConn:Disconnect()
				rattleConn = nil
			end
			return
		end

		local progress = elapsed / rattleDuration
		local intensity = 0.03 + (progress * 0.12)
		local speed = 28 + (progress * 30)

		local rotOffset = math.sin(elapsed * speed) * intensity
		base.CFrame = chestFinalCF * CFrame.Angles(0, 0, rotOffset)
		setLidAngle(math.abs(rotOffset * 25))

		-- Light begins leaking through the seam
		pointLight.Brightness = progress * 1.5

		if os.clock() - lastClickTime >= (0.16 - (progress * 0.08)) then
			lastClickTime = os.clock()
			playSound(SOUNDS.Click, 0.25, 2.0 + (progress * 0.6))
		end
	end)

	if not isSkipped then
		task.wait(rattleDuration)
	end
	if rattleConn then
		rattleConn:Disconnect()
		rattleConn = nil
	end

	base.CFrame = chestFinalCF
	setLidAngle(0)

	-- ================================================================
	-- PHASE 3: SLOW AUTHENTIC CREAKING OPEN
	-- ================================================================
	skipBtn.Visible = false

	-- Detach/dissolve latch
	if latch and latch.Parent then
		TweenService:Create(latch, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		Debris:AddItem(latch, 0.3)
	end

	-- Start authentic creaking audio and emission particles
	playSound(SOUNDS.Creak, 0.85, 0.95)
	particles.Rate = 35

	local openDuration = if isSkipped then 0.2 else 2.2
	local openStart = os.clock()
	local openConn: RBXScriptConnection? = nil

	openConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - openStart
		local rawAlpha = math.clamp(elapsed / openDuration, 0, 1)
		-- Smooth sine curve for slow, heavy creaking feel
		local smoothAlpha = math.sin(rawAlpha * math.pi * 0.5)

		local currentAngle = smoothAlpha * 118
		setLidAngle(currentAngle)

		-- PointLight ramps up dynamically casting light on player and ground
		pointLight.Brightness = 1.5 + (smoothAlpha * 3.5)

		if rawAlpha >= 1 or isSkipped then
			if openConn then
				openConn:Disconnect()
				openConn = nil
			end
		end
	end)

	if not isSkipped then
		task.wait(openDuration)
	end
	if openConn then
		openConn:Disconnect()
		openConn = nil
	end

	setLidAngle(118)
	pointLight.Brightness = 5.0

	-- ================================================================
	-- PHASE 4: PHYSICAL REWARD POPS OUT!
	-- ================================================================
	playSound(SOUNDS.Pop, 0.9, 1.1)
	playSound(SOUNDS.Fanfare, 0.75, 1.0)

	-- Spawn physical reward inside the open chest
	local propSpawnCF = chestFinalCF * CFrame.new(0, 0.6, 0)
	local rewardProp = buildPhysicalRewardProp(reward, propSpawnCF)
	rewardProp.Parent = fxFolder

	local propRoot = rewardProp.PrimaryPart :: BasePart
	local apexCF = chestFinalCF * CFrame.new(0, 4.2, 0)

	-- Pop-out upward launch animation with bounce
	local popTween = TweenService:Create(propRoot, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = apexCF,
	})
	popTween:Play()

	-- 3D Overhead Billboard attached to floating reward
	local rarityColor = LootBoxConfig.TIER_COLORS[reward.rarity] or Color3.fromRGB(255, 215, 0)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RewardBillboard"
	billboard.Size = UDim2.new(0, 360, 0, 130)
	billboard.StudsOffset = Vector3.new(0, 2.3, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = propRoot

	local bBg = Instance.new("Frame")
	bBg.Size = UDim2.new(1, 0, 1, 0)
	bBg.BackgroundColor3 = Color3.fromRGB(15, 16, 24)
	bBg.BackgroundTransparency = 0.2
	bBg.BorderSizePixel = 0
	bBg.Parent = billboard

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 14)
	bCorner.Parent = bBg

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = rarityColor
	bStroke.Thickness = 2.2
	bStroke.Parent = bBg

	-- Rarity Pill
	local rarityPill = Instance.new("TextLabel")
	rarityPill.Size = UDim2.new(0, 120, 0, 20)
	rarityPill.Position = UDim2.new(0.5, 0, 0, 10)
	rarityPill.AnchorPoint = Vector2.new(0.5, 0)
	rarityPill.BackgroundColor3 = rarityColor
	rarityPill.Text = string.format("★ %s ★", reward.rarity:upper())
	rarityPill.TextColor3 = if reward.rarity == "Mythic" or reward.rarity == "Common" then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(255, 255, 255)
	rarityPill.Font = Enum.Font.GothamBlack
	rarityPill.TextSize = 11
	rarityPill.BorderSizePixel = 0
	rarityPill.Parent = bBg

	local rpCorner = Instance.new("UICorner")
	rpCorner.CornerRadius = UDim.new(0, 6)
	rpCorner.Parent = rarityPill

	-- Reward Name & Amount
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 34)
	titleLabel.Position = UDim2.new(0, 10, 0, 36)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = reward.icon .. "  " .. reward.name
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 20
	titleLabel.Parent = bBg

	-- Subtitle Description
	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -20, 0, 22)
	subLabel.Position = UDim2.new(0, 10, 0, 72)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = reward.description
	subLabel.TextColor3 = Color3.fromRGB(180, 195, 220)
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 12
	subLabel.Parent = bBg

	-- Continuous Floating Bobbing & Spin Loop for the physical reward
	local hoverConn: RBXScriptConnection? = nil
	local hoverStart = os.clock()

	hoverConn = RunService.RenderStepped:Connect(function()
		if not propRoot or not propRoot.Parent then return end
		local now = os.clock() - hoverStart
		local bobY = math.sin(now * 3.0) * 0.25
		local spinAngle = (now * 45) % 360

		propRoot.CFrame = apexCF * CFrame.new(0, bobY, 0) * CFrame.Angles(0, math.rad(spinAngle), 0)

		-- Also keep parts of the reward model aligned
		for _, part in ipairs(rewardProp:GetChildren()) do
			if part:IsA("BasePart") and part ~= propRoot then
				-- They maintain relative offsets
			end
		end
	end)

	-- ================================================================
	-- PHASE 5: ACTION BUTTONS (Collect / Open Another)
	-- ================================================================
	local actionRow = Instance.new("Frame")
	actionRow.Size = UDim2.new(0, 380, 0, 52)
	actionRow.Position = UDim2.new(0.5, 0, 1, -80)
	actionRow.AnchorPoint = Vector2.new(0.5, 0)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = screenGui

	local hasMore = (remainingCount > 0)

	-- Collect Button
	local collectBtn = Instance.new("TextButton")
	collectBtn.Size = if hasMore then UDim2.new(0.48, 0, 1, 0) else UDim2.new(1, 0, 1, 0)
	collectBtn.Position = UDim2.new(0, 0, 0, 0)
	collectBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 115)
	collectBtn.Text = "✓ COLLECT"
	collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectBtn.Font = Enum.Font.GothamBlack
	collectBtn.TextSize = 15
	collectBtn.BorderSizePixel = 0
	collectBtn.Parent = actionRow

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 10)
	cbCorner.Parent = collectBtn

	local cbStroke = Instance.new("UIStroke")
	cbStroke.Color = Color3.fromRGB(120, 255, 180)
	cbStroke.Thickness = 1.5
	cbStroke.Parent = collectBtn

	-- Open Another Button
	local openMoreBtn: TextButton? = nil
	if hasMore then
		openMoreBtn = Instance.new("TextButton")
		openMoreBtn.Size = UDim2.new(0.48, 0, 1, 0)
		openMoreBtn.Position = UDim2.new(0.52, 0, 0, 0)
		openMoreBtn.BackgroundColor3 = boxDef.color
		openMoreBtn.Text = string.format("OPEN ANOTHER (%d)", remainingCount)
		openMoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		openMoreBtn.Font = Enum.Font.GothamBlack
		openMoreBtn.TextSize = 13
		openMoreBtn.BorderSizePixel = 0
		openMoreBtn.Parent = actionRow

		local omCorner = Instance.new("UICorner")
		omCorner.CornerRadius = UDim.new(0, 10)
		omCorner.Parent = openMoreBtn

		local omStroke = Instance.new("UIStroke")
		omStroke.Color = boxDef.accentColor
		omStroke.Thickness = 1.5
		omStroke.Parent = openMoreBtn
	end

	-- Slide in action row
	actionRow.Position = UDim2.new(0.5, 0, 1, 20)
	TweenService:Create(actionRow, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -85),
	}):Play()

	-- Clean Collection Animation Handler
	local isClosing = false
	local function doCollect(onDone: () -> ())
		if isClosing then return end
		isClosing = true

		if hoverConn then
			hoverConn:Disconnect()
			hoverConn = nil
		end

		playSound(SOUNDS.Chime, 0.7, 1.2)

		-- Hide billboard and UI buttons
		billboard.Enabled = false
		screenGui:Destroy()

		-- Tween reward prop into player's torso (vacuum absorption arc)
		local targetAbsorptionCF = hrp.CFrame * CFrame.new(0, 0.5, 0)
		local absorbTween = TweenService:Create(propRoot, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			CFrame = targetAbsorptionCF,
		})
		absorbTween:Play()

		-- Fade out chest model
		for _, part in ipairs(chestModel:GetDescendants()) do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			elseif part:IsA("PointLight") then
				TweenService:Create(part, TweenInfo.new(0.35), { Brightness = 0 }):Play()
			end
		end

		absorbTween.Completed:Wait()

		-- Restore camera and humanoid controls
		camera.CameraType = origCameraType or Enum.CameraType.Custom
		if origCameraSubject then
			camera.CameraSubject = origCameraSubject
		elseif humanoid then
			camera.CameraSubject = humanoid
		end

		if humanoid then
			humanoid.WalkSpeed = origWalkSpeed
			humanoid.JumpPower = origJumpPower
		end

		-- Clean up workspace models
		rewardProp:Destroy()
		chestModel:Destroy()

		onDone()
	end

	collectBtn.MouseButton1Click:Connect(function()
		doCollect(function()
			if onFinished then
				onFinished()
			end
		end)
	end)

	if openMoreBtn and onOpenAnother then
		openMoreBtn.MouseButton1Click:Connect(function()
			doCollect(function()
				onOpenAnother()
			end)
		end)
	end

	-- Auto-collect failsafe after 14 seconds if left open
	task.delay(14, function()
		if not isClosing then
			doCollect(function()
				if onFinished then
					onFinished()
				end
			end)
		end
	end)
end

return LootBoxAnimation
