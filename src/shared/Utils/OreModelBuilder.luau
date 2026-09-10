--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

export type OreModelData = {
	model: Model,
	corePart: Part,
	sides: { [number]: { BasePart } },
}

local OreModelBuilder = {}

-- Utility to create authentic retro stud or smooth parts
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
	part.Material = material or Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = if canCollide ~= nil then canCollide else false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- ====================================================================
-- BUILD MULTIFACETED ORE MODEL
-- ====================================================================
function OreModelBuilder.buildOreModel(
	oreId: string,
	name: string,
	color: Color3,
	accentColor: Color3,
	scale: number,
	position: Vector3,
	zone: string?
): OreModelData
	local model = Instance.new("Model")
	model.Name = oreId

	local isMagma = (zone == "Zone2" or string.find(name:lower(), "magma") ~= nil or string.find(name:lower(), "molten") ~= nil)
	local isCosmic = (zone == "Zone3" or string.find(name:lower(), "void") ~= nil or string.find(name:lower(), "cosmic") ~= nil)

	local rockMaterial = if isMagma then Enum.Material.CrackedLava
		elseif isCosmic then Enum.Material.Basalt
		else Enum.Material.Slate

	local rockColor = if isMagma then Color3.fromRGB(45, 30, 25)
		elseif isCosmic then Color3.fromRGB(30, 25, 42)
		else Color3.fromRGB(85, 90, 100):Lerp(color, 0.25)

	-- 1. CENTRAL MULTI-SIDED BOULDER CORE
	local coreHeight = 3.2 * scale
	local coreWidth = 3.6 * scale
	local coreSize = Vector3.new(coreWidth, coreHeight, coreWidth)
	local coreCF = CFrame.new(position + Vector3.new(0, coreHeight / 2, 0))

	local corePart = createPart(model, "OreCore", coreSize, coreCF, rockColor, rockMaterial, true)
	corePart.TopSurface = Enum.SurfaceType.Studs
	model.PrimaryPart = corePart

	-- 2. ANGLED PERIMETER ROCK FACETS (Creates an 8-sided craggy polygonal boulder silhouette)
	local facetAngles = { 0, 45, 90, 135, 180, 225, 270, 315 }
	for i, deg in ipairs(facetAngles) do
		local rad = math.rad(deg)
		local facetDist = (coreWidth * 0.44)
		local facetOffset = Vector3.new(math.sin(rad) * facetDist, -0.1 * scale, math.cos(rad) * facetDist)
		local facetSize = Vector3.new(1.7 * scale, coreHeight * 0.9, 0.7 * scale)
		local facetCF = coreCF * CFrame.new(facetOffset) * CFrame.Angles(0, rad, math.rad(-14))

		local facetPart = createPart(model, "RockFacet_" .. i, facetSize, facetCF, rockColor, rockMaterial, true)
		facetPart.TopSurface = Enum.SurfaceType.Studs

		-- Subtle rocky bevel color variation
		if i % 2 == 0 then
			facetPart.Color = rockColor:Lerp(Color3.fromRGB(20, 22, 28), 0.15)
		end
	end

	-- 3. EMBEDDED GLOWING ORE VEINS (Neon crystal ribbons running in crevasses between rock facets)
	for v = 1, 4 do
		local vAngle = (v - 1) * 90 + 22.5
		local vRad = math.rad(vAngle)
		local vDist = (coreWidth * 0.46)
		local veinSize = Vector3.new(0.28 * scale, coreHeight * 0.75, 0.42 * scale)
		local veinCF = coreCF * CFrame.new(math.sin(vRad) * vDist, 0, math.cos(vRad) * vDist) * CFrame.Angles(0, vRad, math.rad(-10))

		local vein = createPart(model, "OreVein_" .. v, veinSize, veinCF, accentColor, Enum.Material.Neon, false)
	end

	-- 4. CRAGGY BASE FOOTERS (Anchors ore naturally to ground terrain)
	local footers = {
		{ offset = Vector3.new(1.6, -coreHeight * 0.38, 1.4) * scale, size = Vector3.new(1.8, 0.8, 1.8) * scale, rot = 30 },
		{ offset = Vector3.new(-1.5, -coreHeight * 0.38, -1.3) * scale, size = Vector3.new(1.7, 0.8, 1.7) * scale, rot = -40 },
		{ offset = Vector3.new(1.4, -coreHeight * 0.38, -1.5) * scale, size = Vector3.new(1.6, 0.8, 1.6) * scale, rot = 65 },
		{ offset = Vector3.new(-1.6, -coreHeight * 0.38, 1.3) * scale, size = Vector3.new(1.7, 0.8, 1.7) * scale, rot = -25 },
	}
	for fIdx, fInfo in ipairs(footers) do
		local footPart = createPart(model, "RockFooter_" .. fIdx, fInfo.size, coreCF * CFrame.new(fInfo.offset) * CFrame.Angles(0, math.rad(fInfo.rot), 0), rockColor, rockMaterial, true)
	end

	-- 5. MULTI-SIDED CRYSTAL SPIRE CLUSTERS (Categorized into 5 distinct sides for staggered popping)
	-- Side 1: Front / North
	-- Side 2: Right / East
	-- Side 3: Back / South
	-- Side 4: Left / West
	-- Side 5: Crown / Top Apex
	local sides: { [number]: { BasePart } } = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
	}

	local crystalColors = { accentColor, color }

	local sideClusterConfigs = {
		-- SIDE 1: FRONT (North, Z > 0)
		[1] = {
			{ offset = Vector3.new(0, 0.25, 1.4) * scale, angles = Vector3.new(32, 0, 0), size = Vector3.new(1.05, 2.3, 1.05) * scale, isMain = true },
			{ offset = Vector3.new(-0.75, -0.1, 1.25) * scale, angles = Vector3.new(22, -25, -15), size = Vector3.new(0.65, 1.6, 0.65) * scale },
			{ offset = Vector3.new(0.7, -0.15, 1.2) * scale, angles = Vector3.new(24, 30, 18), size = Vector3.new(0.6, 1.45, 0.6) * scale },
		},
		-- SIDE 2: RIGHT (East, X > 0)
		[2] = {
			{ offset = Vector3.new(1.4, 0.3, 0) * scale, angles = Vector3.new(0, 0, -32), size = Vector3.new(1.05, 2.2, 1.05) * scale, isMain = true },
			{ offset = Vector3.new(1.25, -0.05, -0.7) * scale, angles = Vector3.new(-20, 22, -25), size = Vector3.new(0.65, 1.5, 0.65) * scale },
			{ offset = Vector3.new(1.2, -0.1, 0.75) * scale, angles = Vector3.new(18, -25, -22), size = Vector3.new(0.6, 1.4, 0.6) * scale },
		},
		-- SIDE 3: BACK (South, Z < 0)
		[3] = {
			{ offset = Vector3.new(0, 0.25, -1.4) * scale, angles = Vector3.new(-32, 0, 0), size = Vector3.new(1.05, 2.3, 1.05) * scale, isMain = true },
			{ offset = Vector3.new(0.75, -0.1, -1.25) * scale, angles = Vector3.new(-22, 25, 15), size = Vector3.new(0.65, 1.6, 0.65) * scale },
			{ offset = Vector3.new(-0.7, -0.15, -1.2) * scale, angles = Vector3.new(-24, -30, -18), size = Vector3.new(0.6, 1.45, 0.6) * scale },
		},
		-- SIDE 4: LEFT (West, X < 0)
		[4] = {
			{ offset = Vector3.new(-1.4, 0.3, 0) * scale, angles = Vector3.new(0, 0, 32), size = Vector3.new(1.05, 2.2, 1.05) * scale, isMain = true },
			{ offset = Vector3.new(-1.25, -0.05, 0.7) * scale, angles = Vector3.new(20, -22, 25), size = Vector3.new(0.65, 1.5, 0.65) * scale },
			{ offset = Vector3.new(-1.2, -0.1, -0.75) * scale, angles = Vector3.new(-18, 25, 22), size = Vector3.new(0.6, 1.4, 0.6) * scale },
		},
		-- SIDE 5: CROWN / TOP APEX PINNACLE
		[5] = {
			{ offset = Vector3.new(0, coreHeight * 0.45, 0) * scale, angles = Vector3.new(0, 45, 0), size = Vector3.new(1.15, 2.7, 1.15) * scale, isMain = true },
			{ offset = Vector3.new(-0.4, coreHeight * 0.38, 0.4) * scale, angles = Vector3.new(16, 20, -12), size = Vector3.new(0.75, 1.9, 0.75) * scale },
			{ offset = Vector3.new(0.4, coreHeight * 0.38, -0.4) * scale, angles = Vector3.new(-16, -20, 12), size = Vector3.new(0.7, 1.8, 0.7) * scale },
		},
	}

	for sideIdx = 1, 5 do
		local shardList = sideClusterConfigs[sideIdx]
		for sIdx, sInfo in ipairs(shardList) do
			local targetSize = sInfo.size
			local targetCF = coreCF * CFrame.new(sInfo.offset) * CFrame.Angles(
				math.rad(sInfo.angles.X),
				math.rad(sInfo.angles.Y),
				math.rad(sInfo.angles.Z)
			)

			local crystalColor = if sInfo.isMain then accentColor else crystalColors[(sIdx % #crystalColors) + 1]
			local crystalMaterial = Enum.Material.Neon

			local shard = createPart(
				model,
				string.format("CrystalSpire_Side%d_%d", sideIdx, sIdx),
				targetSize,
				targetCF,
				crystalColor,
				crystalMaterial,
				false
			)

			-- SpecialMesh bevel for pointed crystal prism
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Wedge
			mesh.Scale = Vector3.new(1.0, 1.0, 1.0)
			mesh.Parent = shard

			-- Store target attributes for animation
			shard:SetAttribute("TargetSize", targetSize)
			shard:SetAttribute("TargetCFrame", targetCF)
			shard:SetAttribute("SideIndex", sideIdx)
			shard:SetAttribute("IsMainSpire", sInfo.isMain == true)

			table.insert(sides[sideIdx], shard)
		end
	end

	-- 6. AMBIENT POINT LIGHT & SPARKLE PARTICLES
	local light = Instance.new("PointLight")
	light.Color = accentColor
	light.Brightness = 2.2
	light.Range = 14 * scale
	light.Parent = corePart

	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, coreHeight * 0.45, 0)
	attach.Parent = corePart

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "OreSparkles"
	sparkles.Texture = "rbxassetid://244199991"
	sparkles.Color = ColorSequence.new(accentColor, color)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25 * scale),
		NumberSequenceKeypoint.new(0.5, 0.55 * scale),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Lifetime = NumberRange.new(1.2, 2.0)
	sparkles.Rate = 6 * scale
	sparkles.Speed = NumberRange.new(1.2, 2.8)
	sparkles.SpreadAngle = Vector2.new(45, 45)
	sparkles.Acceleration = Vector3.new(0, 2.0, 0)
	sparkles.LightEmission = 0.95
	sparkles.Parent = attach

	return {
		model = model,
		corePart = corePart,
		sides = sides,
	}
