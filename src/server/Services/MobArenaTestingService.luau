--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)

local MobArenaTestingService = {}

local ARENA_CENTER = Vector3.new(0, 220, 500)
local ARENA_ARRIVAL = ARENA_CENTER + Vector3.new(0, 4.0, 55)
local TOWN_SPAWN = Vector3.new(0, 5.0, 0)

local lastArrivalTimes: { [Player]: number } = {}
local arenaFolder: Folder

-- Utility: Part builder
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
	part.Material = material or Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = if canCollide ~= nil then canCollide else true
	part.Parent = parent
	return part
end

-- Constructs a containment pen / box with reinforced tinted glass walls and neon posts
local function buildMobPen(
	parent: Folder,
	penId: string,
	title: string,
	subtitle: string,
	centerPos: Vector3,
	penSize: Vector2,
	accentColor: Color3
)
	local penModel = Instance.new("Model")
	penModel.Name = "MobPen_" .. penId
	penModel.Parent = parent

	local halfW = penSize.X / 2
	local halfD = penSize.Y / 2
	local wallHeight = 14
	local floorY = centerPos.Y

	-- Pen Floor (Studs surface for authentic building feel)
	local floorPart = createPart(
		penModel,
		"PenFloor",
		Vector3.new(penSize.X, 1, penSize.Y),
		CFrame.new(centerPos.X, floorY + 0.2, centerPos.Z),
		Color3.fromRGB(30, 32, 42),
		Enum.Material.Concrete,
		true
	)
	floorPart.TopSurface = Enum.SurfaceType.Studs

	-- Border Ring
	local curbThickness = 1.2
	local borderCurb = createPart(
		penModel,
		"BorderCurb",
		Vector3.new(penSize.X + 1.6, 1.4, penSize.Y + 1.6),
		CFrame.new(centerPos.X, floorY + 0.3, centerPos.Z),
		accentColor,
		Enum.Material.Neon,
		false
	)

	-- 4 Corner Neon Posts
	local corners = {
		Vector3.new(centerPos.X - halfW, floorY + (wallHeight / 2), centerPos.Z - halfD),
		Vector3.new(centerPos.X + halfW, floorY + (wallHeight / 2), centerPos.Z - halfD),
		Vector3.new(centerPos.X - halfW, floorY + (wallHeight / 2), centerPos.Z + halfD),
		Vector3.new(centerPos.X + halfW, floorY + (wallHeight / 2), centerPos.Z + halfD),
	}
	for i, cornerPos in ipairs(corners) do
		createPart(
			penModel,
			"CornerPost_" .. i,
			Vector3.new(1.6, wallHeight, 1.6),
			CFrame.new(cornerPos),
			accentColor,
			Enum.Material.Neon,
			true
		)
	end

	-- 3 Reinforced Tinted Glass Enclosure Walls + 1 Gated Entrance
	-- North Wall
	local nWall = createPart(
		penModel,
		"Wall_North",
		Vector3.new(penSize.X, wallHeight, 0.8),
		CFrame.new(centerPos.X, floorY + (wallHeight / 2), centerPos.Z - halfD),
		Color3.fromRGB(40, 50, 70),
		Enum.Material.Glass,
		true
	)
	nWall.Transparency = 0.55

	-- East Wall
	local eWall = createPart(
		penModel,
		"Wall_East",
		Vector3.new(0.8, wallHeight, penSize.Y),
		CFrame.new(centerPos.X + halfW, floorY + (wallHeight / 2), centerPos.Z),
		Color3.fromRGB(40, 50, 70),
		Enum.Material.Glass,
		true
	)
	eWall.Transparency = 0.55

	-- West Wall
	local wWall = createPart(
		penModel,
		"Wall_West",
		Vector3.new(0.8, wallHeight, penSize.Y),
		CFrame.new(centerPos.X - halfW, floorY + (wallHeight / 2), centerPos.Z),
		Color3.fromRGB(40, 50, 70),
		Enum.Material.Glass,
		true
	)
	wWall.Transparency = 0.55

	-- South Wall (Gated / Opening for entrance)
	local gateWidth = 10
	local sideWallWidth = (penSize.X - gateWidth) / 2
	local sWallLeft = createPart(
		penModel,
		"Wall_SouthLeft",
		Vector3.new(sideWallWidth, wallHeight, 0.8),
		CFrame.new(centerPos.X - (halfW - sideWallWidth / 2), floorY + (wallHeight / 2), centerPos.Z + halfD),
		Color3.fromRGB(40, 50, 70),
		Enum.Material.Glass,
		true
	)
	sWallLeft.Transparency = 0.55

	local sWallRight = createPart(
		penModel,
		"Wall_SouthRight",
		Vector3.new(sideWallWidth, wallHeight, 0.8),
		CFrame.new(centerPos.X + (halfW - sideWallWidth / 2), floorY + (wallHeight / 2), centerPos.Z + halfD),
		Color3.fromRGB(40, 50, 70),
		Enum.Material.Glass,
		true
	)
	sWallRight.Transparency = 0.55

	-- Overhead Gate Lintel
	createPart(
		penModel,
		"GateLintel",
		Vector3.new(gateWidth, 2.0, 1.2),
		CFrame.new(centerPos.X, floorY + wallHeight - 1.0, centerPos.Z + halfD),
		accentColor,
		Enum.Material.Metal,
		true
	)

	-- Floating Overhead Tag / Info Billboard
	local signAnchor = createPart(
		penModel,
		"SignAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(centerPos.X, floorY + wallHeight + 3.0, centerPos.Z),
		accentColor,
		Enum.Material.SmoothPlastic,
		false
	)
	signAnchor.Transparency = 1

	local bb = Instance.new("BillboardGui")
	bb.Name = "PenInfoGui"
	bb.Size = UDim2.new(0, 320, 0, 56)
	bb.StudsOffset = Vector3.new(0, 1.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.Parent = signAnchor

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 32)
	titleLbl.Position = UDim2.new(0, 0, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = accentColor
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextSize = 22
	titleLbl.TextStrokeTransparency = 0.15
	titleLbl.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
	titleLbl.Parent = bb

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, 0, 0, 20)
	subLbl.Position = UDim2.new(0, 0, 0, 30)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = subtitle
	subLbl.TextColor3 = Color3.fromRGB(220, 230, 250)
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextSize = 13
	subLbl.TextStrokeTransparency = 0.3
	subLbl.Parent = bb
