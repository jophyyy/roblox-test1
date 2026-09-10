--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local MeteorClient = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- UI References
local screenGui: ScreenGui
local alertBanner: Frame
local alertTitle: TextLabel
local alertSubtitle: TextLabel
local alertTimer: TextLabel
local activeShowcaseFrame: Frame? = nil

-- Right-Side Timer Widget References
local timerWidget: Frame
local widgetStroke: UIStroke
local widgetHeaderLabel: TextLabel
local widgetTimeLabel: TextLabel
local widgetSubLabel: TextLabel
local widgetIcon: TextLabel

-- State tracking
local currentServerState: string = "IDLE"
local targetNextEventTime: number = 0
local currentZoneName: string? = nil
local currentZoneIcon: string? = nil

-- Active visual instances
local activeBeaconFolder: Folder? = nil
local activeCountdownThread: thread? = nil

-- Audio effects
local function playSound(soundId: string, speed: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Distance-attenuated camera shake
local function shakeCamera(intensity: number, duration: number)
	task.spawn(function()
		local startTime = os.clock()
		while (os.clock() - startTime) < duration do
			local elapsed = os.clock() - startTime
			local progress = 1 - (elapsed / duration)
			local currentIntensity = intensity * progress

			local offsetX = (math.random() - 0.5) * 2 * currentIntensity
			local offsetY = (math.random() - 0.5) * 2 * currentIntensity
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(offsetY), math.rad(offsetX), 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Builds floating HUD banners for event notifications
local function buildHUD()
	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("MeteorEventHUDGui")
	if existing then existing:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MeteorEventHUDGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 18
	screenGui.Parent = pGui

	-- 1. Alert Banner (Top Center Countdown)
	alertBanner = Instance.new("Frame")
	alertBanner.Name = "MeteorAlertBanner"
	alertBanner.Size = UDim2.new(0, 480, 0, 75)
	alertBanner.Position = UDim2.new(0.5, 0, -0.2, 0) -- Hidden above
	alertBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	alertBanner.BackgroundColor3 = Color3.fromRGB(28, 16, 18)
	alertBanner.BorderSizePixel = 0
	alertBanner.Parent = screenGui

	local aCorner = Instance.new("UICorner")
	aCorner.CornerRadius = UDim.new(0, 16)
	aCorner.Parent = alertBanner

	local aStroke = Instance.new("UIStroke")
	aStroke.Color = Color3.fromRGB(255, 80, 30)
	aStroke.Thickness = 2.5
	aStroke.Parent = alertBanner

	alertTitle = Instance.new("TextLabel")
	alertTitle.Name = "Title"
	alertTitle.Size = UDim2.new(1, -20, 0.40, 0)
	alertTitle.Position = UDim2.new(0, 10, 0.08, 0)
	alertTitle.BackgroundTransparency = 1
	alertTitle.Text = "☄️ CELESTIAL METEOR INCOMING! ☄️"
	alertTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	alertTitle.Font = Enum.Font.GothamBlack
	alertTitle.TextSize = 17
	alertTitle.TextStrokeTransparency = 0.15
	alertTitle.Parent = alertBanner

	alertSubtitle = Instance.new("TextLabel")
	alertSubtitle.Name = "Subtitle"
	alertSubtitle.Size = UDim2.new(1, -20, 0.30, 0)
	alertSubtitle.Position = UDim2.new(0, 10, 0.45, 0)
	alertSubtitle.BackgroundTransparency = 1
	alertSubtitle.Text = "Target Crash Site: Zone 1 Meadow Fields"
	alertSubtitle.TextColor3 = Color3.fromRGB(240, 240, 250)
	alertSubtitle.Font = Enum.Font.GothamBold
	alertSubtitle.TextSize = 13
	alertSubtitle.TextStrokeTransparency = 0.2
	alertSubtitle.Parent = alertBanner

	alertTimer = Instance.new("TextLabel")
	alertTimer.Name = "Timer"
	alertTimer.Size = UDim2.new(1, -20, 0.25, 0)
	alertTimer.Position = UDim2.new(0, 10, 0.72, 0)
	alertTimer.BackgroundTransparency = 1
	alertTimer.Text = "Impact in: 15s"
	alertTimer.TextColor3 = Color3.fromRGB(255, 110, 50)
	alertTimer.Font = Enum.Font.GothamBlack
	alertTimer.TextSize = 13
	alertTimer.TextStrokeTransparency = 0.2
	alertTimer.Parent = alertBanner

	-- 2. Right-Side Meteor Event Countdown & Status Widget
	timerWidget = Instance.new("Frame")
	timerWidget.Name = "MeteorTimerWidget"
	timerWidget.Size = UDim2.new(0, 142, 0, 58)
	timerWidget.Position = UDim2.new(1, -16, 0.5, -75)
	timerWidget.AnchorPoint = Vector2.new(1, 1)
	timerWidget.BackgroundColor3 = Color3.fromRGB(18, 16, 26)
	timerWidget.BackgroundTransparency = 0.15
	timerWidget.BorderSizePixel = 0
	timerWidget.Parent = screenGui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 14)
	tCorner.Parent = timerWidget

	widgetStroke = Instance.new("UIStroke")
	widgetStroke.Name = "BorderStroke"
	widgetStroke.Thickness = 2.0
	widgetStroke.Color = Color3.fromRGB(75, 125, 215)
	widgetStroke.Parent = timerWidget

	local tGrad = Instance.new("UIGradient")
	tGrad.Rotation = 90
	tGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 28, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 14, 24)),
	})
	tGrad.Parent = timerWidget

	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.Size = UDim2.new(1, -16, 0, 16)
	headerRow.Position = UDim2.new(0, 8, 0, 5)
	headerRow.BackgroundTransparency = 1
	headerRow.Parent = timerWidget

	widgetIcon = Instance.new("TextLabel")
	widgetIcon.Name = "Icon"
	widgetIcon.Size = UDim2.new(0, 16, 1, 0)
	widgetIcon.Position = UDim2.new(0, 0, 0, 0)
	widgetIcon.BackgroundTransparency = 1
	widgetIcon.Text = "☄️"
	widgetIcon.TextSize = 12
	widgetIcon.Parent = headerRow

	widgetHeaderLabel = Instance.new("TextLabel")
	widgetHeaderLabel.Name = "HeaderTitle"
	widgetHeaderLabel.Size = UDim2.new(1, -20, 1, 0)
	widgetHeaderLabel.Position = UDim2.new(0, 20, 0, 0)
	widgetHeaderLabel.BackgroundTransparency = 1
	widgetHeaderLabel.Text = "NEXT METEOR"
	widgetHeaderLabel.TextColor3 = Color3.fromRGB(255, 205, 80)
	widgetHeaderLabel.Font = Enum.Font.GothamBlack
	widgetHeaderLabel.TextSize = 10
	widgetHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
	widgetHeaderLabel.TextStrokeTransparency = 0.3
	widgetHeaderLabel.Parent = headerRow

	widgetTimeLabel = Instance.new("TextLabel")
	widgetTimeLabel.Name = "MainTimeLabel"
	widgetTimeLabel.Size = UDim2.new(1, -16, 0, 22)
	widgetTimeLabel.Position = UDim2.new(0, 8, 0, 20)
	widgetTimeLabel.BackgroundTransparency = 1
	widgetTimeLabel.Text = "--:--"
	widgetTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	widgetTimeLabel.Font = Enum.Font.GothamBlack
	widgetTimeLabel.TextSize = 18
	widgetTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	widgetTimeLabel.TextStrokeTransparency = 0.2
	widgetTimeLabel.Parent = timerWidget

	widgetSubLabel = Instance.new("TextLabel")
	widgetSubLabel.Name = "SubLabel"
	widgetSubLabel.Size = UDim2.new(1, -16, 0, 13)
	widgetSubLabel.Position = UDim2.new(0, 8, 0, 42)
	widgetSubLabel.BackgroundTransparency = 1
	widgetSubLabel.Text = "Starfall Incoming"
	widgetSubLabel.TextColor3 = Color3.fromRGB(165, 190, 230)
	widgetSubLabel.Font = Enum.Font.GothamBold
	widgetSubLabel.TextSize = 9
	widgetSubLabel.TextXAlignment = Enum.TextXAlignment.Center
	widgetSubLabel.TextStrokeTransparency = 0.4
	widgetSubLabel.Parent = timerWidget

	local interactBtn = Instance.new("TextButton")
	interactBtn.Name = "InteractBtn"
	interactBtn.Size = UDim2.new(1, 0, 1, 0)
	interactBtn.BackgroundTransparency = 1
	interactBtn.Text = ""
	interactBtn.Parent = timerWidget

	interactBtn.MouseEnter:Connect(function()
		TweenService:Create(timerWidget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 146, 0, 60),
			BackgroundTransparency = 0.05,
		}):Play()
	end)

	interactBtn.MouseLeave:Connect(function()
		TweenService:Create(timerWidget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 142, 0, 58),
			BackgroundTransparency = 0.15,
		}):Play()
	end)
