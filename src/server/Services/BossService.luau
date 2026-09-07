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

local BossService = {}

local bossFolder: Folder
local bossModel: Model? = nil
local bossHumanoid: Humanoid? = nil
local bossRootPart: Part? = nil
local bossHealthBarFill: Frame? = nil
local bossHealthLabel: TextLabel? = nil

local currentHealth = BossConfig.BOSS.maxHealth
local maxHealth = BossConfig.BOSS.maxHealth
local isAlive = false
local isAttacking = false
local isStunned = false
local lastAttackTime = 0

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

-- Builds the physical 3D Infernal Magma Golem NPC
function BossService.spawnBoss()
	if bossModel then
		bossModel:Destroy()
		bossModel = nil
	end

	currentHealth = maxHealth
	isAlive = true
	isAttacking = false
	isStunned = false

	local spawnPos = BossConfig.BOSS.arenaCenter + Vector3.new(0, 6, 0)
	local spawnCF = CFrame.new(spawnPos)

	local model = Instance.new("Model")
	model.Name = "InfernalMagmaGolem"

	local basaltDark = Color3.fromRGB(30, 24, 26)
	local basaltMid = Color3.fromRGB(48, 38, 42)
	local magmaRed = Color3.fromRGB(255, 60, 10)
	local eyeGold = Color3.fromRGB(255, 215, 0)

	-- 1. HumanoidRootPart (Anchored = false for physical navigation)
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
	hum.MaxHealth = maxHealth
	hum.Health = maxHealth
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

	-- Magma fist knuckles
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

	-- 8. Overhead Health Billboard
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
	healthText.Text = string.format("%s / %s HP", FormatNumber.formatCompact(maxHealth), FormatNumber.formatCompact(maxHealth))
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
		BossService.attackBoss(player)
	end)

	model.Parent = bossFolder

	bossModel = model
	bossHumanoid = hum
	bossRootPart = root
	bossHealthBarFill = barFill
	bossHealthLabel = healthText

	-- Broadcast spawn
	local respawnEvent = Remotes.getEvent("BossRespawned")
	respawnEvent:FireAllClients(maxHealth, spawnPos)
	print("👹 [BossService] Infernal Magma Golem spawned at " .. tostring(spawnPos))
end

-- Executes the Golem ground slam attack damaging all nearby players
function BossService.performSlamAttack()
	if not isAlive or isAttacking or isStunned or not bossRootPart then
		return
	end

	isAttacking = true
	lastAttackTime = os.clock()

	-- Broadcast telegraph to all clients (triggers roar, ground vibration, warning visual)
	local attackEvent = Remotes.getEvent("BossAttacking")
	attackEvent:FireAllClients(bossRootPart.Position, BossConfig.BOSS.attackRadius)

	-- 0.45s Windup Telegraph before impact
	task.wait(0.45)

	if not isAlive or not bossRootPart then
		isAttacking = false
		return
	end

	local slamCenter = bossRootPart.Position - Vector3.new(0, 3.5, 0)
	local attackRadius = BossConfig.BOSS.attackRadius
	local dmg = BossConfig.BOSS.attackDamage

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
				local pushDir = Vector3.new(diff.X, 0.4, diff.Z).Unit * 22
				pRoot.AssemblyLinearVelocity = pushDir

				print(string.format("💥 [BossService] Golem slammed %s for %d DMG! (%d HP remaining)", p.Name, dmg, math.floor(pHum.Health)))
			end
		end
	end

	task.wait(0.3)
	isAttacking = false
end

