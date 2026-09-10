--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local TutorialController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- GUI References
local screenGui: ScreenGui? = nil
local questCard: Frame? = nil
local cardStroke: UIStroke? = nil
local stepBadge: TextLabel? = nil
local titleLabel: TextLabel? = nil
local instructionLabel: TextLabel? = nil
local iconLabel: TextLabel? = nil
local progressFill: Frame? = nil
local progressLabel: TextLabel? = nil
local rewardLabel: TextLabel? = nil
local skipButton: TextButton? = nil

-- In-World 3D Guide Arrow & Target References
local activeWorldGuideModel: Model? = nil
local activeGuideConn: RBXScriptConnection? = nil
local activeTargetButton: GuiObject? = nil
local activeTargetStroke: UIStroke? = nil
local activePulseConn: RBXScriptConnection? = nil

-- State tracking
local currentStepNum: number = 1
local isTutorialCompleted: boolean = false
local currentStepCount: number = 0

local function playLocalSound(soundId: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

-- Emits small 2D glowing confetti particles bursting from a GUI element
local function emitCardSparks(parent: GuiObject, count: number, color: Color3)
	for i = 1, count do
		local spark = Instance.new("Frame")
		spark.Size = UDim2.new(0, 8, 0, 8)
		spark.Position = UDim2.new(0.5, 0, 0.5, 0)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = color
		spark.BorderSizePixel = 0
		spark.ZIndex = 25
		spark.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = spark

		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.4
		local dist = math.random(60, 160)
		local endX = math.cos(angle) * dist
		local endY = math.sin(angle) * dist

		local tw = TweenService:Create(spark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, endX, 0.5, endY),
			Size = UDim2.new(0, 2, 0, 2),
			BackgroundTransparency = 1,
		})
		tw:Play()
		task.delay(0.5, function() spark:Destroy() end)
	end
end

-- Clears any active 3D in-world guide arrow
local function clearWorldGuide()
	if activeGuideConn then
		activeGuideConn:Disconnect()
		activeGuideConn = nil
	end
	if activeWorldGuideModel then
		activeWorldGuideModel:Destroy()
		activeWorldGuideModel = nil
	end
end

-- Clears any pulsing highlight on sidebar buttons
local function clearButtonSpotlight()
	if activePulseConn then
		activePulseConn:Disconnect()
		activePulseConn = nil
	end
	if activeTargetStroke then
		activeTargetStroke:Destroy()
		activeTargetStroke = nil
	end
	activeTargetButton = nil
end

-- Finds the closest active low-level starter ore in Zone 1 (Stone 25 HP, Copper 60 HP)
local function findNearestLowLevelOre(): (BasePart?, string?, number?)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, nil, nil end
	local rootPos = char.HumanoidRootPart.Position

	local activeOres = Workspace:FindFirstChild("ActiveOres")
	if not activeOres then return nil, nil, nil end

	local bestPart: BasePart? = nil
	local bestName: string? = nil
	local bestHp: number? = nil
	local bestDist = math.huge

	-- Tier 1 Priority: Stone Boulder (25 HP) or Copper Vein (60 HP)
	for _, oreModel in ipairs(activeOres:GetChildren()) do
		if oreModel:IsA("Model") and oreModel.PrimaryPart then
			local oreType = oreModel:GetAttribute("OreType")
			local maxHp = oreModel:GetAttribute("MaxHealth") or 9999
			local nameText = oreModel.Name
			local billboard = oreModel:FindFirstChild("OreBillboard", true)
			if billboard then
				local tLabel = billboard:FindFirstChild("OreTitle") :: TextLabel?
				if tLabel then nameText = tLabel.Text end
			end

			local isStarterLowLevel = (oreType == "Stone" or oreType == "Copper" or maxHp <= 60
				or string.find(nameText:lower(), "stone") ~= nil
				or string.find(nameText:lower(), "copper") ~= nil)

			if isStarterLowLevel then
				local dist = (oreModel.PrimaryPart.Position - rootPos).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestPart = oreModel.PrimaryPart
					bestName = if oreType then oreType else (if string.find(nameText:lower(), "copper") then "Copper" else "Stone")
					bestHp = if maxHp <= 60 then maxHp else 25
				end
			end
		end
	end

	-- Tier 2 Fallback: Any Zone 1 ore with health <= 140 (Iron)
	if not bestPart then
		for _, oreModel in ipairs(activeOres:GetChildren()) do
			if oreModel:IsA("Model") and oreModel.PrimaryPart then
				local maxHp = oreModel:GetAttribute("MaxHealth") or 9999
				local dist = (oreModel.PrimaryPart.Position - rootPos).Magnitude
				if maxHp <= 140 and dist < bestDist then
					bestDist = dist
					bestPart = oreModel.PrimaryPart
					bestName = oreModel:GetAttribute("OreType") or "Iron"
					bestHp = maxHp
				end
			end
		end
	end

	return bestPart, bestName, bestHp
