--!strict
--[[
	WorldBuilder: builds the whole cozy arena from primitives at server start.

	- Round grassy arena (with an invisible wall so nobody walks off)
	- A little Nepali tea-house stall ("Momo Ghar")
	- Prayer flags strung between poles
	- Rolling hills, pastel trees and low-poly mountains in the distance
	- Soft, warm lighting with Atmosphere

	Nothing here uses external assets: only parts, materials and built-in effects.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.MomoCatch.Config)

local Colors = Config.Colors
local ARENA = Config.Arena
local GROUND_Y = ARENA.GroundY
local CENTER = Vector3.new(ARENA.Center.X, GROUND_Y, ARENA.Center.Z)

local WorldBuilder = {}

-- Fixed seed so the decorations look the same every time.
local random = Random.new(20240611)

type PartProps = { [string]: any }

local function makePart(parent: Instance, props: PartProps): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Decorative parts nobody needs to collide with or raycast against.
local function decor(parent: Instance, props: PartProps): Part
	local part = makePart(parent, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Cylinders in Roblox lie along X; this rotates one to stand upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function cylinder(
	parent: Instance,
	center: CFrame,
	height: number,
	diameter: number,
	props: PartProps
): Part
	local part = makePart(parent, props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = center * UPRIGHT
	return part
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

--------------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------------
local function buildLighting()
	-- Replace any default post effects so the look is consistent.
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("BloomEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("DepthOfFieldEffect")
			or child:IsA("BlurEffect")
		then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 16.2 -- warm late afternoon
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(150, 128, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 170, 165)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 196)
	Lighting.ColorShift_Bottom = Color3.fromRGB(200, 180, 230)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(255, 220, 226)
	atmosphere.Decay = Color3.fromRGB(196, 176, 232)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.04
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 249, 242)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.04
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
end

--------------------------------------------------------------------------------
-- Ground, arena and boundary
--------------------------------------------------------------------------------
local function buildGround(root: Instance)
	local ground = folder("Ground", root)

	-- Big meadow that fills the view, a little below the arena.
	makePart(ground, {
		Name = "Meadow",
		Size = Vector3.new(2048, 4, 2048),
		CFrame = CFrame.new(CENTER.X, GROUND_Y - 2.6, CENTER.Z),
		Material = Enum.Material.Grass,
		Color = Colors.Meadow,
	})

	-- Raised wooden-edged rim, then the grassy arena on top.
	cylinder(ground, CFrame.new(CENTER + Vector3.new(0, -1.1, 0)), 1.8, ARENA.Radius * 2 + 4, {
		Name = "ArenaRim",
		Material = Enum.Material.WoodPlanks,
		Color = Colors.ArenaRim,
	})
	cylinder(ground, CFrame.new(CENTER + Vector3.new(0, -1, 0)), 2, ARENA.Radius * 2, {
		Name = "Arena",
		Material = Enum.Material.Grass,
		Color = Colors.Grass,
	})

	-- Invisible wall so players can't wander off the arena.
	local wall = folder("Boundary", ground)
	local segments = 36
	local wallRadius = ARENA.Radius + 1
	local segmentWidth = 2 * math.pi * wallRadius / segments + 0.5
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local position = CENTER + Vector3.new(math.cos(angle) * wallRadius, 10, math.sin(angle) * wallRadius)
		makePart(wall, {
			Name = "Wall",
			Size = Vector3.new(segmentWidth, 24, 1),
			CFrame = CFrame.lookAt(position, Vector3.new(CENTER.X, position.Y, CENTER.Z)),
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
		})
	end

	-- Little flowers dotted around the arena edge and the meadow.
	local flowers = folder("Flowers", ground)
	for _ = 1, 90 do
		local angle = random:NextNumber(0, math.pi * 2)
		local onArena = random:NextNumber() < 0.45
		local distance = if onArena
			then random:NextNumber(ARENA.Radius * 0.6, ARENA.Radius - 2)
			else random:NextNumber(ARENA.Radius + 6, ARENA.Radius + 70)
		local y = if onArena then GROUND_Y else GROUND_Y - 0.6
		local position = CENTER
			+ Vector3.new(math.cos(angle) * distance, y + 0.25, math.sin(angle) * distance)
		local flowerColors = Colors.Flowers
		decor(flowers, {
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * random:NextNumber(0.5, 0.9),
			Position = position,
			Color = flowerColors[random:NextInteger(1, #flowerColors)],
			CastShadow = false,
		})
	end
end

--------------------------------------------------------------------------------
-- Tea house stall
--------------------------------------------------------------------------------
local function buildTeaHouse(root: Instance)
	local stall = Instance.new("Model")
	stall.Name = "TeaHouse"
	stall.Parent = root

	-- The stall sits at the back edge of the arena and faces the centre (-Z is front).
	local position = CENTER + Vector3.new(0, 0, -(ARENA.Radius - 9))
	local base = CFrame.lookAt(position, CENTER)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	local width, depth, wallHeight = 16, 10, 7.5

	-- Floor
	makePart(stall, {
		Name = "Floor",
		Size = Vector3.new(width, 0.6, depth),
		CFrame = at(0, 0.3, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Colors.Wood,
	})
	-- Back wall
	makePart(stall, {
		Name = "BackWall",
		Size = Vector3.new(width, wallHeight, 0.6),
		CFrame = at(0, wallHeight / 2 + 0.6, depth / 2 - 0.3),
		Color = Colors.Wall,
	})
	-- Carved-wood window on the back wall (classic Newari style, simplified)
	decor(stall, {
		Name = "Window",
		Size = Vector3.new(4, 2.6, 0.3),
		CFrame = at(0, 4.6, depth / 2 - 0.7),
		Color = Colors.WoodDark,
		Material = Enum.Material.Wood,
	})
	for i = -1, 1 do
		decor(stall, {
			Name = "WindowBar",
			Size = Vector3.new(0.25, 2.6, 0.2),
			CFrame = at(i * 1, 4.6, depth / 2 - 0.9),
			Color = Colors.Wood,
			Material = Enum.Material.Wood,
		})
	end
	-- Corner posts
	for _, x in { -width / 2 + 0.5, width / 2 - 0.5 } do
		for _, z in { -depth / 2 + 0.5, depth / 2 - 0.5 } do
			makePart(stall, {
				Name = "Post",
				Size = Vector3.new(0.8, wallHeight, 0.8),
				CFrame = at(x, wallHeight / 2 + 0.6, z),
				Material = Enum.Material.Wood,
				Color = Colors.WoodDark,
			})
		end
	end
	-- Counter at the front
	makePart(stall, {
		Name = "Counter",
		Size = Vector3.new(width - 3, 3, 1.6),
		CFrame = at(0, 2.1, -depth / 2 + 1.5),
		Material = Enum.Material.WoodPlanks,
		Color = Colors.Wood,
	})
	makePart(stall, {
		Name = "CounterTop",
		Size = Vector3.new(width - 2.4, 0.3, 2.1),
		CFrame = at(0, 3.75, -depth / 2 + 1.5),
		Color = Colors.Wall,
	})

	-- Gable roof made of two tilted slabs (no wedge orientation guesswork).
	local roofAngle = math.rad(26)
	local slabLength = depth / 2 / math.cos(roofAngle) + 1.6
	local ridgeY = wallHeight + 0.6 + (depth / 2) * math.tan(roofAngle) + 0.4
	for _, side in { -1, 1 } do
		local z = side * (slabLength / 2) * math.cos(roofAngle)
		local y = ridgeY - (slabLength / 2) * math.sin(roofAngle)
		makePart(stall, {
			Name = "Roof",
			Size = Vector3.new(width + 2, 0.5, slabLength),
			CFrame = at(0, y, z) * CFrame.Angles(side * roofAngle, 0, 0),
			Color = Colors.Roof,
			Material = Enum.Material.Slate,
		})
	end
	-- Ridge beam
	makePart(stall, {
		Name = "Ridge",
		Size = Vector3.new(width + 2.4, 0.6, 0.6),
		CFrame = at(0, ridgeY + 0.1, 0),
		Material = Enum.Material.Wood,
		Color = Colors.WoodDark,
	})

	-- Sign above the counter: "Momo Ghar" means "momo house".
	local sign = makePart(stall, {
		Name = "Sign",
		Size = Vector3.new(8, 1.8, 0.3),
		CFrame = at(0, wallHeight - 0.3, -depth / 2 - 0.2),
		Color = Colors.UiPink,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 50
	signGui.LightInfluence = 0.2
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.BackgroundTransparency = 1
	signText.Size = UDim2.fromScale(1, 1)
	signText.Text = "Momo Ghar 🥟"
	signText.TextScaled = true
	signText.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.Parent = signGui

	-- Steamer stacks on the counter
	local counterTop = 3.9
	for _, x in { -4.5, -2.6, 3.8 } do
		local stackHeight = random:NextInteger(2, 4)
		for level = 1, stackHeight do
			cylinder(stall, at(x, counterTop + (level - 0.5) * 0.7, -depth / 2 + 1.5), 0.6, 1.7, {
				Name = "Steamer",
				Material = Enum.Material.Wood,
				Color = if level % 2 == 0 then Colors.Bamboo else Colors.BambooDark,
			})
		end
		cylinder(stall, at(x, counterTop + stackHeight * 0.7 + 0.15, -depth / 2 + 1.5), 0.3, 1.5, {
			Name = "SteamerLid",
			Color = Colors.Bamboo,
		})
	end
	-- A plate of momos on the counter
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		local momo = decor(stall, {
			Name = "PlateMomo",
			Size = Vector3.new(0.8, 0.55, 0.8),
			CFrame = at(
				0.8 + math.cos(angle) * 0.55,
				counterTop + 0.35,
				-depth / 2 + 1.5 + math.sin(angle) * 0.55
			),
			Color = Colors.MomoNormal,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = momo
	end
	cylinder(stall, at(0.8, counterTop + 0.05, -depth / 2 + 1.5), 0.1, 2.2, {
		Name = "Plate",
		Color = Color3.new(1, 1, 1),
	})
	-- Kettle
	local kettle = decor(stall, {
		Name = "Kettle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		CFrame = at(-0.9, counterTop + 0.5, -depth / 2 + 1.5),
		Color = Color3.fromRGB(196, 132, 96),
		Material = Enum.Material.Metal,
	})
	kettle.Reflectance = 0.1

	-- Paper lanterns hanging from the roof corners
	for _, x in { -width / 2 + 1.4, width / 2 - 1.4 } do
		decor(stall, {
			Name = "LanternString",
			Size = Vector3.new(0.1, 1.2, 0.1),
			CFrame = at(x, wallHeight - 0.1, -depth / 2 - 0.4),
			Color = Colors.WoodDark,
		})
		local lantern = decor(stall, {
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.3,
			CFrame = at(x, wallHeight - 1.2, -depth / 2 - 0.4),
			Color = if x < 0 then Color3.fromRGB(255, 170, 190) else Color3.fromRGB(255, 220, 150),
			Material = Enum.Material.Neon,
		})
		local light = Instance.new("PointLight")
		light.Color = lantern.Color
		light.Range = 12
		light.Brightness = 1.2
		light.Parent = lantern
	end

	-- Stools in front of the counter
	for _, x in { -4, 0, 4 } do
		cylinder(stall, at(x, 0.9, -depth / 2 - 1.6), 1.8, 0.4, {
			Name = "StoolLeg",
			Color = Colors.WoodDark,
		})
		cylinder(stall, at(x, 1.9, -depth / 2 - 1.6), 0.3, 1.6, {
			Name = "StoolSeat",
			Color = Colors.UiPink,
		})
	end
end

--------------------------------------------------------------------------------
-- Prayer flags
--------------------------------------------------------------------------------
local function buildPrayerFlags(root: Instance)
	local flags = folder("PrayerFlags", root)
	local poleHeight = 15
	local poleRadius = ARENA.Radius - 2
	-- Poles around the arena, leaving a gap behind the tea house (which is at -Z).
	local poleAngles = { -45, 0, 45, 90, 135, 180, 225 }
	local tops: { Vector3 } = {}
	for _, degrees in poleAngles do
		-- Angles are measured so 270 degrees would be the tea house side.
		local angle = math.rad(degrees)
		local foot = CENTER + Vector3.new(math.cos(angle) * poleRadius, 0, math.sin(angle) * poleRadius)
		cylinder(flags, CFrame.new(foot + Vector3.new(0, poleHeight / 2, 0)), poleHeight, 0.6, {
			Name = "Pole",
			Material = Enum.Material.Wood,
			Color = Colors.Wood,
		})
		decor(flags, {
			Name = "PoleCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.1,
			Position = foot + Vector3.new(0, poleHeight + 0.4, 0),
			Color = Colors.UiGold,
		})
		table.insert(tops, foot + Vector3.new(0, poleHeight - 0.4, 0))
	end

	local flagColors = Colors.PrayerFlags
	local function hangFlagLine(a: Vector3, b: Vector3)
		local count = math.max(6, math.floor((b - a).Magnitude / 1.8))
		local sag = math.min(3.5, (b - a).Magnitude * 0.08)
		local function pointAt(t: number): Vector3
			return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		end
		local previous = pointAt(0)
		for i = 1, count do
			local t = i / count
			local point = pointAt(t)
			local segment = point - previous
			decor(flags, {
				Name = "String",
				Size = Vector3.new(0.08, 0.08, segment.Magnitude),
				CFrame = CFrame.lookAt(previous:Lerp(point, 0.5), point),
				Color = Color3.fromRGB(240, 230, 210),
				CastShadow = false,
			})
			if i < count then
				local direction = segment.Unit
				local normal = direction:Cross(Vector3.yAxis)
				if normal.Magnitude < 1e-3 then
					normal = Vector3.xAxis
				end
				local flagCenter = point - Vector3.new(0, 0.85, 0)
				decor(flags, {
					Name = "Flag",
					Size = Vector3.new(1.2, 1.5, 0.05),
					CFrame = CFrame.lookAt(flagCenter, flagCenter + normal.Unit),
					Color = flagColors[(i - 1) % #flagColors + 1],
					Material = Enum.Material.Fabric,
					CastShadow = false,
				})
			end
			previous = point
		end
	end

	for i = 1, #tops - 1 do
		hangFlagLine(tops[i], tops[i + 1])
	end
	-- One long line across the middle, high above the play area.
	hangFlagLine(tops[2] + Vector3.new(0, 0.3, 0), tops[6] + Vector3.new(0, 0.3, 0))
end

--------------------------------------------------------------------------------
-- Scenery: hills, trees, mountains
--------------------------------------------------------------------------------
local function buildScenery(root: Instance)
	local scenery = folder("Scenery", root)

	-- Soft rolling hills: big spheres mostly sunk into the meadow.
	for _ = 1, 16 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(150, 260)
		local size = random:NextNumber(70, 140)
		local sink = size * random:NextNumber(0.32, 0.4)
		local hill = decor(scenery, {
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = CENTER
				+ Vector3.new(math.cos(angle) * distance, size / 2 - sink * 1.4, math.sin(angle) * distance),
			Material = Enum.Material.Grass,
			Color = Colors.Meadow:Lerp(Colors.Grass, random:NextNumber()),
		})
		hill.CanCollide = false
	end

	-- Round pastel trees around the meadow.
	local treeColors = {
		Color3.fromRGB(140, 210, 150),
		Color3.fromRGB(255, 196, 214),
		Color3.fromRGB(170, 220, 120),
	}
	for _ = 1, 22 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(ARENA.Radius + 14, ARENA.Radius + 90)
		local foot = CENTER + Vector3.new(math.cos(angle) * distance, -0.6, math.sin(angle) * distance)
		local height = random:NextNumber(5, 9)
		cylinder(scenery, CFrame.new(foot + Vector3.new(0, height / 2, 0)), height, 1.2, {
			Name = "Trunk",
			Material = Enum.Material.Wood,
			Color = Colors.WoodDark,
		})
		local canopy = random:NextNumber(6, 10)
		decor(scenery, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * canopy,
			Position = foot + Vector3.new(0, height + canopy * 0.3, 0),
			Material = Enum.Material.Grass,
			Color = treeColors[random:NextInteger(1, #treeColors)],
		})
	end

	-- Low-poly mountains: stacked, twisted blocks that taper into snowy peaks.
	local function mountain(position: Vector3, baseWidth: number, height: number)
		local tiers = 6
		local tierHeight = height / tiers
		for tier = 0, tiers - 1 do
			local t = tier / tiers
			local width = baseWidth * (1 - t * 0.82)
			local snowy = tier >= tiers - 2
			decor(scenery, {
				Name = "Mountain",
				Size = Vector3.new(width, tierHeight * 1.15, width),
				CFrame = CFrame.new(position + Vector3.new(0, tierHeight * (tier + 0.5), 0))
					* CFrame.Angles(0, random:NextNumber(0, math.pi / 2), 0),
				Material = if snowy then Enum.Material.Snow else Enum.Material.Slate,
				Color = if snowy
					then Colors.Snow
					else Colors.Mountain:Lerp(Colors.MountainDark, random:NextNumber()),
				CastShadow = false,
			})
		end
	end

	-- A range mostly behind the tea house (-Z), wrapping around the sides.
	for i = 0, 9 do
		local angle = math.rad(-170 + i * 18 + random:NextNumber(-6, 6))
		local distance = random:NextNumber(420, 620)
		local position = CENTER + Vector3.new(math.cos(angle) * distance, -2, math.sin(angle) * distance)
		mountain(position, random:NextNumber(220, 360), random:NextNumber(160, 280))
	end
end

--------------------------------------------------------------------------------
-- Spawn point
--------------------------------------------------------------------------------
local function buildSpawn(root: Instance)
	-- Remove the Baseplate template's default floor and spawn, which would sit
	-- inside our arena. (Only ever touches objects with these exact names.)
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child.Name == "SpawnLocation" then
			child:Destroy()
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MomoSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(CENTER + Vector3.new(0, 0.1, 14))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field bubble
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	spawn.Parent = root
end

function WorldBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("MomoArena")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "MomoArena"

	buildLighting()
	buildGround(root)
	buildTeaHouse(root)
	buildPrayerFlags(root)
	buildScenery(root)
	buildSpawn(root)

	root.Parent = Workspace

	Players.RespawnTime = 2
	return root
end

-- Folder that holds every falling momo (created once, shared by all rounds).
function WorldBuilder.getMomoFolder(): Folder
	local existing = Workspace:FindFirstChild("MomoCatchMomos")
	if existing and existing:IsA("Folder") then
		return existing
	end
	return folder("MomoCatchMomos", Workspace)
end

return WorldBuilder
