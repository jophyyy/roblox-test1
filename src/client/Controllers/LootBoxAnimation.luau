--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LootBoxConfig = require(ReplicatedStorage.Shared.Config.LootBoxConfig)

local LootBoxAnimation = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local SOUNDS = {
	Thud = "rbxassetid://6895079853",
	Fanfare = "rbxassetid://5153737200",
	Chime = "rbxassetid://131886985",
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

-- Builds a stylized 3D Chest model inside the ViewportFrame
local function buildChestModel(boxDef: LootBoxConfig.LootBoxDef): (Model, Part, Part, Part)
	local model = Instance.new("Model")
	model.Name = "Chest_" .. boxDef.id

	local baseColor = boxDef.color
	local trimColor = boxDef.accentColor
	local isNeon = (boxDef.modelType == "Cyber" or boxDef.modelType == "Void" or boxDef.modelType == "Magma")

	-- 1. Chest Base
	local base = Instance.new("Part")
	base.Name = "ChestBase"
	base.Size = Vector3.new(3.6, 2.0, 2.6)
	base.CFrame = CFrame.new(0, 1.0, 0)
	base.Color = baseColor
	base.Material = if isNeon then Enum.Material.Glass else Enum.Material.WoodPlanks
	base.Anchored = true
	base.CanCollide = false
	base.Parent = model

	-- Base Trim / Straps (Left & Right corner brackets)
	for _, xOffset in ipairs({ -1.6, 1.6 }) do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.3, 2.06, 2.66)
		band.CFrame = base.CFrame * CFrame.new(xOffset, 0, 0)
		band.Color = trimColor
		band.Material = if isNeon then Enum.Material.Neon else Enum.Material.Metal
		band.Anchored = true
		band.CanCollide = false
		band.Parent = model
	end

	-- 2. Chest Lid (Rotates on rear hinge)
	local hingeOrigin = CFrame.new(0, 2.0, 1.3)
	local lid = Instance.new("Part")
	lid.Name = "ChestLid"
	lid.Size = Vector3.new(3.68, 1.1, 2.68)
	-- Offset center relative to hinge
	lid.CFrame = hingeOrigin * CFrame.new(0, 0.55, -1.34)
	lid.Color = baseColor
	lid.Material = if isNeon then Enum.Material.Glass else Enum.Material.WoodPlanks
	lid.Anchored = true
	lid.CanCollide = false
	lid.Parent = model

	-- Lid Top Bevel / Arch
	local lidTop = Instance.new("Part")
	lidTop.Name = "LidTop"
	lidTop.Size = Vector3.new(3.5, 0.4, 2.4)
	lidTop.CFrame = lid.CFrame * CFrame.new(0, 0.65, 0)
	lidTop.Color = trimColor
	lidTop.Material = if isNeon then Enum.Material.Neon else Enum.Material.Metal
	lidTop.Anchored = true
	lidTop.CanCollide = false
	lidTop.Parent = model

	-- 3. Front Latch / Lock
	local latch = Instance.new("Part")
	latch.Name = "LockLatch"
	latch.Size = Vector3.new(0.8, 0.9, 0.3)
	latch.CFrame = base.CFrame * CFrame.new(0, 0.5, -1.45)
	latch.Color = trimColor
	latch.Material = Enum.Material.Neon
	latch.Anchored = true
	latch.CanCollide = false
	latch.Parent = model

	-- 4. Glowing Internal Core (Light shoots out when open)
	local coreLight = Instance.new("Part")
	coreLight.Name = "CoreLight"
	coreLight.Size = Vector3.new(2.8, 0.8, 1.8)
	coreLight.CFrame = base.CFrame * CFrame.new(0, 0.4, 0)
	coreLight.Color = trimColor
	coreLight.Material = Enum.Material.Neon
	coreLight.Transparency = 1
	coreLight.Anchored = true
	coreLight.CanCollide = false
	coreLight.Parent = model

	model.PrimaryPart = base
	return model, base, lid, coreLight
end

