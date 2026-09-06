--!strict
local UIController = require(script.Controllers.UIController)
local AudioController = require(script.Controllers.AudioController)
local PetClient = require(script.Controllers.PetClient)
local SprintClient = require(script.Controllers.SprintClient)
local PetHatchAnimation = require(script.Controllers.PetHatchAnimation)
local MiningClient = require(script.Controllers.MiningClient)

print("⛏️ [Mining Simulator] Initializing Client Controllers...")

UIController.init()
AudioController.init()
PetClient.init()
SprintClient.init()
PetHatchAnimation.init()
MiningClient.init()

print("✅ [Mining Simulator] Client Ready!")
