--!strict
local DataService = require(script.Services.DataService)
local PetService = require(script.Services.PetService)
local RebirthService = require(script.Services.RebirthService)
local TycoonService = require(script.Services.TycoonService)
local MapService = require(script.Services.MapService)
local MarketplaceServiceHandler = require(script.Services.MarketplaceServiceHandler)

print("💎 [Crystal Tycoon] Initializing Server Services...")

MarketplaceServiceHandler.init()
MapService.init()
DataService.init()
PetService.init()
RebirthService.init()
TycoonService.init()

print("✅ [Crystal Tycoon] Server Services Successfully Initialized!")

