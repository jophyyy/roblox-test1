--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetModelBuilder = require(ReplicatedStorage.Shared.Utils.PetModelBuilder)

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
local function buildPetModel(petDef: PetConfig.PetDef, scaleMult: number?): Model
	return PetModelBuilder.createModel(petDef, (scaleMult or 1.0) * 1.1, false)
end

-- Emits a 2D expanding shockwave ring in ScreenGui
local function emitShockwave(parent: GuiObject, maxDiameter: number, duration: number, color: Color3)
	local ring = Instance.new("Frame")
	ring.Name = "Shockwave"
	ring.Size = UDim2.new(0, 30, 0, 30)
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
	for _ = 1, count do
		local spark = Instance.new("Frame")
		spark.Size = UDim2.new(0, 9, 0, 9)
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

-- Explodes 3D shell shards inside a ViewportFrame's WorldModel
local function explodeShardsInViewport(worldModel: WorldModel)
	local shardColors = {
		Color3.fromRGB(245, 248, 255),
		Color3.fromRGB(0, 220, 255),
		Color3.fromRGB(235, 240, 255),
		Color3.fromRGB(255, 225, 120),
	}

	for i = 1, 12 do
		local shard = Instance.new("Part")
		shard.Name = "Shard_" .. i
		shard.Size = Vector3.new(0.5 + math.random() * 0.4, 0.5 + math.random() * 0.4, 0.25)
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

-- Represents a single animated egg slot on screen
type EggSlot = {
	holder: Frame,
	viewport: ViewportFrame,
	worldModel: WorldModel,
	eggPart: Part,
	eggBand: Part,
	innerCore: Part,
	crackLines: { Part },
	petDef: PetConfig.PetDef,
	petModel: Model?,
	basePos: UDim2,
	baseSize: number,
}

local function createEggSlot(
	parent: Instance,
	petDef: PetConfig.PetDef,
	basePos: UDim2,
	baseSize: number,
	scaleMult: number
): EggSlot
	local holder = Instance.new("Frame")
	holder.Name = "EggSlotHolder"
	holder.Size = UDim2.new(0, baseSize, 0, baseSize)
	holder.Position = basePos
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 5
	holder.Parent = parent

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
	viewport.Parent = holder

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local vCamera = Instance.new("Camera")
	vCamera.FieldOfView = 48
	vCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 7.2), Vector3.new(0, 0.2, 0))
	vCamera.Parent = viewport
	viewport.CurrentCamera = vCamera

	-- 3D Egg
	local eggPart = Instance.new("Part")
	eggPart.Name = "ViewportEgg"
	eggPart.Size = Vector3.new(2.8 * scaleMult, 4.0 * scaleMult, 2.8 * scaleMult)
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
	eggBand.Size = Vector3.new(2.88 * scaleMult, 0.4 * scaleMult, 2.88 * scaleMult)
	eggBand.CFrame = CFrame.new(0, -0.2 * scaleMult, 0)
	eggBand.Color = Color3.fromRGB(0, 220, 255)
	eggBand.Material = Enum.Material.Neon
	eggBand.Anchored = true
	eggBand.CanCollide = false
	eggBand.Parent = worldModel

	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.025, 0.18, 1.025)
	bandMesh.Parent = eggBand

	-- Inner Glowing Neon Core (revealed through cracks)
	local innerCore = Instance.new("Part")
	innerCore.Name = "InnerCore"
	innerCore.Size = Vector3.new(2.2 * scaleMult, 3.2 * scaleMult, 2.2 * scaleMult)
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

	-- 4 3D Crack Fracture Veins
	local crackLines: { Part } = {}
	local crackConfigs = {
		{ cf = CFrame.new(0, 0.7 * scaleMult, 1.38 * scaleMult) * CFrame.Angles(0, 0, math.rad(35)), size = Vector3.new(1.1 * scaleMult, 0.1 * scaleMult, 0.1 * scaleMult) },
		{ cf = CFrame.new(0.7 * scaleMult, -0.2 * scaleMult, 1.32 * scaleMult) * CFrame.Angles(0, 0, math.rad(-40)), size = Vector3.new(1.3 * scaleMult, 0.1 * scaleMult, 0.1 * scaleMult) },
		{ cf = CFrame.new(-0.8 * scaleMult, 0.2 * scaleMult, 1.28 * scaleMult) * CFrame.Angles(0, 0, math.rad(55)), size = Vector3.new(1.15 * scaleMult, 0.1 * scaleMult, 0.1 * scaleMult) },
		{ cf = CFrame.new(0.1 * scaleMult, -0.9 * scaleMult, 1.35 * scaleMult) * CFrame.Angles(0, 0, math.rad(-20)), size = Vector3.new(1.4 * scaleMult, 0.1 * scaleMult, 0.1 * scaleMult) },
	}

	for cIdx, cCfg in ipairs(crackConfigs) do
		local cPart = Instance.new("Part")
		cPart.Name = "Crack_" .. cIdx
		cPart.Size = cCfg.size
		cPart.CFrame = cCfg.cf
		cPart.Color = Color3.fromRGB(255, 235, 120)
		cPart.Material = Enum.Material.Neon
		cPart.Transparency = 1
		cPart.Anchored = true
		cPart.CanCollide = false
		cPart.Parent = worldModel
		table.insert(crackLines, cPart)
	end

	return {
		holder = holder,
		viewport = viewport,
		worldModel = worldModel,
		eggPart = eggPart,
		eggBand = eggBand,
		innerCore = innerCore,
		crackLines = crackLines,
		petDef = petDef,
		petModel = nil,
		basePos = basePos,
		baseSize = baseSize,
	}
