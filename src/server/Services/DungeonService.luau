--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local DungeonConfig = require(ReplicatedStorage.Shared.Config.DungeonConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

export type ActiveMob = {
	id: string,
	model: Model,
	humanoid: Humanoid,
	rootPart: Part,
	healthFill: Frame?,
	healthLabel: TextLabel?,
	maxHealth: number,
	currentHealth: number,
	attackDamage: number,
	lastAttackTime: number,
	isBoss: boolean,
}

local DungeonService = {}

-- State
local arenaFolder: Folder
local mobsFolder: Folder
local currentStage = 0
local dungeonState: "Idle" | "Countdown" | "Active" | "StageCleared" | "Victory" = "Idle"
local activePlayers: { [Player]: boolean } = {}
local activeMobs: { [string]: ActiveMob } = {}
local mobsRemaining = 0
local stageLoopThread: thread? = nil
local aggroConnection: RBXScriptConnection? = nil

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

-- 1. Build the Dungeon Tower Arena Chamber
function DungeonService.buildArena()
	arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "DungeonTowerArena"
	arenaFolder.Parent = Workspace

	mobsFolder = Instance.new("Folder")
	mobsFolder.Name = "ActiveDungeonMobs"
	mobsFolder.Parent = arenaFolder

	local c = DungeonConfig.ARENA_CENTER
	local floorY = c.Y
	local stoneDark = Color3.fromRGB(45, 48, 55)
	local stoneLight = Color3.fromRGB(75, 80, 92)
	local runePurple = Color3.fromRGB(180, 50, 240)
	local goldTrim = Color3.fromRGB(255, 215, 60)

	-- Circular Ashlar Stone Plinth (80x80 studs)
	local baseDeck = createStudPart(arenaFolder, "ArenaDeck", Vector3.new(78, 2.5, 78), CFrame.new(c.X, floorY, c.Z), stoneDark, Enum.Material.Cobblestone)
	local innerFloor = createStudPart(arenaFolder, "InnerFloor", Vector3.new(72, 0.4, 72), CFrame.new(c.X, floorY + 1.35, c.Z), stoneLight, Enum.Material.Cobblestone)

	-- Ancient Runic Center Ring
	local centerDisc = createStudPart(arenaFolder, "CenterRunicDisc", Vector3.new(24, 0.2, 24), CFrame.new(c.X, floorY + 1.5, c.Z), runePurple, Enum.Material.Neon)
	centerDisc.Shape = Enum.PartType.Cylinder
	centerDisc.CFrame = CFrame.new(c.X, floorY + 1.5, c.Z) * CFrame.Angles(0, 0, math.rad(90))

	-- 8 Perimeter Pillars with Iron Braziers
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local dist = 36
		local px = c.X + math.cos(angle) * dist
		local pz = c.Z + math.sin(angle) * dist

		local pillar = createStudPart(arenaFolder, "ArenaPillar_" .. i, Vector3.new(4, 16, 4), CFrame.new(px, floorY + 8, pz), stoneDark, Enum.Material.Cobblestone)
		
		-- Brazier Bowl
		local bowl = createStudPart(arenaFolder, "BrazierBowl_" .. i, Vector3.new(5, 1.5, 5), CFrame.new(px, floorY + 16.5, pz), Color3.fromRGB(30, 30, 35), Enum.Material.Metal)
		
		-- Fire Core
		local firePart = Instance.new("Part")
		firePart.Name = "BrazierFlame"
		firePart.Size = Vector3.new(2, 2, 2)
		firePart.CFrame = CFrame.new(px, floorY + 17.5, pz)
		firePart.Transparency = 1
		firePart.CanCollide = false
		firePart.Anchored = true
		firePart.Parent = arenaFolder

		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 10
		fire.Color = Color3.fromRGB(255, 140, 20)
		fire.SecondaryColor = Color3.fromRGB(255, 50, 0)
		fire.Parent = firePart

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 60)
		light.Range = 32
		light.Brightness = 2.2
		light.Parent = firePart
	end

	-- Perimeter Parapet Walls (Keep players inside combat zone)
	for i = 1, 16 do
		local angle = math.rad((i - 1) * 22.5)
		local dist = 38.5
		local wx = c.X + math.cos(angle) * dist
		local wz = c.Z + math.sin(angle) * dist
		local rotY = -angle + math.rad(90)
		local wall = createStudPart(arenaFolder, "ParapetWall_" .. i, Vector3.new(15.5, 5, 2.5), CFrame.new(wx, floorY + 3.8, wz) * CFrame.Angles(0, rotY, 0), stoneDark, Enum.Material.Cobblestone)
	end

	-- Return / Exit Portal at South Perimeter
	local exitPos = DungeonConfig.EXIT_PORTAL
	local exitArch = createStudPart(arenaFolder, "ExitPortalArch", Vector3.new(10, 12, 2), CFrame.new(exitPos.X, floorY + 7, exitPos.Z), stoneDark, Enum.Material.Cobblestone)
	
	local exitVortex = Instance.new("Part")
	exitVortex.Name = "ExitVortex"
	exitVortex.Size = Vector3.new(6, 9, 0.4)
	exitVortex.CFrame = CFrame.new(exitPos.X, floorY + 6.5, exitPos.Z)
	exitVortex.Color = Color3.fromRGB(0, 220, 255)
	exitVortex.Material = Enum.Material.Neon
	exitVortex.Transparency = 0.3
	exitVortex.Anchored = true
	exitVortex.CanCollide = false
	exitVortex.Parent = arenaFolder

	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.Name = "ExitPrompt"
	exitPrompt.ActionText = "Return to Town"
	exitPrompt.ObjectText = "Dungeon Exit Portal"
	exitPrompt.KeyboardKeyCode = Enum.KeyCode.E
	exitPrompt.HoldDuration = 0
	exitPrompt.MaxActivationDistance = 14
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = exitVortex

	exitPrompt.Triggered:Connect(function(player)
		DungeonService.leaveDungeon(player)
	end)
