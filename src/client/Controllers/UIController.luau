--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local GamepassConfig = require(ReplicatedStorage.Shared.Config.GamepassConfig)
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local AudioController = require(script.Parent.AudioController)
local PetHatchAnimation = require(script.Parent.PetHatchAnimation)
local MiningClient = require(script.Parent.MiningClient)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local UIController = {}
local cachedData: any = nil
local isLocalPlayerVIP = false

-- UI References
local screenGui: ScreenGui
local powerLabel: TextLabel
local cashLabel: TextLabel
local gemsLabel: TextLabel
local multiplierBadge: TextLabel
local vipBadge: TextLabel? = nil

local activeModal: Frame? = nil
local activeDialogue: Frame? = nil
local currentShopTab = "Shovel"
local isSpinningWheel = false
local wheelFreeBadge: Frame? = nil

-- Typewriter and RPG Dialogue State
local dialogueTypingThread: thread? = nil
local choicesTypingThread: thread? = nil
local idleBounceConnection: RBXScriptConnection? = nil
local isTypingDialogue = false
local activeTypingTarget: TextLabel? = nil
local activeFullText = ""
local activeOnComplete: (() -> ())? = nil
local choiceAction1: (() -> ())? = nil
local choiceAction2: (() -> ())? = nil
local activeChoiceButtons: { TextButton } = {}
local activeChoiceTexts: { string } = {}
local activeBounceElement: GuiObject? = nil
local activeBounceBasePos: UDim2? = nil

-- Helper to create rounded styled frames
local function createStyledFrame(parent: Instance, name: string, size: UDim2, pos: UDim2, bgColor: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = bgColor
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 70, 90)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	return frame
end

local function showFloatingPopup(text: string, color: Color3, xOffset: number?)
	if not screenGui then return end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 360, 0, 32)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, (xOffset or 0) + math.random(-20, 20), 0.6, math.random(-15, 15))
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.Parent = screenGui

	local targetPos = label.Position - UDim2.new(0, 0, 0.16, 0)
	local tween = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

function UIController.updateHUD()
	if not cachedData then return end
	if powerLabel then
		powerLabel.Text = FormatNumber.formatCompact(cachedData.Power or 10) .. " Power"
	end
	if cashLabel then
		cashLabel.Text = "$" .. FormatNumber.formatCompact(cachedData.Cash or 0)
	end
	if gemsLabel then
		gemsLabel.Text = FormatNumber.formatCompact(cachedData.Gems or 0)
	end
	if multiplierBadge then
		local rebirthMult = RebirthConfig.getMultiplier(cachedData.Rebirths or 0)
		local trailMult = TrailConfig.getCashMultiplier(cachedData.EquippedTrail)
		local skillCashMult = SkillTreeConfig.getTotalCashMult(cachedData.UnlockedSkills)
		local totalMult = rebirthMult * trailMult * skillCashMult
		multiplierBadge.Text = string.format("⚡ %.1fx Boost", totalMult)
	end
	if wheelFreeBadge then
		local now = os.time()
		local lastSpin = cachedData.LastWheelSpin or 0
		local elapsed = now - lastSpin
		local hasFree = (cachedData.FreeSpins and cachedData.FreeSpins > 0) or (elapsed >= WheelConfig.COOLDOWN_SECONDS)
		wheelFreeBadge.Visible = hasFree
	end
end

local function stopIdleBounce()
	if idleBounceConnection then
		idleBounceConnection:Disconnect()
		idleBounceConnection = nil
	end
	if activeBounceElement and activeBounceBasePos then
		activeBounceElement.Position = activeBounceBasePos
	end
	activeBounceElement = nil
	activeBounceBasePos = nil
end

local function startIdleBounce(element: GuiObject)
	stopIdleBounce()
	activeBounceElement = element
	activeBounceBasePos = element.Position
	local basePos = element.Position
	local startClock = os.clock()

	-- Satisfying initial pop bounce
	local popTween = TweenService:Create(element, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = basePos + UDim2.new(0, 0, 0, -8),
	})
	popTween:Play()
	popTween.Completed:Connect(function()
		TweenService:Create(element, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = basePos,
		}):Play()
	end)

	-- Gentle continuous floating idle bounce loop
	idleBounceConnection = RunService.RenderStepped:Connect(function()
		if not activeDialogue or not activeBounceElement then
			stopIdleBounce()
			return
		end
		local elapsed = os.clock() - startClock
		local bounceY = math.sin(elapsed * 3.5) * 4
		element.Position = basePos + UDim2.new(0, 0, 0, bounceY)
	end)
end

-- Types out choices sequentially after NPC dialogue finishes
local function typewriteChoices(onAllFinished: (() -> ())?)
	if choicesTypingThread then
		task.cancel(choicesTypingThread)
		choicesTypingThread = nil
	end

	for _, btn in ipairs(activeChoiceButtons) do
		btn.Text = ""
		btn.Visible = true
	end

	choicesTypingThread = task.spawn(function()
		for idx, btn in ipairs(activeChoiceButtons) do
			local targetText = activeChoiceTexts[idx]
			if not targetText then continue end
			local words = string.split(targetText, " ")
			local displayed = ""
			for wIdx, word in ipairs(words) do
				if wIdx == 1 then
					displayed = word
				else
					displayed = displayed .. " " .. word
				end
				btn.Text = displayed .. " <font color='#FFFFFF'>▮</font>"
				task.wait(0.028)
			end
			btn.Text = targetText
			task.wait(0.04)
		end

		choicesTypingThread = nil
		if onAllFinished then
			onAllFinished()
		end
	end)
end

local function closeDialogue()
	stopIdleBounce()

	if dialogueTypingThread then
		task.cancel(dialogueTypingThread)
		dialogueTypingThread = nil
	end
	if choicesTypingThread then
		task.cancel(choicesTypingThread)
		choicesTypingThread = nil
	end

	isTypingDialogue = false
	activeTypingTarget = nil
	activeFullText = ""
	activeOnComplete = nil
	choiceAction1 = nil
	choiceAction2 = nil
	activeChoiceButtons = {}
	activeChoiceTexts = {}

	if activeDialogue then
		local target = activeDialogue
		activeDialogue = nil
		local tween = TweenService:Create(target, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 60),
		})
		tween:Play()
		tween.Completed:Connect(function()
			target:Destroy()
		end)
	end
end

-- Fast-forwards / skips word-by-word typewriter to full text
local function skipDialogueTyping()
	stopIdleBounce()

	if dialogueTypingThread then
		task.cancel(dialogueTypingThread)
		dialogueTypingThread = nil
	end
	if choicesTypingThread then
		task.cancel(choicesTypingThread)
		choicesTypingThread = nil
	end

	isTypingDialogue = false
	if activeTypingTarget and activeFullText ~= "" then
		activeTypingTarget.Text = activeFullText
	end

	-- Immediately reveal all choices with full text
	for idx, btn in ipairs(activeChoiceButtons) do
		local fullText = activeChoiceTexts[idx]
		if fullText then
			btn.Text = fullText
			btn.Visible = true
		end
	end

	if activeBounceElement then
		startIdleBounce(activeBounceElement)
	end
end

-- Animates dialogue text word-by-word at a snappy, smooth RPG speed
local function typewriteWords(targetLabel: TextLabel, fullText: string, wordDelay: number?, onComplete: (() -> ())?)
	stopIdleBounce()

	if dialogueTypingThread then
		task.cancel(dialogueTypingThread)
		dialogueTypingThread = nil
	end
	if choicesTypingThread then
		task.cancel(choicesTypingThread)
		choicesTypingThread = nil
	end

	-- Clear choices while NPC speaks
	for _, btn in ipairs(activeChoiceButtons) do
		btn.Text = ""
	end

	isTypingDialogue = true
	activeTypingTarget = targetLabel
	activeFullText = fullText
	activeOnComplete = onComplete
	targetLabel.Text = ""

	local words = string.split(fullText, " ")
	local delay = wordDelay or 0.045

	dialogueTypingThread = task.spawn(function()
		local displayed = ""
		for i, word in ipairs(words) do
			if not isTypingDialogue then break end
			if i == 1 then
				displayed = word
			else
				displayed = displayed .. " " .. word
			end
			targetLabel.Text = displayed .. " <font color='#FFFFFF'>▮</font>"

			-- Subtle, soft retro chatter click every 2 words
			if i % 2 == 1 then
				local s = Instance.new("Sound")
				s.SoundId = "rbxassetid://6895079853"
				s.Volume = 0.03
				s.PlaybackSpeed = 2.4 + (math.random() * 0.4)
				s.Parent = SoundService
				s:Play()
				s.Ended:Connect(function()
					s:Destroy()
				end)
			end

			task.wait(delay)
		end

		if isTypingDialogue then
			targetLabel.Text = fullText
			isTypingDialogue = false
			if onComplete then
				local cb = onComplete
				activeOnComplete = nil
				cb()
			end
		end
	end)
end

local function closeModal()
	closeDialogue()
	if activeModal then
		local target = activeModal
		local tween = TweenService:Create(target, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1.5, 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			target:Destroy()
		end)
		activeModal = nil
	end
end

-- Rebirth Modal
local function openRebirthModal()
	closeModal()
	if not cachedData then
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
		else
			return
		end
	end

	local currentRebirths = cachedData.Rebirths or 0
	local cost = RebirthConfig.getCostForRebirth(currentRebirths)
	local rewardGems = RebirthConfig.getRewardGems(currentRebirths)
	local currentMult = RebirthConfig.getMultiplier(currentRebirths)
	local nextMult = RebirthConfig.getMultiplier(currentRebirths + 1)
	local currentCash = cachedData.Cash or 0
	local progressPct = math.clamp(currentCash / math.max(1, cost), 0, 1)

	local modal = createStyledFrame(screenGui, "RebirthModal", UDim2.new(0, 440, 0, 430), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 30))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	-- Header
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "⚡ REBIRTH CHAMBER ⚡"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	-- Info text
	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(0.9, 0, 0, 130)
	info.Position = UDim2.new(0.05, 0, 0, 55)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(220, 225, 235)
	info.Font = Enum.Font.GothamMedium
	info.TextSize = 14
	info.TextWrapped = true
	info.Text = string.format(
		"Reset your Cash in exchange for permanent cosmic power!\n\n" ..
		"• Current Multiplier: %.1fx\n" ..
		"• Next Multiplier: %.1fx (+50%% Cash & Mine Boost!)\n" ..
		"• Bonus Gems: +%d Gems 💎\n" ..
		"• Required Cash: $%s",
		currentMult,
		nextMult,
		rewardGems,
		FormatNumber.formatComma(cost)
	)
	info.Parent = modal

	-- Progress Bar Background
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.9, 0, 0, 24)
	barBg.Position = UDim2.new(0.05, 0, 0, 195)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
	barBg.BorderSizePixel = 0
	barBg.Parent = modal

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 6)
	barBgCorner.Parent = barBg

	-- Progress Fill
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(progressPct, 0, 1, 0)
	barFill.BackgroundColor3 = if progressPct >= 1 then Color3.fromRGB(0, 230, 118) else Color3.fromRGB(255, 170, 0)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = barFill

	-- Progress Text
	local barText = Instance.new("TextLabel")
	barText.Size = UDim2.new(1, 0, 1, 0)
	barText.BackgroundTransparency = 1
	barText.Text = string.format("$%s / $%s (%d%%)", FormatNumber.formatCompact(currentCash), FormatNumber.formatCompact(cost), math.floor(progressPct * 100))
	barText.TextColor3 = Color3.fromRGB(255, 255, 255)
	barText.Font = Enum.Font.GothamBold
	barText.TextSize = 12
	barText.TextStrokeTransparency = 0.3
	barText.Parent = barBg

	-- Rebirth Button
	local canAfford = currentCash >= cost
	local rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Size = UDim2.new(0.9, 0, 0, 50)
	rebirthBtn.Position = UDim2.new(0.05, 0, 0, 235)
	rebirthBtn.BackgroundColor3 = if canAfford then Color3.fromRGB(0, 200, 100) else Color3.fromRGB(80, 85, 95)
	rebirthBtn.Text = if canAfford then "⚡ REBIRTH NOW! (+100 💎) ⚡" else "NEED MORE CASH"
	rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rebirthBtn.Font = Enum.Font.GothamBlack
	rebirthBtn.TextSize = 16
	rebirthBtn.BorderSizePixel = 0
	rebirthBtn.Parent = modal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = rebirthBtn

	-- Status Feedback label
	local feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Size = UDim2.new(0.9, 0, 0, 25)
	feedbackLabel.Position = UDim2.new(0.05, 0, 0, 295)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Text = if canAfford then "Ready to transcend!" else string.format("Need $%s more cash to Rebirth!", FormatNumber.formatCompact(cost - currentCash))
	feedbackLabel.TextColor3 = if canAfford then Color3.fromRGB(0, 255, 170) else Color3.fromRGB(255, 120, 120)
	feedbackLabel.Font = Enum.Font.GothamBold
	feedbackLabel.TextSize = 13
	feedbackLabel.Parent = modal

	-- Dev testing cheat buttons inside modal
	local devRow = Instance.new("Frame")
	devRow.Name = "DevRebirthRow"
	devRow.Size = UDim2.new(0.9, 0, 0, 36)
	devRow.Position = UDim2.new(0.05, 0, 0, 330)
	devRow.BackgroundTransparency = 1
	devRow.Parent = modal

	local devList = Instance.new("UIListLayout")
	devList.FillDirection = Enum.FillDirection.Horizontal
	devList.Padding = UDim.new(0, 8)
	devList.Parent = devRow

	local function createDevRebirthOption(label: string, count: number)
		local devBtn = Instance.new("TextButton")
		devBtn.Size = UDim2.new(0.31, 0, 1, 0)
		devBtn.BackgroundColor3 = Color3.fromRGB(170, 40, 110)
		devBtn.Text = label
		devBtn.TextColor3 = Color3.fromRGB(255, 225, 245)
		devBtn.Font = Enum.Font.GothamBold
		devBtn.TextSize = 12
		devBtn.BorderSizePixel = 0
		devBtn.Parent = devRow

		local dCorner = Instance.new("UICorner")
		dCorner.CornerRadius = UDim.new(0, 8)
		dCorner.Parent = devBtn

		devBtn.MouseButton1Click:Connect(function()
			local devRebirthFn = Remotes.getFunction("DevAddRebirth")
			local ok, success, newRebirths = pcall(function()
				return devRebirthFn:InvokeServer(count)
			end)
			if ok and success then
				showFloatingPopup(string.format("⚡ +%d REBIRTH(S)! (Total: %d)", count, newRebirths or (cachedData.Rebirths or 0) + count), Color3.fromRGB(255, 120, 220), 0)
				openRebirthModal() -- refresh modal
			end
		end)
	end

	createDevRebirthOption("⚡ +1 (Dev)", 1)
	createDevRebirthOption("⚡ +5 (Dev)", 5)
	createDevRebirthOption("⚡ +10 (Dev)", 10)

	rebirthBtn.MouseButton1Click:Connect(function()
		if canAfford then
			rebirthBtn.Text = "REBIRTHING..."
			local requestFn = Remotes.getFunction("RequestRebirth")
			local ok = requestFn:InvokeServer()
			if ok then
				showFloatingPopup("⚡ REBIRTHED! +50% BOOST! ⚡", Color3.fromRGB(255, 215, 0), 0)
				closeModal()
			else
				rebirthBtn.Text = "FAILED"
			end
		else
			feedbackLabel.Text = string.format("⚠️ Mine or collect $%s more cash first!", FormatNumber.formatCompact(cost - currentCash))
			TweenService:Create(rebirthBtn, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
				Position = UDim2.new(0.07, 0, 0, 235),
			}):Play()
		end
	end)

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	-- Animate In
	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

-- Forward declarations for Pet Modals
local openPetModal: () -> ()
local openPetIndexModal: (filter: string?) -> ()
local openFusionModal: (initialMode: ("Golden" | "Rainbow")?) -> ()

