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

-- Builds a stylized, adorable 3D Pet model for the ViewportFrame
local function buildPetModel(petDef: PetConfig.PetDef): Model
	local model = Instance.new("Model")
	model.Name = "HatchedPetPreview_" .. petDef.id

	-- Primary Body
	local body = Instance.new("Part")
	body.Name = "PrimaryPart"
	body.Size = Vector3.new(2.4, 2.4, 2.4)
	body.CFrame = CFrame.new(0, 0, 0)
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
		dMesh.Scale = Vector3.new(1.1, 1.45, 1.1)
		dMesh.Parent = body
	end
	body.Parent = model
	model.PrimaryPart = body

	-- Adorable Glossy Eyes (Left & Right)
	local eyePositions = {
		Vector3.new(-0.55, 0.25, -1.18),
		Vector3.new(0.55, 0.25, -1.18),
	}
	for i, eyeOffset in ipairs(eyePositions) do
		local eye = Instance.new("Part")
		eye.Name = "Eye_" .. i
		eye.Size = Vector3.new(0.38, 0.44, 0.15)
		eye.CFrame = CFrame.new(eyeOffset)
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
		glint.Size = Vector3.new(0.14, 0.16, 0.08)
		glint.CFrame = eye.CFrame * CFrame.new(0.08, 0.1, -0.07)
		glint.Color = Color3.fromRGB(255, 255, 255)
		glint.Material = Enum.Material.Neon
		glint.Anchored = true
		glint.CanCollide = false
		glint.Parent = model
	end

	-- Cute little button nose / muzzle
	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Size = Vector3.new(0.28, 0.22, 0.18)
	nose.CFrame = CFrame.new(0, -0.1, -1.22)
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
		local earConfigs = {
			{ pos = Vector3.new(-1.25, 1.0, -0.2), rot = Vector3.new(0, 0, -28) },
			{ pos = Vector3.new(1.25, 1.0, -0.2), rot = Vector3.new(0, 0, 28) },
		}
		for eIdx, eCfg in ipairs(earConfigs) do
			local ear = Instance.new("Part")
			ear.Name = "DogeEar_" .. eIdx
			ear.Size = Vector3.new(0.5, 0.9, 0.6)
			ear.CFrame = CFrame.new(eCfg.pos) * CFrame.Angles(0, 0, math.rad(eCfg.rot.Z))
			ear.Color = Color3.fromRGB(205, 165, 60)
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
		local earConfigs = {
			{ pos = Vector3.new(-0.85, 1.35, -0.2), rotZ = 16 },
			{ pos = Vector3.new(0.85, 1.35, -0.2), rotZ = -16 },
		}
		for eIdx, eCfg in ipairs(earConfigs) do
			local ear = Instance.new("Part")
			ear.Name = "KittyEar_" .. eIdx
			ear.Size = Vector3.new(0.55, 0.8, 0.45)
			ear.CFrame = CFrame.new(eCfg.pos) * CFrame.Angles(math.rad(10), 0, math.rad(eCfg.rotZ))
			ear.Color = Color3.fromRGB(255, 175, 195)
			ear.Material = Enum.Material.SmoothPlastic
			ear.Anchored = true
			ear.CanCollide = false
			ear.Parent = model

			local innerEar = Instance.new("Part")
			innerEar.Name = "InnerEar_" .. eIdx
			innerEar.Size = Vector3.new(0.3, 0.55, 0.25)
			innerEar.CFrame = ear.CFrame * CFrame.new(0, 0, -0.15)
			innerEar.Color = Color3.fromRGB(255, 120, 150)
			innerEar.Material = Enum.Material.SmoothPlastic
			innerEar.Anchored = true
			innerEar.CanCollide = false
			innerEar.Parent = model
		end
	elseif petDef.id == "NeonBunny" then
		-- Tall Upright Bunny Ears
		local earConfigs = {
			{ pos = Vector3.new(-0.55, 1.8, -0.1), rotZ = -6 },
			{ pos = Vector3.new(0.55, 1.8, -0.1), rotZ = 6 },
		}
		for eIdx, eCfg in ipairs(earConfigs) do
			local ear = Instance.new("Part")
			ear.Name = "BunnyEar_" .. eIdx
			ear.Size = Vector3.new(0.42, 1.55, 0.42)
			ear.CFrame = CFrame.new(eCfg.pos) * CFrame.Angles(math.rad(-8), 0, math.rad(eCfg.rotZ))
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
		local hornConfigs = {
			{ pos = Vector3.new(-0.85, 1.4, 0.2), rotZ = -25 },
			{ pos = Vector3.new(0.85, 1.4, 0.2), rotZ = 25 },
		}
		for hIdx, hCfg in ipairs(hornConfigs) do
			local horn = Instance.new("Part")
			horn.Name = "DragonHorn_" .. hIdx
			horn.Size = Vector3.new(0.5, 1.1, 0.5)
			horn.CFrame = CFrame.new(hCfg.pos) * CFrame.Angles(math.rad(-25), 0, math.rad(hCfg.rotZ))
			horn.Color = Color3.fromRGB(255, 100, 0)
			horn.Material = Enum.Material.Neon
			horn.Anchored = true
			horn.CanCollide = false
			horn.Parent = model
		end
	end

	return model
