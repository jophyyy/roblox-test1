--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local OreConfig = require(ReplicatedStorage.Shared.Config.OreConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local AudioController = require(script.Parent.AudioController)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = Workspace.CurrentCamera

local MiningClient = {}
local isSwinging = false
local isMouseDown = false
local lastSwingTime = 0
local SWING_COOLDOWN = 0.28
local activeHoldTrack: AnimationTrack? = nil

-- Current procedural swing angle applied during RunService.Stepped (overrides Roblox Animate script)
local currentArmSwingAngle = 0
local BASE_TOOL_GRIP = CFrame.new(0, -0.9, 0) * CFrame.Angles(math.rad(10), 0, 0)

-- Ensures the character is permanently in the active pickaxe-ready holding pose
function MiningClient.updateHoldingPose()
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Clean any legacy Tools from backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in backpack:GetChildren() do
			if item:IsA("Tool") and (item.Name:find("Pickaxe") or item.Name:find("Shovel")) then
				item:Destroy()
			end
		end
	end

	if activeHoldTrack and activeHoldTrack.IsPlaying then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
	local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
	local holdAnimId = if isR15 then "rbxassetid://507768223" else "rbxassetid://182393478"

	local animObj = Instance.new("Animation")
	animObj.AnimationId = holdAnimId

	local ok, track = pcall(function()
		return (animator :: any):LoadAnimation(animObj)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2, 1, 1)
		activeHoldTrack = track
	end
end

-- Refresh holding pose and clean legacy inventory items
function MiningClient.refreshTool()
	MiningClient.updateHoldingPose()
end

-- Finds the right shoulder joint across both R6 and R15 rigs
local function getRightShoulder(char: Model): Motor6D?
	local torso = char:FindFirstChild("Torso") -- R6
	if torso then
		local s = torso:FindFirstChild("Right Shoulder") :: Motor6D?
		if s then return s end
	end

	local rUpperArm = char:FindFirstChild("RightUpperArm") -- R15
	if rUpperArm then
		local s = rUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
		if s then return s end
	end

	return char:FindFirstChild("Right Shoulder", true) :: Motor6D?
end

-- Procedural Pickaxe Swing Animation
function MiningClient.performSwing()
	local now = os.clock()
	if isSwinging or (now - lastSwingTime) < SWING_COOLDOWN then
		return
	end
	isSwinging = true
	lastSwingTime = now

	local char = player.Character
	if not char then
		isSwinging = false
		return
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Maintain holding pose
	MiningClient.updateHoldingPose()

	-- 1. Play Humanoid AnimationTrack (Body & Arm slash motion)
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
		local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)
		local animId = if isR15 then "rbxassetid://507768375" else "rbxassetid://129967305"

		local animObj = Instance.new("Animation")
		animObj.AnimationId = animId
		task.spawn(function()
			local ok, track = pcall(function()
				return (animator :: any):LoadAnimation(animObj)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action4
				track:Play(0.04, 1, 1.9)
			end
		end)
	end

	-- 2. Procedural Arm Rotation + Tool Grip Chop
	task.spawn(function()
		local startTime = os.clock()
		local duration = SWING_COOLDOWN

		local rHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") :: BasePart?
		local gripMotor = if rHand then rHand:FindFirstChild("PickaxeGrip") :: Motor6D? else nil

		while true do
			local elapsed = os.clock() - startTime
			local progress = math.clamp(elapsed / duration, 0, 1)

			if progress <= 0.30 then
				-- Phase 1: Windup (Lift pickaxe back over shoulder)
				local p = progress / 0.30
				currentArmSwingAngle = p * 45
				if gripMotor then
					gripMotor.C1 = BASE_TOOL_GRIP * CFrame.new(0, 0.2 * p, -0.3 * p) * CFrame.Angles(math.rad(-40 * p), 0, math.rad(-10 * p))
				end
			elseif progress <= 0.65 then
				-- Phase 2: Heavy Downward Strike (Chop hard down into the ore!)
				local p = (progress - 0.30) / 0.35
				currentArmSwingAngle = 45 - (p * 135) -- Slams from +45 down to -90 degrees
				if gripMotor then
					local windupGrip = BASE_TOOL_GRIP * CFrame.new(0, 0.2, -0.3) * CFrame.Angles(math.rad(-40), 0, math.rad(-10))
					local strikeGrip = BASE_TOOL_GRIP * CFrame.new(0, -0.3, 0.4) * CFrame.Angles(math.rad(75), 0, math.rad(15))
					gripMotor.C1 = windupGrip:Lerp(strikeGrip, p)
				end
			else
				-- Phase 3: Recoil & Recovery (Snap back to neutral ready for next swing)
				local p = (progress - 0.65) / 0.35
				local easedP = TweenService:GetValue(p, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				currentArmSwingAngle = -90 * (1 - easedP)
				if gripMotor then
					local strikeGrip = BASE_TOOL_GRIP * CFrame.new(0, -0.3, 0.4) * CFrame.Angles(math.rad(75), 0, math.rad(15))
					gripMotor.C1 = strikeGrip:Lerp(BASE_TOOL_GRIP, easedP)
				end
			end

			if progress >= 1 then
				currentArmSwingAngle = 0
				if gripMotor then
					gripMotor.C1 = BASE_TOOL_GRIP
				end
				break
			end

			RunService.RenderStepped:Wait()
		end

		isSwinging = false
	end)

	-- Sound (Crisp Pickaxe Swoosh / Impact)
	AudioController.playSound("rbxassetid://9114223170", 0.5, 1.0 + (math.random() * 0.2 - 0.1))

	-- Target Detection: Priority 1 - Boss (if clicking on Boss or within melee reach of Boss)
	local targetBossId: string? = nil
	local bossFolder = Workspace:FindFirstChild("BossFolder")
	if bossFolder and rootPart then
		for _, bModel in bossFolder:GetChildren() do
			if bModel:IsA("Model") and bModel.PrimaryPart then
				local distToBoss = (bModel.PrimaryPart.Position - rootPart.Position).Magnitude
				if mouse.Target and mouse.Target:IsDescendantOf(bModel) and distToBoss <= 30 then
					targetBossId = bModel.Name
					break
				elseif distToBoss <= 22 then
					targetBossId = bModel.Name
					break
				end
			end
		end
	end

	if targetBossId then
		task.spawn(function()
			local attackBossFn = Remotes.getFunction("AttackBoss")
			local ok, success, res = pcall(function()
				return attackBossFn:InvokeServer(targetBossId)
			end)
			if ok and success and res and res.powerGained then
				MiningClient.showPowerGainPopup(res.powerGained)
			end
		end)
		return
	end

	-- Target Detection: Priority 2 - Training Ores (The Power Quarry Rebirth Training)
	local targetTrainingOreId: string? = nil
	local targetTrainingOrePart: BasePart? = nil

	local trainingFolder = Workspace:FindFirstChild("TrainingOres")
	if trainingFolder and rootPart then
		-- Check direct mouse target first
		if mouse.Target then
			local model = mouse.Target:FindFirstAncestorOfClass("Model")
			if model and model.Parent == trainingFolder then
				local core = model.PrimaryPart or model:FindFirstChild("OreCore") :: BasePart?
				if core and (core.Position - rootPart.Position).Magnitude <= 18 then
					targetTrainingOreId = model.Name
					targetTrainingOrePart = core
				end
			end
		end

		-- If not direct mouse target, check entity range & facing direction
		if not targetTrainingOreId then
			local lookDir = rootPart.CFrame.LookVector
			local closestDist = 16
			for _, model in trainingFolder:GetChildren() do
				if model:IsA("Model") then
					local core = model.PrimaryPart or model:FindFirstChild("OreCore") :: BasePart?
					if core then
						local toOre = core.Position - rootPart.Position
						local dist = toOre.Magnitude
						if dist <= closestDist then
							local dot = lookDir:Dot(toOre.Unit)
							-- Facing check: within frontal cone (dot >= 0.28)
							if dot >= 0.28 then
								closestDist = dist
								targetTrainingOreId = model.Name
								targetTrainingOrePart = core
							end
						end
					end
				end
			end
		end
	end

	if targetTrainingOreId and targetTrainingOrePart then
		task.spawn(function()
			local trainFn = Remotes.getFunction("TrainOnOre")
			local ok, success, res = pcall(function()
				return trainFn:InvokeServer(targetTrainingOreId)
			end)
			if ok and success and res and res.powerGained then
				MiningClient.showPowerGainPopup(res.powerGained)
				AudioController.playSound("rbxassetid://9114223170", 0.7, 1.1 + (math.random() * 0.2 - 0.1))
			elseif ok and not success and type(res) == "string" then
				local pGui = player:FindFirstChild("PlayerGui")
				local hudGui = pGui and pGui:FindFirstChild("MiningHUD")
				if hudGui then
					local warnLabel = Instance.new("TextLabel")
					warnLabel.Size = UDim2.new(0, 380, 0, 36)
					warnLabel.AnchorPoint = Vector2.new(0.5, 0.5)
					warnLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
					warnLabel.BackgroundTransparency = 1
					warnLabel.Text = "🔒 " .. res
					warnLabel.TextColor3 = Color3.fromRGB(255, 90, 80)
					warnLabel.Font = Enum.Font.GothamBlack
					warnLabel.TextSize = 18
					warnLabel.TextStrokeTransparency = 0.2
					warnLabel.Parent = hudGui

					local tw = TweenService:Create(warnLabel, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = warnLabel.Position - UDim2.new(0, 0, 0.08, 0),
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					})
					tw:Play()
					tw.Completed:Connect(function() warnLabel:Destroy() end)
				end
			end
		end)
		return
	end

	-- Target Detection: Priority 3 - Ores (Mouse Target or Closest Ore within reach)
	local targetOreId: string? = nil
	local targetOrePart: BasePart? = nil

	-- 1. Check mouse target
	if mouse.Target then
		local model = mouse.Target:FindFirstAncestorOfClass("Model")
		if model and model.Parent and model.Parent.Name == "ActiveOres" then
			if rootPart and (mouse.Hit.Position - rootPart.Position).Magnitude <= (OreConfig.MAX_MINE_DISTANCE + 4) then
				targetOreId = model.Name
				targetOrePart = model.PrimaryPart
			end
		end
	end

	-- 2. Fallback: Find closest ore in reach
	if not targetOreId and rootPart then
		local oresFolder = Workspace:FindFirstChild("ActiveOres")
		if oresFolder then
			local closestDist = OreConfig.MAX_MINE_DISTANCE
			for _, oreModel in oresFolder:GetChildren() do
				if oreModel:IsA("Model") and oreModel.PrimaryPart then
					local dist = (oreModel.PrimaryPart.Position - rootPart.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						targetOreId = oreModel.Name
						targetOrePart = oreModel.PrimaryPart
					end
				end
			end
		end
	end

	-- Mine Ore via Server
	if targetOreId then
		task.spawn(function()
			local mineRemote = Remotes.getFunction("MineOre")
			local ok, success, res = pcall(function()
				return mineRemote:InvokeServer(targetOreId)
			end)
			if ok and success and res and res.powerGained then
				MiningClient.showPowerGainPopup(res.powerGained)
			end
		end)
		return
	end

	-- Priority 3: Open Air Click - Train Click Power
	task.spawn(function()
		local clickPowerFn = Remotes.getFunction("ClickPower")
		local ok, success, powerGain = pcall(function()
			return clickPowerFn:InvokeServer()
		end)
		if ok and success and powerGain and powerGain > 0 then
			MiningClient.showPowerGainPopup(powerGain)
		end
	end)
end

-- Floating 3D Damage Number
function MiningClient.showDamageNumber(position: Vector3, damage: number, isCrit: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 130, 0, 44)
	billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5 + (math.random(0, 10) / 10), math.random(-15, 15) / 10)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = if isCrit then string.format("💥 CRIT! -%d", damage) else string.format("-%d", damage)
	label.TextColor3 = if isCrit then Color3.fromRGB(255, 220, 40) else Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if isCrit then 22 else 16
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = if isCrit then Color3.fromRGB(180, 40, 0) else Color3.fromRGB(20, 20, 30)
	label.Parent = billboard

	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	billboard.Parent = anchor

	local targetPos = position + Vector3.new(0, 3.8, 0)
	local tween = TweenService:Create(anchor, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	tween:Play()

	local textTween = TweenService:Create(label, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	textTween:Play()

	textTween.Completed:Connect(function()
		anchor:Destroy()
	end)
end

-- Floating Power Gain Indicator above player
function MiningClient.showPowerGainPopup(powerGained: number)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = char.HumanoidRootPart :: BasePart

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 36)
	billboard.StudsOffset = Vector3.new(math.random(-12, 12) / 10, 3.2 + (math.random(0, 8) / 10), math.random(-12, 12) / 10)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = string.format("+%s ⚡", FormatNumber.formatCompact(powerGained))
	label.TextColor3 = Color3.fromRGB(255, 225, 40)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 19
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(180, 80, 0)
	label.Parent = billboard

	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = rootPart.Position
	anchor.Parent = Workspace

	billboard.Parent = anchor

	local targetPos = anchor.Position + Vector3.new(0, 3.2, 0)
	local tween = TweenService:Create(anchor, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	})
	tween:Play()

	local textTween = TweenService:Create(label, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	textTween:Play()

	textTween.Completed:Connect(function()
		anchor:Destroy()
	end)
end

-- Shatter explosion particle burst when ore is destroyed
function MiningClient.playShatterEffect(position: Vector3, oreType: string)
	AudioController.playSound("rbxassetid://9114223849", 0.6, 1.0 + (math.random() * 0.2 - 0.1))

	local oreDef = OreConfig.ORES[oreType] or OreConfig.ORES.Stone
	local chunkCount = 7

	for i = 1, chunkCount do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(0.6, 0.6, 0.6) * (0.6 + math.random() * 0.8)
		chunk.Color = (i % 2 == 0) and oreDef.accentColor or oreDef.color
		chunk.Material = Enum.Material.Neon
		chunk.CanCollide = false
		chunk.Anchored = false
		chunk.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
		chunk.Velocity = Vector3.new(
			math.random(-26, 26),
			math.random(20, 40),
			math.random(-26, 26)
		)
		chunk.RotVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
		chunk.Parent = Workspace

		task.delay(0.7, function()
			TweenService:Create(chunk, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 0.1),
			}):Play()
		end)

		Debris:AddItem(chunk, 1.1)
	end
