--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DungeonClient = {}

-- State
local inDungeon = false
local currentStage = 0
local totalStages = 5
local mobsRemaining = 0
local isBossStage = false

-- UI Elements
local screenGui: ScreenGui? = nil
local hudCard: Frame? = nil
local stageTitleLabel: TextLabel? = nil
local mobsLeftLabel: TextLabel? = nil
local exitButton: TextButton? = nil

-- Boss Bar Elements
local bossBarFrame: Frame? = nil
local bossNameLabel: TextLabel? = nil
local bossBarFill: Frame? = nil
local bossHealthLabel: TextLabel? = nil

-- Center Countdown / Banner Frame
local bannerFrame: Frame? = nil
local bannerTitle: TextLabel? = nil
local bannerSubtitle: TextLabel? = nil

-- Utility: Sound player
local function playSound(soundId: string, volume: number?, speed: number?)
	local snd = Instance.new("Sound")
	snd.SoundId = soundId
	snd.Volume = volume or 0.6
	snd.PlaybackSpeed = speed or 1.0
	snd.Parent = SoundService
	snd:Play()
	Debris:AddItem(snd, 3)
end

-- Floating Damage Numbers above damaged mobs
local function spawnDamageIndicator(pos: Vector3, damage: number, isCrit: boolean)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Position = pos + Vector3.new(math.random(-15, 15) * 0.1, math.random(0, 10) * 0.1, math.random(-15, 15) * 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100
	bb.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = if isCrit then string.format("CRIT! -%s", FormatNumber.format(damage)) else string.format("-%s", FormatNumber.format(damage))
	lbl.TextColor3 = if isCrit then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(255, 75, 75)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = if isCrit then 22 else 17
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.Parent = bb

	local endPos = part.Position + Vector3.new(0, 3.5, 0)
	TweenService:Create(part, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = endPos,
	}):Play()

	TweenService:Create(lbl, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	Debris:AddItem(part, 0.7)
end

-- Big Center Announcement Banner
local function showCenterAnnouncement(title: string, subtitle: string, color: Color3, duration: number?)
	if not bannerFrame or not bannerTitle or not bannerSubtitle then return end

	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSubtitle.Text = subtitle
	bannerFrame.Visible = true
	bannerFrame.BackgroundTransparency = 1
	bannerTitle.TextTransparency = 1
	bannerSubtitle.TextTransparency = 1
	bannerFrame.Position = UDim2.new(0.5, 0, 0.38, -20)

	TweenService:Create(bannerFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.38, 0),
		BackgroundTransparency = 0.15,
	}):Play()
	TweenService:Create(bannerTitle, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSubtitle, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	local stayTime = duration or 2.5
	task.delay(stayTime, function()
		if bannerFrame and bannerFrame.Visible then
			local fade = TweenService:Create(bannerFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.38, -20),
				BackgroundTransparency = 1,
			})
			TweenService:Create(bannerTitle, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerSubtitle, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			fade:Play()
			fade.Completed:Connect(function()
				bannerFrame.Visible = false
			end)
		end
	end)
end

