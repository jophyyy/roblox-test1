--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local BossClient = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- UI Components
local bossGui: ScreenGui
local healthCard: Frame
local cardStroke: UIStroke
local bossTitleLabel: TextLabel
local healthBarFill: Frame
local healthBarCatchup: Frame
local healthText: TextLabel
local statusLabel: TextLabel
local victoryBanner: Frame
local victoryText: TextLabel
local victorySub: TextLabel

local isBossBarVisible = false
local currentBossHP = BossConfig.BOSS.maxHealth
local maxBossHP = BossConfig.BOSS.maxHealth
local currentThemedBossId = "InfernalMagmaGolem"

local function playImpactBoom()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9114223170" -- Heavy rock impact
	sound.PlaybackSpeed = 0.65 -- Deep bass rumble
	sound.Volume = 0.9
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function playVictoryFanfare()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://5153737200" -- Triumphant victory level-up
	sound.PlaybackSpeed = 1.0
	sound.Volume = 0.85
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Sets HUD theme based on the active boss
local function setBossTheme(bossId: string)
	currentThemedBossId = bossId
	if not bossTitleLabel or not cardStroke or not healthBarFill or not statusLabel then return end

	if bossId == "VoidHarbinger" then
		bossTitleLabel.Text = "🌌 VOID HARBINGER CHRONOS [WORLD BOSS] 🌌"
		bossTitleLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
		cardStroke.Color = Color3.fromRGB(140, 40, 255)
		healthBarFill.BackgroundColor3 = Color3.fromRGB(130, 40, 240)
		statusLabel.Text = "Zone 3 Arena • Watch for Void Ground Slams!"
		statusLabel.TextColor3 = Color3.fromRGB(210, 200, 240)
	else
		bossTitleLabel.Text = "👹 INFERNAL MAGMA GOLEM [WORLD BOSS] 👹"
		bossTitleLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
		cardStroke.Color = Color3.fromRGB(255, 65, 15)
		healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
		statusLabel.Text = "Zone 2 Arena • Watch for Ground Slams!"
		statusLabel.TextColor3 = Color3.fromRGB(220, 200, 210)
	end
end