end

-- Refreshes the right-side timer widget text, colors, and countdown value
local function updateTimerWidgetUI()
	if not widgetTimeLabel or not widgetTimeLabel.Parent then return end

	local now = os.time()
	local remaining = math.max(0, targetNextEventTime - now)

	if currentServerState == "COUNTDOWN" then
		widgetStroke.Color = Color3.fromRGB(255, 80, 20)
		widgetHeaderLabel.Text = "⚠️ IMPACT IMMINENT"
		widgetHeaderLabel.TextColor3 = Color3.fromRGB(255, 110, 40)
		widgetIcon.Text = "☄️"
		widgetTimeLabel.Text = string.format("IMPACT %02ds", remaining)
		widgetTimeLabel.TextColor3 = Color3.fromRGB(255, 80, 20)
		widgetSubLabel.Text = if currentZoneName then currentZoneName else "Watch the Skies!"
		widgetSubLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
	elseif currentServerState == "FALLING" or currentServerState == "ACTIVE" then
		widgetStroke.Color = Color3.fromRGB(0, 240, 255)
		widgetHeaderLabel.Text = "⛏️ STARFALL ACTIVE"
		widgetHeaderLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
		widgetIcon.Text = "🌟"
		widgetTimeLabel.Text = if remaining > 0 then string.format("MINE! %02d:%02d", math.floor(remaining / 60), remaining % 60) else "MINE NOW!"
		widgetTimeLabel.TextColor3 = Color3.fromRGB(255, 225, 60)
		widgetSubLabel.Text = if currentZoneName then currentZoneName else "Crater Site Active!"
		widgetSubLabel.TextColor3 = Color3.fromRGB(150, 235, 255)
	else
		local mins = math.floor(remaining / 60)
		local secs = remaining % 60

		if remaining <= 30 and remaining > 0 then
			widgetStroke.Color = Color3.fromRGB(255, 140, 40)
			widgetHeaderLabel.Text = "STRIKE APPROACHING"
			widgetHeaderLabel.TextColor3 = Color3.fromRGB(255, 160, 50)
			widgetTimeLabel.TextColor3 = Color3.fromRGB(255, 140, 50)
			widgetSubLabel.Text = "Prepare Pickaxes!"
			widgetSubLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		else
			widgetStroke.Color = Color3.fromRGB(75, 125, 215)
			widgetHeaderLabel.Text = "NEXT METEOR"
			widgetHeaderLabel.TextColor3 = Color3.fromRGB(255, 205, 80)
			widgetTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			widgetSubLabel.Text = "Starfall Incoming"
			widgetSubLabel.TextColor3 = Color3.fromRGB(165, 190, 230)
		end
		widgetIcon.Text = "☄️"
		widgetTimeLabel.Text = string.format("%02d:%02d", mins, secs)
	end
end

-- Renders the glowing beacon beam and ground targeting reticle
local function createGroundBeacon(position: Vector3, beaconColor: Color3)
	if activeBeaconFolder then
		activeBeaconFolder:Destroy()
		activeBeaconFolder = nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "ClientMeteorBeacon"
	folder.Parent = Workspace
	activeBeaconFolder = folder

	-- 1. Outer Expanding Ground Warning Ring
	local ring = Instance.new("Part")
	ring.Name = "WarningRing"
	ring.Size = Vector3.new(24, 0.3, 24)
	ring.CFrame = CFrame.new(position)
	ring.Color = beaconColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.4
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = folder

	local ringMesh = Instance.new("SpecialMesh")
	ringMesh.MeshType = Enum.MeshType.Cylinder
	ringMesh.Parent = ring

	-- 2. Tall Skyward Beam
	local beam = Instance.new("Part")
	beam.Name = "SkyBeam"
	beam.Size = Vector3.new(4, 500, 4)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 250, 0))
	beam.Color = beaconColor
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.65
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = folder

	local beamMesh = Instance.new("SpecialMesh")
	beamMesh.MeshType = Enum.MeshType.Cylinder
	beamMesh.Parent = beam

	-- Subtle pulsing animation on ground ring
	task.spawn(function()
		while ring and ring.Parent do
			TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.15,
				Size = Vector3.new(28, 0.3, 28),
			}):Play()
			task.wait(0.8)
			if not ring or not ring.Parent then break end
			TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.5,
				Size = Vector3.new(22, 0.3, 22),
			}):Play()
			task.wait(0.8)
		end
	end)
end