function LootBoxAnimation.playOpen(
	boxDef: LootBoxConfig.LootBoxDef,
	reward: LootBoxConfig.RewardItem,
	remainingCount: number,
	onFinished: (() -> ())?,
	onOpenAnother: (() -> ())?
)
	-- Remove any existing animation GUI
	local existing = playerGui:FindFirstChild("LootBoxOpenGui")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LootBoxOpenGui"
	screenGui.DisplayOrder = 160
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Darkened Background Vignette
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	bg.BackgroundTransparency = 1
	bg.BorderSizePixel = 0
	bg.Parent = screenGui

	TweenService:Create(bg, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.25,
	}):Play()

	-- Sunburst / Radial Rays behind Chest
	local sunburst = Instance.new("Frame")
	sunburst.Size = UDim2.new(0, 850, 0, 850)
	sunburst.Position = UDim2.new(0.5, 0, 0.5, -40)
	sunburst.AnchorPoint = Vector2.new(0.5, 0.5)
	sunburst.BackgroundTransparency = 1
	sunburst.Parent = screenGui

	for i = 1, 12 do
		local ray = Instance.new("Frame")
		ray.Size = UDim2.new(0, 18, 1, 0)
		ray.Position = UDim2.new(0.5, -9, 0, 0)
		ray.BackgroundColor3 = boxDef.color
		ray.BackgroundTransparency = 0.88
		ray.BorderSizePixel = 0
		ray.Rotation = (i - 1) * 30
		ray.Parent = sunburst

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(1, 0)
		rCorner.Parent = ray
	end

	-- Spin sunburst in background
	local sunburstRotConn = RunService.RenderStepped:Connect(function(_, step)
		if sunburst and sunburst.Parent then
			sunburst.Rotation = (sunburst.Rotation + (step * 22)) % 360
		end
	end)

	-- Viewport Frame for 3D Chest Model
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(0, 520, 0, 420)
	viewport.Position = UDim2.new(0.5, 0, 0.44, 0)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -2, -1).Unit
	viewport.Ambient = Color3.fromRGB(160, 160, 180)
	viewport.Parent = screenGui

	-- 3D World Setup
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 48
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.2, -7.5), Vector3.new(0, 1.3, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model, base, lid, coreLight = buildChestModel(boxDef)
	model.Parent = world

	-- White Screen Flash Overlay
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = screenGui

	-- Skip / Fast-Forward Button
	local isSkipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Size = UDim2.new(0, 110, 0, 36)
	skipBtn.Position = UDim2.new(1, -130, 0, 24)
	skipBtn.BackgroundColor3 = Color3.fromRGB(34, 38, 52)
	skipBtn.Text = "⚡ SKIP ❯❯"
	skipBtn.TextColor3 = Color3.fromRGB(200, 215, 240)
	skipBtn.Font = Enum.Font.GothamBlack
	skipBtn.TextSize = 13
	skipBtn.BorderSizePixel = 0
	skipBtn.ZIndex = 25
	skipBtn.Parent = screenGui

	local skCorner = Instance.new("UICorner")
	skCorner.CornerRadius = UDim.new(0, 8)
	skCorner.Parent = skipBtn

	local skStroke = Instance.new("UIStroke")
	skStroke.Color = Color3.fromRGB(80, 95, 125)
	skStroke.Thickness = 1.2
	skStroke.Parent = skipBtn

	skipBtn.MouseButton1Click:Connect(function()
		isSkipped = true
		skipBtn.Visible = false
	end)

	-- Chest Drop & Rumble Sequence
	local baseTargetCF = CFrame.new(0, 1.0, 0)
	local lidTargetCF = CFrame.new(0, 2.0, 1.3) * CFrame.new(0, 0.55, -1.34)

	-- Initial high position
	base.CFrame = baseTargetCF * CFrame.new(0, 14, 0)
	lid.CFrame = lidTargetCF * CFrame.new(0, 14, 0)

	-- Drop Animation with Elastic / Back easing
	playSound(SOUNDS.Thud, 0.4, 0.7)
	local dropTweenInfo = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(base, dropTweenInfo, { CFrame = baseTargetCF }):Play()
	local lidDropTween = TweenService:Create(lid, dropTweenInfo, { CFrame = lidTargetCF })
	lidDropTween:Play()
	lidDropTween.Completed:Wait()

	playSound(SOUNDS.Thud, 0.8, 1.0)

	-- Shake & Rattle Phase
	local rattleTime = 1.35
	local startTime = os.clock()
	local rumbleConn: RBXScriptConnection? = nil
	local lastClickTime = 0

	rumbleConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= rattleTime or isSkipped then
			if rumbleConn then
				rumbleConn:Disconnect()
				rumbleConn = nil
			end
			return
		end

		local progress = elapsed / rattleTime
		local intensity = 0.04 + (progress * 0.22)
		local speed = 25 + (progress * 45)

		local rotOffset = math.sin(elapsed * speed) * intensity
		local xOffset = math.cos(elapsed * speed * 1.3) * (intensity * 0.7)

		base.CFrame = baseTargetCF * CFrame.Angles(0, 0, rotOffset) * CFrame.new(xOffset, 0, 0)
		lid.CFrame = lidTargetCF * CFrame.Angles(0, 0, rotOffset) * CFrame.new(xOffset, 0, 0)

		-- Soft clicking
		if os.clock() - lastClickTime >= (0.16 - (progress * 0.10)) then
			lastClickTime = os.clock()
			playSound(SOUNDS.Thud, 0.25, 2.2 + (progress * 0.5))
		end
	end)

	if not isSkipped then
		task.wait(rattleTime)
	end
	if rumbleConn then
		rumbleConn:Disconnect()
		rumbleConn = nil
	end

	-- Restore level position before pop
	base.CFrame = baseTargetCF
	lid.CFrame = lidTargetCF

	-- Unlatch & Burst open lid
	playSound(SOUNDS.Thud, 0.9, 2.0)
	skipBtn.Visible = false

	-- Lid flips back on hinge
	local hingeCF = CFrame.new(0, 2.0, 1.3)
	local openLidCF = hingeCF * CFrame.Angles(-math.rad(110), 0, 0) * CFrame.new(0, 0.55, -1.34)
	TweenService:Create(lid, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = openLidCF,
	}):Play()

	-- Core light flares up
	coreLight.Transparency = 0.15
	TweenService:Create(coreLight, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(3.4, 2.2, 2.4),
		Transparency = 0.4,
	}):Play()

	-- White flash
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	-- Triumphant Fanfare
	playSound(SOUNDS.Fanfare, 0.65, 1.0)

	-- Build Floating Reward Card
	local rewardFrame = Instance.new("Frame")
	rewardFrame.Size = UDim2.new(0, 420, 0, 260)
	rewardFrame.Position = UDim2.new(0.5, 0, 0.68, 0) -- starts low near chest
	rewardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rewardFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	rewardFrame.BackgroundTransparency = 1
	rewardFrame.BorderSizePixel = 0
	rewardFrame.ZIndex = 30
	rewardFrame.Parent = screenGui

	local rfCorner = Instance.new("UICorner")
	rfCorner.CornerRadius = UDim.new(0, 16)
	rfCorner.Parent = rewardFrame

	local rarityColor = LootBoxConfig.TIER_COLORS[reward.rarity] or Color3.fromRGB(255, 215, 0)

	local rfStroke = Instance.new("UIStroke")
	rfStroke.Color = rarityColor
	rfStroke.Thickness = 2.5
	rfStroke.Transparency = 1
	rfStroke.Parent = rewardFrame

	-- Header Banner: "YOU UNLOCKED!"
	local unlockBanner = Instance.new("TextLabel")
	unlockBanner.Size = UDim2.new(1, 0, 0, 28)
	unlockBanner.Position = UDim2.new(0, 0, 0, 14)
	unlockBanner.BackgroundTransparency = 1
	unlockBanner.Text = "✨ YOU UNLOCKED! ✨"
	unlockBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
	unlockBanner.Font = Enum.Font.GothamBlack
	unlockBanner.TextSize = 16
	unlockBanner.TextTransparency = 1
	unlockBanner.ZIndex = 31
	unlockBanner.Parent = rewardFrame

	-- Rarity Pill Badge
	local rarityBadge = Instance.new("TextLabel")
	rarityBadge.Size = UDim2.new(0, 130, 0, 22)
	rarityBadge.Position = UDim2.new(0.5, 0, 0, 46)
	rarityBadge.AnchorPoint = Vector2.new(0.5, 0)
	rarityBadge.BackgroundColor3 = rarityColor
	rarityBadge.Text = string.format("★ %s ★", reward.rarity:upper())
	rarityBadge.TextColor3 = if reward.rarity == "Mythic" or reward.rarity == "Common" then Color3.fromRGB(25, 25, 25) else Color3.fromRGB(255, 255, 255)
	rarityBadge.Font = Enum.Font.GothamBlack
	rarityBadge.TextSize = 11
	rarityBadge.BackgroundTransparency = 1
	rarityBadge.TextTransparency = 1
	rarityBadge.ZIndex = 31
	rarityBadge.BorderSizePixel = 0
	rarityBadge.Parent = rewardFrame

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 6)
	rbCorner.Parent = rarityBadge

	-- Big Glowing Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 0, 68)
	iconLabel.Position = UDim2.new(0, 0, 0, 72)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = reward.icon
	iconLabel.TextSize = 58
	iconLabel.TextTransparency = 1
	iconLabel.ZIndex = 31
	iconLabel.Parent = rewardFrame

	-- Reward Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -24, 0, 32)
	nameLabel.Position = UDim2.new(0, 12, 0, 142)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = reward.name
	nameLabel.TextColor3 = rarityColor
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 22
	nameLabel.TextTransparency = 1
	nameLabel.ZIndex = 31
	nameLabel.Parent = rewardFrame

	-- Reward Description Subtitle
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -30, 0, 20)
	descLabel.Position = UDim2.new(0, 15, 0, 174)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = reward.description
	descLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	descLabel.Font = Enum.Font.GothamBold
	descLabel.TextSize = 12
	descLabel.TextTransparency = 1
	descLabel.ZIndex = 31
	descLabel.Parent = rewardFrame

	-- Action Buttons Row
	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.new(1, -30, 0, 42)
	btnRow.Position = UDim2.new(0, 15, 1, -54)
	btnRow.BackgroundTransparency = 1
	btnRow.ZIndex = 31
	btnRow.Parent = rewardFrame

	local hasMore = (remainingCount > 0)

	-- Collect Button
	local collectBtn = Instance.new("TextButton")
	collectBtn.Size = if hasMore then UDim2.new(0.48, 0, 1, 0) else UDim2.new(1, 0, 1, 0)
	collectBtn.Position = UDim2.new(0, 0, 0, 0)
	collectBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
	collectBtn.Text = "✓ COLLECT"
	collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectBtn.Font = Enum.Font.GothamBlack
	collectBtn.TextSize = 14
	collectBtn.BackgroundTransparency = 1
	collectBtn.TextTransparency = 1
	collectBtn.ZIndex = 32
	collectBtn.BorderSizePixel = 0
	collectBtn.Parent = btnRow

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = collectBtn

	-- Open Another Button (if player has more of this crate)
	local openMoreBtn: TextButton? = nil
	if hasMore then
		openMoreBtn = Instance.new("TextButton")
		openMoreBtn.Size = UDim2.new(0.48, 0, 1, 0)
		openMoreBtn.Position = UDim2.new(0.52, 0, 0, 0)
		openMoreBtn.BackgroundColor3 = boxDef.color
		openMoreBtn.Text = string.format("OPEN ANOTHER (%d)", remainingCount)
		openMoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		openMoreBtn.Font = Enum.Font.GothamBlack
		openMoreBtn.TextSize = 12
		openMoreBtn.BackgroundTransparency = 1
		openMoreBtn.TextTransparency = 1
		openMoreBtn.ZIndex = 32
		openMoreBtn.BorderSizePixel = 0
		openMoreBtn.Parent = btnRow

		local omCorner = Instance.new("UICorner")
		omCorner.CornerRadius = UDim.new(0, 8)
		omCorner.Parent = openMoreBtn
	end

	-- Rise and Fade In Tween for Reward Card
	local revealTween = TweenService:Create(rewardFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.48, 0),
		BackgroundTransparency = 0.05,
	})
	revealTween:Play()

	TweenService:Create(rfStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 }):Play()
	TweenService:Create(unlockBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(rarityBadge, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
	TweenService:Create(iconLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(nameLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(descLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(collectBtn, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
	if openMoreBtn then
		TweenService:Create(openMoreBtn, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
	end

	-- Clean exit handler
	local function closeAnimation()
		if sunburstRotConn then
			sunburstRotConn:Disconnect()
			sunburstRotConn = nil
		end
		screenGui:Destroy()
		if onFinished then
			onFinished()
		end
	end

	collectBtn.MouseButton1Click:Connect(closeAnimation)

	if openMoreBtn and onOpenAnother then
		openMoreBtn.MouseButton1Click:Connect(function()
			if sunburstRotConn then
				sunburstRotConn:Disconnect()
				sunburstRotConn = nil
			end
			screenGui:Destroy()
			onOpenAnother()
		end)
	end
end

return LootBoxAnimation
