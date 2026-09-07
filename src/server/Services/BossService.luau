--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BossConfig = require(ReplicatedStorage.Shared.Config.BossConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

export type ActiveBossState = {
	def: BossConfig.BossDef,
	model: Model?,
	humanoid: Humanoid?,
	rootPart: Part?,
	healthBarFill: Frame?,
	healthLabel: TextLabel?,
	currentHealth: number,
	maxHealth: number,
	isAlive: boolean,
	isAttacking: boolean,
	isStunned: boolean,
	lastAttackTime: number,
}

local BossService = {}

local bossFolder: Folder
local activeBosses: { [string]: ActiveBossState } = {}

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
	part.CanCollide = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function weldParts(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end

-- Builds the physical 3D Infernal Magma Golem NPC (Zone 2)
local function buildInfernalMagmaGolem(state: ActiveBossState)
	local spawnPos = state.def.arenaCenter + Vector3.new(0, 6, 0)
	local spawnCF = CFrame.new(spawnPos)

	local model = Instance.new("Model")
	model.Name = state.def.id

	local basaltDark = Color3.fromRGB(30, 24, 26)
	local basaltMid = Color3.fromRGB(48, 38, 42)
	local magmaRed = Color3.fromRGB(255, 60, 10)
	local eyeGold = Color3.fromRGB(255, 215, 0)

	-- 1. HumanoidRootPart
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(6, 8, 4)
	root.CFrame = spawnCF
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.Parent = model
	model.PrimaryPart = root

	-- 2. Humanoid Setup
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.MaxHealth = state.maxHealth
	hum.Health = state.maxHealth
	hum.WalkSpeed = 12
	hum.AutoRotate = true
	hum.Parent = model

	-- 3. Massive Basalt Torso with Glowing Magma Core
	local torso = createStudPart(model, "Torso", Vector3.new(7.2, 7.5, 4.5), spawnCF, basaltDark)
	weldParts(root, torso)

	local core = createStudPart(model, "MagmaCore", Vector3.new(3.8, 4.5, 1.2), spawnCF * CFrame.new(0, 0.4, -2.1), magmaRed, Enum.Material.Neon)
	weldParts(torso, core)

	-- 4. Horned Stone Head & Glowing Eyes
	local head = createStudPart(model, "Head", Vector3.new(4.2, 3.8, 3.8), spawnCF * CFrame.new(0, 5.2, 0), basaltMid)
	weldParts(torso, head)

	local eyeL = createStudPart(model, "EyeL", Vector3.new(0.8, 0.5, 0.4), spawnCF * CFrame.new(-1.1, 5.4, -1.95), eyeGold, Enum.Material.Neon)
	local eyeR = createStudPart(model, "EyeR", Vector3.new(0.8, 0.5, 0.4), spawnCF * CFrame.new(1.1, 5.4, -1.95), eyeGold, Enum.Material.Neon)
	weldParts(head, eyeL)
	weldParts(head, eyeR)

	-- Brow Spikes
	local hornL = createStudPart(model, "HornL", Vector3.new(1.2, 3.2, 1.2), spawnCF * CFrame.new(-2.2, 7.2, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(-20)), basaltDark)
	local hornR = createStudPart(model, "HornR", Vector3.new(1.2, 3.2, 1.2), spawnCF * CFrame.new(2.2, 7.2, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(20)), basaltDark)
	weldParts(head, hornL)
	weldParts(head, hornR)

	-- 5. Heavy Stone Fists & Arms
	local armL = createStudPart(model, "LeftArm", Vector3.new(3.2, 7.2, 3.2), spawnCF * CFrame.new(-5.2, 0.5, 0), basaltDark)
	local armR = createStudPart(model, "RightArm", Vector3.new(3.2, 7.2, 3.2), spawnCF * CFrame.new(5.2, 0.5, 0), basaltDark)
	weldParts(torso, armL)
	weldParts(torso, armR)

	local fistL = createStudPart(model, "FistL", Vector3.new(3.6, 2.2, 3.6), spawnCF * CFrame.new(-5.2, -3.2, 0), magmaRed, Enum.Material.Neon)
	local fistR = createStudPart(model, "FistR", Vector3.new(3.6, 2.2, 3.6), spawnCF * CFrame.new(5.2, -3.2, 0), magmaRed, Enum.Material.Neon)
	weldParts(armL, fistL)
	weldParts(armR, fistR)

	-- 6. Thick Basalt Leg Columns
	local legL = createStudPart(model, "LeftLeg", Vector3.new(3.0, 5.5, 3.0), spawnCF * CFrame.new(-2.0, -5.5, 0), basaltMid)
	local legR = createStudPart(model, "RightLeg", Vector3.new(3.0, 5.5, 3.0), spawnCF * CFrame.new(2.0, -5.5, 0), basaltMid)
	weldParts(root, legL)
	weldParts(root, legR)

	-- 7. Fire Emitters & Dynamic Aura
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 1.0, 0)
	attach.Parent = head

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "BossFire"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 70, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 0)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.5, 2.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Lifetime = NumberRange.new(1.0, 1.8)
	fire.Rate = 22
	fire.Speed = NumberRange.new(4, 8)
	fire.SpreadAngle = Vector2.new(25, 25)
	fire.Acceleration = Vector3.new(0, 6, 0)
	fire.LightEmission = 0.9
	fire.Parent = attach

	local bossLight = Instance.new("PointLight")
	bossLight.Color = Color3.fromRGB(255, 70, 10)
	bossLight.Brightness = 3.2
	bossLight.Range = 35
	bossLight.Parent = core

	-- 8. Overhead Health Billboard (AlwaysOnTop = false)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BossBillboard"
	billboard.Size = UDim2.new(0, 240, 0, 68)
	billboard.StudsOffset = Vector3.new(0, 9.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 85

	local title = Instance.new("TextLabel")
	title.Name = "BossTitle"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Text = "👹 INFERNAL MAGMA GOLEM 👹"
	title.TextColor3 = Color3.fromRGB(255, 110, 40)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextStrokeTransparency = 0.2
	title.Parent = billboard

	local barBg = Instance.new("Frame")
	barBg.Name = "HealthBarBg"
	barBg.Size = UDim2.new(1, -20, 0, 16)
	barBg.Position = UDim2.new(0, 10, 0, 28)
	barBg.BackgroundColor3 = Color3.fromRGB(24, 18, 20)
	barBg.BorderSizePixel = 0
	barBg.Parent = billboard

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 8)
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 20)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 8)
	barFillCorner.Parent = barFill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(state.maxHealth), FormatNumber.formatCompact(state.maxHealth))
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.Font = Enum.Font.GothamBold
	healthText.TextSize = 12
	healthText.TextStrokeTransparency = 0.3
	healthText.Parent = barBg

	billboard.Parent = head

	-- ClickDetector for direct clicking
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 22
	clickDetector.Parent = torso

	clickDetector.MouseClick:Connect(function(player)
		BossService.attackBoss(player, state.def.id)
	end)

	model.Parent = bossFolder
	state.model = model
	state.humanoid = hum
	state.rootPart = root
	state.healthBarFill = barFill
	state.healthLabel = healthText