-- Renders the falling fireball descending from the clouds
local function animateFallingMeteor(startPos: Vector3, endPos: Vector3)
	local fireball = Instance.new("Part")
	fireball.Name = "FallingFireball"
	fireball.Size = Vector3.new(10, 10, 10)
	fireball.Shape = Enum.PartType.Ball
	fireball.CFrame = CFrame.new(startPos)
	fireball.Color = Color3.fromRGB(255, 90, 15)
	fireball.Material = Enum.Material.Neon
	fireball.Anchored = true
	fireball.CanCollide = false
	fireball.Parent = Workspace

	local att = Instance.new("Attachment")
	att.Parent = fireball

	local trail = Instance.new("ParticleEmitter")
	trail.Name = "MeteorFlameTrail"
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 90, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 20, 10)),
	})
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4.0),
		NumberSequenceKeypoint.new(0.5, 8.0),
		NumberSequenceKeypoint.new(1, 14.0),
	})
	trail.Lifetime = NumberRange.new(0.8, 1.4)
	trail.Rate = 60
	trail.Speed = NumberRange.new(5, 12)
	trail.LightEmission = 1.0
	trail.Parent = att

	-- Descent tween
	local fallDuration = 1.8
	local fallTween = TweenService:Create(fireball, TweenInfo.new(fallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(endPos),
	})
	fallTween:Play()

	-- Whistle / rushing wind sound
	playSound("rbxassetid://9114223170", 0.9, 0.8) -- Fiery swoosh

	fallTween.Completed:Connect(function()
		fireball:Destroy()

		-- Impact explosion sound
		playSound("rbxassetid://138090596", 0.75, 1.0) -- Deep bass boom

		-- Expanding ground shockwave disc
		local shockwave = Instance.new("Part")
		shockwave.Name = "ImpactShockwave"
		shockwave.Size = Vector3.new(4, 0.4, 4)
		shockwave.CFrame = CFrame.new(endPos)
		shockwave.Color = Color3.fromRGB(255, 160, 40)
		shockwave.Material = Enum.Material.Neon
		shockwave.Transparency = 0.2
		shockwave.Anchored = true
		shockwave.CanCollide = false
		shockwave.Parent = Workspace

		local sMesh = Instance.new("SpecialMesh")
		sMesh.MeshType = Enum.MeshType.Cylinder
		sMesh.Parent = shockwave

		local waveTween = TweenService:Create(shockwave, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(65, 0.4, 65),
			Transparency = 1,
		})
		waveTween:Play()
		waveTween.Completed:Connect(function()
			shockwave:Destroy()
		end)

		-- Camera shake based on distance
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local dist = (char.HumanoidRootPart.Position - endPos).Magnitude
			if dist <= 180 then
				local intensity = math.clamp(1.2 * (1 - (dist / 180)), 0.2, 1.2)
				shakeCamera(intensity, 0.65)
			end
		end
	end)
end

-- Displays floating numbers when the meteor is struck
local function spawnHitPopup(pos: Vector3, damage: number, isLocalPlayer: boolean, cash: number?, gems: number?)
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.new(0, 150, 0, 45)
	bill.StudsOffset = Vector3.new((math.random() - 0.5) * 4, 3 + (math.random() * 2), (math.random() - 0.5) * 4)
	bill.AlwaysOnTop = true
	bill.MaxDistance = 100

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = if isLocalPlayer then 18 else 14
	lbl.TextColor3 = if isLocalPlayer then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 120, 40)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = "-" .. FormatNumber.formatComma(damage) .. " 💥"
	lbl.Parent = bill

	local p = Instance.new("Part")
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.CFrame = CFrame.new(pos)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Parent = Workspace
	bill.Parent = p

	local tween = TweenService:Create(bill, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = bill.StudsOffset + Vector3.new(0, 4, 0),
	})
	tween:Play()

	task.delay(0.85, function()
		p:Destroy()
	end)
end

-- Plays massive, sparkling client-side visual shatter debris burst and shockwave
local function playMeteorShatterFX(centerPos: Vector3)
	-- 1. Ensure any lingering client models are wiped
	local activeFolder = Workspace:FindFirstChild("ActiveMeteorEvent")
	if activeFolder then activeFolder:Destroy() end
	local activeMonolith = Workspace:FindFirstChild("CelestialMeteorMonolith")
	if activeMonolith then activeMonolith:Destroy() end

	-- 2. Expanding radiant ground shockwave
	local shockwave = Instance.new("Part")
	shockwave.Name = "ShatterShockwave"
	shockwave.Size = Vector3.new(6, 0.5, 6)
	shockwave.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.5, 0))
	shockwave.Color = Color3.fromRGB(255, 215, 60)
	shockwave.Material = Enum.Material.Neon
	shockwave.Transparency = 0.15
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Parent = Workspace

	local sMesh = Instance.new("SpecialMesh")
	sMesh.MeshType = Enum.MeshType.Cylinder
	sMesh.Parent = shockwave

	TweenService:Create(shockwave, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(75, 0.5, 75),
		Transparency = 1,
	}):Play()
	task.delay(0.85, function() shockwave:Destroy() end)

	-- 3. Prismatic crystal and slate debris burst
	local colors = {
		Color3.fromRGB(255, 215, 60), -- Cosmic Gold
		Color3.fromRGB(0, 240, 255),   -- Stellar Cyan
		Color3.fromRGB(255, 90, 20),   -- Molten Lava
		Color3.fromRGB(180, 50, 255),  -- Void Purple
		Color3.fromRGB(240, 240, 255), -- Starlight White
	}

	local DebrisService = game:GetService("Debris")
	for i = 1, 36 do
		local chunk = Instance.new("Part")
		local sz = (0.8 + math.random() * 1.8)
		chunk.Size = Vector3.new(sz, sz, sz)
		chunk.Position = centerPos + Vector3.new(math.random(-3, 3), math.random(1, 5), math.random(-3, 3))
		chunk.Color = colors[math.random(1, #colors)]
		chunk.Material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Slate
		chunk.CanCollide = false
		chunk.Anchored = false
		chunk.Parent = Workspace

		local phi = math.random() * math.pi * 2
		local costheta = (math.random() - 0.5) * 2
		local speed = math.random(35, 75)
		local dir = Vector3.new(math.cos(phi) * 0.9, math.abs(costheta) + 0.6, math.sin(phi) * 0.9).Unit
		chunk.AssemblyLinearVelocity = dir * speed
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))

		task.delay(0.8, function()
			TweenService:Create(chunk, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 0.1),
			}):Play()
		end)

		DebrisService:AddItem(chunk, 1.3)
	end
end

-- =========================================================================
-- 3D PHYSICAL REWARD PROP BUILDERS (Stud Design & Authenticity)
-- =========================================================================

