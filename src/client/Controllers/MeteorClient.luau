--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local victoryBanner: Frame
local victoryTitle: TextLabel
local victorySubtitle: TextLabel

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

	-- 2. Victory Banner (Top-Center Celebration)
	victoryBanner = Instance.new("Frame")
	victoryBanner.Name = "MeteorVictoryBanner"
	victoryBanner.Size = UDim2.new(0, 520, 0, 85)
	victoryBanner.Position = UDim2.new(0.5, 0, -0.2, 0) -- Hidden above
	victoryBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	victoryBanner.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	victoryBanner.BorderSizePixel = 0
	victoryBanner.Parent = screenGui

	local vCorner = Instance.new("UICorner")
	vCorner.CornerRadius = UDim.new(0, 16)
	vCorner.Parent = victoryBanner

	local vStroke = Instance.new("UIStroke")
	vStroke.Color = Color3.fromRGB(255, 215, 60)
	vStroke.Thickness = 2.5
	vStroke.Parent = victoryBanner

	victoryTitle = Instance.new("TextLabel")
	victoryTitle.Name = "Title"
	victoryTitle.Size = UDim2.new(1, -20, 0.42, 0)
	victoryTitle.Position = UDim2.new(0, 10, 0.08, 0)
	victoryTitle.BackgroundTransparency = 1
	victoryTitle.Text = "🎉 METEOR SHATTERED! JACKPOT GRANTED! 🎉"
	victoryTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	victoryTitle.Font = Enum.Font.GothamBlack
	victoryTitle.TextSize = 18
	victoryTitle.TextStrokeTransparency = 0.15
	victoryTitle.Parent = victoryBanner

	victorySubtitle = Instance.new("TextLabel")
	victorySubtitle.Name = "Subtitle"
	victorySubtitle.Size = UDim2.new(1, -20, 0.45, 0)
	victorySubtitle.Position = UDim2.new(0, 10, 0.50, 0)
	victorySubtitle.BackgroundTransparency = 1
	victorySubtitle.Text = "+$25,000,000 Cash • +15,000 Gems • 3 Rare Crates"
	victorySubtitle.TextColor3 = Color3.fromRGB(0, 240, 255)
	victorySubtitle.Font = Enum.Font.GothamBold
	victorySubtitle.TextSize = 14
	victorySubtitle.TextStrokeTransparency = 0.2
	victorySubtitle.Parent = victoryBanner
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
	lbl.Text = "-" .. FormatNumber.format(damage) .. " 💥"
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
		print("☄️ [MeteorClient] Meteor touched down at " .. tostring(data.zoneName))

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

		if data.success then
			print("🎉 [MeteorClient] Meteor Shattered! Jackpot celebration triggered!")

			-- Victory Fanfare Sound
			playSound("rbxassetid://5153737200", 1.1, 0.9)

			victoryTitle.Text = "🎉 METEOR SHATTERED! JACKPOT GRANTED! 🎉"
			victorySubtitle.Text = string.format("+$%s Cash  •  +%s Gems  •  3 Rare Crates", FormatNumber.format(data.jackpotCash or 25_000_000), FormatNumber.format(data.jackpotGems or 15_000))

			-- Slide victory banner down into view
			victoryBanner.Position = UDim2.new(0.5, 0, -0.2, 0)
			victoryBanner.Visible = true
			TweenService:Create(victoryBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.08, 0),
			}):Play()

			-- Hide victory banner after 6 seconds
			task.delay(6.0, function()
				TweenService:Create(victoryBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, -0.2, 0),
				}):Play()
			end)
		else
			-- Cooled down / failed
			print("💨 [MeteorClient] Meteor cooled down and dissipated")
		end
	end)

	print("✅ [MeteorClient] Meteor World Event Client Initialized!")
end

return MeteorClient
