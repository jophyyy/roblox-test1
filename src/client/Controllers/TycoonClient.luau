--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local TycoonClient = {}

local function playSound(soundId: string, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1.0
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function TycoonClient.init()
	local buyEvent = Remotes.getEvent("ItemPurchased")
	buyEvent.OnClientEvent:Connect(function(itemName: string, cost: number)
		-- Play cheerful purchase chime (standard Roblox asset ID)
		playSound("rbxassetid://9069609200", 0.7, 1.1)
	end)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent.OnClientEvent:Connect(function(playerName: string, rebirthCount: number, bonusGems: number)
		-- Grand fan-fare sound
		playSound("rbxassetid://9069609538", 1.0, 1.0)
	end)

	local crystalEvent = Remotes.getEvent("CrystalCollected")
	crystalEvent.OnClientEvent:Connect(function()
		-- Subtle crystal chime with randomized pitch for pleasant earfeel
		local randomPitch = 0.95 + (math.random() * 0.2)
		playSound("rbxassetid://9069609200", 0.4, randomPitch)
	end)
end

return TycoonClient
