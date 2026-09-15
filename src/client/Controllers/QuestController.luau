--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local MiningClient = require(script.Parent.MiningClient)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QuestController = {}

-- State
local isOpen = false
local currentTab: "Board" | "Active" = "Board"
local cachedActiveQuests = {}
local cachedBoardQuests = {}
local claimableCount = 0

-- UI Elements
local screenGui: ScreenGui? = nil
local modalBackdrop: Frame? = nil
local modalFrame: Frame? = nil
local contentScroll: ScrollingFrame? = nil
local boardTabBtn: TextButton? = nil
local activeTabBtn: TextButton? = nil
local activeBadgeLabel: TextLabel? = nil
local miniTrackerCard: Frame? = nil
local miniTrackerText: TextLabel? = nil
local miniTrackerBar: Frame? = nil

-- Callbacks
local onClaimableCountChanged: ((count: number) -> ())? = nil

-- Helper: Sound generation
local function playUISound(soundType: "click" | "accept" | "claim" | "open" | "tab")
	local sound = Instance.new("Sound")
	if soundType == "accept" then
		sound.SoundId = "rbxassetid://6026987857" -- Parchment stamp / success
		sound.Volume = 0.85
		sound.PlaybackSpeed = 1.05
	elseif soundType == "claim" then
		sound.SoundId = "rbxassetid://9069609268" -- Grand victory fan-fare / reward
		sound.Volume = 1.0
		sound.PlaybackSpeed = 1.0
	elseif soundType == "open" then
		sound.SoundId = "rbxassetid://399712595" -- Scroll unroll
		sound.Volume = 0.7
		sound.PlaybackSpeed = 1.15
	elseif soundType == "tab" then
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.5
		sound.PlaybackSpeed = 1.2
	else
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.4
		sound.PlaybackSpeed = 1.1
	end
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Helper: Floating Popup Notification
local function showQuestBanner(text: string, color: Color3, icon: string?)
	if not screenGui then return end

	local banner = Instance.new("Frame")
	banner.Name = "QuestBanner"
	banner.Size = UDim2.new(0, 360, 0, 52)
	banner.Position = UDim2.new(0.5, 0, 0, 95)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	banner.BorderSizePixel = 0
	banner.ZIndex = 40
	banner.Parent = screenGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = color
	bStroke.Thickness = 2
	bStroke.Parent = banner

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(0, 42, 1, 0)
	iconLbl.Position = UDim2.new(0, 8, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = icon or "📜"
	iconLbl.TextSize = 24
	iconLbl.Font = Enum.Font.FredokaOne
	iconLbl.ZIndex = 41
	iconLbl.Parent = banner

	local textLbl = Instance.new("TextLabel")
	textLbl.Size = UDim2.new(1, -60, 1, 0)
	textLbl.Position = UDim2.new(0, 52, 0, 0)
	textLbl.BackgroundTransparency = 1
	textLbl.Text = text
	textLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLbl.Font = Enum.Font.FredokaOne
	textLbl.TextSize = 14
	textLbl.TextXAlignment = Enum.TextXAlignment.Left
	textLbl.ZIndex = 41
	textLbl.Parent = banner

	-- Pop in animation
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.BackgroundTransparency = 1
	textLbl.TextTransparency = 1
	iconLbl.TextTransparency = 1
	bStroke.Transparency = 1

	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 95),
		BackgroundTransparency = 0.05,
	}):Play()
	TweenService:Create(textLbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(iconLbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(bStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()

	task.delay(2.8, function()
		if banner and banner.Parent then
			local fade = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 70),
				BackgroundTransparency = 1,
			})
			TweenService:Create(textLbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(iconLbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(bStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			fade:Play()
			fade.Completed:Connect(function()
				banner:Destroy()
			end)
		end
	end)
end

-- Helper: Sparkle particle explosion for claim
local function emitClaimSparks(parentGui: GuiObject)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 10, 0, 10)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.ZIndex = 50
	container.Parent = parentGui

	local colors = {
		Color3.fromRGB(255, 215, 0),
		Color3.fromRGB(255, 120, 40),
		Color3.fromRGB(0, 240, 255),
		Color3.fromRGB(160, 60, 255),
		Color3.fromRGB(46, 204, 113),
	}

	for i = 1, 24 do
		local spark = Instance.new("Frame")
		spark.Size = UDim2.new(0, math.random(6, 12), 0, math.random(6, 12))
		spark.Position = UDim2.new(0.5, 0, 0.5, 0)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = colors[math.random(1, #colors)]
		spark.BorderSizePixel = 0
		spark.ZIndex = 51
		spark.Parent = container

		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(1, 0)
		sc.Parent = spark

		local angle = math.rad(math.random(0, 360))
		local dist = math.random(40, 160)
		local endPos = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist)

		TweenService:Create(spark, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = endPos,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 2, 0, 2),
		}):Play()
	end

	task.delay(0.7, function()
		container:Destroy()
	end)
end

-- Refresh UI data from server
function QuestController.fetchData()
	local getFn = Remotes.getFunction("GetQuestData")
	local ok, payload = pcall(function()
		return getFn:InvokeServer()
	end)

	if ok and payload then
		cachedActiveQuests = payload.activeQuests or {}
		cachedBoardQuests = payload.boardQuests or {}

		claimableCount = 0
		for _, q in ipairs(cachedActiveQuests) do
			if q.completed and not q.claimed then
				claimableCount += 1
			end
		end

		if activeBadgeLabel then
			activeBadgeLabel.Visible = claimableCount > 0
			activeBadgeLabel.Text = tostring(claimableCount)
		end

		if onClaimableCountChanged then
			onClaimableCountChanged(claimableCount)
		end

		QuestController.updateMiniTracker()
		if isOpen then
			QuestController.renderContent()
		end
	end
end

-- Update floating HUD mini tracker
function QuestController.updateMiniTracker()
	if not miniTrackerCard or not miniTrackerText or not miniTrackerBar then return end

	local primaryQuest = nil
	for _, q in ipairs(cachedActiveQuests) do
		if not q.claimed then
			primaryQuest = q
			break
		end
	end

	if not primaryQuest then
		miniTrackerCard.Visible = false
		return
	end

	miniTrackerCard.Visible = true
	local prog = primaryQuest.progress or 0
	local target = primaryQuest.targetCount or 1
	local pct = math.clamp(prog / math.max(1, target), 0, 1)

	if primaryQuest.completed then
		miniTrackerText.Text = string.format("%s %s (READY TO CLAIM!)", primaryQuest.icon or "📜", primaryQuest.title)
		miniTrackerText.TextColor3 = Color3.fromRGB(255, 220, 60)
		miniTrackerBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	else
		miniTrackerText.Text = string.format("%s %s: %d/%d", primaryQuest.icon or "📜", primaryQuest.title, prog, target)
		miniTrackerText.TextColor3 = Color3.fromRGB(240, 240, 240)
		miniTrackerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	end

	TweenService:Create(miniTrackerBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0),
	}):Play()
