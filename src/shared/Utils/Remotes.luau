--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}
local remotesFolder: Folder

local REGISTERED_EVENTS = {
	"SyncPlayerData",
	"CrystalCollected",
	"ItemPurchased",
	"PlayerRebirthed",
	"OpenShopDialogue",
	"EggHatched",
	"OpenRobuxPurchaseModal",
	"OpenVIPModal",
	"VIPStatusChanged",
	"OreDamaged",
	"OreDestroyed",
	"BossDamaged",
	"BossAttacking",
	"BossTelegraphSlam",
	"BossMeteorEvent",
	"BossDefeated",
	"BossRespawned",
	"TrainingOreHit",
	"OpenFusionModal",
	"MasteryLevelUp",
	"LootBoxDropped",
	"MeteorEventAnnounced",
	"MeteorCrashed",
	"MeteorDamaged",
	"MeteorDestroyed",
	"MeteorTimerSync",
	"TutorialProgressSync",
	"TutorialStepCompleted",
}

local REGISTERED_FUNCTIONS = {
	"GetPlayerData",
	"ManualHarvest",
	"RequestRebirth",
	"RequestBuyItem",
	"HatchEgg",
	"ToggleEquipPet",
	"DevAddCash",
	"DevAddRebirth",
	"DevAddMasteryXP",
	"BuyShopItem",
	"EquipShopItem",
	"SpinWheel",
	"RequestRobuxEggAction",
	"RequestGamepassAction",
	"MineOre",
	"AttackBoss",
	"BuyTrail",
	"EquipTrail",
	"UnequipTrail",
	"UnlockSkillNode",
	"ClickPower",
	"TrainOnOre",
	"ClaimIndexMilestone",
	"FusePets",
	"OpenLootBox",
	"DevAddLootBoxes",
	"HitMeteor",
	"DevTriggerMeteor",
	"GetMeteorStatus",
	"SkipTutorial",
	"DevTeleportToShowroom",
}

local function getRemotesFolder(): Folder
	if remotesFolder then
		return remotesFolder
	end

	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("GameRemotes")
		if not existing then
			local folder = Instance.new("Folder")
			folder.Name = "GameRemotes"
			folder.Parent = ReplicatedStorage
			remotesFolder = folder
		else
			remotesFolder = existing :: Folder
		end

		-- Pre-populate all events and functions so client never encounters a missing remote
		for _, eventName in ipairs(REGISTERED_EVENTS) do
			if not remotesFolder:FindFirstChild(eventName) then
				local ev = Instance.new("RemoteEvent")
				ev.Name = eventName
				ev.Parent = remotesFolder
			end
		end

		for _, fnName in ipairs(REGISTERED_FUNCTIONS) do
			if not remotesFolder:FindFirstChild(fnName) then
				local fn = Instance.new("RemoteFunction")
				fn.Name = fnName
				fn.Parent = remotesFolder
			end
		end
	else
		remotesFolder = (ReplicatedStorage:WaitForChild("GameRemotes", 15) or ReplicatedStorage:FindFirstChild("GameRemotes")) :: Folder
		if not remotesFolder then
			warn("[Remotes] Warning: GameRemotes folder not found yet, retrying...")
			remotesFolder = ReplicatedStorage:WaitForChild("GameRemotes") :: Folder
		end
	end

	return remotesFolder
end

-- Initialize immediately when required on server
if RunService:IsServer() then
	getRemotesFolder()
end

function Remotes.getEvent(name: string): RemoteEvent
	local folder = getRemotesFolder()
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		end
		return remote :: RemoteEvent
	else
		local found = folder:FindFirstChild(name) or folder:WaitForChild(name, 10)
		if not found then
			error("[Remotes] RemoteEvent '" .. name .. "' was not found in GameRemotes!")
		end
		return found :: RemoteEvent
	end
end

function Remotes.getFunction(name: string): RemoteFunction
	local folder = getRemotesFolder()
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			local newRemote = Instance.new("RemoteFunction")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		end
		return remote :: RemoteFunction
	else
		local found = folder:FindFirstChild(name) or folder:WaitForChild(name, 10)
		if not found then
			error("[Remotes] RemoteFunction '" .. name .. "' was not found in GameRemotes!")
		end
		return found :: RemoteFunction
	end
end

return Remotes

