--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MeteorConfig = require(ReplicatedStorage.Shared.Config.MeteorConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local LootBoxService = require(script.Parent.LootBoxService)

local MeteorService = {}

type EventState = "IDLE" | "COUNTDOWN" | "FALLING" | "ACTIVE"

local currentState: EventState = "IDLE"
local currentLocation: MeteorConfig.CrashLocation? = nil
local currentHealth: number = 0
local maxHealth: number = 0
local contributors: { [Player]: number } = {} -- player -> damage
local eventFolder: Folder? = nil
local meteorModel: Model? = nil
local corePart: Part? = nil
local healthFillFrame: Frame? = nil
local healthLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil

local eventExpiryThread: thread? = nil
local countdownThread: thread? = nil
local autoScheduleThread: thread? = nil

-- Utility to create authentic retro stud-textured parts
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

-- Builds the massive, multifaceted Celestial Meteor Monolith in the impact crater
local function buildMeteorMonolith(location: MeteorConfig.CrashLocation): (Model, Part)
	local model = Instance.new("Model")
	model.Name = "CelestialMeteorMonolith"

	local pos = location.position
	local mCF = CFrame.new(pos)

	local obsidian = Color3.fromRGB(24, 22, 28)
	local craterStone = Color3.fromRGB(48, 42, 40)
	local moltenVein = Color3.fromRGB(255, 80, 10)
	local cosmicGold = Color3.fromRGB(255, 215, 60)
	local stellarCyan = Color3.fromRGB(0, 240, 255)

	-- 1. Outer Scorched Impact Crater Rim
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local rimDist = 18
		local rimPos = pos + Vector3.new(math.cos(angle) * rimDist, 0.6, math.sin(angle) * rimDist)
		local rimPart = createStudPart(
			model,
			"CraterRim_" .. i,
			Vector3.new(12, 1.8, 6),
			CFrame.new(rimPos, pos) * CFrame.Angles(math.rad(15), 0, 0),
			craterStone,
			Enum.Material.Slate
		)
		rimPart.CanCollide = false
	end

	-- 2. Molten Impact Core Disc
	local coreDisc = createStudPart(model, "MoltenBed", Vector3.new(28, 0.8, 28), mCF * CFrame.new(0, 0.4, 0), moltenVein, Enum.Material.Neon)
	coreDisc.CanCollide = false

	-- Smoke & Embers rising from crater bed
	local bedAttach = Instance.new("Attachment")
	bedAttach.Parent = coreDisc

	local bedSmoke = Instance.new("ParticleEmitter")
	bedSmoke.Name = "CraterSmoke"
	bedSmoke.Color = ColorSequence.new(Color3.fromRGB(60, 50, 48))
	bedSmoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 6.0),
	})
	bedSmoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	bedSmoke.Lifetime = NumberRange.new(2.0, 3.5)
	bedSmoke.Rate = 16
	bedSmoke.Speed = NumberRange.new(2, 5)
	bedSmoke.SpreadAngle = Vector2.new(20, 20)
	bedSmoke.Parent = bedAttach

	-- 3. THE CENTRAL METEOR MONOLITH CORE (Multifaceted Boulder)
	local meteorCore = Instance.new("Part")
	meteorCore.Name = "MeteorCore"
	meteorCore.Size = Vector3.new(14, 16, 14)
	meteorCore.CFrame = mCF * CFrame.new(0, 8.5, 0)
	meteorCore.Color = obsidian
	meteorCore.Material = Enum.Material.Slate
	meteorCore.TopSurface = Enum.SurfaceType.Studs
	meteorCore.BottomSurface = Enum.SurfaceType.Inlet
	meteorCore.Anchored = true
	meteorCore.CanCollide = true
	meteorCore.Parent = model
	model.PrimaryPart = meteorCore

	-- 4. Inlaid Celestial Crystals & Radiant Neon Veins
	local shardOffsets = {
		{ offset = Vector3.new(5.5, 2.5, 4.5), size = Vector3.new(4, 9, 4), angle = Vector3.new(25, 30, -15), col = cosmicGold },
		{ offset = Vector3.new(-5.5, 1.0, -4.5), size = Vector3.new(4, 10, 4), angle = Vector3.new(-25, 45, 20), col = moltenVein },
		{ offset = Vector3.new(-5.0, 3.0, 5.0), size = Vector3.new(3.5, 8, 3.5), angle = Vector3.new(20, -40, 30), col = stellarCyan },
		{ offset = Vector3.new(5.0, 0.5, -5.0), size = Vector3.new(4, 8.5, 4), angle = Vector3.new(-30, 15, -25), col = cosmicGold },
		{ offset = Vector3.new(0, 8.5, 0), size = Vector3.new(5, 7, 5), angle = Vector3.new(10, 20, 0), col = stellarCyan },
	}

	for sIdx, sInfo in ipairs(shardOffsets) do
		local shard = Instance.new("Part")
		shard.Name = "MeteorShard_" .. sIdx
		shard.Size = sInfo.size
		shard.CFrame = meteorCore.CFrame * CFrame.new(sInfo.offset) * CFrame.Angles(math.rad(sInfo.angle.X), math.rad(sInfo.angle.Y), math.rad(sInfo.angle.Z))
		shard.Color = sInfo.col
		shard.Material = Enum.Material.Neon
		shard.Anchored = true
		shard.CanCollide = false
		shard.Parent = model
	end

	-- Core Radiant PointLight
	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(255, 160, 40)
	coreLight.Brightness = 4.0
	coreLight.Range = 36
	coreLight.Shadows = true
	coreLight.Parent = meteorCore

	-- Core Sparkling Solar Flare Emitter
	local coreAttach = Instance.new("Attachment")
	coreAttach.Parent = meteorCore

	local flareEmitter = Instance.new("ParticleEmitter")
	flareEmitter.Name = "SolarFlares"
	flareEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 40, 255)),
	})
	flareEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 1.6),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	flareEmitter.Lifetime = NumberRange.new(1.0, 2.2)
	flareEmitter.Rate = 24
	flareEmitter.Speed = NumberRange.new(3, 8)
	flareEmitter.SpreadAngle = Vector2.new(45, 45)
	flareEmitter.LightEmission = 1.0
	flareEmitter.Parent = coreAttach

	-- 5. Overhead Boss-Style Holographic Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MeteorBillboard"
	billboard.Size = UDim2.new(0, 360, 0, 110)
	billboard.StudsOffset = Vector3.new(0, 14, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.30, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "☄️ CELESTIAL STARFALL METEOR ☄️"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 18
	titleLabel.TextStrokeTransparency = 0.15
	titleLabel.Parent = billboard

	-- Time Remaining Countdown Label
	local timeLbl = Instance.new("TextLabel")
	timeLbl.Name = "TimeRemaining"
	timeLbl.Size = UDim2.new(1, 0, 0.22, 0)
	timeLbl.Position = UDim2.new(0, 0, 0.30, 0)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Text = "⏳ Time Remaining: 120s"
	timeLbl.TextColor3 = Color3.fromRGB(255, 120, 60)
	timeLbl.Font = Enum.Font.GothamBold
	timeLbl.TextSize = 14
	timeLbl.TextStrokeTransparency = 0.2
	timeLbl.Parent = billboard
	timerLabel = timeLbl

	-- Health Bar Background Frame
	local barBg = Instance.new("Frame")
	barBg.Name = "HealthBarBg"
	barBg.Size = UDim2.new(0.92, 0, 0.22, 0)
	barBg.Position = UDim2.new(0.04, 0, 0.55, 0)
	barBg.BackgroundColor3 = Color3.fromRGB(24, 20, 26)
	barBg.BorderSizePixel = 0
	barBg.Parent = billboard

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBg

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(255, 180, 40)
	barStroke.Thickness = 2
	barStroke.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 80, 20)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	healthFillFrame = barFill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = barFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Text = "25,000 / 25,000 HP (100%)"
	hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpText.Font = Enum.Font.GothamBlack
	hpText.TextSize = 12
	hpText.TextStrokeTransparency = 0.2
	hpText.Parent = barBg
	healthLabel = hpText

	-- Subtitle hint
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, 0, 0.18, 0)
	hintLabel.Position = UDim2.new(0, 0, 0.82, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "⛏️ Mine with Pickaxe for Huge Rewards & Jackpot Crates!"
	hintLabel.TextColor3 = Color3.fromRGB(210, 230, 255)
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 11
	hintLabel.TextStrokeTransparency = 0.3
	hintLabel.Parent = billboard

	billboard.Parent = meteorCore

	-- 6. ClickDetector & ProximityPrompt for Interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.Parent = meteorCore

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MineMeteorPrompt"
	prompt.ActionText = "Mine Meteor"
	prompt.ObjectText = "Celestial Starfall"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 24
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = meteorCore

	clickDetector.MouseClick:Connect(function(player)
		MeteorService.hitMeteor(player)
	end)

	prompt.Triggered:Connect(function(player)
		MeteorService.hitMeteor(player)
	end)

	return model, meteorCore
end

-- =========================================================================
-- EVENT LIFECYCLE METHODS
-- =========================================================================

-- Initiates the 15-second pre-impact countdown
function MeteorService.startCountdown(forcedLocation: MeteorConfig.CrashLocation?): (boolean, string)
	if currentState ~= "IDLE" then
		return false, "Meteor event is already in progress (" .. currentState .. ")"
	end

	-- Pick random location or use forced location
	if forcedLocation then
		currentLocation = forcedLocation
	else
		local locs = MeteorConfig.CRASH_LOCATIONS
		currentLocation = locs[math.random(1, #locs)]
	end

	local loc = currentLocation :: MeteorConfig.CrashLocation
	currentState = "COUNTDOWN"
	contributors = {}

	print(string.format("☄️ [MeteorService] Celestial Meteor Strike announced at %s! Impact in %ds", loc.zoneName, MeteorConfig.COUNTDOWN_DURATION))

	-- Broadcast announcement to all players
	local announceEvent = Remotes.getEvent("MeteorEventAnnounced")
	announceEvent:FireAllClients({
		id = loc.id,
		zoneName = loc.zoneName,
		zoneIcon = loc.zoneIcon,
		position = loc.position,
		color = loc.color,
		countdown = MeteorConfig.COUNTDOWN_DURATION,
	})

	-- Schedule impact when countdown expires
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end

	countdownThread = task.spawn(function()
		task.wait(MeteorConfig.COUNTDOWN_DURATION)
		if currentState == "COUNTDOWN" then
			MeteorService.performCrash()
		end
	end)

	return true, "Meteor countdown initiated!"
end

-- Executes the falling meteor descent and spawns the Monolith in Workspace
function MeteorService.performCrash()
	if not currentLocation then return end
	currentState = "FALLING"

	local loc = currentLocation
	local targetPos = loc.position
	local skyStartPos = targetPos + Vector3.new(45, 260, 45)

	-- Calculate scaled health based on active player count
	local activePlayers = Players:GetPlayers()
	maxHealth = MeteorConfig.BASE_HEALTH + (#activePlayers * MeteorConfig.HEALTH_PER_PLAYER)
	currentHealth = maxHealth
	contributors = {}

	-- Broadcast crash descent to all clients for synchronized VFX & screen shake
	local crashEvent = Remotes.getEvent("MeteorCrashed")
	crashEvent:FireAllClients({
		position = targetPos,
		skyStartPos = skyStartPos,
		maxHealth = maxHealth,
		zoneName = loc.zoneName,
	})

	-- Descent duration matches client fireball animation (~2.0s)
	task.wait(1.8)

	-- Clean up previous meteor container
	if eventFolder then
		eventFolder:Destroy()
		eventFolder = nil
	end

	eventFolder = Instance.new("Folder")
	eventFolder.Name = "ActiveMeteorEvent"
	eventFolder.Parent = Workspace

	-- Build the physical monolith at the crash crater
	local model, core = buildMeteorMonolith(loc)
	meteorModel = model
	corePart = core
	model.Parent = eventFolder

	currentState = "ACTIVE"
	print(string.format("☄️ [MeteorService] Meteor crashed at %s! Max HP: %d", loc.zoneName, maxHealth))

	-- Start 120-second event expiration timer
	if eventExpiryThread then
		task.cancel(eventExpiryThread)
		eventExpiryThread = nil
	end

	eventExpiryThread = task.spawn(function()
		local remaining = MeteorConfig.EVENT_DURATION
		while remaining > 0 and currentState == "ACTIVE" do
			task.wait(1)
			remaining -= 1
			if timerLabel and timerLabel.Parent then
				timerLabel.Text = string.format("⏳ Time Remaining: %ds", remaining)
				if remaining <= 15 then
					timerLabel.TextColor3 = Color3.fromRGB(255, 40, 40)
				end
			end
		end

		if currentState == "ACTIVE" then
			print("☄️ [MeteorService] Meteor cooled down and dissipated (Time Expired)")
			MeteorService.endEvent(false)
		end
	end)
end

-- Processes player strikes against the Celestial Meteor
function MeteorService.hitMeteor(player: Player): (boolean, any)
	if currentState ~= "ACTIVE" or not corePart or not corePart.Parent then
		return false, "Meteor is not currently active"
	end

	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "No character"
	end

	local pRoot = char.HumanoidRootPart :: BasePart
	local dist = (pRoot.Position - corePart.Position).Magnitude
	if dist > 35 then
		return false, "Too far from meteor"
	end

	local data = DataService.get(player)
	if not data then return false, "No player data" end

	-- Calculate player strike damage based on Power, Pickaxe, Rebirths & Pets
	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local petMult = PetService.getCashMultiplier(player)
	local playerPower = data.Power or 1

	-- Find equipped pickaxe
	local pickaxePower = 1
	for itemId, _ in data.UnlockedItems do
		local itemDef = ShopConfig.ITEMS[itemId]
		if itemDef and itemDef.category == "Pickaxe" and (itemDef.power or 1) > pickaxePower then
			pickaxePower = itemDef.power or 1
		end
	end

	local baseDamage = math.max(15, math.floor(playerPower * pickaxePower * 0.15))
	local strikeDamage = math.clamp(baseDamage, 25, 2500)

	-- Apply damage to shared pool
	currentHealth = math.max(0, currentHealth - strikeDamage)
	contributors[player] = (contributors[player] or 0) + strikeDamage

	-- Update Holographic Health Bar
	local healthPct = math.clamp(currentHealth / maxHealth, 0, 1)
	if healthFillFrame and healthFillFrame.Parent then
		healthFillFrame.Size = UDim2.new(healthPct, 0, 1, 0)
	end
	if healthLabel and healthLabel.Parent then
		healthLabel.Text = string.format("%s / %s HP (%d%%)", FormatNumber.format(currentHealth), FormatNumber.format(maxHealth), math.floor(healthPct * 100))
	end

	-- Award per-hit rewards
	local perHit = MeteorConfig.REWARDS.PerHit
	local cashReward = math.floor(perHit.CashBase * rebirthMult * petMult)
	local gemsReward = perHit.GemsBase
	local powerReward = perHit.PowerBase

	DataService.addCash(player, cashReward)
	DataService.addGems(player, gemsReward)
	DataService.addPower(player, powerReward)

	-- Broadcast damage update to clients
	local damagedEvent = Remotes.getEvent("MeteorDamaged")
	damagedEvent:FireAllClients({
		damage = strikeDamage,
		currentHealth = currentHealth,
		maxHealth = maxHealth,
		hitPosition = corePart.Position + Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 6, (math.random() - 0.5) * 6),
		playerName = player.Name,
		cashEarned = cashReward,
		gemsEarned = gemsReward,
	})

	-- Check for shatter / victory
	if currentHealth <= 0 then
		MeteorService.endEvent(true)
	end

	return true, strikeDamage
end

-- Concludes the meteor event and distributes jackpot rewards
function MeteorService.endEvent(isVictory: boolean)
	if currentState ~= "ACTIVE" and currentState ~= "FALLING" then return end
	currentState = "IDLE"

	if eventExpiryThread then
		task.cancel(eventExpiryThread)
		eventExpiryThread = nil
	end

	local jackpot = MeteorConfig.REWARDS.Jackpot

	if isVictory then
		print("🎉 [MeteorService] Celestial Meteor Shattered! Distributing Jackpot Rewards...")

		-- Broadcast victory to all clients
		local destroyedEvent = Remotes.getEvent("MeteorDestroyed")
		destroyedEvent:FireAllClients({
			success = true,
			position = if corePart then corePart.Position else Vector3.zero,
			jackpotCash = jackpot.CashBase,
			jackpotGems = jackpot.GemsBase,
		})

		-- Distribute jackpot rewards to every player who contributed
		for contribPlayer, damageDealt in pairs(contributors) do
			if contribPlayer and contribPlayer.Parent then
				local pData = DataService.get(contribPlayer)
				local pRebirthMult = if pData then RebirthConfig.getMultiplier(pData.Rebirths or 0) else 1.0

				local finalCash = math.floor(jackpot.CashBase * pRebirthMult)
				local finalGems = jackpot.GemsBase
				local finalPower = jackpot.PowerBase

				DataService.addCash(contribPlayer, finalCash)
				DataService.addGems(contribPlayer, finalGems)
				DataService.addPower(contribPlayer, finalPower)

				-- Award 3 rare/exclusive loot boxes
				for _, crateType in ipairs(jackpot.CrateTypes) do
					LootBoxService.addLootBox(contribPlayer, crateType, 1)
				end

				print(string.format("  🎁 Granted Jackpot to %s (Dmg: %s): +$%s, +%s 💎, 3 Crates!", contribPlayer.Name, FormatNumber.format(damageDealt), FormatNumber.format(finalCash), FormatNumber.format(finalGems)))
			end
		end

		-- Spawn final celebratory explosion
		if corePart then
			local exp = Instance.new("Explosion")
			exp.Position = corePart.Position
			exp.BlastRadius = 0
			exp.DestroyJointRadiusPercent = 0
			exp.Parent = Workspace
		end
	else
		-- Timeout failure
		local destroyedEvent = Remotes.getEvent("MeteorDestroyed")
		destroyedEvent:FireAllClients({
			success = false,
			position = if corePart then corePart.Position else Vector3.zero,
		})
	end

	-- Clean up visual model after brief delay for particle explosion
	task.delay(2.5, function()
		if eventFolder then
			eventFolder:Destroy()
			eventFolder = nil
		end
		meteorModel = nil
		corePart = nil
		healthFillFrame = nil
		healthLabel = nil
		timerLabel = nil
	end)

	-- Schedule next automated meteor strike
	MeteorService.scheduleNextAutoEvent()
end

-- Schedules the next automatic recurring meteor event
function MeteorService.scheduleNextAutoEvent()
	if autoScheduleThread then
		task.cancel(autoScheduleThread)
		autoScheduleThread = nil
	end

	local delaySeconds = math.random(MeteorConfig.AUTO_INTERVAL_MIN, MeteorConfig.AUTO_INTERVAL_MAX)
	print(string.format("🕒 [MeteorService] Next Meteor Strike automatically scheduled in %d minutes (%ds)", math.floor(delaySeconds / 60), delaySeconds))

	autoScheduleThread = task.spawn(function()
		task.wait(delaySeconds)
		if currentState == "IDLE" then
			MeteorService.startCountdown()
		end
	end)
end

-- =========================================================================
-- INITIALIZATION & REMOTES
-- =========================================================================
function MeteorService.init()
	print("☄️ [MeteorService] Initializing Celestial Meteor World Event Service...")

	-- 1. Hook HitMeteor RemoteFunction
	local hitFn = Remotes.getFunction("HitMeteor")
	hitFn.OnServerInvoke = function(player)
		local ok, result = MeteorService.hitMeteor(player)
		return ok, result
	end

	-- 2. Hook DevTriggerMeteor RemoteFunction
	local devFn = Remotes.getFunction("DevTriggerMeteor")
	devFn.OnServerInvoke = function(player)
		print(string.format("⚡ [MeteorService] DevTriggerMeteor invoked by %s!", player.Name))
		-- If in progress, reset and launch fresh countdown
		if currentState ~= "IDLE" then
			if eventFolder then eventFolder:Destroy(); eventFolder = nil end
			currentState = "IDLE"
		end
		local ok, msg = MeteorService.startCountdown()
		return ok, msg
	end

	-- 3. Schedule first automatic meteor strike
	MeteorService.scheduleNextAutoEvent()

	print("✅ [MeteorService] Meteor World Event Service Initialized!")
end

return MeteorService