end

-- Render quest cards inside the modal scroll frame
function QuestController.renderContent()
	if not contentScroll then return end
	contentScroll:ClearAllChildren()

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = contentScroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = contentScroll

	local items = if currentTab == "Board" then cachedBoardQuests else cachedActiveQuests

	if #items == 0 then
		local emptyFrame = Instance.new("Frame")
		emptyFrame.Size = UDim2.new(1, 0, 0, 180)
		emptyFrame.BackgroundTransparency = 1
		emptyFrame.Parent = contentScroll

		local emptyIcon = Instance.new("TextLabel")
		emptyIcon.Size = UDim2.new(1, 0, 0, 60)
		emptyIcon.Position = UDim2.new(0, 0, 0, 30)
		emptyIcon.BackgroundTransparency = 1
		emptyIcon.Text = if currentTab == "Board" then "🎉" else "📜"
		emptyIcon.TextSize = 44
		emptyIcon.Font = Enum.Font.FredokaOne
		emptyIcon.Parent = emptyFrame

		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Size = UDim2.new(1, 0, 0, 32)
		emptyLbl.Position = UDim2.new(0, 0, 0, 95)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = if currentTab == "Board"
			then "All available bounties have been accepted! Check your Active Journal."
			else "No active quests! Visit the Quest Board tab to accept a new bounty."
		emptyLbl.TextColor3 = Color3.fromRGB(180, 185, 200)
		emptyLbl.Font = Enum.Font.FredokaOne
		emptyLbl.TextSize = 16
		emptyLbl.Parent = emptyFrame
		return
	end

	for idx, q in ipairs(items) do
		local card = Instance.new("Frame")
		card.Name = "QuestCard_" .. q.id
		card.Size = UDim2.new(1, -6, 0, 106)
		card.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
		card.BorderSizePixel = 0
		card.LayoutOrder = idx
		card.Parent = contentScroll

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 12)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = if q.completed and not q.claimed
			then Color3.fromRGB(255, 215, 60)
			elseif currentTab == "Board" then Color3.fromRGB(60, 70, 95)
			else Color3.fromRGB(45, 55, 75)
		cardStroke.Thickness = if q.completed and not q.claimed then 2.2 else 1.2
		cardStroke.Parent = card

		-- Quest Icon container
		local iconBg = Instance.new("Frame")
		iconBg.Size = UDim2.new(0, 68, 0, 68)
		iconBg.Position = UDim2.new(0, 14, 0.5, 0)
		iconBg.AnchorPoint = Vector2.new(0, 0.5)
		iconBg.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
		iconBg.BorderSizePixel = 0
		iconBg.Parent = card

		local icCorner = Instance.new("UICorner")
		icCorner.CornerRadius = UDim.new(0, 10)
		icCorner.Parent = iconBg

		local icStroke = Instance.new("UIStroke")
		icStroke.Color = Color3.fromRGB(255, 255, 255)
		icStroke.Transparency = 0.85
		icStroke.Thickness = 1
		icStroke.Parent = iconBg

		local iconText = Instance.new("TextLabel")
		iconText.Size = UDim2.new(1, 0, 1, 0)
		iconText.BackgroundTransparency = 1
		iconText.Text = q.icon or "⚔️"
		iconText.TextSize = 34
		iconText.Font = Enum.Font.FredokaOne
		iconText.Parent = iconBg

		-- Category & Badge Label
		local badgePill = Instance.new("Frame")
		badgePill.Size = UDim2.new(0, 80, 0, 20)
		badgePill.Position = UDim2.new(0, 94, 0, 14)
		badgePill.BackgroundColor3 = if q.category == "Main"
			then Color3.fromRGB(41, 128, 185)
			elseif q.category == "Daily" then Color3.fromRGB(230, 126, 34)
			else Color3.fromRGB(142, 68, 173)
		badgePill.BorderSizePixel = 0
		badgePill.Parent = card

		local bpCorner = Instance.new("UICorner")
		bpCorner.CornerRadius = UDim.new(0, 5)
		bpCorner.Parent = badgePill

		local bpText = Instance.new("TextLabel")
		bpText.Size = UDim2.new(1, 0, 1, 0)
		bpText.BackgroundTransparency = 1
		bpText.Text = q.badge or (string.upper(q.category or "QUEST"))
		bpText.TextColor3 = Color3.fromRGB(255, 255, 255)
		bpText.Font = Enum.Font.FredokaOne
		bpText.TextSize = 11
		bpText.Parent = badgePill

		-- Quest Title
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -300, 0, 22)
		titleLbl.Position = UDim2.new(0, 182, 0, 13)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = q.title or "Adventure Quest"
		titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLbl.Font = Enum.Font.FredokaOne
		titleLbl.TextSize = 17
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = card

		-- Quest Description / Objective
		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -300, 0, 18)
		descLbl.Position = UDim2.new(0, 94, 0, 39)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = q.description or ""
		descLbl.TextColor3 = Color3.fromRGB(175, 185, 205)
		descLbl.Font = Enum.Font.FredokaOne
		descLbl.TextSize = 13
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.Parent = card

		-- Rewards Row (Cash, Gems, Crates, Mastery)
		local rewardsFrame = Instance.new("Frame")
		rewardsFrame.Size = UDim2.new(1, -300, 0, 24)
		rewardsFrame.Position = UDim2.new(0, 94, 0, 66)
		rewardsFrame.BackgroundTransparency = 1
		rewardsFrame.Parent = card

		local rwList = Instance.new("UIListLayout")
		rwList.FillDirection = Enum.FillDirection.Horizontal
		rwList.Padding = UDim.new(0, 8)
		rwList.SortOrder = Enum.SortOrder.LayoutOrder
		rwList.Parent = rewardsFrame

		local function addRewardPill(text: string, color: Color3)
			local pill = Instance.new("Frame")
			pill.Size = UDim2.new(0, 0, 1, 0)
			pill.AutomaticSize = Enum.AutomaticSize.X
			pill.BackgroundColor3 = color
			pill.BackgroundTransparency = 0.2
			pill.BorderSizePixel = 0
			pill.Parent = rewardsFrame

			local pCorner = Instance.new("UICorner")
			pCorner.CornerRadius = UDim.new(0, 6)
			pCorner.Parent = pill

			local pPad = Instance.new("UIPadding")
			pPad.PaddingLeft = UDim.new(0, 8)
			pPad.PaddingRight = UDim.new(0, 8)
			pPad.Parent = pill

			local pText = Instance.new("TextLabel")
			pText.Size = UDim2.new(0, 0, 1, 0)
			pText.AutomaticSize = Enum.AutomaticSize.X
			pText.BackgroundTransparency = 1
			pText.Text = text
			pText.TextColor3 = Color3.fromRGB(255, 255, 255)
			pText.Font = Enum.Font.FredokaOne
			pText.TextSize = 12
			pText.Parent = pill
		end

		if q.rewards then
			if q.rewards.Cash and q.rewards.Cash > 0 then
				addRewardPill(string.format("💰 +$%s", tostring(q.rewards.Cash):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")), Color3.fromRGB(46, 160, 67))
			end
			if q.rewards.Gems and q.rewards.Gems > 0 then
				addRewardPill(string.format("💎 +%d", q.rewards.Gems), Color3.fromRGB(30, 144, 255))
			end
			if q.rewards.Crates then
				for crateId, count in pairs(q.rewards.Crates) do
					addRewardPill(string.format("📦 +%d Crate", count), Color3.fromRGB(155, 89, 182))
				end
			end
			if q.rewards.MasteryXP then
				addRewardPill(string.format("📜 +%d XP", q.rewards.MasteryXP.amount), Color3.fromRGB(230, 126, 34))
			end
		end

		-- RIGHT ACTION SECTION (Accept button vs Progress bar & Claim button)
		local actionFrame = Instance.new("Frame")
		actionFrame.Size = UDim2.new(0, 184, 1, -20)
		actionFrame.Position = UDim2.new(1, -196, 0, 10)
		actionFrame.BackgroundTransparency = 1
		actionFrame.Parent = card

		if currentTab == "Board" then
			-- ACCEPT QUEST 3D STUD BUTTON
			local acceptBtn = Instance.new("TextButton")
			acceptBtn.Name = "AcceptBtn"
			acceptBtn.Size = UDim2.new(1, 0, 0, 48)
			acceptBtn.Position = UDim2.new(0, 0, 0.5, 0)
			acceptBtn.AnchorPoint = Vector2.new(0, 0.5)
			acceptBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
			acceptBtn.BorderSizePixel = 0
			acceptBtn.Text = "➕ ACCEPT QUEST"
			acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			acceptBtn.Font = Enum.Font.FredokaOne
			acceptBtn.TextSize = 14
			acceptBtn.Parent = actionFrame

			local abCorner = Instance.new("UICorner")
			abCorner.CornerRadius = UDim.new(0, 10)
			abCorner.Parent = acceptBtn

			local abStroke = Instance.new("UIStroke")
			abStroke.Color = Color3.fromRGB(0, 0, 0)
			abStroke.Thickness = 2
			abStroke.Parent = acceptBtn

			-- Bottom 3D stud lip
			local lip = Instance.new("Frame")
			lip.Size = UDim2.new(1, 0, 0, 5)
			lip.Position = UDim2.new(0, 0, 1, -5)
			lip.BackgroundColor3 = Color3.fromRGB(30, 130, 70)
			lip.BorderSizePixel = 0
			lip.ZIndex = acceptBtn.ZIndex + 1
			lip.Parent = acceptBtn

			local lipCorner = Instance.new("UICorner")
			lipCorner.CornerRadius = UDim.new(0, 5)
			lipCorner.Parent = lip

			acceptBtn.MouseButton1Click:Connect(function()
				playUISound("click")
				acceptBtn.Text = "⏳ ACCEPTING..."
				acceptBtn.Active = false

				local acceptFn = Remotes.getFunction("AcceptQuest")
				local ok, success, msg = pcall(function()
					return acceptFn:InvokeServer(q.id)
				end)

				if ok and success then
					playUISound("accept")
					showQuestBanner(string.format("Accepted: %s!", q.title), Color3.fromRGB(46, 204, 113), q.icon)
					QuestController.fetchData()
					-- Auto-switch to Active tab to see progress!
					QuestController.switchTab("Active")
				else
					acceptBtn.Text = "❌ FAILED"
					task.wait(1.2)
					acceptBtn.Text = "➕ ACCEPT QUEST"
					acceptBtn.Active = true
				end
			end)
		else
			-- ACTIVE JOURNAL: Progress Bar & Claim Button
			local prog = q.progress or 0
			local target = q.targetCount or 1
			local isDone = q.completed or false
			local pct = math.clamp(prog / math.max(1, target), 0, 1)

			if isDone then
				-- CLAIM REWARD 3D STUD BUTTON (Sparkling Gold!)
				local claimBtn = Instance.new("TextButton")
				claimBtn.Name = "ClaimBtn"
				claimBtn.Size = UDim2.new(1, 0, 0, 48)
				claimBtn.Position = UDim2.new(0, 0, 0.5, 0)
				claimBtn.AnchorPoint = Vector2.new(0, 0.5)
				claimBtn.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
				claimBtn.BorderSizePixel = 0
				claimBtn.Text = "🎉 CLAIM REWARD!"
				claimBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
				claimBtn.Font = Enum.Font.FredokaOne
				claimBtn.TextSize = 14
				claimBtn.Parent = actionFrame

				local cbCorner = Instance.new("UICorner")
				cbCorner.CornerRadius = UDim.new(0, 10)
				cbCorner.Parent = claimBtn

				local cbStroke = Instance.new("UIStroke")
				cbStroke.Color = Color3.fromRGB(0, 0, 0)
				cbStroke.Thickness = 2
				cbStroke.Parent = claimBtn

				-- Bottom 3D lip
				local cbLip = Instance.new("Frame")
				cbLip.Size = UDim2.new(1, 0, 0, 5)
				cbLip.Position = UDim2.new(0, 0, 1, -5)
				cbLip.BackgroundColor3 = Color3.fromRGB(180, 140, 10)
				cbLip.BorderSizePixel = 0
				cbLip.Parent = claimBtn

				-- Pulsate animation
				task.spawn(function()
					while claimBtn and claimBtn.Parent do
						TweenService:Create(claimBtn, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							BackgroundColor3 = Color3.fromRGB(255, 220, 60),
						}):Play()
						task.wait(0.5)
						if not claimBtn or not claimBtn.Parent then break end
						TweenService:Create(claimBtn, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							BackgroundColor3 = Color3.fromRGB(241, 196, 15),
						}):Play()
						task.wait(0.5)
					end
				end)

				claimBtn.MouseButton1Click:Connect(function()
					playUISound("claim")
					emitClaimSparks(card)
					claimBtn.Text = "✨ CLAIMING..."
					claimBtn.Active = false

					local claimFn = Remotes.getFunction("ClaimQuestReward")
					local ok, success, msg, rew = pcall(function()
						return claimFn:InvokeServer(q.id)
					end)

					if ok and success then
						showQuestBanner(string.format("🎉 Claimed: %s!", q.title), Color3.fromRGB(255, 215, 60), "⭐")
						QuestController.fetchData()
					else
						claimBtn.Text = "❌ FAILED"
						task.wait(1)
						claimBtn.Text = "🎉 CLAIM REWARD!"
						claimBtn.Active = true
					end
				end)
			else
				-- Progress Bar & In Progress Tag
				local progContainer = Instance.new("Frame")
				progContainer.Size = UDim2.new(1, 0, 0, 22)
				progContainer.Position = UDim2.new(0, 0, 0, 24)
				progContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
				progContainer.BorderSizePixel = 0
				progContainer.Parent = actionFrame

				local prgCorner = Instance.new("UICorner")
				prgCorner.CornerRadius = UDim.new(0, 6)
				prgCorner.Parent = progContainer

				local prgFill = Instance.new("Frame")
				prgFill.Size = UDim2.new(pct, 0, 1, 0)
				prgFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
				prgFill.BorderSizePixel = 0
				prgFill.Parent = progContainer

				local pfCorner = Instance.new("UICorner")
				pfCorner.CornerRadius = UDim.new(0, 6)
				pfCorner.Parent = prgFill

				local prgText = Instance.new("TextLabel")
				prgText.Size = UDim2.new(1, 0, 1, 0)
				prgText.BackgroundTransparency = 1
				prgText.Text = string.format("%d / %d (%d%%)", prog, target, math.floor(pct * 100))
				prgText.TextColor3 = Color3.fromRGB(255, 255, 255)
				prgText.Font = Enum.Font.FredokaOne
				prgText.TextSize = 12
				prgText.Parent = progContainer

				local statusLbl = Instance.new("TextLabel")
				statusLbl.Size = UDim2.new(1, 0, 0, 18)
				statusLbl.Position = UDim2.new(0, 0, 0, 52)
				statusLbl.BackgroundTransparency = 1
				statusLbl.Text = "⏳ IN PROGRESS"
				statusLbl.TextColor3 = Color3.fromRGB(46, 204, 113)
				statusLbl.Font = Enum.Font.FredokaOne
				statusLbl.TextSize = 12
				statusLbl.Parent = actionFrame
			end
		end
	end