end

-- Builds the physical 3D Void Harbinger Chronos NPC (Zone 3)
local function buildVoidHarbinger(state: ActiveBossState)
	local spawnPos = state.def.arenaCenter + Vector3.new(0, 7, 0)
	local spawnCF = CFrame.new(spawnPos)

	local model = Instance.new("Model")
	model.Name = state.def.id

	local voidDark = Color3.fromRGB(16, 12, 28)
	local voidMid = Color3.fromRGB(36, 28, 56)
	local astralPurple = Color3.fromRGB(150, 50, 255)
	local stardustCyan = Color3.fromRGB(0, 230, 255)

	-- 1. HumanoidRootPart
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(7, 9, 5)
	root.CFrame = spawnCF
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.Parent = model
	model.PrimaryPart = root

	-- 2. Humanoid Setup
	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.MaxHealth = state.maxHealth
	hum.Health = state.maxHealth
	hum.WalkSpeed = 13
	hum.AutoRotate = true
	hum.Parent = model

	-- 3. Massive Obsidian Torso with Glowing Void Core
	local torso = createStudPart(model, "Torso", Vector3.new(8.0, 8.5, 5.0), spawnCF, voidDark)
	weldParts(root, torso)

	local core = createStudPart(model, "VoidCore", Vector3.new(4.2, 5.0, 1.4), spawnCF * CFrame.new(0, 0.4, -2.4), astralPurple, Enum.Material.Neon)
	weldParts(torso, core)

	-- 4. Horned Crown Head & Glowing Cyan Eyes
	local head = createStudPart(model, "Head", Vector3.new(4.5, 4.2, 4.2), spawnCF * CFrame.new(0, 6.0, 0), voidMid)
	weldParts(torso, head)

	local eyeL = createStudPart(model, "EyeL", Vector3.new(0.9, 0.6, 0.4), spawnCF * CFrame.new(-1.2, 6.2, -2.15), stardustCyan, Enum.Material.Neon)
	local eyeR = createStudPart(model, "EyeR", Vector3.new(0.9, 0.6, 0.4), spawnCF * CFrame.new(1.2, 6.2, -2.15), stardustCyan, Enum.Material.Neon)
	weldParts(head, eyeL)
	weldParts(head, eyeR)

	-- Floating Astral Crown / Ring above head
	local crown = createStudPart(model, "AstralCrown", Vector3.new(5.5, 0.5, 5.5), spawnCF * CFrame.new(0, 9.2, 0), stardustCyan, Enum.Material.Neon)
	weldParts(head, crown)

	-- Spired Astral Horns
	local hornL = createStudPart(model, "HornL", Vector3.new(1.4, 4.2, 1.4), spawnCF * CFrame.new(-2.6, 8.4, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(-25)), voidDark)
	local hornR = createStudPart(model, "HornR", Vector3.new(1.4, 4.2, 1.4), spawnCF * CFrame.new(2.6, 8.4, -0.6) * CFrame.Angles(math.rad(25), 0, math.rad(25)), voidDark)
	weldParts(head, hornL)
	weldParts(head, hornR)

	-- 5. Swept Astral Void Wings extending from back
	local wingL = createStudPart(model, "WingL", Vector3.new(2.0, 10.0, 7.0), spawnCF * CFrame.new(-6.5, 4.0, 2.5) * CFrame.Angles(0, math.rad(-35), math.rad(25)), voidMid)
	local wingR = createStudPart(model, "WingR", Vector3.new(2.0, 10.0, 7.0), spawnCF * CFrame.new(6.5, 4.0, 2.5) * CFrame.Angles(0, math.rad(35), math.rad(-25)), voidMid)
	weldParts(torso, wingL)
	weldParts(torso, wingR)

	local wingFeatherL = createStudPart(model, "WingFeatherL", Vector3.new(1.0, 8.0, 5.0), spawnCF * CFrame.new(-7.0, 4.0, 2.8) * CFrame.Angles(0, math.rad(-35), math.rad(25)), astralPurple, Enum.Material.Neon)
	local wingFeatherR = createStudPart(model, "WingFeatherR", Vector3.new(1.0, 8.0, 5.0), spawnCF * CFrame.new(7.0, 4.0, 2.8) * CFrame.Angles(0, math.rad(35), math.rad(-25)), astralPurple, Enum.Material.Neon)
	weldParts(wingL, wingFeatherL)
	weldParts(wingR, wingFeatherR)

	-- 6. Heavy Gauntlets & Void Claws
	local armL = createStudPart(model, "LeftArm", Vector3.new(3.5, 8.0, 3.5), spawnCF * CFrame.new(-5.8, 0.5, 0), voidDark)
	local armR = createStudPart(model, "RightArm", Vector3.new(3.5, 8.0, 3.5), spawnCF * CFrame.new(5.8, 0.5, 0), voidDark)
	weldParts(torso, armL)
	weldParts(torso, armR)

	local fistL = createStudPart(model, "FistL", Vector3.new(4.0, 2.5, 4.0), spawnCF * CFrame.new(-5.8, -3.8, 0), stardustCyan, Enum.Material.Neon)
	local fistR = createStudPart(model, "FistR", Vector3.new(4.0, 2.5, 4.0), spawnCF * CFrame.new(5.8, -3.8, 0), stardustCyan, Enum.Material.Neon)
	weldParts(armL, fistL)
	weldParts(armR, fistR)

	-- 7. Heavy Void Pillar Legs
	local legL = createStudPart(model, "LeftLeg", Vector3.new(3.4, 6.2, 3.4), spawnCF * CFrame.new(-2.2, -6.0, 0), voidMid)
	local legR = createStudPart(model, "RightLeg", Vector3.new(3.4, 6.2, 3.4), spawnCF * CFrame.new(2.2, -6.0, 0), voidMid)
	weldParts(root, legL)
	weldParts(root, legR)

	-- 8. Dynamic Stardust and Void Aura
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 1.2, 0)
	attach.Parent = head

	local stardust = Instance.new("ParticleEmitter")
	stardust.Name = "VoidParticles"
	stardust.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 60, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 230, 255)),
	})
	stardust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(0.5, 3.2),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	stardust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	stardust.Lifetime = NumberRange.new(1.2, 2.2)
	stardust.Rate = 26
	stardust.Speed = NumberRange.new(4, 9)
	stardust.SpreadAngle = Vector2.new(35, 35)
	stardust.Acceleration = Vector3.new(0, 5, 0)
	stardust.LightEmission = 0.95
	stardust.Parent = attach

	local bossLight = Instance.new("PointLight")
	bossLight.Color = Color3.fromRGB(160, 60, 255)
	bossLight.Brightness = 3.5
	bossLight.Range = 40
	bossLight.Parent = core

	-- 9. Overhead Health Billboard (AlwaysOnTop = false)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BossBillboard"
	billboard.Size = UDim2.new(0, 270, 0, 72)
	billboard.StudsOffset = Vector3.new(0, 11.0, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 85

	local title = Instance.new("TextLabel")
	title.Name = "BossTitle"
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = "🌌 VOID HARBINGER CHRONOS 🌌"
	title.TextColor3 = Color3.fromRGB(180, 130, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextStrokeTransparency = 0.2
	title.Parent = billboard

	local barBg = Instance.new("Frame")
	barBg.Name = "HealthBarBg"
	barBg.Size = UDim2.new(1, -20, 0, 16)
	barBg.Position = UDim2.new(0, 10, 0, 30)
	barBg.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
	barBg.BorderSizePixel = 0
	barBg.Parent = billboard

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 8)
	barBgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(140, 40, 255)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 8)
	barFillCorner.Parent = barFill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(state.maxHealth), FormatNumber.formatCompact(state.maxHealth))
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.Font = Enum.Font.GothamBold
	healthText.TextSize = 12
	healthText.TextStrokeTransparency = 0.3
	healthText.Parent = barBg

	billboard.Parent = head

	-- ClickDetector for direct clicking
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 24
	clickDetector.Parent = torso

	clickDetector.MouseClick:Connect(function(player)
		BossService.attackBoss(player, state.def.id)
	end)

	model.Parent = bossFolder
	state.model = model
	state.humanoid = hum
	state.rootPart = root
	state.healthBarFill = barFill
	state.healthLabel = healthText
