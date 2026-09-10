--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PickaxeModelBuilder = require(ReplicatedStorage.Shared.Utils.PickaxeModelBuilder)
local DataService = require(script.Parent.DataService)

local PickaxeService = {}

local BASE_GRIP = CFrame.new(0, -0.65, 0) * CFrame.Angles(math.rad(12), 0, 0)

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

	-- 4. Construct Heroic Multi-Part 3D Pickaxe Model via Builder
	local pickaxeModel = PickaxeModelBuilder.buildPickaxe(toolDef)
	local handle = pickaxeModel.PrimaryPart or pickaxeModel:FindFirstChild("Handle") :: BasePart?
	if not handle then return end

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