end

-- Switch between Board and Active tabs
function QuestController.switchTab(tab: "Board" | "Active")
	currentTab = tab
	playUISound("tab")

	if boardTabBtn and activeTabBtn then
		if tab == "Board" then
			boardTabBtn.BackgroundColor3 = Color3.fromRGB(243, 156, 18)
			boardTabBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
			activeTabBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
			activeTabBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
		else
			activeTabBtn.BackgroundColor3 = Color3.fromRGB(243, 156, 18)
			activeTabBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
			boardTabBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
			boardTabBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
		end
	end

	QuestController.renderContent()
end

-- Open Quest Board / Journal Modal
function QuestController.openQuestModal(defaultTab: ("Board" | "Active")?)
	if isOpen then return end
	isOpen = true
	playUISound("open")

	if defaultTab then
		currentTab = defaultTab
	end

	QuestController.fetchData()

	if modalBackdrop and modalFrame then
		modalBackdrop.Visible = true
		modalFrame.Position = UDim2.new(0.5, 0, 0.5, 30)
		modalFrame.BackgroundTransparency = 0.5
		modalFrame.Visible = true

		TweenService:Create(modalBackdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(modalFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0,
		}):Play()

		QuestController.switchTab(currentTab)
	end
end

-- Close Quest Modal
function QuestController.closeQuestModal()
	if not isOpen then return end
	isOpen = false
	playUISound("click")

	if modalBackdrop and modalFrame then
		local t1 = TweenService:Create(modalFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.5, 30),
			BackgroundTransparency = 1,
		})
		local t2 = TweenService:Create(modalBackdrop, TweenInfo.new(0.2), { BackgroundTransparency = 1 })

		t1:Play()
		t2:Play()
		t1.Completed:Connect(function()
			if not isOpen then
				modalBackdrop.Visible = false
				modalFrame.Visible = false
			end
		end)
	end
