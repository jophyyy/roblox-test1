--!strict
local DataService = require(script.Services.DataService)
local PetService = require(script.Services.PetService)
local RebirthService = require(script.Services.RebirthService)
local MapService = require(script.Services.MapService)
local MarketplaceServiceHandler = require(script.Services.MarketplaceServiceHandler)

print("⛏️ [Mining Simulator] Initializing Server Services...")

MarketplaceServiceHandler.init()
MapService.init()
DataService.init()
PetService.init()
RebirthService.init()

print("✅ [Mining Simulator] Server Services Successfully Initialized!")

