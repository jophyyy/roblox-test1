--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local DataService = require(script.Parent.DataService)

local TrailService = {}
local activeTrails: { [Player]: Trail } = {}

function TrailService.updatePlayerTrail(player: Player)
	local char = player.Character
	if not char then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end

	-- Remove any existing trail and attachments
	local existingTrail = rootPart:FindFirstChild("CharacterTrail")
	if existingTrail then
		existingTrail:Destroy()
	end
	local att0 = rootPart:FindFirstChild("TrailAttachment0")
	if att0 then att0:Destroy() end
	local att1 = rootPart:FindFirstChild("TrailAttachment1")
	if att1 then att1:Destroy() end

	local data = DataService.get(player)
	local skillSpeed = if data then SkillTreeConfig.getTotalSpeedBonus(data.UnlockedSkills) else 0

	if not data or not data.EquippedTrail then
		humanoid.WalkSpeed = 16 + skillSpeed
		return
	end

	local trailDef = TrailConfig.getTrail(data.EquippedTrail)
	local trailSpeed = if trailDef then trailDef.speedBonus else 0

	-- Apply total speed boost directly to Humanoid base speed
	humanoid.WalkSpeed = 16 + trailSpeed + skillSpeed

	-- Create Attachments on HumanoidRootPart
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailAttachment0"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = rootPart

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailAttachment1"
	a1.Position = Vector3.new(0, -1.5, 0)
	a1.Parent = rootPart

	-- Create Roblox Trail
	local trail = Instance.new("Trail")
	trail.Name = "CharacterTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = trailDef.colorSequence
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.65, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = trailDef.lifetime
	trail.WidthScale = trailDef.widthScale
	trail.LightEmission = 0.85
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.MaxLength = 0
	trail.MinLength = 0.1
	trail.Parent = rootPart

	activeTrails[player] = trail
end

function TrailService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			TrailService.updatePlayerTrail(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				task.wait(0.3)
				TrailService.updatePlayerTrail(player)
			end)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			TrailService.updatePlayerTrail(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		activeTrails[player] = nil
	end)

	print("✅ [TrailService] Initialized with 3D character trail renderer!")
end

return TrailService
