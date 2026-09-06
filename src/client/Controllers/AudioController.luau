--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local AudioController = {}

-- Verified pleasant audio assets
local SOUNDS = {
	Purchase = "rbxassetid://131886985",   -- Classic Cash Register "Cha-Ching!"
	Collect = "rbxassetid://6895079853",    -- Clean, crisp coin collect chime
	Rebirth = "rbxassetid://5153737200",    -- Grand victory / level-up fanfare
	BGM = "rbxassetid://1843404009",        -- Iconic upbeat simulator acoustic instrumental ("Happy Song")
	MineHit = "rbxassetid://9114223170",    -- Satisfying pickaxe stone impact
	OreBreak = "rbxassetid://9114223849",   -- Crystal/gem shatter
}

local bgmSound: Sound? = nil
local isMusicPlaying = true

function AudioController.playSound(soundId: string, volume: number?, pitch: number?)
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

function AudioController.toggleMusic(): boolean
	if bgmSound then
		if isMusicPlaying then
			bgmSound.Volume = 0
			isMusicPlaying = false
		else
			bgmSound.Volume = 0.22
			isMusicPlaying = true
		end
	end
	return isMusicPlaying
end

function AudioController.isMusicEnabled(): boolean
	return isMusicPlaying
end

function AudioController.init()
	-- Background Simulator Instrumental Track
	local bgm = Instance.new("Sound")
	bgm.Name = "SimulatorBGM"
	bgm.SoundId = SOUNDS.BGM
	bgm.Volume = 0.22
	bgm.Looped = true
	bgm.Parent = SoundService
	bgm:Play()
	bgmSound = bgm

	local buyEvent = Remotes.getEvent("ItemPurchased")
	buyEvent.OnClientEvent:Connect(function()
		AudioController.playSound(SOUNDS.Purchase, 0.45, 1.0)
	end)

	local rebirthEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthEvent.OnClientEvent:Connect(function()
		AudioController.playSound(SOUNDS.Rebirth, 0.7, 1.0)
	end)

	local crystalEvent = Remotes.getEvent("CrystalCollected")
	crystalEvent.OnClientEvent:Connect(function()
		local randomPitch = 1.0 + (math.random() * 0.15)
		AudioController.playSound(SOUNDS.Collect, 0.35, randomPitch)
	end)
end

return AudioController