end

-- Renders a vibrant ground guide line with streaming arrows leading directly to the target
local function updateWorldGuide(worldTargetType: string?)
	clearWorldGuide()
	if not worldTargetType or isTutorialCompleted then return end

	local guideModel = Instance.new("Model")
	guideModel.Name = "TutorialWorldGuide"
	guideModel.Parent = Workspace
	activeWorldGuideModel = guideModel

	-- 1. Glowing 3D Arrow Head (Inverted Diamond/Cone pointing down at target)
	local arrow = Instance.new("Part")
	arrow.Name = "ArrowHead"
	arrow.Size = Vector3.new(2.4, 2.8, 2.4)
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(255, 215, 40)
	arrow.CanCollide = false
	arrow.Anchored = true
	arrow.Parent = guideModel

	local arrowMesh = Instance.new("SpecialMesh")
	arrowMesh.MeshType = Enum.MeshType.Sphere
	arrowMesh.Scale = Vector3.new(0.8, 1.4, 0.8)
	arrowMesh.Parent = arrow

	-- 2. Glowing Ground Warning Ring at Base of Target
	local ring = Instance.new("Part")
	ring.Name = "GroundRing"
	ring.Size = Vector3.new(7, 0.2, 7)
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 205, 50)
	ring.Transparency = 0.4
	ring.CanCollide = false
	ring.Anchored = true
	ring.Parent = guideModel

	local ringMesh = Instance.new("SpecialMesh")
	ringMesh.MeshType = Enum.MeshType.Cylinder
	ringMesh.Parent = ring

	-- 3. Overhead Target Billboard Banner (Tells player exactly what low-level ore to mine)
	local targetBillboard = Instance.new("BillboardGui")
	targetBillboard.Name = "TargetBillboard"
	targetBillboard.Size = UDim2.new(0, 240, 0, 36)
	targetBillboard.StudsOffset = Vector3.new(0, 4.2, 0)
	targetBillboard.AlwaysOnTop = true
	targetBillboard.MaxDistance = 150
	targetBillboard.Parent = arrow

	local tbCard = Instance.new("Frame")
	tbCard.Size = UDim2.new(1, 0, 1, 0)
	tbCard.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
	tbCard.BackgroundTransparency = 0.15
	tbCard.BorderSizePixel = 0
	tbCard.Parent = targetBillboard

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 8)
	tbCorner.Parent = tbCard

	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = Color3.fromRGB(255, 215, 50)
	tbStroke.Thickness = 1.8
	tbStroke.Parent = tbCard

	local targetBillboardLabel = Instance.new("TextLabel")
	targetBillboardLabel.Size = UDim2.new(1, 0, 1, 0)
	targetBillboardLabel.BackgroundTransparency = 1
	targetBillboardLabel.Text = "🎯 MINE THIS (LOW LEVEL) 🪨"
	targetBillboardLabel.TextColor3 = Color3.fromRGB(255, 225, 60)
	targetBillboardLabel.Font = Enum.Font.GothamBlack
	targetBillboardLabel.TextSize = 12
	targetBillboardLabel.TextStrokeTransparency = 0.2
	targetBillboardLabel.Parent = tbCard

	-- 4. Ground Navigation Beam (Continuous glowing line connecting player to target)
	local startPart = Instance.new("Part")
	startPart.Name = "BeamStart"
	startPart.Size = Vector3.new(0.2, 0.2, 0.2)
	startPart.Transparency = 1
	startPart.CanCollide = false
	startPart.Anchored = true
	startPart.Parent = guideModel

	local startAtt = Instance.new("Attachment")
	startAtt.Parent = startPart

	local endPart = Instance.new("Part")
	endPart.Name = "BeamEnd"
	endPart.Size = Vector3.new(0.2, 0.2, 0.2)
	endPart.Transparency = 1
	endPart.CanCollide = false
	endPart.Anchored = true
	endPart.Parent = guideModel

	local endAtt = Instance.new("Attachment")
	endAtt.Parent = endPart

	local guideBeam = Instance.new("Beam")
	guideBeam.Name = "NavGuideBeam"
	guideBeam.Attachment0 = startAtt
	guideBeam.Attachment1 = endAtt
	guideBeam.Width0 = 2.4
	guideBeam.Width1 = 2.4
	guideBeam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 40)),
	})
	guideBeam.Texture = "rbxassetid://4483345998"
	guideBeam.TextureMode = Enum.TextureMode.Wrap
	guideBeam.TextureLength = 3.2
	guideBeam.TextureSpeed = 2.4
	guideBeam.LightEmission = 0.9
	guideBeam.LightInfluence = 0
	guideBeam.FaceCamera = true
	guideBeam.Parent = guideModel

	-- 5. Procedural Runway Chevron Arrows along the ground path
	local CHEVRON_COUNT = 24
	type ChevronRecord = { part: Part, gui: SurfaceGui, label: TextLabel }
	local chevrons: { ChevronRecord } = {}

	for i = 1, CHEVRON_COUNT do
		local chPart = Instance.new("Part")
		chPart.Name = "NavArrowChevron_" .. i
		chPart.Size = Vector3.new(2.4, 0.08, 1.8)
		chPart.Material = Enum.Material.Neon
		chPart.Color = Color3.fromRGB(255, 215, 40)
		chPart.Transparency = 0.2
		chPart.CanCollide = false
		chPart.Anchored = true
		chPart.TopSurface = Enum.SurfaceType.Smooth
		chPart.BottomSurface = Enum.SurfaceType.Smooth
		chPart.Parent = guideModel

		local chGui = Instance.new("SurfaceGui")
		chGui.Face = Enum.NormalId.Top
		chGui.AlwaysOnTop = false
		chGui.LightInfluence = 0
		chGui.Parent = chPart

		local chLabel = Instance.new("TextLabel")
		chLabel.Size = UDim2.new(1, 0, 1, 0)
		chLabel.BackgroundTransparency = 1
		chLabel.Text = "➤"
		chLabel.TextColor3 = Color3.fromRGB(255, 245, 140)
		chLabel.Font = Enum.Font.GothamBlack
		chLabel.TextSize = 28
		chLabel.Parent = chGui

		table.insert(chevrons, { part = chPart, gui = chGui, label = chLabel })
	end

	local guideTime = 0
	activeGuideConn = RunService.RenderStepped:Connect(function(dt)
		guideTime += dt * 3.5

		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then return end

		local playerPos = rootPart.Position
		local targetPos: Vector3? = nil
		local targetLabelText: string? = nil

		if worldTargetType == "NEAREST_ORE" then
			local orePart, oreName, oreHp = findNearestLowLevelOre()
			if orePart then
				targetPos = orePart.Position
				targetLabelText = string.format("🎯 MINE THIS! (%s • %d HP)", oreName or "Stone", oreHp or 25)
			end
		elseif worldTargetType == "BLACKSMITH" then
			targetPos = Vector3.new(-38, 2, 0)
			targetLabelText = "🛒 BLACKSMITH (BUY PICKAXE)"
		elseif worldTargetType == "HATCHERY" then
			targetPos = Vector3.new(38, 2, 0)
			targetLabelText = "🐾 HATCHERY (GET PETS)"
		end

		if targetPos then
			-- Position overhead 3D arrow above target
			arrow.Transparency = 0
			ring.Transparency = 0.35 + math.sin(guideTime) * 0.15
			local bobY = math.sin(guideTime) * 0.8
			arrow.CFrame = CFrame.new(targetPos + Vector3.new(0, 6.5 + bobY, 0)) * CFrame.Angles(0, guideTime * 0.8, 0)
			ring.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.15, 0))

			targetBillboard.Enabled = true
			targetBillboardLabel.Text = targetLabelText or "🎯 OBJECTIVE"

			-- Update Ground Navigation Beam
			startPart.CFrame = CFrame.new(playerPos - Vector3.new(0, 2.3, 0))
			endPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.2, 0))
			guideBeam.Enabled = true

			-- Position Ground Chevron Arrows in a direct line to the target
			local delta = (targetPos - playerPos)
			local flatDelta = Vector3.new(delta.X, 0, delta.Z)
			local totalDist = flatDelta.Magnitude
			local dir = if totalDist > 0.1 then flatDelta.Unit else Vector3.new(0, 0, -1)

			local stepSpacing = 4.5
			local visibleChevrons = math.clamp(math.floor((totalDist - 4) / stepSpacing), 0, CHEVRON_COUNT)

			for i = 1, CHEVRON_COUNT do
				local ch = chevrons[i]
				if i <= visibleChevrons then
					ch.part.Transparency = 0.1
					local distFromPlayer = 3.5 + (i * stepSpacing)
					local pointPos = playerPos + (dir * distFromPlayer)
					pointPos = Vector3.new(pointPos.X, 0.25, pointPos.Z)

					ch.part.CFrame = CFrame.lookAt(pointPos, pointPos + dir)

					-- Animated ripple pulse travelling towards target
					local wave = (math.sin(guideTime * 6 - i * 0.7) + 1) * 0.5
					ch.part.Color = Color3.fromRGB(255, math.floor(190 + wave * 65), math.floor(30 + wave * 170))
					ch.label.TextColor3 = Color3.fromRGB(255, 255, math.floor(120 + wave * 135))
				else
					ch.part.Transparency = 1
				end
			end
		else
			arrow.Transparency = 1
			ring.Transparency = 1
			guideBeam.Enabled = false
			targetBillboard.Enabled = false
			for _, ch in ipairs(chevrons) do
				ch.part.Transparency = 1
			end
		end
	end)