-- Builds the cinematic top-of-screen Boss Health Bar and Victory announcement
local function buildBossUI()
	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("BossHUDGui")
	if existing then existing:Destroy() end

	bossGui = Instance.new("ScreenGui")
	bossGui.Name = "BossHUDGui"
	bossGui.ResetOnSpawn = false
	bossGui.DisplayOrder = 18
	bossGui.Parent = pGui

	-- 1. Main Boss Health Card (Top Center)
	healthCard = Instance.new("Frame")
	healthCard.Name = "BossHealthCard"
	healthCard.Size = UDim2.new(0, 520, 0, 72)
	healthCard.Position = UDim2.new(0.5, 0, -0.15, 0) -- Hidden above viewport
	healthCard.AnchorPoint = Vector2.new(0.5, 0.5)
	healthCard.BackgroundColor3 = Color3.fromRGB(20, 15, 18)
	healthCard.BorderSizePixel = 0
	healthCard.Parent = bossGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = healthCard

	cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(255, 65, 15)
	cardStroke.Thickness = 2.5
	cardStroke.Parent = healthCard

	-- Boss Title
	bossTitleLabel = Instance.new("TextLabel")
	bossTitleLabel.Name = "BossTitle"
	bossTitleLabel.Size = UDim2.new(1, -20, 0, 24)
	bossTitleLabel.Position = UDim2.new(0, 10, 0, 6)
	bossTitleLabel.BackgroundTransparency = 1
	bossTitleLabel.Text = "👹 INFERNAL MAGMA GOLEM [WORLD BOSS] 👹"
	bossTitleLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
	bossTitleLabel.Font = Enum.Font.GothamBlack
	bossTitleLabel.TextSize = 15
	bossTitleLabel.TextStrokeTransparency = 0.2
	bossTitleLabel.Parent = healthCard

	-- Health Bar Background Track
	local barBg = Instance.new("Frame")
	barBg.Name = "HealthTrack"
	barBg.Size = UDim2.new(1, -24, 0, 18)
	barBg.Position = UDim2.new(0, 12, 0, 32)
	barBg.BackgroundColor3 = Color3.fromRGB(38, 22, 25)
	barBg.BorderSizePixel = 0
	barBg.Parent = healthCard

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 9)
	trackCorner.Parent = barBg

	-- Catchup yellow bar
	healthBarCatchup = Instance.new("Frame")
	healthBarCatchup.Name = "CatchupFill"
	healthBarCatchup.Size = UDim2.new(1, 0, 1, 0)
	healthBarCatchup.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	healthBarCatchup.BorderSizePixel = 0
	healthBarCatchup.Parent = barBg

	local catchupCorner = Instance.new("UICorner")
	catchupCorner.CornerRadius = UDim.new(0, 9)
	catchupCorner.Parent = healthBarCatchup

	-- Main Health Bar
	healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "MainFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = healthBarFill

	-- Health Text
	healthText = Instance.new("TextLabel")
	healthText.Name = "HealthNumbers"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(maxBossHP), FormatNumber.formatCompact(maxBossHP))
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.Font = Enum.Font.GothamBlack
	healthText.TextSize = 11
	healthText.TextStrokeTransparency = 0.25
	healthText.Parent = barBg

	-- Subtitle Status text under bar
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusSubtitle"
	statusLabel.Size = UDim2.new(1, -20, 0, 16)
	statusLabel.Position = UDim2.new(0, 10, 0, 52)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Arena Boss • Watch for Ground Slams!"
	statusLabel.TextColor3 = Color3.fromRGB(220, 200, 210)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 11
	statusLabel.TextStrokeTransparency = 0.4
	statusLabel.Parent = healthCard

	-- 2. Massive Victory Banner (Pops on boss kill)
	victoryBanner = Instance.new("Frame")
	victoryBanner.Name = "VictoryBanner"
	victoryBanner.Size = UDim2.new(0, 540, 0, 110)
	victoryBanner.Position = UDim2.new(0.5, 0, 0.28, 0)
	victoryBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	victoryBanner.BackgroundColor3 = Color3.fromRGB(20, 24, 18)
	victoryBanner.BackgroundTransparency = 1 -- Hidden by default
	victoryBanner.BorderSizePixel = 0
	victoryBanner.Parent = bossGui

	local vCorner = Instance.new("UICorner")
	vCorner.CornerRadius = UDim.new(0, 18)
	vCorner.Parent = victoryBanner

	local vStroke = Instance.new("UIStroke")
	vStroke.Color = Color3.fromRGB(255, 215, 0)
	vStroke.Thickness = 3
	vStroke.Transparency = 1
	vStroke.Parent = victoryBanner

	victoryText = Instance.new("TextLabel")
	victoryText.Name = "VictoryHeader"
	victoryText.Size = UDim2.new(1, 0, 0.55, 0)
	victoryText.Position = UDim2.new(0, 0, 0.08, 0)
	victoryText.BackgroundTransparency = 1
	victoryText.Text = "🏆 WORLD BOSS DEFEATED! 🏆"
	victoryText.TextColor3 = Color3.fromRGB(255, 215, 0)
	victoryText.Font = Enum.Font.GothamBlack
	victoryText.TextSize = 22
	victoryText.TextTransparency = 1
	victoryText.TextStrokeTransparency = 1
	victoryText.Parent = victoryBanner

	victorySub = Instance.new("TextLabel")
	victorySub.Name = "VictoryDetails"
	victorySub.Size = UDim2.new(1, 0, 0.4, 0)
	victorySub.Position = UDim2.new(0, 0, 0.58, 0)
	victorySub.BackgroundTransparency = 1
	victorySub.Text = "+$1,000,000 Cash • +5,000 Gems!"
	victorySub.TextColor3 = Color3.fromRGB(0, 230, 118)
	victorySub.Font = Enum.Font.GothamBold
	victorySub.TextSize = 15
	victorySub.TextTransparency = 1
	victorySub.TextStrokeTransparency = 1
	victorySub.Parent = victoryBanner
end

-- Shows / Hides the top Health Card
function BossClient.setBossBarVisible(visible: boolean)
	if isBossBarVisible == visible then return end
	isBossBarVisible = visible

	if visible then
		healthCard.Visible = true
		local tween = TweenService:Create(healthCard, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.085, 0),
		})
		tween:Play()
	else
		local tween = TweenService:Create(healthCard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.15, 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if not isBossBarVisible then
				healthCard.Visible = false
			end
		end)
	end
end