-- 1. 3D Dollar Sign & Gold Ingot Stacks with Studs
local function build3DCashModel(): Model
	local model = Instance.new("Model")
	model.Name = "Cash3DProp"

	-- Base Stack of 3 Gold Ingots with studs
	local baseBar1 = Instance.new("Part")
	baseBar1.Name = "PrimaryPart"
	baseBar1.Size = Vector3.new(2.4, 0.55, 1.2)
	baseBar1.CFrame = CFrame.new(0, -0.95, 0)
	baseBar1.Color = Color3.fromRGB(255, 205, 30)
	baseBar1.Material = Enum.Material.Metal
	baseBar1.TopSurface = Enum.SurfaceType.Studs
	baseBar1.Anchored = true
	baseBar1.CanCollide = false
	baseBar1.Parent = model
	model.PrimaryPart = baseBar1

	local baseBar2 = Instance.new("Part")
	baseBar2.Name = "GoldBar2"
	baseBar2.Size = Vector3.new(1.8, 0.5, 0.9)
	baseBar2.CFrame = CFrame.new(0, -0.45, 0)
	baseBar2.Color = Color3.fromRGB(255, 220, 60)
	baseBar2.Material = Enum.Material.Metal
	baseBar2.TopSurface = Enum.SurfaceType.Studs
	baseBar2.Anchored = true
	baseBar2.CanCollide = false
	baseBar2.Parent = model

	-- Floating 3D Green & Gold Dollar Sign ($) with Studs
	local spine = Instance.new("Part")
	spine.Name = "DollarSpine"
	spine.Size = Vector3.new(0.24, 2.0, 0.3)
	spine.CFrame = CFrame.new(0, 0.65, 0)
	spine.Color = Color3.fromRGB(60, 235, 100)
	spine.Material = Enum.Material.Neon
	spine.TopSurface = Enum.SurfaceType.Studs
	spine.Anchored = true
	spine.CanCollide = false
	spine.Parent = model

	local sParts = {
		{ size = Vector3.new(1.2, 0.24, 0.3), pos = Vector3.new(0, 1.45, 0) },
		{ size = Vector3.new(0.24, 0.45, 0.3), pos = Vector3.new(-0.5, 1.25, 0) },
		{ size = Vector3.new(1.2, 0.24, 0.3), pos = Vector3.new(0, 0.65, 0) },
		{ size = Vector3.new(0.24, 0.45, 0.3), pos = Vector3.new(0.5, 0.45, 0) },
		{ size = Vector3.new(1.2, 0.24, 0.3), pos = Vector3.new(0, 0.05, 0) },
	}
	for i, cfg in ipairs(sParts) do
		local p = Instance.new("Part")
		p.Name = "S_Part_" .. i
		p.Size = cfg.size
		p.CFrame = CFrame.new(cfg.pos)
		p.Color = Color3.fromRGB(46, 204, 113)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
	end

	return model
end

-- 2. 3D Faceted Radiant Diamond Gem Crystal with Studs
local function build3DGemModel(): Model
	local model = Instance.new("Model")
	model.Name = "Gem3DProp"

	-- Main Diamond Core
	local core = Instance.new("Part")
	core.Name = "PrimaryPart"
	core.Size = Vector3.new(1.6, 2.2, 1.6)
	core.CFrame = CFrame.new(0, 0, 0)
	core.Color = Color3.fromRGB(0, 225, 255)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.Parent = model
	model.PrimaryPart = core

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.0, 1.35, 1.0)
	mesh.Parent = core

	-- Faceted Orbiting Crystal Shards with Studs
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		local shard = Instance.new("Part")
		shard.Name = "Shard_" .. i
		shard.Size = Vector3.new(0.48, 1.7, 0.48)
		shard.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, math.rad(24)) * CFrame.new(0.85, 0, 0)
		shard.Color = Color3.fromRGB(135, 245, 255)
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.15
		shard.TopSurface = Enum.SurfaceType.Studs
		shard.Anchored = true
		shard.CanCollide = false
		shard.Parent = model
	end

	return model
end

-- 3. 3D Pulsing Cosmic Plasma Orb & Lightning Bolts with Studs
local function build3DPowerModel(): Model
	local model = Instance.new("Model")
	model.Name = "Power3DProp"

	local core = Instance.new("Part")
	core.Name = "PrimaryPart"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.CFrame = CFrame.new(0, 0, 0)
	core.Color = Color3.fromRGB(225, 65, 255)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.Parent = model
	model.PrimaryPart = core

	-- Tilted Orbiting Energy Disc
	local ring = Instance.new("Part")
	ring.Name = "EnergyRing"
	ring.Size = Vector3.new(2.8, 0.12, 2.8)
	ring.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(38), math.rad(20), 0)
	ring.Color = Color3.fromRGB(160, 45, 240)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = model

	local ringMesh = Instance.new("SpecialMesh")
	ringMesh.MeshType = Enum.MeshType.Cylinder
	ringMesh.Parent = ring

	-- 3D Zig-zag Lightning Bolts with Studs
	local boltParts = {
		{ size = Vector3.new(0.28, 0.95, 0.28), cf = CFrame.new(-0.25, 0.7, 0.9) * CFrame.Angles(0, 0, math.rad(-30)) },
		{ size = Vector3.new(0.28, 0.95, 0.28), cf = CFrame.new(0.25, 0.05, 0.9) * CFrame.Angles(0, 0, math.rad(30)) },
		{ size = Vector3.new(0.28, 0.95, 0.28), cf = CFrame.new(-0.1, -0.6, 0.9) * CFrame.Angles(0, 0, math.rad(-35)) },
	}
	for i, cfg in ipairs(boltParts) do
		local bolt = Instance.new("Part")
		bolt.Name = "Bolt_" .. i
		bolt.Size = cfg.size
		bolt.CFrame = cfg.cf
		bolt.Color = Color3.fromRGB(255, 240, 80)
		bolt.Material = Enum.Material.Neon
		bolt.TopSurface = Enum.SurfaceType.Studs
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.Parent = model
	end

	return model
end

-- 4. 3D Mystery Loot Crate / Chest with Studs & Glowing Interior
local function build3DCrateModel(): Model
	local model = Instance.new("Model")
	model.Name = "Crate3DProp"

	-- Main Chest Body with Studs
	local body = Instance.new("Part")
	body.Name = "PrimaryPart"
	body.Size = Vector3.new(2.3, 1.4, 1.7)
	body.CFrame = CFrame.new(0, -0.3, 0)
	body.Color = Color3.fromRGB(150, 75, 20)
	body.Material = Enum.Material.WoodPlanks
	body.TopSurface = Enum.SurfaceType.Studs
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	-- Gold Reinforced Metal Straps with Studs
	for _, xOff in ipairs({ -1.0, 1.0 }) do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.22, 1.44, 1.74)
		band.CFrame = CFrame.new(xOff, -0.3, 0)
		band.Color = Color3.fromRGB(255, 205, 40)
		band.Material = Enum.Material.Metal
		band.TopSurface = Enum.SurfaceType.Studs
		band.Anchored = true
		band.CanCollide = false
		band.Parent = model
	end

	-- Ajar Tilted Chest Lid with Studs
	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(2.38, 0.6, 1.78)
	lid.CFrame = CFrame.new(0, 0.65, 0.1) * CFrame.Angles(math.rad(-22), 0, 0)
	lid.Color = Color3.fromRGB(170, 85, 25)
	lid.Material = Enum.Material.WoodPlanks
	lid.TopSurface = Enum.SurfaceType.Studs
	lid.Anchored = true
	lid.CanCollide = false
	lid.Parent = model

	local lidTrim = Instance.new("Part")
	lidTrim.Name = "LidTrim"
	lidTrim.Size = Vector3.new(2.42, 0.22, 1.82)
	lidTrim.CFrame = lid.CFrame * CFrame.new(0, 0.25, 0)
	lidTrim.Color = Color3.fromRGB(255, 210, 50)
	lidTrim.Material = Enum.Material.Metal
	lidTrim.TopSurface = Enum.SurfaceType.Studs
	lidTrim.Anchored = true
	lidTrim.CanCollide = false
	lidTrim.Parent = model

	-- Glowing Golden Treasure Beam from inside
	local glow = Instance.new("Part")
	glow.Name = "GlowInside"
	glow.Size = Vector3.new(1.8, 0.5, 1.2)
	glow.CFrame = CFrame.new(0, 0.35, -0.1)
	glow.Color = Color3.fromRGB(255, 220, 80)
	glow.Material = Enum.Material.Neon
	glow.Anchored = true
	glow.CanCollide = false
	glow.Parent = model

	-- Front Gold Lock Latch
	local lock = Instance.new("Part")
	lock.Name = "Lock"
	lock.Size = Vector3.new(0.5, 0.55, 0.2)
	lock.CFrame = CFrame.new(0, 0.25, -0.92)
	lock.Color = Color3.fromRGB(255, 215, 0)
	lock.Material = Enum.Material.Neon
	lock.Anchored = true
	lock.CanCollide = false
	lock.Parent = model

	return model
