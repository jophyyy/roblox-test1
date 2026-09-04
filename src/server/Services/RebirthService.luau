--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
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
	data.Cash = TycoonConfig.STARTER_CASH
	data.UnlockedItems = {} -- Reset tycoon unlocks
	
	local bonusGems = RebirthConfig.getRewardGems(data.Rebirths)
	data.Gems += bonusGems

	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsVal = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if rebirthsVal then rebirthsVal.Value = data.Rebirths end

		local cashVal = leaderstats:FindFirstChild("Cash") :: NumberValue?
		if cashVal then cashVal.Value = data.Cash end

		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end

	-- Notify clients and other services
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent:FireAllClients(player.Name, data.Rebirths, bonusGems)

	-- Signal TycoonService to rebuild plot for player
	local TycoonService = require(script.Parent.TycoonService)
	TycoonService.resetPlotForPlayer(player)

	return true
end

function RebirthService.init()
	local rebirthRemote = Remotes.getFunction("RequestRebirth")
	rebirthRemote.OnServerInvoke = function(player: Player)
		return RebirthService.rebirth(player)
	end
end

return RebirthService
