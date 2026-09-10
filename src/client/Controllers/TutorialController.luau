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

-- Finds the closest active Zone 1 ore to the player
local function findNearestZone1Ore(): BasePart?
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local rootPos = char.HumanoidRootPart.Position

	local activeOres = Workspace:FindFirstChild("ActiveOres")
	if not activeOres then return nil end

	local closestPart: BasePart? = nil
	local closestDist = 120 -- Within 120 studs

	for _, oreModel in ipairs(activeOres:GetChildren()) do
		if oreModel:IsA("Model") and oreModel.PrimaryPart then
			local dist = (oreModel.PrimaryPart.Position - rootPos).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestPart = oreModel.PrimaryPart
			end
		end
	end

	return closestPart
end

-- Renders a vibrant 3D floating guide arrow above a target position
local function updateWorldGuide(worldTargetType: string?)
	clearWorldGuide()
	if not worldTargetType or isTutorialCompleted then return end

	local guideModel = Instance.new("Model")
	guideModel.Name = "TutorialWorldGuide"
	guideModel.Parent = Workspace
	activeWorldGuideModel = guideModel

	-- Glowing Arrow Head (Inverted Diamond/Cone)
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

	-- Glowing Ground Warning Ring
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

	local guideTime = 0
	activeGuideConn = RunService.RenderStepped:Connect(function(dt)
		guideTime += dt * 3.5

		local targetPos: Vector3? = nil
		if worldTargetType == "NEAREST_ORE" then
			local orePart = findNearestZone1Ore()
			if orePart then
				targetPos = orePart.Position
			end
		elseif worldTargetType == "BLACKSMITH" then
			targetPos = Vector3.new(-38, 2, 0)
		elseif worldTargetType == "HATCHERY" then
			targetPos = Vector3.new(38, 2, 0)
		end

		if targetPos then
			arrow.Transparency = 0
			ring.Transparency = 0.35 + math.sin(guideTime) * 0.15
			local bobY = math.sin(guideTime) * 0.8
			arrow.CFrame = CFrame.new(targetPos + Vector3.new(0, 6.5 + bobY, 0)) * CFrame.Angles(0, guideTime * 0.6, 0)
			ring.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.15, 0))
		else
			arrow.Transparency = 1
			ring.Transparency = 1
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
