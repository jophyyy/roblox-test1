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

local MiningClient = {}
local activeTool: Tool? = nil
local isSwinging = false
local lastSwingTime = 0
local SWING_COOLDOWN = 0.28

-- Creates an authentic retro 3D Pickaxe Model
local function createPickaxeTool(toolName: string, headColor: Color3, isNeon: boolean?): Tool
	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -1.0, 0)
	tool.GripForward = Vector3.new(0, 1, 0)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	-- Handle (Wooden shaft)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 2.5, 0.35)
	handle.Color = Color3.fromRGB(130, 85, 55)
	handle.Material = Enum.Material.Wood
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Parent = tool

	-- Pickaxe Dual Curved Head
	local head = Instance.new("Part")
	head.Name = "PickHead"
	head.Size = Vector3.new(1.8, 0.45, 0.5)
	head.Color = headColor
	head.Material = if isNeon then Enum.Material.Neon else Enum.Material.Metal
	head.TopSurface = Enum.SurfaceType.Studs
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.CanCollide = false
	head.CFrame = handle.CFrame * CFrame.new(0, 1.1, 0)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	-- PointLight if rare/neon
	if isNeon then
		local light = Instance.new("PointLight")
		light.Color = headColor
		light.Brightness = 2.0
		light.Range = 8
		light.Parent = head
	end

	return tool
end

-- Give player their equipped 3D Pickaxe tool
function MiningClient.refreshTool()
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	-- Remove old pickaxes
	for _, item in backpack:GetChildren() do
		if item:IsA("Tool") and item.Name:find("Pickaxe") then
			item:Destroy()
		end
	end

	local char = player.Character
	if char then
		for _, item in char:GetChildren() do
			if item:IsA("Tool") and item.Name:find("Pickaxe") then
				item:Destroy()
			end
		end
	end

	-- Fetch equipped shovel/pickaxe from player data
	local toolName = "Rusty Pickaxe"
	local headColor = Color3.fromRGB(150, 110, 80)
	local isNeon = false

	local getFn = Remotes.getFunction("GetPlayerData")
	local ok, data = pcall(function()
		return getFn:InvokeServer()
	end)

	if ok and data and data.EquippedShovel then
		local toolDef = ShopConfig.getShovel(data.EquippedShovel)
		if toolDef then
			toolName = toolDef.name
			headColor = toolDef.color
			if toolDef.id == "shovel_diamond" or toolDef.id == "shovel_void" then
				isNeon = true
			end
		end
	end

	local tool = createPickaxeTool(toolName, headColor, isNeon)
	tool.Parent = backpack
	activeTool = tool

	tool.Activated:Connect(function()
		MiningClient.performSwing()
	end)
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

	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
	local rightShoulder = char:FindFirstChild("Right Shoulder", true) :: Motor6D?

	-- Arm swing tween if R6/R15 joint exists
	if rightShoulder then
		local originalC0 = rightShoulder.C0
		local windupC0 = originalC0 * CFrame.Angles(math.rad(45), math.rad(-20), 0)
		local strikeC0 = originalC0 * CFrame.Angles(math.rad(-75), math.rad(15), 0)

		local t1 = TweenService:Create(rightShoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = windupC0 })
		t1:Play()
		t1.Completed:Connect(function()
			local t2 = TweenService:Create(rightShoulder, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.In), { C0 = strikeC0 })
			t2:Play()
			t2.Completed:Connect(function()
				task.wait(0.05)
				local t3 = TweenService:Create(rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = originalC0 })
				t3:Play()
				t3.Completed:Connect(function()
					isSwinging = false
				end)
			end)
		end)
	else
		task.delay(SWING_COOLDOWN, function()
			isSwinging = false
		end)
	end

	-- Sound
	AudioController.playSound("rbxassetid://9114223170", 0.45, 1.0 + (math.random() * 0.2 - 0.1))

	-- Target Detection (Raycast or Closest Ore in Reach)
	local targetOreId: string? = nil
	local targetOrePart: BasePart? = nil

	-- 1. Check mouse target
	if mouse.Target then
		local model = mouse.Target:FindFirstAncestorOfClass("Model")
		if model and model.Parent and model.Parent.Name == "ActiveOres" then
			if rootPart and (mouse.Hit.Position - rootPart.Position).Magnitude <= OreConfig.MAX_MINE_DISTANCE then
				targetOreId = model.Name
				targetOrePart = model.PrimaryPart
			end
		end
	end

	-- 2. Fallback: Find closest ore in front of player
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
			local ok, res = pcall(function()
				return mineRemote:InvokeServer(targetOreId)
			end)
		end)
	end
end

-- Floating 3D Damage Number
function MiningClient.showDamageNumber(position: Vector3, damage: number, isCrit: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5 + (math.random(0, 10) / 10), math.random(-15, 15) / 10)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = if isCrit then string.format("💥 CRIT! -%d", damage) else string.format("-%d", damage)
	label.TextColor3 = if isCrit then Color3.fromRGB(255, 220, 40) else Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if isCrit then 20 else 15
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = if isCrit then Color3.fromRGB(180, 40, 0) else Color3.fromRGB(20, 20, 30)
	label.Parent = billboard

	-- Attach to an invisible temporary anchor
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	billboard.Parent = anchor

	-- Float up & fade
	local targetPos = position + Vector3.new(0, 3.5, 0)
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

-- Shatter explosion particle burst when ore is destroyed
function MiningClient.playShatterEffect(position: Vector3, oreType: string)
	AudioController.playSound("rbxassetid://9114223849", 0.6, 1.0 + (math.random() * 0.2 - 0.1))

	local oreDef = OreConfig.ORES[oreType] or OreConfig.ORES.Stone
	local chunkCount = 6

	for i = 1, chunkCount do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(0.6, 0.6, 0.6) * (0.6 + math.random() * 0.8)
		chunk.Color = (i % 2 == 0) and oreDef.accentColor or oreDef.color
		chunk.Material = Enum.Material.Neon
		chunk.CanCollide = false
		chunk.Anchored = false
		chunk.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
		chunk.Velocity = Vector3.new(
			math.random(-25, 25),
			math.random(18, 38),
			math.random(-25, 25)
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
	-- 1. Equip Pickaxe Tool on Character Spawn & Respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		MiningClient.refreshTool()
	end)

	if player.Character then
		task.spawn(function()
			task.wait(0.5)
			MiningClient.refreshTool()
		end)
	end

	-- 2. Listen for Item Purchases to refresh pickaxe model
	local itemPurchased = Remotes.getEvent("ItemPurchased")
	itemPurchased.OnClientEvent:Connect(function()
		task.wait(0.3)
		MiningClient.refreshTool()
	end)

	-- 3. Listen for Ore Damaged Event
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

	-- 4. Listen for Ore Destroyed Event
	local destroyedEvent = Remotes.getEvent("OreDestroyed")
	destroyedEvent.OnClientEvent:Connect(function(oreId: string, position: Vector3, oreType: string)
		MiningClient.playShatterEffect(position, oreType)
	end)

	print("✅ [MiningClient] Initialized with 3D pickaxe swinging and damage popups!")
end

return MiningClient
