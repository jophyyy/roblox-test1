--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LuckyBlockConfig = require(ReplicatedStorage.Shared.Config.LuckyBlockConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local LuckyBlockService = {}

local quarryBlocksFolder: Folder
local SPAWN_INTERVAL = 80 -- seconds between physical quarry spawns
local BLOCK_LIFETIME = 180 -- despawn time if unmined

-- Utility: Stud Part
local function createStudPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

-- Attaches bold '?' labels to all 5 visible faces
local function attachQuestionMarks(parentPart: BasePart, color: Color3)
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
		sg.PixelsPerStud = 30
		sg.AlwaysOnTop = false
		sg.Parent = parentPart

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "?"
		lbl.TextColor3 = color
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 80
		lbl.TextStrokeTransparency = 0.2
		lbl.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
		lbl.Parent = sg
	end
end

-- 1. Construct 3D Physical Lucky Block Model
function LuckyBlockService.createBlockModel(tierId: string, spawnCF: CFrame): Model
	local blockDef = LuckyBlockConfig.getBlock(tierId) or LuckyBlockConfig.BLOCKS.block_gold

	local model = Instance.new("Model")
	model.Name = "QuarryLuckyBlock_" .. blockDef.id

	local cube = Instance.new("Part")
	cube.Name = "LuckyCube"
	cube.Size = Vector3.new(4, 4, 4)
	cube.CFrame = spawnCF
	cube.Color = blockDef.cubeColor
	cube.Material = blockDef.material
	cube.TopSurface = Enum.SurfaceType.Studs
	cube.BottomSurface = Enum.SurfaceType.Smooth
	cube.Anchored = true
	cube.CanCollide = true
	cube.Parent = model
	model.PrimaryPart = cube

	attachQuestionMarks(cube, blockDef.questionColor)

	-- Glowing Beacon Beam into sky
	local beamPart = Instance.new("Part")
	beamPart.Name = "BeaconBeam"
	beamPart.Size = Vector3.new(0.6, 60, 0.6)
	beamPart.CFrame = spawnCF * CFrame.new(0, 30, 0)
	beamPart.Color = blockDef.lightColor
	beamPart.Material = Enum.Material.Neon
	beamPart.Transparency = 0.45
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Parent = model

	local light = Instance.new("PointLight")
	light.Color = blockDef.lightColor
	light.Range = 24
	light.Brightness = 2.4
	light.Parent = cube

	-- Floating Rotating Question Mark Icon overhead
	local floatPart = Instance.new("Part")
	floatPart.Name = "OverheadIcon"
	floatPart.Size = Vector3.new(1.8, 1.8, 0.4)
	floatPart.CFrame = spawnCF * CFrame.new(0, 5.5, 0)
	floatPart.Color = blockDef.questionColor
	floatPart.Material = Enum.Material.Neon
	floatPart.Anchored = true
	floatPart.CanCollide = false
	floatPart.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Name = "BlockBillboard"
	bb.Size = UDim2.new(0, 140, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = cube

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 1, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = string.format("❓ %s", string.upper(blockDef.name))
	nameLbl.TextColor3 = blockDef.lightColor
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextSize = 14
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLbl.Parent = bb

	model:SetAttribute("IsQuarryLuckyBlock", true)
	model:SetAttribute("TierId", blockDef.id)
	model:SetAttribute("HitsRemaining", 3)

	return model
end

-- 2. Spawn a physical Lucky Block in Quarry Terrain
function LuckyBlockService.spawnQuarryBlock()
	if not quarryBlocksFolder then return end

	-- Clean old unmined blocks
	if #quarryBlocksFolder:GetChildren() >= 3 then
		local oldest = quarryBlocksFolder:GetChildren()[1]
		if oldest then oldest:Destroy() end
	end

	-- Pick random quarry coordinate
	local spawnLocations = {
		Vector3.new(0, 2.5, -45),
		Vector3.new(-25, 2.5, -60),
		Vector3.new(25, 2.5, -60),
		Vector3.new(-35, 2.5, -95),
		Vector3.new(35, 2.5, -95),
		Vector3.new(0, 2.5, -120),
		Vector3.new(-20, 2.5, -150),
		Vector3.new(20, 2.5, -150),
	}
	local basePos = spawnLocations[math.random(1, #spawnLocations)]
	local spawnCF = CFrame.new(basePos.X + math.random(-6, 6), basePos.Y + 2.0, basePos.Z + math.random(-6, 6))

	-- Random tier: 50% Gold, 35% Iron, 15% Diamond
	local r = math.random()
	local tierId = if r < 0.35 then "block_iron" elseif r < 0.85 then "block_gold" else "block_diamond"

	local blockModel = LuckyBlockService.createBlockModel(tierId, spawnCF)
	blockModel.Parent = quarryBlocksFolder

	-- Auto-despawn timer
	task.delay(BLOCK_LIFETIME, function()
		if blockModel and blockModel.Parent then
			blockModel:Destroy()
		end
	end)
end

-- 3. Hit and Mine Physical Quarry Lucky Block
function LuckyBlockService.hitQuarryBlock(player: Player, blockModel: Model): (boolean, boolean)
	if not blockModel or not blockModel.Parent then return false, false end
	local hitsRemaining = blockModel:GetAttribute("HitsRemaining") or 3
	local tierId = blockModel:GetAttribute("TierId") or "block_gold"
	local cube = blockModel.PrimaryPart or blockModel:FindFirstChild("LuckyCube") :: BasePart?
	if not cube then return false, false end

	hitsRemaining -= 1
	blockModel:SetAttribute("HitsRemaining", hitsRemaining)

	-- Hit wobble animation
	local originalCF = cube.CFrame
	local wobble = TweenService:Create(cube, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = originalCF * CFrame.Angles(math.rad(math.random(-8, 8)), 0, math.rad(math.random(-8, 8))),
	})
	wobble:Play()
	wobble.Completed:Connect(function()
		cube.CFrame = originalCF
	end)

	if hitsRemaining > 0 then
		-- Chip sound & sparks
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://9114223170"
		snd.Volume = 0.7
		snd.Parent = cube
		snd:Play()
		Debris:AddItem(snd, 1)
		return true, false
	else
		-- 3rd Hit: SHATTER & BREAK!
		local blockDef = LuckyBlockConfig.getBlock(tierId) or LuckyBlockConfig.BLOCKS.block_gold
		local cPos = cube.Position

		-- Scatter 8 Physics debris fragments
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local frag = Instance.new("Part")
					frag.Size = Vector3.new(1.8, 1.8, 1.8)
					frag.CFrame = CFrame.new(cPos + Vector3.new(x * 1.2, y * 1.2, z * 1.2))
					frag.Color = blockDef.cubeColor
					frag.Material = blockDef.material
					frag.TopSurface = Enum.SurfaceType.Studs
					frag.Anchored = false
					frag.CanCollide = true
					frag.Velocity = Vector3.new(x * math.random(15, 35), math.random(25, 45), z * math.random(15, 35))
					frag.Parent = Workspace
					Debris:AddItem(frag, 1.5)
				end
			end
		end

		-- Break sound
		local breakSound = Instance.new("Sound")
		breakSound.SoundId = "rbxassetid://9069609268"
		breakSound.Volume = 0.9
		breakSound.Parent = Workspace
		breakSound:Play()
		Debris:AddItem(breakSound, 2)

		-- Award Rewards to Player
		local data = DataService.get(player)
		if data then
			local cashBonus = math.random(25000, 100000)
			local gemsBonus = math.random(50, 200)

			data.Cash = (data.Cash or 0) + cashBonus
			data.Gems = (data.Gems or 0) + gemsBonus

			-- Give free Lucky Block into inventory
			data.LuckyBlocks = data.LuckyBlocks or {}
			data.LootBoxes = data.LootBoxes or {}
			data.LuckyBlocks[tierId] = (data.LuckyBlocks[tierId] or 0) + 1
			data.LootBoxes[tierId] = (data.LootBoxes[tierId] or 0) + 1
		end

		blockModel:Destroy()
		return true, true
	end
end

-- 4. Open Lucky Block from Inventory / Vault
function LuckyBlockService.openBlock(player: Player, rawBlockId: string): (boolean, any)
	local resolvedId = LuckyBlockConfig.resolveBlockId(rawBlockId)
	local blockDef = LuckyBlockConfig.getBlock(resolvedId)
	if not blockDef then
		return false, "Unknown Lucky Block"
	end

	local data = DataService.get(player)
	if not data then return false, "No player data" end

	data.LuckyBlocks = data.LuckyBlocks or {}
	data.LootBoxes = data.LootBoxes or {}

	-- Check inventory across both modern and legacy keys
	local ownedCount = (data.LuckyBlocks[resolvedId] or 0) + (data.LootBoxes[resolvedId] or 0) + (data.LootBoxes[rawBlockId] or 0)
	if ownedCount <= 0 then
		return false, "You do not own any of this Lucky Block!"
	end

	-- Decrement inventory safely
	if (data.LuckyBlocks[resolvedId] or 0) > 0 then
		data.LuckyBlocks[resolvedId] -= 1
	elseif (data.LootBoxes[resolvedId] or 0) > 0 then
		data.LootBoxes[resolvedId] -= 1
	elseif (data.LootBoxes[rawBlockId] or 0) > 0 then
		data.LootBoxes[rawBlockId] -= 1
	end

	-- Roll reward
	local reward = LuckyBlockConfig.rollReward(resolvedId)

	-- Apply reward
	if reward.type == "Cash" then
		data.Cash = (data.Cash or 0) + reward.amount
	elseif reward.type == "Gems" then
		data.Gems = (data.Gems or 0) + reward.amount
	elseif reward.type == "Pet" and reward.petId then
		PetService.awardPet(player, reward.petId)
	elseif reward.type == "Rebirth" then
		data.Rebirths = (data.Rebirths or 0) + reward.amount
	end

	local remaining = (data.LuckyBlocks[resolvedId] or 0) + (data.LootBoxes[resolvedId] or 0)

	return true, {
		reward = reward,
		remainingCount = remaining,
		blockDef = blockDef,
	}
end

-- 5. Add Lucky Block to Player Inventory
function LuckyBlockService.addLuckyBlock(player: Player, blockId: string, amount: number?)
	local resolved = LuckyBlockConfig.resolveBlockId(blockId)
	local data = DataService.get(player)
	if data then
		data.LuckyBlocks = data.LuckyBlocks or {}
		data.LootBoxes = data.LootBoxes or {}
		local count = amount or 1
		data.LuckyBlocks[resolved] = (data.LuckyBlocks[resolved] or 0) + count
		data.LootBoxes[resolved] = (data.LootBoxes[resolved] or 0) + count
		local dropEvent = Remotes.getEvent("LuckyBlockDropped")
		dropEvent:FireClient(player, resolved, count)
	end
end
LuckyBlockService.addLootBox = LuckyBlockService.addLuckyBlock

-- Initialize LuckyBlockService
function LuckyBlockService.init()
	print("❓ [LuckyBlockService] Initializing Lucky Block Subsystem...")

	quarryBlocksFolder = Instance.new("Folder")
	quarryBlocksFolder.Name = "QuarryLuckyBlocks"
	quarryBlocksFolder.Parent = Workspace

	-- Periodic quarry spawner
	task.spawn(function()
		task.wait(5.0)
		LuckyBlockService.spawnQuarryBlock()

		while true do
			task.wait(SPAWN_INTERVAL)
			LuckyBlockService.spawnQuarryBlock()
		end
	end)

	-- Remote Functions
	local openBlockFn = Remotes.getFunction("OpenLuckyBlock")
	openBlockFn.OnServerInvoke = function(player: Player, blockId: any)
		if typeof(blockId) ~= "string" then return false, "Invalid block ID" end
		return LuckyBlockService.openBlock(player, blockId)
	end

	-- Backward compatibility with legacy OpenLootBox remote
	local legacyOpenFn = Remotes.getFunction("OpenLootBox")
	legacyOpenFn.OnServerInvoke = function(player: Player, boxId: any)
		if typeof(boxId) ~= "string" then return false, "Invalid ID" end
		return LuckyBlockService.openBlock(player, boxId)
	end

	local hitQuarryFn = Remotes.getFunction("MineQuarryLuckyBlock")
	hitQuarryFn.OnServerInvoke = function(player: Player, blockModel: any)
		if not blockModel or not blockModel:IsA("Model") then return false end
		return LuckyBlockService.hitQuarryBlock(player, blockModel)
	end

	local function grantDevBlocks(player: Player): (boolean, string)
		local data = DataService.get(player)
		if data then
			data.LuckyBlocks = data.LuckyBlocks or {}
			data.LootBoxes = data.LootBoxes or {}
			for _, id in ipairs(LuckyBlockConfig.ORDERED_IDS) do
				data.LuckyBlocks[id] = (data.LuckyBlocks[id] or 0) + 5
				data.LootBoxes[id] = (data.LootBoxes[id] or 0) + 5
			end
			return true, "Added +5 of every Lucky Block!"
		end
		return false, "No data"
	end

	-- Dev Cheat: Add Lucky Blocks
	local devAddFn = Remotes.getFunction("DevAddLuckyBlocks")
	devAddFn.OnServerInvoke = function(player: Player)
		return grantDevBlocks(player)
	end

	-- Legacy dev remote
	local devLegacyFn = Remotes.getFunction("DevAddLootBoxes")
	devLegacyFn.OnServerInvoke = function(player: Player)
		return grantDevBlocks(player)
	end

	print("✅ [LuckyBlockService] Lucky Block Subsystem Online!")
end

return LuckyBlockService