-- Build HUD Elements
function DungeonClient.buildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DungeonTowerGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 16
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Top Center HUD Card (Stage & Enemies counter)
	hudCard = Instance.new("Frame")
	hudCard.Name = "DungeonHUDCard"
	hudCard.Size = UDim2.new(0, 340, 0, 64)
	hudCard.Position = UDim2.new(0.5, 0, 0, 16)
	hudCard.AnchorPoint = Vector2.new(0.5, 0)
	hudCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	hudCard.BackgroundTransparency = 0.12
	hudCard.BorderSizePixel = 0
	hudCard.Visible = false
	hudCard.Parent = screenGui

	local hcCorner = Instance.new("UICorner")
	hcCorner.CornerRadius = UDim.new(0, 12)
	hcCorner.Parent = hudCard

	local hcStroke = Instance.new("UIStroke")
	hcStroke.Color = Color3.fromRGB(180, 60, 255)
	hcStroke.Thickness = 2
	hcStroke.Parent = hudCard

	stageTitleLabel = Instance.new("TextLabel")
	stageTitleLabel.Name = "StageTitle"
	stageTitleLabel.Size = UDim2.new(1, 0, 0, 26)
	stageTitleLabel.Position = UDim2.new(0, 0, 0, 8)
	stageTitleLabel.BackgroundTransparency = 1
	stageTitleLabel.Text = "🏰 DUNGEON TOWER • STAGE 1 / 5"
	stageTitleLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	stageTitleLabel.Font = Enum.Font.FredokaOne
	stageTitleLabel.TextSize = 16
	stageTitleLabel.Parent = hudCard

	mobsLeftLabel = Instance.new("TextLabel")
	mobsLeftLabel.Name = "MobsLeft"
	mobsLeftLabel.Size = UDim2.new(1, 0, 0, 20)
	mobsLeftLabel.Position = UDim2.new(0, 0, 0, 36)
	mobsLeftLabel.BackgroundTransparency = 1
	mobsLeftLabel.Text = "💀 Enemies Remaining: 3"
	mobsLeftLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	mobsLeftLabel.Font = Enum.Font.FredokaOne
	mobsLeftLabel.TextSize = 13
	mobsLeftLabel.Parent = hudCard

	-- Top Right Exit Button
	exitButton = Instance.new("TextButton")
	exitButton.Name = "ExitDungeonBtn"
	exitButton.Size = UDim2.new(0, 130, 0, 36)
	exitButton.Position = UDim2.new(1, -145, 0, 18)
	exitButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	exitButton.BorderSizePixel = 0
	exitButton.Text = "🚪 LEAVE TOWER"
	exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitButton.Font = Enum.Font.FredokaOne
	exitButton.TextSize = 12
	exitButton.Visible = false
	exitButton.Parent = screenGui

	local ebCorner = Instance.new("UICorner")
	ebCorner.CornerRadius = UDim.new(0, 8)
	ebCorner.Parent = exitButton

	local ebStroke = Instance.new("UIStroke")
	ebStroke.Color = Color3.fromRGB(0, 0, 0)
	ebStroke.Thickness = 1.6
	ebStroke.Parent = exitButton

	exitButton.MouseButton1Click:Connect(function()
		local leaveFn = Remotes.getFunction("LeaveDungeon")
		leaveFn:InvokeServer()
	end)

	-- Boss Health Bar (Stage 5)
	bossBarFrame = Instance.new("Frame")
	bossBarFrame.Name = "BossBarFrame"
	bossBarFrame.Size = UDim2.new(0, 480, 0, 52)
	bossBarFrame.Position = UDim2.new(0.5, 0, 0, 86)
	bossBarFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossBarFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	bossBarFrame.BorderSizePixel = 0
	bossBarFrame.Visible = false
	bossBarFrame.Parent = screenGui

	local bbCorner = Instance.new("UICorner")
	bbCorner.CornerRadius = UDim.new(0, 10)
	bbCorner.Parent = bossBarFrame

	local bbStroke = Instance.new("UIStroke")
	bbStroke.Color = Color3.fromRGB(255, 80, 10)
	bbStroke.Thickness = 2.2
	bbStroke.Parent = bossBarFrame

	bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Name = "BossName"
	bossNameLabel.Size = UDim2.new(1, -20, 0, 20)
	bossNameLabel.Position = UDim2.new(0, 10, 0, 5)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.Text = "🔥 INFERNAL MAGMA GOLEM • STAGE 5"
	bossNameLabel.TextColor3 = Color3.fromRGB(255, 140, 20)
	bossNameLabel.Font = Enum.Font.FredokaOne
	bossNameLabel.TextSize = 14
	bossNameLabel.Parent = bossBarFrame

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 16)
	barBg.Position = UDim2.new(0, 10, 0, 28)
	barBg.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	barBg.BorderSizePixel = 0
	barBg.Parent = bossBarFrame

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 5)
	bgCorner.Parent = barBg

	bossBarFill = Instance.new("Frame")
	bossBarFill.Size = UDim2.new(1, 0, 1, 0)
	bossBarFill.BackgroundColor3 = Color3.fromRGB(255, 60, 10)
	bossBarFill.BorderSizePixel = 0
	bossBarFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = bossBarFill

	bossHealthLabel = Instance.new("TextLabel")
	bossHealthLabel.Size = UDim2.new(1, 0, 1, 0)
	bossHealthLabel.BackgroundTransparency = 1
	bossHealthLabel.Text = "35,000 / 35,000 (100%)"
	bossHealthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bossHealthLabel.Font = Enum.Font.FredokaOne
	bossHealthLabel.TextSize = 11
	bossHealthLabel.Parent = barBg

	-- Center Announcement Banner Frame
	bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "CenterBanner"
	bannerFrame.Size = UDim2.new(0, 480, 0, 96)
	bannerFrame.Position = UDim2.new(0.5, 0, 0.38, 0)
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	bannerFrame.BorderSizePixel = 0
	bannerFrame.Visible = false
	bannerFrame.Parent = screenGui

	local bnfCorner = Instance.new("UICorner")
	bnfCorner.CornerRadius = UDim.new(0, 14)
	bnfCorner.Parent = bannerFrame

	local bnfStroke = Instance.new("UIStroke")
	bnfStroke.Color = Color3.fromRGB(255, 215, 60)
	bnfStroke.Thickness = 2.4
	bnfStroke.Parent = bannerFrame

	bannerTitle = Instance.new("TextLabel")
	bannerTitle.Size = UDim2.new(1, 0, 0, 44)
	bannerTitle.Position = UDim2.new(0, 0, 0, 10)
	bannerTitle.BackgroundTransparency = 1
	bannerTitle.Text = "STAGE 1"
	bannerTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
	bannerTitle.Font = Enum.Font.FredokaOne
	bannerTitle.TextSize = 28
	bannerTitle.Parent = bannerFrame

	bannerSubtitle = Instance.new("TextLabel")
	bannerSubtitle.Size = UDim2.new(1, 0, 0, 28)
	bannerSubtitle.Position = UDim2.new(0, 0, 0, 54)
	bannerSubtitle.BackgroundTransparency = 1
	bannerSubtitle.Text = "Prepare for battle!"
	bannerSubtitle.TextColor3 = Color3.fromRGB(220, 225, 240)
	bannerSubtitle.Font = Enum.Font.FredokaOne
	bannerSubtitle.TextSize = 16
	bannerSubtitle.Parent = bannerFrame
