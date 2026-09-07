--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local ZoneClient = {}

local player = Players.LocalPlayer
local cachedRebirths = 0
local currentZoneId = "Zone1"
local lastWarnTime = 0

local magmaBarrierPart: BasePart? = nil
local magmaBarrierTouchConn: RBXScriptConnection? = nil

local cosmicBarrierPart: BasePart? = nil
local cosmicBarrierTouchConn: RBXScriptConnection? = nil

-- UI References
local toastGui: ScreenGui
local warningFrame: Frame
local warningText: TextLabel
local zoneBannerFrame: Frame
local zoneTitleText: TextLabel
local zoneSubText: TextLabel

local function playWarningSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://6895079853" -- Crisp thud/bump
	sound.PlaybackSpeed = 0.75 -- Deep buzz tone
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function playZoneTransitionSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://5153737200" -- Soft chime/fanfare
	sound.PlaybackSpeed = 1.15
	sound.Volume = 0.45
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Builds floating HUD toasts for Gate Lockout Warning and Zone Transition
local function buildZoneUI()
	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("ZoneHUDGui")
	if existing then existing:Destroy() end

	toastGui = Instance.new("ScreenGui")
	toastGui.Name = "ZoneHUDGui"
	toastGui.ResetOnSpawn = false
	toastGui.DisplayOrder = 15
	toastGui.Parent = pGui

	-- 1. Gate Lockout Warning Banner (Floating Top-Center Pill)
	warningFrame = Instance.new("Frame")
	warningFrame.Name = "GateWarningBanner"
	warningFrame.Size = UDim2.new(0, 520, 0, 52)
	warningFrame.Position = UDim2.new(0.5, 0, -0.15, 0) -- Hidden above screen
	warningFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	warningFrame.BackgroundColor3 = Color3.fromRGB(28, 14, 16)
	warningFrame.BorderSizePixel = 0
	warningFrame.Parent = toastGui

	local wCorner = Instance.new("UICorner")
	wCorner.CornerRadius = UDim.new(0, 26)
	wCorner.Parent = warningFrame

	local wStroke = Instance.new("UIStroke")
	wStroke.Color = Color3.fromRGB(255, 60, 40)
	wStroke.Thickness = 2.5
	wStroke.Parent = warningFrame

	warningText = Instance.new("TextLabel")
	warningText.Name = "WarningText"
	warningText.Size = UDim2.new(1, -20, 1, 0)
	warningText.Position = UDim2.new(0, 10, 0, 0)
	warningText.BackgroundTransparency = 1
	warningText.Text = "🔒 Requires 5 Rebirths to Enter!"
	warningText.TextColor3 = Color3.fromRGB(255, 220, 220)
	warningText.Font = Enum.Font.GothamBlack
	warningText.TextSize = 15
	warningText.TextStrokeTransparency = 0.2
	warningText.Parent = warningFrame

	-- 2. Cinematic Zone Transition Banner (Sliding Card at Upper Third)
	zoneBannerFrame = Instance.new("Frame")
	zoneBannerFrame.Name = "ZoneTransitionBanner"
	zoneBannerFrame.Size = UDim2.new(0, 400, 0, 72)
	zoneBannerFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
	zoneBannerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	zoneBannerFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	zoneBannerFrame.BackgroundTransparency = 1 -- Hidden initially
	zoneBannerFrame.BorderSizePixel = 0
	zoneBannerFrame.Parent = toastGui

	local zCorner = Instance.new("UICorner")
	zCorner.CornerRadius = UDim.new(0, 16)
	zCorner.Parent = zoneBannerFrame

	local zStroke = Instance.new("UIStroke")
	zStroke.Color = Color3.fromRGB(255, 120, 30)
	zStroke.Thickness = 2
	zStroke.Transparency = 1
	zStroke.Parent = zoneBannerFrame

	zoneTitleText = Instance.new("TextLabel")
	zoneTitleText.Name = "ZoneTitle"
	zoneTitleText.Size = UDim2.new(1, 0, 0.55, 0)
	zoneTitleText.Position = UDim2.new(0, 0, 0.08, 0)
	zoneTitleText.BackgroundTransparency = 1
	zoneTitleText.Text = "🌋 ENTERING: MAGMA CAVERNS"
	zoneTitleText.TextColor3 = Color3.fromRGB(255, 140, 30)
	zoneTitleText.Font = Enum.Font.GothamBlack
	zoneTitleText.TextSize = 19
	zoneTitleText.TextTransparency = 1
	zoneTitleText.TextStrokeTransparency = 1
	zoneTitleText.Parent = zoneBannerFrame

	zoneSubText = Instance.new("TextLabel")
	zoneSubText.Name = "ZoneSubtitle"
	zoneSubText.Size = UDim2.new(1, 0, 0.4, 0)
	zoneSubText.Position = UDim2.new(0, 0, 0.58, 0)
	zoneSubText.BackgroundTransparency = 1
	zoneSubText.Text = "Zone 2 • Requires 5 Rebirths"
	zoneSubText.TextColor3 = Color3.fromRGB(230, 230, 240)
	zoneSubText.Font = Enum.Font.GothamBold
	zoneSubText.TextSize = 13
	zoneSubText.TextTransparency = 1
	zoneSubText.TextStrokeTransparency = 1
	zoneSubText.Parent = zoneBannerFrame
