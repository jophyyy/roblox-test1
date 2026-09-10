--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local DataService = require(script.Parent.DataService)
local LootBoxService = require(script.Parent.LootBoxService)

local TutorialService = {}

-- In-memory session progress counter for multi-count steps (e.g. Step 2: mine 3 ores)
local sessionProgress: { [Player]: { [number]: number } } = {}

local function getSessionCount(player: Player, step: number): number
	if not sessionProgress[player] then
		sessionProgress[player] = {}
	end
	return sessionProgress[player][step] or 0
end

local function setSessionCount(player: Player, step: number, count: number)
	if not sessionProgress[player] then
		sessionProgress[player] = {}
	end
	sessionProgress[player][step] = count
end

function TutorialService.syncProgress(player: Player)
	local step, completed = DataService.getTutorialProgress(player)
	local currentCount = getSessionCount(player, step)
	local syncEvent = Remotes.getEvent("TutorialProgressSync")
	syncEvent:FireClient(player, {
		step = step,
		completed = completed,
		currentCount = currentCount,
	})
end

function TutorialService.completeStep(player: Player, stepNum: number)
	local currentStep, completed = DataService.getTutorialProgress(player)
	if completed or currentStep ~= stepNum then
		return
	end

	local stepDef = TutorialConfig.getStep(stepNum)
	if not stepDef then return end

	-- 1. Disburse Server-Side Rewards
	if stepDef.reward.cash and stepDef.reward.cash > 0 then
		DataService.addCash(player, stepDef.reward.cash)
	end
	if stepDef.reward.gems and stepDef.reward.gems > 0 then
		DataService.addGems(player, stepDef.reward.gems)
	end
	if stepDef.reward.crateId and stepDef.reward.crateCount then
		LootBoxService.addLootBox(player, stepDef.reward.crateId, stepDef.reward.crateCount)
	end

	local nextStep = stepNum + 1
	local isFinal = (stepNum >= TutorialConfig.getTotalSteps())
	local newCompleted = isFinal

	-- 2. Save progress in DataStore
	DataService.setTutorialProgress(player, nextStep, newCompleted)

	-- 3. Broadcast celebration event to client
	local completeEvent = Remotes.getEvent("TutorialStepCompleted")
	completeEvent:FireClient(player, {
		completedStep = stepNum,
		nextStep = nextStep,
		isFinal = isFinal,
		reward = stepDef.reward,
		rewardText = stepDef.rewardText,
	})

	TutorialService.syncProgress(player)
	print(string.format("🎓 [TutorialService] %s completed Tutorial Step %d: %s!", player.Name, stepNum, stepDef.title))
end

-- Listener hook: Called when player mines an ore in Zone 1
function TutorialService.onOreMined(player: Player)
	local step, completed = DataService.getTutorialProgress(player)
	if completed then return end

	if step == 1 then
		TutorialService.completeStep(player, 1)
	elseif step == 2 then
		local count = getSessionCount(player, 2) + 1
		setSessionCount(player, 2, count)
		if count >= 3 then
			TutorialService.completeStep(player, 2)
		else
			TutorialService.syncProgress(player)
		end
	end
end

-- Listener hook: Called when player opens a crate in LootBoxService
function TutorialService.onBoxOpened(player: Player, _boxId: string)
	local step, completed = DataService.getTutorialProgress(player)
	if completed then return end

	if step == 3 then
		TutorialService.completeStep(player, 3)
	end
end

-- Listener hook: Called when player purchases a shop item in DataService
function TutorialService.onShopItemPurchased(player: Player, category: string, _itemId: string)
	local step, completed = DataService.getTutorialProgress(player)
	if completed then return end

	if step == 4 and (category == "Shovels" or category == "Backpacks") then
		TutorialService.completeStep(player, 4)
	end
end

-- Listener hook: Called when player hatches an egg or equips a pet
function TutorialService.onPetEquippedOrHatched(player: Player)
	local step, completed = DataService.getTutorialProgress(player)
	if completed then return end

	if step == 5 then
		TutorialService.completeStep(player, 5)
	end
end

-- Player skips tutorial: grants starter package and marks complete
function TutorialService.skipTutorial(player: Player): boolean
	local _, completed = DataService.getTutorialProgress(player)
	if completed then
		return true
	end

	-- Grant starter boost package so skipping players are not disadvantaged
	DataService.addCash(player, 5000)
	DataService.addGems(player, 200)
	LootBoxService.addLootBox(player, "box_wooden", 1)

	DataService.setTutorialProgress(player, TutorialConfig.getTotalSteps() + 1, true)
	TutorialService.syncProgress(player)

	print(string.format("⏩ [TutorialService] %s skipped tutorial (starter pack granted).", player.Name))
	return true
end

function TutorialService.init()
	-- Handle Skip Remote
	local skipFn = Remotes.getFunction("SkipTutorial")
	skipFn.OnServerInvoke = function(player: Player)
		return TutorialService.skipTutorial(player)
	end

	-- Sync on player spawn / join
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.0)
			TutorialService.syncProgress(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(1.0)
			TutorialService.syncProgress(player)
		end)
	end

	print("🎓 [TutorialService] Initialized beginner tutorial manager!")
end

return TutorialService
