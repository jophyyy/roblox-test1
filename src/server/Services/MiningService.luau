--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local OreConfig = require(ReplicatedStorage.Shared.Config.OreConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local OreModelBuilder = require(ReplicatedStorage.Shared.Utils.OreModelBuilder)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

export type ActiveOre = {
	id: string,
	oreType: string,
	zone: "Zone1" | "Zone2" | "Zone3",
	maxHealth: number,
	health: number,
	model: Model,
	primaryPart: Part,
	position: Vector3,
	healthBarFill: Frame,
	healthText: TextLabel,
	isDestroyed: boolean,
}

local MiningService = {}
local activeOres: { [string]: ActiveOre } = {}
local oresFolder: Folder

-- Utility to create authentic retro stud parts
local function createStudPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function MiningService.spawnOre(oreDef: OreConfig.OreDef, position: Vector3): ActiveOre
	local oreId = "Ore_" .. HttpService:GenerateGUID(false):sub(1, 8)
	local scale = oreDef.scale

	-- Build Multifaceted Rugged Boulder with Multi-Sided Crystal Spire Clusters
	local oreData = OreModelBuilder.buildOreModel(oreId, oreDef.name, oreDef.color, oreDef.accentColor, scale, position, oreDef.zone)
	local model = oreData.model
	local corePart = oreData.corePart
	local sides = oreData.sides

	-- Overhead Billboard GUI (Health Bar & Name)
	local coreHeight = 3.2 * scale
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OreBillboard"
	billboard.Size = UDim2.new(0, 160, 0, 50)
	billboard.StudsOffset = Vector3.new(0, (coreHeight * 0.7) + 2.4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 55

	local title = Instance.new("TextLabel")
	title.Name = "OreTitle"
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = oreDef.icon .. " " .. oreDef.name
	title.TextColor3 = oreDef.accentColor
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 14
	title.TextStrokeTransparency = 0.25
	title.Parent = billboard

	local barBg = Instance.new("Frame")
	barBg.Name = "HealthBarBg"
	barBg.Size = UDim2.new(1, -20, 0, 12)
	barBg.Position = UDim2.new(0, 10, 0, 24)
	barBg.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	barBg.BorderSizePixel = 0
	barBg.Parent = billboard

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 6)
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(0, 230, 118)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 6)
	barFillCorner.Parent = barFill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%d / %d", oreDef.maxHealth, oreDef.maxHealth)
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.Font = Enum.Font.GothamBold
	healthText.TextSize = 10
	healthText.TextStrokeTransparency = 0.4
	healthText.Parent = barBg

	billboard.Parent = corePart

	-- ClickDetector for direct PC clicking & Mobile tapping
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = OreConfig.MAX_MINE_DISTANCE
	clickDetector.Parent = corePart

	local activeOre: ActiveOre = {
		id = oreId,
		oreType = oreDef.id,
		zone = oreDef.zone,
		maxHealth = oreDef.maxHealth,
		health = oreDef.maxHealth,
		model = model,
		primaryPart = corePart,
		position = position,
		healthBarFill = barFill,
		healthText = healthText,
		isDestroyed = false,
	}

	activeOres[oreId] = activeOre

	clickDetector.MouseClick:Connect(function(player)
		MiningService.mineOre(player, oreId)
	end)

	model.Parent = oresFolder

	-- Bouncy pop-in spawn animation:
	-- 1. Rock Boulder drops and lands with bounce
	local origCoreSize = corePart.Size
	corePart.Size = Vector3.new(0.1, 0.1, 0.1)
	local coreTween = TweenService:Create(corePart, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = origCoreSize,
	})
	coreTween:Play()

	-- 2. Staggered Sprout Animation: Crystals pop up little by little on each side!
	coreTween.Completed:Connect(function()
		OreModelBuilder.animateSprout(sides, 0.08)
	end)

	return activeOre
end