end

-- 2. Build Town Ruins Entrance Portal
function DungeonService.buildTownPortal()
	local portalPos = DungeonConfig.TOWN_PORTAL_POS
	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "DungeonEntrancePortal"
	portalFolder.Parent = Workspace

	local stoneDark = Color3.fromRGB(48, 52, 60)
	local runePurple = Color3.fromRGB(200, 60, 255)
	local runeCyan = Color3.fromRGB(0, 230, 255)

	-- Base Dais
	createStudPart(portalFolder, "PortalDais", Vector3.new(16, 1.2, 16), CFrame.new(portalPos.X, portalPos.Y + 0.6, portalPos.Z), stoneDark, Enum.Material.Cobblestone)

	-- Gateway Frame
	createStudPart(portalFolder, "PillarL", Vector3.new(2.8, 14, 2.8), CFrame.new(portalPos.X - 5.5, portalPos.Y + 8, portalPos.Z), stoneDark, Enum.Material.Cobblestone)
	createStudPart(portalFolder, "PillarR", Vector3.new(2.8, 14, 2.8), CFrame.new(portalPos.X + 5.5, portalPos.Y + 8, portalPos.Z), stoneDark, Enum.Material.Cobblestone)
	createStudPart(portalFolder, "Header", Vector3.new(14.5, 2.6, 3.2), CFrame.new(portalPos.X, portalPos.Y + 15, portalPos.Z), stoneDark, Enum.Material.Cobblestone)

	-- Glowing Portal Vortex
	local vortex = Instance.new("Part")
	vortex.Name = "PortalVortex"
	vortex.Size = Vector3.new(8.2, 12, 0.4)
	vortex.CFrame = CFrame.new(portalPos.X, portalPos.Y + 7.5, portalPos.Z)
	vortex.Color = runePurple
	vortex.Material = Enum.Material.Neon
	vortex.Transparency = 0.25
	vortex.Anchored = true
	vortex.CanCollide = false
	vortex.Parent = portalFolder

	-- Particle Emitters
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, runePurple),
		ColorSequenceKeypoint.new(0.5, runeCyan),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	particles.Rate = 22
	particles.Speed = NumberRange.new(2, 5)
	particles.Lifetime = NumberRange.new(1.2, 2.0)
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Parent = vortex

	local light = Instance.new("PointLight")
	light.Color = runePurple
	light.Range = 18
	light.Brightness = 2.5
	light.Parent = vortex

	-- Proximity Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterDungeonPrompt"
	prompt.ActionText = "Enter Dungeon Tower"
	prompt.ObjectText = "Ancient Trial Spire (Stages 1-5)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = vortex

	prompt.Triggered:Connect(function(player)
		DungeonService.startDungeonRun(player)
	end)