end

-- Toggle Quest Modal
function QuestController.toggleQuestModal()
	if isOpen then
		QuestController.closeQuestModal()
	else
		QuestController.openQuestModal()
	end
end

-- Build the Full UI
function QuestController.buildUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestSystemGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	-- Dark Blur Backdrop
	modalBackdrop = Instance.new("Frame")
	modalBackdrop.Name = "ModalBackdrop"
	modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalBackdrop.BackgroundTransparency = 1
	modalBackdrop.Visible = false
	modalBackdrop.Parent = screenGui

	modalBackdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			QuestController.closeQuestModal()
		end
	end)

	-- Main Modal Frame (780 x 560)
	modalFrame = Instance.new("Frame")
	modalFrame.Name = "QuestModalFrame"
	modalFrame.Size = UDim2.new(0, 780, 0, 560)
	modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	modalFrame.BorderSizePixel = 0
	modalFrame.Visible = false
	modalFrame.Parent = screenGui

	-- Absorb clicks so clicking inside does not dismiss backdrop
	modalFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- absorbed
		end
	end)

	local mfCorner = Instance.new("UICorner")
	mfCorner.CornerRadius = UDim.new(0, 16)
	mfCorner.Parent = modalFrame

	local mfStroke = Instance.new("UIStroke")
	mfStroke.Color = Color3.fromRGB(255, 215, 60)
	mfStroke.Thickness = 2.4
	mfStroke.Parent = modalFrame

	-- Top Header Bar
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 68)
	headerBar.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	headerBar.BorderSizePixel = 0
	headerBar.Parent = modalFrame

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(0, 16)
	hbCorner.Parent = headerBar

	-- Flat bottom patch for header
	local hbPatch = Instance.new("Frame")
	hbPatch.Size = UDim2.new(1, 0, 0, 16)
	hbPatch.Position = UDim2.new(0, 0, 1, -16)
	hbPatch.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	hbPatch.BorderSizePixel = 0
	hbPatch.Parent = headerBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -80, 0, 30)
	titleLabel.Position = UDim2.new(0, 20, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "📜 ADVENTURE QUEST BOARD & JOURNAL"
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 21
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = headerBar

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -80, 0, 20)
	subLabel.Position = UDim2.new(0, 20, 0, 40)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Accept bounties, complete town missions, and claim epic rewards!"
	subLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.TextSize = 13
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Parent = headerBar

	-- Close Button (✕)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 38, 0, 38)
	closeBtn.Position = UDim2.new(1, -50, 0, 15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 18
	closeBtn.Parent = headerBar

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = closeBtn

	local cbStroke = Instance.new("UIStroke")
	cbStroke.Color = Color3.fromRGB(0, 0, 0)
	cbStroke.Thickness = 1.8
	cbStroke.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		QuestController.closeQuestModal()
	end)

	-- Navigation Tabs Bar
	local tabsBar = Instance.new("Frame")
	tabsBar.Name = "TabsBar"
	tabsBar.Size = UDim2.new(1, -40, 0, 44)
	tabsBar.Position = UDim2.new(0, 20, 0, 78)
	tabsBar.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	tabsBar.BorderSizePixel = 0
	tabsBar.Parent = modalFrame

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 10)
	tbCorner.Parent = tabsBar

	-- Tab 1: Quest Board
	boardTabBtn = Instance.new("TextButton")
	boardTabBtn.Name = "BoardTab"
	boardTabBtn.Size = UDim2.new(0.5, -4, 1, -6)
	boardTabBtn.Position = UDim2.new(0, 3, 0, 3)
	boardTabBtn.BackgroundColor3 = Color3.fromRGB(243, 156, 18)
	boardTabBtn.BorderSizePixel = 0
	boardTabBtn.Text = "📌 QUEST BOARD (ACCEPT BOUNTIES)"
	boardTabBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
	boardTabBtn.Font = Enum.Font.FredokaOne
	boardTabBtn.TextSize = 14
	boardTabBtn.Parent = tabsBar

	local btbCorner = Instance.new("UICorner")
	btbCorner.CornerRadius = UDim.new(0, 8)
	btbCorner.Parent = boardTabBtn

	boardTabBtn.MouseButton1Click:Connect(function()
		QuestController.switchTab("Board")
	end)

	-- Tab 2: Active Journal
	activeTabBtn = Instance.new("TextButton")
	activeTabBtn.Name = "ActiveTab"
	activeTabBtn.Size = UDim2.new(0.5, -4, 1, -6)
	activeTabBtn.Position = UDim2.new(0.5, 1, 0, 3)
	activeTabBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
	activeTabBtn.BorderSizePixel = 0
	activeTabBtn.Text = "📋 ACTIVE JOURNAL (TRACK & CLAIM)"
	activeTabBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
	activeTabBtn.Font = Enum.Font.FredokaOne
	activeTabBtn.TextSize = 14
	activeTabBtn.Parent = tabsBar

	local atbCorner = Instance.new("UICorner")
	atbCorner.CornerRadius = UDim.new(0, 8)
	atbCorner.Parent = activeTabBtn

	-- Active Claimable Notification Badge on tab
	activeBadgeLabel = Instance.new("TextLabel")
	activeBadgeLabel.Name = "ActiveBadge"
	activeBadgeLabel.Size = UDim2.new(0, 22, 0, 22)
	activeBadgeLabel.Position = UDim2.new(1, -26, 0, 8)
	activeBadgeLabel.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	activeBadgeLabel.BorderSizePixel = 0
	activeBadgeLabel.Text = "1"
	activeBadgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	activeBadgeLabel.Font = Enum.Font.FredokaOne
	activeBadgeLabel.TextSize = 12
	activeBadgeLabel.Visible = false
	activeBadgeLabel.Parent = activeTabBtn

	local abCorner = Instance.new("UICorner")
	abCorner.CornerRadius = UDim.new(1, 0)
	abCorner.Parent = activeBadgeLabel

	local abStroke = Instance.new("UIStroke")
	abStroke.Color = Color3.fromRGB(0, 0, 0)
	abStroke.Thickness = 1.5
	abStroke.Parent = activeBadgeLabel

	activeTabBtn.MouseButton1Click:Connect(function()
		QuestController.switchTab("Active")
	end)

	-- Content Scrolling Frame
	contentScroll = Instance.new("ScrollingFrame")
	contentScroll.Name = "ContentScroll"
	contentScroll.Size = UDim2.new(1, -40, 1, -140)
	contentScroll.Position = UDim2.new(0, 20, 0, 130)
	contentScroll.BackgroundTransparency = 1
	contentScroll.BorderSizePixel = 0
	contentScroll.ScrollBarThickness = 6
	contentScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 60)
	contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentScroll.Parent = modalFrame

	-- Build HUD Mini-Tracker (Top Right below header)
	miniTrackerCard = Instance.new("Frame")
	miniTrackerCard.Name = "HUDQuestTracker"
	miniTrackerCard.Size = UDim2.new(0, 270, 0, 48)
	miniTrackerCard.Position = UDim2.new(1, -284, 0, 72)
	miniTrackerCard.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	miniTrackerCard.BackgroundTransparency = 0.15
	miniTrackerCard.BorderSizePixel = 0
	miniTrackerCard.Visible = false
	miniTrackerCard.Parent = screenGui

	local mtCorner = Instance.new("UICorner")
	mtCorner.CornerRadius = UDim.new(0, 10)
	mtCorner.Parent = miniTrackerCard

	local mtStroke = Instance.new("UIStroke")
	mtStroke.Color = Color3.fromRGB(255, 215, 60)
	mtStroke.Thickness = 1.4
	mtStroke.Parent = miniTrackerCard

	miniTrackerText = Instance.new("TextLabel")
	miniTrackerText.Size = UDim2.new(1, -16, 0, 22)
	miniTrackerText.Position = UDim2.new(0, 8, 0, 4)
	miniTrackerText.BackgroundTransparency = 1
	miniTrackerText.Text = "📜 Quest Progress"
	miniTrackerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	miniTrackerText.Font = Enum.Font.FredokaOne
	miniTrackerText.TextSize = 12
	miniTrackerText.TextXAlignment = Enum.TextXAlignment.Left
	miniTrackerText.Parent = miniTrackerCard

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -16, 0, 10)
	barBg.Position = UDim2.new(0, 8, 0, 28)
	barBg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	barBg.BorderSizePixel = 0
	barBg.Parent = miniTrackerCard

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 5)
	bCorner.Parent = barBg

	miniTrackerBar = Instance.new("Frame")
	miniTrackerBar.Size = UDim2.new(0, 0, 1, 0)
	miniTrackerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	miniTrackerBar.BorderSizePixel = 0
	miniTrackerBar.Parent = barBg

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 5)
	fCorner.Parent = miniTrackerBar

	-- Clicking mini tracker opens quest modal
	local trackerBtn = Instance.new("TextButton")
	trackerBtn.Size = UDim2.new(1, 0, 1, 0)
	trackerBtn.BackgroundTransparency = 1
	trackerBtn.Text = ""
	trackerBtn.Parent = miniTrackerCard

	trackerBtn.MouseButton1Click:Connect(function()
		QuestController.openQuestModal("Active")
	end)