end

function MiningClient.init()
	-- 0. Disable Roblox Backpack Hotbar CoreGui (pickaxe is always held in hand, never an inventory slot)
	task.spawn(function()
		local StarterGui = game:GetService("StarterGui")
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then break end
			task.wait(0.25)
		end
	end)

	-- 1. Stepped Connection: Overrides character right shoulder joint AFTER Roblox Animate script evaluates
	RunService.Stepped:Connect(function()
		if currentArmSwingAngle ~= 0 then
			local char = player.Character
			if char then
				local shoulder = getRightShoulder(char)
				if shoulder then
					shoulder.Transform = shoulder.Transform * CFrame.Angles(math.rad(currentArmSwingAngle), math.rad(currentArmSwingAngle * 0.25), 0)
				end
			end
		end
	end)

	-- 2. Maintain Pickaxe Holding Pose on Character Spawn & Respawn
	player.CharacterAdded:Connect(function(char)
		task.wait(0.4)
		MiningClient.refreshTool()
	end)

	if player.Character then
		task.spawn(function()
			task.wait(0.4)
			MiningClient.refreshTool()
		end)
	end

	-- 3. Mouse Click & Hold-to-Mine Listener
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isMouseDown = true
			MiningClient.performSwing()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isMouseDown = false
		end
	end)

	-- Continuous Hold-to-Mine Loop
	task.spawn(function()
		while true do
			task.wait(0.04)
			if isMouseDown and not isSwinging then
				local now = os.clock()
				if (now - lastSwingTime) >= SWING_COOLDOWN then
					MiningClient.performSwing()
				end
			end
		end
	end)

	-- 4. Listen for Item Purchases to refresh pickaxe model
	local itemPurchased = Remotes.getEvent("ItemPurchased")
	itemPurchased.OnClientEvent:Connect(function()
		task.wait(0.3)
		MiningClient.refreshTool()
	end)

	-- 5. Listen for Ore Damaged Event
	local damagedEvent = Remotes.getEvent("OreDamaged")
	damagedEvent.OnClientEvent:Connect(function(oreId: string, damage: number, isCrit: boolean, health: number, maxHealth: number, position: Vector3)
		MiningClient.showDamageNumber(position, damage, isCrit)

		-- Elastic wobble on the hit ore model
		local oresFolder = Workspace:FindFirstChild("ActiveOres")
		if oresFolder then
			local model = oresFolder:FindFirstChild(oreId) :: Model?
			if model and model.PrimaryPart then
				local core = model.PrimaryPart
				local origSize = core.Size
				local squash = TweenService:Create(core, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = origSize * Vector3.new(1.18, 0.82, 1.18),
				})
				squash:Play()
				squash.Completed:Connect(function()
					TweenService:Create(core, TweenInfo.new(0.18, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
						Size = origSize,
					}):Play()
				end)
			end
		end
	end)

	-- 6. Listen for Ore Destroyed Event
	local destroyedEvent = Remotes.getEvent("OreDestroyed")
	destroyedEvent.OnClientEvent:Connect(function(oreId: string, position: Vector3, oreType: string)
		MiningClient.playShatterEffect(position, oreType)
	end)

	-- 7. Listen for Training Ore Hit Event (Squash & stretch wobble)
	local trainHitEvent = Remotes.getEvent("TrainingOreHit")
	trainHitEvent.OnClientEvent:Connect(function(oreId: string, playerName: string, powerGained: number, position: Vector3)
		local trainingFolder = Workspace:FindFirstChild("TrainingOres")
		if trainingFolder then
			local model = trainingFolder:FindFirstChild(oreId) :: Model?
			if model and model.PrimaryPart then
				local core = model.PrimaryPart
				local origSize = core.Size
				local squash = TweenService:Create(core, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = origSize * Vector3.new(1.16, 0.84, 1.16),
				})
				squash:Play()
				squash.Completed:Connect(function()
					TweenService:Create(core, TweenInfo.new(0.20, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
						Size = origSize,
					}):Play()
				end)
			end
		end
	end)

	print("✅ [MiningClient] Initialized with Stepped arm override, dynamic Grip chop, and hold-to-mine!")
end

return MiningClient