end

-- Emits a 2D expanding shockwave ring in ScreenGui
local function emitShockwave(parent: GuiObject, maxDiameter: number, duration: number, color: Color3)
	local ring = Instance.new("Frame")
	ring.Name = "Shockwave"
	ring.Size = UDim2.new(0, 40, 0, 40)
	ring.Position = UDim2.new(0.5, 0, 0.5, 0)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 8
	ring.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 4
	stroke.Transparency = 0.1
	stroke.Parent = ring

	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, maxDiameter, 0, maxDiameter),
	}):Play()

	local strokeTween = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Thickness = 1,
	})
	strokeTween:Play()
	strokeTween.Completed:Connect(function()
		ring:Destroy()
	end)
end

-- Emits small 2D glowing spark chips bursting outward in the GUI
local function emitSparks2D(parent: GuiObject, count: number, maxDist: number, color: Color3)
	for i = 1, count do
		local spark = Instance.new("Frame")
		spark.Size = UDim2.new(0, 10, 0, 10)
		spark.Position = UDim2.new(0.5, 0, 0.5, 0)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = color
		spark.BorderSizePixel = 0
		spark.ZIndex = 9
		spark.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = spark

		local angle = math.random() * math.pi * 2
		local dist = maxDist * (0.5 + math.random() * 0.5)
		local endX = math.cos(angle) * dist
		local endY = math.sin(angle) * dist

		local tween = TweenService:Create(spark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, endX, 0.5, endY),
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 2, 0, 2),
		})
		tween:Play()
		tween.Completed:Connect(function()
			spark:Destroy()
		end)
	end
end

-- Shakes the central EggHolder frame in Screen Space with rotation, offset, and squash/stretch
local function shakeHolder(
	holder: Frame,
	baseY: number,
	duration: number,
	maxAngleDeg: number,
	maxOffsetPx: number,
	squash: number
)
	local steps = 5
	local stepTime = duration / steps
	for s = 1, steps do
		local sign = (s % 2 == 1) and 1 or -1
		local progress = (1 - (s - 1) / steps)
		local angle = sign * maxAngleDeg * progress
		local offsetX = sign * maxOffsetPx * progress
		local offsetY = ((s % 2 == 1) and -maxOffsetPx * 0.5 or 0)

		local stretchX = 1 + ((s % 2 == 1) and squash or -squash * 0.5)
		local stretchY = 1 + ((s % 2 == 1) and -squash or squash * 0.5)

		holder.Rotation = angle
		holder.Position = UDim2.new(0.5, offsetX, baseY, offsetY)
		holder.Size = UDim2.new(0, 480 * stretchX, 0, 480 * stretchY)
		task.wait(stepTime)
	end

	-- Reset to center
	holder.Rotation = 0
	holder.Position = UDim2.new(0.5, 0, baseY, 0)
	holder.Size = UDim2.new(0, 480, 0, 480)
end