end

-- Shakes all active egg slots together in Screen Space with rotation, offset, and squash/stretch
local function shakeAllSlots(
	slots: { EggSlot },
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

		for _, slot in ipairs(slots) do
			slot.holder.Rotation = angle
			slot.holder.Position = UDim2.new(slot.basePos.X.Scale, slot.basePos.X.Offset + offsetX, slot.basePos.Y.Scale, slot.basePos.Y.Offset + offsetY)
			slot.holder.Size = UDim2.new(0, slot.baseSize * stretchX, 0, slot.baseSize * stretchY)
		end
		task.wait(stepTime)
	end

	-- Reset to neutral base positions
	for _, slot in ipairs(slots) do
		slot.holder.Rotation = 0
		slot.holder.Position = slot.basePos
		slot.holder.Size = UDim2.new(0, slot.baseSize, 0, slot.baseSize)
	end
end

-- High-frequency jitter for final pre-explosion stage
local function vibrateAllSlots(slots: { EggSlot }, duration: number, maxAngleDeg: number, maxOffsetPx: number)
	local elapsed = 0
	local dt = 0.02
	while elapsed < duration do
		local angle = (math.random() - 0.5) * 2 * maxAngleDeg
		local offsetX = (math.random() - 0.5) * 2 * maxOffsetPx
		local offsetY = (math.random() - 0.5) * 2 * maxOffsetPx

		local stretchX = 1 + (math.random() - 0.5) * 0.15
		local stretchY = 1 + (math.random() - 0.5) * 0.15

		for _, slot in ipairs(slots) do
			slot.holder.Rotation = angle
			slot.holder.Position = UDim2.new(slot.basePos.X.Scale, slot.basePos.X.Offset + offsetX, slot.basePos.Y.Scale, slot.basePos.Y.Offset + offsetY)
			slot.holder.Size = UDim2.new(0, slot.baseSize * stretchX, 0, slot.baseSize * stretchY)
		end

		task.wait(dt)
		elapsed += dt
	end

	for _, slot in ipairs(slots) do
		slot.holder.Rotation = 0
		slot.holder.Position = slot.basePos
		slot.holder.Size = UDim2.new(0, slot.baseSize, 0, slot.baseSize)
	end
end

-- Creates an individual pet showcase glassmorphism card
local function createPetShowcaseCard(
	parent: Instance,
	petDef: PetConfig.PetDef,
	pos: UDim2,
	width: number,
	height: number
): Frame
	local card = Instance.new("Frame")
	card.Name = "PetCard_" .. petDef.id
	card.Size = UDim2.new(0, width, 0, height)
	card.Position = pos
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.ZIndex = 15
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = petDef.color
	cardStroke.Thickness = 2.2
	cardStroke.Transparency = 0.2
	cardStroke.Parent = card

	-- Top "HATCHED!" Header
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 0, 22)
	headerLabel.Position = UDim2.new(0, 0, 0, 8)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "✨ HATCHED! ✨"
	headerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 12
	headerLabel.ZIndex = 16
	headerLabel.Parent = card

	-- Pet Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(petDef.name)
	nameLabel.TextColor3 = petDef.color
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = if width > 350 then 24 else 18
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.ZIndex = 16
	nameLabel.Parent = card

	-- Rarity Pill Badge
	local rarityBadge = Instance.new("Frame")
	rarityBadge.Size = UDim2.new(0, 105, 0, 20)
	rarityBadge.Position = UDim2.new(0.5, 0, 0, 62)
	rarityBadge.AnchorPoint = Vector2.new(0.5, 0)
	rarityBadge.BackgroundColor3 = petDef.color
	rarityBadge.BackgroundTransparency = 0.2
	rarityBadge.BorderSizePixel = 0
	rarityBadge.ZIndex = 16
	rarityBadge.Parent = card

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 5)
	rCorner.Parent = rarityBadge

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 1, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(petDef.rarity)
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 11
	rarityLabel.ZIndex = 17
	rarityLabel.Parent = rarityBadge

	-- Stat Boosts
	local cashBoostPct = math.round((petDef.cashMultiplier - 1) * 100)
	local gemBoostPct = math.round((petDef.gemMultiplier - 1) * 100)

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, 0, 0, 22)
	statsLabel.Position = UDim2.new(0, 0, 0, 88)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "💵 +" .. cashBoostPct .. "% Cash  •  💎 +" .. gemBoostPct .. "% Gems"
	statsLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextSize = if width > 350 then 13 else 11
	statsLabel.ZIndex = 16
	statsLabel.Parent = card

	return card
