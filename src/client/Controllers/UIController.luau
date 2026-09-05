--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
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
end

local function closeModal()
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
	sideMenu.Size = UDim2.new(0, 148, 0, 290)
	sideMenu.Position = UDim2.new(0, 16, 0.5, -145)
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

	-- Listen for server events
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