end

-- Displays warning when touching a locked Gate
local isWarningShowing = false
function ZoneClient.showGateLockWarning(zoneId: string?)
	local now = os.clock()
	if isWarningShowing or (now - lastWarnTime) < 2.0 then
		return
	end
	lastWarnTime = now
	isWarningShowing = true

	playWarningSound()

	local targetZone = zoneId or "Zone2"
	local reqRebirths = if targetZone == "Zone3" then ZoneConfig.ZONES.Zone3.rebirthRequired else ZoneConfig.ZONES.Zone2.rebirthRequired
	local zoneName = if targetZone == "Zone3" then "The Cosmic Void" else "Magma Caverns"

	warningText.Text = string.format("🔒 Requires %d Rebirths to Enter %s! (You have %d/%d)", reqRebirths, zoneName, cachedRebirths, reqRebirths)

	-- Shake & slide into view at top-center (Y = 0.11)
	warningFrame.Position = UDim2.new(0.5, 0, -0.15, 0)
	warningFrame.Visible = true

	local slideIn = TweenService:Create(warningFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.11, 0),
	})
	slideIn:Play()

	task.delay(2.6, function()
		local slideOut = TweenService:Create(warningFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.15, 0),
		})
		slideOut:Play()
		slideOut.Completed:Connect(function()
			isWarningShowing = false
		end)
	end)
end