-- Handles player pickaxe strikes against the boss
function BossService.attackBoss(player: Player): (boolean, any)
	if not isAlive or not bossRootPart then
		return false, "Boss is currently defeated"
	end

	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "No character"
	end

	local pRoot = char.HumanoidRootPart :: BasePart
	local dist = (pRoot.Position - bossRootPart.Position).Magnitude
	if dist > 26 then
		return false, "Too far from boss"
	end

	local data = DataService.get(player)
	if not data then return false, "No player data" end

	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local petMult = PetService.getCashMultiplier(player)

	-- Compute Damage using Pickaxe Trait, Trail Boss Multiplier, and Skill Tree Multiplier
	local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
	local trailBossMult = TrailConfig.getBossMultiplier(data.EquippedTrail)
	local skillBossMult = SkillTreeConfig.getTotalBossMult(data.UnlockedSkills)

	local damage, isCrit, trait = BossConfig.calculateDamage(data.EquippedShovel, rebirthMult, petMult)
	damage = math.max(1, math.floor(damage * trailBossMult * skillBossMult))

	-- Apply damage
	currentHealth = math.max(0, currentHealth - damage)
	local isDead = (currentHealth <= 0)

	-- Update Health Bar on Server
	if bossHealthBarFill and bossHealthLabel then
		local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
		bossHealthBarFill.Size = UDim2.new(ratio, 0, 1, 0)
		bossHealthLabel.Text = string.format("%s / %s HP", FormatNumber.formatCompact(currentHealth), FormatNumber.formatCompact(maxHealth))
	end

	-- Execute Special Pickaxe Combat Effects
	local effectTag = if isCrit then "CRIT!" else nil
	if trait.specialEffect == "Stun" then
		if math.random() <= 0.15 and not isStunned then
			isStunned = true
			effectTag = "STAGGER!"
			task.delay(0.8, function()
				isStunned = false
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
			if isAlive and currentHealth > 0 then
				local tickDmg = math.max(1, math.floor(damage * 0.12))
				currentHealth = math.max(0, currentHealth - tickDmg)
				local damagedEvent = Remotes.getEvent("BossDamaged")
				damagedEvent:FireAllClients(currentHealth, maxHealth, tickDmg, false, "🔥 TICK", trait.damageColor, player.Name)
			end
		end)
	elseif trait.specialEffect == "DragonWrath" and isCrit then
		effectTag = "4x WRATH!"
	end

	-- Notify Clients of Hit
	local damagedEvent = Remotes.getEvent("BossDamaged")
	damagedEvent:FireAllClients(currentHealth, maxHealth, damage, isCrit, effectTag or trait.specialEffect, trait.damageColor, player.Name)

	if isDead then
		BossService.onBossDefeated(player)
	end

	return true, {
		damage = damage,
		isCrit = isCrit,
		remainingHealth = currentHealth,
		isDead = isDead,
		trait = trait,
	}
end

-- Handles boss death, distributes massive rewards, and sets respawn timer
function BossService.onBossDefeated(killer: Player)
	if not isAlive then return end
	isAlive = false

	print(string.format("🏆 [BossService] %s defeated the Infernal Magma Golem!", killer.Name))

	-- Award Killer and Arena Players
	local cashReward = BossConfig.BOSS.rewardCash
	local gemReward = BossConfig.BOSS.rewardGems

	DataService.addCash(killer, cashReward)
	DataService.addGems(killer, gemReward)

	-- Broadcast defeat celebration event
	local defeatedEvent = Remotes.getEvent("BossDefeated")
	defeatedEvent:FireAllClients(killer.Name, cashReward, gemReward, BossConfig.BOSS.respawnTime)

	-- Celebratory molten fireworks explosion
	if bossRootPart then
		local explodePos = bossRootPart.Position
		local exp = Instance.new("Explosion")
		exp.Position = explodePos
		exp.BlastRadius = 0
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace

		task.delay(0.6, function()
			if bossModel then
				bossModel:Destroy()
				bossModel = nil
			end
		end)
	end

	-- 20-Second Respawn Loop
	task.delay(BossConfig.BOSS.respawnTime, function()
		BossService.spawnBoss()
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
	attackRemote.OnServerInvoke = function(player: Player)
		return BossService.attackBoss(player)
	end

	-- Initial Spawn
	BossService.spawnBoss()

	-- AI Tick Loop (Runs every 0.28s)
	task.spawn(function()
		while true do
			task.wait(0.28)
			if isAlive and not isAttacking and not isStunned and bossModel and bossRootPart and bossHumanoid then
				local center = BossConfig.BOSS.arenaCenter
				local aggroRadius = BossConfig.BOSS.aggroRadius
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
								local distToBoss = (pPos - bossRootPart.Position).Magnitude
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
					bossHumanoid:MoveTo(targetPos)

					-- If in melee range, execute ground slam attack!
					local distToTarget = (targetPos - bossRootPart.Position).Magnitude
					local now = os.clock()
					if distToTarget <= 10.5 and (now - lastAttackTime) >= BossConfig.BOSS.attackCooldown then
						task.spawn(function()
							BossService.performSlamAttack()
						end)
					end
				else
					-- Return to center of arena and regenerate if dormant
					local distFromCenter = (Vector3.new(bossRootPart.Position.X, center.Y, bossRootPart.Position.Z) - center).Magnitude
					if distFromCenter > 6 then
						bossHumanoid:MoveTo(center)
					end

					if currentHealth < maxHealth then
						currentHealth = math.min(maxHealth, currentHealth + 150)
						if bossHealthBarFill and bossHealthLabel then
							local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
							bossHealthBarFill.Size = UDim2.new(ratio, 0, 1, 0)
							bossHealthLabel.Text = string.format("%s / %s HP", FormatNumber.formatCompact(currentHealth), FormatNumber.formatCompact(maxHealth))
						end
					end
				end
			end
		end
	end)

	print("✅ [BossService] Initialized with Infernal Magma Golem AI and combat system active!")
end

return BossService
