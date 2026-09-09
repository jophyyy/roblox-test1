--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MasteryConfig = require(ReplicatedStorage.Shared.Config.MasteryConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local DataService = require(script.Parent.DataService)

local MasteryService = {}

-- Returns current total XP for a specific track
function MasteryService.getMasteryXP(player: Player, trackId: string): number
	local data = DataService.get(player)
	if not data or not data.Mastery then return 0 end
	return data.Mastery[trackId] or 0
end

-- Returns current Level (1 to 50) for a specific track
function MasteryService.getMasteryLevel(player: Player, trackId: string): number
	local totalXp = MasteryService.getMasteryXP(player, trackId)
	local level, _, _, _ = MasteryConfig.getLevelFromXp(totalXp)
	return level
end

-- Awards Mastery XP and triggers level-up celebration when crossing level boundaries
function MasteryService.addXP(player: Player, trackId: string, amount: number)
	if not MasteryConfig.TRACKS[trackId] then return end
	if amount <= 0 then return end

	local data = DataService.get(player)
	if not data then return end

	data.Mastery = data.Mastery or {
		Eggs = 0,
		BossSlayer = 0,
		Mining = 0,
		PetFusion = 0,
		Rebirth = 0,
	}

	local oldXp = data.Mastery[trackId] or 0
	local oldLevel, _, _, _ = MasteryConfig.getLevelFromXp(oldXp)

	local maxCumulative = MasteryConfig.getCumulativeXp(MasteryConfig.MAX_LEVEL + 1)
	local newXp = math.clamp(oldXp + amount, 0, maxCumulative)
	data.Mastery[trackId] = newXp

	local newLevel, _, _, _ = MasteryConfig.getLevelFromXp(newXp)

	-- Sync updated data to client
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)

	-- Handle Level Up(s)
	if newLevel > oldLevel then
		local trackDef = MasteryConfig.TRACKS[trackId]
		local milestone = trackDef.milestones[newLevel]

		print(string.format("🌟 [MasteryService] %s leveled up %s to LVL %d!", player.Name, trackDef.name, newLevel))

		local levelUpEvent = Remotes.getEvent("MasteryLevelUp")
		levelUpEvent:FireClient(player, trackId, newLevel, milestone)
	end
end

-- ====================================================================
-- ACTIVE MULTIPLIER GETTERS
-- ====================================================================

function MasteryService.getBossDamageMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "BossSlayer")
	local boosts = MasteryConfig.getTrackBoosts("BossSlayer", lvl)
	return boosts.bossDamageMultiplier
end

function MasteryService.getBossRewardsMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "BossSlayer")
	local boosts = MasteryConfig.getTrackBoosts("BossSlayer", lvl)
	return boosts.bossRewardsMultiplier
end

function MasteryService.getBossCritChanceBonus(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "BossSlayer")
	local boosts = MasteryConfig.getTrackBoosts("BossSlayer", lvl)
	return boosts.bossCritChanceBonus
end

function MasteryService.getMiningPowerMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Mining")
	local boosts = MasteryConfig.getTrackBoosts("Mining", lvl)
	return boosts.miningPowerMultiplier
end

function MasteryService.getGemOreBonusMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Mining")
	local boosts = MasteryConfig.getTrackBoosts("Mining", lvl)
	return boosts.gemOreBonusMultiplier
end

function MasteryService.getDoubleStrikeChance(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Mining")
	local boosts = MasteryConfig.getTrackBoosts("Mining", lvl)
	return boosts.doubleStrikeChance
end

function MasteryService.getCashOreMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Mining")
	local boosts = MasteryConfig.getTrackBoosts("Mining", lvl)
	return boosts.cashOreMultiplier
end

function MasteryService.getLuckyEggBonus(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Eggs")
	local boosts = MasteryConfig.getTrackBoosts("Eggs", lvl)
	return boosts.luckyEggBonus
end

function MasteryService.getEggCostDiscount(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Eggs")
	local boosts = MasteryConfig.getTrackBoosts("Eggs", lvl)
	return boosts.eggCostDiscount
end

-- Returns additional equipped pet capacity unlocked via Mastery (Eggs Lvl 50 +1, PetFusion Lvl 35 +1)
function MasteryService.getExtraEquippedSlots(player: Player): number
	local eggLvl = MasteryService.getMasteryLevel(player, "Eggs")
	local fusionLvl = MasteryService.getMasteryLevel(player, "PetFusion")

	local extra = 0
	local eggBoosts = MasteryConfig.getTrackBoosts("Eggs", eggLvl)
	local fusionBoosts = MasteryConfig.getTrackBoosts("PetFusion", fusionLvl)

	extra += eggBoosts.extraPetSlots
	extra += fusionBoosts.extraPetSlots
	return extra
end

function MasteryService.getPetStatsMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "PetFusion")
	local boosts = MasteryConfig.getTrackBoosts("PetFusion", lvl)
	return boosts.petStatsMultiplier
end

function MasteryService.getCashPetMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "PetFusion")
	local boosts = MasteryConfig.getTrackBoosts("PetFusion", lvl)
	return boosts.cashPetMultiplier
end

function MasteryService.getRainbowPetExtraMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "PetFusion")
	local boosts = MasteryConfig.getTrackBoosts("PetFusion", lvl)
	return boosts.rainbowPetExtraMultiplier
end

function MasteryService.getRebirthCostDiscount(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Rebirth")
	local boosts = MasteryConfig.getTrackBoosts("Rebirth", lvl)
	return boosts.rebirthCostDiscount
end

function MasteryService.getRebirthGlobalMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Rebirth")
	local boosts = MasteryConfig.getTrackBoosts("Rebirth", lvl)
	return boosts.rebirthGlobalMultiplier
end

function MasteryService.getCashMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Rebirth")
	local boosts = MasteryConfig.getTrackBoosts("Rebirth", lvl)
	return boosts.globalCashMultiplier
end

function MasteryService.getGemMultiplier(player: Player): number
	local lvl = MasteryService.getMasteryLevel(player, "Rebirth")
	local boosts = MasteryConfig.getTrackBoosts("Rebirth", lvl)
	return boosts.globalGemMultiplier
end

function MasteryService.init()
	-- Remote Function: Dev cheat to add Mastery XP for testing
	local devMasteryRemote = Remotes.getFunction("DevAddMasteryXP")
	devMasteryRemote.OnServerInvoke = function(player: Player, trackId: string, amount: number?)
		local count = if typeof(amount) == "number" and amount > 0 then math.floor(amount) else 1000
		MasteryService.addXP(player, trackId, count)
		return true, MasteryService.getMasteryLevel(player, trackId)
	end

	print("📜 [MasteryService] Initialized! 5 Mastery Tracks Active.")
end

return MasteryService