function MiningService.mineOre(player: Player, oreId: string): (boolean, any)
	local ore = activeOres[oreId]
	if not ore or ore.isDestroyed then
		return false, "Ore not found or already destroyed"
	end

	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "No character"
	end

	local rootPart = char.HumanoidRootPart :: BasePart
	local dist = (rootPart.Position - ore.position).Magnitude
	if dist > (OreConfig.MAX_MINE_DISTANCE + 6) then
		return false, "Too far away"
	end

	local data = DataService.get(player)
	if not data then return false, "No player data" end

	local oreDef = OreConfig.ORES[ore.oreType]
	if not oreDef then return false, "Invalid ore type" end

	-- 0. Award Click Power from pickaxe strike
	local powerGain, clickCash, clickGems = DataService.calculateClickPowerGain(player)
	DataService.addPower(player, powerGain)
	if clickCash > 0 then
		DataService.addCash(player, clickCash)
	end
	if clickGems > 0 then
		DataService.addGems(player, clickGems)
	end

	-- 1. Calculate Player Mining Damage based on Accumulated Power
	local playerPower = math.max(1, data.Power or 10)
	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local petDamageMult = PetService.getCashMultiplier(player)
	local skillMiningMult = SkillTreeConfig.getTotalMiningPowerMult(data.UnlockedSkills)

	local okMastery, MasteryService = pcall(function()
		return require(script.Parent.MasteryService)
	end)
	local masteryPowerMult = if okMastery and MasteryService then MasteryService.getMiningPowerMultiplier(player) else 1.0
	local masteryCashMult = if okMastery and MasteryService then MasteryService.getCashOreMultiplier(player) else 1.0
	local masteryGemMult = if okMastery and MasteryService then MasteryService.getGemOreBonusMultiplier(player) else 1.0
	local globalCashMult = if okMastery and MasteryService then MasteryService.getCashMultiplier(player) else 1.0
	local globalGemMult = if okMastery and MasteryService then MasteryService.getGemMultiplier(player) else 1.0

	-- 15% Chance of Critical Strike
	local isCrit = math.random() <= 0.15
	local critBonus = if isCrit then 2.0 else 1.0

	local totalDamage = math.max(1, math.floor(playerPower * rebirthMult * petDamageMult * skillMiningMult * masteryPowerMult * critBonus))

	-- Award Mining Hit XP
	if okMastery and MasteryService then
		MasteryService.addXP(player, "Mining", 2)
	end

	-- 2. Apply Damage
	ore.health = math.max(0, ore.health - totalDamage)
	local isBroken = (ore.health <= 0)

	-- Update Health UI on Server
	local healthRatio = math.clamp(ore.health / ore.maxHealth, 0, 1)
	ore.healthBarFill.Size = UDim2.new(healthRatio, 0, 1, 0)
	ore.healthText.Text = string.format("%d / %d", ore.health, ore.maxHealth)

	-- Color shift health bar from green to yellow to red
	if healthRatio > 0.5 then
		ore.healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 230, 118)
	elseif healthRatio > 0.25 then
		ore.healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	else
		ore.healthBarFill.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
	end

	-- Notify Clients of Hit (Plays damage popup, wobble, and impact sound)
	local damagedEvent = Remotes.getEvent("OreDamaged")
	damagedEvent:FireAllClients(oreId, totalDamage, isCrit, ore.health, ore.maxHealth, ore.position)

	local cashEarned = 0
	local gemsEarned = 0

	-- 3. Handle Ore Destruction
	if isBroken and not ore.isDestroyed then
		ore.isDestroyed = true

		-- Award Mining Ore Break XP (+15 XP)
		if okMastery and MasteryService then
			MasteryService.addXP(player, "Mining", 15)
		end

		-- Calculate Rewards
		local bpMultiplier = 1.0
		local bpBonusGems = 0
		if data.EquippedBackpack then
			local bpDef = ShopConfig.getBackpack(data.EquippedBackpack)
			if bpDef then
				bpMultiplier = bpDef.multiplier
				bpBonusGems = bpDef.bonusGems
			end
		end

		local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
		local trailCashMult = TrailConfig.getCashMultiplier(data.EquippedTrail)
		local trailBonusGems = TrailConfig.getBonusGems(data.EquippedTrail)

		local skillCashMult = SkillTreeConfig.getTotalCashMult(data.UnlockedSkills)
		local skillBonusGems = SkillTreeConfig.getTotalBonusGems(data.UnlockedSkills)

		local petGemMult = PetService.getGemMultiplier(player)
		cashEarned = math.max(1, math.floor(oreDef.cashReward * bpMultiplier * trailCashMult * skillCashMult * rebirthMult * petDamageMult * masteryCashMult * globalCashMult))
		gemsEarned = math.max(1, math.floor((oreDef.gemsReward + bpBonusGems + trailBonusGems + skillBonusGems) * petGemMult * masteryGemMult * globalGemMult))

		-- Award to player
		DataService.addCash(player, cashEarned)
		DataService.addGems(player, gemsEarned)

		-- Roll for mystery loot box drops based on ore tier / zone
		local oreZone = ore.zone or oreDef.zone or "Zone1"
		local droppedBoxId: string? = nil
		local dropRoll = math.random()

		if oreZone == "Zone3" or oreDef.zone == "Zone3" then
			if dropRoll < 0.05 then
				droppedBoxId = "cyber_chest"
			elseif dropRoll < 0.22 then
				droppedBoxId = "void_chest"
			end
		elseif oreZone == "Zone2" or oreDef.zone == "Zone2" then
			if dropRoll < 0.04 then
				droppedBoxId = "cyber_chest"
			elseif dropRoll < 0.20 then
				droppedBoxId = "magma_chest"
			end
		else
			-- Zone 1
			if oreDef.id == "Diamond" or oreDef.id == "CosmicVoid" or oreDef.id == "Gold" then
				if dropRoll < 0.03 then
					droppedBoxId = "cyber_chest"
				elseif dropRoll < 0.22 then
					droppedBoxId = "gold_chest"
				end
			else
				-- Common Zone 1 ores (Stone, Copper, Iron)
				if dropRoll < 0.12 then
					droppedBoxId = "wooden_chest"
				end
			end
		end

		if droppedBoxId then
			DataService.addLootBox(player, droppedBoxId, 1)
			local boxDropEvent = Remotes.getEvent("LootBoxDropped")
			boxDropEvent:FireClient(player, droppedBoxId, oreDef.name)
		end

		print(string.format("⛏️ [Mining] %s shattered %s! (+$%s, +%d 💎%s)", player.Name, oreDef.name, FormatNumber.formatCompact(cashEarned), gemsEarned, if droppedBoxId then ", +📦 " .. droppedBoxId else ""))

		-- Fire destruction event
		local destroyedEvent = Remotes.getEvent("OreDestroyed")
		destroyedEvent:FireAllClients(oreId, ore.position, ore.oreType)

		-- Tutorial progress hook
		task.spawn(function()
			local okTut, TutorialService = pcall(function()
				return require(script.Parent.TutorialService)
			end)
			if okTut and TutorialService then
				TutorialService.onOreMined(player)
			end
		end)

		-- Remove model
		activeOres[oreId] = nil
		ore.model:Destroy()

		-- Schedule random respawn within the corresponding zone
		local oreZone = ore.zone or oreDef.zone or "Zone1"
		task.delay(OreConfig.RESPAWN_DELAY, function()
			local newOreDef = OreConfig.getRandomOreTypeForZone(oreZone)
			local newPos = OreConfig.getRandomPositionForZone(oreZone)
			MiningService.spawnOre(newOreDef, newPos)
		end)
	end

	return true, {
		damage = totalDamage,
		isCrit = isCrit,
		remainingHealth = ore.health,
		isBroken = isBroken,
		cashEarned = cashEarned,
		gemsEarned = gemsEarned,
		powerGained = powerGain,
	}
