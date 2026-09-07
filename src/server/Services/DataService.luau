--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local DATA_STORE_NAME = "MiningSave_v1"
local AUTOSAVE_INTERVAL = 60

export type PlayerData = {
	Cash: number,
	Power: number,
	Gems: number,
	Rebirths: number,
	UnlockedItems: { [string]: boolean },
	OwnedPets: { [string]: number }, -- petId -> count
	EquippedPets: { [string]: boolean },
	OwnedShovels: { [string]: boolean },
	EquippedShovel: string?,
	OwnedBackpacks: { [string]: boolean },
	EquippedBackpack: string?,
	OwnedTrails: { [string]: boolean },
	EquippedTrail: string?,
	UnlockedSkills: { [string]: boolean },
	LastWheelSpin: number?,
	FreeSpins: number?,
	LastSaved: number,
}

local DataService = {}
local playerDataCache: { [Player]: PlayerData } = {}
local isDataStoreAvailable = true

local store: DataStore? = nil
local success, result = pcall(function()
	return DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

if success and result then
	store = result
else
	warn("[DataService] DataStoreService unavailable or restricted. Operating in memory-only mode.")
	isDataStoreAvailable = false
end

local function getDefaultData(): PlayerData
	return {
		Cash = GameConfig.STARTER_CASH,
		Power = GameConfig.STARTER_POWER,
		Gems = GameConfig.STARTER_GEMS,
		Rebirths = 0,
		UnlockedItems = {},
		OwnedPets = {},
		EquippedPets = {},
		OwnedShovels = { ["shovel_rusty"] = true },
		EquippedShovel = "shovel_rusty",
		OwnedBackpacks = { ["pack_canvas"] = true },
		EquippedBackpack = "pack_canvas",
		OwnedTrails = {},
		EquippedTrail = nil,
		UnlockedSkills = {},
		LastWheelSpin = 0,
		FreeSpins = 1,
		LastSaved = os.time(),
	}
end

local function setupLeaderstats(player: Player, data: PlayerData)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cashVal = leaderstats:FindFirstChild("Cash") or Instance.new("NumberValue")
	cashVal.Name = "Cash"
	cashVal.Value = data.Cash
	cashVal.Parent = leaderstats

	local powerVal = leaderstats:FindFirstChild("Power") or Instance.new("NumberValue")
	powerVal.Name = "Power"
	powerVal.Value = data.Power or GameConfig.STARTER_POWER
	powerVal.Parent = leaderstats

	local rebirthsVal = leaderstats:FindFirstChild("Rebirths") or Instance.new("IntValue")
	rebirthsVal.Name = "Rebirths"
	rebirthsVal.Value = data.Rebirths
	rebirthsVal.Parent = leaderstats

	local gemsVal = leaderstats:FindFirstChild("Gems") or Instance.new("NumberValue")
	gemsVal.Name = "Gems"
	gemsVal.Value = data.Gems
	gemsVal.Parent = leaderstats
end

local function syncToClient(player: Player, data: PlayerData)
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent:FireClient(player, data)
end

function DataService.get(player: Player): PlayerData?
	return playerDataCache[player]
end

function DataService.addCash(player: Player, amount: number)
	local data = playerDataCache[player]
	if not data then return end

	data.Cash = math.max(0, data.Cash + amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cashVal = leaderstats:FindFirstChild("Cash") :: NumberValue?
		if cashVal then cashVal.Value = data.Cash end
	end
	syncToClient(player, data)
end

function DataService.addGems(player: Player, amount: number)
	local data = playerDataCache[player]
	if not data then return end

	local finalAmount = amount
	if amount > 0 then
		local ok, MarketplaceServiceHandler = pcall(function()
			return require(script.Parent.MarketplaceServiceHandler)
		end)
		if ok and MarketplaceServiceHandler and MarketplaceServiceHandler.isVIP(player) then
			finalAmount = amount * 2
		end
	end

	data.Gems = math.max(0, data.Gems + finalAmount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end
	syncToClient(player, data)
end

function DataService.addPower(player: Player, amount: number)
	local data = playerDataCache[player]
	if not data then return end

	data.Power = math.max(0, (data.Power or GameConfig.STARTER_POWER) + amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local powerVal = leaderstats:FindFirstChild("Power") :: NumberValue?
		if powerVal then powerVal.Value = data.Power end
	end
	syncToClient(player, data)
end

function DataService.calculateClickPowerGain(player: Player): (number, number, number)
	local data = playerDataCache[player]
	if not data then return 1, 0, 0 end

	local toolMultiplier = 1.0
	local clickCash = 0
	local clickGems = 0

	if data.EquippedShovel then
		local toolDef = ShopConfig.getShovel(data.EquippedShovel)
		if toolDef then
			toolMultiplier = toolDef.powerMultiplier or 1.0
			clickCash = toolDef.clickCash or 0
			clickGems = toolDef.clickGems or 0
		end
	end

	local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths or 0)
	local trailMult = TrailConfig.getCashMultiplier(data.EquippedTrail)
	local skillPowerMult = SkillTreeConfig.getTotalMiningPowerMult(data.UnlockedSkills)

	-- Pet Multiplier (lazy require PetService to prevent circular dependency)
	local petMult = 1.0
	local ok, PetService = pcall(function()
		return require(script.Parent.PetService)
	end)
	if ok and PetService and PetService.getCashMultiplier then
		petMult = PetService.getCashMultiplier(player)
	end

	local powerGain = math.max(1, math.floor(1 * toolMultiplier * rebirthMult * trailMult * skillPowerMult * petMult))
	return powerGain, clickCash, clickGems
end

function DataService.unlockItem(player: Player, itemId: string)
	local data = playerDataCache[player]
	if not data then return end

	data.UnlockedItems[itemId] = true
	syncToClient(player, data)
end

function DataService.save(player: Player): boolean
	local data = playerDataCache[player]
	if not data or not store or not isDataStoreAvailable then
		return false
	end

	data.LastSaved = os.time()
	local key = "Player_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if not ok then
		warn("[DataService] Error saving data for " .. player.Name .. ": " .. tostring(err))
		return false
	end

	return true
end

function DataService.load(player: Player)
	local key = "Player_" .. player.UserId
	local data: PlayerData? = nil

	if store and isDataStoreAvailable then
		local ok, saved = pcall(function()
			return store:GetAsync(key)
		end)
		if ok and type(saved) == "table" then
			data = saved :: PlayerData
		elseif not ok and string.find(tostring(saved), "StudioAccessToApisNotAllowed") then
			isDataStoreAvailable = false
			print("ℹ️ [DataService] Studio API access is disabled. Running with local in-memory session data.")
		end
	end

	if not data then
		data = getDefaultData()
	end

	-- Ensure table fields exist
	data.UnlockedItems = data.UnlockedItems or {}
	data.OwnedPets = data.OwnedPets or {}
	data.EquippedPets = data.EquippedPets or {}
	data.OwnedShovels = data.OwnedShovels or { ["shovel_rusty"] = true }
	data.EquippedShovel = data.EquippedShovel or "shovel_rusty"
	data.OwnedBackpacks = data.OwnedBackpacks or { ["pack_canvas"] = true }
	data.EquippedBackpack = data.EquippedBackpack or "pack_canvas"
	data.OwnedTrails = data.OwnedTrails or {}
	data.EquippedTrail = data.EquippedTrail or nil
	data.UnlockedSkills = data.UnlockedSkills or {}
	data.LastWheelSpin = data.LastWheelSpin or 0
	data.FreeSpins = data.FreeSpins or 1
	data.Power = data.Power or GameConfig.STARTER_POWER

	playerDataCache[player] = data
	setupLeaderstats(player, data)
	syncToClient(player, data)
end

function DataService.buyShopItem(player: Player, category: string, itemId: string): (boolean, string)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	if category == "Shovel" then
		local shovelDef = ShopConfig.getShovel(itemId)
		if not shovelDef then return false, "Item not found" end
		if data.OwnedShovels[itemId] then return false, "Already owned!" end
		if data.Cash < shovelDef.cost then return false, "Not enough Cash!" end

		DataService.addCash(player, -shovelDef.cost)
		data.OwnedShovels[itemId] = true
		data.EquippedShovel = itemId
		syncToClient(player, data)
		print(string.format("🛒 [Shop] %s purchased Shovel: %s", player.Name, shovelDef.name))
		return true, "Successfully purchased " .. shovelDef.name .. "!"
	elseif category == "Backpack" then
		local packDef = ShopConfig.getBackpack(itemId)
		if not packDef then return false, "Item not found" end
		if data.OwnedBackpacks[itemId] then return false, "Already owned!" end
		if data.Cash < packDef.cost then return false, "Not enough Cash!" end

		DataService.addCash(player, -packDef.cost)
		data.OwnedBackpacks[itemId] = true
		data.EquippedBackpack = itemId
		syncToClient(player, data)
		print(string.format("🛒 [Shop] %s purchased Backpack: %s", player.Name, packDef.name))
		return true, "Successfully purchased " .. packDef.name .. "!"
	end

	return false, "Unknown category"
end

function DataService.equipShopItem(player: Player, category: string, itemId: string): (boolean, string)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	if category == "Shovel" then
		if not data.OwnedShovels[itemId] then return false, "Item not owned!" end
		data.EquippedShovel = itemId
		syncToClient(player, data)
		return true, "Equipped Shovel!"
	elseif category == "Backpack" then
		if not data.OwnedBackpacks[itemId] then return false, "Item not owned!" end
		data.EquippedBackpack = itemId
		syncToClient(player, data)
		return true, "Equipped Backpack!"
	end

	return false, "Unknown category"
end

function DataService.spinWheel(player: Player, spinMode: string?): { success: boolean, sliceIndex: number?, slice: any?, rewardDisplay: string?, message: string?, nextSpinTime: number? }
	local data = playerDataCache[player]
	if not data then
		return { success = false, message = "No player data found." }
	end

	local now = os.time()
	local lastSpin = data.LastWheelSpin or 0
	local elapsed = now - lastSpin
	local hasFreeSpin = (data.FreeSpins and data.FreeSpins > 0) or (elapsed >= WheelConfig.COOLDOWN_SECONDS)

	if spinMode == "Test" then
		-- Instant developer test spin: bypass cooldown and costs
	elseif spinMode == "Gems" then
		if data.Gems < WheelConfig.GEM_SPIN_COST then
			return { success = false, message = "Not enough Gems to spin! Need " .. WheelConfig.GEM_SPIN_COST .. " Gems." }
		end
		DataService.addGems(player, -WheelConfig.GEM_SPIN_COST)
	else
		-- Free spin mode
		if not hasFreeSpin then
			local remaining = math.max(1, WheelConfig.COOLDOWN_SECONDS - elapsed)
			return { success = false, message = string.format("Free spin ready in %ds!", remaining) }
		end

		if data.FreeSpins and data.FreeSpins > 0 then
			data.FreeSpins -= 1
		end
	end

	data.LastWheelSpin = now

	-- Roll slice
	local slice, sliceIndex = WheelConfig.rollSlice()
	local rewardDisplay = ""

	if slice.rewardType == "Cash" then
		local amount = slice.value :: number
		DataService.addCash(player, amount)
		rewardDisplay = "+$" .. tostring(amount) .. " Cash"
	elseif slice.rewardType == "GemsFlat" then
		local amount = slice.value :: number
		DataService.addGems(player, amount)
		rewardDisplay = "+" .. tostring(amount) .. " Gems"
	elseif slice.rewardType == "GemsPercent" then
		local pct = slice.value.percent
		local minGems = slice.value.min
		local granted = math.max(minGems, math.floor(data.Gems * pct))
		DataService.addGems(player, granted)
		rewardDisplay = string.format("+%d Gems (+%d%%)", granted, math.floor(pct * 100))
	elseif slice.rewardType == "Pet" then
		local petId = slice.value :: string
		data.OwnedPets[petId] = (data.OwnedPets[petId] or 0) + 1
		rewardDisplay = "Pet: " .. slice.name
	elseif slice.rewardType == "Jackpot" then
		local bonusGems = math.max(slice.value.minGems, data.Gems)
		DataService.addGems(player, bonusGems)
		local petId = slice.value.petId
		data.OwnedPets[petId] = (data.OwnedPets[petId] or 0) + 1
		rewardDisplay = string.format("JACKPOT! +%d Gems and %s", bonusGems, petId)
	end

	syncToClient(player, data)
	print(string.format("[Wheel] %s spun slice %d (%s) -> %s", player.Name, sliceIndex, slice.name, rewardDisplay))

	return {
		success = true,
		sliceIndex = sliceIndex,
		slice = slice,
		rewardDisplay = rewardDisplay,
		nextSpinTime = data.LastWheelSpin + WheelConfig.COOLDOWN_SECONDS,
	}
end

function DataService.buyTrail(player: Player, trailId: string): (boolean, string?)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
	local trailDef = TrailConfig.getTrail(trailId)
	if not trailDef then return false, "Invalid trail" end

	if data.OwnedTrails and data.OwnedTrails[trailId] then
		return false, "Already owned!"
	end

	if data.Gems < trailDef.cost then
		return false, "Not enough Gems! (Need " .. tostring(trailDef.cost) .. " 💎)"
	end

	data.Gems -= trailDef.cost
	data.OwnedTrails = data.OwnedTrails or {}
	data.OwnedTrails[trailId] = true
	data.EquippedTrail = trailId -- Auto-equip newly purchased trail

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end

	syncToClient(player, data)

	local TrailService = require(script.Parent.TrailService)
	TrailService.updatePlayerTrail(player)

	print(string.format("✨ [DataService] %s purchased and equipped trail: %s", player.Name, trailDef.name))
	return true, nil
end

function DataService.equipTrail(player: Player, trailId: string): (boolean, string?)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
	local trailDef = TrailConfig.getTrail(trailId)
	if not trailDef then return false, "Invalid trail" end

	if not data.OwnedTrails or not data.OwnedTrails[trailId] then
		return false, "Trail not owned"
	end

	data.EquippedTrail = trailId
	syncToClient(player, data)

	local TrailService = require(script.Parent.TrailService)
	TrailService.updatePlayerTrail(player)

	print(string.format("✨ [DataService] %s equipped trail: %s", player.Name, trailDef.name))
	return true, nil
end

function DataService.unequipTrail(player: Player): (boolean, string?)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	data.EquippedTrail = nil
	syncToClient(player, data)

	local TrailService = require(script.Parent.TrailService)
	TrailService.updatePlayerTrail(player)

	print(string.format("✨ [DataService] %s unequipped trail", player.Name))
	return true, nil
end

function DataService.unlockSkillNode(player: Player, nodeId: string): (boolean, string?)
	local data = playerDataCache[player]
	if not data then return false, "No player data" end

	local SkillTreeConfig = require(ReplicatedStorage.Shared.Config.SkillTreeConfig)
	local node = SkillTreeConfig.getNode(nodeId)
	if not node then return false, "Invalid skill node" end

	data.UnlockedSkills = data.UnlockedSkills or {}
	if data.UnlockedSkills[nodeId] then
		return false, "Talent already mastered!"
	end

	if not SkillTreeConfig.canUnlock(nodeId, data.UnlockedSkills) then
		return false, "Prerequisite talent not yet unlocked!"
	end

	if (data.Gems or 0) < node.cost then
		return false, "Not enough Gems!"
	end

	-- Deduct gems and mark unlocked
	DataService.addGems(player, -node.cost)
	data.UnlockedSkills[nodeId] = true
	syncToClient(player, data)

	-- Update character walkspeed if speed talent
	if node.speedBonus > 0 then
		local ok, TrailService = pcall(function()
			return require(script.Parent.TrailService)
		end)
		if ok and TrailService then
			TrailService.updatePlayerTrail(player)
		end
	end

	print(string.format("🌳 [DataService] %s unlocked talent: %s (%s)", player.Name, node.name, nodeId))
	return true, nil
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		DataService.load(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			DataService.load(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		playerDataCache[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.save(player)
		end
	end)

	-- Request full data remote function
	local getDataFn = Remotes.getFunction("GetPlayerData")
	getDataFn.OnServerInvoke = function(player: Player)
		return playerDataCache[player] or getDefaultData()
	end

	-- Shop item purchase and equip remotes
	local buyFn = Remotes.getFunction("BuyShopItem")
	buyFn.OnServerInvoke = function(player: Player, category: string, itemId: string)
		return DataService.buyShopItem(player, category, itemId)
	end

	local equipFn = Remotes.getFunction("EquipShopItem")
	equipFn.OnServerInvoke = function(player: Player, category: string, itemId: string)
		return DataService.equipShopItem(player, category, itemId)
	end

	local spinFn = Remotes.getFunction("SpinWheel")
	spinFn.OnServerInvoke = function(player: Player, spinMode: string?)
		return DataService.spinWheel(player, spinMode)
	end

	-- Trail management remotes
	local buyTrailFn = Remotes.getFunction("BuyTrail")
	buyTrailFn.OnServerInvoke = function(player: Player, trailId: string)
		return DataService.buyTrail(player, trailId)
	end

	local equipTrailFn = Remotes.getFunction("EquipTrail")
	equipTrailFn.OnServerInvoke = function(player: Player, trailId: string)
		return DataService.equipTrail(player, trailId)
	end

	local unequipTrailFn = Remotes.getFunction("UnequipTrail")
	unequipTrailFn.OnServerInvoke = function(player: Player)
		return DataService.unequipTrail(player)
	end

	local unlockSkillFn = Remotes.getFunction("UnlockSkillNode")
	unlockSkillFn.OnServerInvoke = function(player: Player, nodeId: string)
		return DataService.unlockSkillNode(player, nodeId)
	end

	-- Click / Train Power remote
	local clickPowerFn = Remotes.getFunction("ClickPower")
	clickPowerFn.OnServerInvoke = function(player: Player)
		local data = playerDataCache[player]
		if not data then return false, 0, 0, 0 end

		local powerGain, clickCash, clickGems = DataService.calculateClickPowerGain(player)
		DataService.addPower(player, powerGain)
		if clickCash > 0 then
			DataService.addCash(player, clickCash)
		end
		if clickGems > 0 then
			DataService.addGems(player, clickGems)
		end

		return true, powerGain, clickCash, clickGems
	end

	-- Dev testing cheat remote (+$10,000,000 Cash, +50,000 Gems, +25,000 Power)
	local devRemote = Remotes.getFunction("DevAddCash")
	devRemote.OnServerInvoke = function(player: Player)
		local addCash = 10_000_000
		local addGems = 50_000
		local addPower = 25_000
		DataService.addCash(player, addCash)
		DataService.addGems(player, addGems)
		DataService.addPower(player, addPower)
		print(string.format("⚡ [Dev] Granted $%d, %d Gems, and %d Power to %s for testing!", addCash, addGems, addPower, player.Name))
		return true, addCash, addGems
	end

	-- Periodic auto-save loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				DataService.save(player)
			end
		end
	end)
end

return DataService