end

-- Constructs the Complete Mob Testing Arena
function MobArenaTestingService.buildArena()
	if arenaFolder then
		arenaFolder:Destroy()
	end

	arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "MobTestingArena"
	arenaFolder.Parent = Workspace

	local centerY = ARENA_CENTER.Y

	-- 1. Main Deck Floor (150x150 studs)
	local mainFloor = createPart(
		arenaFolder,
		"MainDeck",
		Vector3.new(150, 3.0, 150),
		CFrame.new(ARENA_CENTER),
		Color3.fromRGB(20, 22, 30),
		Enum.Material.Slate,
		true
	)
	mainFloor.TopSurface = Enum.SurfaceType.Studs

	-- Perimeter Neon Curb
	createPart(
		arenaFolder,
		"PerimeterCurb",
		Vector3.new(153, 3.8, 153),
		CFrame.new(ARENA_CENTER + Vector3.new(0, -0.2, 0)),
		Color3.fromRGB(255, 120, 0),
		Enum.Material.Neon,
		false
	)

	-- Perimeter Safety Guardrails (4 sides)
	local railHeight = 3.6
	local rails = {
		{ size = Vector3.new(150, railHeight, 1.2), cf = CFrame.new(ARENA_CENTER + Vector3.new(0, 2.8, -75)) },
		{ size = Vector3.new(150, railHeight, 1.2), cf = CFrame.new(ARENA_CENTER + Vector3.new(0, 2.8, 75)) },
		{ size = Vector3.new(1.2, railHeight, 150), cf = CFrame.new(ARENA_CENTER + Vector3.new(-75, 2.8, 0)) },
		{ size = Vector3.new(1.2, railHeight, 150), cf = CFrame.new(ARENA_CENTER + Vector3.new(75, 2.8, 0)) },
	}
	for i, r in ipairs(rails) do
		createPart(arenaFolder, "GuardRail_" .. i, r.size, r.cf, Color3.fromRGB(45, 50, 65), Enum.Material.Metal, true)
	end

	-- 2. Four Mob Containment Pens ("Boxes")
	-- Pen A: Starter Mobs (North-West)
	buildMobPen(
		arenaFolder,
		"Alpha",
		"📦 MOB PEN ALPHA",
		"Starter & Swarm Entities (Ready for Mobs)",
		ARENA_CENTER + Vector3.new(-42, 1.5, -35),
		Vector2.new(34, 34),
		Color3.fromRGB(0, 220, 140)
	)

	-- Pen B: Armored Brutes (North-East)
	buildMobPen(
		arenaFolder,
		"Beta",
		"📦 MOB PEN BETA",
		"Heavy & Armored Brutes (Ready for Mobs)",
		ARENA_CENTER + Vector3.new(42, 1.5, -35),
		Vector2.new(34, 34),
		Color3.fromRGB(0, 180, 255)
	)

	-- Pen C: Ranged & Elemental (South-West)
	buildMobPen(
		arenaFolder,
		"Gamma",
		"📦 MOB PEN GAMMA",
		"Ranged & Elemental Casters (Ready for Mobs)",
		ARENA_CENTER + Vector3.new(-42, 1.5, 25),
		Vector2.new(34, 34),
		Color3.fromRGB(255, 175, 30)
	)

	-- Pen D: Elite Minibosses (South-East)
	buildMobPen(
		arenaFolder,
		"Delta",
		"📦 MOB PEN DELTA",
		"Elite Miniboss Encounters (Ready for Mobs)",
		ARENA_CENTER + Vector3.new(42, 1.5, 25),
		Vector2.new(34, 34),
		Color3.fromRGB(240, 60, 190)
	)

	-- 3. Center Grand Colosseum Combat Pit (Boss Area)
	local pitCenter = ARENA_CENTER + Vector3.new(0, 1.6, -5)
	local pitFloor = createPart(
		arenaFolder,
		"BossPitFloor",
		Vector3.new(46, 1.2, 46),
		CFrame.new(pitCenter),
		Color3.fromRGB(28, 16, 22),
		Enum.Material.CrackedLava,
		true
	)
	pitFloor.TopSurface = Enum.SurfaceType.Studs

	createPart(
		arenaFolder,
		"BossPitRing",
		Vector3.new(48, 1.6, 48),
		CFrame.new(pitCenter),
		Color3.fromRGB(255, 60, 40),
		Enum.Material.Neon,
		false
	)

	-- 4 Corner Brazier Pillars around Colosseum Pit
	local colCorners = {
		Vector3.new(pitCenter.X - 23, centerY + 4, pitCenter.Z - 23),
		Vector3.new(pitCenter.X + 23, centerY + 4, pitCenter.Z - 23),
		Vector3.new(pitCenter.X - 23, centerY + 4, pitCenter.Z + 23),
		Vector3.new(pitCenter.X + 23, centerY + 4, pitCenter.Z + 23),
	}
	for i, cPos in ipairs(colCorners) do
		local pillar = createPart(
			arenaFolder,
			"ColPillar_" .. i,
			Vector3.new(2.4, 8, 2.4),
			CFrame.new(cPos),
			Color3.fromRGB(40, 45, 55),
			Enum.Material.Cobblestone,
			true
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 20)
		light.Range = 26
		light.Brightness = 2.4
		light.Parent = pillar
	end

	-- Center Colosseum Banner
	local centerSignAnchor = createPart(
		arenaFolder,
		"CenterSignAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(pitCenter + Vector3.new(0, 18, 0)),
		Color3.fromRGB(255, 60, 40),
		Enum.Material.SmoothPlastic,
		false
	)
	centerSignAnchor.Transparency = 1

	local cbb = Instance.new("BillboardGui")
	cbb.Name = "CenterSignGui"
	cbb.Size = UDim2.new(0, 380, 0, 60)
	cbb.AlwaysOnTop = false
	cbb.MaxDistance = 160
	cbb.Parent = centerSignAnchor

	local cTitle = Instance.new("TextLabel")
	cTitle.Size = UDim2.new(1, 0, 0, 34)
	cTitle.BackgroundTransparency = 1
	cTitle.Text = "⚔️ GRAND MOB COLOSSEUM ⚔️"
	cTitle.TextColor3 = Color3.fromRGB(255, 80, 60)
	cTitle.Font = Enum.Font.FredokaOne
	cTitle.TextSize = 25
	cTitle.TextStrokeTransparency = 0.1
	cTitle.Parent = cbb

	local cSub = Instance.new("TextLabel")
	cSub.Size = UDim2.new(1, 0, 0, 20)
	cSub.Position = UDim2.new(0, 0, 0, 32)
	cSub.BackgroundTransparency = 1
	cSub.Text = "Arena Boss Pit • Staged Combat Testing Grounds"
	cSub.TextColor3 = Color3.fromRGB(255, 215, 120)
	cSub.Font = Enum.Font.GothamBold
	cSub.TextSize = 13
	cSub.Parent = cbb

	-- 4. Arrival Landing Pad & Beacon Light
	local padPos = ARENA_CENTER + Vector3.new(-10, 1.6, 60)
	local arrivalPad = createPart(
		arenaFolder,
		"ArrivalPad",
		Vector3.new(12, 0.4, 12),
		CFrame.new(padPos),
		Color3.fromRGB(255, 170, 0),
		Enum.Material.Neon,
		true
	)

	createPart(
		arenaFolder,
		"ArrivalRing",
		Vector3.new(14, 0.2, 14),
		CFrame.new(padPos + Vector3.new(0, -0.1, 0)),
		Color3.fromRGB(255, 220, 100),
		Enum.Material.Neon,
		false
	)

	-- Beacon Light into sky
	local beacon = createPart(
		arenaFolder,
		"BeaconBeam",
		Vector3.new(0.8, 80, 0.8),
		CFrame.new(padPos + Vector3.new(0, 40, 0)),
		Color3.fromRGB(255, 170, 0),
		Enum.Material.Neon,
		false
	)
	beacon.Transparency = 0.4

	-- 5. Physical Return Teleport Pad (to Town)
	local returnPos = ARENA_CENTER + Vector3.new(14, 1.6, 60)
	local returnPad = createPart(
		arenaFolder,
		"ReturnPad",
		Vector3.new(10, 0.4, 10),
		CFrame.new(returnPos),
		Color3.fromRGB(0, 230, 120),
		Enum.Material.Neon,
		true
	)

	local rbb = Instance.new("BillboardGui")
	rbb.Size = UDim2.new(0, 180, 0, 42)
	rbb.StudsOffset = Vector3.new(0, 3.0, 0)
	rbb.AlwaysOnTop = false
	rbb.MaxDistance = 60
	rbb.Parent = returnPad

	local rLbl = Instance.new("TextLabel")
	rLbl.Size = UDim2.new(1, 0, 1, 0)
	rLbl.BackgroundTransparency = 1
	rLbl.Text = "🏡 Return to Town\n(Step on pad or press E)"
	rLbl.TextColor3 = Color3.fromRGB(120, 255, 180)
	rLbl.Font = Enum.Font.FredokaOne
	rLbl.TextSize = 13
	rLbl.TextStrokeTransparency = 0.2
	rLbl.Parent = rbb

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Return to Town"
	prompt.ObjectText = "Teleporter"
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.Parent = returnPad
	prompt.Triggered:Connect(function(player)
		MobArenaTestingService.teleportPlayer(player, "Town")
	end)

	local lastReturnPadTouch: { [Player]: number } = {}
	returnPad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local now = os.clock()
			if now - (lastArrivalTimes[player] or 0) < 3.0 then
				return
			end
			if now - (lastReturnPadTouch[player] or 0) < 2.0 then
				return
			end
			lastReturnPadTouch[player] = now
			MobArenaTestingService.teleportPlayer(player, "Town")
		end
	end)

	-- 6. Safety Net Barrier beneath platform (catches falling players)
	local safetyNet = createPart(
		arenaFolder,
		"SafetyNet",
		Vector3.new(280, 2, 280),
		CFrame.new(ARENA_CENTER + Vector3.new(0, -22, 0)),
		Color3.fromRGB(0, 0, 0),
		Enum.Material.SmoothPlastic,
		true
	)
	safetyNet.Transparency = 1
	safetyNet.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			MobArenaTestingService.teleportPlayer(player, "Arena")
		end
	end)