end

-- Spawns or respawns a world boss
function BossService.spawnBoss(bossId: string?)
	local targets = {}
	if bossId then
		if BossConfig.BOSSES[bossId] then
			table.insert(targets, BossConfig.BOSSES[bossId])
		end
	else
		for _, bDef in BossConfig.BOSSES do
			table.insert(targets, bDef)
		end
	end

	for _, bDef in ipairs(targets) do
		local existing = activeBosses[bDef.id]
		if existing and existing.model then
			existing.model:Destroy()
			existing.model = nil
		end

		local state: ActiveBossState = {
			def = bDef,
			model = nil,
			humanoid = nil,
			rootPart = nil,
			healthBarFill = nil,
			healthLabel = nil,
			currentHealth = bDef.maxHealth,
			maxHealth = bDef.maxHealth,
			isAlive = true,
			isAttacking = false,
			isStunned = false,
			lastAttackTime = 0,
		}
		activeBosses[bDef.id] = state

		if bDef.id == "InfernalMagmaGolem" then
			buildInfernalMagmaGolem(state)
		elseif bDef.id == "VoidHarbinger" then
			buildVoidHarbinger(state)
		end

		local respawnEvent = Remotes.getEvent("BossRespawned")
		respawnEvent:FireAllClients(bDef.maxHealth, bDef.arenaCenter, bDef.id)
		print(string.format("⚔️ [BossService] %s spawned at %s (HP: %s)", bDef.name, tostring(bDef.arenaCenter), FormatNumber.formatCompact(bDef.maxHealth)))
	end
