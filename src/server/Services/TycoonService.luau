--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Remotes = require(ReplicatedStorage.Shared.Utils.Remotes)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

export type Plot = {
	id: number,
	model: Model,
	origin: Vector3,
	owner: Player?,
	storedCash: number,
	storedGems: number,
	activeItems: { [string]: Instance },
	activeButtons: { [string]: Instance },
	dropperThreads: { [string]: thread },
}

local TycoonService = {}
local plots: { [number]: Plot } = {}
local playerPlots: { [Player]: Plot } = {}

-- Utility to build parts cleanly
local function createPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, anchored: boolean?, canCollide: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Plastic
	part.Anchored = if anchored ~= nil then anchored else true
	part.CanCollide = if canCollide ~= nil then canCollide else true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function TycoonService.updateCollectorUI(plot: Plot)
	local archTop = plot.model:FindFirstChild("ArchTop")
	if archTop then
		local billboard = archTop:FindFirstChild("CollectorBillboard") :: BillboardGui?
		if billboard then
			local storedLabel = billboard:FindFirstChild("StoredLabel") :: TextLabel?
			if storedLabel then
				storedLabel.Text = string.format("Stored: $%s | 💎 %d", FormatNumber.formatCompact(plot.storedCash), plot.storedGems)
			end
		end
	end

	local collectPad = plot.model:FindFirstChild("CollectCashPad")
	if collectPad then
		local billboard = collectPad:FindFirstChild("CollectBillboard") :: BillboardGui?
		if billboard then
			local amountLabel = billboard:FindFirstChild("AmountLabel") :: TextLabel?
			if amountLabel then
				if plot.storedCash > 0 or plot.storedGems > 0 then
					amountLabel.Text = string.format("Touch to Claim: $%s (+%d 💎)", FormatNumber.formatCompact(plot.storedCash), plot.storedGems)
					amountLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
				else
					amountLabel.Text = "Touch to Claim: $0"
					amountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
			end
		end
	end
end