-- Pet Hatching & Inventory Modal
openPetModal = function()
	closeModal()
	if not cachedData then return end

	local modal = createStyledFrame(screenGui, "PetModal", UDim2.new(0, 530, 0, 460), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 30))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 42)
	title.Position = UDim2.new(0, 0, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "🐾 PET SANCTUARY 🐾"
	title.TextColor3 = Color3.fromRGB(80, 240, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	-- Navigation Tabs
	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(0.92, 0, 0, 32)
	tabRow.Position = UDim2.new(0.04, 0, 0, 46)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = modal

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 8)
	tabList.Parent = tabRow

	local invTab = Instance.new("TextButton")
	invTab.Size = UDim2.new(0.315, 0, 1, 0)
	invTab.BackgroundColor3 = Color3.fromRGB(65, 105, 225)
	invTab.Text = "🐾 Inventory"
	invTab.TextColor3 = Color3.fromRGB(255, 255, 255)
	invTab.Font = Enum.Font.GothamBlack
	invTab.TextSize = 12
	invTab.BorderSizePixel = 0
	invTab.Parent = tabRow

	local itCorner = Instance.new("UICorner")
	itCorner.CornerRadius = UDim.new(0, 6)
	itCorner.Parent = invTab

	local indexTab = Instance.new("TextButton")
	indexTab.Size = UDim2.new(0.315, 0, 1, 0)
	indexTab.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	local petIndex = cachedData.PetIndex or {}
	local discCount = 0
	for petId, _ in PetConfig.PETS do
		if petIndex[petId] then discCount += 1 end
	end
	indexTab.Text = string.format("📖 Index (%d/%d)", discCount, PetConfig.getTotalPetsCount())
	indexTab.TextColor3 = Color3.fromRGB(200, 210, 230)
	indexTab.Font = Enum.Font.GothamBold
	indexTab.TextSize = 12
	indexTab.BorderSizePixel = 0
	indexTab.Parent = tabRow

	local idCorner = Instance.new("UICorner")
	idCorner.CornerRadius = UDim.new(0, 6)
	idCorner.Parent = indexTab

	indexTab.MouseButton1Click:Connect(function()
		openPetIndexModal()
	end)

	local fuseTab = Instance.new("TextButton")
	fuseTab.Size = UDim2.new(0.315, 0, 1, 0)
	fuseTab.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
	fuseTab.Text = "⚗️ Fusion"
	fuseTab.TextColor3 = Color3.fromRGB(255, 215, 80)
	fuseTab.Font = Enum.Font.GothamBold
	fuseTab.TextSize = 12
	fuseTab.BorderSizePixel = 0
	fuseTab.Parent = tabRow

	local ftCorner = Instance.new("UICorner")
	ftCorner.CornerRadius = UDim.new(0, 6)
	ftCorner.Parent = fuseTab

	fuseTab.MouseButton1Click:Connect(function()
		openFusionModal()
	end)

	-- Egg Hatch Section
	local eggSection = Instance.new("Frame")
	eggSection.Size = UDim2.new(0.92, 0, 0, 126)
	eggSection.Position = UDim2.new(0.04, 0, 0, 86)
	eggSection.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	eggSection.BorderSizePixel = 0
	eggSection.Parent = modal

	local eggCorner = Instance.new("UICorner")
	eggCorner.CornerRadius = UDim.new(0, 8)
	eggCorner.Parent = eggSection

	local eggSecTitle = Instance.new("TextLabel")
	eggSecTitle.Size = UDim2.new(1, 0, 0, 24)
	eggSecTitle.BackgroundTransparency = 1
	eggSecTitle.Text = "Hatch Eggs (Boosts Cash & Gems!)"
	eggSecTitle.TextColor3 = Color3.fromRGB(200, 210, 230)
	eggSecTitle.Font = Enum.Font.GothamBold
	eggSecTitle.TextSize = 13
	eggSecTitle.Parent = eggSection

	local eggList = {"BasicEgg", "CosmicEgg", "MagmaEgg"}
	for i, eggId in ipairs(eggList) do
		local eggDef = PetConfig.EGGS[eggId]
		if eggDef then
			local eggBtn = Instance.new("TextButton")
			eggBtn.Size = UDim2.new(0.30, 0, 0, 75)
			eggBtn.Position = UDim2.new(0.025 + (i - 1) * 0.325, 0, 0, 32)
			eggBtn.BackgroundColor3 = if eggId == "MagmaEgg" then Color3.fromRGB(60, 32, 28) else Color3.fromRGB(40, 48, 68)
			eggBtn.Text = eggDef.name .. "\n💎 " .. eggDef.cost .. " Gems"
			eggBtn.TextColor3 = if eggId == "MagmaEgg" then Color3.fromRGB(255, 150, 60) else Color3.fromRGB(255, 255, 255)
			eggBtn.Font = Enum.Font.GothamBold
			eggBtn.TextSize = 13
			eggBtn.BorderSizePixel = 0
			eggBtn.Parent = eggSection

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = eggBtn

			eggBtn.MouseButton1Click:Connect(function()
				local hatchFn = Remotes.getFunction("HatchEgg")
				local ok, petIds, err = hatchFn:InvokeServer(eggId, 1)
				local firstId = if typeof(petIds) == "table" then petIds[1] else petIds
				if ok and firstId and PetConfig.PETS[firstId] then
					eggBtn.Text = "HATCHED!\n" .. PetConfig.PETS[firstId].name
					task.wait(1.5)
					openPetModal() -- refresh
				end
			end)
		end
	end

	-- Inventory Section
	local invLabel = Instance.new("TextLabel")
	invLabel.Size = UDim2.new(1, 0, 0, 24)
	invLabel.Position = UDim2.new(0, 0, 0, 220)
	invLabel.BackgroundTransparency = 1
	invLabel.Text = "Your Pets (Equipped: Max 3)"
	invLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	invLabel.Font = Enum.Font.GothamBold
	invLabel.TextSize = 14
	invLabel.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 195)
	scroll.Position = UDim2.new(0.04, 0, 0, 248)
	scroll.BackgroundColor3 = Color3.fromRGB(26, 29, 38)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll

	local uilist = Instance.new("UIListLayout")
	uilist.Padding = UDim.new(0, 6)
	uilist.Parent = scroll

	local ownedCount = 0
	for petId, count in cachedData.OwnedPets or {} do
		if count > 0 and PetConfig.PETS[petId] then
			ownedCount += 1
			local pet = PetConfig.PETS[petId]
			local isEquipped = cachedData.EquippedPets[petId]

			local row = Instance.new("Frame")
			row.Size = UDim2.new(0.96, 0, 0, 48)
			row.BackgroundColor3 = if isEquipped then Color3.fromRGB(35, 60, 50) else Color3.fromRGB(35, 38, 50)
			row.BorderSizePixel = 0
			row.Parent = scroll

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 6)
			rCorner.Parent = row

			local petNameLabel = Instance.new("TextLabel")
			petNameLabel.Size = UDim2.new(0.6, 0, 1, 0)
			petNameLabel.Position = UDim2.new(0.04, 0, 0, 0)
			petNameLabel.BackgroundTransparency = 1
			petNameLabel.Text = pet.name .. " (x" .. count .. ") | +" .. string.format("%.0f%%", (pet.cashMultiplier - 1) * 100)
			petNameLabel.TextColor3 = pet.color
			petNameLabel.Font = Enum.Font.GothamBold
			petNameLabel.TextSize = 13
			petNameLabel.TextXAlignment = Enum.TextXAlignment.Left
			petNameLabel.Parent = row

			local equipBtn = Instance.new("TextButton")
			equipBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
			equipBtn.Position = UDim2.new(0.66, 0, 0.15, 0)
			equipBtn.BackgroundColor3 = if isEquipped then Color3.fromRGB(220, 80, 80) else Color3.fromRGB(0, 180, 100)
			equipBtn.Text = if isEquipped then "Unequip" else "Equip"
			equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			equipBtn.Font = Enum.Font.GothamBold
			equipBtn.TextSize = 12
			equipBtn.BorderSizePixel = 0
			equipBtn.Parent = row

			local eqCorner = Instance.new("UICorner")
			eqCorner.CornerRadius = UDim.new(0, 6)
			eqCorner.Parent = equipBtn

			equipBtn.MouseButton1Click:Connect(function()
				local equipFn = Remotes.getFunction("ToggleEquipPet")
				equipFn:InvokeServer(petId)
				task.wait(0.2)
				openPetModal()
			end)
		end
	end

	if ownedCount == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 1, 0)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No pets yet! Hatch an egg above to get your first pet."
		emptyLabel.TextColor3 = Color3.fromRGB(150, 155, 170)
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextSize = 13
		emptyLabel.Parent = scroll
	end

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

-- ==========================================
-- 📖 PET BESTIARY / COLLECTION INDEX MODAL
-- ==========================================
openPetIndexModal = function(currentFilter: string?)
	closeModal()
	if not cachedData then return end

	local activeFilter = currentFilter or "All"
	local petIndex = cachedData.PetIndex or {}
	local claimedMilestones = cachedData.ClaimedIndexMilestones or {}

	-- Count discovered pets
	local totalPets = PetConfig.getTotalPetsCount()
	local discoveredCount = 0
	for petId, _ in PetConfig.PETS do
		if petIndex[petId] then
			discoveredCount += 1
		end
	end
	local pct = math.clamp(discoveredCount / math.max(1, totalPets), 0, 1)

	-- Calculate total power boost from claimed milestones
	local totalBoostPct = 0
	for _, m in ipairs(PetConfig.INDEX_MILESTONES) do
		if claimedMilestones[m.id] then
			totalBoostPct += m.powerBoostPct
		end
	end

	local modal = createStyledFrame(screenGui, "PetIndexModal", UDim2.new(0, 640, 0, 530), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(18, 20, 28))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	-- Header Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 42)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "📖 PET COLLECTION INDEX 📖"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	-- Navigation Tabs
	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(0.92, 0, 0, 32)
	tabRow.Position = UDim2.new(0.04, 0, 0, 48)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = modal

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 6)
	tabList.Parent = tabRow

	local invTabBtn = Instance.new("TextButton")
	invTabBtn.Size = UDim2.new(0.315, 0, 1, 0)
	invTabBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 60)
	invTabBtn.Text = "🐾 Inventory"
	invTabBtn.TextColor3 = Color3.fromRGB(190, 200, 220)
	invTabBtn.Font = Enum.Font.GothamBold
	invTabBtn.TextSize = 12
	invTabBtn.BorderSizePixel = 0
	invTabBtn.Parent = tabRow

	local tCorner1 = Instance.new("UICorner")
	tCorner1.CornerRadius = UDim.new(0, 6)
	tCorner1.Parent = invTabBtn

	invTabBtn.MouseButton1Click:Connect(openPetModal)

	local indexTabBtn = Instance.new("TextButton")
	indexTabBtn.Size = UDim2.new(0.315, 0, 1, 0)
	indexTabBtn.BackgroundColor3 = Color3.fromRGB(0, 165, 215)
	indexTabBtn.Text = string.format("📖 Index (%d/%d)", discoveredCount, totalPets)
	indexTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	indexTabBtn.Font = Enum.Font.GothamBlack
	indexTabBtn.TextSize = 12
	indexTabBtn.BorderSizePixel = 0
	indexTabBtn.Parent = tabRow

	local tCorner2 = Instance.new("UICorner")
	tCorner2.CornerRadius = UDim.new(0, 6)
	tCorner2.Parent = indexTabBtn

	local fuseTabBtn = Instance.new("TextButton")
	fuseTabBtn.Size = UDim2.new(0.315, 0, 1, 0)
	fuseTabBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 60)
	fuseTabBtn.Text = "⚗️ Fusion"
	fuseTabBtn.TextColor3 = Color3.fromRGB(255, 215, 80)
	fuseTabBtn.Font = Enum.Font.GothamBold
	fuseTabBtn.TextSize = 12
	fuseTabBtn.BorderSizePixel = 0
	fuseTabBtn.Parent = tabRow

	local tCorner3 = Instance.new("UICorner")
	tCorner3.CornerRadius = UDim.new(0, 6)
	tCorner3.Parent = fuseTabBtn

	fuseTabBtn.MouseButton1Click:Connect(function()
		openFusionModal()
	end)

	-- Progress and Total Boost Banner
	local progressCard = Instance.new("Frame")
	progressCard.Size = UDim2.new(0.92, 0, 0, 44)
	progressCard.Position = UDim2.new(0.04, 0, 0, 88)
	progressCard.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
	progressCard.BorderSizePixel = 0
	progressCard.Parent = modal

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 8)
	pCorner.Parent = progressCard

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Size = UDim2.new(0.55, 0, 0.45, 0)
	progressLabel.Position = UDim2.new(0.03, 0, 0.1, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = string.format("Discovery Progress: %d / %d Pets (%d%%)", discoveredCount, totalPets, math.floor(pct * 100))
	progressLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextSize = 12
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = progressCard

	local boostLabel = Instance.new("TextLabel")
	boostLabel.Size = UDim2.new(0.4, 0, 0.45, 0)
	boostLabel.Position = UDim2.new(0.57, 0, 0.1, 0)
	boostLabel.BackgroundTransparency = 1
	boostLabel.Text = string.format("⚡ Total Boost: +%d%% Power", totalBoostPct)
	boostLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
	boostLabel.Font = Enum.Font.GothamBlack
	boostLabel.TextSize = 12
	boostLabel.TextXAlignment = Enum.TextXAlignment.Right
	boostLabel.Parent = progressCard

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.94, 0, 0, 10)
	barBg.Position = UDim2.new(0.03, 0, 0.65, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	barBg.BorderSizePixel = 0
	barBg.Parent = progressCard

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 5)
	bCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(pct, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local bfCorner = Instance.new("UICorner")
	bfCorner.CornerRadius = UDim.new(0, 5)
	bfCorner.Parent = barFill

	-- Milestone Rewards Strip
	local milestoneSec = Instance.new("Frame")
	milestoneSec.Size = UDim2.new(0.92, 0, 0, 68)
	milestoneSec.Position = UDim2.new(0.04, 0, 0, 138)
	milestoneSec.BackgroundColor3 = Color3.fromRGB(22, 25, 36)
	milestoneSec.BorderSizePixel = 0
	milestoneSec.Parent = modal

	local mCorner = Instance.new("UICorner")
	mCorner.CornerRadius = UDim.new(0, 8)
	mCorner.Parent = milestoneSec

	local mLayout = Instance.new("UIListLayout")
	mLayout.FillDirection = Enum.FillDirection.Horizontal
	mLayout.Padding = UDim.new(0, 8)
	mLayout.Parent = milestoneSec

	for _, m in ipairs(PetConfig.INDEX_MILESTONES) do
		local isClaimed = claimedMilestones[m.id] == true
		local isEligible = discoveredCount >= m.requiredCount and not isClaimed

		local mCard = Instance.new("Frame")
		mCard.Size = UDim2.new(0.235, 0, 0.9, 0)
		mCard.Position = UDim2.new(0, 0, 0.05, 0)
		mCard.BackgroundColor3 = if isEligible then Color3.fromRGB(35, 55, 45) elseif isClaimed then Color3.fromRGB(28, 30, 40) else Color3.fromRGB(25, 28, 38)
		mCard.BorderSizePixel = 0
		mCard.Parent = milestoneSec

		local mcCorner = Instance.new("UICorner")
		mcCorner.CornerRadius = UDim.new(0, 6)
		mcCorner.Parent = mCard

		local mTitle = Instance.new("TextLabel")
		mTitle.Size = UDim2.new(1, 0, 0.35, 0)
		mTitle.BackgroundTransparency = 1
		mTitle.Text = string.format("%s %s (%d)", m.icon, m.name, m.requiredCount)
		mTitle.TextColor3 = if isEligible then Color3.fromRGB(255, 220, 100) else Color3.fromRGB(210, 215, 230)
		mTitle.Font = Enum.Font.GothamBold
		mTitle.TextSize = 10
		mTitle.Parent = mCard

		local mReward = Instance.new("TextLabel")
		mReward.Size = UDim2.new(1, 0, 0.3, 0)
		mReward.Position = UDim2.new(0, 0, 0.32, 0)
		mReward.BackgroundTransparency = 1
		mReward.Text = string.format("+%s 💎 • +%d%% ⚡", FormatNumber.formatCompact(m.gemsReward), m.powerBoostPct)
		mReward.TextColor3 = Color3.fromRGB(0, 230, 180)
		mReward.Font = Enum.Font.GothamBold
		mReward.TextSize = 10
		mReward.Parent = mCard

		local claimBtn = Instance.new("TextButton")
		claimBtn.Size = UDim2.new(0.88, 0, 0.32, 0)
		claimBtn.Position = UDim2.new(0.06, 0, 0.64, 0)
		claimBtn.BorderSizePixel = 0
		claimBtn.Font = Enum.Font.GothamBlack
		claimBtn.TextSize = 10
		claimBtn.Parent = mCard

		local cbCorner = Instance.new("UICorner")
		cbCorner.CornerRadius = UDim.new(0, 4)
		cbCorner.Parent = claimBtn

		if isClaimed then
			claimBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 50)
			claimBtn.Text = "✓ CLAIMED"
			claimBtn.TextColor3 = Color3.fromRGB(150, 200, 160)
		elseif isEligible then
			claimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
			claimBtn.Text = "CLAIM REWARD"
			claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			claimBtn.MouseButton1Click:Connect(function()
				local claimFn = Remotes.getFunction("ClaimIndexMilestone")
				local ok, msg = claimFn:InvokeServer(m.id)
				if ok then
					showFloatingPopup(string.format("🏆 CLAIMED %s! (+%s 💎)", m.name:upper(), FormatNumber.formatCompact(m.gemsReward)), Color3.fromRGB(0, 255, 180), 0)
					openPetIndexModal(activeFilter)
				end
			end)
		else
			claimBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			claimBtn.Text = string.format("🔒 %d/%d", discoveredCount, m.requiredCount)
			claimBtn.TextColor3 = Color3.fromRGB(140, 145, 160)
		end
	end

	-- Category Filter Bar
	local filterBar = Instance.new("Frame")
	filterBar.Size = UDim2.new(0.92, 0, 0, 28)
	filterBar.Position = UDim2.new(0.04, 0, 0, 212)
	filterBar.BackgroundTransparency = 1
	filterBar.Parent = modal

	local fLayout = Instance.new("UIListLayout")
	fLayout.FillDirection = Enum.FillDirection.Horizontal
	fLayout.Padding = UDim.new(0, 6)
	fLayout.Parent = filterBar

	local filterOptions = {
		{ id = "All", label = "All Pets" },
		{ id = "BasicEgg", label = "Prism Egg" },
		{ id = "MagmaEgg", label = "Magma Egg" },
		{ id = "CosmicEgg", label = "Cosmic Void" },
		{ id = "RobuxEgg", label = "Exclusive" },
	}

	for _, opt in ipairs(filterOptions) do
		local isSel = (opt.id == activeFilter)
		local fBtn = Instance.new("TextButton")
		fBtn.Size = UDim2.new(0.188, 0, 1, 0)
		fBtn.BackgroundColor3 = if isSel then Color3.fromRGB(0, 165, 215) else Color3.fromRGB(32, 36, 50)
		fBtn.Text = opt.label
		fBtn.TextColor3 = if isSel then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(190, 195, 215)
		fBtn.Font = Enum.Font.GothamBold
		fBtn.TextSize = 11
		fBtn.BorderSizePixel = 0
		fBtn.Parent = filterBar

		local fCorner = Instance.new("UICorner")
		fCorner.CornerRadius = UDim.new(0, 6)
		fCorner.Parent = fBtn

		fBtn.MouseButton1Click:Connect(function()
			openPetIndexModal(opt.id)
		end)
	end

	-- Pet Catalog Grid in a ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 270)
	scroll.Position = UDim2.new(0.04, 0, 0, 246)
	scroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 185, 0, 175)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.Parent = scroll

	local pListPad = Instance.new("UIPadding")
	pListPad.PaddingTop = UDim.new(0, 8)
	pListPad.PaddingLeft = UDim.new(0, 8)
	pListPad.PaddingRight = UDim.new(0, 8)
	pListPad.PaddingBottom = UDim.new(0, 8)
	pListPad.Parent = scroll

	-- Fixed ordered list of pets
	local petOrder = {
		"CrystalDoge", "SparkleKitty", "NeonBunny",
		"InfernoDragon", "VoidPhoenix",
		"MagmaHound", "VolcanicGolem", "ElderMagmaDrake",
		"AstralKitsune", "VoidLeviathan", "ChronosDrake"
	}

	for _, petId in ipairs(petOrder) do
		local pet = PetConfig.PETS[petId]
		if pet then
			if activeFilter == "All" or pet.originEgg == activeFilter then
				local isDiscovered = (petIndex[petId] == true)
				local rarityColor = PetConfig.getRarityColor(pet.rarity)
				local ownedCount = cachedData.OwnedPets and cachedData.OwnedPets[petId] or 0

				local card = Instance.new("Frame")
				card.BackgroundColor3 = if isDiscovered then Color3.fromRGB(24, 28, 40) else Color3.fromRGB(20, 22, 30)
				card.BorderSizePixel = 0
				card.Parent = scroll

				local cCorner = Instance.new("UICorner")
				cCorner.CornerRadius = UDim.new(0, 10)
				cCorner.Parent = card

				local cStroke = Instance.new("UIStroke")
				cStroke.Color = if isDiscovered then rarityColor else Color3.fromRGB(45, 48, 60)
				cStroke.Thickness = if isDiscovered then 1.5 else 1
				cStroke.Transparency = if isDiscovered then 0.2 else 0.6
				cStroke.Parent = card

				-- Rarity Pill Badge
				local rarityBadge = Instance.new("TextLabel")
				rarityBadge.Size = UDim2.new(0.9, 0, 0, 18)
				rarityBadge.Position = UDim2.new(0.05, 0, 0, 6)
				rarityBadge.BackgroundColor3 = if isDiscovered then rarityColor else Color3.fromRGB(38, 40, 50)
				rarityBadge.BackgroundTransparency = if isDiscovered then 0.75 else 0.5
				rarityBadge.Text = if isDiscovered then pet.rarity:upper() else string.format("??? • %s", pet.rarity:upper())
				rarityBadge.TextColor3 = if isDiscovered then rarityColor else Color3.fromRGB(150, 155, 170)
				rarityBadge.Font = Enum.Font.GothamBlack
				rarityBadge.TextSize = 10
				rarityBadge.BorderSizePixel = 0
				rarityBadge.Parent = card

				local rbCorner = Instance.new("UICorner")
				rbCorner.CornerRadius = UDim.new(0, 4)
				rbCorner.Parent = rarityBadge

				-- Pet Icon
				local iconLabel = Instance.new("TextLabel")
				iconLabel.Size = UDim2.new(1, 0, 0, 44)
				iconLabel.Position = UDim2.new(0, 0, 0, 28)
				iconLabel.BackgroundTransparency = 1
				iconLabel.Text = if isDiscovered then pet.icon else "❓"
				iconLabel.TextSize = if isDiscovered then 36 else 30
				iconLabel.Parent = card

				-- Pet Name
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(0.92, 0, 0, 20)
				nameLabel.Position = UDim2.new(0.04, 0, 0, 74)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = if isDiscovered then pet.name else "???"
				nameLabel.TextColor3 = if isDiscovered then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 155, 170)
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextSize = 12
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.Parent = card

				-- Multipliers
				local multLabel = Instance.new("TextLabel")
				multLabel.Size = UDim2.new(0.92, 0, 0, 16)
				multLabel.Position = UDim2.new(0.04, 0, 0, 96)
				multLabel.BackgroundTransparency = 1
				if isDiscovered then
					multLabel.Text = string.format("+%.0f%% Cash • +%.0f%% Gems", (pet.cashMultiplier - 1) * 100, (pet.gemMultiplier - 1) * 100)
					multLabel.TextColor3 = Color3.fromRGB(0, 230, 140)
				else
					multLabel.Text = "🔒 Multipliers Hidden"
					multLabel.TextColor3 = Color3.fromRGB(120, 125, 140)
				end
				multLabel.Font = Enum.Font.GothamMedium
				multLabel.TextSize = 10
				multLabel.Parent = card

				-- Egg Origin Source
				local eggDef = PetConfig.EGGS[pet.originEgg]
				local originName = if eggDef then eggDef.name else "Egg"
				local originLabel = Instance.new("TextLabel")
				originLabel.Size = UDim2.new(0.92, 0, 0, 16)
				originLabel.Position = UDim2.new(0.04, 0, 0, 116)
				originLabel.BackgroundTransparency = 1
				originLabel.Text = "🥚 " .. originName
				originLabel.TextColor3 = Color3.fromRGB(255, 215, 120)
				originLabel.Font = Enum.Font.GothamMedium
				originLabel.TextSize = 10
				originLabel.Parent = card

				-- Discovery status footer pill
				local statusPill = Instance.new("TextLabel")
				statusPill.Size = UDim2.new(0.9, 0, 0, 24)
				statusPill.Position = UDim2.new(0.05, 0, 0, 142)
				statusPill.BorderSizePixel = 0
				statusPill.Font = Enum.Font.GothamBold
				statusPill.TextSize = 10

				local spCorner = Instance.new("UICorner")
				spCorner.CornerRadius = UDim.new(0, 6)
				spCorner.Parent = statusPill

				if isDiscovered then
					statusPill.BackgroundColor3 = Color3.fromRGB(35, 65, 45)
					statusPill.Text = if ownedCount > 0 then string.format("✓ Owned (%dx)", ownedCount) else "✓ Discovered"
					statusPill.TextColor3 = Color3.fromRGB(100, 255, 170)
				else
					statusPill.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
					statusPill.Text = "🔒 Undiscovered"
					statusPill.TextColor3 = Color3.fromRGB(140, 145, 160)
				end
				statusPill.Parent = card
			end
		end
	end

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	-- Animate In
	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

