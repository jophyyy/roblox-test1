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

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(255, 65, 15)
	cardStroke.Thickness = 2.5
	cardStroke.Parent = healthCard

	-- Boss Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "BossTitle"
	titleLabel.Size = UDim2.new(1, -20, 0, 24)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "👹 INFERNAL MAGMA GOLEM [WORLD BOSS] 👹"
	titleLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 15
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = healthCard

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

	-- Catchup yellow bar (for juicy damage impact feel)
	healthBarCatchup = Instance.new("Frame")
	healthBarCatchup.Name = "CatchupFill"
	healthBarCatchup.Size = UDim2.new(1, 0, 1, 0)
	healthBarCatchup.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	healthBarCatchup.BorderSizePixel = 0
	healthBarCatchup.Parent = barBg

	local catchupCorner = Instance.new("UICorner")
	catchupCorner.CornerRadius = UDim.new(0, 9)
	catchupCorner.Parent = healthBarCatchup

	-- Main Fiery Red/Orange Health Bar
	healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "MainFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = healthBarFill

	-- Health Text (Overlay on top of bar)
	healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(maxBossHP), FormatNumber.formatCompact(maxBossHP))
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.Font = Enum.Font.GothamBold
	healthText.TextSize = 12
	healthText.TextStrokeTransparency = 0.3
	healthText.Parent = barBg

	-- Subtitle Status (e.g. "⚔️ In Combat • Ground Slam Incoming!")
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 16)
	statusLabel.Position = UDim2.new(0, 0, 0, 52)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Zone 2 Arena • Watch for Ground Slams!"
	statusLabel.TextColor3 = Color3.fromRGB(220, 200, 210)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 11
	statusLabel.TextStrokeTransparency = 0.4
	statusLabel.Parent = healthCard

	-- 2. Victory Announcement Banner
	victoryBanner = Instance.new("Frame")
	victoryBanner.Name = "VictoryBanner"
	victoryBanner.Size = UDim2.new(0, 480, 0, 80)
	victoryBanner.Position = UDim2.new(0.5, 0, 0.22, 0)
	victoryBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	victoryBanner.BackgroundColor3 = Color3.fromRGB(25, 18, 22)
	victoryBanner.BackgroundTransparency = 1
	victoryBanner.BorderSizePixel = 0
	victoryBanner.Parent = bossGui

	local vCorner = Instance.new("UICorner")
	vCorner.CornerRadius = UDim.new(0, 16)
	vCorner.Parent = victoryBanner

	local vStroke = Instance.new("UIStroke")
	vStroke.Color = Color3.fromRGB(255, 215, 0)
	vStroke.Thickness = 2.5
	vStroke.Transparency = 1
	vStroke.Parent = victoryBanner

	victoryText = Instance.new("TextLabel")
	victoryText.Name = "VictoryTitle"
	victoryText.Size = UDim2.new(1, 0, 0.55, 0)
	victoryText.BackgroundTransparency = 1
	victoryText.Text = "🏆 INFERNAL MAGMA GOLEM DEFEATED! 🏆"
	victoryText.TextColor3 = Color3.fromRGB(255, 215, 0)
	victoryText.Font = Enum.Font.GothamBlack
	victoryText.TextSize = 18
	victoryText.TextTransparency = 1
	victoryText.TextStrokeTransparency = 1
	victoryText.Parent = victoryBanner

	victorySub = Instance.new("TextLabel")
	victorySub.Name = "VictorySub"
	victorySub.Size = UDim2.new(1, 0, 0.45, 0)
	victorySub.Position = UDim2.new(0, 0, 0.55, 0)
	victorySub.BackgroundTransparency = 1
	victorySub.Text = "+$1,000,000 Cash • +5,000 Gems!"
	victorySub.TextColor3 = Color3.fromRGB(0, 240, 255)
	victorySub.Font = Enum.Font.GothamBold
	victorySub.TextSize = 14
	victorySub.TextTransparency = 1
	victorySub.TextStrokeTransparency = 1
	victorySub.Parent = victoryBanner
end

-- Toggles top boss health card visibility
function BossClient.setBossBarVisible(visible: boolean)
	if isBossBarVisible == visible then return end
	isBossBarVisible = visible

	local targetPos = if visible then UDim2.new(0.5, 0, 0.08, 0) else UDim2.new(0.5, 0, -0.15, 0)
	local style = if visible then Enum.EasingStyle.Back else Enum.EasingStyle.Quad
	local dir = if visible then Enum.EasingDirection.Out else Enum.EasingDirection.In

	TweenService:Create(healthCard, TweenInfo.new(0.4, style, dir), {
		Position = targetPos,
	}):Play()
end