function TycoonService.createPlot(plotId: number, origin: Vector3): Plot
	local model = Instance.new("Model")
	model.Name = "Plot_" .. plotId

	-- Main Floor (Clean dark slate base resting directly on baseplate)
	local floor = createPart(model, "Floor", Vector3.new(90, 1.2, 70), CFrame.new(origin + Vector3.new(0, 0.6, 0)), Color3.fromRGB(24, 26, 32), Enum.Material.SmoothPlastic)

	-- 4 Perimeter Neon Border Beams framing the plot without ANY surface overlap (Zero Z-fighting)
	createPart(model, "BorderFront", Vector3.new(92, 1.6, 1.5), CFrame.new(origin + Vector3.new(0, 0.8, 35.75)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon, true, false)
	createPart(model, "BorderBack", Vector3.new(92, 1.6, 1.5), CFrame.new(origin + Vector3.new(0, 0.8, -35.75)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon, true, false)
	createPart(model, "BorderLeft", Vector3.new(1.5, 1.6, 70), CFrame.new(origin + Vector3.new(-45.75, 0.8, 0)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon, true, false)
	createPart(model, "BorderRight", Vector3.new(1.5, 1.6, 70), CFrame.new(origin + Vector3.new(45.75, 0.8, 0)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon, true, false)

	-- Claim Pad at the entrance (Z = +30)
	local claimPad = createPart(model, "ClaimPad", Vector3.new(12, 0.4, 10), CFrame.new(origin + Vector3.new(0, 1.4, 30)), Color3.fromRGB(0, 230, 118), Enum.Material.Neon)
	
	local claimGui = Instance.new("BillboardGui")
	claimGui.Name = "ClaimBillboard"
	claimGui.Size = UDim2.new(0, 220, 0, 60)
	claimGui.StudsOffset = Vector3.new(0, 4, 0)
	claimGui.AlwaysOnTop = true

	local claimText = Instance.new("TextLabel")
	claimText.Name = "Text"
	claimText.Size = UDim2.new(1, 0, 1, 0)
	claimText.BackgroundTransparency = 1
	claimText.Text = "Touch to Claim Plot #" .. plotId
	claimText.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimText.TextStrokeTransparency = 0.2
	claimText.Font = Enum.Font.GothamBold
	claimText.TextSize = 18
	claimText.Parent = claimGui
	claimGui.Parent = claimPad

	-- Conveyor Belt (Z from -27 to +17, surface at Y = 1.8)
	local conveyor = createPart(model, "Conveyor", Vector3.new(8, 1.0, 44), CFrame.new(origin + Vector3.new(0, 1.3, -5)), Color3.fromRGB(35, 36, 42), Enum.Material.Metal)
	conveyor.AssemblyLinearVelocity = Vector3.new(0, 0, TycoonConfig.CONVEYOR_SPEED)

	-- Conveyor Side Rails
	createPart(model, "RailLeft", Vector3.new(0.6, 2.0, 44), CFrame.new(origin + Vector3.new(-4.3, 2.0, -5)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon)
	createPart(model, "RailRight", Vector3.new(0.6, 2.0, 44), CFrame.new(origin + Vector3.new(4.3, 2.0, -5)), Color3.fromRGB(0, 170, 255), Enum.Material.Neon)

	-- COLLECTOR HOPPER AT END OF CONVEYOR (Z = +17 to +24.5)
	-- Solid glowing neon collection floor (flush at Y=1.7 to catch all crystals coming off the conveyor)
	local collectorPad = createPart(model, "CollectorSensor", Vector3.new(9.2, 0.8, 7.5), CFrame.new(origin + Vector3.new(0, 1.3, 20.75)), Color3.fromRGB(255, 85, 20), Enum.Material.Neon, true, true)
	collectorPad.CanTouch = true

	-- Invisible Sensor Curtain spanning the entire entrance mouth (Z=18.5) so no crystal can enter without triggering
	local sensorCurtain = createPart(model, "CollectorCurtain", Vector3.new(8.8, 4.0, 2.0), CFrame.new(origin + Vector3.new(0, 2.8, 18.5)), Color3.fromRGB(255, 255, 255), Enum.Material.Plastic, true, false)
	sensorCurtain.Transparency = 1
	sensorCurtain.CanTouch = true

	-- U-Shape Enclosure Walls (Back & Sides only, NO front wall!)
	local wallLeft = createPart(model, "CollectorWallLeft", Vector3.new(0.6, 2.6, 7.5), CFrame.new(origin + Vector3.new(-4.4, 2.5, 20.75)), Color3.fromRGB(45, 48, 58), Enum.Material.Metal)
	wallLeft.CanTouch = true
	local wallRight = createPart(model, "CollectorWallRight", Vector3.new(0.6, 2.6, 7.5), CFrame.new(origin + Vector3.new(4.4, 2.5, 20.75)), Color3.fromRGB(45, 48, 58), Enum.Material.Metal)
	wallRight.CanTouch = true
	local backWall = createPart(model, "CollectorWallBack", Vector3.new(9.4, 2.6, 0.6), CFrame.new(origin + Vector3.new(0, 2.5, 24.5)), Color3.fromRGB(45, 48, 58), Enum.Material.Metal)
	backWall.CanTouch = true

	-- Overhead Collector Arch with Live Digital Stored Counter
	local archTop = createPart(model, "ArchTop", Vector3.new(9.8, 1.0, 1.2), CFrame.new(origin + Vector3.new(0, 4.4, 20.75)), Color3.fromRGB(255, 120, 0), Enum.Material.Neon)
	createPart(model, "ArchPillarL", Vector3.new(0.8, 2.4, 1.2), CFrame.new(origin + Vector3.new(-4.5, 3.2, 20.75)), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
	createPart(model, "ArchPillarR", Vector3.new(0.8, 2.4, 1.2), CFrame.new(origin + Vector3.new(4.5, 3.2, 20.75)), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)

	local archGui = Instance.new("BillboardGui")
	archGui.Name = "CollectorBillboard"
	archGui.Size = UDim2.new(0, 240, 0, 60)
	archGui.StudsOffset = Vector3.new(0, 2.2, 0)
	archGui.AlwaysOnTop = true

	local archLabel = Instance.new("TextLabel")
	archLabel.Name = "TitleLabel"
	archLabel.Size = UDim2.new(1, 0, 0.5, 0)
	archLabel.BackgroundTransparency = 1
	archLabel.Text = "💎 CRYSTAL COLLECTOR 💰"
	archLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	archLabel.Font = Enum.Font.GothamBlack
	archLabel.TextSize = 16
	archLabel.TextStrokeTransparency = 0.2
	archLabel.Parent = archGui

	local storedLabel = Instance.new("TextLabel")
	storedLabel.Name = "StoredLabel"
	storedLabel.Size = UDim2.new(1, 0, 0.5, 0)
	storedLabel.Position = UDim2.new(0, 0, 0.5, 0)
	storedLabel.BackgroundTransparency = 1
	storedLabel.Text = "Stored: $0 | 💎 0"
	storedLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
	storedLabel.Font = Enum.Font.GothamBold
	storedLabel.TextSize = 15
	storedLabel.TextStrokeTransparency = 0.2
	storedLabel.Parent = archGui
	archGui.Parent = archTop

	-- PHYSICAL CLAIM MONEY PAD (Placed right beside the collector)
	local collectPad = createPart(model, "CollectCashPad", Vector3.new(7, 0.6, 7), CFrame.new(origin + Vector3.new(-8.5, 1.2, 20.75)), Color3.fromRGB(0, 230, 118), Enum.Material.Neon)
	
	local collectGui = Instance.new("BillboardGui")
	collectGui.Name = "CollectBillboard"
	collectGui.Size = UDim2.new(0, 220, 0, 65)
	collectGui.StudsOffset = Vector3.new(0, 3.5, 0)
	collectGui.AlwaysOnTop = true

	local colTitle = Instance.new("TextLabel")
	colTitle.Name = "Title"
	colTitle.Size = UDim2.new(1, 0, 0.45, 0)
	colTitle.BackgroundTransparency = 1
	colTitle.Text = "💰 COLLECT CASH 💰"
	colTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	colTitle.Font = Enum.Font.GothamBlack
	colTitle.TextSize = 16
	colTitle.TextStrokeTransparency = 0.2
	colTitle.Parent = collectGui

	local colAmount = Instance.new("TextLabel")
	colAmount.Name = "AmountLabel"
	colAmount.Size = UDim2.new(1, 0, 0.45, 0)
	colAmount.Position = UDim2.new(0, 0, 0.45, 0)
	colAmount.BackgroundTransparency = 1
	colAmount.Text = "Touch to Claim: $0"
	colAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
	colAmount.Font = Enum.Font.GothamBold
	colAmount.TextSize = 14
	colAmount.TextStrokeTransparency = 0.2
	colAmount.Parent = collectGui
	collectGui.Parent = collectPad

	-- Folder for dynamic items & buttons
	local itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "PurchasedItems"
	itemsFolder.Parent = model

	local buttonsFolder = Instance.new("Folder")
	buttonsFolder.Name = "Buttons"
	buttonsFolder.Parent = model

	local crystalsFolder = Instance.new("Folder")
	crystalsFolder.Name = "Crystals"
	crystalsFolder.Parent = model

	local plotData: Plot = {
		id = plotId,
		model = model,
		origin = origin,
		owner = nil,
		storedCash = 0,
		storedGems = 0,
		activeItems = {},
		activeButtons = {},
		dropperThreads = {},
	}

	-- Function to payout accumulated cash to player
	local function claimStoredCash(player: Player)
		if plotData.storedCash > 0 or plotData.storedGems > 0 then
			local cashToClaim = plotData.storedCash
			local gemsToClaim = plotData.storedGems

			plotData.storedCash = 0
			plotData.storedGems = 0

			DataService.addCash(player, cashToClaim)
			if gemsToClaim > 0 then
				DataService.addGems(player, gemsToClaim)
			end

			print(string.format("🎉 [Plot %d] %s claimed $%d and %d Gems from Collector!", plotId, player.Name, cashToClaim, gemsToClaim))

			TycoonService.updateCollectorUI(plotData)

			local collectEvent = Remotes.getEvent("CrystalCollected")
			collectEvent:FireClient(player, cashToClaim, gemsToClaim, collectPad.Position)
		end
	end

	-- Collector touch logic: robust handling for both sensor pad and back wall
	local function handleCrystalCollection(hit: BasePart)
		if not hit or not hit.Parent then return end
		local isCrystal = hit:GetAttribute("IsCrystal") or string.find(hit.Name, "Crystal") ~= nil
		if isCrystal and not hit:GetAttribute("Collected") then
			hit:SetAttribute("Collected", true)
			local baseValue = (hit:GetAttribute("Value") or 10) :: number
			local upgraderMult = (hit:GetAttribute("Multiplier") or 1) :: number
			local baseGems = (hit:GetAttribute("Gems") or 0) :: number

			local player = plotData.owner
			local rebirthMult = 1
			local petCashMult = 1
			local petGemMult = 1

			if player then
				local pData = DataService.get(player)
				if pData then
					local okRebirth, rMult = pcall(function()
						return RebirthConfig.getMultiplier(pData.Rebirths)
					end)
					if okRebirth and rMult then
						rebirthMult = rMult
					end
				end
				local okPetCash, pCash = pcall(function()
					return PetService.getCashMultiplier(player)
				end)
				if okPetCash and pCash then
					petCashMult = pCash
				end
				local okPetGem, pGem = pcall(function()
					return PetService.getGemMultiplier(player)
				end)
				if okPetGem and pGem then
					petGemMult = pGem
				end
			end

			local totalEarnedCash = math.max(1, math.floor(baseValue * upgraderMult * rebirthMult * petCashMult))
			local bonusGemRoll = if (baseGems > 0 or math.random() <= 0.25) then math.max(1, baseGems) else 0
			local totalEarnedGems = math.floor(bonusGemRoll * petGemMult)

			-- Store into the Collector Bank!
			plotData.storedCash += totalEarnedCash
			plotData.storedGems += totalEarnedGems

			print(string.format("💰 [Plot %d] Ore collected: +$%d (Collector Stored: $%d, 💎 %d)", plotId, totalEarnedCash, plotData.storedCash, plotData.storedGems))

			TycoonService.updateCollectorUI(plotData)
			hit:Destroy()
		else
			-- If player walks onto the collector pad directly, allow them to claim too!
			local character = hit:FindFirstAncestorOfClass("Model")
			if character then
				local player = Players:GetPlayerFromCharacter(character)
				if player and plotData.owner == player then
					claimStoredCash(player)
				end
			end
		end
	end

	collectorPad.Touched:Connect(handleCrystalCollection)
	sensorCurtain.Touched:Connect(handleCrystalCollection)
	backWall.Touched:Connect(handleCrystalCollection)
	wallLeft.Touched:Connect(handleCrystalCollection)
	wallRight.Touched:Connect(handleCrystalCollection)

	-- Active spatial scanner backup loop: scans collector volume 4x per second so no crystal can ever be missed
	task.spawn(function()
		while model and model.Parent do
			task.wait(0.25)
			if collectorPad and collectorPad.Parent then
				local parts = Workspace:GetPartsInPart(collectorPad)
				for _, part in ipairs(parts) do
					if (part:GetAttribute("IsCrystal") or string.find(part.Name, "Crystal") ~= nil) and not part:GetAttribute("Collected") then
						handleCrystalCollection(part)
					end
				end
			end
			if sensorCurtain and sensorCurtain.Parent then
				local parts = Workspace:GetPartsInPart(sensorCurtain)
				for _, part in ipairs(parts) do
					if (part:GetAttribute("IsCrystal") or string.find(part.Name, "Crystal") ~= nil) and not part:GetAttribute("Collected") then
						handleCrystalCollection(part)
					end
				end
			end
		end
	end)

	-- Touch event for the Claim Cash Pad
	collectPad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player and plotData.owner == player then
			claimStoredCash(player)
		end
	end)

	-- Claim Pad Touch logic (for plot entrance)
	claimPad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player and not plotData.owner and not playerPlots[player] then
			print(string.format("🎯 [Plot %d] Claimed by player: %s", plotId, player.Name))
			TycoonService.claimPlot(plotData, player)
		end
	end)

	model.Parent = Workspace:FindFirstChild("Tycoons") or Workspace
	return plotData
end

function TycoonService.claimPlot(plot: Plot, player: Player)
	plot.owner = player
	playerPlots[player] = plot

	local claimPad = plot.model:FindFirstChild("ClaimPad")
	if claimPad then
		local billboard = claimPad:FindFirstChild("ClaimBillboard") :: BillboardGui?
		if billboard then
			local text = billboard:FindFirstChild("Text") :: TextLabel?
			if text then
				text.Text = player.DisplayName .. "'s Crystal Lab"
				text.TextColor3 = Color3.fromRGB(0, 255, 170)
			end
		end
	end

	-- Build plot based on player's saved data
	TycoonService.refreshPlotForPlayer(player)
end

function TycoonService.unclaimPlot(plot: Plot)
	for _, thread in plot.dropperThreads do
		task.cancel(thread)
	end
	plot.dropperThreads = {}

	plot.activeItems = {}
	plot.activeButtons = {}

	local itemsFolder = plot.model:FindFirstChild("PurchasedItems")
	if itemsFolder then itemsFolder:ClearAllChildren() end

	local buttonsFolder = plot.model:FindFirstChild("Buttons")
	if buttonsFolder then buttonsFolder:ClearAllChildren() end

	local crystalsFolder = plot.model:FindFirstChild("Crystals")
	if crystalsFolder then crystalsFolder:ClearAllChildren() end

	local claimPad = plot.model:FindFirstChild("ClaimPad")
	if claimPad then
		local billboard = claimPad:FindFirstChild("ClaimBillboard") :: BillboardGui?
		if billboard then
			local text = billboard:FindFirstChild("Text") :: TextLabel?
			if text then
				text.Text = "Touch to Claim Plot #" .. plot.id
				text.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	plot.storedCash = 0
	plot.storedGems = 0
	TycoonService.updateCollectorUI(plot)

	if plot.owner then
		playerPlots[plot.owner] = nil
	end
	plot.owner = nil
end

function TycoonService.spawnDropperCrystal(plot: Plot, dropperDef: TycoonConfig.DropperDef, spawnPos: Vector3)
	local crystalsFolder = plot.model:FindFirstChild("Crystals")
	if not crystalsFolder then return end

	local crystal = Instance.new("Part")
	crystal.Name = dropperDef.name .. "_Crystal"
	crystal.Size = Vector3.new(1.4, 1.4, 1.4)
	crystal.CFrame = CFrame.new(spawnPos)
	crystal.Color = dropperDef.crystalColor
	crystal.Material = dropperDef.crystalMaterial
	crystal.TopSurface = Enum.SurfaceType.Smooth
	crystal.BottomSurface = Enum.SurfaceType.Smooth
	crystal.Anchored = false
	crystal.CanCollide = true
	crystal.CanTouch = true
	-- Low friction physics so crystals smoothly travel along conveyor without sticking
	crystal.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.05, 0.2, 1, 1)

	crystal:SetAttribute("IsCrystal", true)
	crystal:SetAttribute("Value", dropperDef.crystalValue)
	crystal:SetAttribute("Multiplier", 1)
	crystal:SetAttribute("Gems", dropperDef.gemValue or 0)

	-- Glow attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = crystal

	local glow = Instance.new("PointLight")
	glow.Color = dropperDef.crystalColor
	glow.Brightness = 1.2
	glow.Range = 6
	glow.Parent = crystal

	crystal.Parent = crystalsFolder

	-- Lock network ownership to server so touch events and physics calculate 100% on server
	pcall(function()
		crystal:SetNetworkOwner(nil)
	end)

	-- Auto-cleanup if it falls out of bounds
	task.delay(20, function()
		if crystal and crystal.Parent then
			crystal:Destroy()
		end
	end)
end

function TycoonService.buildItem(plot: Plot, itemDef: TycoonConfig.ItemDef)
	if plot.activeItems[itemDef.id] then return end

	local itemsFolder = plot.model:FindFirstChild("PurchasedItems")
	if not itemsFolder then return end

	local itemModel = Instance.new("Model")
	itemModel.Name = itemDef.id

	if itemDef.category == "Dropper" then
		local dDef = itemDef :: TycoonConfig.DropperDef
		-- Position droppers progressively along the conveyor
		local dropperIndex = tonumber(string.match(itemDef.id, "%d+")) or 1
		local zOffset = -22 + ((dropperIndex - 1) * 8)
		local standPos = plot.origin + Vector3.new(0, 9, zOffset)

		-- Stand and dispenser
		local stand = createPart(itemModel, "Stand", Vector3.new(2, 8, 2), CFrame.new(plot.origin + Vector3.new(-6, 5, zOffset)), Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
		local arm = createPart(itemModel, "Arm", Vector3.new(6, 1.5, 2), CFrame.new(plot.origin + Vector3.new(-3, 8.5, zOffset)), Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
		local dispenser = createPart(itemModel, "Dispenser", Vector3.new(3.5, 2, 3.5), CFrame.new(standPos), dDef.crystalColor, Enum.Material.Neon)

		itemModel.Parent = itemsFolder
		plot.activeItems[itemDef.id] = itemModel

		-- Dropper loop
		local dropThread = task.spawn(function()
			while plot.owner and plot.activeItems[itemDef.id] do
				task.wait(dDef.dropInterval)
				TycoonService.spawnDropperCrystal(plot, dDef, standPos - Vector3.new(0, 1.8, 0))
			end
		end)
		plot.dropperThreads[itemDef.id] = dropThread

	elseif itemDef.category == "Upgrader" then
		local uDef = itemDef :: TycoonConfig.UpgraderDef
		local upgraderIndex = tonumber(string.match(itemDef.id, "%d+")) or 1
		local zOffset = -14 + ((upgraderIndex - 1) * 16)
		local archPos = plot.origin + Vector3.new(0, 3, zOffset)

		-- Arch frame
		createPart(itemModel, "PillarL", Vector3.new(1.2, 5, 2), CFrame.new(plot.origin + Vector3.new(-4.5, 3.5, zOffset)), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
		createPart(itemModel, "PillarR", Vector3.new(1.2, 5, 2), CFrame.new(plot.origin + Vector3.new(4.5, 3.5, zOffset)), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
		createPart(itemModel, "TopBar", Vector3.new(10, 1.2, 2), CFrame.new(plot.origin + Vector3.new(0, 6, zOffset)), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)

		-- Glowing laser field
		local laser = createPart(itemModel, "LaserField", Vector3.new(8, 4.5, 0.4), CFrame.new(plot.origin + Vector3.new(0, 3.5, zOffset)), uDef.laserColor, Enum.Material.ForceField, true, false)
		
		laser.Touched:Connect(function(hit)
			if hit:GetAttribute("IsCrystal") and not hit:GetAttribute("Upgraded_" .. uDef.id) then
				hit:SetAttribute("Upgraded_" .. uDef.id, true)
				local currentMult = (hit:GetAttribute("Multiplier") or 1) :: number
				hit:SetAttribute("Multiplier", currentMult * uDef.multiplier)
				hit.Color = uDef.laserColor
			end
		end)

		itemModel.Parent = itemsFolder
		plot.activeItems[itemDef.id] = itemModel

	elseif itemDef.category == "Structure" then
		-- Surrounding decorative neon walls
		local wallL = createPart(itemModel, "WallLeft", Vector3.new(2, 14, 68), CFrame.new(plot.origin + Vector3.new(-44, 8, 0)), Color3.fromRGB(30, 32, 40), Enum.Material.Glass)
		local wallR = createPart(itemModel, "WallRight", Vector3.new(2, 14, 68), CFrame.new(plot.origin + Vector3.new(44, 8, 0)), Color3.fromRGB(30, 32, 40), Enum.Material.Glass)
		local wallB = createPart(itemModel, "WallBack", Vector3.new(86, 14, 2), CFrame.new(plot.origin + Vector3.new(0, 8, -34)), Color3.fromRGB(30, 32, 40), Enum.Material.Glass)

		itemModel.Parent = itemsFolder
		plot.activeItems[itemDef.id] = itemModel
	end
end

function TycoonService.createButton(plot: Plot, itemDef: TycoonConfig.ItemDef)
	if plot.activeButtons[itemDef.id] then return end

	local buttonsFolder = plot.model:FindFirstChild("Buttons")
	if not buttonsFolder then return end

	-- Position buttons neatly in rows along the left/right aisles
	local itemIndex = 1
	for idx, item in ipairs(TycoonConfig.ITEMS) do
		if item.id == itemDef.id then
			itemIndex = idx
			break
		end
	end

	local side = if itemIndex % 2 == 0 then 1 else -1
	local row = math.floor((itemIndex - 1) / 2)
	local buttonPos = plot.origin + Vector3.new(side * 18, 1.2, -20 + (row * 10))

	local buttonPad = createPart(buttonsFolder, "Button_" .. itemDef.id, Vector3.new(5, 0.6, 5), CFrame.new(buttonPos), Color3.fromRGB(0, 170, 255), Enum.Material.Neon)
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ButtonGui"
	billboard.Size = UDim2.new(0, 160, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = itemDef.name
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Parent = billboard

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.5, 0)
	costLabel.Position = UDim2.new(0, 0, 0.5, 0)
	costLabel.BackgroundTransparency = 1
	local costText = if itemDef.cost == 0 then "FREE" else "💰 " .. FormatNumber.formatCompact(itemDef.cost)
	costLabel.Text = costText
	costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	costLabel.Font = Enum.Font.GothamBlack
	costLabel.TextSize = 15
	costLabel.TextStrokeTransparency = 0.2
	costLabel.Parent = billboard
	billboard.Parent = buttonPad

	plot.activeButtons[itemDef.id] = buttonPad

	-- Touch to purchase
	local debounced = false
	buttonPad.Touched:Connect(function(hit)
		if debounced then return end
		local character = hit.Parent
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player and plot.owner == player then
			debounced = true
			TycoonService.buyItem(player, itemDef.id)
			task.wait(1)
			debounced = false
		end
	end)
end

function TycoonService.buyItem(player: Player, itemId: string): boolean
	local plot = playerPlots[player]
	if not plot then return false end

	local data = DataService.get(player)
	if not data then return false end

	if data.UnlockedItems[itemId] then
		return false
	end

	local targetItem: TycoonConfig.ItemDef? = nil
	for _, item in ipairs(TycoonConfig.ITEMS) do
		if item.id == itemId then
			targetItem = item
			break
		end
	end

	if not targetItem then return false end

	-- Check prerequisite
	if targetItem.prerequisite and not data.UnlockedItems[targetItem.prerequisite] then
		return false
	end

	-- Check cost
	if data.Cash < targetItem.cost then
		return false
	end

	-- Deduct cash and record unlock
	DataService.addCash(player, -targetItem.cost)
	DataService.unlockItem(player, itemId)

	-- Remove button pad
	if plot.activeButtons[itemId] then
		plot.activeButtons[itemId]:Destroy()
		plot.activeButtons[itemId] = nil
	end

	-- Build the 3D item
	TycoonService.buildItem(plot, targetItem)

	-- Check for newly unlocked buttons
	TycoonService.refreshButtons(plot, data)

	local soundEvent = Remotes.getEvent("ItemPurchased")
	soundEvent:FireClient(player, targetItem.name, targetItem.cost)

	return true
end

function TycoonService.refreshButtons(plot: Plot, data: DataService.PlayerData)
	for _, item in ipairs(TycoonConfig.ITEMS) do
		local isUnlocked = data.UnlockedItems[item.id]
		local prereqMet = (item.prerequisite == nil) or data.UnlockedItems[item.prerequisite]

		if not isUnlocked and prereqMet then
			TycoonService.createButton(plot, item)
		end
	end
end

function TycoonService.refreshPlotForPlayer(player: Player)
	local plot = playerPlots[player]
	if not plot then return end

	local data = DataService.get(player)
	if not data then return end

	-- Build all unlocked items
	for _, item in ipairs(TycoonConfig.ITEMS) do
		if data.UnlockedItems[item.id] then
			TycoonService.buildItem(plot, item)
		end
	end

	-- Spawn available buttons
	TycoonService.refreshButtons(plot, data)
end

function TycoonService.resetPlotForPlayer(player: Player)
	local plot = playerPlots[player]
	if not plot then return end

	for _, thread in plot.dropperThreads do
		task.cancel(thread)
	end
	plot.dropperThreads = {}
	plot.activeItems = {}
	plot.activeButtons = {}

	local itemsFolder = plot.model:FindFirstChild("PurchasedItems")
	if itemsFolder then itemsFolder:ClearAllChildren() end

	local buttonsFolder = plot.model:FindFirstChild("Buttons")
	if buttonsFolder then buttonsFolder:ClearAllChildren() end

	local crystalsFolder = plot.model:FindFirstChild("Crystals")
	if crystalsFolder then crystalsFolder:ClearAllChildren() end

	plot.storedCash = 0
	plot.storedGems = 0
	TycoonService.updateCollectorUI(plot)

	TycoonService.refreshPlotForPlayer(player)
end

function TycoonService.init()
	local tycoonsFolder = Workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then
		tycoonsFolder = Instance.new("Folder")
		tycoonsFolder.Name = "Tycoons"
		tycoonsFolder.Parent = Workspace
	end

	-- Spawn Plots arranged neatly around the baseplate (Y=0 so floors rest directly on the baseplate)
	local offsets = {
		Vector3.new(-TycoonConfig.PLOT_SPACING / 2, 0, -TycoonConfig.PLOT_SPACING / 2),
		Vector3.new(TycoonConfig.PLOT_SPACING / 2, 0, -TycoonConfig.PLOT_SPACING / 2),
		Vector3.new(-TycoonConfig.PLOT_SPACING / 2, 0, TycoonConfig.PLOT_SPACING / 2),
		Vector3.new(TycoonConfig.PLOT_SPACING / 2, 0, TycoonConfig.PLOT_SPACING / 2),
	}

	for i = 1, TycoonConfig.PLOT_COUNT do
		plots[i] = TycoonService.createPlot(i, offsets[i])
	end

	-- Manual harvest remote function (Simulator clicker mechanic)
	local harvestRemote = Remotes.getFunction("ManualHarvest")
	harvestRemote.OnServerInvoke = function(player: Player)
		local data = DataService.get(player)
		if not data then return 0, 0 end

		local rebirthMult = RebirthConfig.getMultiplier(data.Rebirths)
		local petCashMult = PetService.getCashMultiplier(player)
		local petGemMult = PetService.getGemMultiplier(player)

		local earnedCash = math.floor(TycoonConfig.MANUAL_CLICK_CASH * rebirthMult * petCashMult)
		
		-- 10% chance for a Lucky Gem Strike (+5 Gems)
		local isCrit = math.random() <= 0.10
		local baseGems = if isCrit then 5 else TycoonConfig.MANUAL_CLICK_GEMS
		local earnedGems = math.floor(baseGems * petGemMult)

		DataService.addCash(player, earnedCash)
		DataService.addGems(player, earnedGems)

		return earnedCash, earnedGems
	end

	-- UI buy remote function
	local buyRemote = Remotes.getFunction("RequestBuyItem")
	buyRemote.OnServerInvoke = function(player: Player, itemId: string)
		return TycoonService.buyItem(player, itemId)
	end

	Players.PlayerRemoving:Connect(function(player)
		local plot = playerPlots[player]
		if plot then
			TycoonService.unclaimPlot(plot)
		end
	end)
end

return TycoonService