-- ==========================================
-- ⚗️ PET FUSION CHAMBER MODAL (GOLDEN & RAINBOW)
-- ==========================================
openFusionModal = function(initialMode: ("Golden" | "Rainbow")?)
	closeModal()
	if not cachedData then return end

	local activeMode = initialMode or "Golden"
	local ownedPets = cachedData.OwnedPets or {}

	local modal = createStyledFrame(screenGui, "PetFusionModal", UDim2.new(0, 660, 0, 540), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(18, 20, 28))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local stroke = modal:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if activeMode == "Golden" then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 100, 220)
		stroke.Thickness = 2.0
	end

	-- Header Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "⚗️ PET FUSION CHAMBER ⚗️"
	title.TextColor3 = if activeMode == "Golden" then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 120, 240)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 21
	title.Parent = modal

	-- Top Hub Navigation Tabs
	local topTabs = Instance.new("Frame")
	topTabs.Size = UDim2.new(0.92, 0, 0, 30)
	topTabs.Position = UDim2.new(0.04, 0, 0, 46)
	topTabs.BackgroundTransparency = 1
	topTabs.Parent = modal

	local tLayout = Instance.new("UIListLayout")
	tLayout.FillDirection = Enum.FillDirection.Horizontal
	tLayout.Padding = UDim.new(0, 6)
	tLayout.Parent = topTabs

	local function addHubTab(text: string, isActive: boolean, onClick: () -> ())
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.315, 0, 1, 0)
		btn.BackgroundColor3 = if isActive then Color3.fromRGB(0, 165, 215) else Color3.fromRGB(34, 38, 52)
		btn.Text = text
		btn.TextColor3 = if isActive then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(190, 195, 215)
		btn.Font = if isActive then Enum.Font.GothamBlack else Enum.Font.GothamBold
		btn.TextSize = 12
		btn.BorderSizePixel = 0
		btn.Parent = topTabs

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn

		btn.MouseButton1Click:Connect(onClick)
	end

	addHubTab("🐾 Inventory", false, openPetModal)
	addHubTab("📖 Pet Index", false, function() openPetIndexModal() end)
	addHubTab("⚗️ Pet Fusion", true, function() openFusionModal(activeMode) end)

	-- Mode Switcher Banner (Big Golden vs Rainbow toggle buttons)
	local modeRow = Instance.new("Frame")
	modeRow.Size = UDim2.new(0.92, 0, 0, 46)
	modeRow.Position = UDim2.new(0.04, 0, 0, 84)
	modeRow.BackgroundTransparency = 1
	modeRow.Parent = modal

	local mLayout = Instance.new("UIListLayout")
	mLayout.FillDirection = Enum.FillDirection.Horizontal
	mLayout.Padding = UDim.new(0, 8)
	mLayout.Parent = modeRow

	-- Golden Mode Button
	local isGold = (activeMode == "Golden")
	local goldBtn = Instance.new("TextButton")
	goldBtn.Size = UDim2.new(0.488, 0, 1, 0)
	goldBtn.BackgroundColor3 = if isGold then Color3.fromRGB(55, 45, 18) else Color3.fromRGB(26, 28, 38)
	goldBtn.Text = "🌟 GOLDEN FUSION\n3 Normal Pets ➔ 1 Golden (3x Stats)"
	goldBtn.TextColor3 = if isGold then Color3.fromRGB(255, 225, 80) else Color3.fromRGB(170, 175, 190)
	goldBtn.Font = Enum.Font.GothamBold
	goldBtn.TextSize = 11
	goldBtn.BorderSizePixel = 0
	goldBtn.Parent = modeRow

	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 8)
	gCorner.Parent = goldBtn

	local gStroke = Instance.new("UIStroke")
	gStroke.Color = if isGold then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(45, 48, 60)
	gStroke.Thickness = if isGold then 2 else 1
	gStroke.Parent = goldBtn

	goldBtn.MouseButton1Click:Connect(function()
		openFusionModal("Golden")
	end)

	-- Rainbow Mode Button
	local isRainbow = (activeMode == "Rainbow")
	local rbBtn = Instance.new("TextButton")
	rbBtn.Size = UDim2.new(0.488, 0, 1, 0)
	rbBtn.BackgroundColor3 = if isRainbow then Color3.fromRGB(50, 22, 55) else Color3.fromRGB(26, 28, 38)
	rbBtn.Text = "🌈 RAINBOW FUSION\n3 Golden Pets ➔ 1 Rainbow (9x Stats)"
	rbBtn.TextColor3 = if isRainbow then Color3.fromRGB(255, 130, 240) else Color3.fromRGB(170, 175, 190)
	rbBtn.Font = Enum.Font.GothamBold
	rbBtn.TextSize = 11
	rbBtn.BorderSizePixel = 0
	rbBtn.Parent = modeRow

	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0, 8)
	rbCorner.Parent = rbBtn

	local rbStroke = Instance.new("UIStroke")
	rbStroke.Color = if isRainbow then Color3.fromRGB(255, 100, 220) else Color3.fromRGB(45, 48, 60)
	rbStroke.Thickness = if isRainbow then 2 else 1
	rbStroke.Parent = rbBtn

	rbBtn.MouseButton1Click:Connect(function()
		openFusionModal("Rainbow")
	end)

	-- Info tip banner
	local infoCard = Instance.new("Frame")
	infoCard.Size = UDim2.new(0.92, 0, 0, 24)
	infoCard.Position = UDim2.new(0.04, 0, 0, 136)
	infoCard.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	infoCard.BorderSizePixel = 0
	infoCard.Parent = modal

	local icCorner = Instance.new("UICorner")
	icCorner.CornerRadius = UDim.new(0, 6)
	icCorner.Parent = infoCard

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -16, 1, 0)
	infoLabel.Position = UDim2.new(0, 8, 0, 0)
	infoLabel.BackgroundTransparency = 1
	if activeMode == "Golden" then
		infoLabel.Text = "💡 Tip: 3 Normal pets of the same species fuse with 100% success into 1 Golden Pet!"
	else
		infoLabel.Text = "💡 Tip: 3 Golden pets of the same species fuse with 100% success into 1 Rainbow Pet!"
	end
	infoLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	infoLabel.Font = Enum.Font.GothamMedium
	infoLabel.TextSize = 11
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = infoCard

	-- Fusion Candidates Scrolling Frame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 360)
	scroll.Position = UDim2.new(0.04, 0, 0, 166)
	scroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	-- Build species list sorted by (canFuse desc, ownedCount desc)
	type FusionCandidate = {
		baseId: string,
		sourceId: string,
		targetId: string,
		ownedCount: number,
		canFuse: boolean,
	}

	local candidates: { FusionCandidate } = {}
	for _, baseId in ipairs(PetConfig.BASE_PET_IDS) do
		local sourceId = if activeMode == "Golden" then baseId else PetConfig.getGoldenId(baseId)
		local targetId = if activeMode == "Golden" then PetConfig.getGoldenId(baseId) else PetConfig.getRainbowId(baseId)
		local count = ownedPets[sourceId] or 0
		table.insert(candidates, {
			baseId = baseId,
			sourceId = sourceId,
			targetId = targetId,
			ownedCount = count,
			canFuse = count >= 3,
		})
	end

	table.sort(candidates, function(a, b)
		if a.canFuse ~= b.canFuse then
			return a.canFuse == true
		end
		return a.ownedCount > b.ownedCount
	end)

	for _, cand in ipairs(candidates) do
		local srcPet = PetConfig.PETS[cand.sourceId]
		local tgtPet = PetConfig.PETS[cand.targetId]
		if srcPet and tgtPet then
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 78)
			card.BackgroundColor3 = if cand.canFuse then Color3.fromRGB(24, 28, 40) else Color3.fromRGB(20, 22, 30)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 8)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = if cand.canFuse then (if activeMode == "Golden" then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 100, 220)) else Color3.fromRGB(38, 42, 54)
			cStroke.Thickness = if cand.canFuse then 1.5 else 1
			cStroke.Parent = card

			-- Left: Source Pet Column
			local srcIcon = Instance.new("TextLabel")
			srcIcon.Size = UDim2.new(0, 46, 0, 46)
			srcIcon.Position = UDim2.new(0, 10, 0, 16)
			srcIcon.BackgroundTransparency = 1
			srcIcon.Text = srcPet.icon
			srcIcon.TextSize = 30
			srcIcon.Parent = card

			local srcName = Instance.new("TextLabel")
			srcName.Size = UDim2.new(0, 140, 0, 20)
			srcName.Position = UDim2.new(0, 58, 0, 14)
			srcName.BackgroundTransparency = 1
			srcName.Text = srcPet.name
			srcName.TextColor3 = Color3.fromRGB(240, 245, 255)
			srcName.Font = Enum.Font.GothamBold
			srcName.TextSize = 13
			srcName.TextXAlignment = Enum.TextXAlignment.Left
			srcName.TextTruncate = Enum.TextTruncate.AtEnd
			srcName.Parent = card

			local countPill = Instance.new("TextLabel")
			countPill.Size = UDim2.new(0, 120, 0, 20)
			countPill.Position = UDim2.new(0, 58, 0, 36)
			countPill.BackgroundColor3 = if cand.canFuse then Color3.fromRGB(25, 55, 35) else Color3.fromRGB(32, 34, 44)
			countPill.Text = if cand.canFuse then string.format("✓ %d / 3 Ready!", cand.ownedCount) else string.format("🔒 %d / 3 Needed", cand.ownedCount)
			countPill.TextColor3 = if cand.canFuse then Color3.fromRGB(80, 255, 160) else Color3.fromRGB(150, 155, 170)
			countPill.Font = Enum.Font.GothamBold
			countPill.TextSize = 11
			countPill.BorderSizePixel = 0
			countPill.Parent = card

			local cpCorner = Instance.new("UICorner")
			cpCorner.CornerRadius = UDim.new(0, 4)
			cpCorner.Parent = countPill

			-- Center Arrow
			local arrow = Instance.new("TextLabel")
			arrow.Size = UDim2.new(0, 36, 0, 36)
			arrow.Position = UDim2.new(0, 206, 0, 21)
			arrow.BackgroundTransparency = 1
			arrow.Text = "➔"
			arrow.TextColor3 = if cand.canFuse then (if activeMode == "Golden" then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 100, 220)) else Color3.fromRGB(100, 105, 120)
			arrow.Font = Enum.Font.GothamBlack
			arrow.TextSize = 22
			arrow.Parent = card

			-- Right Column: Target Pet Result Preview
			local tgtIcon = Instance.new("TextLabel")
			tgtIcon.Size = UDim2.new(0, 46, 0, 46)
			tgtIcon.Position = UDim2.new(0, 248, 0, 16)
			tgtIcon.BackgroundTransparency = 1
			tgtIcon.Text = tgtPet.icon
			tgtIcon.TextSize = 30
			tgtIcon.Parent = card

			local tgtName = Instance.new("TextLabel")
			tgtName.Size = UDim2.new(0, 150, 0, 20)
			tgtName.Position = UDim2.new(0, 298, 0, 14)
			tgtName.BackgroundTransparency = 1
			tgtName.Text = tgtPet.name
			tgtName.TextColor3 = if activeMode == "Golden" then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 130, 240)
			tgtName.Font = Enum.Font.GothamBlack
			tgtName.TextSize = 13
			tgtName.TextXAlignment = Enum.TextXAlignment.Left
			tgtName.TextTruncate = Enum.TextTruncate.AtEnd
			tgtName.Parent = card

			local multLabel = Instance.new("TextLabel")
			multLabel.Size = UDim2.new(0, 150, 0, 18)
			multLabel.Position = UDim2.new(0, 298, 0, 36)
			multLabel.BackgroundTransparency = 1
			multLabel.Text = string.format("+%.0f%% Cash • +%.0f%% Gems", (tgtPet.cashMultiplier - 1) * 100, (tgtPet.gemMultiplier - 1) * 100)
			multLabel.TextColor3 = Color3.fromRGB(0, 230, 160)
			multLabel.Font = Enum.Font.GothamBold
			multLabel.TextSize = 10
			multLabel.TextXAlignment = Enum.TextXAlignment.Left
			multLabel.Parent = card

			-- Action Buttons (Fuse 1x, Fuse All)
			if cand.canFuse then
				local batches = math.floor(cand.ownedCount / 3)
				local canFuseAll = (batches >= 2)

				local fuse1Btn = Instance.new("TextButton")
				fuse1Btn.Size = if canFuseAll then UDim2.new(0, 78, 0, 38) else UDim2.new(0, 110, 0, 42)
				fuse1Btn.Position = if canFuseAll then UDim2.new(1, -170, 0, 19) else UDim2.new(1, -122, 0, 18)
				fuse1Btn.BackgroundColor3 = if activeMode == "Golden" then Color3.fromRGB(210, 160, 20) else Color3.fromRGB(180, 50, 160)
				fuse1Btn.Text = "FUSE 1x"
				fuse1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				fuse1Btn.Font = Enum.Font.GothamBlack
				fuse1Btn.TextSize = 12
				fuse1Btn.BorderSizePixel = 0
				fuse1Btn.Parent = card

				local f1Corner = Instance.new("UICorner")
				f1Corner.CornerRadius = UDim.new(0, 6)
				f1Corner.Parent = fuse1Btn

				fuse1Btn.MouseButton1Click:Connect(function()
					fuse1Btn.Text = "..."
					local fuseFn = Remotes.getFunction("FusePets")
					local ok, targetId, batchCount, msg = fuseFn:InvokeServer(activeMode, cand.baseId, false)
					if ok then
						showFloatingPopup(msg or "✨ Fusion Successful!", if activeMode == "Golden" then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(255, 100, 220), 0)
						openFusionModal(activeMode)
					else
						showFloatingPopup("⚠️ " .. tostring(msg), Color3.fromRGB(255, 80, 80), 0)
						openFusionModal(activeMode)
					end
				end)

				if canFuseAll then
					local fuseAllBtn = Instance.new("TextButton")
					fuseAllBtn.Size = UDim2.new(0, 84, 0, 38)
					fuseAllBtn.Position = UDim2.new(1, -88, 0, 19)
					fuseAllBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 140)
					fuseAllBtn.Text = string.format("ALL (%dx)", batches)
					fuseAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
					fuseAllBtn.Font = Enum.Font.GothamBlack
					fuseAllBtn.TextSize = 11
					fuseAllBtn.BorderSizePixel = 0
					fuseAllBtn.Parent = card

					local faCorner = Instance.new("UICorner")
					faCorner.CornerRadius = UDim.new(0, 6)
					faCorner.Parent = fuseAllBtn

					fuseAllBtn.MouseButton1Click:Connect(function()
						fuseAllBtn.Text = "..."
						local fuseFn = Remotes.getFunction("FusePets")
						local ok, targetId, batchCount, msg = fuseFn:InvokeServer(activeMode, cand.baseId, true)
						if ok then
							showFloatingPopup(msg or "✨ Batch Fusion Successful!", if activeMode == "Golden" then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(255, 100, 220), 0)
							openFusionModal(activeMode)
						else
							showFloatingPopup("⚠️ " .. tostring(msg), Color3.fromRGB(255, 80, 80), 0)
							openFusionModal(activeMode)
						end
					end)
				end
			else
				local lockedBtn = Instance.new("TextLabel")
				lockedBtn.Size = UDim2.new(0, 110, 0, 38)
				lockedBtn.Position = UDim2.new(1, -122, 0, 20)
				lockedBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
				lockedBtn.Text = string.format("🔒 Need %d More", 3 - cand.ownedCount)
				lockedBtn.TextColor3 = Color3.fromRGB(130, 135, 150)
				lockedBtn.Font = Enum.Font.GothamBold
				lockedBtn.TextSize = 11
				lockedBtn.BorderSizePixel = 0
				lockedBtn.Parent = card

				local lCorner = Instance.new("UICorner")
				lCorner.CornerRadius = UDim.new(0, 6)
				lCorner.Parent = lockedBtn
			end
		end
	end

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	-- Animate In
	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function openRobuxEggModal()
	closeModal()

	local modal = createStyledFrame(screenGui, "RobuxEggModal", UDim2.new(0, 520, 0, 440), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(18, 20, 28))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local stroke = modal:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(255, 215, 60)
		stroke.Thickness = 2.0
	end

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "👑 EXCLUSIVE EGG 👑"
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(1, 0, 0, 20)
	subTitle.Position = UDim2.new(0, 0, 0, 42)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Monetized Developer Product • Price: 1,000 Robux (R$)"
	subTitle.TextColor3 = Color3.fromRGB(0, 230, 118)
	subTitle.Font = Enum.Font.GothamBold
	subTitle.TextSize = 13
	subTitle.Parent = modal

	-- Drops Container Card
	local dropsFrame = Instance.new("Frame")
	dropsFrame.Size = UDim2.new(0.92, 0, 0, 130)
	dropsFrame.Position = UDim2.new(0.04, 0, 0, 72)
	dropsFrame.BackgroundColor3 = Color3.fromRGB(26, 29, 40)
	dropsFrame.BorderSizePixel = 0
	dropsFrame.Parent = modal

	local dropsCorner = Instance.new("UICorner")
	dropsCorner.CornerRadius = UDim.new(0, 10)
	dropsCorner.Parent = dropsFrame

	local dropsHeader = Instance.new("TextLabel")
	dropsHeader.Size = UDim2.new(1, 0, 0, 26)
	dropsHeader.BackgroundTransparency = 1
	dropsHeader.Text = "✨ Guaranteed Mythic & Legendary Creatures ✨"
	dropsHeader.TextColor3 = Color3.fromRGB(220, 230, 255)
	dropsHeader.Font = Enum.Font.GothamBold
	dropsHeader.TextSize = 13
	dropsHeader.Parent = dropsFrame

	local dropItems = {
		{ name = "🐰 Neon Bunny", rarity = "Rare", chance = "50%", mult = "2.5x Gems", color = Color3.fromRGB(100, 220, 255) },
		{ name = "🔥 Inferno Drake", rarity = "Epic", chance = "35%", mult = "4.0x Gems", color = Color3.fromRGB(255, 140, 40) },
		{ name = "🌌 Void Phoenix", rarity = "Legendary", chance = "15%", mult = "7.5x Gems", color = Color3.fromRGB(220, 60, 255) },
	}

	for i, item in ipairs(dropItems) do
		local itemCard = Instance.new("Frame")
		itemCard.Size = UDim2.new(0.3, 0, 0, 85)
		itemCard.Position = UDim2.new(0.025 + (i - 1) * 0.325, 0, 0, 32)
		itemCard.BackgroundColor3 = Color3.fromRGB(34, 38, 54)
		itemCard.BorderSizePixel = 0
		itemCard.Parent = dropsFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = itemCard

		local itemTitle = Instance.new("TextLabel")
		itemTitle.Size = UDim2.new(1, 0, 0, 32)
		itemTitle.Position = UDim2.new(0, 0, 0, 4)
		itemTitle.BackgroundTransparency = 1
		itemTitle.Text = item.name
		itemTitle.TextColor3 = item.color
		itemTitle.Font = Enum.Font.GothamBold
		itemTitle.TextSize = 12
		itemTitle.Parent = itemCard

		local chanceLbl = Instance.new("TextLabel")
		chanceLbl.Size = UDim2.new(1, 0, 0, 22)
		chanceLbl.Position = UDim2.new(0, 0, 0, 34)
		chanceLbl.BackgroundTransparency = 1
		chanceLbl.Text = item.chance .. " Chance"
		chanceLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		chanceLbl.Font = Enum.Font.GothamBlack
		chanceLbl.TextSize = 13
		chanceLbl.Parent = itemCard

		local multLbl = Instance.new("TextLabel")
		multLbl.Size = UDim2.new(1, 0, 0, 20)
		multLbl.Position = UDim2.new(0, 0, 0, 58)
		multLbl.BackgroundTransparency = 1
		multLbl.Text = item.mult
		multLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
		multLbl.Font = Enum.Font.GothamMedium
		multLbl.TextSize = 11
		multLbl.Parent = itemCard
	end

	-- Info Text / Guidance Box
	local infoBox = Instance.new("Frame")
	infoBox.Size = UDim2.new(0.92, 0, 0, 78)
	infoBox.Position = UDim2.new(0.04, 0, 0, 212)
	infoBox.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	infoBox.BorderSizePixel = 0
	infoBox.Parent = modal

	local infoCorner = Instance.new("UICorner")
	infoCorner.CornerRadius = UDim.new(0, 8)
	infoCorner.Parent = infoBox

	local eggDef = PetConfig.EGGS.RobuxEgg
	local productId = (eggDef and eggDef.productId) or 0

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -16, 1, -10)
	infoLabel.Position = UDim2.new(0, 8, 0, 5)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.TextWrapped = true
	infoLabel.Font = Enum.Font.GothamMedium
	infoLabel.TextSize = 11

	if productId == 0 then
		infoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		infoLabel.Text = "⚙️ Studio Test Mode (Product ID = 0):\n• Click 'Buy for 1,000 R$' to test prompt logic.\n• Click 'Free Studio Test Hatch' to test hatching without Robux!\n• To enable real Robux: Create a Developer Product on Creator Hub and paste ID in PetConfig.luau."
	else
		infoLabel.TextColor3 = Color3.fromRGB(150, 255, 180)
		infoLabel.Text = string.format("🟢 Live Product Active (Product ID = %d):\n• Purchases charge 1,000 Robux via official Roblox modal.\n• Safe receipt processing handled automatically on server.", productId)
	end
	infoLabel.Parent = infoBox

	-- Action Buttons Container
	local btnContainer = Instance.new("Frame")
	btnContainer.Size = UDim2.new(0.92, 0, 0, 110)
	btnContainer.Position = UDim2.new(0.04, 0, 0, 302)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = modal

	-- Primary: Buy for 1,000 Robux
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(1, 0, 0, 48)
	buyBtn.Position = UDim2.new(0, 0, 0, 0)
	buyBtn.BackgroundColor3 = Color3.fromRGB(0, 190, 100)
	buyBtn.Text = "👑 Buy for 1,000 Robux (R$)"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextSize = 16
	buyBtn.BorderSizePixel = 0
	buyBtn.Parent = btnContainer

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		local fn = Remotes.getFunction("RequestRobuxEggAction")
		local ok, res = pcall(function()
			return fn:InvokeServer("PromptPurchase")
		end)
		if ok and res then
			if res.prompted then
				closeModal()
			elseif res.reason == "NO_PRODUCT_ID" then
				showFloatingPopup("⚙️ Product ID is 0! See info box.", Color3.fromRGB(255, 190, 50), 0)
			else
				showFloatingPopup("❌ " .. tostring(res.message or "Cannot prompt"), Color3.fromRGB(255, 90, 80), 0)
			end
		else
			showFloatingPopup("❌ Network error", Color3.fromRGB(255, 90, 80), 0)
		end
	end)

	-- Secondary: Free Studio Test Hatch
	local testBtn = Instance.new("TextButton")
	testBtn.Size = UDim2.new(1, 0, 0, 44)
	testBtn.Position = UDim2.new(0, 0, 0, 56)
	testBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 180)
	testBtn.Text = "🧪 Free Studio Test Hatch (No Robux Needed)"
	testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	testBtn.Font = Enum.Font.GothamBold
	testBtn.TextSize = 14
	testBtn.BorderSizePixel = 0
	testBtn.Parent = btnContainer

	local testCorner = Instance.new("UICorner")
	testCorner.CornerRadius = UDim.new(0, 10)
	testCorner.Parent = testBtn

	testBtn.MouseButton1Click:Connect(function()
		closeModal()
		local fn = Remotes.getFunction("RequestRobuxEggAction")
		local ok, res = pcall(function()
			return fn:InvokeServer("DevTestHatch")
		end)
		if not ok or not res or not res.success then
			showFloatingPopup("❌ Test hatch failed!", Color3.fromRGB(255, 90, 80), 0)
		end
	end)

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(closeModal)

	local tween = TweenService:Create(modal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})
	tween:Play()
