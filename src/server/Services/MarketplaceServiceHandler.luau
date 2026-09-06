--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetService = require(script.Parent.PetService)

local MarketplaceServiceHandler = {}

-- Track processed purchase IDs in memory to avoid duplicate fulfillments within a session
local processedPurchases: { [string]: boolean } = {}

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

	-- 1. Check if this is the 1,000 Robux Exclusive Egg
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

-- Triggers the purchase flow for the 1,000 Robux Egg
function MarketplaceServiceHandler.handleRobuxEggPurchase(player: Player)
	local eggDef = PetConfig.EGGS.RobuxEgg
	if not eggDef then return end

	local productId = eggDef.productId or 0
	if productId == 0 then
		-- =========================================================================
		-- DEV / STUDIO TEST FALLBACK:
		-- Since no live Developer Product has been published in the Creator Dashboard yet,
		-- we simulate the purchase directly so you can test hatching the 1,000 Robux Egg!
		-- =========================================================================
		print("💎 [Marketplace] Test Mode: Hatching 1,000 Robux Egg for " .. player.Name)
		local ok, petIds, err = PetService.hatchEgg(player, "RobuxEgg", 1)
		if not ok then
			warn("⚠️ [Marketplace] Test Robux Egg hatch failed: " .. tostring(err))
		end
	else
		-- LIVE PRODUCTION: Prompt the native Roblox Robux purchase dialog
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("⚠️ [Marketplace] Failed to prompt product purchase: " .. tostring(err))
		end
	end
end

function MarketplaceServiceHandler.init()
	-- Register receipt processor
	MarketplaceService.ProcessReceipt = MarketplaceServiceHandler.processReceipt
	print("✅ [MarketplaceServiceHandler] ProcessReceipt registered!")
end

return MarketplaceServiceHandler