-- Smoothly updates health bars with catchup lag
function BossClient.updateHealth(currHP: number, maxHP: number)
	currentBossHP = currHP
	maxBossHP = maxHP

	local ratio = math.clamp(currHP / maxHP, 0, 1)
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(currHP), FormatNumber.formatCompact(maxHP))

	-- Instant snappy main bar fill
	healthBarFill.Size = UDim2.new(ratio, 0, 1, 0)

	-- Delayed catchup yellow bar
	task.delay(0.2, function()
		TweenService:Create(healthBarCatchup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0),
		}):Play()
	end)
end

-- Renders 3D World Space Damage Numbers
function BossClient.showCombatNumber(worldPos: Vector3, damage: number, isCrit: boolean, effectTag: string?, damageColor: Color3)
	local offset = Vector3.new((math.random() * 4) - 2, 6 + math.random() * 2, (math.random() * 4) - 2)
	local startPos = worldPos + offset

	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = startPos
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 45)
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.15

	if isCrit then
		label.Text = string.format("💥 -%s 💥\n%s", FormatNumber.formatCompact(damage), effectTag or "CRIT!")
		label.TextColor3 = Color3.fromRGB(255, 220, 0)
		label.TextSize = 20
	else
		label.Text = string.format("-%s %s", FormatNumber.formatCompact(damage), if effectTag then "• " .. effectTag else "")
		label.TextColor3 = damageColor
		label.TextSize = 16
	end
	label.Parent = bb

	-- Float up & fade out
	local targetPos = startPos + Vector3.new(0, 4.5, 0)
	local tween = TweenService:Create(part, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	local fade = TweenService:Create(label, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	fade:Play()

	Debris:AddItem(part, 0.9)
end

-- Accurately raycasts down to find the floor surface at any (X, Z) coordinate
local function getFloorY(pos: Vector3): number
	local rayOrigin = Vector3.new(pos.X, 45, pos.Z)
	local rayDir = Vector3.new(0, -90, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignoreList, p.Character)
		end
	end
	local bossFolder = Workspace:FindFirstChild("BossFolder")
	if bossFolder then
		table.insert(ignoreList, bossFolder)
	end
	rayParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(rayOrigin, rayDir, rayParams)
	if result then
		return result.Position.Y + 0.12
	end
	return 2.85 -- Default Colosseum floor height
end

-- Renders an expanding danger zone ring on the floor with fill countdown
function BossClient.visualizeTelegraphSlam(centerPos: Vector3, radius: number, duration: number, bossId: string?)
	local floorY = getFloorY(centerPos)
	local ringColor = if bossId == "VoidHarbinger" then Color3.fromRGB(180, 50, 255) else Color3.fromRGB(255, 40, 10)
	local fillColor = if bossId == "VoidHarbinger" then Color3.fromRGB(140, 30, 240) else Color3.fromRGB(255, 80, 20)

	-- Outer glowing perimeter ring
	local border = Instance.new("Part")
	border.Name = "TelegraphBorder"
	border.Shape = Enum.PartType.Cylinder
	border.Size = Vector3.new(0.35, radius * 2, radius * 2)
	border.CFrame = CFrame.new(centerPos.X, floorY, centerPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	border.Color = ringColor
	border.Material = Enum.Material.Neon
	border.Transparency = 0.45
	border.Anchored = true
	border.CanCollide = false
	border.Parent = Workspace

	-- Expanding inner fill disk
	local fill = Instance.new("Part")
	fill.Name = "TelegraphFill"
	fill.Shape = Enum.PartType.Cylinder
	fill.Size = Vector3.new(0.4, 1, 1)
	fill.CFrame = CFrame.new(centerPos.X, floorY + 0.05, centerPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	fill.Color = fillColor
	fill.Material = Enum.Material.Neon
	fill.Transparency = 0.35
	fill.Anchored = true
	fill.CanCollide = false
	fill.Parent = Workspace

	local fillTween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 0.1,
	})
	fillTween:Play()

	task.delay(duration, function()
		fillTween:Cancel()
		if fill and fill.Parent then fill:Destroy() end
		if border and border.Parent then border:Destroy() end
	end)
end

-- Ground Slam Visual & Sound FX with erupting basalt spikes and geyser
function BossClient.visualizeGroundSlam(bossPos: Vector3, radius: number)
	playImpactBoom()

	local floorY = getFloorY(bossPos)
	local isVoid = (currentThemedBossId == "VoidHarbinger")
	local primaryColor = if isVoid then Color3.fromRGB(150, 50, 255) else Color3.fromRGB(255, 75, 15)
	local rockColor = if isVoid then Color3.fromRGB(24, 18, 36) else Color3.fromRGB(36, 26, 28)

	-- 1. Expanding shockwave ring
	local ring = Instance.new("Part")
	ring.Name = "SlamShockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.45, 4, 4)
	ring.CFrame = CFrame.new(bossPos.X, floorY, bossPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = primaryColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = Workspace

	local expandTween = TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2.2, radius * 2.2),
		Transparency = 1,
	})
	expandTween:Play()
	Debris:AddItem(ring, 0.6)

	-- 2. Towering Magma / Void Geyser Burst at ground center
	local geyser = Instance.new("Part")
	geyser.Name = "SlamGeyser"
	geyser.Shape = Enum.PartType.Cylinder
	geyser.Size = Vector3.new(4, 3, 3)
	geyser.CFrame = CFrame.new(bossPos.X, floorY + 1.5, bossPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	geyser.Color = primaryColor
	geyser.Material = Enum.Material.Neon
	geyser.Transparency = 0.15
	geyser.Anchored = true
	geyser.CanCollide = false
	geyser.Parent = Workspace

	local geyserTween = TweenService:Create(geyser, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(24, 6.5, 6.5),
		CFrame = CFrame.new(bossPos.X, floorY + 12, bossPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1,
	})
	geyserTween:Play()
	Debris:AddItem(geyser, 0.4)

	-- 3. Erupting Basalt Earth Spikes bursting from the ground in a perimeter ring
	local numSpikes = 8
	local spikeRadius = radius * 0.65
	for i = 1, numSpikes do
		local angle = (i / numSpikes) * math.pi * 2
		local spikeOffset = Vector3.new(math.cos(angle) * spikeRadius, 0, math.sin(angle) * spikeRadius)
		local groundPoint = Vector3.new(bossPos.X + spikeOffset.X, floorY, bossPos.Z + spikeOffset.Z)

		local spike = Instance.new("WedgePart")
		spike.Name = "BasaltSpike"
		spike.Size = Vector3.new(2.4, 6.5, 2.4)
		spike.Color = rockColor
		spike.Material = Enum.Material.Basalt
		spike.Anchored = true
		spike.CanCollide = false
		local lookAtCenter = CFrame.lookAt(groundPoint, Vector3.new(bossPos.X, groundPoint.Y, bossPos.Z))
		spike.CFrame = (lookAtCenter * CFrame.Angles(math.rad(18), math.rad(180), 0)) - Vector3.new(0, 6, 0)
		spike.Parent = Workspace

		local riseTween = TweenService:Create(spike, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = spike.CFrame + Vector3.new(0, 7.5, 0),
		})
		riseTween:Play()

		task.delay(0.55, function()
			if spike and spike.Parent then
				local sinkTween = TweenService:Create(spike, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = spike.CFrame - Vector3.new(0, 8, 0),
					Transparency = 1,
				})
				sinkTween:Play()
				sinkTween.Completed:Connect(function()
					spike:Destroy()
				end)
			end
		end)
	end

	-- 4. Dynamic Camera Shake for nearby players
	local myChar = player.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		local dist = (myChar.HumanoidRootPart.Position - bossPos).Magnitude
		if dist <= (radius + 24) then
			task.spawn(function()
				local intensity = math.clamp(1 - (dist / (radius + 24)), 0.25, 1.0)
				for _ = 1, 8 do
					local camOffset = Vector3.new(
						(math.random() - 0.5) * 2.0 * intensity,
						(math.random() - 0.5) * 2.0 * intensity,
						(math.random() - 0.5) * 1.5 * intensity
					)
					camera.CFrame = camera.CFrame * CFrame.new(camOffset)
					RunService.RenderStepped:Wait()
				end
			end)
		end
	end