end

-- Connect Tool handling (Holster pickaxe when Quest Scroll is equipped)
local function setupToolListeners(char: Model)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and (child.Name:find("Quest") or child:GetAttribute("IsQuestTool")) then
			-- Holster pickaxe so tools do not overlap in hand
			MiningClient.setPickaxeVisible(false)

			-- Listen to client activation
			child.Activated:Connect(function()
				QuestController.openQuestModal()
			end)
		end
	end)

	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and (child.Name:find("Quest") or child:GetAttribute("IsQuestTool")) then
			-- Restore pickaxe
			MiningClient.setPickaxeVisible(true)
		end
	end)

	-- Check if tool is already in hand
	for _, child in char:GetChildren() do
		if child:IsA("Tool") and (child.Name:find("Quest") or child:GetAttribute("IsQuestTool")) then
			MiningClient.setPickaxeVisible(false)
			child.Activated:Connect(function()
				QuestController.openQuestModal()
			end)
		end
	end
end

-- Register badge update callback for UIController
function QuestController.onBadgeChanged(cb: (count: number) -> ())
	onClaimableCountChanged = cb
	if cb then
		cb(claimableCount)
	end
end

-- Initialize QuestController
function QuestController.init()
	print("📜 [QuestController] Initializing Client Quest Controller...")

	QuestController.buildUI()

	-- Remote Event: OpenQuestModal (from Quest Board or Tool)
	local openEvent = Remotes.getEvent("OpenQuestModal")
	openEvent.OnClientEvent:Connect(function(tabName: any)
		local defaultTab = if tabName == "Active" then "Active" else "Board"
		QuestController.openQuestModal(defaultTab)
	end)

	-- Remote Event: QuestProgressUpdated
	local syncEvt = Remotes.getEvent("QuestProgressUpdated")
	syncEvt.OnClientEvent:Connect(function(updateInfo: any)
		if updateInfo and updateInfo.title then
			if updateInfo.status == "Claimed" then
				showQuestBanner(string.format("🎉 Claimed: %s!", updateInfo.title), Color3.fromRGB(255, 215, 60), updateInfo.icon or "⭐")
			elseif updateInfo.status == "Completed" then
				showQuestBanner(string.format("⭐ Quest Completed: %s! [Q to Claim]", updateInfo.title), Color3.fromRGB(255, 215, 60), updateInfo.icon or "📜")
			elseif updateInfo.status == "Accepted" then
				showQuestBanner(string.format("Accepted: %s!", updateInfo.title), Color3.fromRGB(46, 204, 113), updateInfo.icon or "📜")
			else
				showQuestBanner(string.format("📜 Quest Update: %s (%d/%d)", updateInfo.title, updateInfo.progress or 0, updateInfo.target or 1), Color3.fromRGB(0, 210, 255), updateInfo.icon or "📜")
			end
		end
		QuestController.fetchData()
	end)

	-- Setup Tool listeners on character spawn/respawn
	if player.Character then
		setupToolListeners(player.Character)
	end
	player.CharacterAdded:Connect(setupToolListeners)

	-- Hotkey: Q or J to toggle Quest Modal
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.J then
			QuestController.toggleQuestModal()
		end
	end)

	-- Initial Data fetch
	task.delay(1.5, function()
		QuestController.fetchData()
	end)

	print("✅ [QuestController] Client Quest Controller Online!")
end

return QuestController
