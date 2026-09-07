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

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

export type ActiveOre = {
	id: string,
	oreType: string,
	zone: "Zone1" | "Zone2",
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

	local model = Instance.new("Model")
	model.Name = oreId

	-- Main Boulder Core (Studded Rock Base)
	local coreSize = Vector3.new(3.8, 3.2, 3.8) * scale
	local corePart = createStudPart(model, "OreCore", coreSize, CFrame.new(position + Vector3.new(0, coreSize.Y / 2, 0)), oreDef.color)
	model.PrimaryPart = corePart

	-- Protruding Angled Crystal Shards (Neon spikes)
	local shardColors = { oreDef.accentColor, oreDef.color }
	local shardOffsets = {
		{ offset = Vector3.new(0.8, 1.1, 0.7) * scale, angles = Vector3.new(25, 30, -20), size = Vector3.new(1.1, 2.2, 1.1) * scale },
		{ offset = Vector3.new(-0.9, 0.9, -0.6) * scale, angles = Vector3.new(-30, 45, 15), size = Vector3.new(1.0, 1.9, 1.0) * scale },
		{ offset = Vector3.new(0.5, 1.4, -0.8) * scale, angles = Vector3.new(15, -40, 35), size = Vector3.new(0.9, 2.4, 0.9) * scale },
		{ offset = Vector3.new(-0.6, 1.2, 0.9) * scale, angles = Vector3.new(-20, 15, -30), size = Vector3.new(1.0, 2.0, 1.0) * scale },
	}

	for sIdx, sInfo in ipairs(shardOffsets) do
		local shard = Instance.new("Part")
		shard.Name = "CrystalShard_" .. sIdx
		shard.Size = sInfo.size
		shard.CFrame = corePart.CFrame * CFrame.new(sInfo.offset) * CFrame.Angles(math.rad(sInfo.angles.X), math.rad(sInfo.angles.Y), math.rad(sInfo.angles.Z))
		shard.Color = shardColors[(sIdx % #shardColors) + 1]
		shard.Material = Enum.Material.Neon
		shard.Anchored = true
		shard.CanCollide = false
		shard.Parent = model
	end

	-- Ambient Radiant Glow Light
	local light = Instance.new("PointLight")
	light.Color = oreDef.accentColor
	light.Brightness = 1.8
	light.Range = 12 * scale
	light.Parent = corePart

	-- Sparkle Particles
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, coreSize.Y * 0.4, 0)
	attach.Parent = corePart

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "OreSparkles"
	sparkles.Color = ColorSequence.new(oreDef.accentColor)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25 * scale),
		NumberSequenceKeypoint.new(0.5, 0.45 * scale),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparkles.Lifetime = NumberRange.new(1.0, 1.8)
	sparkles.Rate = 5 * scale
	sparkles.Speed = NumberRange.new(0.8, 2.0)
	sparkles.SpreadAngle = Vector2.new(35, 35)
	sparkles.Acceleration = Vector3.new(0, 2.5, 0)
	sparkles.LightEmission = 0.9
	sparkles.Parent = attach

	-- Overhead Billboard GUI (Health Bar & Name)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OreBillboard"
	billboard.Size = UDim2.new(0, 160, 0, 50)
	billboard.StudsOffset = Vector3.new(0, (coreSize.Y * 0.6) + 2.2, 0)
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

	-- Bouncy pop-in spawn animation
	corePart.Size = Vector3.new(0.1, 0.1, 0.1)
	TweenService:Create(corePart, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = coreSize,
	}):Play()

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

	-- 1. Calculate Player Mining Power & Multipliers
	local baseDamage = 10
	if data.EquippedShovel then
		local toolDef = ShopConfig.getShovel(data.EquippedShovel)
		if toolDef and toolDef.miningPower then
			baseDamage = toolDef.miningPower
		end
	end

	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local petDamageMult = PetService.getCashMultiplier(player)
	local skillMiningMult = SkillTreeConfig.getTotalMiningPowerMult(data.UnlockedSkills)

	-- 15% Chance of Critical Strike
	local isCrit = math.random() <= 0.15
	local critBonus = if isCrit then 2.0 else 1.0

	local totalDamage = math.max(1, math.floor(baseDamage * rebirthMult * petDamageMult * skillMiningMult * critBonus))

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
		cashEarned = math.max(1, math.floor(oreDef.cashReward * bpMultiplier * trailCashMult * skillCashMult * rebirthMult * petDamageMult))
		gemsEarned = math.max(1, math.floor((oreDef.gemsReward + bpBonusGems + trailBonusGems + skillBonusGems) * petGemMult))

		-- Award to player
		DataService.addCash(player, cashEarned)
		DataService.addGems(player, gemsEarned)

		print(string.format("⛏️ [Mining] %s shattered %s! (+$%s, +%d 💎)", player.Name, oreDef.name, FormatNumber.formatCompact(cashEarned), gemsEarned))

		-- Fire destruction event
		local destroyedEvent = Remotes.getEvent("OreDestroyed")
		destroyedEvent:FireAllClients(oreId, ore.position, ore.oreType)

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
	}
end

function MiningService.init()
	-- 1. Create ActiveOres folder in Workspace
	local existing = Workspace:FindFirstChild("ActiveOres")
	if existing then existing:Destroy() end

	oresFolder = Instance.new("Folder")
	oresFolder.Name = "ActiveOres"
	oresFolder.Parent = Workspace

	-- 2. Populate Map with Initial Active Ores for Zone 1 and Zone 2
	print(string.format("⛏️ [MiningService] Spawning initial %d Zone 1 ores and %d Zone 2 ores...", OreConfig.TOTAL_ACTIVE_ORES_ZONE1, OreConfig.TOTAL_ACTIVE_ORES_ZONE2))
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

		-- Fallback free click if no ore in range
		local data = DataService.get(player)
		if not data then return 0, 0 end
		local cash = 10
		DataService.addCash(player, cash)
		return cash, 0
	end

	print("✅ [MiningService] Initialized with dynamic random respawn system active!")
end

return MiningService
