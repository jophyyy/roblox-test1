--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local TycoonClient = {}

-- Verified pleasant audio assets
local SOUNDS = {
	Purchase = "rbxassetid://131886985",   -- Classic Tycoon Cash Register "Cha-Ching!"
	Collect = "rbxassetid://6895079853",    -- Clean, crisp coin collect chime
	Rebirth = "rbxassetid://5153737200",    -- Grand victory / level-up fanfare
}

local function playSound(soundId: string, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.45
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
		-- Classic pleasant cash register chime
		playSound(SOUNDS.Purchase, 0.45, 1.0)
	end)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent.OnClientEvent:Connect(function(playerName: string, rebirthCount: number, bonusGems: number)
		-- Grand victory fanfare
		playSound(SOUNDS.Rebirth, 0.7, 1.0)
	end)

	local crystalEvent = Remotes.getEvent("CrystalCollected")
	crystalEvent.OnClientEvent:Connect(function()
		-- Subtle pleasant coin chime with slight pitch variation
		local randomPitch = 1.0 + (math.random() * 0.15)
		playSound(SOUNDS.Collect, 0.35, randomPitch)
	end)
end

return TycoonClient
