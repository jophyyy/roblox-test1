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

	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)
	local petStatsBonus = if okMastery and MasteryService then MasteryService.getPetStatsMultiplier(player) else 1.0
	local cashPetBonus = if okMastery and MasteryService then MasteryService.getCashPetMultiplier(player) else 1.0

	local mult = 1.0
	for petId, equipped in data.EquippedPets do
		if equipped and PetConfig.PETS[petId] then
			local petDef = PetConfig.PETS[petId]
			local bonus = (petDef.cashMultiplier - 1) * petStatsBonus * cashPetBonus
			if petDef.tier == "Rainbow" and okMastery and MasteryService then
				bonus *= MasteryService.getRainbowPetExtraMultiplier(player)
			end
			mult += bonus
		end
	end
	return mult
end

function PetService.getGemMultiplier(player: Player): number
	local data = DataService.get(player)
	if not data then return 1 end

	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)
	local petStatsBonus = if okMastery and MasteryService then MasteryService.getPetStatsMultiplier(player) else 1.0

	local mult = 1.0
	for petId, equipped in data.EquippedPets do
		if equipped and PetConfig.PETS[petId] then
			local petDef = PetConfig.PETS[petId]
			local bonus = (petDef.gemMultiplier - 1) * petStatsBonus
			if petDef.tier == "Rainbow" and okMastery and MasteryService then
				bonus *= MasteryService.getRainbowPetExtraMultiplier(player)
			end
			mult += bonus
		end
	end
	return mult
end

function PetService.hatchEgg(player: Player, eggId: string, count: number?): (boolean, any, string?)
	local hatchCount = if count and count > 0 then count else 1
	local eggDef = PetConfig.EGGS[eggId]
	if not eggDef then
		local hatchEvent = Remotes.getEvent("EggHatched")
		hatchEvent:FireClient(player, false, nil, "Invalid egg")
		return false, nil, "Invalid egg"
	end

	local data = DataService.get(player)
	if not data then
		return false, nil, "Player data not loaded"
	end

	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)

	if eggDef.currency == "Gems" then
		local discount = if okMastery and MasteryService then MasteryService.getEggCostDiscount(player) else 0
		local totalCost = math.max(1, math.floor(eggDef.cost * hatchCount * (1 - discount)))
		if data.Gems < totalCost then
			local hatchEvent = Remotes.getEvent("EggHatched")
			hatchEvent:FireClient(player, false, nil, "Not enough Gems! (Need " .. tostring(totalCost) .. " 💎)")
			return false, nil, "Not enough Gems"
		end
		-- Deduct gems
		DataService.addGems(player, -totalCost)
	end

	-- Award Egg Mastery XP
	if okMastery and MasteryService then
		MasteryService.addXP(player, "Eggs", 10 * hatchCount)
	end

	-- Calculate total drop pool weight
	local totalWeight = 0
	for _, entry in eggDef.dropPool do
		totalWeight += entry.weight
	end

	local pickedPetIds: { string } = {}
	for _ = 1, hatchCount do
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

		-- Add to inventory & discover in Pet Index
		data.OwnedPets[pickedPetId] = (data.OwnedPets[pickedPetId] or 0) + 1
		data.PetIndex = data.PetIndex or {}
		data.PetIndex[pickedPetId] = true
		table.insert(pickedPetIds, pickedPetId)
	end

	-- Sync
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	local hatchEvent = Remotes.getEvent("EggHatched")
	hatchEvent:FireClient(player, true, pickedPetIds, nil)

	return true, pickedPetIds, nil
end

function PetService.toggleEquip(player: Player, petId: string): boolean
	local data = DataService.get(player)
	if not data or not data.OwnedPets[petId] or data.OwnedPets[petId] <= 0 then
		return false
	end

	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)
	local extraSlots = if okMastery and MasteryService then MasteryService.getExtraEquippedSlots(player) else 0
	local maxAllowed = PetConfig.MAX_EQUIPPED + extraSlots

	if data.EquippedPets[petId] then
		data.EquippedPets[petId] = nil
	else
		local count = 0
		for _, equipped in data.EquippedPets do
			if equipped then count += 1 end
		end
		if count >= maxAllowed then
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
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 45

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

		if petDef.tier == "Golden" then
			part.Material = Enum.Material.Glass
			part.Reflectance = 0.4
			particles.Rate = 18
			particles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
			label.TextColor3 = Color3.fromRGB(255, 225, 60)
		elseif petDef.tier == "Rainbow" then
			part.Material = Enum.Material.Neon
			particles.Rate = 24
			particles.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 240)),
			})
			label.TextColor3 = Color3.fromRGB(255, 120, 240)
		end

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