end

-- Main Public Entrypoint: Accepts a single petId string OR an array of petIds { string }
function PetHatchAnimation.playHatch(petInput: any)
	if isHatching then return end
	isHatching = true

	local petIds: { string } = {}
	if type(petInput) == "string" then
		table.insert(petIds, petInput)
	elseif type(petInput) == "table" then
		for _, id in ipairs(petInput) do
			if type(id) == "string" then
				table.insert(petIds, id)
			end
		end
	end

	if #petIds == 0 then
		table.insert(petIds, "CrystalDoge")
	end

	local isTriple = (#petIds >= 3)
	local hatchCount = if isTriple then 3 else 1

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

	TweenService:Create(backdrop, TweenInfo.new(0.35), { BackgroundTransparency = 0.82 }):Play()

	-- 3. Rotating Sunburst Rays
	local rayContainer = Instance.new("Frame")
	rayContainer.Name = "SunburstContainer"
	rayContainer.Size = UDim2.new(0, 750, 0, 750)
	rayContainer.Position = UDim2.new(0.5, 0, 0.44, 0)
	rayContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	rayContainer.BackgroundTransparency = 1
	rayContainer.ZIndex = 2
	rayContainer.Parent = hatchGui

	for r = 0, 7 do
		local ray = Instance.new("Frame")
		ray.Size = UDim2.new(0, 80, 0, 720)
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

	local rayRotConn: RBXScriptConnection? = nil
	rayRotConn = RunService.RenderStepped:Connect(function(dt)
		if rayContainer and rayContainer.Parent then
			rayContainer.Rotation += dt * 18
		end
	end)

	-- 4. Setup Egg Slots
	local slots: { EggSlot } = {}

	if isTriple then
		-- 3 Eggs Side by Side (Left, Center, Right)
		local slotLayouts = {
			{ pos = UDim2.new(0.23, 0, 0.44, 0), size = 330, mult = 0.85 },
			{ pos = UDim2.new(0.50, 0, 0.44, 0), size = 340, mult = 0.88 },
			{ pos = UDim2.new(0.77, 0, 0.44, 0), size = 330, mult = 0.85 },
		}
		for i = 1, 3 do
			local petDef = PetConfig.PETS[petIds[i]] or PetConfig.PETS.CrystalDoge
			local layout = slotLayouts[i]
			local slot = createEggSlot(hatchGui, petDef, layout.pos, layout.size, layout.mult)
			table.insert(slots, slot)
		end
	else
		-- Single Big Egg in Center (480x480)
		local petDef = PetConfig.PETS[petIds[1]] or PetConfig.PETS.CrystalDoge
		local slot = createEggSlot(hatchGui, petDef, UDim2.new(0.5, 0, 0.46, 0), 480, 1.0)
		table.insert(slots, slot)
	end

	-- Initial entrance: Eggs bounce up into view
	for _, slot in ipairs(slots) do
		slot.holder.Size = UDim2.new(0, 40, 0, 40)
	end

	playSound(SOUNDS.Thud, 0.5, 1.25)
	for idx, slot in ipairs(slots) do
		task.delay((idx - 1) * 0.08, function()
			TweenService:Create(slot.holder, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, slot.baseSize, 0, slot.baseSize),
			}):Play()
		end)
	end
	task.wait(0.5)

	-- ==========================================
	-- 5-STAGE ESCALATING SHAKE & CRACK SEQUENCE
	-- ==========================================

	-- STAGE 1: First Hairline Crack
	playSound(SOUNDS.Thud, 0.5, 0.85)
	for _, slot in ipairs(slots) do
		if slot.crackLines[1] then slot.crackLines[1].Transparency = 0 end
		emitSparks2D(slot.holder, 8, 100, Color3.fromRGB(255, 240, 160))
	end
	shakeAllSlots(slots, 0.26, 9, 8, 0.05)
	task.wait(0.22)

	-- STAGE 2: Second Crack & Shockwaves
	playSound(SOUNDS.Thud, 0.55, 1.0)
	for _, slot in ipairs(slots) do
		if slot.crackLines[2] then slot.crackLines[2].Transparency = 0 end
		emitShockwave(slot.holder, 260, 0.35, Color3.fromRGB(0, 220, 255))
		emitSparks2D(slot.holder, 12, 150, Color3.fromRGB(0, 230, 255))
	end
	shakeAllSlots(slots, 0.28, 16, 16, 0.09)
	task.wait(0.20)

	-- STAGE 3: Third Deep Fracture & Glowing Core
	playSound(SOUNDS.Thud, 0.65, 1.18)
	for _, slot in ipairs(slots) do
		if slot.crackLines[3] then slot.crackLines[3].Transparency = 0 end
		slot.innerCore.Transparency = 0.5
		emitShockwave(slot.holder, 350, 0.4, Color3.fromRGB(255, 230, 100))
		emitSparks2D(slot.holder, 18, 200, Color3.fromRGB(255, 220, 120))
	end
	shakeAllSlots(slots, 0.32, 24, 24, 0.14)
	task.wait(0.18)

	-- STAGE 4: Violent Final Rattle & Blinding White Glow
	playSound(SOUNDS.Thud, 0.75, 1.42)
	for _, slot in ipairs(slots) do
		if slot.crackLines[4] then slot.crackLines[4].Transparency = 0 end
		for _, cl in ipairs(slot.crackLines) do
			cl.Color = Color3.fromRGB(255, 255, 255)
		end
		slot.innerCore.Transparency = 0.1
		slot.innerCore.Color = Color3.fromRGB(255, 255, 255)
		emitShockwave(slot.holder, 440, 0.45, Color3.fromRGB(255, 255, 255))
		emitSparks2D(slot.holder, 25, 260, Color3.fromRGB(255, 255, 255))
	end
	vibrateAllSlots(slots, 0.42, 30, 24)
	task.wait(0.12)

	-- STAGE 5: THE BIG BURST & PET REVEAL!
	for _, slot in ipairs(slots) do
		explodeShardsInViewport(slot.worldModel)
		slot.eggPart:Destroy()
		slot.eggBand:Destroy()
		slot.innerCore:Destroy()
		for _, cl in ipairs(slot.crackLines) do
			cl:Destroy()
		end
	end

	emitShockwave(hatchGui, 950, 0.55, Color3.fromRGB(255, 240, 150))
	emitSparks2D(hatchGui, 40, 450, Color3.fromRGB(255, 215, 0))

	-- Triumphant Fanfare Sound
	playSound(SOUNDS.Fanfare, 0.65, 1.0)

	-- Full Screen Radiant Flash
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

	-- ==========================================
	-- PET REVEAL & SHOWCASE CARDS
	-- ==========================================
	local createdCards: { Frame } = {}

	for i, slot in ipairs(slots) do
		local petScale = if isTriple then 0.85 else 1.0
		local petModel = buildPetModel(slot.petDef, petScale)
		petModel.Parent = slot.worldModel
		slot.petModel = petModel

		petModel:PivotTo(CFrame.new(0, 0, 0))

		-- Create Showcase Card below the slot
		local cardPos: UDim2
		local cardWidth: number
		local cardHeight: number

		if isTriple then
			local cardLayouts = {
				UDim2.new(0.23, 0, 0.77, 0),
				UDim2.new(0.50, 0, 0.77, 0),
				UDim2.new(0.77, 0, 0.77, 0),
			}
			cardPos = cardLayouts[i]
			cardWidth = 295
			cardHeight = 120
		else
			cardPos = UDim2.new(0.5, 0, 0.78, 0)
			cardWidth = 420
			cardHeight = 150
		end

		local card = createPetShowcaseCard(hatchGui, slot.petDef, cardPos, cardWidth, cardHeight)
		table.insert(createdCards, card)
	end

	-- Non-blocking Collect Button at bottom
	local collectBtn = Instance.new("TextButton")
	collectBtn.Name = "CollectBtn"
	collectBtn.Size = UDim2.new(0, 240, 0, 38)
	collectBtn.Position = UDim2.new(0.5, 0, 0.94, 0)
	collectBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	collectBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 130)
	collectBtn.Text = "✨ COLLECT ✨"
	collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectBtn.Font = Enum.Font.GothamBlack
	collectBtn.TextSize = 15
	collectBtn.BorderSizePixel = 0
	collectBtn.ZIndex = 30
	collectBtn.Parent = hatchGui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = collectBtn

	-- Continuous 360° Pet Rotation in ViewportFrames
	local rotAngle = 0
	local rotConn: RBXScriptConnection? = nil
	rotConn = RunService.RenderStepped:Connect(function(dt)
		rotAngle += dt * 2.4
		local bob = math.sin(rotAngle * 2) * 0.15
		for _, slot in ipairs(slots) do
			if slot.petModel and slot.petModel.PrimaryPart then
				slot.petModel:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, rotAngle, 0))
			end
		end
	end)

	-- Dismissal Logic
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

		-- Zoom out / shrink egg holders and cards
		for _, slot in ipairs(slots) do
			TweenService:Create(slot.holder, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 10, 0, 10),
			}):Play()
		end
		for _, card in ipairs(createdCards) do
			TweenService:Create(card, TweenInfo.new(0.3), {
				Position = card.Position + UDim2.new(0, 0, 0.1, 0),
				BackgroundTransparency = 1,
			}):Play()
		end
		TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()

		task.wait(0.32)

		-- Cleanup
		hatchGui:Destroy()

		isHatching = false
	end

	collectBtn.MouseButton1Click:Connect(doDismiss)

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
