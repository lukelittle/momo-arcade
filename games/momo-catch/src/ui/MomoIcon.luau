--!strict
--[[
	MomoIcon: a tiny kawaii momo drawn with rounded frames (no image assets).
	Used for lives, the score pill and the title screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)

local Colors = Config.Colors
local create = UIHelpers.create

local MomoIcon = {}

local function circle(name: string, size: UDim2, position: UDim2, color: Color3, parent: Instance): Frame
	local frame = create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
	UIHelpers.corner(frame, UDim.new(0.5, 0))
	return frame
end

function MomoIcon.colorsFor(kind: Types.MomoKind): (Color3, Color3)
	if kind == "Golden" then
		return Colors.MomoGolden, Colors.MomoGoldenPleat
	elseif kind == "Burnt" then
		return Colors.MomoBurnt, Colors.MomoBurntPleat
	end
	return Colors.MomoNormal, Colors.MomoNormalPleat
end

-- `size` is the icon width in pixels; height is ~80% of that.
function MomoIcon.create(size: number, kind: Types.MomoKind?): Frame
	local root = create("Frame", {
		Name = "MomoIcon",
		Size = UDim2.fromOffset(size, size * 0.8),
		BackgroundTransparency = 1,
	}) :: Frame

	local bodyColor, pleatColor = MomoIcon.colorsFor(kind or "Normal")

	local body = circle("Body", UDim2.fromScale(1, 0.72), UDim2.fromScale(0.5, 0.62), bodyColor, root)
	UIHelpers.stroke(body, Colors.UiBrown, math.max(1, size / 28), 0.55)
	-- Pleats gathered at the top, then the little knot.
	for i, x in { 0.32, 0.5, 0.68 } do
		circle(
			"Pleat",
			UDim2.fromScale(0.26, 0.3),
			UDim2.fromScale(x, if i == 2 then 0.26 else 0.3),
			pleatColor,
			root
		)
	end
	circle("Knot", UDim2.fromScale(0.18, 0.2), UDim2.fromScale(0.5, 0.12), pleatColor, root)

	-- Face
	local eyeColor = if kind == "Burnt" then Color3.fromRGB(250, 220, 200) else Colors.UiBrown
	circle("Eye", UDim2.fromScale(0.09, 0.11), UDim2.fromScale(0.37, 0.6), eyeColor, root)
	circle("Eye", UDim2.fromScale(0.09, 0.11), UDim2.fromScale(0.63, 0.6), eyeColor, root)
	local blush = Color3.fromRGB(255, 170, 185)
	for _, x in { 0.25, 0.75 } do
		local cheek = circle("Blush", UDim2.fromScale(0.13, 0.08), UDim2.fromScale(x, 0.72), blush, root)
		cheek.BackgroundTransparency = 0.3
	end

	return root
end

-- Recolours an icon (e.g. grey it out when a life is lost).
function MomoIcon.paint(icon: Frame, bodyColor: Color3, pleatColor: Color3, faceTransparency: number?)
	for _, child in icon:GetChildren() do
		if not child:IsA("Frame") then
			continue
		end
		if child.Name == "Body" then
			child.BackgroundColor3 = bodyColor
		elseif child.Name == "Pleat" or child.Name == "Knot" then
			child.BackgroundColor3 = pleatColor
		elseif child.Name == "Eye" then
			child.BackgroundTransparency = faceTransparency or 0
		elseif child.Name == "Blush" then
			child.BackgroundTransparency = math.max(0.3, faceTransparency or 0)
		end
	end
end

return MomoIcon