-- Fuses 3 Normal pets into 1 Golden pet, or 3 Golden pets into 1 Rainbow pet
function PetService.fusePets(player: Player, mode: "Golden" | "Rainbow", rawBasePetId: string, fuseAll: boolean?): (boolean, string?, number?, string?)
	local data = DataService.get(player)
	if not data then
		return false, nil, 0, "Player data not loaded"
	end

	local baseId = PetConfig.getBasePetId(rawBasePetId)
	local baseDef = PetConfig.PETS[baseId]
	if not baseDef then
		return false, nil, 0, "Invalid pet species"
	end

	local sourcePetId: string
	local targetPetId: string

	if mode == "Golden" then
		-- Requires 3 Normal pets of species -> 1 Golden
		sourcePetId = baseId
		targetPetId = PetConfig.getGoldenId(baseId)
	elseif mode == "Rainbow" then
		-- Requires 3 Golden pets of species -> 1 Rainbow
		sourcePetId = PetConfig.getGoldenId(baseId)
		targetPetId = PetConfig.getRainbowId(baseId)
	else
		return false, nil, 0, "Invalid fusion mode"
	end

	local targetDef = PetConfig.PETS[targetPetId]
	if not targetDef then
		return false, nil, 0, "Target pet tier not found"
	end

	local ownedSourceCount = data.OwnedPets[sourcePetId] or 0
	if ownedSourceCount < 3 then
		local srcTierName = if mode == "Golden" then "Normal" else "Golden"
		return false, nil, 0, string.format("Need at least 3 %s %s to fuse (you have %d)!", srcTierName, baseDef.name, ownedSourceCount)
	end

	local batches = 1
	if fuseAll then
		batches = math.max(1, math.floor(ownedSourceCount / 3))
	end

	local consumeCount = batches * 3
	local remaining = ownedSourceCount - consumeCount

	if remaining <= 0 then
		data.OwnedPets[sourcePetId] = nil
		if data.EquippedPets[sourcePetId] then
			data.EquippedPets[sourcePetId] = nil
		end
	else
		data.OwnedPets[sourcePetId] = remaining
	end

	-- Grant fused pets
	data.OwnedPets[targetPetId] = (data.OwnedPets[targetPetId] or 0) + batches

	-- Register to Pet Index
	data.PetIndex = data.PetIndex or {}
	data.PetIndex[targetPetId] = true

	-- Update followers if equipped changed
	PetService.updateFollowers(player)

	-- Award Pet Fusion Mastery XP
	local successMsg = string.format("✨ FUSED %dx %s!", batches, targetDef.name)
	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)
	if okMastery and MasteryService then
		local xpPerBatch = if mode == "Golden" then 50 else 150
		MasteryService.addXP(player, "PetFusion", xpPerBatch * batches)

		local fusionLvl = MasteryService.getMasteryLevel(player, "PetFusion")
		if fusionLvl >= 50 and math.random() <= 0.15 then
			data.OwnedPets[targetPetId] = (data.OwnedPets[targetPetId] or 0) + 1
			successMsg ..= " 🔮 PHILOSOPHER'S DUPE (+1 Free)!"
		end
	end

	-- Sync updated data to client
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	print(string.format("⚗️ [PetService] %s fused %dx %s (%s)", player.Name, batches, targetDef.name, mode))

	return true, targetPetId, batches, successMsg
end

function PetService.init()
	local hatchRemote = Remotes.getFunction("HatchEgg")
	hatchRemote.OnServerInvoke = function(player: Player, eggId: string, count: number?)
		return PetService.hatchEgg(player, eggId, count)
	end

	local equipRemote = Remotes.getFunction("ToggleEquipPet")
	equipRemote.OnServerInvoke = function(player: Player, petId: string)
		return PetService.toggleEquip(player, petId)
	end

	local fuseRemote = Remotes.getFunction("FusePets")
	fuseRemote.OnServerInvoke = function(player: Player, mode: string, basePetId: string, fuseAll: boolean?)
		return PetService.fusePets(player, mode :: any, basePetId, fuseAll)
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