end

-- Executes the ground slam attack damaging all nearby players
function BossService.performSlamAttack(state: ActiveBossState)
	if not state.isAlive or state.isAttacking or state.isStunned or not state.rootPart then
		return
	end

	state.isAttacking = true
	state.lastAttackTime = os.clock()

	-- Broadcast telegraph to all clients
	local attackEvent = Remotes.getEvent("BossAttacking")
	attackEvent:FireAllClients(state.rootPart.Position, state.def.attackRadius, state.def.id)

	-- 0.45s Windup Telegraph before impact
	task.wait(0.45)

	if not state.isAlive or not state.rootPart then
		state.isAttacking = false
		return
	end

	local slamCenter = state.rootPart.Position - Vector3.new(0, 3.5, 0)
	local attackRadius = state.def.attackRadius
	local dmg = state.def.attackDamage

	-- Check players caught in slam radius
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
			local pRoot = char.HumanoidRootPart :: BasePart
			local pHum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
			local dist = (pRoot.Position - slamCenter).Magnitude

			if dist <= attackRadius and pHum.Health > 0 then
				pHum:TakeDamage(dmg)

				-- Knockback pulse away from slam center
				local diff = (pRoot.Position - slamCenter).Unit
				local pushDir = Vector3.new(diff.X, 0.4, diff.Z).Unit * 24
				pRoot.AssemblyLinearVelocity = pushDir

				print(string.format("💥 [BossService] %s slammed %s for %d DMG! (%d HP remaining)", state.def.name, p.Name, dmg, math.floor(pHum.Health)))
			end
		end
	end

	task.wait(0.3)
	state.isAttacking = false
