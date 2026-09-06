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
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local TycoonClient = require(script.Parent.TycoonClient)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local UIController = {}
local cachedData: any = nil

-- UI References
local screenGui: ScreenGui
local cashLabel: TextLabel
local gemsLabel: TextLabel
local multiplierBadge: TextLabel

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
	label.Size = UDim2.new(0, 160, 0, 32)
	label.Position = UDim2.new(0.5, (xOffset or 0) + math.random(-30, 30), 0.6, math.random(-15, 15))
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
	if cashLabel then
		cashLabel.Text = "$" .. FormatNumber.formatCompact(cachedData.Cash or 0)
	end
	if gemsLabel then
		gemsLabel.Text = FormatNumber.formatCompact(cachedData.Gems or 0)
	end
	if multiplierBadge then
		local rebirthMult = RebirthConfig.getMultiplier(cachedData.Rebirths or 0)
		multiplierBadge.Text = string.format("⚡ %.1fx Boost", rebirthMult)
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

	local modal = createStyledFrame(screenGui, "RebirthModal", UDim2.new(0, 440, 0, 390), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 30))
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
		"Reset your Tycoon progress in exchange for permanent cosmic power!\n\n" ..
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

-- Pet Hatching & Inventory Modal
local function openPetModal()
	closeModal()
	if not cachedData then return end

	local modal = createStyledFrame(screenGui, "PetModal", UDim2.new(0, 520, 0, 420), UDim2.new(0.5, 0, 1.5, 0), Color3.fromRGB(20, 22, 30))
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	activeModal = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "🐾 PET SANCTUARY 🐾"
	title.TextColor3 = Color3.fromRGB(80, 240, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.Parent = modal

	-- Egg Hatch Section
	local eggSection = Instance.new("Frame")
	eggSection.Size = UDim2.new(0.92, 0, 0, 130)
	eggSection.Position = UDim2.new(0.04, 0, 0, 55)
	eggSection.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
	eggSection.BorderSizePixel = 0
	eggSection.Parent = modal

	local eggCorner = Instance.new("UICorner")
	eggCorner.CornerRadius = UDim.new(0, 8)
	eggCorner.Parent = eggSection

	local eggSecTitle = Instance.new("TextLabel")
	eggSecTitle.Size = UDim2.new(1, 0, 0, 25)
	eggSecTitle.BackgroundTransparency = 1
	eggSecTitle.Text = "Hatch Eggs (Boosts Cash & Gems!)"
	eggSecTitle.TextColor3 = Color3.fromRGB(200, 210, 230)
	eggSecTitle.Font = Enum.Font.GothamBold
	eggSecTitle.TextSize = 13
	eggSecTitle.Parent = eggSection

	local eggList = {"BasicEgg", "CosmicEgg"}
	for i, eggId in ipairs(eggList) do
		local eggDef = PetConfig.EGGS[eggId]
		if eggDef then
			local eggBtn = Instance.new("TextButton")
			eggBtn.Size = UDim2.new(0.46, 0, 0, 75)
			eggBtn.Position = UDim2.new(0.03 + (i - 1) * 0.49, 0, 0, 35)
			eggBtn.BackgroundColor3 = Color3.fromRGB(40, 48, 68)
			eggBtn.Text = eggDef.name .. "\n💎 " .. eggDef.cost .. " Gems"
			eggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			eggBtn.Font = Enum.Font.GothamBold
			eggBtn.TextSize = 14
			eggBtn.BorderSizePixel = 0
			eggBtn.Parent = eggSection

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = eggBtn

			eggBtn.MouseButton1Click:Connect(function()
				local hatchFn = Remotes.getFunction("HatchEgg")
				local ok, petId, err = hatchFn:InvokeServer(eggId)
				if ok and petId and PetConfig.PETS[petId] then
					eggBtn.Text = "HATCHED!\n" .. PetConfig.PETS[petId].name
					task.wait(1.5)
					openPetModal() -- refresh
				end
			end)
		end
	end

	-- Inventory Section
	local invLabel = Instance.new("TextLabel")
	invLabel.Size = UDim2.new(1, 0, 0, 25)
	invLabel.Position = UDim2.new(0, 0, 0, 195)
	invLabel.BackgroundTransparency = 1
	invLabel.Text = "Your Pets (Equipped: Max 3)"
	invLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	invLabel.Font = Enum.Font.GothamBold
	invLabel.TextSize = 14
	invLabel.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(0.92, 0, 0, 175)
	scroll.Position = UDim2.new(0.04, 0, 0, 225)
	scroll.BackgroundColor3 = Color3.fromRGB(26, 29, 38)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.Parent = modal

	local sCorner = Instance.new("UICorner")
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
	subTitle.Text = "Equip shovels for higher click rewards & backpacks for tycoon multipliers!"
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
				perkLabel.Text = string.format("+%s Cash/Click%s", FormatNumber.formatCompact(sh.clickCash), gemBonusText)
			else
				local bp = item :: ShopConfig.BackpackDef
				local gemBonusText = if bp.bonusGems > 0 then string.format(" • +%d 💎/Ore", bp.bonusGems) else ""
				perkLabel.Text = string.format("+%.0f%% Tycoon Cash%s", (bp.multiplier - 1) * 100, gemBonusText)
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

	-- Choice 1: What do you have for sale?
	choiceAction1 = function()
		closeDialogue()
		openEquipmentShopModal()
	end
	makeChoice(1, "[1] What do you have for sale?", choiceAction1)

	-- Choice 2: Any advice for the mines?
	choiceAction2 = function()
		local tip = "Build out your tycoon droppers and upgrade fields. Upgraded ores yield heaps of cash. Buy a sturdy backpack from me to multiply every batch."
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

function UIController.buildHUD()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TycoonHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- TOP BAR CONTAINER
	local topBar = createStyledFrame(screenGui, "TopBar", UDim2.new(0, 560, 0, 56), UDim2.new(0.5, -280, 0, 16), Color3.fromRGB(18, 20, 26))

	-- Cash Container
	local cashBox = Instance.new("Frame")
	cashBox.Size = UDim2.new(0.38, 0, 1, 0)
	cashBox.BackgroundTransparency = 1
	cashBox.Parent = topBar

	local cashIcon = Instance.new("TextLabel")
	cashIcon.Size = UDim2.new(0, 36, 1, 0)
	cashIcon.BackgroundTransparency = 1
	cashIcon.Text = "💰"
	cashIcon.TextSize = 22
	cashIcon.Parent = cashBox

	cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.new(1, -40, 1, 0)
	cashLabel.Position = UDim2.new(0, 38, 0, 0)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$0"
	cashLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
	cashLabel.Font = Enum.Font.GothamBlack
	cashLabel.TextSize = 20
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.Parent = cashBox

	-- Gems Container
	local gemsBox = Instance.new("Frame")
	gemsBox.Size = UDim2.new(0.32, 0, 1, 0)
	gemsBox.Position = UDim2.new(0.38, 0, 0, 0)
	gemsBox.BackgroundTransparency = 1
	gemsBox.Parent = topBar

	local gemsIcon = Instance.new("TextLabel")
	gemsIcon.Size = UDim2.new(0, 36, 1, 0)
	gemsIcon.BackgroundTransparency = 1
	gemsIcon.Text = "💎"
	gemsIcon.TextSize = 22
	gemsIcon.Parent = gemsBox

	gemsLabel = Instance.new("TextLabel")
	gemsLabel.Size = UDim2.new(1, -40, 1, 0)
	gemsLabel.Position = UDim2.new(0, 38, 0, 0)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.Text = "0"
	gemsLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
	gemsLabel.Font = Enum.Font.GothamBlack
	gemsLabel.TextSize = 20
	gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemsLabel.Parent = gemsBox

	-- Multiplier Badge
	multiplierBadge = Instance.new("TextLabel")
	multiplierBadge.Size = UDim2.new(0.28, 0, 0.7, 0)
	multiplierBadge.Position = UDim2.new(0.7, 0, 0.15, 0)
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

	-- SIDE MENU BUTTONS
	local sideMenu = Instance.new("Frame")
	sideMenu.Name = "SideMenu"
	sideMenu.Size = UDim2.new(0, 148, 0, 350)
	sideMenu.Position = UDim2.new(0, 16, 0.5, -175)
	sideMenu.BackgroundTransparency = 1
	sideMenu.Parent = screenGui

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = sideMenu

	local function createMenuButton(name: string, text: string, color: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 0, 46)
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

	-- SIMULATOR QUICK HARVEST CLICKER BUTTON
	local harvestBtn = createMenuButton("HarvestBtn", "⛏️ Mine (+$$/💎)", Color3.fromRGB(0, 180, 120), function()
		local harvestFn = Remotes.getFunction("ManualHarvest")
		local ok, cashEarned, gemsEarned = pcall(function()
			return harvestFn:InvokeServer()
		end)
		if ok then
			if cashEarned and cashEarned > 0 then
				showFloatingPopup("+$" .. FormatNumber.formatCompact(cashEarned), Color3.fromRGB(0, 255, 170), -35)
			end
			if gemsEarned and gemsEarned > 0 then
				local gemText = if gemsEarned > 1 then ("+" .. gemsEarned .. " 💎 CRIT!") else ("+" .. gemsEarned .. " 💎")
				local gemColor = if gemsEarned > 1 then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(0, 220, 255)
				showFloatingPopup(gemText, gemColor, 35)
			end
		end
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

	-- SIMULATOR BGM MUSIC MUTE / UNMUTE TOGGLE
	local musicBtn: TextButton? = nil
	musicBtn = createMenuButton("MusicBtn", "🎵 Music: ON", Color3.fromRGB(70, 80, 95), function()
		local isPlaying = TycoonClient.toggleMusic()
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
			elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.KeypadThree or input.KeyCode == Enum.KeyCode.Escape then
				closeDialogue()
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

	-- Initial Data fetch
	task.spawn(function()
		local getFn = Remotes.getFunction("GetPlayerData")
		local ok, data = pcall(function()
			return getFn:InvokeServer()
		end)
		if ok and data then
			cachedData = data
			UIController.updateHUD()
		end
	end)
end

function UIController.init()
	UIController.buildHUD()
end

return UIController
