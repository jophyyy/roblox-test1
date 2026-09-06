--!strict
local UIController = require(script.Controllers.UIController)
local TycoonClient = require(script.Controllers.TycoonClient)
local PetClient = require(script.Controllers.PetClient)
local SprintClient = require(script.Controllers.SprintClient)
local PetHatchAnimation = require(script.Controllers.PetHatchAnimation)

print("💎 [Crystal Tycoon] Initializing Client Controllers...")

UIController.init()
TycoonClient.init()
PetClient.init()
SprintClient.init()
PetHatchAnimation.init()

print("✅ [Crystal Tycoon] Client Ready!")
