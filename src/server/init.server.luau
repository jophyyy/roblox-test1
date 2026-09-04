--!strict
local DataService = require(script.Services.DataService)
local PetService = require(script.Services.PetService)
local RebirthService = require(script.Services.RebirthService)
local TycoonService = require(script.Services.TycoonService)

print("💎 [Crystal Tycoon] Initializing Server Services...")

DataService.init()
PetService.init()
RebirthService.init()
TycoonService.init()

print("✅ [Crystal Tycoon] Server Services Successfully Initialized!")
