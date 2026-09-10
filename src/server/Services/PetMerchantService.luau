--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetMerchantConfig = require(ReplicatedStorage.Shared.Config.PetMerchantConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local DataService = require(script.Parent.DataService)

local PetMerchantService = {}

local currentMultiplier: number = 1.00
local cycleTimeRemaining: number = PetMerchantConfig.CYCLE_DURATION
local perPetMultipliers: { [string]: number } = {}
local cachedBillboard: BillboardGui? = nil

local function getBillboard(): BillboardGui?
	if cachedBillboard and cachedBillboard.Parent then
		return cachedBillboard
	end
	local found = Workspace:FindFirstChild("FinneasBillboard", true)
	if found and found:IsA("BillboardGui") then
		cachedBillboard = found
		return cachedBillboard
	end
	return nil
end

function PetMerchantService.getState()
	local mood = PetMerchantConfig.getMood(currentMultiplier)
	return {
		currentMultiplier = currentMultiplier,
		cycleTimeRemaining = cycleTimeRemaining,
		mood = mood,
		perPetMultipliers = perPetMultipliers,
	}
end

function PetMerchantService.rollNewMarket()
	-- Weighted random distribution to simulate lively stock market swings
	local roll = math.random()
	local mult = 1.0

	if roll < 0.20 then
		-- 20% chance: Lowball crash (0.50x to 0.95x)
		mult = 0.50 + math.random() * 0.45
	elseif roll < 0.55 then
		-- 35% chance: Fair to good (1.00x to 1.75x)
		mult = 1.00 + math.random() * 0.75
	elseif roll < 0.80 then
		-- 25% chance: Pet craze boom (1.80x to 3.20x)
		mult = 1.80 + math.random() * 1.40
	elseif roll < 0.94 then
		-- 14% chance: Mega buyout surge (3.25x to 4.50x)
		mult = 3.25 + math.random() * 1.25
	else
		-- 6% chance: GOD-TIER 5X JACKPOT (4.50x to 5.00x)
		mult = 4.50 + math.random() * 0.50
	end

	currentMultiplier = math.floor(mult * 100 + 0.5) / 100
	cycleTimeRemaining = PetMerchantConfig.CYCLE_DURATION

	-- Generate individual pet price variations (±8% around currentMultiplier)
	perPetMultipliers = {}
	for petId, _ in pairs(PetConfig.PETS) do
		local variation = (math.random(-8, 8)) / 100
		local petMult = math.clamp(currentMultiplier * (1 + variation), PetMerchantConfig.MIN_MULTIPLIER, PetMerchantConfig.MAX_MULTIPLIER)
		perPetMultipliers[petId] = math.floor(petMult * 100 + 0.5) / 100
	end

	local mood = PetMerchantConfig.getMood(currentMultiplier)
	print(string.format("🐾 [PetMerchantService] Finneas changed his mind! Rate: %.2fx (%s)", currentMultiplier, mood.name))

	-- Update in-world billboard
	local bb = getBillboard()
	if bb then
		local rateLbl = bb:FindFirstChild("RateLabel") :: TextLabel?
		if rateLbl then
			rateLbl.Text = string.format("Market: %s %.2fx", mood.badge, currentMultiplier)
			rateLbl.TextColor3 = mood.color
		end
		local timerLbl = bb:FindFirstChild("TimerLabel") :: TextLabel?
		if timerLbl then
			timerLbl.Text = string.format("🧠 Mind changes in: %ds", cycleTimeRemaining)
		end
	end

	-- Broadcast new prices to all clients
	local syncEvent = Remotes.getEvent("PetMerchantPriceSync")
	syncEvent:FireAllClients(PetMerchantService.getState())
end

function PetMerchantService.sellPet(player: Player, petId: string, count: number?): (boolean, string, number)
	local data = DataService.get(player)
	if not data then return false, "Player data not loaded", 0 end

	local ownedCount = data.OwnedPets and data.OwnedPets[petId] or 0
	local isEquipped = data.EquippedPets and data.EquippedPets[petId] == true
	local equippedCount = if isEquipped then 1 else 0
	local unusedCount = math.max(0, ownedCount - equippedCount)

	local toSell = math.min(unusedCount, math.max(1, count or 1))
	if toSell <= 0 then
		return false, "No unused pets of this type available to sell! (Unequip first)", 0
	end

	local petMult = perPetMultipliers[petId] or currentMultiplier
	local unitPrice = PetMerchantConfig.calculatePrice(petId, petMult)
	local totalPayout = unitPrice * toSell

	local petDef = PetConfig.PETS[petId]
	local petName = if petDef then petDef.name else petId

	-- Deduct owned count
	local newOwned = ownedCount - toSell
	if newOwned <= 0 then
		data.OwnedPets[petId] = nil
	else
		data.OwnedPets[petId] = newOwned
	end

	-- Award cash
	DataService.addCash(player, totalPayout)

	print(string.format("🐾 [PetMerchantService] %s sold %dx %s for $%d (Multiplier: %.2fx)", player.Name, toSell, petName, totalPayout, petMult))

	return true, string.format("Sold %dx %s for $%s! (+%.2fx)", toSell, petName, FormatNumber.formatCompact(totalPayout), petMult), totalPayout
end

function PetMerchantService.sellAllUnusedPets(player: Player): (boolean, string, number)
	local data = DataService.get(player)
	if not data or not data.OwnedPets then return false, "No pets owned", 0 end

	local totalPayout = 0
	local totalCount = 0

	for petId, ownedCount in pairs(data.OwnedPets) do
		local isEquipped = data.EquippedPets and data.EquippedPets[petId] == true
		local equippedCount = if isEquipped then 1 else 0
		local unused = math.max(0, ownedCount - equippedCount)

		if unused > 0 then
			local petMult = perPetMultipliers[petId] or currentMultiplier
			local unitPrice = PetMerchantConfig.calculatePrice(petId, petMult)
			totalPayout += unitPrice * unused
			totalCount += unused

			if equippedCount > 0 then
				data.OwnedPets[petId] = equippedCount
			else
				data.OwnedPets[petId] = nil
			end
		end
	end

	if totalCount <= 0 then
		return false, "No unused pets available to sell! (All your pets are equipped or none owned)", 0
	end

	DataService.addCash(player, totalPayout)

	print(string.format("🐾 [PetMerchantService] %s sold ALL %d unused pets for $%d!", player.Name, totalCount, totalPayout))

	return true, string.format("Sold all %d unused pets for a whopping $%s!", totalCount, FormatNumber.formatCompact(totalPayout)), totalPayout
end

function PetMerchantService.devForceMindChange(player: Player): (boolean, string)
	PetMerchantService.rollNewMarket()
	local mood = PetMerchantConfig.getMood(currentMultiplier)
	return true, string.format("⚡ Finneas's mind changed! New Market: %.2fx (%s)", currentMultiplier, mood.name)
end

function PetMerchantService.init()
	print("🐾 [PetMerchantService] Initializing Pet Sell Merchant Service...")

	-- Setup remote handlers
	local sellFn = Remotes.getFunction("SellPet")
	sellFn.OnServerInvoke = function(player: Player, petId: string, count: number?)
		return PetMerchantService.sellPet(player, petId, count)
	end

	local sellAllFn = Remotes.getFunction("SellAllUnusedPets")
	sellAllFn.OnServerInvoke = function(player: Player)
		return PetMerchantService.sellAllUnusedPets(player)
	end

	local stateFn = Remotes.getFunction("GetPetMerchantState")
	stateFn.OnServerInvoke = function(player: Player)
		return PetMerchantService.getState()
	end

	local devFn = Remotes.getFunction("DevForceMerchantMindChange")
	devFn.OnServerInvoke = function(player: Player)
		return PetMerchantService.devForceMindChange(player)
	end

	-- Initial roll
	PetMerchantService.rollNewMarket()

	-- 1-second countdown ticker
	task.spawn(function()
		while true do
			task.wait(1)
			cycleTimeRemaining -= 1

			local bb = getBillboard()
			if bb then
				local timerLbl = bb:FindFirstChild("TimerLabel") :: TextLabel?
				if timerLbl then
					timerLbl.Text = string.format("🧠 Mind changes in: %ds", math.max(0, cycleTimeRemaining))
				end
			end

			if cycleTimeRemaining <= 0 then
				PetMerchantService.rollNewMarket()
			end
		end
	end)

	print("✓ [PetMerchantService] Initialized with fluctuating 'Mind Changes' economy (0.50x to 5.00x)")
end

return PetMerchantService
