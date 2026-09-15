--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local DataService = require(script.Parent.DataService)

local QuestService = {}

-- Generates the authentic 3D Quest Scroll tool
function QuestService.createQuestScrollTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "📜 Quest Scroll"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click to open your Adventure Quest Journal"
	tool:SetAttribute("IsQuestTool", true)

	-- Handle Part (Rolled Cream Parchment)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.55, 1.4, 0.55)
	handle.Color = Color3.fromRGB(246, 238, 218)
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Anchored = false
	handle.Massless = true

	local cylMesh = Instance.new("CylinderMesh")
	cylMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	cylMesh.Parent = handle

	-- Wooden Dowel Caps (Top & Bottom Mahogany Knobs)
	for _, yOffset in ipairs({ -0.75, 0.75 }) do
		local cap = Instance.new("Part")
		cap.Name = "DowelCap"
		cap.Size = Vector3.new(0.65, 0.2, 0.65)
		cap.Color = Color3.fromRGB(85, 48, 25)
		cap.Material = Enum.Material.Wood
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth
		cap.CanCollide = false
		cap.Anchored = false
		cap.Massless = true
		cap.CFrame = handle.CFrame * CFrame.new(0, yOffset, 0)

		local capMesh = Instance.new("CylinderMesh")
		capMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
		capMesh.Parent = cap

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = cap
		weld.Parent = cap
		cap.Parent = tool
	end

	-- Crimson Velvet Ribbon Band
	local ribbon = Instance.new("Part")
	ribbon.Name = "RibbonBand"
	ribbon.Size = Vector3.new(0.58, 0.28, 0.58)
	ribbon.Color = Color3.fromRGB(180, 32, 45)
	ribbon.Material = Enum.Material.Fabric
	ribbon.TopSurface = Enum.SurfaceType.Smooth
	ribbon.BottomSurface = Enum.SurfaceType.Smooth
	ribbon.CanCollide = false
	ribbon.Anchored = false
	ribbon.Massless = true
	ribbon.CFrame = handle.CFrame

	local ribMesh = Instance.new("CylinderMesh")
	ribMesh.Scale = Vector3.new(1.0, 1.0, 1.0)
	ribMesh.Parent = ribbon

	local rWeld = Instance.new("WeldConstraint")
	rWeld.Part0 = handle
	rWeld.Part1 = ribbon
	rWeld.Parent = ribbon
	ribbon.Parent = tool

	-- Golden Wax Seal
	local seal = Instance.new("Part")
	seal.Name = "WaxSeal"
	seal.Size = Vector3.new(0.28, 0.28, 0.15)
	seal.Color = Color3.fromRGB(245, 195, 45)
	seal.Material = Enum.Material.SmoothPlastic
	seal.CanCollide = false
	seal.Anchored = false
	seal.Massless = true
	seal.CFrame = handle.CFrame * CFrame.new(0, 0, -0.32)

	local sMesh = Instance.new("SpecialMesh")
	sMesh.MeshType = Enum.MeshType.Sphere
	sMesh.Parent = seal

	local sWeld = Instance.new("WeldConstraint")
	sWeld.Part0 = handle
	sWeld.Part1 = seal
	sWeld.Parent = seal
	seal.Parent = tool

	-- Gentle golden light radiance
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 120)
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = handle

	-- Grip CFrame so the scroll is held comfortably horizontally/diagonally in hand
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	handle.Parent = tool

	return tool
end

