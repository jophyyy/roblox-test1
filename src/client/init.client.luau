--!strict
local UIController = require(script.Controllers.UIController)
local TycoonClient = require(script.Controllers.TycoonClient)
local PetClient = require(script.Controllers.PetClient)

print("💎 [Crystal Tycoon] Initializing Client Controllers...")

UIController.init()
TycoonClient.init()
PetClient.init()

print("✅ [Crystal Tycoon] Client Ready!")