end

-- Helper: Broadcast state to participants
local function broadcastDungeonState(data: any)
	local event = Remotes.getEvent("DungeonStateUpdated")
	for p in pairs(activePlayers) do
		if p and p.Parent then
			event:FireClient(p, data)
		end
	end
end

-- Helper: Clean up active mobs
local function clearActiveMobs()
	for id, mob in pairs(activeMobs) do
		if mob.model and mob.model.Parent then
			mob.model:Destroy()
		end
	end
	activeMobs = {}
	mobsRemaining = 0
end

-- 3. Procedural Mob Construction (Stages 1–4)
local function buildMobModel(mobDef: DungeonConfig.MobDef, spawnCF: CFrame, mobIndex: number): (Model, ActiveMob)
	local mobModel = Instance.new("Model")
	mobModel.Name = string.format("%s_%d", mobDef.name:gsub("%s+", ""), mobIndex)

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 2)
	rootPart.CFrame = spawnCF
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Anchored = false
	rootPart.Parent = mobModel
	mobModel.PrimaryPart = rootPart

	-- Main Torso Body
	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = mobDef.size
	body.CFrame = spawnCF
	body.Color = mobDef.color
	body.Material = mobDef.material
	body.TopSurface = Enum.SurfaceType.Studs
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CanCollide = true
	body.Anchored = false
	body.Parent = mobModel

	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = rootPart
	w1.Part1 = body
	w1.Parent = rootPart

	-- Glowing Stud Eyes
	for _, eyeX in ipairs({ -0.3, 0.3 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(mobDef.size.X * 0.22, mobDef.size.Y * 0.22, 0.4)
		eye.CFrame = spawnCF * CFrame.new(eyeX * mobDef.size.X, mobDef.size.Y * 0.25, -mobDef.size.Z * 0.52)
		eye.Color = mobDef.eyeColor
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.Anchored = false
		eye.Parent = mobModel

		local ew = Instance.new("WeldConstraint")
		ew.Part0 = body
		ew.Part1 = eye
		ew.Parent = body
	end

	-- Core Sparkle / Glow
	local coreLight = Instance.new("PointLight")
	coreLight.Color = mobDef.eyeColor
	coreLight.Range = 10
	coreLight.Brightness = 1.6
	coreLight.Parent = body

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = mobDef.maxHealth
	humanoid.Health = mobDef.maxHealth
	humanoid.WalkSpeed = mobDef.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = mobModel

	-- Overhead Health BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "MobHealthGui"
	bb.Size = UDim2.new(0, 130, 0, 36)
	bb.StudsOffset = Vector3.new(0, mobDef.size.Y + 2.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.Parent = body

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0, 16)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = string.format("💀 %s", mobDef.name)
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextSize = 13
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.Parent = bb

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, 0, 0, 10)
	barBg.Position = UDim2.new(0, 0, 0, 18)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = barFill

	local hpLbl = Instance.new("TextLabel")
	hpLbl.Size = UDim2.new(1, 0, 1, 0)
	hpLbl.BackgroundTransparency = 1
	hpLbl.Text = string.format("%s / %s", FormatNumber.format(mobDef.maxHealth), FormatNumber.format(mobDef.maxHealth))
	hpLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpLbl.Font = Enum.Font.FredokaOne
	hpLbl.TextSize = 9
	hpLbl.Parent = barBg

	mobModel:SetAttribute("IsDungeonMob", true)
	mobModel:SetAttribute("MobId", mobModel.Name)

	local activeMob: ActiveMob = {
		id = mobModel.Name,
		model = mobModel,
		humanoid = humanoid,
		rootPart = rootPart,
		healthFill = barFill,
		healthLabel = hpLbl,
		maxHealth = mobDef.maxHealth,
		currentHealth = mobDef.maxHealth,
		attackDamage = mobDef.attackDamage,
		lastAttackTime = 0,
		isBoss = false,
	}

	return mobModel, activeMob
end

-- 4. Spawn Stage 5 Climax Boss (Infernal Magma Golem)
local function spawnStage5Boss(): ActiveMob
	local bossDef = BossConfig.BOSSES.InfernalMagmaGolem
	local c = DungeonConfig.ARENA_CENTER
	local spawnCF = CFrame.new(c.X, c.Y + 4, c.Z)

	-- Construct Tower Edition Magma Golem
	local bossModel = Instance.new("Model")
	bossModel.Name = "TowerInfernalMagmaGolem"

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(4, 4, 4)
	rootPart.CFrame = spawnCF
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Anchored = false
	rootPart.Parent = bossModel
	bossModel.PrimaryPart = rootPart

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(9, 10, 6)
	torso.CFrame = spawnCF
	torso.Color = Color3.fromRGB(45, 20, 22)
	torso.Material = Enum.Material.Basalt
	torso.TopSurface = Enum.SurfaceType.Studs
	torso.BottomSurface = Enum.SurfaceType.Smooth
	torso.CanCollide = true
	torso.Anchored = false
	torso.Parent = bossModel

	local tw = Instance.new("WeldConstraint")
	tw.Part0 = rootPart
	tw.Part1 = torso
	tw.Parent = rootPart

	-- Molten Fire Chest Core
	local core = Instance.new("Part")
	core.Name = "MagmaCore"
	core.Size = Vector3.new(4.5, 4.5, 2)
	core.CFrame = spawnCF * CFrame.new(0, 0.5, -2.6)
	core.Color = Color3.fromRGB(255, 75, 10)
	core.Material = Enum.Material.Neon
	core.CanCollide = false
	core.Anchored = false
	core.Parent = bossModel

	local cw = Instance.new("WeldConstraint")
	cw.Part0 = torso
	cw.Part1 = core
	cw.Parent = torso

	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 14
	fire.Color = Color3.fromRGB(255, 160, 20)
	fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
	fire.Parent = core

	-- Fists
	for _, side in ipairs({ -1, 1 }) do
		local arm = Instance.new("Part")
		arm.Name = "Arm_" .. side
		arm.Size = Vector3.new(3.6, 9, 3.6)
		arm.CFrame = spawnCF * CFrame.new(side * 6.5, -0.5, 0)
		arm.Color = Color3.fromRGB(38, 16, 18)
		arm.Material = Enum.Material.Basalt
		arm.TopSurface = Enum.SurfaceType.Studs
		arm.CanCollide = false
		arm.Anchored = false
		arm.Parent = bossModel

		local aw = Instance.new("WeldConstraint")
		aw.Part0 = torso
		aw.Part1 = arm
		aw.Parent = torso

		-- Glowing Magma Fist Knuckles
		local fist = Instance.new("Part")
		fist.Name = "Fist_" .. side
		fist.Size = Vector3.new(4.4, 4.4, 4.4)
		fist.CFrame = spawnCF * CFrame.new(side * 6.5, -5.2, 0)
		fist.Color = Color3.fromRGB(255, 60, 10)
		fist.Material = Enum.Material.CrackedLava
		fist.CanCollide = false
		fist.Anchored = false
		fist.Parent = bossModel

		local fw = Instance.new("WeldConstraint")
		fw.Part0 = arm
		fw.Part1 = fist
		fw.Parent = arm
	end

	-- Humanoid
	local maxHP = 35000
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = maxHP
	humanoid.Health = maxHP
	humanoid.WalkSpeed = 10
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = bossModel

	bossModel:SetAttribute("IsDungeonMob", true)
	bossModel:SetAttribute("MobId", bossModel.Name)
	bossModel:SetAttribute("IsBoss", true)
	bossModel.Parent = mobsFolder

	local bossState: ActiveMob = {
		id = bossModel.Name,
		model = bossModel,
		humanoid = humanoid,
		rootPart = rootPart,
		healthFill = nil,
		healthLabel = nil,
		maxHealth = maxHP,
		currentHealth = maxHP,
		attackDamage = 35,
		lastAttackTime = 0,
		isBoss = true,
	}

	-- Broadcast Boss HUD to clients
	local bossEvt = Remotes.getEvent("DungeonBossUpdated")
	for p in pairs(activePlayers) do
		bossEvt:FireClient(p, {
			name = "Infernal Magma Golem",
			title = "Tower Climax Boss • Stage 5/5",
			currentHealth = maxHP,
			maxHealth = maxHP,
			isAlive = true,
		})
	end

	return bossState
end

-- 5. Start a Dungeon Stage Wave
function DungeonService.runStage(stageNum: number)
	currentStage = stageNum
	local stageDef = DungeonConfig.getStage(stageNum)
	if not stageDef then return end

	dungeonState = "Countdown"
	clearActiveMobs()

	broadcastDungeonState({
		state = "Countdown",
		stage = stageNum,
		stageTitle = stageDef.title,
		totalStages = 5,
		countdownSeconds = 3,
	})

	task.wait(3.0)

	-- Check if player is still in arena
	local hasPlayers = false
	for p in pairs(activePlayers) do
		if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			hasPlayers = true
			break
		end
	end
	if not hasPlayers then
		DungeonService.resetDungeon()
		return
	end

	dungeonState = "Active"

	if stageDef.isBoss then
		-- Spawn Stage 5 Boss
		mobsRemaining = 1
		local bState = spawnStage5Boss()
		activeMobs[bState.id] = bState
	else
		-- Spawn Stage 1-4 Mobs
		local mobDef = stageDef.mobs
		if mobDef then
			mobsRemaining = mobDef.count
			local c = DungeonConfig.ARENA_CENTER
			for i = 1, mobDef.count do
				local spreadAngle = math.rad(-60 + ((i - 1) * (120 / math.max(1, mobDef.count - 1))))
				local spawnDist = 24
				local sx = c.X + (math.sin(spreadAngle) * spawnDist)
				local sz = c.Z - (math.cos(spreadAngle) * spawnDist)
				local spawnCF = CFrame.new(sx, c.Y + (mobDef.size.Y * 0.5) + 1.5, sz)

				local model, activeMob = buildMobModel(mobDef, spawnCF, i)
				model.Parent = mobsFolder
				activeMobs[activeMob.id] = activeMob
			end
		end
	end

	broadcastDungeonState({
		state = "Active",
		stage = stageNum,
		stageTitle = stageDef.title,
		totalStages = 5,
		mobsRemaining = mobsRemaining,
	})
end

-- 6. Mob Aggro & Pursuit Loop
local function startAggroLoop()
	if aggroConnection then aggroConnection:Disconnect() end

	local timer = 0
	aggroConnection = RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.25 then return end
		timer = 0

		if dungeonState ~= "Active" then return end

		-- Find closest player
		local closestChar: Model? = nil
		local closestDist = 9999
		local c = DungeonConfig.ARENA_CENTER

		for p in pairs(activePlayers) do
			local char = p.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local distFromCenter = (hrp.Position - c).Magnitude
					if distFromCenter <= DungeonConfig.ARENA_RADIUS + 10 then
						local dist = (hrp.Position - c).Magnitude
						if dist < closestDist then
							closestDist = dist
							closestChar = char
						end
					end
				end
			end
		end

		if not closestChar then return end
		local targetHrp = closestChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetHum = closestChar:FindFirstChildOfClass("Humanoid")
		if not targetHrp or not targetHum then return end

		local now = os.clock()

		for _, mob in pairs(activeMobs) do
			if mob.humanoid and mob.humanoid.Health > 0 and mob.rootPart then
				local distToPlayer = (mob.rootPart.Position - targetHrp.Position).Magnitude
				
				-- Pursue player
				mob.humanoid:MoveTo(targetHrp.Position)

				-- Contact Attack
				local attackRange = if mob.isBoss then 16 else 7
				local attackCooldown = if mob.isBoss then 2.2 else 1.4

				if distToPlayer <= attackRange and (now - mob.lastAttackTime) >= attackCooldown then
					mob.lastAttackTime = now
					targetHum:TakeDamage(mob.attackDamage)

					-- Audio / hit feedback
					local hitSound = Instance.new("Sound")
					hitSound.SoundId = "rbxassetid://566593606"
					hitSound.Volume = 0.6
					hitSound.Parent = mob.rootPart
					hitSound:Play()
					Debris:AddItem(hitSound, 1)

					-- If boss, visual shockwave stomp
					if mob.isBoss then
						local shock = Instance.new("Part")
						shock.Name = "LavaShockwave"
						shock.Size = Vector3.new(2, 0.4, 2)
						shock.CFrame = mob.rootPart.CFrame * CFrame.new(0, -3.5, 0)
						shock.Color = Color3.fromRGB(255, 80, 10)
						shock.Material = Enum.Material.Neon
						shock.Anchored = true
						shock.CanCollide = false
						shock.Parent = arenaFolder

						TweenService:Create(shock, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(34, 0.4, 34),
							Transparency = 1,
						}):Play()
						Debris:AddItem(shock, 0.7)
					end
				end
			end
		end
	end)