end

-- Handles player pickaxe strikes against the boss
function BossService.attackBoss(player: Player, targetBossId: string?): (boolean, any)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "No character"
	end

	local pRoot = char.HumanoidRootPart :: BasePart

	-- Resolve target boss (either by targetBossId or closest within 28 studs)
	local chosenState: ActiveBossState? = nil
	if targetBossId and activeBosses[targetBossId] then
		chosenState = activeBosses[targetBossId]
	else
		local closestDist = 28
		for _, state in activeBosses do
			if state.isAlive and state.rootPart then
				local dist = (pRoot.Position - state.rootPart.Position).Magnitude
				if dist <= closestDist then
					closestDist = dist
					chosenState = state
				end
			end
		end
	end

	if not chosenState or not chosenState.isAlive or not chosenState.rootPart then
		return false, "Boss is currently defeated"
	end

	local dist = (pRoot.Position - chosenState.rootPart.Position).Magnitude
	if dist > 28 then
		return false, "Too far from boss"
	end

	local data = DataService.get(player)
	if not data then return false, "No player data" end

	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local petMult = PetService.getCashMultiplier(player)

	-- 0. Award Click Power from boss strike
	local powerGain, clickCash, clickGems = DataService.calculateClickPowerGain(player)
	DataService.addPower(player, powerGain)
	if clickCash > 0 then
		DataService.addCash(player, clickCash)
	end
	if clickGems > 0 then
		DataService.addGems(player, clickGems)
	end

	-- Compute Damage using Player's Power, Pickaxe Trait, Trail Boss Multiplier, and Skill Tree Multiplier
	local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
	local trailBossMult = TrailConfig.getBossMultiplier(data.EquippedTrail)
	local skillBossMult = SkillTreeConfig.getTotalBossMult(data.UnlockedSkills)

	local playerPower = math.max(1, data.Power or 10)
	local damage, isCrit, trait = BossConfig.calculateDamage(playerPower, data.EquippedShovel, rebirthMult, petMult)
	damage = math.max(1, math.floor(damage * trailBossMult * skillBossMult))

	-- Apply damage
	chosenState.currentHealth = math.max(0, chosenState.currentHealth - damage)
	local isDead = (chosenState.currentHealth <= 0)

	-- Update Health Bar on Server
	if chosenState.healthBarFill and chosenState.healthLabel then
		local ratio = math.clamp(chosenState.currentHealth / chosenState.maxHealth, 0, 1)
		chosenState.healthBarFill.Size = UDim2.new(ratio, 0, 1, 0)
		chosenState.healthLabel.Text = string.format("%s / %s HP", FormatNumber.formatCompact(chosenState.currentHealth), FormatNumber.formatCompact(chosenState.maxHealth))
	end

	-- Execute Special Pickaxe Combat Effects
	local effectTag = if isCrit then "CRIT!" else nil
	if trait.specialEffect == "Stun" then
		if math.random() <= 0.15 and not chosenState.isStunned then
			chosenState.isStunned = true
			effectTag = "STAGGER!"
			task.delay(0.8, function()
				chosenState.isStunned = false
			end)
		end
	elseif trait.specialEffect == "GoldRush" then
		DataService.addCash(player, 250)
		effectTag = "+$250!"
	elseif trait.specialEffect == "VoidSiphon" then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 10)
		end
		effectTag = "+10 HP!"
	elseif trait.specialEffect == "MoltenBurn" then
		effectTag = "BURN!"
		task.delay(0.5, function()
			if chosenState.isAlive and chosenState.currentHealth > 0 then
				local tickDmg = math.max(1, math.floor(damage * 0.12))
				chosenState.currentHealth = math.max(0, chosenState.currentHealth - tickDmg)
				local damagedEvent = Remotes.getEvent("BossDamaged")
				damagedEvent:FireAllClients(chosenState.currentHealth, chosenState.maxHealth, tickDmg, false, "🔥 TICK", trait.damageColor, player.Name, chosenState.def.id)
			end
		end)
	elseif trait.specialEffect == "DragonWrath" and isCrit then
		effectTag = "4x WRATH!"
	end

	-- Notify Clients of Hit
	local damagedEvent = Remotes.getEvent("BossDamaged")
	damagedEvent:FireAllClients(chosenState.currentHealth, chosenState.maxHealth, damage, isCrit, effectTag or trait.specialEffect, trait.damageColor, player.Name, chosenState.def.id)

	if isDead then
		BossService.onBossDefeated(player, chosenState)
	end

	return true, {
		damage = damage,
		isCrit = isCrit,
		remainingHealth = chosenState.currentHealth,
		isDead = isDead,
		trait = trait,
		powerGained = powerGain,
		bossId = chosenState.def.id,
	}
