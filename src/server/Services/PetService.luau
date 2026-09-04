--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)

local PetService = {}

-- Track active visual follower models: [Player] -> { [petId]: Model }
local activePetModels: { [Player]: { [string]: Model } } = {}

function PetService.getCashMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data then return 1 end

	local mult = 1.0
	for petId, equipped in data.EquippedPets do
		if equipped and PetConfig.PETS[petId] then
			mult += (PetConfig.PETS[petId].cashMultiplier - 1)
		end
	end
	return mult
end

function PetService.getGemMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data then return 1 end

	local mult = 1.0
	for petId, equipped in data.EquippedPets do
		if equipped and PetConfig.PETS[petId] then
			mult += (PetConfig.PETS[petId].gemMultiplier - 1)
		end
	end
	return mult
end

function PetService.hatchEgg(player: Player, eggId: string): (boolean, string?, string?)
	local eggDef = PetConfig.EGGS[eggId]
	if not eggDef then return false, nil, "Invalid egg" end

	local data = DataService.get(player)
	if not data or data.Gems < eggDef.cost then
		return false, nil, "Not enough Gems"
	end

	-- Deduct gems
	DataService.addGems(player, -eggDef.cost)

	-- Roll weighted table
	local totalWeight = 0
	for _, entry in eggDef.dropPool do
		totalWeight += entry.weight
	end

	local roll = math.random() * totalWeight
	local current = 0
	local pickedPetId = eggDef.dropPool[1].petId

	for _, entry in eggDef.dropPool do
		current += entry.weight
		if roll <= current then
			pickedPetId = entry.petId
			break
		end
	end

	-- Add to inventory
	data.OwnedPets[pickedPetId] = (data.OwnedPets[pickedPetId] or 0) + 1

	-- Sync
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	return true, pickedPetId, nil
end

function PetService.toggleEquip(player: Player, petId: string): boolean
	local data = DataService.get(player)
	if not data or not data.OwnedPets[petId] or data.OwnedPets[petId] <= 0 then
		return false
	end

	if data.EquippedPets[petId] then
		data.EquippedPets[petId] = nil
	else
		local count = 0
		for _, equipped in data.EquippedPets do
			if equipped then count += 1 end
		end
		if count >= PetConfig.MAX_EQUIPPED then
			return false
		end
		data.EquippedPets[petId] = true
	end

	PetService.updateFollowers(player)

	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)
	return true
end

function PetService.updateFollowers(player: Player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local rootPart = character.HumanoidRootPart :: BasePart

	-- Clear old models
	if activePetModels[player] then
		for _, model in activePetModels[player] do
			model:Destroy()
		end
	end
	activePetModels[player] = {}

	local data = DataService.get(player)
	if not data then return end

	local equippedList = {}
	for petId, eq in data.EquippedPets do
		if eq and PetConfig.PETS[petId] then
			table.insert(equippedList, PetConfig.PETS[petId])
		end
	end

	local petFolder = Workspace:FindFirstChild("PlayerPets")
	if not petFolder then
		petFolder = Instance.new("Folder")
		petFolder.Name = "PlayerPets"
		petFolder.Parent = Workspace
	end

	for index, petDef in ipairs(equippedList) do
		local petModel = Instance.new("Model")
		petModel.Name = player.Name .. "_" .. petDef.name

		local part = Instance.new("Part")
		part.Name = "PrimaryPart"
		part.Size = Vector3.new(2, 2, 2)
		part.CanCollide = false
		part.Massless = true
		part.Color = petDef.color
		part.Material = Enum.Material.SmoothPlastic

		if petDef.meshType == "Sphere" then
			part.Shape = Enum.PartType.Ball
		end

		-- Floating Billboard tag
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 100, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 1.8, 0)
		billboard.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = petDef.name
		label.TextColor3 = petDef.color
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.Parent = billboard
		billboard.Parent = part

		-- Soft particle glow
		local attachment = Instance.new("Attachment")
		attachment.Parent = part

		local particles = Instance.new("ParticleEmitter")
		particles.Size = NumberSequence.new(0.3, 0.1)
		particles.Rate = 12
		particles.Lifetime = NumberRange.new(0.6, 1.0)
		particles.Color = ColorSequence.new(petDef.color)
		particles.Speed = NumberRange.new(1, 2)
		particles.Parent = attachment

		-- Follow physics via AlignPosition and AlignOrientation
		local charAttachment = Instance.new("Attachment")
		local angle = ((index - 1) / math.max(1, #equippedList)) * math.pi * 2
		local offsetX = math.cos(angle) * 4
		local offsetZ = math.sin(angle) * 4 + 3
		charAttachment.Position = Vector3.new(offsetX, 1.5, offsetZ)
		charAttachment.Parent = rootPart

		local alignPos = Instance.new("AlignPosition")
		alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
		alignPos.Attachment0 = attachment
		alignPos.Attachment1 = charAttachment
		alignPos.MaxForce = 50000
		alignPos.Responsiveness = 15
		alignPos.Parent = part

		local alignRot = Instance.new("AlignOrientation")
		alignRot.Mode = Enum.OrientationAlignmentMode.TwoAttachment
		alignRot.Attachment0 = attachment
		alignRot.Attachment1 = charAttachment
		alignRot.MaxTorque = 50000
		alignRot.Responsiveness = 15
		alignRot.Parent = part

		part.CFrame = rootPart.CFrame * CFrame.new(offsetX, 1.5, offsetZ)
		part.Parent = petModel
		petModel.PrimaryPart = part
		petModel.Parent = petFolder

		activePetModels[player][petDef.id] = petModel
	end
end

function PetService.init()
	local hatchRemote = Remotes.getFunction("HatchEgg")
	hatchRemote.OnServerInvoke = function(player: Player, eggId: string)
		return PetService.hatchEgg(player, eggId)
	end

	local equipRemote = Remotes.getFunction("ToggleEquipPet")
	equipRemote.OnServerInvoke = function(player: Player, petId: string)
		return PetService.toggleEquip(player, petId)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			PetService.updateFollowers(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if activePetModels[player] then
			for _, model in activePetModels[player] do
				model:Destroy()
			end
			activePetModels[player] = nil
		end
	end)
end

return PetService
