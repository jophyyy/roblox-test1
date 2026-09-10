--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local DataService = require(script.Parent.DataService)

type LeaderboardCategory = LeaderboardConfig.LeaderboardCategory
type LeaderboardEntry = LeaderboardConfig.LeaderboardEntry

local LeaderboardService = {}

local MONUMENT_CENTER = Vector3.new(0, 0, -32)
local UPDATE_INTERVAL = 25

-- In-world SurfaceGui references for each category board
local boardGuiContainers: { [LeaderboardCategory]: Frame } = {}

-- Utility to create anchored, non-colliding or colliding decorative parts
local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = if canCollide ~= nil then canCollide else false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- =========================================================================
-- RANKING COMPUTATION & DATA RETRIEVAL
-- =========================================================================

-- Retrieves sorted rankings for a given category (combining online players & mock players for full boards)
function LeaderboardService.getRankings(category: LeaderboardCategory, requestingPlayer: Player?): {
	category: LeaderboardCategory,
	entries: { LeaderboardEntry },
	playerRank: number?,
	playerValue: number?,
}
	local catDef = LeaderboardConfig.CATEGORIES[category]
	if not catDef then
		catDef = LeaderboardConfig.CATEGORIES.Cash
	end

	local pool: { { userId: number, username: string, displayName: string, value: number, isOnline: boolean } } = {}
	local seenUserIds: { [number]: boolean } = {}

	-- 1. Gather all currently online players and their active stats
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.get(p)
		if data then
			local val = 0
			if category == "Cash" then
				val = data.Cash or 0
			elseif category == "Power" then
				val = data.Power or 0
			elseif category == "Rebirths" then
				val = data.Rebirths or 0
			end

			table.insert(pool, {
				userId = p.UserId,
				username = p.Name,
				displayName = p.DisplayName,
				value = val,
				isOnline = true,
			})
			seenUserIds[p.UserId] = true
		end
	end

	-- 2. Populate simulated hall-of-fame entries so leaderboards are vibrant in solo testing
	for _, mock in ipairs(LeaderboardConfig.MOCK_PLAYERS) do
		if not seenUserIds[mock.userId] then
			local val = 0
			if category == "Cash" then
				val = mock.cash
			elseif category == "Power" then
				val = mock.power
			elseif category == "Rebirths" then
				val = mock.rebirths
			end

			table.insert(pool, {
				userId = mock.userId,
				username = mock.username,
				displayName = mock.displayName,
				value = val,
				isOnline = false,
			})
		end
	end

	-- 3. Sort pool descending by stat value
	table.sort(pool, function(a, b)
		if a.value == b.value then
			return a.userId < b.userId
		end
		return a.value > b.value
	end)

	-- 4. Build formatted entries
	local entries: { LeaderboardEntry } = {}
	local playerRank: number? = nil
	local playerValue: number? = nil

	for rank, item in ipairs(pool) do
		local isLocal = requestingPlayer and (item.userId == requestingPlayer.UserId)
		if isLocal then
			playerRank = rank
			playerValue = item.value
		end

		local formatted: string
		if category == "Cash" then
			formatted = "$" .. FormatNumber.formatCompact(item.value)
		elseif category == "Power" then
			formatted = FormatNumber.formatCompact(item.value) .. " ⚡"
		elseif category == "Rebirths" then
			formatted = tostring(item.value) .. " 🔄"
		else
			formatted = tostring(item.value)
		end

		table.insert(entries, {
			rank = rank,
			userId = item.userId,
			username = item.username,
			displayName = item.displayName,
			value = item.value,
			formattedValue = formatted,
			isLocalPlayer = isLocal,
		})
	end

	return {
		category = category,
		entries = entries,
		playerRank = playerRank or (#entries + 1),
		playerValue = playerValue or 0,
	}
end

-- =========================================================================
-- IN-WORLD SURFACEGUI UPDATER
-- =========================================================================

-- Renders up to 10 ranked rows on an in-world SurfaceGui
local function updateBoardSurfaceGui(category: LeaderboardCategory)
	local container = boardGuiContainers[category]
	if not container then return end

	local catDef = LeaderboardConfig.CATEGORIES[category]
	if not catDef then return end

	local res = LeaderboardService.getRankings(category, nil)
	local top10 = res.entries

	-- Clear old rows
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i = 1, math.min(10, #top10) do
		local entry = top10[i]

		local row = Instance.new("Frame")
		row.Name = "Row_" .. i
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = if i == 1 then Color3.fromRGB(48, 42, 24)
			elseif i == 2 then Color3.fromRGB(38, 42, 50)
			elseif i == 3 then Color3.fromRGB(44, 34, 28)
			elseif i % 2 == 0 then Color3.fromRGB(24, 27, 36)
			else Color3.fromRGB(20, 22, 30)
		row.BorderSizePixel = 0
		row.Parent = container

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		if i <= 3 then
			local rowStroke = Instance.new("UIStroke")
			rowStroke.Color = if i == 1 then Color3.fromRGB(255, 215, 0)
				elseif i == 2 then Color3.fromRGB(215, 225, 240)
				else Color3.fromRGB(205, 127, 50)
			rowStroke.Transparency = 0.4
			rowStroke.Thickness = 1.2
			rowStroke.Parent = row
		end

		-- Rank Badge
		local rankBadge = Instance.new("TextLabel")
		rankBadge.Size = UDim2.new(0, 38, 1, 0)
		rankBadge.Position = UDim2.new(0, 4, 0, 0)
		rankBadge.BackgroundTransparency = 1
		rankBadge.Text = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else "#" .. i
		rankBadge.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 0)
			elseif i == 2 then Color3.fromRGB(220, 230, 245)
			elseif i == 3 then Color3.fromRGB(230, 150, 80)
			else Color3.fromRGB(160, 175, 195)
		rankBadge.Font = Enum.Font.GothamBlack
		rankBadge.TextSize = 16
		rankBadge.Parent = row

		-- Player Headshot Avatar
		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(0, 28, 0, 28)
		avatarImg.Position = UDim2.new(0, 44, 0.5, 0)
		avatarImg.AnchorPoint = Vector2.new(0, 0.5)
		avatarImg.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
		avatarImg.BorderSizePixel = 0
		avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", entry.userId)
		avatarImg.Parent = row

		local avCorner = Instance.new("UICorner")
		avCorner.CornerRadius = UDim.new(1, 0)
		avCorner.Parent = avatarImg

		-- Player Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -210, 1, 0)
		nameLbl.Position = UDim2.new(0, 80, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.displayName
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		-- Formatted Value
		local valLbl = Instance.new("TextLabel")
		valLbl.Size = UDim2.new(0, 115, 1, 0)
		valLbl.Position = UDim2.new(1, -125, 0, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = entry.formattedValue
		valLbl.TextColor3 = catDef.color
		valLbl.Font = Enum.Font.GothamBlack
		valLbl.TextSize = 14
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = row
	end
end

-- =========================================================================
-- PHYSICAL IN-WORLD MONUMENT BUILDER
-- =========================================================================
local function buildPhysicalMonument(parentFolder: Folder)
	local monument = Instance.new("Model")
	monument.Name = "LeaderboardMonument"
	monument.Parent = parentFolder

	local center = MONUMENT_CENTER

	-- 1. Grand Slate Foundation Pavement (38 x 1.2 x 24)
	createPart(monument, "PlazaPavement", Vector3.new(42, 0.8, 22), CFrame.new(center + Vector3.new(0, 0.4, 0)), Color3.fromRGB(30, 34, 44), Enum.Material.Slate, true)
	createPart(monument, "PlazaTrim", Vector3.new(42.8, 0.3, 22.8), CFrame.new(center + Vector3.new(0, 0.9, 0)), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, false)

	-- 2. Archway Pillars & Header
	local archLeft = createPart(monument, "ArchPillarL", Vector3.new(3, 16, 3), CFrame.new(center + Vector3.new(-20, 8, -4)), Color3.fromRGB(40, 44, 56), Enum.Material.Slate, true)
	local archRight = createPart(monument, "ArchPillarR", Vector3.new(3, 16, 3), CFrame.new(center + Vector3.new(20, 8, -4)), Color3.fromRGB(40, 44, 56), Enum.Material.Slate, true)
	local archBeam = createPart(monument, "ArchBeam", Vector3.new(43, 3, 3.4), CFrame.new(center + Vector3.new(0, 15.5, -4)), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, true)

	local archBb = Instance.new("BillboardGui")
	archBb.Size = UDim2.new(0, 520, 0, 55)
	archBb.StudsOffset = Vector3.new(0, 2.5, 0)
	archBb.AlwaysOnTop = false
	archBb.MaxDistance = 90
	archBb.Parent = archBeam

	local archTitle = Instance.new("TextLabel")
	archTitle.Size = UDim2.new(1, 0, 1, 0)
	archTitle.BackgroundTransparency = 1
	archTitle.Text = "🏆 HALL OF CHAMPIONS 🏆"
	archTitle.TextColor3 = Color3.fromRGB(255, 225, 60)
	archTitle.Font = Enum.Font.GothamBlack
	archTitle.TextSize = 24
	archTitle.TextStrokeTransparency = 0.2
	archTitle.Parent = archBb

	-- 3. The 3 Towering Leaderboard Display Boards
	local boardDefs = {
		{
			category = "Power" :: LeaderboardCategory,
			offset = Vector3.new(-13.5, 7.5, -3.5),
			angleY = math.rad(10),
			catDef = LeaderboardConfig.CATEGORIES.Power,
		},
		{
			category = "Cash" :: LeaderboardCategory,
			offset = Vector3.new(0, 8.0, -4.5),
			angleY = 0,
			catDef = LeaderboardConfig.CATEGORIES.Cash,
		},
		{
			category = "Rebirths" :: LeaderboardCategory,
			offset = Vector3.new(13.5, 7.5, -3.5),
			angleY = math.rad(-10),
			catDef = LeaderboardConfig.CATEGORIES.Rebirths,
		},
	}

	for _, b in ipairs(boardDefs) do
		local boardCF = CFrame.new(center + b.offset) * CFrame.Angles(0, b.angleY, 0)

		-- Board backing frame
		createPart(monument, "BoardFrame_" .. b.category, Vector3.new(12.4, 13.8, 1.2), boardCF, Color3.fromRGB(20, 23, 32), Enum.Material.Slate, true)
		-- Glowing perimeter trim
		createPart(monument, "BoardTrim_" .. b.category, Vector3.new(12.8, 14.2, 0.4), boardCF * CFrame.new(0, 0, 0.5), b.catDef.color, Enum.Material.Neon, false)

		-- SurfaceGui Display on Front
		local displayPart = createPart(monument, "BoardFace_" .. b.category, Vector3.new(12, 13.4, 0.2), boardCF * CFrame.new(0, 0, 0.65), Color3.fromRGB(15, 18, 25), Enum.Material.SmoothPlastic, false)

		local sGui = Instance.new("SurfaceGui")
		sGui.Name = "LeaderboardSurfaceGui"
		sGui.Face = Enum.NormalId.Front
		sGui.CanvasSize = Vector2.new(480, 560)
		sGui.AlwaysOnTop = false
		sGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sGui.Parent = displayPart

		local rootFrame = Instance.new("Frame")
		rootFrame.Size = UDim2.new(1, 0, 1, 0)
		rootFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
		rootFrame.BorderSizePixel = 0
		rootFrame.Parent = sGui

		-- Board Header
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 68)
		header.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
		header.BorderSizePixel = 0
		header.Parent = rootFrame

		local hTitle = Instance.new("TextLabel")
		hTitle.Size = UDim2.new(1, 0, 0, 36)
		hTitle.Position = UDim2.new(0, 0, 0, 8)
		hTitle.BackgroundTransparency = 1
		hTitle.Text = b.catDef.title
		hTitle.TextColor3 = b.catDef.color
		hTitle.Font = Enum.Font.GothamBlack
		hTitle.TextSize = 22
		hTitle.Parent = header

		local hSub = Instance.new("TextLabel")
		hSub.Size = UDim2.new(1, 0, 0, 20)
		hSub.Position = UDim2.new(0, 0, 0, 42)
		hSub.BackgroundTransparency = 1
		hSub.Text = "Top 10 Global Champions • Live Updates"
		hSub.TextColor3 = Color3.fromRGB(180, 195, 215)
		hSub.Font = Enum.Font.GothamBold
		hSub.TextSize = 12
		hSub.Parent = header

		-- Rows Container
		local rowsContainer = Instance.new("Frame")
		rowsContainer.Name = "RowsContainer"
		rowsContainer.Size = UDim2.new(1, -20, 1, -80)
		rowsContainer.Position = UDim2.new(0, 10, 0, 74)
		rowsContainer.BackgroundTransparency = 1
		rowsContainer.Parent = rootFrame

		local rList = Instance.new("UIListLayout")
		rList.Padding = UDim.new(0, 8)
		rList.Parent = rowsContainer

		boardGuiContainers[b.category] = rowsContainer
	end

	-- 4. In-World Physical Podium Dais (🥇 1st Gold, 🥈 2nd Silver, 🥉 3rd Bronze)
	local podiums = {
		{ rank = 1, pos = center + Vector3.new(0, 0.8, 5), height = 2.4, color = Color3.fromRGB(255, 215, 0), label = "🥇 1ST PLACE" },
		{ rank = 2, pos = center + Vector3.new(-7, 0.8, 4.5), height = 1.7, color = Color3.fromRGB(220, 230, 245), label = "🥈 2ND PLACE" },
		{ rank = 3, pos = center + Vector3.new(7, 0.8, 4.5), height = 1.2, color = Color3.fromRGB(215, 135, 65), label = "🥉 3RD PLACE" },
	}

	for _, pod in ipairs(podiums) do
		local base = createPart(monument, "Podium_" .. pod.rank, Vector3.new(5.2, pod.height, 5.2), CFrame.new(pod.pos + Vector3.new(0, pod.height * 0.5, 0)), Color3.fromRGB(36, 40, 52), Enum.Material.Slate, true)
		createPart(monument, "PodiumTrim_" .. pod.rank, Vector3.new(5.4, 0.25, 5.4), CFrame.new(pod.pos + Vector3.new(0, pod.height + 0.1, 0)), pod.color, Enum.Material.Neon, false)

		local podBb = Instance.new("BillboardGui")
		podBb.Size = UDim2.new(0, 140, 0, 36)
		podBb.StudsOffset = Vector3.new(0, (pod.height * 0.5) + 2.2, 0)
		podBb.AlwaysOnTop = false
		podBb.MaxDistance = 45
		podBb.Parent = base

		local podLbl = Instance.new("TextLabel")
		podLbl.Size = UDim2.new(1, 0, 1, 0)
		podLbl.BackgroundTransparency = 1
		podLbl.Text = pod.label
		podLbl.TextColor3 = pod.color
		podLbl.Font = Enum.Font.GothamBlack
		podLbl.TextSize = 13
		podLbl.TextStrokeTransparency = 0.2
		podLbl.Parent = podBb

		-- Floating Crown on 1st Place Podium
		if pod.rank == 1 then
			local crown = createPart(monument, "GoldCrown", Vector3.new(1.8, 0.8, 1.8), CFrame.new(pod.pos + Vector3.new(0, pod.height + 1.2, 0)), Color3.fromRGB(255, 215, 0), Enum.Material.Neon, false)
			task.spawn(function()
				local startY = crown.Position.Y
				local rot = 0
				while crown and crown.Parent do
					rot += 0.03
					local bob = math.sin(rot * 2) * 0.2
					crown.CFrame = CFrame.new(crown.Position.X, startY + bob, crown.Position.Z) * CFrame.Angles(0, rot, 0)
					task.wait(0.03)
				end
			end)
		end

		-- ProximityPrompt to open full detailed leaderboard UI
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "View Full Leaderboard"
		prompt.ObjectText = "Hall of Champions"
		prompt.MaxActivationDistance = 14
		prompt.HoldDuration = 0
		prompt.Parent = base
		prompt.Triggered:Connect(function(player)
			local openEvent = Remotes.getEvent("OpenLeaderboardModal")
			openEvent:FireClient(player, "Cash")
		end)
	end
end

-- =========================================================================
-- INITIALIZATION
-- =========================================================================
function LeaderboardService.init()
	print("🏆 [LeaderboardService] Initializing Hall of Champions Leaderboard Service...")

	-- 1. Register RemoteFunction for client UI modal queries
	local getLeaderboardFn = Remotes.getFunction("GetLeaderboardData")
	getLeaderboardFn.OnServerInvoke = function(player: Player, categoryArg: any)
		local cat: LeaderboardCategory = "Cash"
		if typeof(categoryArg) == "string" and LeaderboardConfig.CATEGORIES[categoryArg :: LeaderboardCategory] then
			cat = categoryArg :: LeaderboardCategory
		end
		return LeaderboardService.getRankings(cat, player)
	end

	-- 2. Build In-World Physical Monument in Town Center
	local mapFolder = Workspace:FindFirstChild("Map") or Workspace
	local existing = mapFolder:FindFirstChild("LeaderboardMonument")
	if existing then
		existing:Destroy()
	end
	buildPhysicalMonument(mapFolder)

	-- 3. Initial SurfaceGui render
	for _, catDef in ipairs(LeaderboardConfig.ORDERED_CATEGORIES) do
		updateBoardSurfaceGui(catDef.id)
	end

	-- 4. Background refresh loop every UPDATE_INTERVAL seconds
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			for _, catDef in ipairs(LeaderboardConfig.ORDERED_CATEGORIES) do
				pcall(function()
					updateBoardSurfaceGui(catDef.id)
				end)
			end
		end
	end)

	print("✅ [LeaderboardService] Hall of Champions Leaderboards Online in Town Plaza at (0, 0, -32)!")
end

return LeaderboardService
