--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
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

	playerDataCache[player] = data
	setupLeaderstats(player, data)
	syncToClient(player, data)
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
