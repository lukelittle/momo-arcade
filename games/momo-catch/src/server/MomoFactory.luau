--!strict
--[[
	MomoFactory: builds momo models out of parts.

	A momo is a squished cream ellipsoid with a ring of little pleats gathered into a
	knot on top. Golden momos sparkle and glow; burnt ones are dark and smoke.

	Momos are unanchored and moved by physics constraints (owned by the server), so
	clients see smooth, interpolated motion:
	  - LinearVelocity "Fall" sets the falling speed (plus a gentle sway)
	  - AngularVelocity "Spin" spins and wobbles them
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)

local Colors = Config.Colors
-- Every size and offset below is for a 1x momo; this scales the whole model so they
-- read clearly on a phone screen.
local SCALE = Config.Spawning.MomoScale

export type Momo = {
	model: Model,
	body: BasePart,
	fall: LinearVelocity,
	spin: AngularVelocity,
	kind: Types.MomoKind,
}

local MomoFactory = {}

local PLEAT_COUNT = 7

local function ellipsoid(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * SCALE
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function colorsFor(kind: Types.MomoKind): (Color3, Color3)
	if kind == "Golden" then
		return Colors.MomoGolden, Colors.MomoGoldenPleat
	elseif kind == "Burnt" then
		return Colors.MomoBurnt, Colors.MomoBurntPleat
	end
	return Colors.MomoNormal, Colors.MomoNormalPleat
end

-- Builds a momo at `cframe` (not yet parented). Call `MomoFactory.launch` after parenting.
function MomoFactory.create(kind: Types.MomoKind, cframe: CFrame, ownerUserId: number): Momo
	local bodyColor, pleatColor = colorsFor(kind)

	local model = Instance.new("Model")
	model.Name = `Momo_{kind}`
	model:SetAttribute("Kind", kind)
	model:SetAttribute("OwnerUserId", ownerUserId)

	local body = ellipsoid("Body", Vector3.new(2.4, 1.6, 2.4), bodyColor)
	body.CFrame = cframe
	body.Parent = model
	model.PrimaryPart = body

	local function attach(part: BasePart, offset: CFrame)
		part.CFrame = cframe * (offset.Rotation + offset.Position * SCALE)
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	-- Pleats: small ellipsoids in a ring, leaning inward to meet at the top.
	for i = 1, PLEAT_COUNT do
		local angle = (i / PLEAT_COUNT) * math.pi * 2
		local pleat = ellipsoid("Pleat", Vector3.new(0.55, 0.95, 0.38), pleatColor)
		attach(
			pleat,
			CFrame.Angles(0, -angle, 0) * CFrame.new(0.45, 0.55, 0) * CFrame.Angles(0, 0, math.rad(38))
		)
	end
	attach(ellipsoid("Knot", Vector3.new(0.5, 0.4, 0.5), pleatColor), CFrame.new(0, 0.95, 0))

	if kind == "Golden" then
		body.Reflectance = 0.15
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 236, 140)
		sparkles.Parent = body
		local light = Instance.new("PointLight")
		light.Color = Colors.MomoGolden
		light.Range = 8 * SCALE
		light.Brightness = 1.5
		light.Parent = body
	elseif kind == "Burnt" then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(70, 60, 60)
		smoke.Opacity = 0.25
		smoke.Size = 1.2 * SCALE
		smoke.RiseVelocity = 3
		smoke.Parent = body
	end

	-- Physics movers
	local attachment = Instance.new("Attachment")
	attachment.Name = "Root"
	attachment.Parent = body

	local fall = Instance.new("LinearVelocity")
	fall.Name = "Fall"
	fall.Attachment0 = attachment
	fall.RelativeTo = Enum.ActuatorRelativeTo.World
	fall.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	-- Big but finite: math.huge forces/torques can destabilise the solver on tiny parts.
	fall.MaxForce = 1e6
	fall.VectorVelocity = Vector3.zero
	fall.Parent = body

	local spin = Instance.new("AngularVelocity")
	spin.Name = "Spin"
	spin.Attachment0 = attachment
	spin.RelativeTo = Enum.ActuatorRelativeTo.World
	spin.MaxTorque = 1e6
	spin.AngularVelocity = Vector3.zero
	spin.Parent = body

	return {
		model = model,
		body = body,
		fall = fall,
		spin = spin,
		kind = kind,
	}
end

-- After the momo is parented into Workspace: let the server simulate it so every
-- client sees the same smooth motion (and no client can move it).
function MomoFactory.launch(momo: Momo, velocity: Vector3)
	momo.fall.VectorVelocity = velocity
	if momo.body:IsDescendantOf(workspace) then
		pcall(function()
			momo.body:SetNetworkOwner(nil)
		end)
	end
end

return MomoFactory