end

local function openVIPModal()
	closeModal()

	local modal = createStyledFrame(screenGui, "VIPModal", UDim2.new(0, 500, 0, 440), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 32))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local stroke = modal:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(255, 215, 60)
		stroke.Thickness = 2.0
	end

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "👑 VIP MEMBERSHIP PASS 👑"
	title.TextColor3 = Color3.fromRGB(255, 215, 60)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(1, 0, 0, 20)
	subTitle.Position = UDim2.new(0, 0, 0, 42)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Permanent Gamepass • Price: 400 Robux (R$)"
	subTitle.TextColor3 = Color3.fromRGB(0, 230, 118)
	subTitle.Font = Enum.Font.GothamBold
	subTitle.TextSize = 13
	subTitle.Parent = modal

	-- Perks List
	local perksFrame = Instance.new("Frame")
	perksFrame.Size = UDim2.new(0.92, 0, 0, 140)
	perksFrame.Position = UDim2.new(0.04, 0, 0, 72)
	perksFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
	perksFrame.BorderSizePixel = 0
	perksFrame.Parent = modal

	local perksCorner = Instance.new("UICorner")
	perksCorner.CornerRadius = UDim.new(0, 10)
	perksCorner.Parent = perksFrame

	local perks = {
		"💎 2x GEMS MULTIPLIER on all mining, collectors & wheel!",
		"👑 Golden [VIP] Overhead Crown Badge & Prestige Chat Tag!",
		"⚡ +25% Faster Base Walkspeed permanently!",
		"✨ Exclusive Golden Aura particle sparkles!",
	}

	for i, perkText in ipairs(perks) do
		local pLabel = Instance.new("TextLabel")
		pLabel.Size = UDim2.new(1, -20, 0, 28)
		pLabel.Position = UDim2.new(0, 14, 0, 10 + (i - 1) * 30)
		pLabel.BackgroundTransparency = 1
		pLabel.Text = perkText
		pLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
		pLabel.Font = Enum.Font.GothamBold
		pLabel.TextSize = 12
		pLabel.TextXAlignment = Enum.TextXAlignment.Left
		pLabel.Parent = perksFrame
	end

	-- VIP Status Card
	local statusCard = Instance.new("Frame")
	statusCard.Size = UDim2.new(0.92, 0, 0, 50)
	statusCard.Position = UDim2.new(0.04, 0, 0, 222)
	statusCard.BackgroundColor3 = isLocalPlayerVIP and Color3.fromRGB(35, 60, 30) or Color3.fromRGB(35, 38, 50)
	statusCard.BorderSizePixel = 0
	statusCard.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = statusCard

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, 0, 1, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = isLocalPlayerVIP and "👑 YOUR VIP MEMBERSHIP IS ACTIVE (2x Perks Enabled!)" or "🔒 Status: Not Owned Yet"
	statusLbl.TextColor3 = isLocalPlayerVIP and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(200, 205, 220)
	statusLbl.Font = Enum.Font.GothamBlack
	statusLbl.TextSize = 13
	statusLbl.Parent = statusCard

	-- Action Buttons
	local btnContainer = Instance.new("Frame")
	btnContainer.Size = UDim2.new(0.92, 0, 0, 120)
	btnContainer.Position = UDim2.new(0.04, 0, 0, 282)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = modal

	-- Buy Button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(1, 0, 0, 48)
	buyBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 20)
	buyBtn.Text = "👑 Buy VIP Pass (400 Robux)"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextSize = 16
	buyBtn.BorderSizePixel = 0
	buyBtn.Parent = btnContainer

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		local fn = Remotes.getFunction("RequestGamepassAction")
		local ok, res = pcall(function()
			return fn:InvokeServer("PromptPass")
		end)
		if ok and res then
			if res.prompted then
				closeModal()
			elseif res.reason == "NO_PASS_ID" then
				showFloatingPopup("⚙️ Pass ID is 0! See Dev Test mode below.", Color3.fromRGB(255, 190, 50), 0)
			else
				showFloatingPopup("❌ " .. tostring(res.message or "Cannot prompt pass"), Color3.fromRGB(255, 90, 80), 0)
			end
		end
	end)

	-- Dev Test Toggle Button
	local testBtn = Instance.new("TextButton")
	testBtn.Size = UDim2.new(1, 0, 0, 44)
	testBtn.Position = UDim2.new(0, 0, 0, 56)
	testBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 130)
	testBtn.Text = "🧪 Toggle VIP Test Mode (Free In Studio)"
	testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	testBtn.Font = Enum.Font.GothamBold
	testBtn.TextSize = 14
	testBtn.BorderSizePixel = 0
	testBtn.Parent = btnContainer

	local testCorner = Instance.new("UICorner")
	testCorner.CornerRadius = UDim.new(0, 10)
	testCorner.Parent = testBtn

	testBtn.MouseButton1Click:Connect(function()
		local fn = Remotes.getFunction("RequestGamepassAction")
		local ok, res = pcall(function()
			return fn:InvokeServer("DevTestToggle")
		end)
		if ok and res and res.success then
			isLocalPlayerVIP = res.isVIP
			UIController.updateVIPDisplay(res.isVIP)
			openVIPModal() -- re-render modal with updated status
			showFloatingPopup("👑 VIP " .. (res.isVIP and "ACTIVATED (2x Gems)!" or "DEACTIVATED!"), Color3.fromRGB(255, 215, 0), 0)
		end
	end)

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(closeModal)

	local tween = TweenService:Create(modal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})
	tween:Play()
end