-- Updates boss health bar display
function BossClient.updateHealth(currentHP: number, maxHP: number)
	currentBossHP = math.max(0, currentHP)
	maxBossHP = maxHP

	local ratio = math.clamp(currentBossHP / maxBossHP, 0, 1)

	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(currentBossHP), FormatNumber.formatCompact(maxBossHP))

	-- Main bar updates immediately
	TweenService:Create(healthBarFill, TweenInfo.new(0.12, Enum.EasingStyle.Linear), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()

	-- Catchup yellow bar trails smoothly
	TweenService:Create(healthBarCatchup, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
end

-- Displays 3D floating damage number over boss with pickaxe trait styling
function BossClient.showCombatNumber(position: Vector3, damage: number, isCrit: boolean, effectTag: string?, damageColor: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 48)
	billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 8.5 + (math.random(0, 15) / 10), math.random(-15, 15) / 10)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 80

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.65, 0)
	label.BackgroundTransparency = 1
	label.Text = (if isCrit then "💥 -" else "-") .. FormatNumber.formatCompact(damage)
	label.TextColor3 = damageColor or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if isCrit then 22 else 17
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	if effectTag and effectTag ~= "None" then
		local tag = Instance.new("TextLabel")
		tag.Size = UDim2.new(1, 0, 0.35, 0)
		tag.Position = UDim2.new(0, 0, 0.65, 0)
		tag.BackgroundTransparency = 1
		tag.Text = effectTag
		tag.TextColor3 = if isCrit then Color3.fromRGB(255, 215, 0) else damageColor
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 12
		tag.TextStrokeTransparency = 0.25
		tag.Parent = billboard
	end

	-- Anchor to a temporary invisible part at boss position
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = Workspace
	billboard.Parent = part

	-- Floating animation upwards
	TweenService:Create(billboard, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, 3.2, 0),
	}):Play()

	TweenService:Create(label, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	Debris:AddItem(part, 1.1)
end

-- Ground slam visual telegraph & camera shake
function BossClient.visualizeGroundSlam(bossPos: Vector3, radius: number)
	task.spawn(function()
		-- 1. Warning red ring expanding on ground
		local ring = Instance.new("Part")
		ring.Name = "SlamTelegraphRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 2, 2)
		ring.CFrame = CFrame.new(bossPos - Vector3.new(0, 3.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = Color3.fromRGB(255, 40, 10)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.5
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = Workspace

		TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, radius * 2, radius * 2),
			Transparency = 0.2,
		}):Play()

		task.wait(0.45)

		-- 2. Impact: Fiery shockwave explosion
		playImpactBoom()

		ring.Color = Color3.fromRGB(255, 220, 80)
		TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.4, (radius + 6) * 2, (radius + 6) * 2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.4)

		-- 3. Camera Shake if player is close
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local pPos = char.HumanoidRootPart.Position
			local dist = (pPos - bossPos).Magnitude
			if dist <= 55 then
				local shakePower = math.clamp(1 - (dist / 55), 0.2, 1.0)
				for i = 1, 6 do
					local offset = Vector3.new((math.random() - 0.5) * shakePower * 0.8, (math.random() - 0.5) * shakePower * 0.8, 0)
					camera.CFrame = camera.CFrame * CFrame.Angles(offset.X * 0.05, offset.Y * 0.05, 0)
					RunService.RenderStepped:Wait()
				end
			end
		end
	end)
end

function BossClient.init()
	print("👹 [BossClient] Initializing Boss Combat Client...")

	buildBossUI()

	-- 1. Listen for BossDamaged RemoteEvent
	local damagedEvent = Remotes.getEvent("BossDamaged")
	damagedEvent.OnClientEvent:Connect(function(currHP, maxHP, damage, isCrit, effectTag, damageColor, attackerName)
		BossClient.updateHealth(currHP, maxHP)

		local bossFolder = Workspace:FindFirstChild("BossFolder")
		local bossModel = bossFolder and bossFolder:FindFirstChild("InfernalMagmaGolem")
		local hitPos = if bossModel and bossModel.PrimaryPart then bossModel.PrimaryPart.Position else BossConfig.BOSS.arenaCenter

		BossClient.showCombatNumber(hitPos, damage, isCrit, effectTag, damageColor)
	end)

	-- 2. Listen for BossAttacking RemoteEvent
	local attackEvent = Remotes.getEvent("BossAttacking")
	attackEvent.OnClientEvent:Connect(function(bossPos, radius)
		statusLabel.Text = "⚠️ BOSS SLAM INCOMING! SPRINT AWAY! ⚠️"
		statusLabel.TextColor3 = Color3.fromRGB(255, 60, 40)

		BossClient.visualizeGroundSlam(bossPos, radius)

		task.delay(1.5, function()
			statusLabel.Text = "Zone 2 Arena • Watch for Ground Slams!"
			statusLabel.TextColor3 = Color3.fromRGB(220, 200, 210)
		end)
	end)

	-- 3. Listen for BossDefeated RemoteEvent
	local defeatedEvent = Remotes.getEvent("BossDefeated")
	defeatedEvent.OnClientEvent:Connect(function(killerName, cashReward, gemReward, respawnTime)
		playVictoryFanfare()
		BossClient.updateHealth(0, maxBossHP)

		victoryText.Text = string.format("🏆 %s DEFEATED THE MAGMA GOLEM! 🏆", killerName:upper())
		victorySub.Text = string.format("+$%s Cash • +%d Gems!", FormatNumber.formatCompact(cashReward), gemReward)

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

	-- 4. Listen for BossRespawned RemoteEvent
	local respawnEvent = Remotes.getEvent("BossRespawned")
	respawnEvent.OnClientEvent:Connect(function(newMaxHP, spawnPos)
		BossClient.updateHealth(newMaxHP, newMaxHP)
		statusLabel.Text = "Zone 2 Arena • Watch for Ground Slams!"
		statusLabel.TextColor3 = Color3.fromRGB(220, 200, 210)
	end)

	-- 5. Proximity Tracking: Auto-Show/Hide Boss Health Bar when near Arena
	task.spawn(function()
		while true do
			task.wait(0.4)
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local pPos = char.HumanoidRootPart.Position
				local center = BossConfig.BOSS.arenaCenter
				local dist = (Vector3.new(pPos.X, center.Y, pPos.Z) - center).Magnitude

				if dist <= 75 then
					BossClient.setBossBarVisible(true)
				else
					BossClient.setBossBarVisible(false)
				end
			else
				BossClient.setBossBarVisible(false)
			end
		end
	end)

	print("✅ [BossClient] Initialized! Boss HUD and Combat FX Active.")
end

return BossClient