end

-- 7. Damage Mob (Called when player attacks with pickaxe)
function DungeonService.damageMob(player: Player, mobId: string, damageOverride: number?): (boolean, number)
	if dungeonState ~= "Active" then return false, 0 end
	local mob = activeMobs[mobId]
	if not mob or not mob.humanoid or mob.humanoid.Health <= 0 then return false, 0 end

	-- Calculate Player Damage via equipped shovel & pets
	local data = DataService.get(player)
	local shovelId = if data and data.EquippedShovel then data.EquippedShovel else "shovel_rusty"
	local shovelDef = ShopConfig.getShovel(shovelId)
	local baseDamage = if shovelDef then shovelDef.damage else 10

	local petMult = PetService.getTotalMultiplier(player)
	local bossMult = 1.0

	-- Check pickaxe traits
	local trait = BossConfig.PICKAXE_TRAITS[shovelId]
	local isCrit = false
	if trait then
		bossMult = trait.bossDamageMultiplier or 1.0
		if math.random() < trait.critChance then
			isCrit = true
			bossMult *= trait.critMultiplier
		end
		if trait.specialEffect == "GoldRush" and data then
			data.Cash = (data.Cash or 0) + 150
		end
	end

	local totalDamage = damageOverride or math.floor(baseDamage * petMult * bossMult)
	totalDamage = math.max(1, totalDamage)

	mob.currentHealth = math.max(0, mob.currentHealth - totalDamage)
	mob.humanoid.Health = mob.currentHealth

	-- Update Health Bar
	if mob.healthFill and mob.healthLabel then
		local pct = math.clamp(mob.currentHealth / math.max(1, mob.maxHealth), 0, 1)
		mob.healthFill.Size = UDim2.new(pct, 0, 1, 0)
		mob.healthLabel.Text = string.format("%s / %s", FormatNumber.format(mob.currentHealth), FormatNumber.format(mob.maxHealth))
	end

	-- If boss, broadcast Boss Health Bar
	if mob.isBoss then
		local bossEvt = Remotes.getEvent("DungeonBossUpdated")
		for p in pairs(activePlayers) do
			bossEvt:FireClient(p, {
				name = "Infernal Magma Golem",
				title = "Tower Climax Boss • Stage 5/5",
				currentHealth = mob.currentHealth,
				maxHealth = mob.maxHealth,
				isAlive = mob.currentHealth > 0,
			})
		end
	end

	-- Notify QuestService of boss damage if stage 5
	if mob.isBoss then
		local okQ, QuestService = pcall(function() return require(script.Parent.QuestService) end)
		if okQ and QuestService then
			QuestService.onBossDamaged(player, totalDamage)
		end
	end

	-- Floating Damage Floater Indicator to Client
	local dmgEvt = Remotes.getEvent("DungeonMobDamaged")
	dmgEvt:FireClient(player, {
		mobId = mob.id,
		position = mob.rootPart.Position + Vector3.new(0, 3, 0),
		damage = totalDamage,
		isCrit = isCrit,
	})

	-- Mob Death Check
	if mob.currentHealth <= 0 then
		mobsRemaining = math.max(0, mobsRemaining - 1)

		-- Shatter particle effect
		local deathPart = Instance.new("Part")
		deathPart.Size = Vector3.new(1, 1, 1)
		deathPart.CFrame = mob.rootPart.CFrame
		deathPart.Transparency = 1
		deathPart.Anchored = true
		deathPart.CanCollide = false
		deathPart.Parent = arenaFolder

		local sparks = Instance.new("Sparkles")
		sparks.SparkleColor = if mob.isBoss then Color3.fromRGB(255, 100, 20) else Color3.fromRGB(255, 215, 60)
		sparks.Parent = deathPart
		Debris:AddItem(deathPart, 1.2)

		mob.model:Destroy()
		activeMobs[mobId] = nil

		broadcastDungeonState({
			state = "Active",
			stage = currentStage,
			totalStages = 5,
			mobsRemaining = mobsRemaining,
		})

		-- Wave Cleared Check
		if mobsRemaining <= 0 then
			DungeonService.onStageCompleted()
		end
	end

	return true, totalDamage