-- Displays cinematic transition banner when crossing zone threshold
function ZoneClient.showZoneTransition(zoneId: string)
	local zone = ZoneConfig.ZONES[zoneId]
	if not zone then return end

	playZoneTransitionSound()

	zoneTitleText.Text = string.format("%s ENTERING: %s %s", zone.icon, zone.name:upper(), zone.icon)
	zoneTitleText.TextColor3 = zone.color
	if zoneId == "Zone2" then
		zoneSubText.Text = "Zone 2 • Magma & Molten Ores (5+ Rebirths)"
	elseif zoneId == "Zone3" then
		zoneSubText.Text = "Zone 3 • Cosmic Void & Astral Ores (10+ Rebirths)"
	elseif zoneId == "TrainingQuarry" then
		zoneSubText.Text = "Rebirth Training Grounds • Multi-Tier Power Ores"
	else
		zoneSubText.Text = "Zone 1 • Peaceful Haven & Starter Ores"
	end

	local stroke = zoneBannerFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = zone.color
	end

	-- Fade in and subtle scale/slide
	zoneBannerFrame.Position = UDim2.new(0.5, 0, 0.13, 0)
	zoneBannerFrame.BackgroundTransparency = 1
	zoneTitleText.TextTransparency = 1
	zoneTitleText.TextStrokeTransparency = 1
	zoneSubText.TextTransparency = 1
	zoneSubText.TextStrokeTransparency = 1
	if stroke then stroke.Transparency = 1 end

	TweenService:Create(zoneBannerFrame, TweenInfo.new(0.4), { BackgroundTransparency = 0.15, Position = UDim2.new(0.5, 0, 0.16, 0) }):Play()
	TweenService:Create(zoneTitleText, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	TweenService:Create(zoneSubText, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 0.2 }):Play()
	end

	task.delay(3.0, function()
		TweenService:Create(zoneBannerFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.13, 0) }):Play()
		TweenService:Create(zoneTitleText, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(zoneSubText, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

-- Searches for Gate Barriers in Workspace and configures collision & touched handlers
local function setupBarriers()
	if magmaBarrierTouchConn then
		magmaBarrierTouchConn:Disconnect()
		magmaBarrierTouchConn = nil
	end
	if cosmicBarrierTouchConn then
		cosmicBarrierTouchConn:Disconnect()
		cosmicBarrierTouchConn = nil
	end

	local map = Workspace:FindFirstChild("Map")
	if not map then return end

	-- 1. Magma Gate Barrier (Zone 2, Z = -140)
	local magmaGate = map:FindFirstChild("MagmaGate")
	if magmaGate then
		local barrier = magmaGate:FindFirstChild("MagmaGateBarrier") :: BasePart?
		if barrier then
			magmaBarrierPart = barrier
			magmaBarrierTouchConn = barrier.Touched:Connect(function(hit)
				local char = hit.Parent
				if not char or char ~= player.Character then return end

				local reqRebirths = ZoneConfig.ZONES.Zone2.rebirthRequired
				if cachedRebirths < reqRebirths then
					ZoneClient.showGateLockWarning("Zone2")

					-- Gentle bounce back
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and root.Position.Z < -135 then
						root.CFrame = CFrame.new(root.Position.X, root.Position.Y, -135)
					end
				end
			end)
		end
	end

	-- 2. Cosmic Gate Barrier (Zone 3, Z = 140)
	local cosmicGate = map:FindFirstChild("CosmicGate")
	if cosmicGate then
		local barrier = cosmicGate:FindFirstChild("CosmicGateBarrier") :: BasePart?
		if barrier then
			cosmicBarrierPart = barrier
			cosmicBarrierTouchConn = barrier.Touched:Connect(function(hit)
				local char = hit.Parent
				if not char or char ~= player.Character then return end

				local reqRebirths = ZoneConfig.ZONES.Zone3.rebirthRequired
				if cachedRebirths < reqRebirths then
					ZoneClient.showGateLockWarning("Zone3")

					-- Gentle bounce back
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and root.Position.Z > 135 then
						root.CFrame = CFrame.new(root.Position.X, root.Position.Y, 135)
					end
				end
			end)
		end
	end

	-- Update collision states
	ZoneClient.updateRebirths(cachedRebirths)
end

-- Updates client Rebirth count and gate barriers CanCollide
function ZoneClient.updateRebirths(rebirths: number)
	cachedRebirths = rebirths

	-- Magma Gate (5 Rebirths)
	local reqMagma = ZoneConfig.ZONES.Zone2.rebirthRequired
	local isMagmaUnlocked = (cachedRebirths >= reqMagma)
	if magmaBarrierPart and magmaBarrierPart.Parent then
		if isMagmaUnlocked then
			magmaBarrierPart.CanCollide = false
			magmaBarrierPart.Transparency = 0.82
		else
			magmaBarrierPart.CanCollide = true
			magmaBarrierPart.Transparency = 0.35
		end
	end

	-- Cosmic Gate (10 Rebirths)
	local reqCosmic = ZoneConfig.ZONES.Zone3.rebirthRequired
	local isCosmicUnlocked = (cachedRebirths >= reqCosmic)
	if cosmicBarrierPart and cosmicBarrierPart.Parent then
		if isCosmicUnlocked then
			cosmicBarrierPart.CanCollide = false
			cosmicBarrierPart.Transparency = 0.82
		else
			cosmicBarrierPart.CanCollide = true
			cosmicBarrierPart.Transparency = 0.35
		end
	end
end

function ZoneClient.init()
	print("🚪 [ZoneClient] Initializing Zone Client Controller...")

	buildZoneUI()

	-- Try locating barriers
	task.spawn(function()
		local attempts = 0
		while attempts < 30 and (not magmaBarrierPart or not cosmicBarrierPart) do
			setupBarriers()
			if magmaBarrierPart and cosmicBarrierPart then break end
			task.wait(0.5)
			attempts += 1
		end
	end)

	-- Watch for Map being rebuilt or added
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Map" then
			task.wait(0.2)
			setupBarriers()
		end
	end)

	-- Retrieve initial player data
	task.spawn(function()
		local getDataFn = Remotes.getFunction("GetPlayerData")
		local data = getDataFn:InvokeServer()
		if data and data.Rebirths ~= nil then
			ZoneClient.updateRebirths(data.Rebirths)
		end
	end)

	-- Listen for SyncPlayerData updates
	local syncEvent = Remotes.getEvent("SyncPlayerData")
	syncEvent.OnClientEvent:Connect(function(data)
		if data and data.Rebirths ~= nil then
			ZoneClient.updateRebirths(data.Rebirths)
		end
	end)

	-- Listen for PlayerRebirthed event
	local rebirthedEvent = Remotes.getEvent("PlayerRebirthed")
	rebirthedEvent.OnClientEvent:Connect(function(arg1, arg2)
		if typeof(arg1) == "number" then
			ZoneClient.updateRebirths(arg1)
		elseif typeof(arg2) == "number" and (arg1 == nil or arg1 == player.Name) then
			ZoneClient.updateRebirths(arg2)
		end
	end)

	-- Continuous Zone Transition Tracker
	task.spawn(function()
		while true do
			task.wait(0.35)
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local rootPart = char:FindFirstChild("HumanoidRootPart") :: BasePart
				local xPos = rootPart.Position.X
				local zPos = rootPart.Position.Z

				if zPos <= -145 and currentZoneId ~= "Zone2" then
					currentZoneId = "Zone2"
					ZoneClient.showZoneTransition("Zone2")
				elseif zPos >= 145 and currentZoneId ~= "Zone3" then
					currentZoneId = "Zone3"
					ZoneClient.showZoneTransition("Zone3")
				elseif xPos >= 70 and math.abs(zPos) <= 45 and currentZoneId ~= "TrainingQuarry" then
					currentZoneId = "TrainingQuarry"
					ZoneClient.showZoneTransition("TrainingQuarry")
				elseif zPos >= -133 and zPos <= 133 and xPos < 65 and currentZoneId ~= "Zone1" then
					currentZoneId = "Zone1"
					ZoneClient.showZoneTransition("Zone1")
				end
			end
		end
	end)

	print("✅ [ZoneClient] Initialized! Gatekeeping (5 & 10 Rebirths) and Zone Transitions Active.")
end

return ZoneClient
