--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local DataService = require(script.Parent.DataService)

local PickaxeService = {}

local BASE_GRIP = CFrame.new(0, -0.9, 0) * CFrame.Angles(math.rad(10), 0, 0)

-- Spawns or updates the 3D pickaxe model welded permanently to the player's right hand
function PickaxeService.updatePlayerPickaxe(player: Player)
	local char = player.Character
	if not char then return end

	-- 1. Strip any legacy Tools from Backpack or Character so there is never an inventory tool
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in backpack:GetChildren() do
			if item:IsA("Tool") and (item.Name:find("Pickaxe") or item.Name:find("Shovel")) then
				item:Destroy()
			end
		end
	end

	for _, item in char:GetChildren() do
		if item:IsA("Tool") and (item.Name:find("Pickaxe") or item.Name:find("Shovel")) then
			item:Destroy()
		end
	end

	-- 2. Remove existing equipped pickaxe model
	local oldPickaxe = char:FindFirstChild("EquippedPickaxe")
	if oldPickaxe then
		oldPickaxe:Destroy()
	end

	local rHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") :: BasePart?
	if not rHand then return end

	-- Remove old grip motor if any
	local oldGrip = rHand:FindFirstChild("PickaxeGrip")
	if oldGrip then
		oldGrip:Destroy()
	end

	-- 3. Fetch equipped pickaxe config
	local data = DataService.get(player)
	local shovelId = if data and data.EquippedShovel then data.EquippedShovel else "shovel_rusty"
	local toolDef = ShopConfig.getShovel(shovelId)
	if not toolDef then return end

	local isNeon = (toolDef.id == "shovel_diamond" or toolDef.id == "shovel_void" or toolDef.id == "shovel_magma" or toolDef.id == "shovel_infernal")

	-- 4. Construct Authentic Retro 3D Pickaxe Model
	local pickaxeModel = Instance.new("Model")
	pickaxeModel.Name = "EquippedPickaxe"

	-- Handle (Wooden Shaft)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 2.5, 0.35)
	handle.Color = Color3.fromRGB(130, 85, 55)
	handle.Material = Enum.Material.Wood
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	handle.Parent = pickaxeModel
	pickaxeModel.PrimaryPart = handle

	-- Pickaxe Dual Curved Head with Studs
	local head = Instance.new("Part")
	head.Name = "PickHead"
	head.Size = Vector3.new(1.9, 0.5, 0.55)
	head.Color = toolDef.color
	head.Material = if isNeon then Enum.Material.Neon else Enum.Material.Metal
	head.TopSurface = Enum.SurfaceType.Studs
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.CanCollide = false
	head.Massless = true
	head.Anchored = false
	head.CFrame = handle.CFrame * CFrame.new(0, 1.15, 0)
	head.Parent = pickaxeModel

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = handle
	headWeld.Part1 = head
	headWeld.Parent = handle

	-- Glowing point light and sparks for higher-tier pickaxes
	if isNeon then
		local light = Instance.new("PointLight")
		light.Color = toolDef.color
		light.Brightness = 2.4
		light.Range = 9
		light.Parent = head

		local attach = Instance.new("Attachment")
		attach.Parent = head

		local sparks = Instance.new("ParticleEmitter")
		sparks.Size = NumberSequence.new(0.25, 0.05)
		sparks.Rate = 10
		sparks.Speed = NumberRange.new(0.5, 1.5)
		sparks.Color = ColorSequence.new(toolDef.color)
		sparks.Parent = attach
	end

	-- 5. Weld Handle directly to Player's Right Hand via Motor6D
	local gripAtt = rHand:FindFirstChild("RightGripAttachment") :: Attachment?

	local motor = Instance.new("Motor6D")
	motor.Name = "PickaxeGrip"
	motor.Part0 = rHand
	motor.Part1 = handle
	motor.C0 = if gripAtt then gripAtt.CFrame else CFrame.new(0, -0.85, 0)
	motor.C1 = BASE_GRIP
	motor.Parent = rHand

	pickaxeModel.Parent = char
end

function PickaxeService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			PickaxeService.updatePlayerPickaxe(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				task.wait(0.3)
				PickaxeService.updatePlayerPickaxe(player)
			end)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			PickaxeService.updatePlayerPickaxe(player)
		end)
	end

	print("✅ [PickaxeService] Initialized with permanent hand-held 3D pickaxe manager!")
end

return PickaxeService
