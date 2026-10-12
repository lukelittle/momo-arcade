--!strict
--[[
	TweenHelpers: short wrappers around TweenService for common UI/world animations.
]]

local TweenService = game:GetService("TweenService")

local TweenHelpers = {}

export type Props = { [string]: any }

function TweenHelpers.info(
	seconds: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	repeatCount: number?,
	reverses: boolean?
): TweenInfo
	return TweenInfo.new(
		seconds,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		repeatCount or 0,
		reverses or false
	)
end

-- Creates and plays a tween. Accepts a TweenInfo or just a duration in seconds.
function TweenHelpers.play(instance: Instance, info: TweenInfo | number, props: Props): Tween
	local tweenInfo = if typeof(info) == "number" then TweenHelpers.info(info) else info
	local tween = TweenService:Create(instance, tweenInfo, props)
	tween:Play()
	return tween
end

-- Returns (creating if needed) a UIScale named "TweenScale" on a GUI object.
function TweenHelpers.getScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("TweenScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "TweenScale"
	scale.Parent = gui
	return scale
end

-- A quick bouncy "boing": grows to `amount` then settles back to 1.
function TweenHelpers.pop(gui: GuiObject, amount: number?)
	local scale = TweenHelpers.getScale(gui)
	scale.Scale = amount or 1.2
	TweenHelpers.play(scale, TweenHelpers.info(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
end

-- Scales a GUI object in from 0 with a little overshoot.
function TweenHelpers.popIn(gui: GuiObject, seconds: number?)
	local scale = TweenHelpers.getScale(gui)
	scale.Scale = 0
	TweenHelpers.play(
		scale,
		TweenHelpers.info(seconds or 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Scale = 1,
		}
	)
end

-- Gentle endless up/down bob, handy for titles. Returns the tween so callers can cancel it.
function TweenHelpers.bob(gui: GuiObject, pixels: number, seconds: number): Tween
	local start = gui.Position
	return TweenHelpers.play(
		gui,
		TweenHelpers.info(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = start + UDim2.fromOffset(0, -pixels) }
	)
end

return TweenHelpers