local function openEquipmentShopModal()
	closeModal()
	closeDialogue()

	if not cachedData then
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
		else
			return
		end
	end

	local modal = createStyledFrame(screenGui, "EquipmentShopModal", UDim2.new(0, 530, 0, 480), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 30))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	-- Header Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 42)
	title.BackgroundTransparency = 1
	title.Text = "🛒 BARNABY'S EQUIPMENT SHOP 🛒"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.Font = Enum.Font.Antique
	title.TextSize = 22
	title.Parent = modal

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(1, 0, 0, 20)
	subTitle.Position = UDim2.new(0, 0, 0, 38)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Equip pickaxes for higher mining power & backpacks for bonus multipliers!"
	subTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
	subTitle.Font = Enum.Font.Antique
	subTitle.TextSize = 14
	subTitle.Parent = modal

	-- Tab Switcher Bar
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(0.92, 0, 0, 40)
	tabBar.Position = UDim2.new(0.04, 0, 0, 66)
	tabBar.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = modal

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 8)
	tbCorner.Parent = tabBar

	local tabShovelBtn = Instance.new("TextButton")
	tabShovelBtn.Size = UDim2.new(0.5, -4, 1, -6)
	tabShovelBtn.Position = UDim2.new(0, 3, 0, 3)
	tabShovelBtn.Text = "⛏️ Shovels (Tools)"
	tabShovelBtn.Font = Enum.Font.Antique
	tabShovelBtn.TextSize = 15
	tabShovelBtn.BorderSizePixel = 0
	tabShovelBtn.Parent = tabBar

	local t1Corner = Instance.new("UICorner")
	t1Corner.CornerRadius = UDim.new(0, 6)
	t1Corner.Parent = tabShovelBtn

	local tabPackBtn = Instance.new("TextButton")
	tabPackBtn.Size = UDim2.new(0.5, -4, 1, -6)
	tabPackBtn.Position = UDim2.new(0.5, 1, 0, 3)
	tabPackBtn.Text = "🎒 Backpacks (Boosts)"
	tabPackBtn.Font = Enum.Font.Antique
	tabPackBtn.TextSize = 15
	tabPackBtn.BorderSizePixel = 0
	tabPackBtn.Parent = tabBar

	local t2Corner = Instance.new("UICorner")
	t2Corner.CornerRadius = UDim.new(0, 6)
	t2Corner.Parent = tabPackBtn

	-- Scrolling Items Container
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 350)
	scroll.Position = UDim2.new(0.04, 0, 0, 114)
	scroll.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll

	local function refreshItems()
		scroll:ClearAllChildren()
		local uilist = Instance.new("UIListLayout")
		uilist.Padding = UDim.new(0, 8)
		uilist.Parent = scroll

		-- Update Tab active styles
		if currentShopTab == "Shovel" then
			tabShovelBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
			tabShovelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			tabPackBtn.BackgroundColor3 = Color3.fromRGB(35, 39, 52)
			tabPackBtn.TextColor3 = Color3.fromRGB(170, 175, 190)
		else
			tabPackBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
			tabPackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			tabShovelBtn.BackgroundColor3 = Color3.fromRGB(35, 39, 52)
			tabShovelBtn.TextColor3 = Color3.fromRGB(170, 175, 190)
		end

		local items = if currentShopTab == "Shovel" then ShopConfig.SHOVELS else ShopConfig.BACKPACKS
		local ownedMap = if currentShopTab == "Shovel" then (cachedData.OwnedShovels or {}) else (cachedData.OwnedBackpacks or {})
		local equippedId = if currentShopTab == "Shovel" then cachedData.EquippedShovel else cachedData.EquippedBackpack

		for _, item in ipairs(items) do
			local isOwned = ownedMap[item.id] == true
			local isEquipped = (equippedId == item.id)

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 66)
			card.BackgroundColor3 = if isEquipped then Color3.fromRGB(36, 55, 46) else Color3.fromRGB(32, 35, 46)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 8)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = if isEquipped then Color3.fromRGB(0, 230, 118) else Color3.fromRGB(55, 62, 78)
			cStroke.Thickness = if isEquipped then 1.5 else 1
			cStroke.Parent = card

			-- Icon box
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 48, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = item.icon
			iconLabel.TextSize = 26
			iconLabel.Parent = card

			-- Name Label
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.55, 0, 0, 24)
			nameLabel.Position = UDim2.new(0, 52, 0, 8)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = item.name
			nameLabel.TextColor3 = item.color
			nameLabel.Font = Enum.Font.Antique
			nameLabel.TextSize = 16
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = card

			-- Stat perks line
			local perkLabel = Instance.new("TextLabel")
			perkLabel.Size = UDim2.new(0.55, 0, 0, 20)
			perkLabel.Position = UDim2.new(0, 52, 0, 34)
			perkLabel.BackgroundTransparency = 1
			perkLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
			perkLabel.Font = Enum.Font.Antique
			perkLabel.TextSize = 13
			perkLabel.TextXAlignment = Enum.TextXAlignment.Left

			if item.category == "Shovel" then
				local sh = item :: ShopConfig.ShovelDef
				local gemBonusText = if sh.clickGems > 0 then string.format(" • +%d 💎/Click", sh.clickGems) else ""
				perkLabel.Text = string.format("⚡ x%.1fx Power/Click • +$%s Cash%s", sh.powerMultiplier, FormatNumber.formatCompact(sh.clickCash), gemBonusText)
			else
				local bp = item :: ShopConfig.BackpackDef
				local gemBonusText = if bp.bonusGems > 0 then string.format(" • +%d 💎/Ore", bp.bonusGems) else ""
				perkLabel.Text = string.format("+%.0f%% Mining Cash%s", (bp.multiplier - 1) * 100, gemBonusText)
			end
			perkLabel.Parent = card

			-- Action Button
			local actionBtn = Instance.new("TextButton")
			actionBtn.Size = UDim2.new(0.32, 0, 0, 42)
			actionBtn.Position = UDim2.new(0.65, 0, 0.5, -21)
			actionBtn.Font = Enum.Font.Antique
			actionBtn.TextSize = 14
			actionBtn.BorderSizePixel = 0
			actionBtn.Parent = card

			local aCorner = Instance.new("UICorner")
			aCorner.CornerRadius = UDim.new(0, 8)
			aCorner.Parent = actionBtn

			if isEquipped then
				actionBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
				actionBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
				actionBtn.Text = "EQUIPPED"
			elseif isOwned then
				actionBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 230)
				actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				actionBtn.Text = "EQUIP"
				actionBtn.MouseButton1Click:Connect(function()
					local equipFn = Remotes.getFunction("EquipShopItem")
					local ok, success, msg = pcall(function()
						return equipFn:InvokeServer(item.category, item.id)
					end)
					if ok and success then
						if item.category == "Shovel" then
							cachedData.EquippedShovel = item.id
						else
							cachedData.EquippedBackpack = item.id
						end
						showFloatingPopup("Equipped " .. item.name .. "!", Color3.fromRGB(0, 230, 118))
						refreshItems()
					end
				end)
			else
				local canAfford = (cachedData.Cash or 0) >= item.cost
				actionBtn.BackgroundColor3 = if canAfford then Color3.fromRGB(0, 180, 100) else Color3.fromRGB(80, 50, 55)
				actionBtn.TextColor3 = if canAfford then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(200, 150, 150)
				actionBtn.Text = if canAfford then ("$" .. FormatNumber.formatCompact(item.cost) .. " BUY") else ("$" .. FormatNumber.formatCompact(item.cost))

				actionBtn.MouseButton1Click:Connect(function()
					local buyFn = Remotes.getFunction("BuyShopItem")
					local ok, success, msg = pcall(function()
						return buyFn:InvokeServer(item.category, item.id)
					end)
					if ok and success then
						showFloatingPopup("Bought " .. item.name .. "!", Color3.fromRGB(255, 215, 0))
						local getFn = Remotes.getFunction("GetPlayerData")
						local okData, freshData = pcall(function()
							return getFn:InvokeServer()
						end)
						if okData and freshData then
							cachedData = freshData
						end
						UIController.updateHUD()
						refreshItems()
					else
						showFloatingPopup(tostring(msg or "Cannot purchase"), Color3.fromRGB(255, 90, 80))
					end
				end)
			end
		end

		scroll.CanvasSize = UDim2.new(0, 0, 0, #items * 76)
	end

	tabShovelBtn.MouseButton1Click:Connect(function()
		currentShopTab = "Shovel"
		refreshItems()
	end)

	tabPackBtn.MouseButton1Click:Connect(function()
		currentShopTab = "Backpack"
		refreshItems()
	end)

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	refreshItems()

	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function openWheelModal()
	closeModal()
	closeDialogue()

	if not screenGui then return end

	if not cachedData then
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
		end
	end

	-- Sleek Monochrome Modal (Pure Black & White)
	local modal = createStyledFrame(screenGui, "WheelModal", UDim2.new(0, 480, 0, 560), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(14, 14, 16))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Thickness = 2
	modalStroke.Color = Color3.fromRGB(255, 255, 255)
	modalStroke.Transparency = 0.3
	modalStroke.Parent = modal

	-- Close Button (Monochrome)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -42, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.ZIndex = 20
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = 1.5
	closeStroke.Color = Color3.fromRGB(255, 255, 255)
	closeStroke.Transparency = 0.5
	closeStroke.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	-- Header Title (Stark Pure White)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "LUCKY WHEEL OF FORTUNE"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.Antique
	title.TextSize = 24
	title.ZIndex = 10
	title.Parent = modal

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 2
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Parent = title

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(1, 0, 0, 18)
	subTitle.Position = UDim2.new(0, 0, 0, 44)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Spin to win Cash, Gem Boosts, or Mythic Pets"
	subTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	subTitle.Font = Enum.Font.Antique
	subTitle.TextSize = 14
	subTitle.ZIndex = 10
	subTitle.Parent = modal

	-- WHEEL CONTAINER (Circular monochrome frame)
	local wheelContainer = Instance.new("Frame")
	wheelContainer.Name = "WheelContainer"
	wheelContainer.Size = UDim2.new(0, 340, 0, 340)
	wheelContainer.Position = UDim2.new(0.5, 0, 0, 238)
	wheelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	wheelContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	wheelContainer.BorderSizePixel = 0
	wheelContainer.ZIndex = 5
	wheelContainer.Parent = modal

	local wCorner = Instance.new("UICorner")
	wCorner.CornerRadius = UDim.new(1, 0)
	wCorner.Parent = wheelContainer

	-- White casing ring stroke
	local wStroke = Instance.new("UIStroke")
	wStroke.Thickness = 4
	wStroke.Color = Color3.fromRGB(255, 255, 255)
	wStroke.Parent = wheelContainer

	-- ROTATING DISC
	local wheelDisc = Instance.new("Frame")
	wheelDisc.Name = "WheelDisc"
	wheelDisc.Size = UDim2.new(1, 0, 1, 0)
	wheelDisc.Position = UDim2.new(0.5, 0, 0.5, 0)
	wheelDisc.AnchorPoint = Vector2.new(0.5, 0.5)
	wheelDisc.BackgroundTransparency = 1
	wheelDisc.ZIndex = 6
	wheelDisc.Rotation = 0
	wheelDisc.Parent = wheelContainer

	local sliceWedges: { [number]: Frame } = {}

	-- Populate 8 Slices (Monochrome)
	for i = 1, 8 do
		local sliceDef = WheelConfig.SLICES[i]
		local angle = (i - 1) * 45

		local sliceHolder = Instance.new("Frame")
		sliceHolder.Name = "SliceHolder_" .. i
		sliceHolder.Size = UDim2.new(1, 0, 1, 0)
		sliceHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
		sliceHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		sliceHolder.BackgroundTransparency = 1
		sliceHolder.Rotation = angle
		sliceHolder.ZIndex = 7
		sliceHolder.Parent = wheelDisc

		-- Wedge card positioned radially at top of rotation
		local wedge = Instance.new("Frame")
		wedge.Name = "Wedge"
		wedge.Size = UDim2.new(0, 86, 0, 64)
		wedge.Position = UDim2.new(0.5, 0, 0, 14)
		wedge.AnchorPoint = Vector2.new(0.5, 0)
		wedge.BackgroundColor3 = sliceDef.color
		wedge.BorderSizePixel = 0
		wedge.ZIndex = 8
		wedge.Parent = sliceHolder

		local wedgeCorner = Instance.new("UICorner")
		wedgeCorner.CornerRadius = UDim.new(0, 8)
		wedgeCorner.Parent = wedge

		local wedgeStroke = Instance.new("UIStroke")
		wedgeStroke.Thickness = 1.5
		wedgeStroke.Color = Color3.fromRGB(255, 255, 255)
		wedgeStroke.Transparency = 0.5
		wedgeStroke.Parent = wedge

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0, 20)
		iconLabel.Position = UDim2.new(0, 0, 0, 4)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = sliceDef.icon
		iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 13
		iconLabel.ZIndex = 9
		iconLabel.Parent = wedge

		local valLabel = Instance.new("TextLabel")
		valLabel.Size = UDim2.new(1, -6, 0, 18)
		valLabel.Position = UDim2.new(0, 3, 0, 24)
		valLabel.BackgroundTransparency = 1
		valLabel.Text = sliceDef.label
		valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		valLabel.Font = Enum.Font.GothamBold
		valLabel.TextSize = 11
		valLabel.TextWrapped = true
		valLabel.ZIndex = 9
		valLabel.Parent = wedge

		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 2.0
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Parent = valLabel

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(1, 0, 0, 14)
		rarityLabel.Position = UDim2.new(0, 0, 1, -16)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = string.upper(sliceDef.rarity)
		rarityLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		rarityLabel.Font = Enum.Font.GothamMedium
		rarityLabel.TextSize = 8
		rarityLabel.ZIndex = 9
		rarityLabel.Parent = wedge

		sliceWedges[i] = wedge
	end

	-- Center Hub (White circle with black label)
	local centerHub = Instance.new("Frame")
	centerHub.Name = "CenterHub"
	centerHub.Size = UDim2.new(0, 56, 0, 56)
	centerHub.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerHub.AnchorPoint = Vector2.new(0.5, 0.5)
	centerHub.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	centerHub.BorderSizePixel = 0
	centerHub.ZIndex = 12
	centerHub.Parent = wheelContainer

	local hubCorner = Instance.new("UICorner")
	hubCorner.CornerRadius = UDim.new(1, 0)
	hubCorner.Parent = centerHub

	local hubStroke = Instance.new("UIStroke")
	hubStroke.Thickness = 2.5
	hubStroke.Color = Color3.fromRGB(0, 0, 0)
	hubStroke.Parent = centerHub

	local hubIcon = Instance.new("TextLabel")
	hubIcon.Size = UDim2.new(1, 0, 1, 0)
	hubIcon.BackgroundTransparency = 1
	hubIcon.Text = "SPIN"
	hubIcon.TextColor3 = Color3.fromRGB(0, 0, 0)
	hubIcon.Font = Enum.Font.GothamBlack
	hubIcon.TextSize = 14
	hubIcon.ZIndex = 13
	hubIcon.Parent = centerHub

	-- Pointer / Ticker Arrow (Monochrome)
	local pointer = Instance.new("TextLabel")
	pointer.Name = "WheelPointer"
	pointer.Size = UDim2.new(0, 36, 0, 36)
	pointer.Position = UDim2.new(0.5, 0, 0, -14)
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.BackgroundTransparency = 1
	pointer.Text = "▼"
	pointer.TextColor3 = Color3.fromRGB(255, 255, 255)
	pointer.TextSize = 34
	pointer.Font = Enum.Font.GothamBlack
	pointer.ZIndex = 15
	pointer.Parent = wheelContainer

	local pStroke = Instance.new("UIStroke")
	pStroke.Thickness = 3
	pStroke.Color = Color3.fromRGB(0, 0, 0)
	pStroke.Parent = pointer

	-- Status / Cooldown Text (White & Light Gray)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.Position = UDim2.new(0, 0, 1, -114)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Checking spin status..."
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 13
	statusLabel.ZIndex = 10
	statusLabel.Parent = modal

	-- Main Spin Button (High-Contrast White & Black)
	local spinBtn = Instance.new("TextButton")
	spinBtn.Name = "SpinActionBtn"
	spinBtn.Size = UDim2.new(0, 240, 0, 48)
	spinBtn.Position = UDim2.new(0.5, -120, 1, -88)
	spinBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	spinBtn.Text = "SPIN (FREE)"
	spinBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	spinBtn.Font = Enum.Font.GothamBlack
	spinBtn.TextSize = 16
	spinBtn.BorderSizePixel = 0
	spinBtn.ZIndex = 10
	spinBtn.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 10)
	sCorner.Parent = spinBtn

	local sStroke = Instance.new("UIStroke")
	sStroke.Thickness = 2
	sStroke.Color = Color3.fromRGB(0, 0, 0)
	sStroke.Parent = spinBtn

	-- Inversion on hover
	spinBtn.MouseEnter:Connect(function()
		if not isSpinningWheel then
			spinBtn.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		end
	end)
	spinBtn.MouseLeave:Connect(function()
		if not isSpinningWheel then
			spinBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)

	-- Dev / Fast Test Spin Button (Instant test simulator feature)
	local testSpinBtn = Instance.new("TextButton")
	testSpinBtn.Name = "TestSpinBtn"
	testSpinBtn.Size = UDim2.new(0, 150, 0, 28)
	testSpinBtn.Position = UDim2.new(0.5, -75, 1, -34)
	testSpinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	testSpinBtn.Text = "Test Spin (Free)"
	testSpinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	testSpinBtn.Font = Enum.Font.GothamBold
	testSpinBtn.TextSize = 11
	testSpinBtn.BorderSizePixel = 0
	testSpinBtn.ZIndex = 10
	testSpinBtn.Parent = modal

	local tsCorner = Instance.new("UICorner")
	tsCorner.CornerRadius = UDim.new(0, 6)
	tsCorner.Parent = testSpinBtn

	local tsStroke = Instance.new("UIStroke")
	tsStroke.Thickness = 1
	tsStroke.Color = Color3.fromRGB(255, 255, 255)
	tsStroke.Transparency = 0.6
	tsStroke.Parent = testSpinBtn

	-- State update function for buttons & countdown
	local function updateSpinStatus()
		if not modal.Parent then return end
		local now = os.time()
		local lastSpin = (cachedData and cachedData.LastWheelSpin) or 0
		local elapsed = now - lastSpin
		local hasFree = (cachedData and cachedData.FreeSpins and cachedData.FreeSpins > 0) or (elapsed >= WheelConfig.COOLDOWN_SECONDS)

		if hasFree then
			statusLabel.Text = "FREE SPIN AVAILABLE"
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			spinBtn.Text = "SPIN (FREE)"
		else
			local remaining = math.max(0, WheelConfig.COOLDOWN_SECONDS - elapsed)
			local mins = math.floor(remaining / 60)
			local secs = remaining % 60
			statusLabel.Text = string.format("Next free spin in: %02d:%02d", mins, secs)
			statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
			spinBtn.Text = "SPIN (50 GEMS)"
		end
	end

	updateSpinStatus()

	-- Live status refresh loop while modal is open
	task.spawn(function()
		while modal.Parent and not isSpinningWheel do
			task.wait(1)
			updateSpinStatus()
		end
	end)

	-- Execute Spin Action
	local function doSpin(isTestSpin: boolean?)
		if isSpinningWheel then return end
		isSpinningWheel = true
		spinBtn.AutoButtonColor = false
		spinBtn.Text = "SPINNING..."
		testSpinBtn.Visible = false

		local now = os.time()
		local lastSpin = (cachedData and cachedData.LastWheelSpin) or 0
		local elapsed = now - lastSpin
		local hasFree = (cachedData and cachedData.FreeSpins and cachedData.FreeSpins > 0) or (elapsed >= WheelConfig.COOLDOWN_SECONDS)

		local spinMode = "Free"
		if isTestSpin then
			spinMode = "Test"
		elseif not hasFree then
			spinMode = "Gems"
		end

		local spinFn = Remotes.getFunction("SpinWheel")
		local ok, result = pcall(function()
			return spinFn:InvokeServer(spinMode)
		end)

		if not ok or not result or not result.success then
			local errMsg = if result and result.message then result.message else "Failed to spin wheel!"
			showFloatingPopup(errMsg, Color3.fromRGB(255, 255, 255))
			isSpinningWheel = false
			spinBtn.AutoButtonColor = true
			testSpinBtn.Visible = true
			updateSpinStatus()
			return
		end

		-- SUCCESS: Animate the wheel to target slice with full power every time!
		local sliceIndex = result.sliceIndex :: number
		local targetAngle = (360 - ((sliceIndex - 1) * 45)) % 360
		local currentAngle = wheelDisc.Rotation % 360
		local deltaAngle = (targetAngle - currentAngle) % 360
		if deltaAngle <= 0 then
			deltaAngle += 360
		end

		local fullRotations = 6 * 360 -- 6 full high-power revolutions (2,160 degrees)
		local targetRotation = wheelDisc.Rotation + fullRotations + deltaAngle

		-- Sound effect & Pointer bounce during spin
		local spinDuration = 3.8
		local lastTickAngle = wheelDisc.Rotation
		local tickConnection: RBXScriptConnection? = nil

		tickConnection = RunService.RenderStepped:Connect(function()
			local current = wheelDisc.Rotation
			if math.abs(current - lastTickAngle) >= 45 then
				lastTickAngle = current
				-- Soft mechanical click
				local s = Instance.new("Sound")
				s.SoundId = "rbxassetid://6895079853"
				s.Volume = 0.05
				s.PlaybackSpeed = 2.0 + (math.random() * 0.4)
				s.Parent = SoundService
				s:Play()
				s.Ended:Connect(function() s:Destroy() end)

				-- Pointer flick
				pointer.Rotation = -16
				TweenService:Create(pointer, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Rotation = 0,
				}):Play()
			end
		end)

		local spinTween = TweenService:Create(wheelDisc, TweenInfo.new(spinDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Rotation = targetRotation,
		})

		spinTween:Play()
		spinTween.Completed:Connect(function()
			if tickConnection then
				tickConnection:Disconnect()
				tickConnection = nil
			end
			pointer.Rotation = 0

			-- Winning wedge pulse
			local winningWedge = sliceWedges[sliceIndex]
			if winningWedge then
				TweenService:Create(winningWedge, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 3, true), {
					Size = UDim2.new(0, 96, 0, 72),
				}):Play()
			end

			-- Play sound
			local winSound = Instance.new("Sound")
			winSound.SoundId = "rbxassetid://6895079853"
			winSound.Volume = 0.12
			winSound.PlaybackSpeed = 1.0
			winSound.Parent = SoundService
			winSound:Play()
			winSound.Ended:Connect(function() winSound:Destroy() end)

			showFloatingPopup(result.rewardDisplay, Color3.fromRGB(255, 255, 255), 0)

			-- Monochrome Celebration Winner Card
			local winCard = Instance.new("Frame")
			winCard.Name = "WinCard"
			winCard.Size = UDim2.new(0, 360, 0, 160)
			winCard.Position = UDim2.new(0.5, 0, 0.5, 0)
			winCard.AnchorPoint = Vector2.new(0.5, 0.5)
			winCard.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
			winCard.BorderSizePixel = 0
			winCard.ZIndex = 25
			winCard.Parent = modal

			local wcCorner = Instance.new("UICorner")
			wcCorner.CornerRadius = UDim.new(0, 12)
			wcCorner.Parent = winCard

			local wcStroke = Instance.new("UIStroke")
			wcStroke.Thickness = 2.5
			wcStroke.Color = Color3.fromRGB(255, 255, 255)
			wcStroke.Parent = winCard

			local winTitle = Instance.new("TextLabel")
			winTitle.Size = UDim2.new(1, 0, 0, 32)
			winTitle.Position = UDim2.new(0, 0, 0, 16)
			winTitle.BackgroundTransparency = 1
			winTitle.Text = "YOU WON!"
			winTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
			winTitle.Font = Enum.Font.Antique
			winTitle.TextSize = 24
			winTitle.ZIndex = 26
			winTitle.Parent = winCard

			local winReward = Instance.new("TextLabel")
			winReward.Size = UDim2.new(1, -20, 0, 40)
			winReward.Position = UDim2.new(0, 10, 0, 52)
			winReward.BackgroundTransparency = 1
			winReward.Text = result.rewardDisplay
			winReward.TextColor3 = Color3.fromRGB(255, 255, 255)
			winReward.Font = Enum.Font.GothamBold
			winReward.TextSize = 17
			winReward.TextWrapped = true
			winReward.ZIndex = 26
			winReward.Parent = winCard

			local okBtn = Instance.new("TextButton")
			okBtn.Size = UDim2.new(0, 140, 0, 36)
			okBtn.Position = UDim2.new(0.5, -70, 1, -46)
			okBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			okBtn.Text = "CONTINUE"
			okBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
			okBtn.Font = Enum.Font.GothamBold
			okBtn.TextSize = 13
			okBtn.BorderSizePixel = 0
			okBtn.ZIndex = 26
			okBtn.Parent = winCard

			local okCorner = Instance.new("UICorner")
			okCorner.CornerRadius = UDim.new(0, 8)
			okCorner.Parent = okBtn

			okBtn.MouseButton1Click:Connect(function()
				winCard:Destroy()
				isSpinningWheel = false
				spinBtn.AutoButtonColor = true
				testSpinBtn.Visible = true
				updateSpinStatus()
			end)
		end)
	end

	spinBtn.MouseButton1Click:Connect(function()
		doSpin(false)
	end)

	testSpinBtn.MouseButton1Click:Connect(function()
		doSpin(true)
	end)

	-- Entrance animation
	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function openTrailsShopModal()
	closeModal()
	closeDialogue()

	if not cachedData then
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
		else
			return
		end
	end

	local modal = createStyledFrame(screenGui, "TrailsShopModal", UDim2.new(0, 560, 0, 510), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(22, 20, 32))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	-- Header Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 38)
	title.BackgroundTransparency = 1
	title.Text = "✨ ZEPHYR'S TRAIL SANCTUARY ✨"
	title.TextColor3 = Color3.fromRGB(220, 160, 255)
	title.Font = Enum.Font.Antique
	title.TextSize = 22
	title.Parent = modal

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(1, 0, 0, 20)
	subTitle.Position = UDim2.new(0, 0, 0, 36)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Equip mystical trails for Speed, Cash Multipliers, Gems & Boss Damage!"
	subTitle.TextColor3 = Color3.fromRGB(180, 185, 215)
	subTitle.Font = Enum.Font.Antique
	subTitle.TextSize = 13
	subTitle.Parent = modal

	-- Scrolling Items Container
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 420)
	scroll.Position = UDim2.new(0.04, 0, 0, 68)
	scroll.BackgroundColor3 = Color3.fromRGB(26, 24, 38)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = scroll

	local function refreshTrails()
		scroll:ClearAllChildren()
		local uilist = Instance.new("UIListLayout")
		uilist.Padding = UDim.new(0, 8)
		uilist.Parent = scroll

		local ownedTrails = cachedData.OwnedTrails or {}
		local equippedId = cachedData.EquippedTrail

		for _, trailId in ipairs(TrailConfig.TRAIL_ORDER) do
			local trail = TrailConfig.TRAILS[trailId]
			if not trail then continue end

			local isOwned = ownedTrails[trailId] == true
			local isEquipped = (equippedId == trailId)

			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.96, 0, 0, 78)
			card.BackgroundColor3 = if isEquipped then Color3.fromRGB(42, 32, 64) else Color3.fromRGB(32, 29, 44)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 8)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = if isEquipped then Color3.fromRGB(180, 80, 255) else Color3.fromRGB(60, 52, 80)
			cStroke.Thickness = if isEquipped then 2 else 1
			cStroke.Parent = card

			-- Icon box
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 52, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = trail.icon
			iconLabel.TextSize = 30
			iconLabel.Parent = card

			-- Name Label
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.55, 0, 0, 22)
			nameLabel.Position = UDim2.new(0, 54, 0, 6)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = trail.name
			nameLabel.TextColor3 = Color3.fromRGB(255, 235, 140)
			nameLabel.Font = Enum.Font.Antique
			nameLabel.TextSize = 16
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = card

			-- Perks Line 1 (Speed & Cash)
			local perkLine1 = Instance.new("TextLabel")
			perkLine1.Size = UDim2.new(0.55, 0, 0, 18)
			perkLine1.Position = UDim2.new(0, 54, 0, 30)
			perkLine1.BackgroundTransparency = 1
			perkLine1.TextColor3 = Color3.fromRGB(200, 215, 240)
			perkLine1.Font = Enum.Font.Antique
			perkLine1.TextSize = 12
			perkLine1.TextXAlignment = Enum.TextXAlignment.Left
			local cashBonusPct = math.floor((trail.cashMultiplier - 1.0) * 100 + 0.5)
			perkLine1.Text = string.format("👟 +%d Speed   💰 +%d%% Cash", trail.speedBonus, cashBonusPct)
			perkLine1.Parent = card

			-- Perks Line 2 (Gems & Boss Dmg)
			local perkLine2 = Instance.new("TextLabel")
			perkLine2.Size = UDim2.new(0.55, 0, 0, 18)
			perkLine2.Position = UDim2.new(0, 54, 0, 50)
			perkLine2.BackgroundTransparency = 1
			perkLine2.TextColor3 = Color3.fromRGB(180, 235, 210)
			perkLine2.Font = Enum.Font.Antique
			perkLine2.TextSize = 12
			perkLine2.TextXAlignment = Enum.TextXAlignment.Left
			local bossBonusPct = math.floor((trail.bossMultiplier - 1.0) * 100 + 0.5)
			local bossText = if bossBonusPct > 0 then string.format("   ⚔️ +%d%% Boss Dmg", bossBonusPct) else ""
			local gemText = if trail.bonusGems > 0 then string.format("💎 +%d Gems/Ore", trail.bonusGems) else "💎 +0 Gems"
			perkLine2.Text = string.format("%s%s", gemText, bossText)
			perkLine2.Parent = card

			-- Action Button
			local actionBtn = Instance.new("TextButton")
			actionBtn.Size = UDim2.new(0.30, 0, 0, 42)
			actionBtn.Position = UDim2.new(0.67, 0, 0.5, -21)
			actionBtn.Font = Enum.Font.Antique
			actionBtn.TextSize = 14
			actionBtn.BorderSizePixel = 0
			actionBtn.Parent = card

			local aCorner = Instance.new("UICorner")
			aCorner.CornerRadius = UDim.new(0, 8)
			aCorner.Parent = actionBtn

			if isEquipped then
				actionBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 75)
				actionBtn.TextColor3 = Color3.fromRGB(230, 255, 230)
				actionBtn.Text = "EQUIPPED"
				actionBtn.MouseButton1Click:Connect(function()
					local unequipFn = Remotes.getFunction("UnequipTrail")
					local ok, success, msg = pcall(function()
						return unequipFn:InvokeServer()
					end)
					if ok and success then
						cachedData.EquippedTrail = nil
						showFloatingPopup("Unequipped trail!", Color3.fromRGB(200, 200, 200))
						refreshTrails()
						UIController.updateHUD()
					end
				end)
			elseif isOwned then
				actionBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 240)
				actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				actionBtn.Text = "EQUIP"
				actionBtn.MouseButton1Click:Connect(function()
					local equipFn = Remotes.getFunction("EquipTrail")
					local ok, success, msg = pcall(function()
						return equipFn:InvokeServer(trailId)
					end)
					if ok and success then
						cachedData.EquippedTrail = trailId
						showFloatingPopup("Equipped " .. trail.name .. "!", Color3.fromRGB(180, 80, 255))
						refreshTrails()
						UIController.updateHUD()
					else
						showFloatingPopup(tostring(msg or "Failed to equip"), Color3.fromRGB(255, 90, 80))
					end
				end)
			else
				local canAfford = (cachedData.Gems or 0) >= trail.cost
				actionBtn.BackgroundColor3 = if canAfford then Color3.fromRGB(160, 40, 220) else Color3.fromRGB(75, 40, 60)
				actionBtn.TextColor3 = if canAfford then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(200, 160, 175)
				actionBtn.Text = "💎 " .. FormatNumber.formatCompact(trail.cost) .. " BUY"

				actionBtn.MouseButton1Click:Connect(function()
					local buyFn = Remotes.getFunction("BuyTrail")
					local ok, success, msg = pcall(function()
						return buyFn:InvokeServer(trailId)
					end)
					if ok and success then
						showFloatingPopup("Unlocked " .. trail.name .. "!", Color3.fromRGB(220, 160, 255))
						local getFn = Remotes.getFunction("GetPlayerData")
						local okData, freshData = pcall(function()
							return getFn:InvokeServer()
						end)
						if okData and freshData then
							cachedData = freshData
						end
						UIController.updateHUD()
						refreshTrails()
					else
						showFloatingPopup(tostring(msg or "Cannot purchase"), Color3.fromRGB(255, 90, 80))
					end
				end)
			end
		end

		scroll.CanvasSize = UDim2.new(0, 0, 0, #TrailConfig.TRAIL_ORDER * 86)
	end

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -42, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	refreshTrails()

	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function openUpgradeTreeModal()
	if activeModal and activeModal.Name == "UpgradeTreeModal" then
		closeModal()
		return
	end

	closeModal()
	closeDialogue()

	if not screenGui then return end

	if not cachedData then
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
		else
			return
		end
	end

	-- Fullscreen Modal Container (Deep cosmic slate-navy, NOT pitch black)
	local modal = Instance.new("Frame")
	modal.Name = "UpgradeTreeModal"
	modal.Size = UDim2.new(1, 0, 1, 0)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.new(0.5, 0, 0.5, 0)
	modal.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	modal.BorderSizePixel = 0
	modal.ZIndex = 40
	modal.Parent = screenGui
	activeModal = modal

	-- Atmospheric background gradient (cosmic deep slate / indigo)
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 30, 48)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 18, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 13, 20)),
	})
	bgGradient.Rotation = 45
	bgGradient.Parent = modal

	-- Cosmic Ambient Stars / Dust particles across modal background
	local starContainer = Instance.new("Frame")
	starContainer.Name = "Starfield"
	starContainer.Size = UDim2.new(1, 0, 1, 0)
	starContainer.BackgroundTransparency = 1
	starContainer.ZIndex = 40
	starContainer.Parent = modal

	local starSeeds = {
		{ 0.08, 0.15, 3, 0.6, Color3.fromRGB(160, 210, 255) },
		{ 0.14, 0.42, 2, 0.7, Color3.fromRGB(255, 230, 150) },
		{ 0.22, 0.78, 4, 0.5, Color3.fromRGB(255, 180, 220) },
		{ 0.31, 0.18, 2, 0.7, Color3.fromRGB(180, 240, 255) },
		{ 0.45, 0.22, 3, 0.6, Color3.fromRGB(255, 220, 120) },
		{ 0.58, 0.14, 2, 0.8, Color3.fromRGB(200, 230, 255) },
		{ 0.72, 0.30, 3, 0.6, Color3.fromRGB(255, 200, 140) },
		{ 0.85, 0.20, 2, 0.7, Color3.fromRGB(160, 220, 255) },
		{ 0.92, 0.55, 4, 0.5, Color3.fromRGB(220, 180, 255) },
		{ 0.82, 0.80, 3, 0.6, Color3.fromRGB(180, 255, 220) },
		{ 0.68, 0.88, 2, 0.7, Color3.fromRGB(255, 230, 160) },
		{ 0.38, 0.85, 3, 0.6, Color3.fromRGB(200, 190, 255) },
		{ 0.18, 0.88, 2, 0.8, Color3.fromRGB(180, 230, 255) },
		{ 0.05, 0.62, 3, 0.7, Color3.fromRGB(255, 210, 160) },
		{ 0.95, 0.35, 2, 0.6, Color3.fromRGB(255, 255, 255) },
		{ 0.28, 0.52, 2, 0.75, Color3.fromRGB(255, 240, 180) },
		{ 0.76, 0.58, 3, 0.65, Color3.fromRGB(190, 230, 255) },
		{ 0.52, 0.80, 2, 0.7, Color3.fromRGB(255, 200, 255) },
	}
	for _, s in ipairs(starSeeds) do
		local star = Instance.new("Frame")
		star.Size = UDim2.new(0, s[3], 0, s[3])
		star.Position = UDim2.new(s[1], 0, s[2], 0)
		star.BackgroundColor3 = s[5]
		star.BackgroundTransparency = s[4]
		star.BorderSizePixel = 0
		star.ZIndex = 40
		star.Parent = starContainer

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(1, 0)
		sCorner.Parent = star
	end

	-- Top Header Bar
	local header = Instance.new("Frame")
	header.Name = "HeaderBar"
	header.Size = UDim2.new(1, 0, 0, 68)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	header.BorderSizePixel = 0
	header.ZIndex = 50
	header.Parent = modal

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Thickness = 1.5
	headerStroke.Color = Color3.fromRGB(0, 210, 150)
	headerStroke.Transparency = 0.5
	headerStroke.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.38, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 24, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🌟 ANCIENT TALENT TREE 🌟"
	titleLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	titleLabel.Font = Enum.Font.Antique
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 51
	titleLabel.Parent = header

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(0.38, 0, 0, 18)
	subTitle.Position = UDim2.new(0, 24, 0, 40)
	subTitle.BackgroundTransparency = 1
	subTitle.Text = "Awaken the central core to expand outward into ancient talent branches"
	subTitle.TextColor3 = Color3.fromRGB(165, 185, 210)
	subTitle.Font = Enum.Font.Antique
	subTitle.TextSize = 13
	subTitle.TextXAlignment = Enum.TextXAlignment.Left
	subTitle.ZIndex = 51
	subTitle.Parent = header

	-- Live Currency Display (Gems Badge)
	local gemsBadge = Instance.new("TextLabel")
	gemsBadge.Size = UDim2.new(0, 135, 0, 38)
	gemsBadge.Position = UDim2.new(1, -415, 0.5, -19)
	gemsBadge.BackgroundColor3 = Color3.fromRGB(26, 22, 42)
	gemsBadge.Text = "💎 " .. FormatNumber.formatCompact(cachedData.Gems or 0)
	gemsBadge.TextColor3 = Color3.fromRGB(0, 255, 230)
	gemsBadge.Font = Enum.Font.GothamBold
	gemsBadge.TextSize = 13
	gemsBadge.BorderSizePixel = 0
	gemsBadge.ZIndex = 51
	gemsBadge.Parent = header

	local gbCorner = Instance.new("UICorner")
	gbCorner.CornerRadius = UDim.new(0, 8)
	gbCorner.Parent = gemsBadge

	local gbStroke = Instance.new("UIStroke")
	gbStroke.Thickness = 1
	gbStroke.Color = Color3.fromRGB(160, 60, 230)
	gbStroke.Parent = gemsBadge

	-- Quick Dev Cheat Button to test talent unlocking seamlessly
	local devGemsBtn = Instance.new("TextButton")
	devGemsBtn.Size = UDim2.new(0, 130, 0, 38)
	devGemsBtn.Position = UDim2.new(1, -265, 0.5, -19)
	devGemsBtn.BackgroundColor3 = Color3.fromRGB(90, 45, 140)
	devGemsBtn.Text = "⚡ +50K 💎 (Dev)"
	devGemsBtn.TextColor3 = Color3.fromRGB(255, 225, 120)
	devGemsBtn.Font = Enum.Font.GothamBold
	devGemsBtn.TextSize = 12
	devGemsBtn.BorderSizePixel = 0
	devGemsBtn.ZIndex = 51
	devGemsBtn.Parent = header

	local dgbCorner = Instance.new("UICorner")
	dgbCorner.CornerRadius = UDim.new(0, 8)
	dgbCorner.Parent = devGemsBtn

	local dgbStroke = Instance.new("UIStroke")
	dgbStroke.Thickness = 1
	dgbStroke.Color = Color3.fromRGB(200, 120, 255)
	dgbStroke.Transparency = 0.5
	dgbStroke.Parent = devGemsBtn

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 110, 0, 38)
	closeBtn.Position = UDim2.new(1, -120, 0.5, -19)
	closeBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 60)
	closeBtn.Text = "✕ CLOSE"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.BorderSizePixel = 0
	closeBtn.ZIndex = 51
	closeBtn.Parent = header

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(closeModal)

	-- Fullscreen Tree Canvas
	local treeCanvas = Instance.new("Frame")
	treeCanvas.Name = "TreeCanvas"
	treeCanvas.Size = UDim2.new(1, 0, 1, -70)
	treeCanvas.Position = UDim2.new(0, 0, 0, 70)
	treeCanvas.BackgroundTransparency = 1
	treeCanvas.ZIndex = 41
	treeCanvas.Parent = modal

	-- Forward-declare render function
	local renderTree: () -> ()

	-- Wire drawing helper
	local function drawWire(p0: Vector2, p1: Vector2, color: Color3, thickness: number, transparency: number)
		local delta = p1 - p0
		local length = delta.Magnitude
		local angle = math.deg(math.atan2(delta.Y, delta.X))
		local mid = (p0 + p1) / 2

		-- Ambient glow under-wire
		local glowWire = Instance.new("Frame")
		glowWire.Name = "WireGlow"
		glowWire.AnchorPoint = Vector2.new(0.5, 0.5)
		glowWire.Position = UDim2.new(0, mid.X, 0, mid.Y)
		glowWire.Size = UDim2.new(0, length, 0, thickness + 4)
		glowWire.Rotation = angle
		glowWire.BackgroundColor3 = color
		glowWire.BackgroundTransparency = math.clamp(transparency + 0.5, 0, 1)
		glowWire.BorderSizePixel = 0
		glowWire.ZIndex = 41
		glowWire.Parent = treeCanvas

		local gwCorner = Instance.new("UICorner")
		gwCorner.CornerRadius = UDim.new(1, 0)
		gwCorner.Parent = glowWire

		-- Core illuminated conduit wire
		local wire = Instance.new("Frame")
		wire.Name = "Wire"
		wire.AnchorPoint = Vector2.new(0.5, 0.5)
		wire.Position = UDim2.new(0, mid.X, 0, mid.Y)
		wire.Size = UDim2.new(0, length, 0, thickness)
		wire.Rotation = angle
		wire.BackgroundColor3 = color
		wire.BackgroundTransparency = transparency
		wire.BorderSizePixel = 0
		wire.ZIndex = 42
		wire.Parent = treeCanvas

		local wCorner = Instance.new("UICorner")
		wCorner.CornerRadius = UDim.new(1, 0)
		wCorner.Parent = wire
		return wire
	end

	-- Flat-top regular hexagon construction helper
	local function drawHexagon(
		node: SkillTreeConfig.SkillNode,
		isUnlocked: boolean,
		canUnlock: boolean,
		isBase: boolean,
		onUnlock: () -> ()
	): Frame
		local radius = if isBase then 72 else 58
		local hexW = radius * 2
		local hexH = math.floor(radius * 1.732 + 0.5)

		local hexHolder = Instance.new("Frame")
		hexHolder.Name = "Hex_" .. node.id
		hexHolder.Size = UDim2.new(0, hexW, 0, hexH)
		hexHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		hexHolder.Position = UDim2.new(node.position.X, 0, node.position.Y, 0)
		hexHolder.BackgroundTransparency = 1
		hexHolder.BorderSizePixel = 0
		hexHolder.ZIndex = 43
		hexHolder.Parent = treeCanvas

		-- 1. Outer Ambient Neon Glow Halo
		local halo = Instance.new("Frame")
		halo.Name = "GlowHalo"
		halo.Size = UDim2.new(0, hexW + 18, 0, hexH + 18)
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.new(0.5, 0, 0.5, 0)
		halo.BackgroundColor3 = node.color
		halo.BackgroundTransparency = if isUnlocked then 0.70 elseif isBase then 0.74 else 0.84
		halo.BorderSizePixel = 0
		halo.ZIndex = 43
		halo.Parent = hexHolder

		local hCorner = Instance.new("UICorner")
		hCorner.CornerRadius = UDim.new(1, 0)
		hCorner.Parent = halo

		-- Subtle breathing animation for Central Base Core
		if isBase and not isUnlocked then
			TweenService:Create(halo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency = 0.55,
				Size = UDim2.new(0, hexW + 28, 0, hexH + 28),
			}):Play()
		end

		-- 2. Glassmorphic Card Body
		local card = Instance.new("Frame")
		card.Name = "CardBody"
		card.Size = UDim2.new(0, radius * 1.72, 0, radius * 1.50)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.new(0.5, 0, 0.5, 0)
		card.BackgroundColor3 = if isUnlocked
			then node.color:Lerp(Color3.fromRGB(16, 24, 38), 0.70)
			elseif isBase
			then Color3.fromRGB(38, 32, 20)
			else Color3.fromRGB(22, 28, 42)
		card.BorderSizePixel = 0
		card.ZIndex = 44
		card.Parent = hexHolder

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 14)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = node.color
		cStroke.Thickness = if isUnlocked then 2 else 1
		cStroke.Transparency = if isUnlocked then 0.2 else 0.5
		cStroke.Parent = card

		-- 3. 6 Perimeter Borders for Flat-Top Regular Hexagon
		local halfR = radius * 0.5
		local hVal = radius * 0.8660
		local vertices = {
			Vector2.new(halfR, -hVal),
			Vector2.new(-halfR, -hVal),
			Vector2.new(-radius, 0),
			Vector2.new(-halfR, hVal),
			Vector2.new(halfR, hVal),
			Vector2.new(radius, 0),
		}

		local borderColor = if isUnlocked
			then node.color
			elseif isBase
			then Color3.fromRGB(255, 230, 110)
			else node.color:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
		local borderThickness = if isUnlocked then 3.5 else 2.5

		for i = 1, 6 do
			local nextIdx = if i == 6 then 1 else i + 1
			local vA = vertices[i]
			local vB = vertices[nextIdx]
			local delta = vB - vA
			local length = delta.Magnitude
			local angle = math.deg(math.atan2(delta.Y, delta.X))
			local mid = (vA + vB) / 2

			local edge = Instance.new("Frame")
			edge.Name = "Edge_" .. i
			edge.AnchorPoint = Vector2.new(0.5, 0.5)
			edge.Position = UDim2.new(0.5, mid.X, 0.5, mid.Y)
			edge.Size = UDim2.new(0, length + 2, 0, borderThickness)
			edge.Rotation = angle
			edge.BackgroundColor3 = borderColor
			edge.BorderSizePixel = 0
			edge.ZIndex = 45
			edge.Parent = hexHolder

			local eCorner = Instance.new("UICorner")
			eCorner.CornerRadius = UDim.new(1, 0)
			eCorner.Parent = edge

			-- Glowing vertex star dot at each hexagon corner
			local dot = Instance.new("Frame")
			dot.Name = "VertexDot_" .. i
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(0.5, vA.X, 0.5, vA.Y)
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.BackgroundColor3 = borderColor
			dot.BorderSizePixel = 0
			dot.ZIndex = 46
			dot.Parent = hexHolder

			local dCorner = Instance.new("UICorner")
			dCorner.CornerRadius = UDim.new(1, 0)
			dCorner.Parent = dot
		end

		-- 4. Content inside Hexagon
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.Size = UDim2.new(1, 0, 1, 0)
		content.BackgroundTransparency = 1
		content.ZIndex = 47
		content.Parent = hexHolder

		-- Icon
		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(1, 0, 0, if isBase then 30 else 24)
		iconLbl.Position = UDim2.new(0, 0, 0, if isBase then 8 else 6)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = node.icon
		iconLbl.TextSize = if isBase then 26 else 20
		iconLbl.ZIndex = 47
		iconLbl.Parent = content

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -14, 0, 16)
		nameLbl.Position = UDim2.new(0, 7, 0, if isBase then 38 else 30)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = node.name
		nameLbl.TextColor3 = if isUnlocked then Color3.fromRGB(255, 255, 255) elseif isBase then Color3.fromRGB(255, 225, 100) else node.color
		nameLbl.Font = Enum.Font.Antique
		nameLbl.TextSize = if isBase then 13 else 11
		nameLbl.ZIndex = 47
		nameLbl.Parent = content

		-- Perk summary
		local perkLbl = Instance.new("TextLabel")
		perkLbl.Size = UDim2.new(1, -10, 0, 14)
		perkLbl.Position = UDim2.new(0, 5, 0, if isBase then 54 else 46)
		perkLbl.BackgroundTransparency = 1
		perkLbl.TextColor3 = Color3.fromRGB(190, 220, 245)
		perkLbl.Font = Enum.Font.Antique
		perkLbl.TextSize = if isBase then 11 else 10
		perkLbl.ZIndex = 47

		if node.branch == "Power" then
			local mineBonus = math.floor((node.miningPowerMult - 1.0) * 100 + 0.5)
			local bossBonus = math.floor((node.bossMultiplier - 1.0) * 100 + 0.5)
			perkLbl.Text = string.format("+%d%% Mine • +%d%% Boss", mineBonus, bossBonus)
		elseif node.branch == "Speed" then
			perkLbl.Text = string.format("+%d Walk • +%d Sprint", node.speedBonus, math.floor(node.speedBonus * 1.5))
		elseif node.branch == "Luck" then
			local cashBonus = math.floor((node.cashMultiplier - 1.0) * 100 + 0.5)
			perkLbl.Text = string.format("+%d 💎 • +%d%% Cash", node.bonusGems, cashBonus)
		else
			perkLbl.Text = "+10% All • +2 Speed"
		end
		perkLbl.Parent = content

		-- Status Button / Tag
		if isUnlocked then
			local masteredTag = Instance.new("TextLabel")
			masteredTag.Size = UDim2.new(0.80, 0, 0, if isBase then 24 else 20)
			masteredTag.Position = UDim2.new(0.10, 0, 1, if isBase then -36 else -28)
			masteredTag.BackgroundColor3 = Color3.fromRGB(24, 70, 45)
			masteredTag.Text = "✓ MASTERED"
			masteredTag.TextColor3 = Color3.fromRGB(80, 255, 170)
			masteredTag.Font = Enum.Font.GothamBold
			masteredTag.TextSize = 10
			masteredTag.BorderSizePixel = 0
			masteredTag.ZIndex = 48
			masteredTag.Parent = content

			local mtCorner = Instance.new("UICorner")
			mtCorner.CornerRadius = UDim.new(1, 0)
			mtCorner.Parent = masteredTag
		elseif canUnlock then
			local canAfford = (cachedData.Gems or 0) >= node.cost
			local buyBtn = Instance.new("TextButton")
			buyBtn.Size = UDim2.new(0.82, 0, 0, if isBase then 26 else 22)
			buyBtn.Position = UDim2.new(0.09, 0, 1, if isBase then -38 else -30)
			buyBtn.BackgroundColor3 = if canAfford
				then (if isBase then Color3.fromRGB(220, 165, 30) else Color3.fromRGB(0, 175, 115))
				else Color3.fromRGB(85, 45, 60)
			buyBtn.Text = (if isBase then "🌟 " else "💎 ") .. FormatNumber.formatCompact(node.cost) .. (if isBase then " AWAKEN" else " BUY")
			buyBtn.TextColor3 = if canAfford then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(230, 170, 185)
			buyBtn.Font = Enum.Font.GothamBold
			buyBtn.TextSize = 10
			buyBtn.BorderSizePixel = 0
			buyBtn.ZIndex = 49
			buyBtn.Parent = content

			local bbCorner = Instance.new("UICorner")
			bbCorner.CornerRadius = UDim.new(1, 0)
			bbCorner.Parent = buyBtn

			buyBtn.MouseButton1Click:Connect(onUnlock)
		end

		-- 5. Full Hexagon Click Trigger
		local hitArea = Instance.new("TextButton")
		hitArea.Name = "HitArea"
		hitArea.Size = UDim2.new(1, 0, 1, 0)
		hitArea.Position = UDim2.new(0, 0, 0, 0)
		hitArea.BackgroundTransparency = 1
		hitArea.Text = ""
		hitArea.ZIndex = 48
		hitArea.Parent = hexHolder

		hitArea.MouseButton1Click:Connect(function()
			if canUnlock then
				onUnlock()
			elseif isUnlocked then
				showFloatingPopup(node.name .. " is already active!", node.color)
			end
		end)

		-- Hover effect
		hitArea.MouseEnter:Connect(function()
			if canUnlock or isUnlocked then
				TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, radius * 1.82, 0, radius * 1.58),
				}):Play()
				TweenService:Create(halo, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.58,
				}):Play()
			end
		end)
		hitArea.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, radius * 1.72, 0, radius * 1.50),
			}):Play()
			TweenService:Create(halo, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = if isUnlocked then 0.70 elseif isBase then 0.74 else 0.84,
			}):Play()
		end)

		return hexHolder
	end

	renderTree = function()
		treeCanvas:ClearAllChildren()

		local cw = treeCanvas.AbsoluteSize.X
		local ch = treeCanvas.AbsoluteSize.Y
		if cw < 200 or ch < 200 then
			if screenGui and screenGui.AbsoluteSize.X > 200 then
				cw = screenGui.AbsoluteSize.X
				ch = screenGui.AbsoluteSize.Y - 70
			else
				cw = 1200
				ch = 800
			end
		end

		-- Ambient Branch Orientation Guides
		local branchLabels = {
			{ x = 0.18, y = 0.08, name = "⚔️ MIGHT & BOSS SLAYER", color = Color3.fromRGB(255, 80, 60) },
			{ x = 0.82, y = 0.08, name = "⚡ VELOCITY & MOBILITY", color = Color3.fromRGB(40, 210, 255) },
			{ x = 0.50, y = 0.96, name = "👑 FORTUNE & ABUNDANCE", color = Color3.fromRGB(210, 110, 255) },
		}

		for _, bl in ipairs(branchLabels) do
			local bLbl = Instance.new("TextLabel")
			bLbl.Size = UDim2.new(0, 240, 0, 22)
			bLbl.AnchorPoint = Vector2.new(0.5, 0.5)
			bLbl.Position = UDim2.new(bl.x, 0, bl.y, 0)
			bLbl.BackgroundTransparency = 1
			bLbl.Text = bl.name
			bLbl.TextColor3 = bl.color
			bLbl.Font = Enum.Font.Antique
			bLbl.TextSize = 13
			bLbl.TextTransparency = 0.35
			bLbl.ZIndex = 41
			bLbl.Parent = treeCanvas
		end

		-- Centered Guidance Banner
		local isBaseUnlocked = SkillTreeConfig.isUnlocked("node_base", cachedData.UnlockedSkills)
		local bannerText = if isBaseUnlocked
			then "✦ ANCIENT DISCIPLINES UNLOCKED • INVEST GEMS TO ADVANCE ✦"
			else "✦ AWAKEN THE CENTRAL CORE TO REVEAL THE TALENT TREE ✦"

		local guideBanner = Instance.new("TextLabel")
		guideBanner.Size = UDim2.new(0, 520, 0, 20)
		guideBanner.AnchorPoint = Vector2.new(0.5, 0.5)
		guideBanner.Position = UDim2.new(0.5, 0, 0.5, 95)
		guideBanner.BackgroundTransparency = 1
		guideBanner.Text = bannerText
		guideBanner.TextColor3 = if isBaseUnlocked then Color3.fromRGB(0, 220, 180) else Color3.fromRGB(255, 215, 90)
		guideBanner.Font = Enum.Font.GothamBold
		guideBanner.TextSize = 11
		guideBanner.TextTransparency = 0.25
		guideBanner.ZIndex = 41
		guideBanner.Parent = treeCanvas

		-- 1. Draw Connecting Branch Lines ONLY if both parent and child are visible!
		for _, nodeId in ipairs(SkillTreeConfig.NODE_ORDER) do
			local node = SkillTreeConfig.NODES[nodeId]
			if node and node.parent then
				local parentNode = SkillTreeConfig.NODES[node.parent]
				if parentNode then
					local isParentVisible = SkillTreeConfig.isRevealed(parentNode.id, cachedData.UnlockedSkills)
					local isChildVisible = SkillTreeConfig.isRevealed(node.id, cachedData.UnlockedSkills)

					-- Strict Fog-of-War: Wires to hidden nodes are NOT drawn!
					if isParentVisible and isChildVisible then
						local p0 = Vector2.new(parentNode.position.X * cw, parentNode.position.Y * ch)
						local p1 = Vector2.new(node.position.X * cw, node.position.Y * ch)

						local isChildUnlocked = SkillTreeConfig.isUnlocked(node.id, cachedData.UnlockedSkills)
						if isChildUnlocked then
							drawWire(p0, p1, node.color, 4, 0)
						else
							drawWire(p0, p1, node.color, 2.5, 0.35)
						end
					end
				end
			end
		end

		-- 2. Render Hexagon Nodes (Hidden means completely omitted from screen!)
		for _, nodeId in ipairs(SkillTreeConfig.NODE_ORDER) do
			local node = SkillTreeConfig.NODES[nodeId]
			if not node then continue end

			local isVisible = SkillTreeConfig.isRevealed(node.id, cachedData.UnlockedSkills)
			if not isVisible then
				-- HIDDEN: CANNOT EVEN SEE IT! Omit completely!
				continue
			end

			local isUnlocked = SkillTreeConfig.isUnlocked(node.id, cachedData.UnlockedSkills)
			local canUnlock = SkillTreeConfig.canUnlock(node.id, cachedData.UnlockedSkills)
			local isBase = (node.parent == nil)

			local function onUnlock()
				local unlockFn = Remotes.getFunction("UnlockSkillNode")
				local ok, success, msg = pcall(function()
					return unlockFn:InvokeServer(node.id)
				end)

				if ok and success then
					local s = Instance.new("Sound")
					s.SoundId = "rbxassetid://6895079853"
					s.Volume = 0.25
					s.PlaybackSpeed = 1.25
					s.Parent = SoundService
					s:Play()
					s.Ended:Connect(function() s:Destroy() end)

					showFloatingPopup("Mastered " .. node.name .. "!", node.color)

					local getFn = Remotes.getFunction("GetPlayerData")
					local okData, freshData = pcall(function()
						return getFn:InvokeServer()
					end)
					if okData and freshData then
						cachedData = freshData
					end

					gemsBadge.Text = "💎 " .. FormatNumber.formatCompact(cachedData.Gems or 0)
					UIController.updateHUD()

					-- Re-render immediately: Next hexagon appears right now!
					renderTree()
				else
					showFloatingPopup(tostring(msg or "Cannot unlock"), Color3.fromRGB(255, 90, 80))
				end
			end

			drawHexagon(node, isUnlocked, canUnlock, isBase, onUnlock)
		end
	end

	-- Dev cheat button to add gems and test the tree immediately
	devGemsBtn.MouseButton1Click:Connect(function()
		local devFn = Remotes.getFunction("DevAddCash")
		local ok, success, addedCash, addedGems = pcall(function()
			return devFn:InvokeServer()
		end)
		if ok and success then
			local getFn = Remotes.getFunction("GetPlayerData")
			local okData, freshData = pcall(function()
				return getFn:InvokeServer()
			end)
			if okData and freshData then
				cachedData = freshData
			end
			gemsBadge.Text = "💎 " .. FormatNumber.formatCompact(cachedData.Gems or 0)
			UIController.updateHUD()
			showFloatingPopup("+50,000 💎!", Color3.fromRGB(0, 255, 220), 0)
			renderTree()
		end
	end)

	-- Listen for canvas size changes to keep wires and nodes perfectly centered
	local resizeConn = treeCanvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if activeModal == modal then
			renderTree()
		end
	end)
	modal.Destroying:Connect(function()
		resizeConn:Disconnect()
	end)

	renderTree()

	-- Smooth subtle pop-in entrance animation
	modal.Position = UDim2.new(0.5, 0, 0.52, 0)
	modal.BackgroundTransparency = 0.3
	TweenService:Create(modal, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0,
	}):Play()
