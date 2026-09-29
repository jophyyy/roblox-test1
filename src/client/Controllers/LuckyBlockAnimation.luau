--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local LuckyBlockConfig = require(ReplicatedStorage.Shared.Config.LuckyBlockConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetModelBuilder = require(ReplicatedStorage.Shared.Utils.PetModelBuilder)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local LuckyBlockAnimation = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local camera = workspace.CurrentCamera

local SOUNDS = {
	Thud = "rbxassetid://6895079853",
	Click = "rbxassetid://6895079853",
	Crack = "rbxassetid://9069609268",
	Pop = "rbxassetid://6026985055",
	Fanfare = "rbxassetid://5153737200",
	Jackpot = "rbxassetid://5153737200",
	Chime = "rbxassetid://131886985",
	Shatter = "rbxassetid://9114223170",
}

local function playSound(soundId: string, volume: number?, pitch: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.7
	sound.PlaybackSpeed = pitch or 1.0
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
	return sound
end

local function getFXFolder(): Folder
	local folder = workspace:FindFirstChild("LuckyBlockWorldFX")
	if not folder or not folder:IsA("Folder") then
		folder = Instance.new("Folder")
		folder.Name = "LuckyBlockWorldFX"
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Attaches stud surface & bold question mark SurfaceGuis
local function attachQuestionFaces(part: BasePart, color: Color3)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs

	local faces = {
		Enum.NormalId.Front,
		Enum.NormalId.Back,
		Enum.NormalId.Left,
		Enum.NormalId.Right,
		Enum.NormalId.Top,
	}

	for _, face in ipairs(faces) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "LuckyFace_" .. face.Name
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 28
		sg.AlwaysOnTop = false
		sg.Parent = part

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "?"
		lbl.TextColor3 = color
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 85
		lbl.TextStrokeTransparency = 0.15
		lbl.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
		lbl.Parent = sg
	end
end

-- Builds reward 3D prop for in-world floating reveal
local function buildRewardProp(reward: LuckyBlockConfig.RewardItem, baseCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "LuckyRewardProp"

	if reward.type == "Pet" and reward.petId then
		local petDef = PetConfig.getPet(reward.petId)
		if petDef then
			local petModel = PetModelBuilder.buildDisplayModel(petDef)
			petModel.Name = "PetDisplay"
			local root = petModel.PrimaryPart
			if root then
				petModel:PivotTo(baseCF)
				petModel.Parent = model
				model.PrimaryPart = root
				return model
			end
		end
	end

	-- Procedural Gem / Cash / Star prop
	local root = Instance.new("Part")
	root.Name = "PropRoot"
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = baseCF
	root.Parent = model
	model.PrimaryPart = root

	if reward.type == "Cash" then
		root.Size = Vector3.new(2.4, 1.2, 1.6)
		root.Color = Color3.fromRGB(40, 200, 90)
		root.Material = Enum.Material.Neon

		local label = Instance.new("BillboardGui")
		label.Size = UDim2.new(0, 160, 0, 40)
		label.StudsOffset = Vector3.new(0, 1.5, 0)
		label.AlwaysOnTop = true
		label.Parent = root

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Text = "💵 " .. FormatNumber.format(reward.amount)
		t.TextColor3 = Color3.fromRGB(100, 255, 140)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 22
		t.TextStrokeTransparency = 0.2
		t.TextStrokeColor3 = Color3.fromRGB(10, 50, 20)
		t.Parent = label

	elseif reward.type == "Gems" then
		root.Size = Vector3.new(1.8, 1.8, 1.8)
		root.Shape = Enum.PartType.Ball
		root.Color = Color3.fromRGB(0, 230, 255)
		root.Material = Enum.Material.ForceField

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(0, 240, 255)
		light.Brightness = 3
		light.Range = 12
		light.Parent = root

		local label = Instance.new("BillboardGui")
		label.Size = UDim2.new(0, 160, 0, 40)
		label.StudsOffset = Vector3.new(0, 1.5, 0)
		label.AlwaysOnTop = true
		label.Parent = root

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Text = "💎 " .. FormatNumber.format(reward.amount)
		t.TextColor3 = Color3.fromRGB(150, 245, 255)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 22
		t.TextStrokeTransparency = 0.2
		t.TextStrokeColor3 = Color3.fromRGB(0, 30, 60)
		t.Parent = label

	else
		-- Rebirth or Generic
		root.Size = Vector3.new(2.0, 2.0, 2.0)
		root.Color = Color3.fromRGB(255, 205, 30)
		root.Material = Enum.Material.Neon

		local label = Instance.new("BillboardGui")
		label.Size = UDim2.new(0, 160, 0, 40)
		label.StudsOffset = Vector3.new(0, 1.5, 0)
		label.AlwaysOnTop = true
		label.Parent = root

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Text = "⭐ " .. reward.name
		t.TextColor3 = Color3.fromRGB(255, 240, 120)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 20
		t.TextStrokeTransparency = 0.2
		t.Parent = label
	end

	return model
end

-- ====================================================================
-- MAIN OPENING CUTSCENE
-- ====================================================================
function LuckyBlockAnimation.playOpen(
	blockDef: LuckyBlockConfig.LuckyBlockDef,
	reward: LuckyBlockConfig.RewardItem,
	remainingCount: number?,
	onFinished: (() -> ())?,
	onOpenAnother: (() -> ())?
)
	remainingCount = remainingCount or 0
	local char = player.Character
	if not char then
		if onFinished then onFinished() end
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		if onFinished then onFinished() end
		return
	end

	-- Freeze character safely
	local origWalkSpeed = humanoid.WalkSpeed
	local origJumpPower = humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	local fxFolder = getFXFolder()
	fxFolder:ClearAllChildren()

	-- Set up Cinematic Camera & Placement in front of player
	local origCameraType = camera.CameraType
	local origCameraSubject = camera.CameraSubject
	local origCameraCF = camera.CFrame

	camera.CameraType = Enum.CameraType.Scriptable

	-- Compute block position: 9 studs directly forward from camera, eye level
	local forwardVector = camera.CFrame.LookVector
	local blockPos = camera.CFrame.Position + (forwardVector * 9.5) + Vector3.new(0, -0.4, 0)
	local blockTargetCF = CFrame.new(blockPos, camera.CFrame.Position)

	-- ================================================================
	-- SCREEN GUI OVERLAY (Vignette & Controls)
	-- ================================================================
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LuckyBlockCutsceneGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 150
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(5, 5, 12)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	-- Vignette edge effect
	local vignetteGradient = Instance.new("UIGradient")
	vignetteGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
	vignetteGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.65, 0.75),
		NumberSequenceKeypoint.new(1, 0.95),
	})
	vignetteGradient.Parent = backdrop

	local isSkipped = false
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0, 110, 0, 38)
	skipBtn.Position = UDim2.new(1, -125, 0, 20)
	skipBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	skipBtn.BackgroundTransparency = 0.3
	skipBtn.Text = "⏩ SKIP"
	skipBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
	skipBtn.Font = Enum.Font.FredokaOne
	skipBtn.TextSize = 16
	skipBtn.BorderSizePixel = 0
	skipBtn.Parent = screenGui

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

	skipBtn.MouseButton1Click:Connect(function()
		isSkipped = true
		skipBtn.Visible = false
	end)

	-- ================================================================
	-- 3D PHYSICAL LUCKY BLOCK
	-- ================================================================
	local cube = Instance.new("Part")
	cube.Name = "CinematicLuckyCube"
	cube.Size = Vector3.new(3.6, 3.6, 3.6)
	cube.CFrame = blockTargetCF * CFrame.new(0, -6, 0) -- starts below, swoops up
	cube.Color = blockDef.cubeColor
	cube.Material = blockDef.material
	cube.Anchored = true
	cube.CanCollide = false
	cube.Parent = fxFolder

	attachQuestionFaces(cube, blockDef.questionColor)

	local pointLight = Instance.new("PointLight")
	pointLight.Color = blockDef.lightColor
	pointLight.Brightness = 1.8
	pointLight.Range = 22
	pointLight.Parent = cube

	-- Intro swoop-in
	playSound(SOUNDS.Thud, 0.8, 1.1)
	local introTween = TweenService:Create(cube, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = blockTargetCF,
	})
	introTween:Play()
	introTween.Completed:Wait()

	-- ================================================================
	-- PHASE 1: CHARGE-UP & INTENSE VIBRATION SHAKE
	-- ================================================================
	local rattleDuration = if isSkipped then 0.1 else 1.3
	local rattleStart = os.clock()
	local lastClickTime = 0
	local shakeConn: RBXScriptConnection? = nil

	shakeConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - rattleStart
		if elapsed >= rattleDuration or isSkipped then
			if shakeConn then
				shakeConn:Disconnect()
				shakeConn = nil
			end
			return
		end

		local progress = elapsed / rattleDuration
		local intensity = 0.04 + (progress * 0.18)
		local speed = 32 + (progress * 45)

		local rotOffset = math.sin(elapsed * speed) * intensity
		local liftOffset = math.sin(progress * math.pi) * 0.4
		cube.CFrame = blockTargetCF * CFrame.new(0, liftOffset, 0) * CFrame.Angles(rotOffset, rotOffset * 0.7, rotOffset)

		-- Light builds up inside
		pointLight.Brightness = 1.8 + (progress * 7.0)

		if os.clock() - lastClickTime >= (0.14 - (progress * 0.08)) then
			lastClickTime = os.clock()
			playSound(SOUNDS.Click, 0.35, 1.8 + (progress * 0.8))
		end
	end)

	if not isSkipped then
		task.wait(rattleDuration)
	end
	if shakeConn then
		shakeConn:Disconnect()
		shakeConn = nil
	end

	skipBtn.Visible = false

	-- ================================================================
	-- PHASE 2: SHATTER & EXPLOSION!
	-- ================================================================
	local shatterPos = cube.Position
	cube:Destroy()

	playSound(SOUNDS.Crack, 0.95, 1.05)
	playSound(SOUNDS.Pop, 0.8, 1.2)

	-- Scatter 8 Stud Debris Fragments outwards
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local frag = Instance.new("Part")
				frag.Size = Vector3.new(1.6, 1.6, 1.6)
				frag.CFrame = CFrame.new(shatterPos + Vector3.new(x * 0.9, y * 0.9, z * 0.9))
				frag.Color = blockDef.cubeColor
				frag.Material = blockDef.material
				frag.TopSurface = Enum.SurfaceType.Studs
				frag.BottomSurface = Enum.SurfaceType.Studs
				frag.Anchored = false
				frag.CanCollide = false
				frag.Velocity = Vector3.new(x * math.random(18, 36), math.random(14, 30), z * math.random(18, 36))
				frag.RotVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
				frag.Parent = fxFolder

				-- Fade out and destroy
				task.delay(0.6, function()
					if frag and frag.Parent then
						TweenService:Create(frag, TweenInfo.new(0.5), { Transparency = 1 }):Play()
						Debris:AddItem(frag, 0.5)
					end
				end)
			end
		end
	end

	-- Shockwave Ring Expansion
	local shockRing = Instance.new("Part")
	shockRing.Shape = Enum.PartType.Cylinder
	shockRing.Size = Vector3.new(0.2, 1, 1)
	shockRing.CFrame = CFrame.new(shatterPos) * CFrame.Angles(0, 0, math.rad(90))
	shockRing.Color = blockDef.lightColor
	shockRing.Material = Enum.Material.Neon
	shockRing.Anchored = true
	shockRing.CanCollide = false
	shockRing.Parent = fxFolder

	TweenService:Create(shockRing, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 14, 14),
		Transparency = 1,
	}):Play()
	Debris:AddItem(shockRing, 0.6)

	-- ================================================================
	-- PHASE 3: REWARD PROPS & MEGA JACKPOT (3X) REVEAL
	-- ================================================================
	local rewardModel = buildRewardProp(reward, CFrame.new(shatterPos))
	rewardModel.Parent = fxFolder
	local propRoot = rewardModel.PrimaryPart :: BasePart

	-- Apex upward launch with bounce
	local apexCF = CFrame.new(shatterPos + Vector3.new(0, 1.2, 0))
	local popTween = TweenService:Create(propRoot, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = apexCF,
	})
	popTween:Play()

	-- Gentle hovering & rotation loop
	local hoverConn: RBXScriptConnection? = nil
	local hoverStart = os.clock()
	hoverConn = RunService.RenderStepped:Connect(function()
		if not propRoot or not propRoot.Parent then
			if hoverConn then hoverConn:Disconnect() end
			return
		end
		local t = os.clock() - hoverStart
		propRoot.CFrame = apexCF * CFrame.new(0, math.sin(t * 2.8) * 0.3, 0) * CFrame.Angles(0, t * 1.5, 0)
	end)

	playSound(SOUNDS.Fanfare, 0.8, 1.0)

	-- ================================================================
	-- PHASE 4: MEGA JACKPOT CELEBRATION
	-- ================================================================
	local isJackpot = (reward.isMegaJackpot == true)
	if isJackpot then
		playSound(SOUNDS.Jackpot, 1.0, 1.1)

		-- Golden Fireworks Screen Banner
		local jackpotBanner = Instance.new("Frame")
		jackpotBanner.Name = "MegaJackpotBanner"
		jackpotBanner.Size = UDim2.new(0, 480, 0, 75)
		jackpotBanner.Position = UDim2.new(0.5, 0, 0.18, 0)
		jackpotBanner.AnchorPoint = Vector2.new(0.5, 0.5)
		jackpotBanner.BackgroundColor3 = Color3.fromRGB(255, 190, 0)
		jackpotBanner.BorderSizePixel = 0
		jackpotBanner.Parent = screenGui

		local jbCorner = Instance.new("UICorner")
		jbCorner.CornerRadius = UDim.new(0, 14)
		jbCorner.Parent = jackpotBanner

		local jbStroke = Instance.new("UIStroke")
		jbStroke.Color = Color3.fromRGB(255, 255, 220)
		jbStroke.Thickness = 3
		jbStroke.Parent = jackpotBanner

		local jbText = Instance.new("TextLabel")
		jbText.Size = UDim2.new(1, 0, 1, 0)
		jbText.BackgroundTransparency = 1
		jbText.Text = "🌟 MEGA JACKPOT! (3X MULTIPLIER) 🌟"
		jbText.TextColor3 = Color3.fromRGB(40, 15, 0)
		jbText.Font = Enum.Font.FredokaOne
		jbText.TextSize = 22
		jbText.Parent = jackpotBanner

		-- Pulsing scale animation
		task.spawn(function()
			while jackpotBanner and jackpotBanner.Parent do
				TweenService:Create(jackpotBanner, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Size = UDim2.new(0, 510, 0, 80),
				}):Play()
				task.wait(0.4)
				if not jackpotBanner or not jackpotBanner.Parent then break end
				TweenService:Create(jackpotBanner, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Size = UDim2.new(0, 480, 0, 75),
				}):Play()
				task.wait(0.4)
			end
		end)
	end

	-- ================================================================
	-- PHASE 5: REWARD CARD UI & CLAIM BUTTONS
	-- ================================================================
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "RewardCard"
	cardFrame.Size = UDim2.new(0, 400, 0, 160)
	cardFrame.Position = UDim2.new(0.5, 0, 1, 60)
	cardFrame.AnchorPoint = Vector2.new(0.5, 1)
	cardFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	cardFrame.BorderSizePixel = 0
	cardFrame.Parent = screenGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = cardFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = LuckyBlockConfig.TIER_COLORS[reward.rarity] or Color3.fromRGB(245, 180, 0)
	cardStroke.Thickness = 2.5
	cardStroke.Parent = cardFrame

	-- Tier Pill
	local tierPill = Instance.new("TextLabel")
	tierPill.Size = UDim2.new(0, 120, 0, 24)
	tierPill.Position = UDim2.new(0.5, 0, 0, 14)
	tierPill.AnchorPoint = Vector2.new(0.5, 0)
	tierPill.BackgroundColor3 = LuckyBlockConfig.TIER_COLORS[reward.rarity] or Color3.fromRGB(245, 180, 0)
	tierPill.Text = string.upper(reward.rarity)
	tierPill.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierPill.Font = Enum.Font.FredokaOne
	tierPill.TextSize = 13
	tierPill.BorderSizePixel = 0
	tierPill.Parent = cardFrame

	local tpCorner = Instance.new("UICorner")
	tpCorner.CornerRadius = UDim.new(0, 6)
	tpCorner.Parent = tierPill

	-- Reward Title
	local rewardTitle = Instance.new("TextLabel")
	rewardTitle.Size = UDim2.new(0.9, 0, 0, 36)
	rewardTitle.Position = UDim2.new(0.5, 0, 0, 44)
	rewardTitle.AnchorPoint = Vector2.new(0.5, 0)
	rewardTitle.BackgroundTransparency = 1
	rewardTitle.Text = reward.name
	rewardTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	rewardTitle.Font = Enum.Font.FredokaOne
	rewardTitle.TextSize = 22
	rewardTitle.TextStrokeTransparency = 0.5
	rewardTitle.Parent = cardFrame

	-- Action Row: Collect / Open Another
	local actionRow = Instance.new("Frame")
	actionRow.Size = UDim2.new(0.9, 0, 0, 48)
	actionRow.Position = UDim2.new(0.5, 0, 0, 95)
	actionRow.AnchorPoint = Vector2.new(0.5, 0)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = cardFrame

	local hasMore = (remainingCount > 0)

	local collectBtn = Instance.new("TextButton")
	collectBtn.Size = if hasMore then UDim2.new(0.48, 0, 1, 0) else UDim2.new(1, 0, 1, 0)
	collectBtn.Position = UDim2.new(0, 0, 0, 0)
	collectBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 115)
	collectBtn.Text = "✓ CLAIM"
	collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectBtn.Font = Enum.Font.FredokaOne
	collectBtn.TextSize = 17
	collectBtn.BorderSizePixel = 0
	collectBtn.Parent = actionRow

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 10)
	cbCorner.Parent = collectBtn

	local openAnotherBtn: TextButton? = nil
	if hasMore then
		openAnotherBtn = Instance.new("TextButton")
		openAnotherBtn.Size = UDim2.new(0.48, 0, 1, 0)
		openAnotherBtn.Position = UDim2.new(0.52, 0, 0, 0)
		openAnotherBtn.BackgroundColor3 = blockDef.cubeColor
		openAnotherBtn.Text = string.format("OPEN ANOTHER (%d)", remainingCount)
		openAnotherBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		openAnotherBtn.Font = Enum.Font.FredokaOne
		openAnotherBtn.TextSize = 13
		openAnotherBtn.BorderSizePixel = 0
		openAnotherBtn.Parent = actionRow

		local oaCorner = Instance.new("UICorner")
		oaCorner.CornerRadius = UDim.new(0, 10)
		oaCorner.Parent = openAnotherBtn
	end

	-- Slide card into view
	TweenService:Create(cardFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -40),
	}):Play()

	-- Collection Handler
	local isClosing = false
	local function doCollect(onDone: () -> ())
		if isClosing then return end
		isClosing = true

		if hoverConn then
			hoverConn:Disconnect()
			hoverConn = nil
		end

		playSound(SOUNDS.Chime, 0.75, 1.2)
		screenGui:Destroy()

		-- Prop absorption into player
		local absorbTargetCF = hrp.CFrame * CFrame.new(0, 0.5, 0)
		local absorbTween = TweenService:Create(propRoot, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			CFrame = absorbTargetCF,
		})
		absorbTween:Play()
		absorbTween.Completed:Wait()

		-- Restore controls & camera
		camera.CameraType = origCameraType or Enum.CameraType.Custom
		if origCameraSubject then
			camera.CameraSubject = origCameraSubject
		elseif humanoid then
			camera.CameraSubject = humanoid
		end

		humanoid.WalkSpeed = origWalkSpeed
		humanoid.JumpPower = origJumpPower

		fxFolder:ClearAllChildren()
		onDone()
	end

	collectBtn.MouseButton1Click:Connect(function()
		doCollect(function()
			if onFinished then onFinished() end
		end)
	end)

	if openAnotherBtn and onOpenAnother then
		openAnotherBtn.MouseButton1Click:Connect(function()
			doCollect(function()
				onOpenAnother()
			end)
		end)
	end

	-- Auto-collect failsafe after 12s if player is idle
	task.delay(12, function()
		if not isClosing then
			doCollect(function()
				if onFinished then onFinished() end
			end)
		end
	end)
end

return LuckyBlockAnimation
