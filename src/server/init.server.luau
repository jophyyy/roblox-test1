--!strict
local DataService = require(script.Services.DataService)
local PetService = require(script.Services.PetService)
local RebirthService = require(script.Services.RebirthService)
local MapService = require(script.Services.MapService)
local MarketplaceServiceHandler = require(script.Services.MarketplaceServiceHandler)
local MiningService = require(script.Services.MiningService)
local BossService = require(script.Services.BossService)
local TrailService = require(script.Services.TrailService)
local PickaxeService = require(script.Services.PickaxeService)
local MasteryService = require(script.Services.MasteryService)
local LootBoxService = require(script.Services.LootBoxService)
local MeteorService = require(script.Services.MeteorService)

print("⛏️ [Mining Simulator] Initializing Server Services...")

local services = {
	{ name = "MarketplaceServiceHandler", fn = MarketplaceServiceHandler.init },
	{ name = "MapService", fn = MapService.init },
	{ name = "DataService", fn = DataService.init },
	{ name = "MasteryService", fn = MasteryService.init },
	{ name = "PetService", fn = PetService.init },
	{ name = "RebirthService", fn = RebirthService.init },
	{ name = "MiningService", fn = MiningService.init },
	{ name = "BossService", fn = BossService.init },
	{ name = "TrailService", fn = TrailService.init },
	{ name = "PickaxeService", fn = PickaxeService.init },
	{ name = "LootBoxService", fn = LootBoxService.init },
	{ name = "MeteorService", fn = MeteorService.init },
}

for _, s in ipairs(services) do
	local ok, err = pcall(s.fn)
	if ok then
		print(string.format("  ✓ [%s] Initialized", s.name))
	else
		warn(string.format("  ❌ [%s] Init failed: %s", s.name, tostring(err)))
	end
end

print("✅ [Mining Simulator] Server Services Successfully Initialized!")