end

-- 8. Stage Completed & Rewards Handling
function DungeonService.onStageCompleted()
	local stageDef = DungeonConfig.getStage(currentStage)
	if not stageDef then return end

	-- Award Rewards to Active Players
	for p in pairs(activePlayers) do
		local data = DataService.get(p)
		if data then
			if stageDef.reward.cash > 0 then
				data.Cash = (data.Cash or 0) + stageDef.reward.cash
			end
			if stageDef.reward.gems > 0 then
				data.Gems = (data.Gems or 0) + stageDef.reward.gems
			end
			if stageDef.reward.crateId then
				data.LootBoxes = data.LootBoxes or {}
				data.LootBoxes[stageDef.reward.crateId] = (data.LootBoxes[stageDef.reward.crateId] or 0) + 1
			end
			if stageDef.reward.masteryXP then
				local okM, MasteryService = pcall(function() return require(script.Parent.MasteryService) end)
				if okM and MasteryService then
					MasteryService.addXP(p, stageDef.reward.masteryXP.track, stageDef.reward.masteryXP.amount)
				end
			end
		end
	end

	if currentStage >= 5 then
		-- VICTORY!
		dungeonState = "Victory"
		broadcastDungeonState({
			state = "Victory",
			stage = 5,
			totalStages = 5,
			reward = stageDef.reward,
		})

		-- Confetti / Celebration at Arena Center
		local c = DungeonConfig.ARENA_CENTER
		for i = 1, 12 do
			task.spawn(function()
				local firework = Instance.new("Part")
				firework.Size = Vector3.new(1, 1, 1)
				firework.CFrame = CFrame.new(c.X + math.random(-20, 20), c.Y + 12 + math.random(0, 10), c.Z + math.random(-20, 20))
				firework.Transparency = 1
				firework.Anchored = true
				firework.CanCollide = false
				firework.Parent = arenaFolder

				local spk = Instance.new("Sparkles")
				spk.SparkleColor = Color3.fromRGB(math.random(100, 255), math.random(100, 255), math.random(100, 255))
				spk.Parent = firework
				Debris:AddItem(firework, 2)
			end)
		end

		task.delay(10.0, function()
			if dungeonState == "Victory" then
				for p in pairs(activePlayers) do
					DungeonService.leaveDungeon(p)
				end
				DungeonService.resetDungeon()
			end
		end)
	else
		-- STAGE CLEARED: 4s Intermission then Advance
		dungeonState = "StageCleared"
		broadcastDungeonState({
			state = "StageCleared",
			stage = currentStage,
			totalStages = 5,
			reward = stageDef.reward,
			nextStageInSeconds = 4,
		})

		task.delay(4.0, function()
			if dungeonState == "StageCleared" then
				DungeonService.runStage(currentStage + 1)
			end
		end)
	end