end

-- Pulses a golden neon outline on target sidebar buttons
local function updateButtonSpotlight(buttonName: string?)
	clearButtonSpotlight()
	if not buttonName or isTutorialCompleted then return end

	local pGui = player:WaitForChild("PlayerGui")
	local miningHud = pGui:FindFirstChild("MiningHUD")
	if not miningHud then return end

	local sideMenu = miningHud:FindFirstChild("SideMenu")
	if not sideMenu then return end

	local targetBtn = sideMenu:FindFirstChild(buttonName) :: GuiObject?
	if not targetBtn then return end

	activeTargetButton = targetBtn

	local stroke = Instance.new("UIStroke")
	stroke.Name = "TutorialSpotlightStroke"
	stroke.Color = Color3.fromRGB(255, 215, 40)
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = targetBtn
	activeTargetStroke = stroke

	local pulseTime = 0
	activePulseConn = RunService.RenderStepped:Connect(function(dt)
		pulseTime += dt * 5
		local p = (math.sin(pulseTime) + 1) * 0.5
		if stroke and stroke.Parent then
			stroke.Thickness = 2.0 + p * 2.0
			stroke.Color = Color3.fromRGB(255, math.floor(180 + p * 75), math.floor(30 + p * 120))
		end
	end)
end

-- Builds the glassmorphic floating Tutorial Quest Card
local function buildTutorialGUI()
	if screenGui and screenGui.Parent then return end

	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("TutorialHUDGui")
	if existing then existing:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialHUDGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = pGui

	-- Master Quest Card Container
	questCard = Instance.new("Frame")
	questCard.Name = "TutorialQuestCard"
	questCard.Size = UDim2.new(0, 370, 0, 84)
	questCard.Position = UDim2.new(0.5, 0, 0, 16)
	questCard.AnchorPoint = Vector2.new(0.5, 0)
	questCard.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
	questCard.BackgroundTransparency = 0.15
	questCard.BorderSizePixel = 0
	questCard.Parent = screenGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = questCard

	cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "BorderGlow"
	cardStroke.Thickness = 2.0
	cardStroke.Color = Color3.fromRGB(80, 175, 255)
	cardStroke.Parent = questCard

	local cardGrad = Instance.new("UIGradient")
	cardGrad.Rotation = 90
	cardGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 28, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 14, 24)),
	})
	cardGrad.Parent = questCard

	-- Top Header Row: Step Badge & Skip Button
	local topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.Size = UDim2.new(1, -20, 0, 16)
	topRow.Position = UDim2.new(0, 10, 0, 6)
	topRow.BackgroundTransparency = 1
	topRow.Parent = questCard

	stepBadge = Instance.new("TextLabel")
	stepBadge.Name = "StepBadge"
	stepBadge.Size = UDim2.new(0, 200, 1, 0)
	stepBadge.BackgroundTransparency = 1
	stepBadge.Text = "🔰 BEGINNER QUEST • STEP 1 OF 5"
	stepBadge.TextColor3 = Color3.fromRGB(255, 215, 60)
	stepBadge.Font = Enum.Font.GothamBlack
	stepBadge.TextSize = 10
	stepBadge.TextXAlignment = Enum.TextXAlignment.Left
	stepBadge.TextStrokeTransparency = 0.3
	stepBadge.Parent = topRow

	skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipBtn"
	skipButton.Size = UDim2.new(0, 64, 1, 0)
	skipButton.Position = UDim2.new(1, -64, 0, 0)
	skipButton.BackgroundTransparency = 1
	skipButton.Text = "✕ Skip"
	skipButton.TextColor3 = Color3.fromRGB(155, 160, 185)
	skipButton.Font = Enum.Font.GothamBold
	skipButton.TextSize = 11
	skipButton.Parent = topRow

	skipButton.MouseEnter:Connect(function()
		skipButton.TextColor3 = Color3.fromRGB(255, 220, 90)
	end)
	skipButton.MouseLeave:Connect(function()
		skipButton.TextColor3 = Color3.fromRGB(155, 160, 185)
	end)

	-- Handle Skip Confirmation
	skipButton.MouseButton1Click:Connect(function()
		playLocalSound("rbxassetid://9114223170", 1.2, 0.6)
		local skipFn = Remotes.getFunction("SkipTutorial")
		local ok = pcall(function()
			return skipFn:InvokeServer()
		end)
		if ok then
			TutorialController.onTutorialCompleted(true)
		end
	end)

	-- Content Row: Icon, Title & Instruction
	local contentRow = Instance.new("Frame")
	contentRow.Name = "ContentRow"
	contentRow.Size = UDim2.new(1, -20, 0, 32)
	contentRow.Position = UDim2.new(0, 10, 0, 24)
	contentRow.BackgroundTransparency = 1
	contentRow.Parent = questCard

	iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 28, 1, 0)
	iconLabel.Position = UDim2.new(0, 0, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "⛏️"
	iconLabel.TextSize = 22
	iconLabel.Parent = contentRow

	local textCol = Instance.new("Frame")
	textCol.Name = "TextCol"
	textCol.Size = UDim2.new(1, -36, 1, 0)
	textCol.Position = UDim2.new(0, 34, 0, 0)
	textCol.BackgroundTransparency = 1
	textCol.Parent = contentRow

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 17)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "First Strike"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextStrokeTransparency = 0.25
	titleLabel.Parent = textCol

	instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "Instruction"
	instructionLabel.Size = UDim2.new(1, 0, 0, 14)
	instructionLabel.Position = UDim2.new(0, 0, 0, 16)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Mine 1 ore nearby in Zone 1"
	instructionLabel.TextColor3 = Color3.fromRGB(180, 215, 255)
	instructionLabel.Font = Enum.Font.GothamMedium
	instructionLabel.TextSize = 11
	instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
	instructionLabel.TextStrokeTransparency = 0.35
	instructionLabel.Parent = textCol

	-- Bottom Row: Animated Progress Bar & Reward Label
	local bottomRow = Instance.new("Frame")
	bottomRow.Name = "BottomRow"
	bottomRow.Size = UDim2.new(1, -20, 0, 16)
	bottomRow.Position = UDim2.new(0, 10, 0, 60)
	bottomRow.BackgroundTransparency = 1
	bottomRow.Parent = questCard

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBarBg"
	barBg.Size = UDim2.new(0, 170, 0, 8)
	barBg.Position = UDim2.new(0, 0, 0.5, 0)
	barBg.AnchorPoint = Vector2.new(0, 0.5)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
	barBg.BorderSizePixel = 0
	barBg.Parent = bottomRow

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(0, 235, 200)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = progressFill

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 60)),
	})
	fillGrad.Parent = progressFill

	progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ProgressText"
	progressLabel.Size = UDim2.new(0, 42, 1, 0)
	progressLabel.Position = UDim2.new(0, 176, 0, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = "0/1"
	progressLabel.TextColor3 = Color3.fromRGB(200, 210, 240)
	progressLabel.Font = Enum.Font.GothamBold
	progressLabel.TextSize = 10
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = bottomRow

	rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name = "RewardText"
	rewardLabel.Size = UDim2.new(1, -225, 1, 0)
	rewardLabel.Position = UDim2.new(1, 0, 0, 0)
	rewardLabel.AnchorPoint = Vector2.new(1, 0)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Text = "🎁 +$500 • +50 💎"
	rewardLabel.TextColor3 = Color3.fromRGB(115, 255, 165)
	rewardLabel.Font = Enum.Font.GothamBlack
	rewardLabel.TextSize = 10
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
	rewardLabel.TextStrokeTransparency = 0.25
	rewardLabel.Parent = bottomRow
end

-- Updates the Tutorial Quest Card UI with the current step definition & progress
function TutorialController.renderStep(stepNum: number, currentCount: number)
	if isTutorialCompleted or stepNum > TutorialConfig.getTotalSteps() then
		TutorialController.onTutorialCompleted(false)
		return
	end

	buildTutorialGUI()
	if not questCard or not questCard.Parent then return end

	local stepDef = TutorialConfig.getStep(stepNum)
	if not stepDef then return end

	currentStepNum = stepNum
	currentStepCount = currentCount

	questCard.Visible = true

	stepBadge.Text = string.format("🔰 BEGINNER QUEST • STEP %d OF %d", stepNum, TutorialConfig.getTotalSteps())
	titleLabel.Text = stepDef.title
	instructionLabel.Text = stepDef.shortInstruction
	iconLabel.Text = stepDef.icon
	rewardLabel.Text = "🎁 " .. stepDef.rewardText

	-- Progress Bar
	local count = math.clamp(currentCount, 0, stepDef.targetCount)
	local ratio = if stepDef.targetCount > 0 then (count / stepDef.targetCount) else 0
	progressLabel.Text = string.format("%d/%d", count, stepDef.targetCount)

	TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()

	-- Dynamic World & UI Spotlights
	updateWorldGuide(stepDef.worldTarget)
	updateButtonSpotlight(stepDef.targetUI)

	-- Pulse card stroke color to signal new step
	cardStroke.Color = Color3.fromRGB(255, 215, 60)
	TweenService:Create(cardStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(80, 175, 255),
	}):Play()