end

function MiningService.init()
	-- 1. Create ActiveOres folder in Workspace
	local existing = Workspace:FindFirstChild("ActiveOres")
	if existing then existing:Destroy() end

	oresFolder = Instance.new("Folder")
	oresFolder.Name = "ActiveOres"
	oresFolder.Parent = Workspace

	-- 2. Populate Map with Initial Active Ores for Zone 1, Zone 2, and Zone 3
	print(string.format("⛏️ [MiningService] Spawning initial %d Zone 1, %d Zone 2, and %d Zone 3 ores...", OreConfig.TOTAL_ACTIVE_ORES_ZONE1, OreConfig.TOTAL_ACTIVE_ORES_ZONE2, OreConfig.TOTAL_ACTIVE_ORES_ZONE3))
	for _ = 1, OreConfig.TOTAL_ACTIVE_ORES_ZONE1 do
		local oreDef = OreConfig.getRandomOreTypeForZone("Zone1")
		local pos = OreConfig.getRandomPositionForZone("Zone1")
		MiningService.spawnOre(oreDef, pos)
	end
	for _ = 1, OreConfig.TOTAL_ACTIVE_ORES_ZONE2 do
		local oreDef = OreConfig.getRandomOreTypeForZone("Zone2")
		local pos = OreConfig.getRandomPositionForZone("Zone2")
		MiningService.spawnOre(oreDef, pos)
	end
	for _ = 1, OreConfig.TOTAL_ACTIVE_ORES_ZONE3 do
		local oreDef = OreConfig.getRandomOreTypeForZone("Zone3")
		local pos = OreConfig.getRandomPositionForZone("Zone3")
		MiningService.spawnOre(oreDef, pos)
	end

	-- 3. Register MineOre Remote Function
	local mineRemote = Remotes.getFunction("MineOre")
	mineRemote.OnServerInvoke = function(player: Player, oreId: string)
		return MiningService.mineOre(player, oreId)
	end

	-- Also update ManualHarvest to mine the closest ore if available!
	local harvestRemote = Remotes.getFunction("ManualHarvest")
	harvestRemote.OnServerInvoke = function(player: Player)
		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then
			return 0, 0
		end

		local rootPos = char.HumanoidRootPart.Position
		local closestOre: ActiveOre? = nil
		local closestDist = OreConfig.MAX_MINE_DISTANCE

		for _, ore in activeOres do
			if not ore.isDestroyed then
				local dist = (ore.position - rootPos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestOre = ore
				end
			end
		end

		if closestOre then
			local ok, res = MiningService.mineOre(player, closestOre.id)
			if ok and res and res.isBroken then
				return res.cashEarned, res.gemsEarned
			elseif ok and res then
				return res.damage, 0
			end
		end

		-- Fallback free click if no ore in range: trains power and earns cash
		local data = DataService.get(player)
		if not data then return 0, 0 end
		local pGain, cEarned, gEarned = DataService.calculateClickPowerGain(player)
		DataService.addPower(player, pGain)
		if cEarned > 0 then
			DataService.addCash(player, cEarned)
		end
		if gEarned > 0 then
			DataService.addGems(player, gEarned)
		end
		return cEarned, gEarned
	end

	print("✅ [MiningService] Initialized with dynamic random respawn system active!")
end

return MiningService