end

-- Renders apocalyptic meteor strikes across the arena with crystal-clear AOE indicators
function BossClient.visualizeMeteorBarrage(targets: { Vector3 }, bossId: string?)
	local isVoid = (bossId == "VoidHarbinger")
	local meteorColor = if isVoid then Color3.fromRGB(190, 60, 255) else Color3.fromRGB(255, 60, 10)
	local fireColor = if isVoid then Color3.fromRGB(150, 40, 255) else Color3.fromRGB(255, 180, 20)
	local aoeRadius = 14

	for _, rawTargetPos in ipairs(targets) do
		task.spawn(function()
			local floorY = getFloorY(rawTargetPos)
			local targetPos = Vector3.new(rawTargetPos.X, floorY, rawTargetPos.Z)

			-- 1. Outer Danger Ring (Cylinder on floor)
			local warningBorder = Instance.new("Part")
			warningBorder.Name = "MeteorWarningBorder"
			warningBorder.Shape = Enum.PartType.Cylinder
			warningBorder.Size = Vector3.new(0.35, aoeRadius, aoeRadius)
			warningBorder.CFrame = CFrame.new(targetPos.X, floorY + 0.08, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
			warningBorder.Color = meteorColor
			warningBorder.Material = Enum.Material.Neon
			warningBorder.Transparency = 0.45
			warningBorder.Anchored = true
			warningBorder.CanCollide = false
			warningBorder.Parent = Workspace

			-- 2. Expanding Inner Fill Disk (Countdown fill towards aoeRadius)
			local warningFill = Instance.new("Part")
			warningFill.Name = "MeteorWarningFill"
			warningFill.Shape = Enum.PartType.Cylinder
			warningFill.Size = Vector3.new(0.4, 1.5, 1.5)
			warningFill.CFrame = CFrame.new(targetPos.X, floorY + 0.12, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
			warningFill.Color = fireColor
			warningFill.Material = Enum.Material.Neon
			warningFill.Transparency = 0.35
			warningFill.Anchored = true
			warningFill.CanCollide = false
			warningFill.Parent = Workspace

			local fillTween = TweenService:Create(warningFill, TweenInfo.new(1.25, Enum.EasingStyle.Linear), {
				Size = Vector3.new(0.4, aoeRadius, aoeRadius),
				Transparency = 0.1,
			})
			fillTween:Play()

			-- 3. Vertical Target Beacon Beam (Visible from anywhere in the colosseum)
			local targetBeam = Instance.new("Part")
			targetBeam.Name = "MeteorTargetBeam"
			targetBeam.Shape = Enum.PartType.Cylinder
			targetBeam.Size = Vector3.new(45, 2.8, 2.8)
			targetBeam.CFrame = CFrame.new(targetPos.X, floorY + 22.5, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
			targetBeam.Color = meteorColor
			targetBeam.Material = Enum.Material.Neon
			targetBeam.Transparency = 0.65
			targetBeam.Anchored = true
			targetBeam.CanCollide = false
			targetBeam.Parent = Workspace

			local pulseBeam = TweenService:Create(targetBeam, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Transparency = 0.35,
			})
			pulseBeam:Play()

			-- 4. Floating Warning Billboard on ground
			local bbPart = Instance.new("Part")
			bbPart.Size = Vector3.new(0.1, 0.1, 0.1)
			bbPart.CFrame = CFrame.new(targetPos.X, floorY + 1.2, targetPos.Z)
			bbPart.Transparency = 1
			bbPart.Anchored = true
			bbPart.CanCollide = false
			bbPart.Parent = Workspace

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 140, 0, 40)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 90
			bb.Parent = bbPart

			local bbLabel = Instance.new("TextLabel")
			bbLabel.Size = UDim2.new(1, 0, 1, 0)
			bbLabel.BackgroundTransparency = 1
			bbLabel.Text = "⚠️ INCOMING!"
			bbLabel.TextColor3 = fireColor
			bbLabel.Font = Enum.Font.GothamBlack
			bbLabel.TextSize = 14
			bbLabel.TextStrokeTransparency = 0.2
			bbLabel.Parent = bb

			-- 5. Flaming Meteor falling from the sky
			local startPos = targetPos + Vector3.new((math.random() - 0.5) * 6, 65, (math.random() - 0.5) * 6)
			local meteor = Instance.new("Part")
			meteor.Name = "FallingMeteor"
			meteor.Shape = Enum.PartType.Ball
			meteor.Size = Vector3.new(5.0, 5.0, 5.0)
			meteor.Position = startPos
			meteor.Color = meteorColor
			meteor.Material = Enum.Material.Neon
			meteor.Anchored = true
			meteor.CanCollide = false
			meteor.Parent = Workspace

			local attach = Instance.new("Attachment")
			attach.Parent = meteor

			local trailEmitter = Instance.new("ParticleEmitter")
			trailEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, fireColor),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 5)),
			})
			trailEmitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 3.8),
				NumberSequenceKeypoint.new(1, 0.2),
			})
			trailEmitter.Lifetime = NumberRange.new(0.3, 0.6)
			trailEmitter.Rate = 45
			trailEmitter.Speed = NumberRange.new(5, 9)
			trailEmitter.Parent = attach

			-- Accelerate down to target in 1.25s
			local dropTween = TweenService:Create(meteor, TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = targetPos,
			})
			dropTween:Play()

			dropTween.Completed:Connect(function()
				fillTween:Cancel()
				pulseBeam:Cancel()
				if warningBorder and warningBorder.Parent then warningBorder:Destroy() end
				if warningFill and warningFill.Parent then warningFill:Destroy() end
				if targetBeam and targetBeam.Parent then targetBeam:Destroy() end
				if bbPart and bbPart.Parent then bbPart:Destroy() end
				if meteor and meteor.Parent then meteor:Destroy() end

				playImpactBoom()

				-- Crater shockwave burst
				local shockwave = Instance.new("Part")
				shockwave.Name = "MeteorShockwave"
				shockwave.Shape = Enum.PartType.Cylinder
				shockwave.Size = Vector3.new(0.35, 2, 2)
				shockwave.CFrame = CFrame.new(targetPos.X, floorY + 0.12, targetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
				shockwave.Color = meteorColor
				shockwave.Material = Enum.Material.Neon
				shockwave.Transparency = 0.1
				shockwave.Anchored = true
				shockwave.CanCollide = false
				shockwave.Parent = Workspace

				local boomTween = TweenService:Create(shockwave, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.2, 18, 18),
					Transparency = 1,
				})
				boomTween:Play()
				Debris:AddItem(shockwave, 0.5)

				-- Local camera shake
				local myChar = player.Character
				if myChar and myChar:FindFirstChild("HumanoidRootPart") then
					local dist = (myChar.HumanoidRootPart.Position - targetPos).Magnitude
					if dist <= 40 then
						task.spawn(function()
							local intensity = math.clamp(1 - (dist / 40), 0.2, 0.85)
							for _ = 1, 6 do
								local camOffset = Vector3.new(
									(math.random() - 0.5) * 1.6 * intensity,
									(math.random() - 0.5) * 1.6 * intensity,
									(math.random() - 0.5) * 1.1 * intensity
								)
								camera.CFrame = camera.CFrame * CFrame.new(camOffset)
								RunService.RenderStepped:Wait()
							end
						end)
					end
				end
			end)
		end)
	end