end

-- Connect Pickaxe Click Target Search in Dungeon
local function setupDungeonPickaxeHitting()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not inDungeon then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then return end

		-- Check distance to all active mobs
		local mobsFolder = workspace:FindFirstChild("DungeonTowerArena") and workspace.DungeonTowerArena:FindFirstChild("ActiveDungeonMobs")
		if not mobsFolder then return end

		local closestMob: Model? = nil
		local closestDist = 12

		for _, mob in ipairs(mobsFolder:GetChildren()) do
			if mob:IsA("Model") and mob:GetAttribute("IsDungeonMob") then
				local mRoot = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
				if mRoot and mRoot:IsA("BasePart") then
					local dist = (mRoot.Position - hrp.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						closestMob = mob
					end
				end
			end
		end

		if closestMob then
			local mobId = closestMob:GetAttribute("MobId")
			if mobId and typeof(mobId) == "string" then
				local dmgFn = Remotes.getFunction("DamageDungeonMob")
				task.spawn(function()
					dmgFn:InvokeServer(mobId)
				end)
			end
		end
	end)
end

-- Initialize DungeonClient
function DungeonClient.init()
	print("🏰 [DungeonClient] Initializing Client Dungeon Controller...")
	DungeonClient.buildUI()
	setupDungeonPickaxeHitting()

	-- Remote Event: DungeonStateUpdated
	local stateEvt = Remotes.getEvent("DungeonStateUpdated")
	stateEvt.OnClientEvent:Connect(function(data: any)
		if not data then return end

		if data.state == "Left" then
			inDungeon = false
			if hudCard then hudCard.Visible = false end
			if exitButton then exitButton.Visible = false end
			if bossBarFrame then bossBarFrame.Visible = false end
			return
		end

		inDungeon = true
		if hudCard then hudCard.Visible = true end
		if exitButton then exitButton.Visible = true end

		currentStage = data.stage or currentStage
		totalStages = data.totalStages or totalStages
		isBossStage = (currentStage >= 5)

		if stageTitleLabel then
			stageTitleLabel.Text = string.format("🏰 DUNGEON TOWER • STAGE %d / %d", currentStage, totalStages)
		end

		if isBossStage then
			if mobsLeftLabel then mobsLeftLabel.Text = "🔥 BOSS CLIMAX" end
			if bossBarFrame then bossBarFrame.Visible = true end
		else
			if bossBarFrame then bossBarFrame.Visible = false end
			if mobsLeftLabel and data.mobsRemaining ~= nil then
				mobsLeftLabel.Text = string.format("💀 Enemies Remaining: %d", data.mobsRemaining)
			end
		end

		if data.state == "Countdown" then
			playSound("rbxassetid://9069609268", 0.6, 1.2)
			local titleText = string.format("STAGE %d: %s", data.stage, string.upper(data.stageTitle or "WAVE"))
			showCenterAnnouncement(titleText, "Wave starting in 3 seconds...", Color3.fromRGB(255, 215, 60), 2.8)
		elseif data.state == "StageCleared" then
			playSound("rbxassetid://6026987857", 0.8, 1.1)
			local rew = data.reward
			local rewText = if rew then string.format("+$%s  •  +💎%d", FormatNumber.format(rew.cash), rew.gems) else ""
			showCenterAnnouncement(string.format("🎉 STAGE %d CLEARED!", data.stage), rewText, Color3.fromRGB(46, 204, 113), 3.2)
		elseif data.state == "Victory" then
			playSound("rbxassetid://9069609268", 1.0, 1.0)
			local rew = data.reward
			local rewText = if rew then string.format("JACKPOT: +$%s  •  +💎%d  •  📦 GOLD CRATE!", FormatNumber.format(rew.cash), rew.gems) else ""
			showCenterAnnouncement("👑 TOWER CONQUERED!", rewText, Color3.fromRGB(255, 215, 0), 6.0)
			if bossBarFrame then bossBarFrame.Visible = false end
		end
	end)

	-- Remote Event: DungeonBossUpdated
	local bossEvt = Remotes.getEvent("DungeonBossUpdated")
	bossEvt.OnClientEvent:Connect(function(bData: any)
		if not bData then return end
		if bossBarFrame then bossBarFrame.Visible = bData.isAlive end

		if bossNameLabel and bData.name then
			bossNameLabel.Text = string.format("🔥 %s • %s", bData.name, bData.title or "STAGE 5 BOSS")
		end

		if bossBarFill and bossHealthLabel and bData.maxHealth and bData.currentHealth then
			local pct = math.clamp(bData.currentHealth / math.max(1, bData.maxHealth), 0, 1)
			TweenService:Create(bossBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(pct, 0, 1, 0),
			}):Play()
			bossHealthLabel.Text = string.format("%s / %s (%d%%)", FormatNumber.format(bData.currentHealth), FormatNumber.format(bData.maxHealth), math.floor(pct * 100))
		end
	end)

	-- Remote Event: DungeonMobDamaged
	local dmgEvt = Remotes.getEvent("DungeonMobDamaged")
	dmgEvt.OnClientEvent:Connect(function(dInfo: any)
		if dInfo and dInfo.position and dInfo.damage then
			spawnDamageIndicator(dInfo.position, dInfo.damage, dInfo.isCrit or false)
		end
	end)

	print("✅ [DungeonClient] Client Dungeon Controller Online!")
end

return DungeonClient