-- Violent high-frequency jitter for final pre-explosion stage
local function vibrateHolder(holder: Frame, baseY: number, duration: number, maxAngleDeg: number, maxOffsetPx: number)
	local elapsed = 0
	local dt = 0.02
	while elapsed < duration do
		local angle = (math.random() - 0.5) * 2 * maxAngleDeg
		local offsetX = (math.random() - 0.5) * 2 * maxOffsetPx
		local offsetY = (math.random() - 0.5) * 2 * maxOffsetPx

		local stretchX = 1 + (math.random() - 0.5) * 0.15
		local stretchY = 1 + (math.random() - 0.5) * 0.15

		holder.Rotation = angle
		holder.Position = UDim2.new(0.5, offsetX, baseY, offsetY)
		holder.Size = UDim2.new(0, 480 * stretchX, 0, 480 * stretchY)

		task.wait(dt)
		elapsed += dt
	end

	-- Reset
	holder.Rotation = 0
	holder.Position = UDim2.new(0.5, 0, baseY, 0)
	holder.Size = UDim2.new(0, 480, 0, 480)
end

-- Explodes 3D shell shards inside the ViewportFrame
local function explodeShardsInViewport(worldModel: WorldModel)
	local shardColors = {
		Color3.fromRGB(245, 248, 255),
		Color3.fromRGB(0, 220, 255),
		Color3.fromRGB(235, 240, 255),
		Color3.fromRGB(255, 225, 120),
	}

	for i = 1, 14 do
		local shard = Instance.new("Part")
		shard.Name = "Shard_" .. i
		shard.Size = Vector3.new(0.6 + math.random() * 0.4, 0.6 + math.random() * 0.4, 0.25)
		shard.Color = shardColors[math.random(1, #shardColors)]
		shard.Material = if math.random() > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		shard.Anchored = true
		shard.CanCollide = false

		local dir = Vector3.new(
			(math.random() - 0.5) * 2,
			(math.random() - 0.2) * 2,
			(math.random() - 0.5) * 2
		).Unit

		shard.CFrame = CFrame.new(dir * 0.5) * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		)
		shard.Parent = worldModel

		local targetCF = CFrame.new(dir * (7 + math.random() * 4)) * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		)

		local tween = TweenService:Create(shard, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = targetCF,
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			shard:Destroy()
		end)
	end
end