end

function BossClient.init()
	print("👹 [BossClient] Initializing Boss Combat Client...")

	buildBossUI()

	-- 1. Listen for BossDamaged RemoteEvent
	local damagedEvent = Remotes.getEvent("BossDamaged")
	damagedEvent.OnClientEvent:Connect(function(currHP, maxHP, damage, isCrit, effectTag, damageColor, attackerName, bossId)
		if bossId then
			setBossTheme(bossId)
		end
		BossClient.updateHealth(currHP, maxHP)

		local bossFolder = Workspace:FindFirstChild("BossFolder")
		local targetModel = if bossId and bossFolder then bossFolder:FindFirstChild(bossId) else nil
		if not targetModel and bossFolder then
			targetModel = bossFolder:FindFirstChild("InfernalMagmaGolem") or bossFolder:FindFirstChild("VoidHarbinger")
		end

		local defaultCenter = if bossId and BossConfig.BOSSES[bossId] then BossConfig.BOSSES[bossId].arenaCenter else BossConfig.BOSS.arenaCenter
		local hitPos = if targetModel and targetModel:IsA("Model") and targetModel.PrimaryPart then targetModel.PrimaryPart.Position else defaultCenter

		BossClient.showCombatNumber(hitPos, damage, isCrit, effectTag, damageColor)
	end)

	-- 2. Listen for BossTelegraphSlam RemoteEvent
	local telegraphEvent = Remotes.getEvent("BossTelegraphSlam")
	telegraphEvent.OnClientEvent:Connect(function(centerPos, radius, duration, bossId)
		if bossId then
			setBossTheme(bossId)
		end
		statusLabel.Text = "⚠️ CRUSHING SLAM CHARGING! GET OUT OF THE RED ZONE! ⚠️"
		statusLabel.TextColor3 = Color3.fromRGB(255, 60, 40)

		BossClient.visualizeTelegraphSlam(centerPos, radius, duration, bossId)
	end)

	-- 3. Listen for BossAttacking RemoteEvent
	local attackEvent = Remotes.getEvent("BossAttacking")
	attackEvent.OnClientEvent:Connect(function(bossPos, radius, bossId)
		if bossId then
			setBossTheme(bossId)
		end
		statusLabel.Text = "💥 IMPACT! EARTH SHATTERED! 💥"
		statusLabel.TextColor3 = Color3.fromRGB(255, 60, 40)

		BossClient.visualizeGroundSlam(bossPos, radius)

		task.delay(1.5, function()
			setBossTheme(currentThemedBossId)
		end)
	end)

	-- 4. Listen for BossMeteorEvent RemoteEvent
	local meteorEvent = Remotes.getEvent("BossMeteorEvent")
	meteorEvent.OnClientEvent:Connect(function(targets, bossId)
		if bossId then
			setBossTheme(bossId)
		end
		statusLabel.Text = "☄️ METEOR BARRAGE INCOMING! EVADE IMPACT ZONES! ☄️"
		statusLabel.TextColor3 = Color3.fromRGB(255, 140, 20)

		BossClient.visualizeMeteorBarrage(targets, bossId)

		task.delay(2.2, function()
			setBossTheme(currentThemedBossId)
		end)
	end)

	-- 5. Listen for BossDefeated RemoteEvent
	local defeatedEvent = Remotes.getEvent("BossDefeated")
	defeatedEvent.OnClientEvent:Connect(function(killerName, cashReward, gemReward, respawnTime, bossName, bossId)
		playVictoryFanfare()
		BossClient.updateHealth(0, maxBossHP)

		local bTitle = (bossName or "WORLD BOSS"):upper()
		victoryText.Text = string.format("🏆 %s DEFEATED %s! 🏆", killerName:upper(), bTitle)
		victorySub.Text = string.format("+$%s Cash • +%s Gems!", FormatNumber.formatCompact(cashReward), FormatNumber.formatCompact(gemReward))

		local stroke = victoryBanner:FindFirstChildOfClass("UIStroke")

		-- Fade in victory banner
		TweenService:Create(victoryBanner, TweenInfo.new(0.4), { BackgroundTransparency = 0.15 }):Play()
		TweenService:Create(victoryText, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
		TweenService:Create(victorySub, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
		if stroke then TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.1 }):Play() end

		-- Countdown on Boss bar
		task.spawn(function()
			for s = respawnTime, 1, -1 do
				statusLabel.Text = string.format("⏳ Boss Defeated! Respawning in %ds...", s)
				statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				task.wait(1.0)
			end
		end)

		task.delay(4.5, function()
			TweenService:Create(victoryBanner, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(victoryText, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(victorySub, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play() end
		end)
	end)

	-- 6. Listen for BossRespawned RemoteEvent
	local respawnEvent = Remotes.getEvent("BossRespawned")
	respawnEvent.OnClientEvent:Connect(function(newMaxHP, spawnPos, bossId)
		if bossId then
			setBossTheme(bossId)
		end
		BossClient.updateHealth(newMaxHP, newMaxHP)
	end)

	-- 7. Proximity Tracking: Auto-Show/Hide Boss Health Bar when near Arena
	task.spawn(function()
		while true do
			task.wait(0.4)
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local pPos = char.HumanoidRootPart.Position

				local magmaCenter = BossConfig.BOSSES.InfernalMagmaGolem.arenaCenter
				local distMagma = (Vector3.new(pPos.X, magmaCenter.Y, pPos.Z) - magmaCenter).Magnitude

				local voidCenter = BossConfig.BOSSES.VoidHarbinger.arenaCenter
				local distVoid = (Vector3.new(pPos.X, voidCenter.Y, pPos.Z) - voidCenter).Magnitude

				if distMagma <= 90 then
					setBossTheme("InfernalMagmaGolem")
					BossClient.setBossBarVisible(true)
				elseif distVoid <= 90 then
					setBossTheme("VoidHarbinger")
					BossClient.setBossBarVisible(true)
				else
					BossClient.setBossBarVisible(false)
				end
			else
				BossClient.setBossBarVisible(false)
			end
		end
	end)

	print("✅ [BossClient] Initialized! Multi-Boss HUD and Combat FX Active.")
end

return BossClient
