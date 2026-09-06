--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local DATA_STORE_NAME = "TycoonSave_v1"
local AUTOSAVE_INTERVAL = 60

export type PlayerData = {
	Cash: number,
	Gems: number,
	Rebirths: number,
	UnlockedItems: { [string]: boolean },
	OwnedPets: { [string]: number }, -- petId -> count
	EquippedPets: { [string]: boolean },
	OwnedShovels: { [string]: boolean },
	EquippedShovel: string?,
	OwnedBackpacks: { [string]: boolean },
	EquippedBackpack: string?,
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
		Cash = TycoonConfig.STARTER_CASH,
		Gems = TycoonConfig.STARTER_GEMS,
		Rebirths = 0,
		UnlockedItems = {},
		OwnedPets = {},
		EquippedPets = {},
		OwnedShovels = { ["shovel_rusty"] = true },
		EquippedShovel = "shovel_rusty",
		OwnedBackpacks = { ["pack_canvas"] = true },
		EquippedBackpack = "pack_canvas",
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

	data.Gems = math.max(0, data.Gems + amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gemsVal = leaderstats:FindFirstChild("Gems") :: NumberValue?
		if gemsVal then gemsVal.Value = data.Gems end
	end
	syncToClient(player, data)
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
	data.LastWheelSpin = data.LastWheelSpin or 0
	data.FreeSpins = data.FreeSpins or 1

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
