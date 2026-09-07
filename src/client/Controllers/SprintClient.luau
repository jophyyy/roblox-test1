--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)

local SprintClient = {}

local BASE_NORMAL_SPEED = 16
local BASE_SPRINT_SPEED = 30
local NORMAL_FOV = 70
local SPRINT_FOV = 78

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local isShiftHeld = false
local currentHumanoid: Humanoid? = nil
local trailSpeedBonus = 0
local skillSpeedBonus = 0

local function getNormalSpeed(): number
	return BASE_NORMAL_SPEED + trailSpeedBonus + skillSpeedBonus
end

local function getSprintSpeed(): number
	return BASE_SPRINT_SPEED + math.floor((trailSpeedBonus + skillSpeedBonus) * 1.5)
end

local function getHumanoid(): Humanoid?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function setSprint(sprinting: boolean)
	local hum = currentHumanoid or getHumanoid()
	if not hum then return end

	local targetSpeed = if sprinting then getSprintSpeed() else getNormalSpeed()
	local targetFOV = if sprinting then SPRINT_FOV else NORMAL_FOV

	hum.WalkSpeed = targetSpeed

	if camera then
		TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = targetFOV,
		}):Play()
	end
end

local function onCharacterAdded(character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	currentHumanoid = hum
	hum.WalkSpeed = if isShiftHeld then getSprintSpeed() else getNormalSpeed()

	hum.Died:Connect(function()
		isShiftHeld = false
		setSprint(false)
	end)
end

local function updateSpeedFromData(data: any)
	if not data then return end
	trailSpeedBonus = TrailConfig.getSpeedBonus(data.EquippedTrail)
	skillSpeedBonus = SkillTreeConfig.getTotalSpeedBonus(data.UnlockedSkills)
	setSprint(isShiftHeld)
end

function SprintClient.init()
	if player.Character then
		task.spawn(function()
			onCharacterAdded(player.Character)
		end)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Listen for player data to update trail & skill speed bonuses
	task.spawn(function()
		local getDataFn = Remotes.getFunction("GetPlayerData")
		local data = getDataFn:InvokeServer()
		updateSpeedFromData(data)
	end)

	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent.OnClientEvent:Connect(function(data)
		updateSpeedFromData(data)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if UserInputService:GetFocusedTextBox() ~= nil then return end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			isShiftHeld = true
			setSprint(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			isShiftHeld = false
			setSprint(false)
		end
	end)
end

return SprintClient