end

-- Plays triumphant animation and reward popup when a step is completed
function TutorialController.onStepCompleted(data: any)
	local stepNum = data.completedStep or currentStepNum
	local isFinal = data.isFinal or false

	playLocalSound("rbxassetid://9117970732", 1.15, 0.9) -- Crisp chime & coin sound

	if questCard and questCard.Parent then
		emitCardSparks(questCard, 24, Color3.fromRGB(255, 215, 50))

		-- Bounce Quest Card
		local pop = TweenService:Create(questCard, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 390, 0, 90),
		})
		pop:Play()
		pop.Completed:Connect(function()
			TweenService:Create(questCard, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 370, 0, 84),
			}):Play()
		end)
	end

	-- Floating Step Complete Banner
	local pGui = player:WaitForChild("PlayerGui")
	local toast = Instance.new("Frame")
	toast.Name = "TutorialStepToast"
	toast.Size = UDim2.new(0, 320, 0, 38)
	toast.Position = UDim2.new(0.5, 0, 0, 110)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(20, 65, 38)
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.ZIndex = 30
	toast.Parent = pGui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 10)
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(80, 240, 140)
	tStroke.Thickness = 1.8
	tStroke.Parent = toast

	local tLabel = Instance.new("TextLabel")
	tLabel.Size = UDim2.new(1, 0, 1, 0)
	tLabel.BackgroundTransparency = 1
	tLabel.Text = string.format("✨ STEP %d COMPLETE! %s", stepNum, data.rewardText or "")
	tLabel.TextColor3 = Color3.fromRGB(160, 255, 190)
	tLabel.Font = Enum.Font.GothamBlack
	tLabel.TextSize = 11
	tLabel.TextStrokeTransparency = 0.2
	tLabel.ZIndex = 31
	tLabel.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 116),
	}):Play()

	task.delay(2.6, function()
		if toast and toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, 95),
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Connect(function() toast:Destroy() end)
		end
	end)

	if isFinal then
		TutorialController.onTutorialCompleted(false)
	end