end

-- Handles boss death, distributes massive rewards, and sets respawn timer
function BossService.onBossDefeated(killer: Player, state: ActiveBossState)
	if not state.isAlive then return end
	state.isAlive = false

	print(string.format("🏆 [BossService] %s defeated %s!", killer.Name, state.def.name))

	local cashReward = state.def.rewardCash
	local gemReward = state.def.rewardGems

	DataService.addCash(killer, cashReward)
	DataService.addGems(killer, gemReward)

	-- Broadcast defeat celebration event
	local defeatedEvent = Remotes.getEvent("BossDefeated")
	defeatedEvent:FireAllClients(killer.Name, cashReward, gemReward, state.def.respawnTime, state.def.name, state.def.id)

	-- Celebratory explosion
	if state.rootPart then
		local explodePos = state.rootPart.Position
		local exp = Instance.new("Explosion")
		exp.Position = explodePos
		exp.BlastRadius = 0
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace

		task.delay(0.6, function()
			if state.model then
				state.model:Destroy()
				state.model = nil
			end
		end)
	end

	-- Respawn Loop for this specific boss
	local bossId = state.def.id
	task.delay(state.def.respawnTime, function()
		BossService.spawnBoss(bossId)
	end)
end

function BossService.init()
	local existing = Workspace:FindFirstChild("BossFolder")
	if existing then existing:Destroy() end

	bossFolder = Instance.new("Folder")
	bossFolder.Name = "BossFolder"
	bossFolder.Parent = Workspace

	-- Bind AttackBoss RemoteFunction
	local attackRemote = Remotes.getFunction("AttackBoss")
	attackRemote.OnServerInvoke = function(player: Player, bossId: string?)
		return BossService.attackBoss(player, bossId)
	end

	-- Initial Spawn for all configured World Bosses
	BossService.spawnBoss()

	-- AI Tick Loop (Runs every 0.28s)
	task.spawn(function()
		while true do
			task.wait(0.28)
			for _, state in activeBosses do
				if state.isAlive and not state.isAttacking and not state.isStunned and state.model and state.rootPart and state.humanoid then
					local center = state.def.arenaCenter
					local aggroRadius = state.def.aggroRadius
					local closestPlayer: Player? = nil
					local closestDist = aggroRadius

					for _, p in ipairs(Players:GetPlayers()) do
						local char = p.Character
						if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
							local pHum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
							if pHum.Health > 0 then
								local pPos = char.HumanoidRootPart.Position
								local distFromCenter = (Vector3.new(pPos.X, center.Y, pPos.Z) - center).Magnitude
								if distFromCenter <= aggroRadius then
									local distToBoss = (pPos - state.rootPart.Position).Magnitude
									if distToBoss < closestDist then
										closestDist = distToBoss
										closestPlayer = p
									end
								end
							end
						end
					end

					if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
						local targetPos = closestPlayer.Character.HumanoidRootPart.Position
						state.humanoid:MoveTo(targetPos)

						-- If in melee range, execute ground slam attack!
						local distToTarget = (targetPos - state.rootPart.Position).Magnitude
						local now = os.clock()
						if distToTarget <= 10.5 and (now - state.lastAttackTime) >= state.def.attackCooldown then
							task.spawn(function()
								BossService.performSlamAttack(state)
							end)
						end
					else
						-- Return to center of arena and regenerate if dormant
						local distFromCenter = (Vector3.new(state.rootPart.Position.X, center.Y, state.rootPart.Position.Z) - center).Magnitude
						if distFromCenter > 6 then
							state.humanoid:MoveTo(center)
						end

						if state.currentHealth < state.maxHealth then
							state.currentHealth = math.min(state.maxHealth, state.currentHealth + 250)
							if state.healthBarFill and state.healthLabel then
								local ratio = math.clamp(state.currentHealth / state.maxHealth, 0, 1)
								state.healthBarFill.Size = UDim2.new(ratio, 0, 1, 0)
								state.healthLabel.Text = string.format("%s / %s HP", FormatNumber.formatCompact(state.currentHealth), FormatNumber.formatCompact(state.maxHealth))
							end
						end
					end
				end
			end
		end
	end)

	print("✅ [BossService] Initialized with Multi-Boss AI (Infernal Magma Golem & Void Harbinger Chronos active)!")
end

return BossService
