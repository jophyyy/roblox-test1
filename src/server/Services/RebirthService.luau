--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)

local RebirthService = {}

function RebirthService.canRebirth(player: Player): (boolean, number)
	local data = DataService.get(player)
	if not data then return false, 0 end

	local cost = RebirthConfig.getCostForRebirth(data.Rebirths)
	return (data.Cash >= cost), cost
end

function RebirthService.rebirth(player: Player): boolean
	local data = DataService.get(player)
	if not data then return false end

	local cost = RebirthConfig.getCostForRebirth(data.Rebirths)
	if data.Cash < cost then
		return false
	end

	-- Execute rebirth
	data.Rebirths += 1
	data.Cash = GameConfig.STARTER_CASH
	data.Power = GameConfig.STARTER_POWER
	
	local bonusGems = RebirthConfig.getRewardGems(data.Rebirths)
	data.Gems += bonusGems

	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsVal = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if rebirthsVal then rebirthsVal.Value = data.Rebirths end

		local cashVal = leaderstats:FindFirstChild("Cash") :: NumberValue?
		if cashVal then cashVal.Value = data.Cash end

		local powerVal = leaderstats:FindFirstChild("Power") :: NumberValue?
		if powerVal then powerVal.Value = data.Power end

		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end

	-- Notify clients and other services
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent:FireAllClients(player.Name, data.Rebirths, bonusGems)

	return true
end

-- Developer cheat method to grant rebirths instantly without wiping cash/power
function RebirthService.devAddRebirth(player: Player, amount: number?): (boolean, number)
	local data = DataService.get(player)
	if not data then return false, 0 end

	local count = if typeof(amount) == "number" and amount > 0 then math.floor(amount) else 1
	data.Rebirths += count

	local bonusGems = RebirthConfig.getRewardGems(data.Rebirths) * count
	data.Gems += bonusGems

	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsVal = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if rebirthsVal then rebirthsVal.Value = data.Rebirths end

		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end

	-- Notify clients and other services
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent:FireAllClients(player.Name, data.Rebirths, bonusGems)

	print(string.format("⚡ [Dev] Granted +%d Rebirth(s) to %s! (Total: %d)", count, player.Name, data.Rebirths))
	return true, data.Rebirths
end

function RebirthService.init()
	local rebirthRemote = Remotes.getFunction("RequestRebirth")
	rebirthRemote.OnServerInvoke = function(player: Player)
		return RebirthService.rebirth(player)
	end

	local devRebirthRemote = Remotes.getFunction("DevAddRebirth")
	devRebirthRemote.OnServerInvoke = function(player: Player, amount: number?)
		return RebirthService.devAddRebirth(player, amount)
	end
end

return RebirthService