end

-- Handles full tutorial graduation ceremony
function TutorialController.onTutorialCompleted(wasSkipped: boolean)
	isTutorialCompleted = true
	clearWorldGuide()
	clearButtonSpotlight()

	if not wasSkipped then
		-- Victorious Fanfare
		playLocalSound("rbxassetid://5153737200", 1.0, 1.0)

		local pGui = player:WaitForChild("PlayerGui")
		local ceremony = Instance.new("Frame")
		ceremony.Name = "TutorialGraduationCeremony"
		ceremony.Size = UDim2.new(0, 420, 0, 90)
		ceremony.Position = UDim2.new(0.5, 0, 0.25, 0)
		ceremony.AnchorPoint = Vector2.new(0.5, 0.5)
		ceremony.BackgroundColor3 = Color3.fromRGB(24, 18, 42)
		ceremony.BackgroundTransparency = 0.1
		ceremony.BorderSizePixel = 0
		ceremony.ZIndex = 50
		ceremony.Parent = pGui

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 16)
		cCorner.Parent = ceremony

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(255, 215, 60)
		cStroke.Thickness = 2.5
		cStroke.Parent = ceremony

		local cTitle = Instance.new("TextLabel")
		cTitle.Size = UDim2.new(1, 0, 0, 32)
		cTitle.Position = UDim2.new(0, 0, 0, 10)
		cTitle.BackgroundTransparency = 1
		cTitle.Text = "🎓 TUTORIAL COMPLETE! 🎓"
		cTitle.TextColor3 = Color3.fromRGB(255, 225, 60)
		cTitle.Font = Enum.Font.GothamBlack
		cTitle.TextSize = 18
		cTitle.TextStrokeTransparency = 0.15
		cTitle.ZIndex = 51
		cTitle.Parent = ceremony

		local cSub = Instance.new("TextLabel")
		cSub.Size = UDim2.new(1, -20, 0, 36)
		cSub.Position = UDim2.new(0, 10, 0, 42)
		cSub.BackgroundTransparency = 1
		cSub.Text = "You earned +$10,000 Cash, +500 Gems, and unlocked the entire island! Go explore!"
		cSub.TextColor3 = Color3.fromRGB(220, 230, 255)
		cSub.Font = Enum.Font.GothamBold
		cSub.TextSize = 12
		cSub.TextWrapped = true
		cSub.TextStrokeTransparency = 0.3
		cSub.ZIndex = 51
		cSub.Parent = ceremony

		emitCardSparks(ceremony, 36, Color3.fromRGB(255, 215, 60))

		task.delay(4.5, function()
			if ceremony and ceremony.Parent then
				local fade = TweenService:Create(ceremony, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				})
				fade:Play()
				fade.Completed:Connect(function() ceremony:Destroy() end)
			end
		end)
	end

	-- Dismiss tutorial quest card smoothly
	if questCard and questCard.Parent then
		local dismiss = TweenService:Create(questCard, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -100),
			BackgroundTransparency = 1,
		})
		dismiss:Play()
		dismiss.Completed:Connect(function()
			if questCard then
				questCard.Visible = false
			end
		end)
	end
end

function TutorialController.init()
	print("🎓 [TutorialController] Initializing Tutorial Client Controller...")

	-- 1. Tutorial Progress Sync Handler
	local syncEvent = Remotes.getEvent("TutorialProgressSync")
	syncEvent.OnClientEvent:Connect(function(data)
		if data.completed then
			TutorialController.onTutorialCompleted(false)
		else
			TutorialController.renderStep(data.step or 1, data.currentCount or 0)
		end
	end)

	-- 2. Tutorial Step Completed Handler
	local completeEvent = Remotes.getEvent("TutorialStepCompleted")
	completeEvent.OnClientEvent:Connect(function(data)
		TutorialController.onStepCompleted(data)
	end)

	-- Re-render / update world guide on character respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if not isTutorialCompleted then
			TutorialController.renderStep(currentStepNum, currentStepCount)
		end
	end)
end

return TutorialController