end

-- PUBLIC TELEPORT HANDLER
function MobArenaTestingService.teleportPlayer(player: Player, requestedTarget: string?): (boolean, string)
	local char = player.Character
	if not char then
		local ok, c = pcall(function()
			return player.CharacterAdded:Wait()
		end)
		char = if ok then c else nil
	end
	if not char then return false, "NoCharacter" end

	local root = char:WaitForChild("HumanoidRootPart", 4) :: BasePart?
	if not root then return false, "NoRootPart" end
	local humanoid = char:FindFirstChildOfClass("Humanoid")

	local distToArena = (root.Position - ARENA_CENTER).Magnitude
	local targetCF: CFrame
	local destinationName: string

	if requestedTarget == "Arena" then
		targetCF = CFrame.new(ARENA_ARRIVAL)
		destinationName = "Arena"
	elseif requestedTarget == "Town" then
		targetCF = CFrame.new(TOWN_SPAWN)
		destinationName = "Town"
	else
		-- Auto-toggle fallback
		if distToArena < 120 then
			targetCF = CFrame.new(TOWN_SPAWN)
			destinationName = "Town"
		else
			targetCF = CFrame.new(ARENA_ARRIVAL)
			destinationName = "Arena"
		end
	end

	-- Pre-stream around destination if StreamingEnabled
	if destinationName == "Arena" and Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(targetCF.Position)
		end)
	end

	-- Unseat humanoid if seated
	if humanoid and humanoid.Sit then
		humanoid.Sit = false
	end

	-- Reset velocity
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(targetCF)

	if destinationName == "Arena" then
		lastArrivalTimes[player] = os.clock()
	end

	print(string.format("⚔️ [MobArenaTestingService] Teleported %s to %s at %s", player.Name, destinationName, tostring(targetCF.Position)))
	return true, destinationName
end

function MobArenaTestingService.init()
	print("⚔️ [MobArenaTestingService] Building Mob Fighting Testing Arena...")

	-- 1. Build arena geometry
	MobArenaTestingService.buildArena()

	-- 2. Bind Remote Function
	local tpFn = Remotes.getFunction("DevTeleportToMobArena")
	tpFn.OnServerInvoke = function(player: Player, targetStr: any)
		if typeof(targetStr) == "string" and (targetStr == "Arena" or targetStr == "Town") then
			return MobArenaTestingService.teleportPlayer(player, targetStr)
		end
		return MobArenaTestingService.teleportPlayer(player, nil)
	end

	-- Player death / reset failsafe
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
			if root and (root.Position - ARENA_CENTER).Magnitude < 110 then
				task.wait(0.1)
				char:PivotTo(CFrame.new(ARENA_ARRIVAL))
			end
		end)
	end)

	print("✅ [MobArenaTestingService] Mob Fighting Testing Arena Ready!")
end

return MobArenaTestingService
