--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local GamepassConfig = require(ReplicatedStorage.Shared.Config.GamepassConfig)
local PetService = require(script.Parent.PetService)

local MarketplaceServiceHandler = {}

-- Track processed purchase IDs in memory to avoid duplicate fulfillments within a session
local processedPurchases: { [string]: boolean } = {}

-- In-memory cache of VIP status per player
local playerVipStatus: { [Player]: boolean } = {}

-- Returns true if the player has active VIP benefits (Gamepass or Dev Test mode)
function MarketplaceServiceHandler.isVIP(player: Player): boolean
	return playerVipStatus[player] == true
end

-- Server callback: Called by Roblox whenever a player successfully purchases any Developer Product
function MarketplaceServiceHandler.processReceipt(receiptInfo: {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	PlaceIdWherePurchased: number,
}): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	if processedPurchases[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left before receipt could be processed; Roblox will retry next time they join
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local robuxEggDef = PetConfig.EGGS.RobuxEgg

	-- 1. Check if this is the 1,000 Robux Exclusive Egg Developer Product
	if robuxEggDef and robuxEggDef.productId and productId == robuxEggDef.productId then
		print("💎 [Marketplace] Robux Egg purchase verified for " .. player.Name .. " (Product ID: " .. productId .. ")")
		local ok, petIds, err = PetService.hatchEgg(player, "RobuxEgg", 1)
		if ok then
			processedPurchases[purchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			warn("⚠️ [Marketplace] Failed to grant Robux Egg for " .. player.Name .. ": " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	warn("⚠️ [Marketplace] Unhandled ProductId: " .. tostring(productId))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Checks if a player owns the VIP Gamepass on Roblox's backend
function MarketplaceServiceHandler.checkGamePassOwnership(player: Player)
	local vipDef = GamepassConfig.PASSES.VIP
	if not vipDef or vipDef.passId == 0 then
		return
	end

	task.spawn(function()
		local ok, ownsPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipDef.passId)
		end)

		if ok and ownsPass then
			playerVipStatus[player] = true
			print("👑 [Marketplace] " .. player.Name .. " owns VIP Gamepass!")
			local vipEvent = Remotes.getEvent("VIPStatusChanged")
			vipEvent:FireClient(player, true)
		end
	end)
end

function MarketplaceServiceHandler.init()
	-- 1. Register Developer Product receipt processor
	MarketplaceService.ProcessReceipt = MarketplaceServiceHandler.processReceipt
	print("✅ [MarketplaceServiceHandler] ProcessReceipt registered!")

	-- 2. Check Gamepass ownership when players join
	Players.PlayerAdded:Connect(function(player)
		MarketplaceServiceHandler.checkGamePassOwnership(player)
	end)

	for _, p in Players:GetPlayers() do
		MarketplaceServiceHandler.checkGamePassOwnership(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerVipStatus[player] = nil
	end)

	-- 3. Listen for Gamepass purchases completed in-game
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local vipDef = GamepassConfig.PASSES.VIP
		if wasPurchased and vipDef and passId == vipDef.passId then
			playerVipStatus[player] = true
			print("👑 [Marketplace] " .. player.Name .. " just purchased the VIP Gamepass!")
			local vipEvent = Remotes.getEvent("VIPStatusChanged")
			vipEvent:FireClient(player, true)
		end
	end)

	-- 4. Handle Client Requests for Robux Egg (Prompt Purchase vs Dev Test Hatch)
	local eggActionFn = Remotes.getFunction("RequestRobuxEggAction")
	eggActionFn.OnServerInvoke = function(player: Player, action: string)
		local eggDef = PetConfig.EGGS.RobuxEgg
		if not eggDef then
			return { success = false, message = "Robux Egg not found in config!" }
		end

		if action == "PromptPurchase" then
			local productId = eggDef.productId or 0
			if productId > 0 then
				local ok, err = pcall(function()
					MarketplaceService:PromptProductPurchase(player, productId)
				end)
				if ok then
					return { success = true, prompted = true, productId = productId }
				else
					return { success = false, message = "Failed to prompt purchase: " .. tostring(err) }
				end
			else
				return {
					success = false,
					reason = "NO_PRODUCT_ID",
					productId = 0,
					message = "Developer Product ID is 0. Publish your game and create a 1,000 Robux product in the Creator Hub to enable real Robux transactions!",
				}
			end
		elseif action == "DevTestHatch" then
			print("🧪 [Marketplace] Dev Test Hatch triggered for " .. player.Name)
			local ok, petIds, err = PetService.hatchEgg(player, "RobuxEgg", 1)
			if ok then
				return { success = true, hatched = true }
			else
				return { success = false, message = tostring(err) }
			end
		end

		return { success = false, message = "Invalid action" }
	end

	-- 5. Handle Client Requests for Gamepasses (Prompt Purchase vs Dev Test Toggle)
	local passActionFn = Remotes.getFunction("RequestGamepassAction")
	passActionFn.OnServerInvoke = function(player: Player, action: string, passKey: string?)
		local vipDef = GamepassConfig.PASSES.VIP
		if not vipDef then
			return { success = false, message = "VIP Gamepass not configured" }
		end

		if action == "PromptPass" then
			local passId = vipDef.passId or 0
			if passId > 0 then
				local ok, err = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, passId)
				end)
				if ok then
					return { success = true, prompted = true, passId = passId }
				else
					return { success = false, message = "Failed to prompt Gamepass: " .. tostring(err) }
				end
			else
				return {
					success = false,
					reason = "NO_PASS_ID",
					passId = 0,
					message = "Gamepass ID is 0. Create a Gamepass on the Creator Hub and set passId in GamepassConfig.luau!",
				}
			end
		elseif action == "DevTestToggle" then
			local newStatus = not (playerVipStatus[player] or false)
			playerVipStatus[player] = newStatus
			print("🧪 [Marketplace] Dev Test VIP toggled for " .. player.Name .. ": " .. tostring(newStatus))
			local vipEvent = Remotes.getEvent("VIPStatusChanged")
			vipEvent:FireClient(player, newStatus)
			return { success = true, isVIP = newStatus }
		elseif action == "GetVIPStatus" then
			return { success = true, isVIP = playerVipStatus[player] or false }
		end

		return { success = false, message = "Invalid action" }
	end
end

return MarketplaceServiceHandler