end

local function openDialogueModal(npcName: string)
	print("🗣️ [UIController] openDialogueModal initiated for " .. tostring(npcName or "Barnaby"))
	closeModal()
	closeDialogue()

	if not screenGui then
		warn("[UIController] Cannot open dialogue: screenGui is nil!")
		return
	end

	-- Centered Bottom-Half Transparent Dialogue Container (Wide 960px frame, borderless floating RPG text)
	local dlg = Instance.new("Frame")
	dlg.Name = "DialogueContainer"
	dlg.Size = UDim2.new(0.92, 0, 0, 420)
	dlg.Position = UDim2.new(0.5, 0, 1, 40)
	dlg.AnchorPoint = Vector2.new(0.5, 1)
	dlg.BackgroundTransparency = 1
	dlg.BorderSizePixel = 0
	dlg.ZIndex = 30
	dlg.Parent = screenGui
	activeDialogue = dlg

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(980, 440)
	sizeConstraint.Parent = dlg

	-- Minimalist Monochrome Close "X" Button
	local closeDlgBtn = Instance.new("TextButton")
	closeDlgBtn.Size = UDim2.new(0, 32, 0, 32)
	closeDlgBtn.Position = UDim2.new(1, -20, 0, -10)
	closeDlgBtn.BackgroundTransparency = 1
	closeDlgBtn.Text = "X"
	closeDlgBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
	closeDlgBtn.Font = Enum.Font.GothamBold
	closeDlgBtn.TextSize = 18
	closeDlgBtn.BorderSizePixel = 0
	closeDlgBtn.ZIndex = 35
	closeDlgBtn.Parent = dlg

	closeDlgBtn.MouseEnter:Connect(function()
		closeDlgBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
	closeDlgBtn.MouseLeave:Connect(function()
		closeDlgBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
	end)
	closeDlgBtn.MouseButton1Click:Connect(closeDialogue)

	-- NPC Dialogue Speech Label (Centered, Massive 52px Thick Antique Roguelike Font)
	local speechLabel = Instance.new("TextLabel")
	speechLabel.Name = "SpeechLabel"
	speechLabel.Size = UDim2.new(1, 0, 0, 220)
	speechLabel.Position = UDim2.new(0, 0, 0, 0)
	speechLabel.BackgroundTransparency = 1
	speechLabel.Text = ""
	speechLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speechLabel.Font = Enum.Font.Antique
	speechLabel.TextSize = 52 -- Massive thick font!
	speechLabel.TextWrapped = true
	speechLabel.RichText = true
	speechLabel.TextXAlignment = Enum.TextXAlignment.Center -- Centered!
	speechLabel.TextYAlignment = Enum.TextYAlignment.Top
	speechLabel.ZIndex = 32
	speechLabel.Parent = dlg

	-- Heavy 3.5px pure black stroke for bold, thick text readability without a box
	local speechStroke = Instance.new("UIStroke")
	speechStroke.Thickness = 3.5
	speechStroke.Color = Color3.fromRGB(0, 0, 0)
	speechStroke.Transparency = 0
	speechStroke.Parent = speechLabel

	-- Invisible Click-to-Skip Button covering speech area
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipDetector"
	skipBtn.Size = UDim2.new(1, 0, 0, 220)
	skipBtn.Position = UDim2.new(0, 0, 0, 0)
	skipBtn.BackgroundTransparency = 1
	skipBtn.Text = ""
	skipBtn.ZIndex = 31
	skipBtn.Parent = dlg
	skipBtn.MouseButton1Click:Connect(skipDialogueTyping)

	-- Choice Buttons Column (Centered, Stacked Vertically, NO BOXES)
	local choicesCol = Instance.new("Frame")
	choicesCol.Name = "ChoicesColumn"
	choicesCol.Size = UDim2.new(1, 0, 0, 180)
	choicesCol.Position = UDim2.new(0, 0, 0, 230)
	choicesCol.BackgroundTransparency = 1
	choicesCol.ZIndex = 32
	choicesCol.Parent = dlg

	local choiceList = Instance.new("UIListLayout")
	choiceList.FillDirection = Enum.FillDirection.Vertical -- Stacked vertically!
	choiceList.HorizontalAlignment = Enum.HorizontalAlignment.Center -- Centered!
	choiceList.Padding = UDim.new(0, 8)
	choiceList.SortOrder = Enum.SortOrder.LayoutOrder
	choiceList.Parent = choicesCol

	activeChoiceButtons = {}
	activeChoiceTexts = {}

	local function makeChoice(order: number, rawText: string, onClick: () -> ()): TextButton
		local cBtn = Instance.new("TextButton")
		cBtn.LayoutOrder = order
		cBtn.Size = UDim2.new(1, 0, 0, 48)
		cBtn.BackgroundTransparency = 1 -- NO BOX AROUND CHOICES!
		cBtn.BorderSizePixel = 0
		cBtn.Text = "" -- Empty initially until typewriter starts
		cBtn.TextColor3 = Color3.fromRGB(210, 215, 225)
		cBtn.Font = Enum.Font.Antique
		cBtn.TextSize = 32 -- Bolder & bigger!
		cBtn.TextWrapped = true
		cBtn.TextXAlignment = Enum.TextXAlignment.Center -- Centered!
		cBtn.ZIndex = 34
		cBtn.Parent = choicesCol

		-- Heavy black text stroke so user text is bold, crisp, and readable without a box
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 3.0
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Transparency = 0
		textStroke.Parent = cBtn

		cBtn.MouseEnter:Connect(function()
			if not isTypingDialogue and choicesTypingThread == nil and #cBtn.Text > 0 then
				cBtn.Text = "> " .. rawText .. " <"
				cBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end)
		cBtn.MouseLeave:Connect(function()
			if not isTypingDialogue and choicesTypingThread == nil and #cBtn.Text > 0 then
				cBtn.Text = rawText
				cBtn.TextColor3 = Color3.fromRGB(210, 215, 225)
			end
		end)

		cBtn.MouseButton1Click:Connect(function()
			skipDialogueTyping()
			onClick()
		end)

		table.insert(activeChoiceButtons, cBtn)
		table.insert(activeChoiceTexts, rawText)
		return cBtn
	end

	if npcName == "Zephyr" then
		choiceAction1 = function()
			closeDialogue()
			openTrailsShopModal()
		end
		makeChoice(1, "[1] Show me your mystical trails!", choiceAction1)

		choiceAction2 = function()
			local tip = "My trails weave elemental currents behind your stride. Each trail enhances movement speed, multiplies mining cash, grants bonus gems, and empowers pickaxe strikes against mighty bosses!"
			typewriteWords(speechLabel, tip, 0.04, function()
				typewriteChoices(function()
					startIdleBounce(choicesCol)
				end)
			end)
		end
		makeChoice(2, "[2] How do trails empower me?", choiceAction2)

		makeChoice(3, "[3] Farewell. [Leave]", function()
			closeDialogue()
		end)

		-- Register bounce target
		activeBounceElement = choicesCol
		activeBounceBasePos = choicesCol.Position

		-- Animate in smoothly from bottom to centered bottom half
		TweenService:Create(dlg, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -28),
		}):Play()

		local greeting = "Greetings, traveler! I am Zephyr, the Trail Artisan. By weaving the ancient crystal currents of this realm, I can craft ethereal ribbons that empower your every stride!"
		typewriteWords(speechLabel, greeting, 0.045, function()
			typewriteChoices(function()
				startIdleBounce(choicesCol)
			end)
		end)
	else
		-- Choice 1: What do you have for sale?
		choiceAction1 = function()
			closeDialogue()
			openEquipmentShopModal()
		end
		makeChoice(1, "[1] What do you have for sale?", choiceAction1)

		-- Choice 2: Any advice for the mines?
		choiceAction2 = function()
			local tip = "Swing your pickaxe at glowing ore veins across the map. Rarer ores yield heaps of cash and gems. Buy a sturdy backpack from me to multiply every batch."
			typewriteWords(speechLabel, tip, 0.04, function()
				typewriteChoices(function()
					startIdleBounce(choicesCol)
				end)
			end)
		end
		makeChoice(2, "[2] Tell me about this place.", choiceAction2)

		-- Choice 3: Leave
		makeChoice(3, "[3] Just browsing. [Leave]", function()
			closeDialogue()
		end)

		-- Register bounce target
		activeBounceElement = choicesCol
		activeBounceBasePos = choicesCol.Position

		-- Animate in smoothly from bottom to centered bottom half
		TweenService:Create(dlg, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -28),
		}):Play()

		-- Step 1: Typewrite NPC dialogue first.
		-- Step 2: Once NPC dialogue finishes, typewrite the choices.
		-- Step 3: Once choices finish, start the static/idle bounce animation!
		local greeting = "Greetings, traveler. The ores beneath these mountains are rich, but you will need the right gear to harvest them quickly. What can I do for you?"
		typewriteWords(speechLabel, greeting, 0.045, function()
			typewriteChoices(function()
				startIdleBounce(choicesCol)
			end)
		end)
	end