-- Grants the Quest Scroll tool to player backpack and startergear
function QuestService.ensurePlayerHasQuestTool(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character

	local alreadyHasInBackpack = backpack and backpack:FindFirstChild("📜 Quest Scroll") ~= nil
	local alreadyHasInChar = char and char:FindFirstChild("📜 Quest Scroll") ~= nil

	if not alreadyHasInBackpack and not alreadyHasInChar then
		local tool = QuestService.createQuestScrollTool()

		-- When player clicks while holding the scroll, open the Quest Journal
		tool.Activated:Connect(function()
			local openEvent = Remotes.getEvent("OpenQuestModal")
			openEvent:FireClient(player)
		end)

		if backpack then
			tool.Parent = backpack
		end

		-- Also clone to StarterGear so it automatically equips across respawns
		local starterGear = player:FindFirstChild("StarterGear")
		if starterGear and not starterGear:FindFirstChild("📜 Quest Scroll") then
			local sgTool = tool:Clone()
			sgTool.Activated:Connect(function()
				local openEvent = Remotes.getEvent("OpenQuestModal")
				openEvent:FireClient(player)
			end)
			sgTool.Parent = starterGear
		end
	end
end

-- Retrieves full quest payload for UI
function QuestService.getQuestPayload(player: Player): { activeQuests: { any }, boardQuests: { any } }
	local data = DataService.get(player)
	if not data then
		return { activeQuests = {}, boardQuests = {} }
	end

	data.Quests = data.Quests or {}
	local activeQuests = {}
	local activeMap = {}

	for questId, qProgress in pairs(data.Quests) do
		local def = QuestConfig.getQuest(questId)
		if def then
			activeMap[questId] = true
			table.insert(activeQuests, {
				id = def.id,
				title = def.title,
				description = def.description,
				category = def.category,
				targetType = def.targetType,
				targetCount = def.targetCount,
				progress = qProgress.progress or 0,
				completed = qProgress.completed or false,
				claimed = qProgress.claimed or false,
				icon = def.icon,
				badge = def.badge,
				rewards = def.rewards,
				order = def.order,
			})
		end
	end

	table.sort(activeQuests, function(a, b)
		if a.completed ~= b.completed then
			return a.completed and not b.completed
		end
		return (a.order or 0) < (b.order or 0)
	end)

	-- Board Quests: All available Daily Bounties and unlocked Main Quests not yet accepted
	local boardQuests = {}
	for _, def in ipairs(QuestConfig.getAllQuests()) do
		if not activeMap[def.id] then
			table.insert(boardQuests, {
				id = def.id,
				title = def.title,
				description = def.description,
				category = def.category,
				targetType = def.targetType,
				targetCount = def.targetCount,
				icon = def.icon,
				badge = def.badge,
				rewards = def.rewards,
				order = def.order,
			})
		end
	end

	table.sort(boardQuests, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)

	return {
		activeQuests = activeQuests,
		boardQuests = boardQuests,
	}
end

-- Accepts a quest from the board into the player's active quest journal
function QuestService.acceptQuest(player: Player, questId: string): (boolean, string)
	local data = DataService.get(player)
	if not data then return false, "Player data not loaded" end

	local def = QuestConfig.getQuest(questId)
	if not def then return false, "Invalid quest ID" end

	data.Quests = data.Quests or {}
	if data.Quests[questId] and not data.Quests[questId].claimed then
		return false, "Quest already accepted!"
	end

	data.Quests[questId] = {
		progress = 0,
		completed = false,
		claimed = false,
		acceptedAt = os.time(),
	}

	print(string.format("📜 [QuestService] %s accepted quest: %s (%s)", player.Name, def.title, def.id))

	local syncEvt = Remotes.getEvent("QuestProgressUpdated")
	syncEvt:FireClient(player, {
		questId = def.id,
		title = def.title,
		status = "Accepted",
		progress = 0,
		target = def.targetCount,
		icon = def.icon,
	})

	return true, string.format("Accepted '%s'!", def.title)
end

-- Claims rewards for a completed quest
function QuestService.claimReward(player: Player, questId: string): (boolean, string, any)
	local data = DataService.get(player)
	if not data then return false, "Player data not loaded", nil end

	local qProgress = data.Quests and data.Quests[questId]
	if not qProgress then return false, "Quest not active", nil end
	if not qProgress.completed then return false, "Quest not completed yet!", nil end
	if qProgress.claimed then return false, "Reward already claimed!", nil end

	local def = QuestConfig.getQuest(questId)
	if not def then return false, "Unknown quest", nil end

	qProgress.claimed = true

	-- Grant Rewards
	if def.rewards.Cash and def.rewards.Cash > 0 then
		data.Cash = (data.Cash or 0) + def.rewards.Cash
	end
	if def.rewards.Gems and def.rewards.Gems > 0 then
		data.Gems = (data.Gems or 0) + def.rewards.Gems
	end
	if def.rewards.Crates then
		data.LootBoxes = data.LootBoxes or {}
		for crateId, count in pairs(def.rewards.Crates) do
			data.LootBoxes[crateId] = (data.LootBoxes[crateId] or 0) + count
		end
	end
	if def.rewards.MasteryXP then
		local MasteryService = nil
		local okM, resM = pcall(function() return require(script.Parent.MasteryService) end)
		if okM and resM then
			resM.addXP(player, def.rewards.MasteryXP.track, def.rewards.MasteryXP.amount)
		end
	end

	-- Auto-unlock next main quest if applicable
	if def.category == "Main" then
		for _, nextDef in ipairs(QuestConfig.MAIN_QUESTS) do
			if nextDef.order == def.order + 1 and not data.Quests[nextDef.id] then
				data.Quests[nextDef.id] = {
					progress = 0,
					completed = false,
					claimed = false,
					acceptedAt = os.time(),
				}
				print(string.format("📜 [QuestService] Auto-accepted next main quest for %s: %s", player.Name, nextDef.title))
				break
			end
		end
	end

	print(string.format("🎉 [QuestService] %s claimed reward for quest: %s!", player.Name, def.title))

	local syncEvt = Remotes.getEvent("QuestProgressUpdated")
	syncEvt:FireClient(player, {
		questId = def.id,
		title = def.title,
		status = "Claimed",
		rewards = def.rewards,
		icon = def.icon,
	})

	return true, string.format("Claimed rewards for '%s'!", def.title), def.rewards
end

-- Centralized progress increment handler
function QuestService.updateProgress(player: Player, targetType: QuestConfig.QuestTargetType, amount: number?)
	local data = DataService.get(player)
	if not data or not data.Quests then return end

	local inc = amount or 1

	for questId, qProgress in pairs(data.Quests) do
		if not qProgress.completed and not qProgress.claimed then
			local def = QuestConfig.getQuest(questId)
			if def and def.targetType == targetType then
				qProgress.progress = math.min(def.targetCount, (qProgress.progress or 0) + inc)
				if qProgress.progress >= def.targetCount then
					qProgress.completed = true
					print(string.format("⭐ [QuestService] %s COMPLETED quest: %s!", player.Name, def.title))

					local syncEvt = Remotes.getEvent("QuestProgressUpdated")
					syncEvt:FireClient(player, {
						questId = def.id,
						title = def.title,
						status = "Completed",
						progress = def.targetCount,
						target = def.targetCount,
						icon = def.icon,
					})
				else
					local syncEvt = Remotes.getEvent("QuestProgressUpdated")
					syncEvt:FireClient(player, {
						questId = def.id,
						title = def.title,
						status = "Progress",
						progress = qProgress.progress,
						target = def.targetCount,
						icon = def.icon,
					})
				end
			end
		end
	end
end

-- Specific Event Hooks for other Services
function QuestService.onOreMined(player: Player, oreType: string?, payout: number?)
	QuestService.updateProgress(player, "MineOres", 1)
	if payout and payout > 0 then
		QuestService.updateProgress(player, "EarnCash", payout)
	end
end

function QuestService.onPetHatched(player: Player, count: number?)
	QuestService.updateProgress(player, "HatchPets", count or 1)
end

function QuestService.onPetFused(player: Player)
	QuestService.updateProgress(player, "FusePets", 1)
end

function QuestService.onRebirth(player: Player)
	QuestService.updateProgress(player, "Rebirth", 1)
end

function QuestService.onWheelSpin(player: Player)
	QuestService.updateProgress(player, "SpinWheel", 1)
end

function QuestService.onPetSold(player: Player, count: number?)
	QuestService.updateProgress(player, "SellPets", count or 1)
end

function QuestService.onBossDamaged(player: Player, damage: number)
	QuestService.updateProgress(player, "DefeatBoss", damage)
end

function QuestService.onCashEarned(player: Player, amount: number)
	if amount and amount > 0 then
		QuestService.updateProgress(player, "EarnCash", amount)
	end
end

-- Initialize QuestService
function QuestService.init()
	print("📜 [QuestService] Initializing Quest & Bounty System...")

	-- Setup Remote Functions
	local getFn = Remotes.getFunction("GetQuestData")
	getFn.OnServerInvoke = function(player: Player)
		return QuestService.getQuestPayload(player)
	end

	local acceptFn = Remotes.getFunction("AcceptQuest")
	acceptFn.OnServerInvoke = function(player: Player, questId: any)
		if typeof(questId) ~= "string" then return false, "Invalid ID" end
		return QuestService.acceptQuest(player, questId)
	end

	local claimFn = Remotes.getFunction("ClaimQuestReward")
	claimFn.OnServerInvoke = function(player: Player, questId: any)
		if typeof(questId) ~= "string" then return false, "Invalid ID" end
		return QuestService.claimReward(player, questId)
	end

	-- Ensure Remote Events exist
	Remotes.getEvent("OpenQuestModal")
	Remotes.getEvent("QuestProgressUpdated")

	-- Listen for player spawn to give Quest Scroll Tool
	local function onPlayerReady(player: Player)
		QuestService.ensurePlayerHasQuestTool(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			QuestService.ensurePlayerHasQuestTool(player)
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerReady, p)
	end
	Players.PlayerAdded:Connect(onPlayerReady)

	print("✅ [QuestService] Quest System & Tools Online!")
end

return QuestService