end

-- 9. Start Dungeon Run for Player
function DungeonService.startDungeonRun(player: Player): (boolean, string)
	if not player or not player.Character then return false, "No character found" end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "No HumanoidRootPart found" end

	activePlayers[player] = true

	-- Teleport player to Arena Waiting Dais
	hrp.CFrame = CFrame.new(DungeonConfig.PLAYER_SPAWN)

	-- If arena was idle, initiate Stage 1
	if dungeonState == "Idle" then
		task.spawn(function()
			DungeonService.runStage(1)
		end)
	else
		-- Join ongoing run
		broadcastDungeonState({
			state = dungeonState,
			stage = currentStage,
			totalStages = 5,
			mobsRemaining = mobsRemaining,
		})
	end

	-- Listen for player death / character reset
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			DungeonService.leaveDungeon(player)
		end)
	end

	return true, "Entered Dungeon Tower"
end

-- 10. Leave Dungeon
function DungeonService.leaveDungeon(player: Player)
	activePlayers[player] = nil

	-- Teleport player back to Town Dais
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(DungeonConfig.TOWN_RETURN_POS)
		end
	end

	local event = Remotes.getEvent("DungeonStateUpdated")
	event:FireClient(player, { state = "Left" })

	-- If no players left in arena, reset
	local remaining = 0
	for _ in pairs(activePlayers) do remaining += 1 end
	if remaining == 0 then
		DungeonService.resetDungeon()
	end
