--!strict
local DataService = require(script.Services.DataService)
local PetService = require(script.Services.PetService)
local RebirthService = require(script.Services.RebirthService)
local MapService = require(script.Services.MapService)
local MarketplaceServiceHandler = require(script.Services.MarketplaceServiceHandler)
local MiningService = require(script.Services.MiningService)
local BossService = require(script.Services.BossService)

print("⛏️ [Mining Simulator] Initializing Server Services...")

MarketplaceServiceHandler.init()
MapService.init()
DataService.init()
PetService.init()
RebirthService.init()
MiningService.init()
BossService.init()

print("✅ [Mining Simulator] Server Services Successfully Initialized!")

