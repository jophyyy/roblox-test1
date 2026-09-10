--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local DailyRewardService = {}

function DailyRewardService.getStatus(player: Player)
	local week, day, streak, lastClaim = DataService.getDailyRewardData(player)
	local canClaim = DailyRewardConfig.canClaim(lastClaim)
	local timeRemaining = DailyRewardConfig.getTimeRemaining(lastClaim)

	return {
		currentWeek = week,
		currentDay = day,
		streak = streak,
		lastClaimTime = lastClaim,
		canClaim = canClaim,
		timeRemaining = timeRemaining,
	}
end

function DailyRewardService.claimReward(player: Player, isDevBypass: boolean?): (boolean, string, any)
	local week, day, streak, lastClaim = DataService.getDailyRewardData(player)

	if not isDevBypass and not DailyRewardConfig.canClaim(lastClaim) then
		local remaining = DailyRewardConfig.getTimeRemaining(lastClaim)
		return false, string.format("Daily reward on cooldown! Ready in %s.", DailyRewardConfig.formatTimeRemaining(remaining)), nil
	end

	local rewardDef = DailyRewardConfig.getReward(week, day)
	if not rewardDef then
		return false, "No reward configured for current day.", nil
	end

	-- 1. Award Cash
	if rewardDef.cash and rewardDef.cash > 0 then
		DataService.addCash(player, rewardDef.cash)
	end

	-- 2. Award Gems
	if rewardDef.gems and rewardDef.gems > 0 then
		DataService.addGems(player, rewardDef.gems)
	end

	-- 3. Award Power
	if rewardDef.power and rewardDef.power > 0 then
		DataService.addPower(player, rewardDef.power)
	end

	-- 4. Award Free Wheel Spins
	if rewardDef.spins and rewardDef.spins > 0 then
		DataService.addFreeSpins(player, rewardDef.spins)
	end

	-- 5. Award Crates / LootBoxes
	if rewardDef.crates then
		for _, crate in ipairs(rewardDef.crates) do
			DataService.addLootBox(player, crate.boxId, crate.count)
		end
	end

	-- 6. Award Pets
	if rewardDef.pets then
		for _, pet in ipairs(rewardDef.pets) do
			DataService.addPet(player, pet.petId, pet.count)
		end
	end

	-- Advance day and week
	local nextDay = day + 1
	local nextWeek = week
	if nextDay > DailyRewardConfig.DAYS_PER_WEEK then
		nextDay = 1
		nextWeek = week + 1
		if nextWeek > DailyRewardConfig.TOTAL_WEEKS then
			nextWeek = 1 -- Loops back to Week 1 after Week 7
		end
	end

	local newStreak = streak + 1
	local now = os.time()

	DataService.setDailyRewardClaimed(player, nextWeek, nextDay, newStreak, now)

	print(string.format("🎁 [DailyReward] %s claimed Week %d Day %d (%s)! Total streak: %d", player.Name, week, day, rewardDef.title, newStreak))

	return true, string.format("Successfully claimed Week %d Day %d: %s!", week, day, rewardDef.title), rewardDef
end

function DailyRewardService.devAdvanceDay(player: Player): (boolean, string)
	local week, day, streak, lastClaim = DataService.getDailyRewardData(player)

	-- If currently on cooldown, reset cooldown to 0 so the player can claim the pending day
	if not DailyRewardConfig.canClaim(lastClaim) then
		DataService.devResetDailyCooldown(player)
		return true, string.format("⚡ Dev Fast-Forward: Cooldown reset! Week %d Day %d is now ready to claim.", week, day)
	else
		-- If already ready, claim it directly and then reset cooldown so the NEXT day is ready too!
		local success, msg, rewardDef = DailyRewardService.claimReward(player, true)
		if success then
			DataService.devResetDailyCooldown(player)
			local newWeek, newDay = DataService.getDailyRewardData(player)
			return true, string.format("⚡ Claimed Week %d Day %d! Fast-forwarded to Week %d Day %d (Ready to claim)!", week, day, newWeek, newDay)
		end
		return false, "Failed to dev-advance day: " .. tostring(msg)
	end
end

function DailyRewardService.init()
	print("📅 [DailyRewardService] Initializing Daily Reward Service...")

	-- Setup RemoteFunction handlers
	local claimFn = Remotes.getFunction("ClaimDailyReward")
	claimFn.OnServerInvoke = function(player: Player)
		local success, msg, reward = DailyRewardService.claimReward(player, false)
		return success, msg, reward
	end

	local statusFn = Remotes.getFunction("GetDailyRewardStatus")
	statusFn.OnServerInvoke = function(player: Player)
		return DailyRewardService.getStatus(player)
	end

	local devFn = Remotes.getFunction("DevAdvanceDailyReward")
	devFn.OnServerInvoke = function(player: Player)
		return DailyRewardService.devAdvanceDay(player)
	end

	-- Auto-prompt modal on join if claim is available
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if not player or not player.Parent then return end
			local _, _, _, lastClaim = DataService.getDailyRewardData(player)
			if DailyRewardConfig.canClaim(lastClaim) then
				local promptEvent = Remotes.getEvent("PromptDailyRewardModal")
				promptEvent:FireClient(player)
			end
		end)
	end)

	print("✓ [DailyRewardService] Initialized with 7 Weeks / 49 Escalating Rewards")
end

return DailyRewardService
