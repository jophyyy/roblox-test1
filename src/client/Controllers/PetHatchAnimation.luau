--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local PetHatchAnimation = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local isHatching = false

-- Verified crisp sounds
local SOUNDS = {
	Thud = "rbxassetid://6895079853",     -- Crisp chime/thud (pitch modulated for cracks)
	Fanfare = "rbxassetid://5153737200",  -- Triumphant level-up fanfare
	Collect = "rbxassetid://131886985",   -- Pleasant collect chime
}

local function playSound(soundId: string, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1.0
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function getHumanoid(): Humanoid?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(): BasePart?
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Builds a stylized, adorable 3D Pet model with ears, eyes, tail/horns, and glowing aura
local function buildPetModel(petDef: PetConfig.PetDef, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "HatchedPetPreview_" .. petDef.id

	-- Primary Body
	local body = Instance.new("Part")
	body.Name = "PrimaryPart"
	body.Size = Vector3.new(2.0, 2.0, 2.0)
	body.CFrame = cf
	body.Color = petDef.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false

	if petDef.meshType == "Sphere" then
		body.Shape = Enum.PartType.Ball
	elseif petDef.meshType == "Diamond" then
		local dMesh = Instance.new("SpecialMesh")
		dMesh.MeshType = Enum.MeshType.Sphere
		dMesh.Scale = Vector3.new(1.1, 1.4, 1.1)
		dMesh.Parent = body
	end
	body.Parent = model
	model.PrimaryPart = body

	-- Adorable Glossy Eyes (Left & Right)
	local eyePositions = {
		Vector3.new(-0.45, 0.2, -0.96),
		Vector3.new(0.45, 0.2, -0.96),
	}
	for i, eyeOffset in ipairs(eyePositions) do
		local eye = Instance.new("Part")
		eye.Name = "Eye_" .. i
		eye.Size = Vector3.new(0.32, 0.36, 0.15)
		eye.CFrame = cf * CFrame.new(eyeOffset)
		eye.Color = Color3.fromRGB(24, 24, 30)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model

		local eyeMesh = Instance.new("SpecialMesh")
		eyeMesh.MeshType = Enum.MeshType.Sphere
		eyeMesh.Parent = eye

		-- Cute white sparkle glint inside each eye
		local glint = Instance.new("Part")
		glint.Name = "Glint_" .. i
		glint.Size = Vector3.new(0.12, 0.14, 0.08)
		glint.CFrame = eye.CFrame * CFrame.new(0.06, 0.08, -0.06)
		glint.Color = Color3.fromRGB(255, 255, 255)
		glint.Material = Enum.Material.Neon
		glint.Anchored = true
		glint.CanCollide = false
		glint.Parent = model
	end

	-- Cute little button nose / muzzle
	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Size = Vector3.new(0.24, 0.18, 0.15)
	nose.CFrame = cf * CFrame.new(0, -0.08, -1.0)
	nose.Color = Color3.fromRGB(45, 35, 35)
	nose.Material = Enum.Material.SmoothPlastic
	nose.Anchored = true
	nose.CanCollide = false
	nose.Parent = model

	local noseMesh = Instance.new("SpecialMesh")
	noseMesh.MeshType = Enum.MeshType.Sphere
	noseMesh.Parent = nose

	-- Ears / Feature Accents according to pet breed
	if petDef.id == "CrystalDoge" then
		-- Floppy Puppy Ears
		local earOffsets = {
			{ pos = Vector3.new(-1.05, 0.85, -0.2), rot = Vector3.new(0, 0, -25) },
			{ pos = Vector3.new(1.05, 0.85, -0.2), rot = Vector3.new(0, 0, 25) },
		}
		for eIdx, eData in ipairs(earOffsets) do
			local ear = Instance.new("Part")
			ear.Name = "DogeEar_" .. eIdx
			ear.Size = Vector3.new(0.4, 0.75, 0.5)
			ear.CFrame = cf * CFrame.new(eData.pos) * CFrame.Angles(0, 0, math.rad(eData.rot.Z))
			ear.Color = Color3.fromRGB(200, 160, 60)
			ear.Material = Enum.Material.SmoothPlastic
			ear.Anchored = true
			ear.CanCollide = false
			ear.Parent = model

			local eMesh = Instance.new("SpecialMesh")
			eMesh.MeshType = Enum.MeshType.Sphere
			eMesh.Parent = ear
		end
	elseif petDef.id == "SparkleKitty" then
		-- Pointed Cat Ears with Pink Inner Lining
		local earOffsets = {
			Vector3.new(-0.7, 1.15, -0.2),
			Vector3.new(0.7, 1.15, -0.2),
		}
		for eIdx, ePos in ipairs(earOffsets) do
			local ear = Instance.new("Part")
			ear.Name = "KittyEar_" .. eIdx
			ear.Size = Vector3.new(0.45, 0.65, 0.4)
			ear.CFrame = cf * CFrame.new(ePos) * CFrame.Angles(math.rad(10), 0, if eIdx == 1 then math.rad(15) else math.rad(-15))
			ear.Color = Color3.fromRGB(255, 170, 190)
			ear.Material = Enum.Material.SmoothPlastic
			ear.Anchored = true
			ear.CanCollide = false
			ear.Parent = model

			local innerEar = Instance.new("Part")
			innerEar.Name = "InnerEar_" .. eIdx
			innerEar.Size = Vector3.new(0.25, 0.45, 0.2)
			innerEar.CFrame = ear.CFrame * CFrame.new(0, 0, -0.12)
			innerEar.Color = Color3.fromRGB(255, 120, 150)
			innerEar.Material = Enum.Material.SmoothPlastic
			innerEar.Anchored = true
			innerEar.CanCollide = false
			innerEar.Parent = model
		end
	elseif petDef.id == "NeonBunny" then
		-- Tall Upright Bunny Ears
		local earOffsets = {
			Vector3.new(-0.45, 1.45, -0.1),
			Vector3.new(0.45, 1.45, -0.1),
		}
		for eIdx, ePos in ipairs(earOffsets) do
			local ear = Instance.new("Part")
			ear.Name = "BunnyEar_" .. eIdx
			ear.Size = Vector3.new(0.35, 1.25, 0.35)
			ear.CFrame = cf * CFrame.new(ePos) * CFrame.Angles(math.rad(-8), 0, if eIdx == 1 then math.rad(-6) else math.rad(6))
			ear.Color = Color3.fromRGB(80, 240, 255)
			ear.Material = Enum.Material.Neon
			ear.Anchored = true
			ear.CanCollide = false
			ear.Parent = model

			local eMesh = Instance.new("SpecialMesh")
			eMesh.MeshType = Enum.MeshType.Sphere
			eMesh.Scale = Vector3.new(1.0, 1.8, 1.0)
			eMesh.Parent = ear
		end
	elseif petDef.id == "InfernoDragon" then
		-- Curved Fiery Horns
		local hornOffsets = {
			Vector3.new(-0.7, 1.15, 0.2),
			Vector3.new(0.7, 1.15, 0.2),
		}
		for hIdx, hPos in ipairs(hornOffsets) do
			local horn = Instance.new("Part")
			horn.Name = "DragonHorn_" .. hIdx
			horn.Size = Vector3.new(0.4, 0.9, 0.4)
			horn.CFrame = cf * CFrame.new(hPos) * CFrame.Angles(math.rad(-25), 0, if hIdx == 1 then math.rad(-25) else math.rad(25))
			horn.Color = Color3.fromRGB(255, 100, 0)
			horn.Material = Enum.Material.Neon
			horn.Anchored = true
			horn.CanCollide = false
			horn.Parent = model
		end
	end

	-- Soft Glowing Aura Particles
	local auraAttach = Instance.new("Attachment")
	auraAttach.Parent = body

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "PetAura"
	sparkles.Color = ColorSequence.new(petDef.color)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.LightEmission = 0.9
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Rate = 18
	sparkles.Speed = NumberRange.new(1.0, 2.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = auraAttach

	-- PointLight radiating from pet
	local pLight = Instance.new("PointLight")
	pLight.Color = petDef.color
	pLight.Brightness = 2.5
	pLight.Range = 14
	pLight.Parent = body

	return model
end

-- Creates an egg shake animation over `duration` seconds with specified angle and hop
local function shakeEgg(
	eggParts: { BasePart },
	baseCF: CFrame,
	duration: number,
	maxAngleDeg: number,
	hopHeight: number
)
	local steps = 5
	local stepTime = duration / steps
	for s = 1, steps do
		local angle = math.rad((s % 2 == 1 and 1 or -1) * maxAngleDeg * (1 - (s - 1) / steps))
		local hop = (s % 2 == 1) and hopHeight or 0
		local rollOffset = CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, angle)

		for _, p in ipairs(eggParts) do
			local rel = p:GetAttribute("RelCF") :: CFrame?
			if rel then
				p.CFrame = baseCF * rollOffset * rel
			end
		end
		task.wait(stepTime)
	end

	-- Reset to base
	for _, p in ipairs(eggParts) do
		local rel = p:GetAttribute("RelCF") :: CFrame?
		if rel then
			p.CFrame = baseCF * rel
		end
	end
end

-- High-frequency vibration for final pre-explosion rattle
local function vibrateEgg(eggParts: { BasePart }, baseCF: CFrame, duration: number, maxAngleDeg: number)
	local elapsed = 0
	local dt = 0.02
	while elapsed < duration do
		local angleZ = math.rad((math.random() - 0.5) * 2 * maxAngleDeg)
		local angleX = math.rad((math.random() - 0.5) * 2 * (maxAngleDeg * 0.5))
		local hop = math.random() * 0.15
		local offset = CFrame.new(0, hop, 0) * CFrame.Angles(angleX, 0, angleZ)

		for _, p in ipairs(eggParts) do
			local rel = p:GetAttribute("RelCF") :: CFrame?
			if rel then
				p.CFrame = baseCF * offset * rel
			end
		end
		task.wait(dt)
		elapsed += dt
	end

	-- Reset
	for _, p in ipairs(eggParts) do
		local rel = p:GetAttribute("RelCF") :: CFrame?
		if rel then
			p.CFrame = baseCF * rel
		end
	end
end

-- Explodes 3D shell shards outward into space
local function explodeEggShards(centerPos: Vector3, container: Folder)
	local shardColors = {
		Color3.fromRGB(245, 248, 255),
		Color3.fromRGB(0, 220, 255),
		Color3.fromRGB(235, 240, 255),
		Color3.fromRGB(255, 225, 120),
	}

	for i = 1, 14 do
		local shard = Instance.new("Part")
		shard.Name = "Shard_" .. i
		shard.Size = Vector3.new(0.5 + math.random() * 0.4, 0.5 + math.random() * 0.4, 0.2)
		shard.Color = shardColors[math.random(1, #shardColors)]
		shard.Material = if math.random() > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanTouch = false

		local dir = Vector3.new(
			(math.random() - 0.5) * 2,
			(math.random() - 0.2) * 2,
			(math.random() - 0.5) * 2
		).Unit

		shard.CFrame = CFrame.new(centerPos + dir * 0.5) * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		)
		shard.Parent = container

		local targetCF = CFrame.new(centerPos + dir * (6 + math.random() * 4)) * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		)

		local tween = TweenService:Create(shard, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = targetCF,
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			shard:Destroy()
		end)
	end
end

-- Main Public Entrypoint: Plays the full hatching sequence
function PetHatchAnimation.playHatch(petId: string)
	if isHatching then return end
	isHatching = true

	local petDef = PetConfig.PETS[petId]
	if not petDef then
		-- Fallback to default
		petDef = PetConfig.PETS.CrystalDoge
	end

	local hum = getHumanoid()
	local rootPart = getRootPart()
	if not hum or not rootPart then
		isHatching = false
		return
	end

	-- 1. Lock player movement & store original speeds
	local origWalkSpeed = hum.WalkSpeed
	local origJumpPower = hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0

	-- 2. Stage Location: ~4.2 studs directly in front of the player's chest
	local centerPos = rootPart.Position + rootPart.CFrame.LookVector * 4.2 + Vector3.new(0, 0.4, 0)
	local eggBaseCF = CFrame.new(centerPos, rootPart.Position + Vector3.new(0, 0.4, 0))

	-- Stage container in Workspace (client-only)
	local stageFolder = Instance.new("Folder")
	stageFolder.Name = "HatchAnimationStage"
	stageFolder.Parent = Workspace

	-- 3. ScreenGui Vignette & Cinematic Overlay
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local hatchGui = Instance.new("ScreenGui")
	hatchGui.Name = "HatchCinematicGui"
	hatchGui.ResetOnSpawn = false
	hatchGui.DisplayOrder = 100
	hatchGui.Parent = playerGui

	local vignette = Instance.new("Frame")
	vignette.Name = "CinematicVignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 1
	vignette.Parent = hatchGui

	TweenService:Create(vignette, TweenInfo.new(0.35), { BackgroundTransparency = 0.45 }):Play()

	-- 4. Build 3D Staged Egg
	local eggParts: { BasePart } = {}

	local eggPart = Instance.new("Part")
	eggPart.Name = "HatchingEgg"
	eggPart.Size = Vector3.new(2.4, 3.45, 2.4)
	eggPart.Color = Color3.fromRGB(246, 248, 255)
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = false
	eggPart.CanTouch = false
	eggPart:SetAttribute("RelCF", CFrame.new(0, 0, 0))
	eggPart.Parent = stageFolder

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Parent = eggPart
	table.insert(eggParts, eggPart)

	-- Glowing Waist Band
	local eggBand = Instance.new("Part")
	eggBand.Name = "EggBand"
	eggBand.Size = Vector3.new(2.48, 0.35, 2.48)
	eggBand.Color = Color3.fromRGB(0, 220, 255)
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.CanTouch = false
	eggBand:SetAttribute("RelCF", CFrame.new(0, -0.15, 0))
	eggBand.Parent = stageFolder

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.025, 0.18, 1.025)
	bandMesh.Parent = eggBand
	table.insert(eggParts, eggBand)

	-- Inner Glowing Neon Core (shows through cracks)
	local innerCore = Instance.new("Part")
	innerCore.Name = "InnerCore"
	innerCore.Size = Vector3.new(1.8, 2.6, 1.8)
	innerCore.Color = Color3.fromRGB(255, 225, 100)
	innerCore.Material = Enum.Material.Neon
	innerCore.Transparency = 1
	innerCore.Anchored = true
	innerCore.CanCollide = false
	innerCore.CanTouch = false
	innerCore:SetAttribute("RelCF", CFrame.new(0, 0, 0))
	innerCore.Parent = stageFolder

	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Sphere
	coreMesh.Parent = innerCore
	table.insert(eggParts, innerCore)

	-- 4 3D Crack Fracture Veins on the Egg Surface
	local crackLines: { Part } = {}
	local crackConfigs = {
		{ rel = CFrame.new(0, 0.6, -1.18) * CFrame.Angles(0, 0, math.rad(35)), size = Vector3.new(0.9, 0.08, 0.08) },
		{ rel = CFrame.new(0.6, -0.2, -1.12) * CFrame.Angles(0, 0, math.rad(-40)), size = Vector3.new(1.1, 0.08, 0.08) },
		{ rel = CFrame.new(-0.7, 0.2, -1.08) * CFrame.Angles(0, 0, math.rad(55)), size = Vector3.new(0.95, 0.08, 0.08) },
		{ rel = CFrame.new(0.1, -0.8, -1.15) * CFrame.Angles(0, 0, math.rad(-20)), size = Vector3.new(1.2, 0.08, 0.08) },
	}

	for cIdx, cCfg in ipairs(crackConfigs) do
		local cPart = Instance.new("Part")
		cPart.Name = "Crack_" .. cIdx
		cPart.Size = cCfg.size
		cPart.Color = Color3.fromRGB(255, 235, 120)
		cPart.Material = Enum.Material.Neon
		cPart.Transparency = 1 -- Hidden until cracked
		cPart.Anchored = true
		cPart.CanCollide = false
		cPart.CanTouch = false
		cPart:SetAttribute("RelCF", cCfg.rel)
		cPart.Parent = stageFolder
		table.insert(crackLines, cPart)
		table.insert(eggParts, cPart)
	end

	-- Ambient Light
	local eggLight = Instance.new("PointLight")
	eggLight.Color = Color3.fromRGB(0, 220, 255)
	eggLight.Brightness = 2.0
	eggLight.Range = 16
	eggLight.Parent = eggPart

	-- Shell Debris Particle Emitter
	local debrisAttach = Instance.new("Attachment")
	debrisAttach.Parent = eggPart

	local debris = Instance.new("ParticleEmitter")
	debris.Name = "ShellDebris"
	debris.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255)),
	})
	debris.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	debris.Rate = 0
	debris.Speed = NumberRange.new(5, 10)
	debris.SpreadAngle = Vector2.new(180, 180)
	debris.Acceleration = Vector3.new(0, -22, 0)
	debris.Lifetime = NumberRange.new(0.6, 1.1)
	debris.LightEmission = 0.8
	debris.Parent = debrisAttach

	-- Initial Spawn: Egg pops up from below with a bounce
	for _, p in ipairs(eggParts) do
		local rel = p:GetAttribute("RelCF") :: CFrame? or CFrame.new()
		p.CFrame = eggBaseCF * CFrame.new(0, -1.4, 0) * rel
	end

	playSound(SOUNDS.Thud, 0.45, 1.25)
	for _, p in ipairs(eggParts) do
		local rel = p:GetAttribute("RelCF") :: CFrame? or CFrame.new()
		TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = eggBaseCF * rel,
		}):Play()
	end
	task.wait(0.45)

	-- ==========================================
	-- 5-STAGE ESCALATING SHAKE & CRACK SEQUENCE
	-- ==========================================

	-- STAGE 1: First Hairline Crack
	playSound(SOUNDS.Thud, 0.5, 0.85)
	debris:Emit(10)
	if crackLines[1] then crackLines[1].Transparency = 0 end
	shakeEgg(eggParts, eggBaseCF, 0.26, 8, 0.08)
	task.wait(0.24)

	-- STAGE 2: Second Crack, wider wobble
	playSound(SOUNDS.Thud, 0.55, 1.0)
	debris:Emit(16)
	if crackLines[2] then crackLines[2].Transparency = 0 end
	shakeEgg(eggParts, eggBaseCF, 0.28, 14, 0.15)
	task.wait(0.22)

	-- STAGE 3: Third Deep Fracture, Inner Core begins shining
	playSound(SOUNDS.Thud, 0.65, 1.18)
	debris:Emit(24)
	if crackLines[3] then crackLines[3].Transparency = 0 end
	innerCore.Transparency = 0.5
	eggLight.Brightness = 3.5
	shakeEgg(eggParts, eggBaseCF, 0.32, 22, 0.22)
	task.wait(0.20)

	-- STAGE 4: Violent Final Rattle, Energy overflows
	playSound(SOUNDS.Thud, 0.75, 1.42)
	debris:Emit(35)
	if crackLines[4] then crackLines[4].Transparency = 0 end
	for _, cl in ipairs(crackLines) do
		cl.Color = Color3.fromRGB(255, 255, 255)
	end
	innerCore.Transparency = 0.15
	eggLight.Brightness = 6.0
	eggLight.Color = Color3.fromRGB(255, 255, 255)

	vibrateEgg(eggParts, eggBaseCF, 0.42, 28)
	task.wait(0.12)

	-- STAGE 5: THE BIG BURST & REVEAL!
	-- Explode 3D Shards
	explodeEggShards(centerPos, stageFolder)

	-- Grand Fanfare sound
	playSound(SOUNDS.Fanfare, 0.65, 1.0)

	-- White flash in GUI
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.2
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = hatchGui

	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.spawn(function()
		task.wait(0.45)
		flash:Destroy()
	end)

	-- Remove original egg parts
	for _, p in ipairs(eggParts) do
		p:Destroy()
	end

	-- ==========================================
	-- PET MODEL SHOWCASE & REVEAL CARD
	-- ==========================================
	local petModel = buildPetModel(petDef, CFrame.new(centerPos + Vector3.new(0, 0.8, 0)))
	petModel.Parent = stageFolder

	-- Elastic bounce entrance for pet
	local primary = petModel.PrimaryPart :: BasePart
	primary.CFrame = CFrame.new(centerPos + Vector3.new(0, 2.0, 0))
	TweenService:Create(primary, TweenInfo.new(0.65, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(centerPos),
	}):Play()

	-- Modern Glassmorphism Pet Showcase Card (Top/Center)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "PetShowcaseCard"
	cardFrame.Size = UDim2.new(0, 380, 0, 150)
	cardFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
	cardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	cardFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	cardFrame.BackgroundTransparency = 0.1
	cardFrame.BorderSizePixel = 0
	cardFrame.ZIndex = 10
	cardFrame.Parent = hatchGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = cardFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = petDef.color
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.2
	cardStroke.Parent = cardFrame

	-- Top "HATCHED!" Header
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 0, 26)
	headerLabel.Position = UDim2.new(0, 0, 0, 12)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "✨ HATCHED! ✨"
	headerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 14
	headerLabel.ZIndex = 11
	headerLabel.Parent = cardFrame

	-- Pet Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 36)
	nameLabel.Position = UDim2.new(0, 0, 0, 36)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(petDef.name)
	nameLabel.TextColor3 = petDef.color
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 24
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.ZIndex = 11
	nameLabel.Parent = cardFrame

	-- Rarity Pill Badge
	local rarityBadge = Instance.new("Frame")
	rarityBadge.Size = UDim2.new(0, 110, 0, 22)
	rarityBadge.Position = UDim2.new(0.5, 0, 0, 78)
	rarityBadge.AnchorPoint = Vector2.new(0.5, 0)
	rarityBadge.BackgroundColor3 = petDef.color
	rarityBadge.BackgroundTransparency = 0.2
	rarityBadge.BorderSizePixel = 0
	rarityBadge.ZIndex = 11
	rarityBadge.Parent = cardFrame

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 6)
	rCorner.Parent = rarityBadge

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 1, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(petDef.rarity)
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 12
	rarityLabel.ZIndex = 12
	rarityLabel.Parent = rarityBadge

	-- Stat Boosts
	local cashBoostPct = math.round((petDef.cashMultiplier - 1) * 100)
	local gemBoostPct = math.round((petDef.gemMultiplier - 1) * 100)

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, 0, 0, 24)
	statsLabel.Position = UDim2.new(0, 0, 0, 108)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "💵 +" .. cashBoostPct .. "% Cash   •   💎 +" .. gemBoostPct .. "% Gems"
	statsLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextSize = 13
	statsLabel.ZIndex = 11
	statsLabel.Parent = cardFrame

	-- Tap / Click anywhere button to dismiss
	local clickCatcher = Instance.new("TextButton")
	clickCatcher.Name = "ClickToDismiss"
	clickCatcher.Size = UDim2.new(1, 0, 1, 0)
	clickCatcher.BackgroundTransparency = 1
	clickCatcher.Text = ""
	clickCatcher.ZIndex = 20
	clickCatcher.Parent = hatchGui

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0, 28)
	hintLabel.Position = UDim2.new(0, 0, 0.88, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "[ Click anywhere to collect ]"
	hintLabel.TextColor3 = Color3.fromRGB(180, 195, 215)
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 14
	hintLabel.ZIndex = 21
	hintLabel.Parent = hatchGui

	-- Continuous pet slow idle spin & gentle bobbing
	local rotAngle = 0
	local rotConn: RBXScriptConnection? = nil
	rotConn = RunService.RenderStepped:Connect(function(dt)
		if not primary or not primary.Parent then return end
		rotAngle += dt * 2.2
		local bob = math.sin(rotAngle * 2) * 0.15
		primary.CFrame = CFrame.new(centerPos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, rotAngle, 0)
	end)

	-- Wait for click dismiss or 3.0s auto-dismiss
	local dismissed = false
	local function doDismiss()
		if dismissed then return end
		dismissed = true

		if rotConn then
			rotConn:Disconnect()
			rotConn = nil
		end

		playSound(SOUNDS.Collect, 0.5, 1.25)

		-- Pet zooms toward player rootPart while shrinking
		if primary and rootPart then
			local flyTween = TweenService:Create(primary, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = rootPart.CFrame,
				Size = Vector3.new(0.2, 0.2, 0.2),
				Transparency = 1,
			})
			flyTween:Play()
		end

		-- Fade out GUI
		TweenService:Create(vignette, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardFrame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0.05, 0), BackgroundTransparency = 1 }):Play()

		task.wait(0.35)

		-- Cleanup
		stageFolder:Destroy()
		hatchGui:Destroy()

		-- Restore Humanoid speed
		hum.WalkSpeed = origWalkSpeed
		hum.JumpPower = origJumpPower

		isHatching = false
	end

	clickCatcher.MouseButton1Click:Connect(doDismiss)

	task.delay(3.2, function()
		if not dismissed then
			doDismiss()
		end
	end)
end

function PetHatchAnimation.init()
	-- Listen for character death to safely cleanup if interrupted
	local function bindChar(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			if isHatching then
				isHatching = false
				local existingStage = Workspace:FindFirstChild("HatchAnimationStage")
				if existingStage then existingStage:Destroy() end
				local existingGui = player.PlayerGui:FindFirstChild("HatchCinematicGui")
				if existingGui then existingGui:Destroy() end
			end
		end)
	end

	if player.Character then
		bindChar(player.Character)
	end
	player.CharacterAdded:Connect(bindChar)
end

return PetHatchAnimation
