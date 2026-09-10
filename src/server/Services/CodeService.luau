--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local CodeConfig = require(ReplicatedStorage.Shared.Config.CodeConfig)
local MasteryConfig = require(ReplicatedStorage.Shared.Config.MasteryConfig)
local DataService = require(script.Parent.DataService)
local LootBoxService = require(script.Parent.LootBoxService)
local MasteryService = require(script.Parent.MasteryService)
local PetService = require(script.Parent.PetService)

local CodeService = {}

function CodeService.redeemCode(player: Player, rawCode: string): (boolean, string, any?, any?)
	if typeof(rawCode) ~= "string" or string.len(rawCode) == 0 then
		return false, "Please enter a code."
	end

	local codeDef = CodeConfig.getCode(rawCode)
	if not codeDef then
		return false, "Invalid code! Check spelling and try again."
	end

	local data = DataService.get(player)
	if not data then
		return false, "Player data not loaded. Please wait a moment."
	end

	if DataService.isCodeRedeemed(player, codeDef.code) then
		return false, "Code already redeemed!"
	end

	local reward = codeDef.reward

	-- 1. Disburse Cash Reward
	if reward.cash and reward.cash > 0 then
		DataService.addCash(player, reward.cash)
	end

	-- 2. Disburse Gems Reward
	if reward.gems and reward.gems > 0 then
		DataService.addGems(player, reward.gems)
	end

	-- 3. Disburse Power Reward
	if reward.power and reward.power > 0 then
		DataService.addPower(player, reward.power)
	end

	-- 4. Disburse Free Wheel Spins
	if reward.freeSpins and reward.freeSpins > 0 then
		data.FreeSpins = (data.FreeSpins or 0) + reward.freeSpins
	end

	-- 5. Disburse Crates / LootBoxes
	if reward.lootBoxes then
		for boxId, count in reward.lootBoxes do
			if count > 0 then
				LootBoxService.addLootBox(player, boxId, count)
			end
		end
	end

	-- 6. Disburse Mastery XP across all tracks
	if reward.masteryXP and reward.masteryXP > 0 then
		for _, trackId in ipairs(MasteryConfig.TRACK_ORDER) do
			pcall(function()
				MasteryService.addXP(player, trackId, reward.masteryXP)
			end)
		end
	end

	-- 7. Disburse Bonus Pet
	if reward.petId then
		DataService.addPet(player, reward.petId)
	end

	-- 8. Mark Code as Redeemed & Sync Data
	DataService.markCodeRedeemed(player, codeDef.code)

	print(string.format("🎟️ [CodeService] %s successfully redeemed code [%s] (%s)", player.Name, codeDef.code, codeDef.rewardSummary))
	return true, "Successfully redeemed " .. codeDef.code .. "!", codeDef.title, reward
end

function CodeService.init()
	print("🎟️ [CodeService] Initializing Promo Codes Service...")

	-- 1. Bind RemoteFunction for Client UI
	local redeemFn = Remotes.getFunction("RedeemCode")
	redeemFn.OnServerInvoke = function(player: Player, rawCode: any)
		if typeof(rawCode) ~= "string" then
			return false, "Invalid code format."
		end
		return CodeService.redeemCode(player, rawCode)
	end

	-- 2. Support Chat Commands: /code <CODE> or /redeem <CODE>
	local function hookPlayerChat(player: Player)
		player.Chatted:Connect(function(msg: string)
			local lower = string.lower(msg)
			if string.sub(lower, 1, 6) == "/code " then
				local entered = string.sub(msg, 7)
				CodeService.redeemCode(player, entered)
			elseif string.sub(lower, 1, 8) == "/redeem " then
				local entered = string.sub(msg, 9)
				CodeService.redeemCode(player, entered)
			end
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayerChat(p)
	end
	Players.PlayerAdded:Connect(hookPlayerChat)

	print("✅ [CodeService] Promo Codes System Online!")
end

return CodeService