end

-- ====================================================================
-- STAGGERED SPROUT ANIMATION: Pops up little by little on each side
-- ====================================================================
function OreModelBuilder.animateSprout(sides: { [number]: { BasePart } }, delayBetweenSides: number?)
	local stepDelay = delayBetweenSides or 0.09

	-- Initially set all crystals to near-zero scale
	for sideIdx = 1, 5 do
		local parts = sides[sideIdx]
		if parts then
			for _, part in ipairs(parts) do
				local targetCF = part:GetAttribute("TargetCFrame") :: CFrame?
				if targetCF then
					part.Size = Vector3.new(0.05, 0.05, 0.05)
					part.CFrame = targetCF * CFrame.new(0, -0.6, 0)
				end
			end
		end
	end

	-- Sequentially pop out side-by-side with bouncy elastic easing
	task.spawn(function()
		for sideIdx = 1, 5 do
			local parts = sides[sideIdx]
			if parts then
				for _, part in ipairs(parts) do
					local targetSize = part:GetAttribute("TargetSize") :: Vector3?
					local targetCF = part:GetAttribute("TargetCFrame") :: CFrame?
					if targetSize and targetCF then
						TweenService:Create(part, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Size = targetSize,
							CFrame = targetCF,
						}):Play()
					end
				end
			end
			task.wait(stepDelay)
		end
	end)
end

return OreModelBuilder