-- Main Public Entrypoint: Plays full-screen prominent egg hatching cinematic
function PetHatchAnimation.playHatch(petId: string)
	if isHatching then return end
	isHatching = true

	local petDef = PetConfig.PETS[petId]
	if not petDef then
		petDef = PetConfig.PETS.CrystalDoge
	end

	local hum = getHumanoid()
	local origWalkSpeed = 16
	local origJumpPower = 50
	if hum then
		origWalkSpeed = hum.WalkSpeed
		origJumpPower = hum.JumpPower
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	-- 1. Create Full-Screen Cinematic ScreenGui
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local hatchGui = Instance.new("ScreenGui")
	hatchGui.Name = "HatchCinematicGui"
	hatchGui.ResetOnSpawn = false
	hatchGui.DisplayOrder = 200
	hatchGui.IgnoreGuiInset = true
	hatchGui.Parent = playerGui

	-- 2. Dark Full-Screen Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name = "CinematicBackdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = hatchGui

	TweenService:Create(backdrop, TweenInfo.new(0.35), { BackgroundTransparency = 0.35 }):Play()

	-- 3. Rotating Sunburst Rays in the background behind the egg
	local rayContainer = Instance.new("Frame")
	rayContainer.Name = "SunburstContainer"
	rayContainer.Size = UDim2.new(0, 680, 0, 680)
	rayContainer.Position = UDim2.new(0.5, 0, 0.46, 0)
	rayContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	rayContainer.BackgroundTransparency = 1
	rayContainer.ZIndex = 2
	rayContainer.Parent = hatchGui

	for r = 0, 7 do
		local ray = Instance.new("Frame")
		ray.Size = UDim2.new(0, 75, 0, 650)
		ray.Position = UDim2.new(0.5, 0, 0.5, 0)
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Rotation = r * 45
		ray.BackgroundColor3 = Color3.fromRGB(255, 235, 160)
		ray.BackgroundTransparency = 0.94
		ray.BorderSizePixel = 0
		ray.ZIndex = 2
		ray.Parent = rayContainer

		local rayCorner = Instance.new("UICorner")
		rayCorner.CornerRadius = UDim.new(0.5, 0)
		rayCorner.Parent = ray
	end

	-- Slowly rotate rays
	local rayRotConn: RBXScriptConnection? = nil
	rayRotConn = RunService.RenderStepped:Connect(function(dt)
		if rayContainer and rayContainer.Parent then
			rayContainer.Rotation += dt * 18
		end
	end)

	-- 4. Central Large Egg Holder Frame (480x480) in the middle of the screen
	local eggHolder = Instance.new("Frame")
	eggHolder.Name = "EggHolder"
	eggHolder.Size = UDim2.new(0, 480, 0, 480)
	eggHolder.Position = UDim2.new(0.5, 0, 0.46, 0)
	eggHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	eggHolder.BackgroundTransparency = 1
	eggHolder.ZIndex = 5
	eggHolder.Parent = hatchGui

	-- 5. ViewportFrame for 3D Egg and Pet
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "EggViewport"
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0.5, -1, -1.2)
	viewport.Ambient = Color3.fromRGB(160, 170, 195)
	viewport.ZIndex = 6
	viewport.Parent = eggHolder

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local vCamera = Instance.new("Camera")
	vCamera.FieldOfView = 48
	vCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 7.2), Vector3.new(0, 0.2, 0))
	vCamera.Parent = viewport
	viewport.CurrentCamera = vCamera

	-- 6. Construct 3D Egg inside ViewportFrame
	local eggPart = Instance.new("Part")
	eggPart.Name = "ViewportEgg"
	eggPart.Size = Vector3.new(2.8, 4.0, 2.8)
	eggPart.CFrame = CFrame.new(0, 0, 0)
	eggPart.Color = Color3.fromRGB(246, 248, 255)
	eggPart.Material = Enum.Material.SmoothPlastic
	eggPart.Anchored = true
	eggPart.CanCollide = false
	eggPart.Parent = worldModel

	local eggMesh = Instance.new("SpecialMesh")
	eggMesh.MeshType = Enum.MeshType.Sphere
	eggMesh.Parent = eggPart

	-- Glowing Waist Band
	local eggBand = Instance.new("Part")
	eggBand.Name = "EggBand"
	eggBand.Size = Vector3.new(2.88, 0.4, 2.88)
	eggBand.CFrame = CFrame.new(0, -0.2, 0)
	eggBand.Color = Color3.fromRGB(0, 220, 255)
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = worldModel

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.025, 0.18, 1.025)
	bandMesh.Parent = eggBand

	-- Inner Glowing Neon Core (shows through cracks)
	local innerCore = Instance.new("Part")
	innerCore.Name = "InnerCore"
	innerCore.Size = Vector3.new(2.2, 3.2, 2.2)
	innerCore.CFrame = CFrame.new(0, 0, 0)
	innerCore.Color = Color3.fromRGB(255, 225, 80)
	innerCore.Material = Enum.Material.Neon
	innerCore.Transparency = 1
	innerCore.Anchored = true
	innerCore.CanCollide = false
	innerCore.Parent = worldModel

	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Sphere
	coreMesh.Parent = innerCore

	-- 4 3D Crack Fracture Veins on the Egg Surface
	local crackLines: { Part } = {}
	local crackConfigs = {
		{ cf = CFrame.new(0, 0.7, 1.38) * CFrame.Angles(0, 0, math.rad(35)), size = Vector3.new(1.1, 0.1, 0.1) },
		{ cf = CFrame.new(0.7, -0.2, 1.32) * CFrame.Angles(0, 0, math.rad(-40)), size = Vector3.new(1.3, 0.1, 0.1) },
		{ cf = CFrame.new(-0.8, 0.2, 1.28) * CFrame.Angles(0, 0, math.rad(55)), size = Vector3.new(1.15, 0.1, 0.1) },
		{ cf = CFrame.new(0.1, -0.9, 1.35) * CFrame.Angles(0, 0, math.rad(-20)), size = Vector3.new(1.4, 0.1, 0.1) },
	}

	for cIdx, cCfg in ipairs(crackConfigs) do
		local cPart = Instance.new("Part")
		cPart.Name = "Crack_" .. cIdx
		cPart.Size = cCfg.size
		cPart.CFrame = cCfg.cf
		cPart.Color = Color3.fromRGB(255, 235, 120)
		cPart.Material = Enum.Material.Neon
		cPart.Transparency = 1 -- Hidden until cracked
		cPart.Anchored = true
		cPart.CanCollide = false
		cPart.Parent = worldModel
		table.insert(crackLines, cPart)
	end

	-- Pop Egg onto screen with a bounce
	eggHolder.Size = UDim2.new(0, 50, 0, 50)
	playSound(SOUNDS.Thud, 0.5, 1.25)
	TweenService:Create(eggHolder, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 480, 0, 480),
	}):Play()
	task.wait(0.45)

	-- ==========================================
	-- 5-STAGE ESCALATING SHAKE & CRACK SEQUENCE
	-- ==========================================

	-- STAGE 1: First Hairline Crack
	playSound(SOUNDS.Thud, 0.5, 0.85)
	if crackLines[1] then crackLines[1].Transparency = 0 end
	emitSparks2D(hatchGui, 8, 120, Color3.fromRGB(255, 240, 160))
	shakeHolder(eggHolder, 0.46, 0.26, 9, 8, 0.05)
	task.wait(0.22)

	-- STAGE 2: Second Crack, wider wobble & shockwave
	playSound(SOUNDS.Thud, 0.55, 1.0)
	if crackLines[2] then crackLines[2].Transparency = 0 end
	emitShockwave(eggHolder, 280, 0.35, Color3.fromRGB(0, 220, 255))
	emitSparks2D(hatchGui, 14, 180, Color3.fromRGB(0, 230, 255))
	shakeHolder(eggHolder, 0.46, 0.28, 16, 16, 0.09)
	task.wait(0.20)

	-- STAGE 3: Third Deep Fracture, Inner Core begins shining
	playSound(SOUNDS.Thud, 0.65, 1.18)
	if crackLines[3] then crackLines[3].Transparency = 0 end
	innerCore.Transparency = 0.5
	emitShockwave(eggHolder, 380, 0.4, Color3.fromRGB(255, 230, 100))
	emitSparks2D(hatchGui, 20, 240, Color3.fromRGB(255, 220, 120))
	shakeHolder(eggHolder, 0.46, 0.32, 24, 24, 0.14)
	task.wait(0.18)

	-- STAGE 4: Violent Final Rattle & Blinding Energy
	playSound(SOUNDS.Thud, 0.75, 1.42)
	if crackLines[4] then crackLines[4].Transparency = 0 end
	for _, cl in ipairs(crackLines) do
		cl.Color = Color3.fromRGB(255, 255, 255)
	end
	innerCore.Transparency = 0.1
	innerCore.Color = Color3.fromRGB(255, 255, 255)
	emitShockwave(eggHolder, 480, 0.45, Color3.fromRGB(255, 255, 255))
	emitSparks2D(hatchGui, 30, 300, Color3.fromRGB(255, 255, 255))
	vibrateHolder(eggHolder, 0.46, 0.42, 30, 25)
	task.wait(0.12)

	-- STAGE 5: THE BIG BURST & REVEAL!
	-- Explode 3D Shards in Viewport
	explodeShardsInViewport(worldModel)

	-- Grand Screen Shockwave & Sparks
	emitShockwave(hatchGui, 900, 0.55, Color3.fromRGB(255, 240, 150))
	emitSparks2D(hatchGui, 36, 400, petDef.color)

	-- Triumphant Fanfare Sound
	playSound(SOUNDS.Fanfare, 0.65, 1.0)

	-- White screen flash
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.15
	flash.BorderSizePixel = 0
	flash.ZIndex = 25
	flash.Parent = hatchGui

	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.spawn(function()
		task.wait(0.45)
		flash:Destroy()
	end)

	-- Destroy original egg parts
	eggPart:Destroy()
	eggBand:Destroy()
	innerCore:Destroy()
	for _, cl in ipairs(crackLines) do
		cl:Destroy()
	end

	-- ==========================================
	-- PET MODEL SHOWCASE IN VIEWPORTFRAME
	-- ==========================================
	local petModel = buildPetModel(petDef)
	petModel.Parent = worldModel

	local primary = petModel.PrimaryPart :: BasePart
	primary.CFrame = CFrame.new(0, 3.5, 0)
	TweenService:Create(primary, TweenInfo.new(0.65, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(0, 0, 0),
	}):Play()

	-- Modern Glassmorphism Pet Showcase Card (Positioned neatly below the big egg viewport)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "PetShowcaseCard"
	cardFrame.Size = UDim2.new(0, 420, 0, 150)
	cardFrame.Position = UDim2.new(0.5, 0, 0.78, 0)
	cardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	cardFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	cardFrame.BackgroundTransparency = 0.1
	cardFrame.BorderSizePixel = 0
	cardFrame.ZIndex = 15
	cardFrame.Parent = hatchGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = cardFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = petDef.color
	cardStroke.Thickness = 2.5
	cardStroke.Transparency = 0.2
	cardStroke.Parent = cardFrame

	-- Top "HATCHED!" Header
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 0, 24)
	headerLabel.Position = UDim2.new(0, 0, 0, 10)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "✨ HATCHED! ✨"
	headerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 14
	headerLabel.ZIndex = 16
	headerLabel.Parent = cardFrame

	-- Pet Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 36)
	nameLabel.Position = UDim2.new(0, 0, 0, 34)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(petDef.name)
	nameLabel.TextColor3 = petDef.color
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 25
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.ZIndex = 16
	nameLabel.Parent = cardFrame

	-- Rarity Pill Badge
	local rarityBadge = Instance.new("Frame")
	rarityBadge.Size = UDim2.new(0, 115, 0, 22)
	rarityBadge.Position = UDim2.new(0.5, 0, 0, 76)
	rarityBadge.AnchorPoint = Vector2.new(0.5, 0)
	rarityBadge.BackgroundColor3 = petDef.color
	rarityBadge.BackgroundTransparency = 0.2
	rarityBadge.BorderSizePixel = 0
	rarityBadge.ZIndex = 16
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
	rarityLabel.ZIndex = 17
	rarityLabel.Parent = rarityBadge

	-- Stat Boosts
	local cashBoostPct = math.round((petDef.cashMultiplier - 1) * 100)
	local gemBoostPct = math.round((petDef.gemMultiplier - 1) * 100)

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, 0, 0, 24)
	statsLabel.Position = UDim2.new(0, 0, 0, 106)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "💵 +" .. cashBoostPct .. "% Cash   •   💎 +" .. gemBoostPct .. "% Gems"
	statsLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextSize = 13
	statsLabel.ZIndex = 16
	statsLabel.Parent = cardFrame

	-- Tap / Click anywhere button to dismiss
	local clickCatcher = Instance.new("TextButton")
	clickCatcher.Name = "ClickToDismiss"
	clickCatcher.Size = UDim2.new(1, 0, 1, 0)
	clickCatcher.BackgroundTransparency = 1
	clickCatcher.Text = ""
	clickCatcher.ZIndex = 30
	clickCatcher.Parent = hatchGui

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0, 26)
	hintLabel.Position = UDim2.new(0, 0, 0.94, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "[ Click anywhere to collect ]"
	hintLabel.TextColor3 = Color3.fromRGB(180, 195, 215)
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 14
	hintLabel.ZIndex = 31
	hintLabel.Parent = hatchGui

	-- Continuous pet slow idle spin & gentle bobbing in ViewportFrame
	local rotAngle = 0
	local rotConn: RBXScriptConnection? = nil
	rotConn = RunService.RenderStepped:Connect(function(dt)
		if not primary or not primary.Parent then return end
		rotAngle += dt * 2.4
		local bob = math.sin(rotAngle * 2) * 0.15
		for _, part in ipairs(petModel:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Keep relative offsets around primary while rotating
				-- Primary part handles base pivot
			end
		end
		-- Rotate pet model around Y
		petModel:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, rotAngle, 0))
	end)

	-- Wait for click dismiss or 3.2s auto-dismiss
	local dismissed = false
	local function doDismiss()
		if dismissed then return end
		dismissed = true

		if rotConn then
			rotConn:Disconnect()
			rotConn = nil
		end
		if rayRotConn then
			rayRotConn:Disconnect()
			rayRotConn = nil
		end

		playSound(SOUNDS.Collect, 0.5, 1.25)

		-- Zoom out / shrink eggHolder & fade card
		TweenService:Create(eggHolder, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 10, 0, 10),
		}):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardFrame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0.9, 0), BackgroundTransparency = 1 }):Play()

		task.wait(0.32)

		-- Cleanup
		hatchGui:Destroy()

		-- Restore Humanoid speed
		if hum then
			hum.WalkSpeed = origWalkSpeed
			hum.JumpPower = origJumpPower
		end

		isHatching = false
	end

	clickCatcher.MouseButton1Click:Connect(doDismiss)

	task.delay(3.5, function()
		if not dismissed then
			doDismiss()
		end
	end)
end

function PetHatchAnimation.init()
	local function bindChar(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			if isHatching then
				isHatching = false
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
