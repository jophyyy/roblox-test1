--!strict
local UIController = require(script.Controllers.UIController)
local AudioController = require(script.Controllers.AudioController)
local PetClient = require(script.Controllers.PetClient)
local SprintClient = require(script.Controllers.SprintClient)
local PetHatchAnimation = require(script.Controllers.PetHatchAnimation)
local MiningClient = require(script.Controllers.MiningClient)
local ZoneClient = require(script.Controllers.ZoneClient)
local BossClient = require(script.Controllers.BossClient)
local MeteorClient = require(script.Controllers.MeteorClient)

print("⛏️ [Mining Simulator] Initializing Client Controllers...")

UIController.init()
AudioController.init()
PetClient.init()
SprintClient.init()
PetHatchAnimation.init()
MiningClient.init()
ZoneClient.init()
BossClient.init()
MeteorClient.init()

print("✅ [Mining Simulator] Client Ready!")