end

-- Emits small 2D glowing spark particles bursting radially outward
local function emitSparks2D(parent: GuiObject, count: number, maxDist: number, color: Color3)
	for i = 1, count do
		local spark = Instance.new("Frame")
		spark.Size = UDim2.new(0, 10, 0, 10)
		spark.Position = UDim2.new(0.5, 0, 0.38, 0)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = color
		spark.BorderSizePixel = 0
		spark.ZIndex = 12
		spark.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = spark

		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.4
		local dist = math.random(maxDist * 0.45, maxDist)
		local endX = math.cos(angle) * dist
		local endY = math.sin(angle) * dist

		local tween = TweenService:Create(spark, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, endX, 0.38, endY),
			Size = UDim2.new(0, 2, 0, 2),
			BackgroundTransparency = 1,
		})
		tween:Play()
		task.delay(0.5, function()
			spark:Destroy()
		end)
	end
end

-- =========================================================================
-- PHYSICAL 3D SEQUENTIAL REWARD SHOWCASE ANIMATION
-- =========================================================================
-- Each reward is a real 3D physical model (with studs & materials) inside a transparent
-- ViewportFrame with a rotating spark sunburst behind it (NO border box / card around it).
-- The 3D model pops up in the center, spins and hovers, plays its unique sound,
-- then slides to its slot on the left as the next item pops in!
local function playSequentialAwardsAnimation(data: any)
	if activeShowcaseFrame then
		activeShowcaseFrame:Destroy()
		activeShowcaseFrame = nil
	end

	local gui = screenGui
	if not gui or not gui.Parent then
		local pGui = player:WaitForChild("PlayerGui")
		gui = pGui:FindFirstChild("MeteorEventHUDGui") :: ScreenGui?
	end
	if not gui then return end

	-- Master transparent full-screen showcase canvas (NO borders, NO enclosing card box)
	local showcase = Instance.new("Frame")
	showcase.Name = "MeteorPhysicalShowcase"
	showcase.Size = UDim2.new(1, 0, 1, 0)
	showcase.Position = UDim2.new(0, 0, 0, 0)
	showcase.BackgroundTransparency = 1
	showcase.BorderSizePixel = 0
	showcase.ClipsDescendants = false
	showcase.Parent = gui
	activeShowcaseFrame = showcase

	-- Responsive scale for smaller devices & mobile
	local masterScale = Instance.new("UIScale")
	masterScale.Parent = showcase
	local function updateScale()
		if camera and camera.ViewportSize.X > 0 then
			local vpW = camera.ViewportSize.X
			if vpW < 780 then
				masterScale.Scale = math.clamp(vpW / 780, 0.55, 1.0)
			else
				masterScale.Scale = 1.0
			end
		end
	end
	updateScale()
	local vpConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	-- Subtle cinematic dark backdrop vignette (fades in softly to make 3D models pop)
	local backdrop = Instance.new("Frame")
	backdrop.Name = "CinematicBackdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = showcase

	TweenService:Create(backdrop, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.72,
	}):Play()

	-- Floating Overhead Title (NO card box around it)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "FloatingTitle"
	titleLabel.Size = UDim2.new(1, 0, 0, 36)
	titleLabel.Position = UDim2.new(0.5, 0, 0.16, 0)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "☄️ METEOR SHATTERED! JACKPOT GRANTED! ☄️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 24
	titleLabel.TextStrokeTransparency = 0.12
	titleLabel.TextStrokeColor3 = Color3.fromRGB(15, 10, 25)
	titleLabel.ZIndex = 15
	titleLabel.Parent = showcase

	local subTitleLabel = Instance.new("TextLabel")
	subTitleLabel.Name = "FloatingSubtitle"
	subTitleLabel.Size = UDim2.new(1, 0, 0, 20)
	subTitleLabel.Position = UDim2.new(0.5, 0, 0.205, 0)
	subTitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subTitleLabel.BackgroundTransparency = 1
	subTitleLabel.Text = "JACKPOT REWARDS UNLOCKED"
	subTitleLabel.TextColor3 = Color3.fromRGB(195, 190, 230)
	subTitleLabel.Font = Enum.Font.GothamBold
	subTitleLabel.TextSize = 13
	subTitleLabel.TextStrokeTransparency = 0.25
	subTitleLabel.TextStrokeColor3 = Color3.fromRGB(15, 10, 25)
	subTitleLabel.ZIndex = 15
	subTitleLabel.Parent = showcase

	-- Reward Item Definitions with 3D Builders and Unique Audio
	local awardDefs = {
		{
			id = "cash",
			title = "CASH JACKPOT",
			value = string.format("+$%s", FormatNumber.formatComma(data.jackpotCash or 25_000_000)),
			valueColor = Color3.fromRGB(110, 255, 150),
			sparkColor = Color3.fromRGB(255, 225, 70),
			builder = build3DCashModel,
			soundId = "rbxassetid://9117970732", -- Crisp gold ring & coin sound
			soundSpeed = 1.0,
			soundVolume = 0.9,
		},
		{
			id = "gems",
			title = "DIAMOND CACHE",
			value = string.format("+%s Gems", FormatNumber.formatComma(data.jackpotGems or 15_000)),
			valueColor = Color3.fromRGB(120, 240, 255),
			sparkColor = Color3.fromRGB(0, 230, 255),
			builder = build3DGemModel,
			soundId = "rbxassetid://9114223170", -- High crystalline diamond ping
			soundSpeed = 1.32,
			soundVolume = 0.95,
		},
		{
			id = "power",
			title = "COSMIC POWER",
			value = string.format("+%s Power", FormatNumber.formatComma(data.jackpotPower or 5_000)),
			valueColor = Color3.fromRGB(245, 160, 255),
			sparkColor = Color3.fromRGB(220, 70, 255),
			builder = build3DPowerModel,
			soundId = "rbxassetid://9114223849", -- High-voltage electric surge zap
			soundSpeed = 1.25,
			soundVolume = 0.9,
		},
		{
			id = "crates",
			title = "RARE CRATES",
			value = string.format("+%d Mystery Crates", data.cratesCount or 3),
			valueColor = Color3.fromRGB(255, 215, 100),
			sparkColor = Color3.fromRGB(255, 165, 40),
			builder = build3DCrateModel,
			soundId = "rbxassetid://6895079853", -- Heavy chest ratchet click & unlock
			soundSpeed = 1.2,
			soundVolume = 0.85,
			extraSoundId = "rbxassetid://5153737200", -- Rare fanfare pop
		},
	}

	-- Layout calculation for 4 side-by-side floating 3D slots
	local slotCount = #awardDefs
	local slotStep = 180
	local totalSpan = (slotCount - 1) * slotStep -- 540 px
	local startX = -totalSpan / 2 -- -270 px
	local centerScreenY = 0.48

	type ActiveSlot = {
		holder: Frame,
		scale: UIScale,
		model: Model,
		rayContainer: Frame,
		targetX: number,
	}
	local activeSlots: { ActiveSlot } = {}

	-- Continuous 3D Spinning & Bobbing RenderStepped Connection
	local rotAngle = 0
	local rotConn: RBXScriptConnection? = nil
	rotConn = RunService.RenderStepped:Connect(function(dt)
		rotAngle += dt * 2.5
		local bob = math.sin(rotAngle * 2.2) * 0.12
		for _, slot in ipairs(activeSlots) do
			if slot.model and slot.model.PrimaryPart then
				slot.model:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, rotAngle, 0))
			end
			if slot.rayContainer and slot.rayContainer.Parent then
				slot.rayContainer.Rotation += dt * 22
			end
		end
	end)

	-- Sequential presentation loop
	for index, award in ipairs(awardDefs) do
		if not showcase or not showcase.Parent then
			if rotConn then rotConn:Disconnect() end
			if vpConn then vpConn:Disconnect() end
			return
		end

		local targetSlotX = startX + (index - 1) * slotStep

		-- 1. Create transparent Slot Holder directly at its assigned tray slot position
		local slotHolder = Instance.new("Frame")
		slotHolder.Name = "RewardSlot_" .. award.id
		slotHolder.Size = UDim2.new(0, 165, 0, 215)
		slotHolder.Position = UDim2.new(0.5, targetSlotX, centerScreenY, 0) -- Reveals directly in place!
		slotHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		slotHolder.BackgroundTransparency = 1
		slotHolder.BorderSizePixel = 0
		slotHolder.ZIndex = 15
		slotHolder.Parent = showcase

		local slotScale = Instance.new("UIScale")
		slotScale.Scale = 0 -- Starts at 0 for pop-up
		slotScale.Parent = slotHolder

		-- 2. Rotating Sunburst Rays (Starts hidden during black silhouette phase)
		local rayContainer = Instance.new("Frame")
		rayContainer.Name = "SunburstContainer"
		rayContainer.Size = UDim2.new(0, 195, 0, 195)
		rayContainer.Position = UDim2.new(0.5, 0, 0, 72)
		rayContainer.AnchorPoint = Vector2.new(0.5, 0.5)
		rayContainer.BackgroundTransparency = 1
		rayContainer.ZIndex = 8
		rayContainer.Parent = slotHolder

		for r = 0, 7 do
			local ray = Instance.new("Frame")
			ray.Size = UDim2.new(0, 26, 0, 190)
			ray.Position = UDim2.new(0.5, 0, 0.5, 0)
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Rotation = r * 45
			ray.BackgroundColor3 = award.sparkColor
			ray.BackgroundTransparency = 1 -- Hidden until revealed!
			ray.BorderSizePixel = 0
			ray.ZIndex = 8
			ray.Parent = rayContainer

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0.5, 0)
			rCorner.Parent = ray
		end

		-- 3. Transparent ViewportFrame for physical 3D Model
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "PropViewport"
		viewport.Size = UDim2.new(1, 0, 0, 140)
		viewport.Position = UDim2.new(0.5, 0, 0, 0)
		viewport.AnchorPoint = Vector2.new(0.5, 0)
		viewport.BackgroundTransparency = 1
		viewport.BorderSizePixel = 0
		viewport.LightColor = Color3.fromRGB(35, 30, 48) -- Dim mystery shadow lighting
		viewport.LightDirection = Vector3.new(0.6, -1, -1.2)
		viewport.Ambient = Color3.fromRGB(20, 18, 28)
		viewport.ZIndex = 10
		viewport.Parent = slotHolder

		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		local vCamera = Instance.new("Camera")
		vCamera.FieldOfView = 48
		vCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, 5.8), Vector3.new(0, 0.2, 0))
		vCamera.Parent = viewport
		viewport.CurrentCamera = vCamera

		-- Build the physical 3D model & record original properties
		local model3D = award.builder()
		model3D.Parent = worldModel

		type PartBackup = {
			part: BasePart,
			color: Color3,
			material: Enum.Material,
			transparency: number,
		}
		local originalParts: { PartBackup } = {}
		for _, desc in ipairs(model3D:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(originalParts, {
					part = desc,
					color = desc.Color,
					material = desc.Material,
					transparency = desc.Transparency,
				})
				-- Make it completely black as a mystery silhouette!
				desc.Color = Color3.fromRGB(15, 12, 22)
				desc.Material = Enum.Material.SmoothPlastic
			end
		end

		-- 4. Floating Labels (starts with mystery question marks)
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "Title"
		titleLbl.Size = UDim2.new(1, 30, 0, 16)
		titleLbl.Position = UDim2.new(0.5, 0, 0, 148)
		titleLbl.AnchorPoint = Vector2.new(0.5, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = "???"
		titleLbl.TextColor3 = Color3.fromRGB(160, 165, 185)
		titleLbl.Font = Enum.Font.GothamBlack
		titleLbl.TextSize = 11
		titleLbl.TextStrokeTransparency = 0.2
		titleLbl.TextStrokeColor3 = Color3.fromRGB(10, 8, 16)
		titleLbl.ZIndex = 12
		titleLbl.Parent = slotHolder

		local valLbl = Instance.new("TextLabel")
		valLbl.Name = "Value"
		valLbl.Size = UDim2.new(1, 30, 0, 24)
		valLbl.Position = UDim2.new(0.5, 0, 0, 166)
		valLbl.AnchorPoint = Vector2.new(0.5, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = "MYSTERY REWARD"
		valLbl.TextColor3 = Color3.fromRGB(135, 140, 160)
		valLbl.Font = Enum.Font.GothamBlack
		valLbl.TextSize = 13
		valLbl.TextStrokeTransparency = 0.25
		valLbl.TextStrokeColor3 = Color3.fromRGB(10, 8, 16)
		valLbl.ZIndex = 12
		valLbl.Parent = slotHolder

		local activeSlotRecord: ActiveSlot = {
			holder = slotHolder,
			scale = slotScale,
			model = model3D,
			rayContainer = rayContainer,
			targetX = targetSlotX,
		}
		table.insert(activeSlots, activeSlotRecord)

		-- =====================================================================
		-- PHASE 1: BLACK SILHOUETTE ENTRANCE & SUSPENSE WOBBLE IN PLACE
		-- =====================================================================
		-- Pops into its assigned position as a pitch black spinning silhouette
		playSound("rbxassetid://6895079853", 1.5, 0.65) -- Mystery thud / click

		local silhouettePop = TweenService:Create(slotScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.15,
		})
		silhouettePop:Play()
		silhouettePop.Completed:Wait()

		TweenService:Create(slotScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()

		-- Suspense anticipation wobble in place while spinning in pitch black
		local wobbleStart = os.clock()
		while (os.clock() - wobbleStart) < 0.32 do
			local wobble = math.sin((os.clock() - wobbleStart) * 32) * 5.5
			slotHolder.Rotation = wobble
			RunService.RenderStepped:Wait()
		end
		slotHolder.Rotation = 0

		if not showcase or not showcase.Parent then
			if rotConn then rotConn:Disconnect() end
			if vpConn then vpConn:Disconnect() end
			return
		end

		-- =====================================================================
		-- PHASE 2: PHYSICAL REVEAL POP! (Flash, Color Restore, Scale Bounce, Audio)
		-- =====================================================================
		-- Localized circular radiant flash burst around the item
		local flashBurst = Instance.new("Frame")
		flashBurst.Name = "RevealFlashBurst"
		flashBurst.Size = UDim2.new(0, 110, 0, 110)
		flashBurst.Position = UDim2.new(0.5, 0, 0, 70)
		flashBurst.AnchorPoint = Vector2.new(0.5, 0.5)
		flashBurst.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flashBurst.BackgroundTransparency = 0.12
		flashBurst.BorderSizePixel = 0
		flashBurst.ZIndex = 18
		flashBurst.Parent = slotHolder

		local fbCorner = Instance.new("UICorner")
		fbCorner.CornerRadius = UDim.new(1, 0)
		fbCorner.Parent = flashBurst

		TweenService:Create(flashBurst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 250, 0, 250),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.38, function() flashBurst:Destroy() end)

		-- Restore full physical 3D colors, materials, and brilliant lighting
		for _, item in ipairs(originalParts) do
			item.part.Color = item.color
			item.part.Material = item.material
			item.part.Transparency = item.transparency
		end
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.Ambient = Color3.fromRGB(155, 155, 185)

		-- Fade in the radiant rotating sunburst rays
		for _, r in ipairs(rayContainer:GetChildren()) do
			if r:IsA("Frame") then
				TweenService:Create(r, TweenInfo.new(0.25), { BackgroundTransparency = 0.90 }):Play()
			end
		end

		-- Reveal true reward title and amount
		titleLbl.Text = award.title
		titleLbl.TextColor3 = Color3.fromRGB(210, 215, 235)
		valLbl.Text = award.value
		valLbl.TextColor3 = award.valueColor
		valLbl.TextSize = 17

		-- Unique sound for this item
		playSound(award.soundId, award.soundSpeed, award.soundVolume)
		if award.extraSoundId then
			task.delay(0.15, function()
				playSound(award.extraSoundId, 1.15, 0.8)
			end)
		end

		-- Emit outward glowing sparks directly from this slot
		emitSparks2D(slotHolder, 28, 145, award.sparkColor)

		-- Big physical pop scale-bounce overshoot
		local popTween = TweenService:Create(slotScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.40,
		})
		popTween:Play()
		popTween.Completed:Wait()

		TweenService:Create(slotScale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()

		-- =====================================================================
		-- PHASE 3: HOVER & SETTLE IN PLACE (No sliding across screen)
		-- =====================================================================
		local hoverUp = TweenService:Create(slotHolder, TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, targetSlotX, centerScreenY, -8),
		})
		hoverUp:Play()
		hoverUp.Completed:Wait()

		local hoverDown = TweenService:Create(slotHolder, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, targetSlotX, centerScreenY, 0),
		})
		hoverDown:Play()
		hoverDown.Completed:Wait()

		-- Short settle pause before next reward appears in its own slot position
		task.wait(0.18)
	end

	-- 5. Grand Finale: All 4 3D models spinning together!
	if not showcase or not showcase.Parent then
		if rotConn then rotConn:Disconnect() end
		if vpConn then vpConn:Disconnect() end
		return
	end

	-- Victorious Fanfare Sound
	playSound("rbxassetid://5153737200", 1.0, 1.0)

	-- Screen burst sparks
	emitSparks2D(showcase, 36, 400, Color3.fromRGB(255, 220, 90))

	-- Bottom Confirmation Pill (Clean floating badge)
	local claimPill = Instance.new("Frame")
	claimPill.Name = "ClaimPill"
	claimPill.Size = UDim2.new(0, 340, 0, 30)
	claimPill.Position = UDim2.new(0.5, 0, centerScreenY + 0.22, 0)
	claimPill.AnchorPoint = Vector2.new(0.5, 0.5)
	claimPill.BackgroundColor3 = Color3.fromRGB(25, 70, 40)
	claimPill.BackgroundTransparency = 1
	claimPill.BorderSizePixel = 0
	claimPill.ZIndex = 15
	claimPill.Parent = showcase

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(1, 0)
	pCorner.Parent = claimPill

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(80, 230, 130)
	pStroke.Thickness = 1.6
	pStroke.Transparency = 1
	pStroke.Parent = claimPill

	local pLabel = Instance.new("TextLabel")
	pLabel.Size = UDim2.new(1, 0, 1, 0)
	pLabel.BackgroundTransparency = 1
	pLabel.Text = "✨ ALL REWARDS CLAIMED & DEPOSITED ✨"
	pLabel.TextColor3 = Color3.fromRGB(150, 255, 180)
	pLabel.Font = Enum.Font.GothamBlack
	pLabel.TextSize = 12
	pLabel.TextStrokeTransparency = 0.3
	pLabel.TextTransparency = 1
	pLabel.ZIndex = 16
	pLabel.Parent = claimPill

	TweenService:Create(claimPill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.2,
	}):Play()
	TweenService:Create(pStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.15,
	}):Play()
	TweenService:Create(pLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	-- 6. Hold showcase for 5.0 seconds so player can watch the 4 3D models spin, then fade out
	task.wait(5.0)

	if rotConn then
		rotConn:Disconnect()
		rotConn = nil
	end
	if vpConn then
		vpConn:Disconnect()
		vpConn = nil
	end

	if showcase and showcase.Parent then
		for _, c in ipairs(showcase:GetDescendants()) do
			if c:IsA("TextLabel") then
				TweenService:Create(c, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif c:IsA("Frame") or c:IsA("ViewportFrame") then
				TweenService:Create(c, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				}):Play()
			elseif c:IsA("UIStroke") then
				TweenService:Create(c, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end

		task.wait(0.48)
		if showcase and showcase.Parent then
			showcase:Destroy()
		end
		if activeShowcaseFrame == showcase then
			activeShowcaseFrame = nil
		end
	end
end

-- =========================================================================
-- INITIALIZATION
-- =========================================================================
function MeteorClient.init()
	print("☄️ [MeteorClient] Initializing Meteor World Event Client...")
	buildHUD()

	-- 1. MeteorEventAnnounced Handler
	local announceEvent = Remotes.getEvent("MeteorEventAnnounced")
	announceEvent.OnClientEvent:Connect(function(data)
		print(string.format("☄️ [MeteorClient] Meteor Strike Announced in %s! %ds until crash", data.zoneName, data.countdown))

		-- Clear any active reward showcase
		if activeShowcaseFrame then
			activeShowcaseFrame:Destroy()
			activeShowcaseFrame = nil
		end

		-- Update state
		currentServerState = "COUNTDOWN"
		targetNextEventTime = os.time() + (data.countdown or 15)
		currentZoneName = data.zoneName
		currentZoneIcon = data.zoneIcon
		updateTimerWidgetUI()

		-- Sound fanfare alert
		playSound("rbxassetid://9114223170", 1.1, 0.7)

		-- Show Ground Beacon Beam
		createGroundBeacon(data.position, data.color or Color3.fromRGB(255, 100, 20))

		-- Update Alert Banner
		alertSubtitle.Text = "Target Crash Site: " .. tostring(data.zoneName)
		alertTimer.Text = string.format("Impact in: %ds", data.countdown)

		-- Slide Alert Banner Down into view
		alertBanner.Position = UDim2.new(0.5, 0, -0.2, 0)
		alertBanner.Visible = true
		TweenService:Create(alertBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.08, 0),
		}):Play()

		-- Local countdown ticker
		if activeCountdownThread then task.cancel(activeCountdownThread) end
		activeCountdownThread = task.spawn(function()
			local remaining = data.countdown or 15
			while remaining > 0 do
				task.wait(1)
				remaining -= 1
				if alertTimer and alertTimer.Parent then
					alertTimer.Text = string.format("Impact in: %ds", remaining)
				end
			end
		end)
	end)

	-- 2. MeteorCrashed Handler
	local crashEvent = Remotes.getEvent("MeteorCrashed")
	crashEvent.OnClientEvent:Connect(function(data)
		print("☄️ [MeteorClient] Meteor descending upon " .. tostring(data.zoneName))

		-- Update state
		currentServerState = "ACTIVE"
		targetNextEventTime = os.time() + 120
		currentZoneName = data.zoneName
		updateTimerWidgetUI()

		-- Smoothly transition sky to night time as the meteor begins to fall
		TweenService:Create(Lighting, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			ClockTime = 23.8,
			Brightness = 0.9,
			OutdoorAmbient = Color3.fromRGB(45, 40, 65),
			FogColor = Color3.fromRGB(30, 25, 45),
		}):Play()

		-- Remove ground beacon
		if activeBeaconFolder then
			activeBeaconFolder:Destroy()
			activeBeaconFolder = nil
		end

		-- Slide Alert Banner out of view
		TweenService:Create(alertBanner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.2, 0),
		}):Play()

		-- Animate falling visual fireball
		animateFallingMeteor(data.skyStartPos, data.position)
	end)

	-- 3. MeteorDamaged Handler
	local damagedEvent = Remotes.getEvent("MeteorDamaged")
	damagedEvent.OnClientEvent:Connect(function(data)
		local isMe = (data.playerName == player.Name)
		spawnHitPopup(data.hitPosition, data.damage, isMe, data.cashEarned, data.gemsEarned)

		if isMe then
			playSound("rbxassetid://9117970732", 1.05 + ((math.random() - 0.5) * 0.1), 0.6)
		end
	end)

	-- 4. MeteorDestroyed Handler
	local destroyedEvent = Remotes.getEvent("MeteorDestroyed")
	destroyedEvent.OnClientEvent:Connect(function(data)
		if activeBeaconFolder then
			activeBeaconFolder:Destroy()
			activeBeaconFolder = nil
		end

		-- Update state
		currentServerState = "IDLE"
		updateTimerWidgetUI()

		-- Smoothly transition sky back to daytime dusk
		TweenService:Create(Lighting, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			ClockTime = 17.5,
			Brightness = 2.4,
			OutdoorAmbient = Color3.fromRGB(135, 140, 155),
			FogColor = Color3.fromRGB(155, 168, 185),
		}):Play()

		if data.success then
			print("🎉 [MeteorClient] Meteor Shattered! Jackpot celebration triggered!")

			-- Play full client-side visual shatter explosion & shockwave
			playMeteorShatterFX(data.position or Vector3.zero)

			-- Shatter sound & camera shake
			playSound("rbxassetid://9114223849", 1.0, 1.0) -- Heavy crystal shatter
			shakeCamera(1.8, 1.0)

			-- Play sequential award pop-up & slide-to-left showcase animation
			task.spawn(function()
				playSequentialAwardsAnimation(data)
			end)
		else
			-- Cooled down / failed
			print("💨 [MeteorClient] Meteor cooled down and dissipated")
			if activeShowcaseFrame then
				activeShowcaseFrame:Destroy()
				activeShowcaseFrame = nil
			end
			local activeFolder = Workspace:FindFirstChild("ActiveMeteorEvent")
			if activeFolder then activeFolder:Destroy() end
		end
	end)

	-- 5. MeteorTimerSync Handler (Real-time server sync for next meteor event)
	local timerSyncEvent = Remotes.getEvent("MeteorTimerSync")
	timerSyncEvent.OnClientEvent:Connect(function(data)
		currentServerState = data.state or "IDLE"
		targetNextEventTime = data.nextEventTime or (os.time() + 300)
		currentZoneName = data.zoneName
		currentZoneIcon = data.zoneIcon
		updateTimerWidgetUI()
	end)

	-- 6. Initial Status Query on startup
	task.spawn(function()
		local ok, status = pcall(function()
			local statusFn = Remotes.getFunction("GetMeteorStatus")
			return statusFn:InvokeServer()
		end)
		if ok and status and type(status) == "table" then
			currentServerState = status.state or "IDLE"
			targetNextEventTime = status.nextEventTime or (os.time() + 300)
			currentZoneName = status.zoneName
			currentZoneIcon = status.zoneIcon
			updateTimerWidgetUI()
		end
	end)

	-- 7. Continuous 1-second right-side timer widget ticker loop
	task.spawn(function()
		while true do
			task.wait(1)
			updateTimerWidgetUI()
		end
	end)

	print("✅ [MeteorClient] Meteor World Event Client Initialized with Right-Side Timer!")
end

return MeteorClient