end

-- Reset Arena to Idle
function DungeonService.resetDungeon()
	dungeonState = "Idle"
	currentStage = 0
	clearActiveMobs()
	activePlayers = {}
end

-- Initialize DungeonService
function DungeonService.init()
	print("🏰 [DungeonService] Initializing Stage-Based Dungeon Tower...")

	DungeonService.buildArena()
	DungeonService.buildTownPortal()
	startAggroLoop()

	-- Remotes Setup
	local enterFn = Remotes.getFunction("EnterDungeon")
	enterFn.OnServerInvoke = function(player: Player)
		return DungeonService.startDungeonRun(player)
	end

	local leaveFn = Remotes.getFunction("LeaveDungeon")
	leaveFn.OnServerInvoke = function(player: Player)
		DungeonService.leaveDungeon(player)
		return true
	end

	local damageFn = Remotes.getFunction("DamageDungeonMob")
	damageFn.OnServerInvoke = function(player: Player, mobId: any)
		if typeof(mobId) ~= "string" then return false, 0 end
		return DungeonService.damageMob(player, mobId)
	end

	Players.PlayerRemoving:Connect(function(player)
		if activePlayers[player] then
			DungeonService.leaveDungeon(player)
		end
	end)

	print("✅ [DungeonService] Stage-Based Dungeon Tower Online!")
end

return DungeonService