end

function UIController.buildHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MiningHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- TOP BAR CONTAINER
	local topBar = createStyledFrame(screenGui, "TopBar", UDim2.new(0, 780, 0, 56), UDim2.new(0.5, -390, 0, 16), Color3.fromRGB(18, 20, 26))

	-- Power Container
	local powerBox = Instance.new("Frame")
	powerBox.Size = UDim2.new(0, 155, 1, 0)
	powerBox.Position = UDim2.new(0, 12, 0, 0)
	powerBox.BackgroundTransparency = 1
	powerBox.Parent = topBar

	local powerIcon = Instance.new("TextLabel")
	powerIcon.Size = UDim2.new(0, 32, 1, 0)
	powerIcon.BackgroundTransparency = 1
	powerIcon.Text = "⚡"
	powerIcon.TextSize = 22
	powerIcon.Parent = powerBox

	powerLabel = Instance.new("TextLabel")
	powerLabel.Size = UDim2.new(1, -34, 1, 0)
	powerLabel.Position = UDim2.new(0, 34, 0, 0)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text = "10 Power"
	powerLabel.TextColor3 = Color3.fromRGB(255, 215, 35)
	powerLabel.Font = Enum.Font.GothamBlack
	powerLabel.TextSize = 18
	powerLabel.TextXAlignment = Enum.TextXAlignment.Left
	powerLabel.Parent = powerBox

	-- Cash Container
	local cashBox = Instance.new("Frame")
	cashBox.Size = UDim2.new(0, 155, 1, 0)
	cashBox.Position = UDim2.new(0, 175, 0, 0)
	cashBox.BackgroundTransparency = 1
	cashBox.Parent = topBar

	local cashIcon = Instance.new("TextLabel")
	cashIcon.Size = UDim2.new(0, 32, 1, 0)
	cashIcon.BackgroundTransparency = 1
	cashIcon.Text = "💰"
	cashIcon.TextSize = 22
	cashIcon.Parent = cashBox

	cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.new(1, -34, 1, 0)
	cashLabel.Position = UDim2.new(0, 34, 0, 0)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$0"
	cashLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
	cashLabel.Font = Enum.Font.GothamBlack
	cashLabel.TextSize = 18
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.Parent = cashBox

	-- Gems Container
	local gemsBox = Instance.new("Frame")
	gemsBox.Size = UDim2.new(0, 130, 1, 0)
	gemsBox.Position = UDim2.new(0, 338, 0, 0)
	gemsBox.BackgroundTransparency = 1
	gemsBox.Parent = topBar

	local gemsIcon = Instance.new("TextLabel")
	gemsIcon.Size = UDim2.new(0, 32, 1, 0)
	gemsIcon.BackgroundTransparency = 1
	gemsIcon.Text = "💎"
	gemsIcon.TextSize = 22
	gemsIcon.Parent = gemsBox

	gemsLabel = Instance.new("TextLabel")
	gemsLabel.Size = UDim2.new(1, -34, 1, 0)
	gemsLabel.Position = UDim2.new(0, 34, 0, 0)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.Text = "0"
	gemsLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
	gemsLabel.Font = Enum.Font.GothamBlack
	gemsLabel.TextSize = 18
	gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemsLabel.Parent = gemsBox

	-- Multiplier Badge
	multiplierBadge = Instance.new("TextLabel")
	multiplierBadge.Size = UDim2.new(0, 135, 0.7, 0)
	multiplierBadge.Position = UDim2.new(0, 480, 0.15, 0)
	multiplierBadge.BackgroundColor3 = Color3.fromRGB(35, 42, 60)
	multiplierBadge.Text = "⚡ 1.0x Boost"
	multiplierBadge.TextColor3 = Color3.fromRGB(255, 215, 0)
	multiplierBadge.Font = Enum.Font.GothamBold
	multiplierBadge.TextSize = 13
	multiplierBadge.BorderSizePixel = 0
	multiplierBadge.Parent = topBar

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 8)
	badgeCorner.Parent = multiplierBadge

	-- VIP Badge
	vipBadge = Instance.new("TextLabel")
	vipBadge.Size = UDim2.new(0, 135, 0.7, 0)
	vipBadge.Position = UDim2.new(0, 628, 0.15, 0)
	vipBadge.BackgroundColor3 = Color3.fromRGB(85, 60, 15)
	vipBadge.Text = "👑 VIP 2X"
	vipBadge.TextColor3 = Color3.fromRGB(255, 215, 60)
	vipBadge.Font = Enum.Font.GothamBlack
	vipBadge.TextSize = 12
	vipBadge.BorderSizePixel = 0
	vipBadge.Visible = isLocalPlayerVIP
	vipBadge.Parent = topBar

	local vipBadgeCorner = Instance.new("UICorner")
	vipBadgeCorner.CornerRadius = UDim.new(0, 8)
	vipBadgeCorner.Parent = vipBadge

	-- SIDE MENU BUTTONS
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.Size = UDim2.new(0, 148, 0, 490)
	sideMenu.Position = UDim2.new(0, 16, 0.5, -245)
	sideMenu.BackgroundTransparency = 1
	sideMenu.Parent = screenGui

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.Parent = sideMenu

	local function createMenuButton(name: string, text: string, color: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 0, 39)
		btn.BackgroundColor3 = color
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.BorderSizePixel = 0
		btn.Parent = sideMenu

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.8
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	createMenuButton("ShopBtn", "🛒 Shop", Color3.fromRGB(220, 100, 30), openEquipmentShopModal)
	createMenuButton("RebirthBtn", "⚡ Rebirth", Color3.fromRGB(218, 165, 32), openRebirthModal)
	createMenuButton("PetsBtn", "🐾 Pets", Color3.fromRGB(65, 105, 225), openPetModal)
	createMenuButton("IndexBtn", "📖 Pet Index", Color3.fromRGB(0, 165, 215), function()
		openPetIndexModal()
	end)
	createMenuButton("FusionBtn", "⚗️ Fusion", Color3.fromRGB(245, 150, 0), function()
		openFusionModal()
	end)
	createMenuButton("TrailsBtn", "✨ Trails", Color3.fromRGB(160, 40, 220), openTrailsShopModal)
	createMenuButton("TreeBtn", "🌳 Upgrades", Color3.fromRGB(0, 175, 120), openUpgradeTreeModal)
	createMenuButton("VIPBtn", "👑 VIP Pass", Color3.fromRGB(190, 140, 15), openVIPModal)

	-- SIMULATOR QUICK HARVEST CLICKER BUTTON
	local harvestBtn = createMenuButton("HarvestBtn", "⛏️ Mine (+$$/💎)", Color3.fromRGB(0, 180, 120), function()
		MiningClient.performSwing()
	end)

	-- DEV TESTING CHEAT BUTTON (+$10,000,000 & +50,000 Gems for easy upgrade testing)
	createMenuButton("DevBtn", "⚡ +$10M (Dev)", Color3.fromRGB(147, 51, 234), function()
		local devFn = Remotes.getFunction("DevAddCash")
		local ok, success, addedCash, addedGems = pcall(function()
			return devFn:InvokeServer()
		end)
		if ok and success then
			showFloatingPopup("+$10,000,000!", Color3.fromRGB(255, 215, 0), -35)
			showFloatingPopup("+50,000 💎!", Color3.fromRGB(0, 255, 220), 35)
		end
	end)

	-- DEV TESTING REBIRTH CHEAT BUTTON (+1 on Left Click, +5 on Right Click)
	local devRebirthBtn = createMenuButton("DevRebirthBtn", "🔄 +Rebirth (Dev)", Color3.fromRGB(190, 40, 115), function()
		local devRebirthFn = Remotes.getFunction("DevAddRebirth")
		local ok, success, newRebirths = pcall(function()
			return devRebirthFn:InvokeServer(1)
		end)
		if ok and success then
			showFloatingPopup(string.format("⚡ +1 REBIRTH! (Total: %d)", newRebirths or (cachedData.Rebirths or 0) + 1), Color3.fromRGB(255, 120, 220), 0)
		end
	end)
	devRebirthBtn.MouseButton2Click:Connect(function()
		local devRebirthFn = Remotes.getFunction("DevAddRebirth")
		local ok, success, newRebirths = pcall(function()
			return devRebirthFn:InvokeServer(5)
		end)
		if ok and success then
			showFloatingPopup(string.format("⚡ +5 REBIRTHS! (Total: %d)", newRebirths or (cachedData.Rebirths or 0) + 5), Color3.fromRGB(255, 120, 220), 0)
		end
	end)

	-- SIMULATOR BGM MUSIC MUTE / UNMUTE TOGGLE
	local musicBtn: TextButton? = nil
	musicBtn = createMenuButton("MusicBtn", "🎵 Music: ON", Color3.fromRGB(70, 80, 95), function()
		local isPlaying = AudioController.toggleMusic()
		if musicBtn then
			musicBtn.Text = if isPlaying then "🎵 Music: ON" else "🔇 Music: OFF"
			musicBtn.BackgroundColor3 = if isPlaying then Color3.fromRGB(70, 80, 95) else Color3.fromRGB(50, 55, 65)
		end
	end)

	-- RIGHT-SIDE SIMULATOR ACTION BUTTONS (Lucky Wheel)
	local rightSideMenu = Instance.new("Frame")
	rightSideMenu.Name = "RightSideMenu"
	rightSideMenu.Size = UDim2.new(0, 80, 0, 100)
	rightSideMenu.Position = UDim2.new(1, -96, 0.5, -50)
	rightSideMenu.BackgroundTransparency = 1
	rightSideMenu.Parent = screenGui

	local wheelBtn = Instance.new("TextButton")
	wheelBtn.Name = "WheelSpinBtn"
	wheelBtn.Size = UDim2.new(0, 74, 0, 74)
	wheelBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
	wheelBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	wheelBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	wheelBtn.Text = ""
	wheelBtn.BorderSizePixel = 0
	wheelBtn.Parent = rightSideMenu

	local wBtnCorner = Instance.new("UICorner")
	wBtnCorner.CornerRadius = UDim.new(0, 18)
	wBtnCorner.Parent = wheelBtn

	local wBtnStroke = Instance.new("UIStroke")
	wBtnStroke.Thickness = 2.5
	wBtnStroke.Color = Color3.fromRGB(255, 255, 255)
	wBtnStroke.Parent = wheelBtn

	local wBtnIcon = Instance.new("TextLabel")
	wBtnIcon.Size = UDim2.new(1, 0, 0, 32)
	wBtnIcon.Position = UDim2.new(0, 0, 0, 8)
	wBtnIcon.BackgroundTransparency = 1
	wBtnIcon.Text = "WHEEL"
	wBtnIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	wBtnIcon.Font = Enum.Font.Antique
	wBtnIcon.TextSize = 14
	wBtnIcon.Parent = wheelBtn

	local wBtnText = Instance.new("TextLabel")
	wBtnText.Size = UDim2.new(1, 0, 0, 22)
	wBtnText.Position = UDim2.new(0, 0, 1, -26)
	wBtnText.BackgroundTransparency = 1
	wBtnText.Text = "SPIN"
	wBtnText.TextColor3 = Color3.fromRGB(255, 255, 255)
	wBtnText.Font = Enum.Font.GothamBlack
	wBtnText.TextSize = 14
	wBtnText.Parent = wheelBtn

	-- "FREE" Badge on top-right corner (Black & White)
	local freeBadge = Instance.new("Frame")
	freeBadge.Name = "FreeBadge"
	freeBadge.Size = UDim2.new(0, 42, 0, 20)
	freeBadge.Position = UDim2.new(1, -22, 0, -8)
	freeBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	freeBadge.BorderSizePixel = 0
	freeBadge.ZIndex = 5
	freeBadge.Parent = wheelBtn
	wheelFreeBadge = freeBadge

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = freeBadge

	local bStroke = Instance.new("UIStroke")
	bStroke.Thickness = 1.5
	bStroke.Color = Color3.fromRGB(0, 0, 0)
	bStroke.Parent = freeBadge

	local bText = Instance.new("TextLabel")
	bText.Size = UDim2.new(1, 0, 1, 0)
	bText.BackgroundTransparency = 1
	bText.Text = "FREE"
	bText.TextColor3 = Color3.fromRGB(0, 0, 0)
	bText.Font = Enum.Font.GothamBlack
	bText.TextSize = 10
	bText.ZIndex = 6
	bText.Parent = freeBadge

	-- Idle breathing animation
	TweenService:Create(wheelBtn, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.new(0, 78, 0, 78),
	}):Play()

	wheelBtn.MouseButton1Click:Connect(openWheelModal)

	-- Instantaneous local client prompt response when pressing E near Barnaby
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player or who == nil then
			if prompt.Name == "TalkPrompt" or prompt.ActionText == "Talk" or string.find(prompt.ObjectText, "Barnaby") then
				print("🗣️ [UIController] ProximityPrompt triggered locally on client for Barnaby!")
				openDialogueModal("Barnaby")
			end
		end
	end)

	-- Dialogue keyboard shortcuts [1], [2], [3], [Space], [E], [Esc]
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not activeDialogue then return end
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if (isTypingDialogue or choicesTypingThread ~= nil) and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Return) then
				skipDialogueTyping()
				return
			end

			if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
				if choiceAction1 then
					choiceAction1()
				end
			elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo then
				if choiceAction2 then
					choiceAction2()
				end
			elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.KeypadThree then
				closeDialogue()
			end
		end
	end)

	-- Escape key closes activeModal or activeDialogue
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if UserInputService:GetFocusedTextBox() ~= nil then return end

		if input.KeyCode == Enum.KeyCode.Escape then
			if activeModal then
				closeModal()
			elseif activeDialogue then
				closeDialogue()
			end
		elseif input.KeyCode == Enum.KeyCode.U then
			if activeModal and activeModal.Name == "UpgradeTreeModal" then
				closeModal()
			elseif not activeModal and not activeDialogue then
				openUpgradeTreeModal()
			end
		end
	end)

	-- Listen for server events
	local dialogueEvent = Remotes.getEvent("OpenShopDialogue")
	dialogueEvent.OnClientEvent:Connect(function(npcName: string?)
		print("🗣️ [UIController] OpenShopDialogue received from server for " .. tostring(npcName))
		openDialogueModal(npcName or "Barnaby")
	end)

	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent.OnClientEvent:Connect(function(data)
		cachedData = data
		UIController.updateHUD()
	end)

	local crystalEvent = Remotes.getEvent("CrystalCollected")
	crystalEvent.OnClientEvent:Connect(function(earnedCash: number, earnedGems: number?)
		if earnedCash and earnedCash > 0 then
			showFloatingPopup("+$" .. FormatNumber.formatCompact(earnedCash), Color3.fromRGB(0, 255, 170), -35)
		end
		if earnedGems and earnedGems > 0 then
			showFloatingPopup("+" .. earnedGems .. " 💎", Color3.fromRGB(0, 220, 255), 35)
		end
	end)

	local eggHatchedEvent = Remotes.getEvent("EggHatched")
	eggHatchedEvent.OnClientEvent:Connect(function(success: boolean, petData: any, reason: string?)
		if success and petData then
			closeModal()
			closeDialogue()
			PetHatchAnimation.playHatch(petData)
		else
			showFloatingPopup("❌ " .. tostring(reason or "Cannot hatch egg!"), Color3.fromRGB(255, 90, 80), 0)
		end
	end)

	-- Open Robux Egg Modal (Event from ProximityPrompt)
	local robuxModalEvent = Remotes.getEvent("OpenRobuxPurchaseModal")
	robuxModalEvent.OnClientEvent:Connect(function()
		openRobuxEggModal()
	end)

	-- Open VIP Modal (Event from VIP ProximityPrompt)
	local openVipEvent = Remotes.getEvent("OpenVIPModal")
	openVipEvent.OnClientEvent:Connect(function()
		openVIPModal()
	end)

	-- Open Pet Fusion Modal (Event from Fusion ProximityPrompt)
	local openFusionEvent = Remotes.getEvent("OpenFusionModal")
	openFusionEvent.OnClientEvent:Connect(function()
		openFusionModal()
	end)

	-- Sync VIP Status in Real-Time
	local vipStatusEvent = Remotes.getEvent("VIPStatusChanged")
	vipStatusEvent.OnClientEvent:Connect(function(isVip: boolean)
		UIController.updateVIPDisplay(isVip)
	end)

	-- Initial Data fetch & VIP Status check
	task.spawn(function()
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
			UIController.updateHUD()
		end

		local passFn = Remotes.getFunction("RequestGamepassAction")
		local okVip, vipRes = pcall(function()
			return passFn:InvokeServer("GetVIPStatus")
		end)
		if okVip and vipRes and vipRes.isVIP ~= nil then
			UIController.updateVIPDisplay(vipRes.isVIP)
		end
	end)
end

function UIController.updateVIPDisplay(isVip: boolean)
	isLocalPlayerVIP = isVip
	if vipBadge then
		vipBadge.Visible = isVip
	end
end

function UIController.init()
	UIController.buildHUD()
end

return UIController
