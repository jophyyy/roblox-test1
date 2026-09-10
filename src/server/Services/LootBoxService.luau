--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local LootBoxConfig = require(ReplicatedStorage.Shared.Config.LootBoxConfig)
local DataService = require(script.Parent.DataService)

local LootBoxService = {}

function LootBoxService.openBox(player: Player, boxId: string): (boolean, any)
	local boxDef = LootBoxConfig.getBox(boxId)
	if not boxDef then
		return false, "Invalid loot box type!"
	end

	-- Consume 1 box from player inventory
	local success = DataService.consumeLootBox(player, boxId, 1)
	if not success then
		return false, "You do not own any " .. boxDef.name .. "!"
	end

	-- Roll reward
	local reward = LootBoxConfig.rollReward(boxId)

	-- Apply reward
	if reward.category == "Cash" and reward.amount then
		DataService.addCash(player, reward.amount)
	elseif reward.category == "Gems" and reward.amount then
		DataService.addGems(player, reward.amount)
	elseif reward.category == "Power" and reward.amount then
		DataService.addPower(player, reward.amount)
	elseif reward.category == "Pet" and reward.petId then
		DataService.addPet(player, reward.petId, 1)
	end

	local boxes = DataService.getLootBoxes(player)
	local remaining = boxes[boxId] or 0

	print(string.format("📦 [LootBoxService] %s opened %s -> %s (%s)", player.Name, boxDef.name, reward.name, reward.category))

	-- Tutorial progress hook
	task.spawn(function()
		local okTut, TutorialService = pcall(function()
			return require(script.Parent.TutorialService)
		end)
		if okTut and TutorialService then
			TutorialService.onBoxOpened(player, boxId)
		end
	end)

	return true, {
		boxId = boxId,
		box = boxDef,
		reward = reward,
		remainingCount = remaining,
	}
end

function LootBoxService.addLootBox(player: Player, boxId: string, amount: number?)
	DataService.addLootBox(player, boxId, amount)
end

function LootBoxService.init()
	local openRemote = Remotes.getFunction("OpenLootBox")
	openRemote.OnServerInvoke = function(player: Player, boxId: string)
		local ok, result = LootBoxService.openBox(player, boxId)
		if ok then
			return true, result
		else
			return false, result
		end
	end

	local devRemote = Remotes.getFunction("DevAddLootBoxes")
	devRemote.OnServerInvoke = function(player: Player)
		for _, bId in ipairs(LootBoxConfig.ORDERED_IDS) do
			DataService.addLootBox(player, bId, 5)
		end
		return true, "Added 5 of each crate variety to inventory!"
	end

	print("📦 [LootBoxService] Initialized successfully!")
end

return LootBoxService
