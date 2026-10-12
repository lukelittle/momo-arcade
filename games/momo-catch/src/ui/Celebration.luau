--!strict
--[[
	Celebration: the full-screen easter-egg message with falling confetti.
	Builds its own ScreenGui (above everything, ignoring the top-bar inset) and
	cleans itself up when closed.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Trove = require(ReplicatedStorage.Shared.Trove)
local TweenHelpers = require(ReplicatedStorage.Shared.TweenHelpers)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)
local MomoIcon = require(script.Parent.MomoIcon)

local Colors = Config.Colors
local Fonts = UIHelpers.Fonts
local create = UIHelpers.create

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 143, 171),
	Color3.fromRGB(255, 214, 102),
	Color3.fromRGB(140, 220, 190),
	Color3.fromRGB(170, 190, 255),
	Color3.fromRGB(220, 170, 255),
	Color3.fromRGB(255, 255, 255),
}

local Celebration = {}

local active: Trove.Trove? = nil

local function spawnConfetti(layer: Frame, random: Random)
	local piece = create("Frame", {
		Name = "Confetti",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(random:NextInteger(10, 18), random:NextInteger(6, 10)),
		Position = UDim2.fromScale(random:NextNumber(0, 1), -0.05),
		Rotation = random:NextNumber(0, 360),
		BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)],
		BorderSizePixel = 0,
		Parent = layer,
	}) :: Frame
	if random:NextNumber() < 0.4 then
		UIHelpers.corner(piece, UDim.new(0.5, 0))
	end
	local duration = random:NextNumber(2.4, 4.4)
	local tween = TweenHelpers.play(piece, TweenHelpers.info(duration, Enum.EasingStyle.Linear), {
		Position = piece.Position + UDim2.fromScale(random:NextNumber(-0.12, 0.12), 1.12),
		Rotation = piece.Rotation + random:NextNumber(-540, 540),
	})
	tween.Completed:Once(function()
		piece:Destroy()
	end)
end

function Celebration.isOpen(): boolean
	return active ~= nil
end

function Celebration.close()
	local trove = active
	active = nil
	if trove then
		trove:Clean()
	end
end

-- Shows the message. `onClose` runs once when it is dismissed (button or timeout).
function Celebration.show(playerGui: Instance, text: string, subtext: string, onClose: (() -> ())?)
	Celebration.close()
	local trove = Trove.new()
	active = trove

	local gui = trove:Add(create("ScreenGui", {
		Name = "MomoCelebration",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui)

	local backdrop = create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.08,
		Parent = gui,
	}) :: Frame
	UIHelpers.gradient(backdrop, Color3.fromRGB(255, 205, 220), Color3.fromRGB(215, 200, 255))

	local confettiLayer = create("Frame", {
		Name = "Confetti",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = gui,
	}) :: Frame

	local holder = create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 560),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	}) :: Frame
	UIHelpers.autoScale(holder, 760, 0.4, 1.3)

	local content = create("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	}) :: Frame
	UIHelpers.list(content, Enum.FillDirection.Vertical, 18)

	local icons = create("Frame", {
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	})
	UIHelpers.list(icons, Enum.FillDirection.Horizontal, 20)
	for i = 1, 5 do
		local icon = MomoIcon.create(if i == 3 then 120 else 80, if i == 3 then "Golden" else "Normal")
		icon.LayoutOrder = i
		icon.Parent = icons
	end

	local title = UIHelpers.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 190),
		TextSize = 92,
		Font = Fonts.Title,
		TextColor = Colors.UiPinkDark,
		LayoutOrder = 2,
		Parent = content,
	})
	UIHelpers.stroke(title, Color3.new(1, 1, 1), 5)

	UIHelpers.label({
		Text = subtext,
		Size = UDim2.new(1, 0, 0, 56),
		TextSize = 36,
		TextColor = Colors.UiBrown,
		LayoutOrder = 3,
		Parent = content,
	})

	local closed = false
	local function finish()
		if closed then
			return
		end
		closed = true
		if active == trove then
			Celebration.close()
		end
		if onClose then
			onClose()
		end
	end
	trove:Add(finish) -- closing for any reason counts as finishing

	local button = UIHelpers.button({
		Text = "Aww, thank you! ❤️",
		Size = UDim2.fromOffset(420, 90),
		Color = Colors.UiPink,
		TextColor = Color3.new(1, 1, 1),
		StrokeColor = Colors.UiPinkDark,
		TextSize = 40,
		LayoutOrder = 4,
		Parent = content,
		OnActivated = finish,
	})

	gui.Parent = playerGui
	TweenHelpers.popIn(content, 0.6)
	TweenHelpers.bob(title, 8, 1.4)
	GuiService.SelectedObject = button
	trove:Add(function()
		if GuiService.SelectedObject == button then
			GuiService.SelectedObject = nil
		end
	end)

	-- Confetti: a big first burst, then a steady sprinkle until closed.
	local random = Random.new()
	trove:Add(task.spawn(function()
		for _ = 1, 90 do
			spawnConfetti(confettiLayer, random)
			if random:NextNumber() < 0.3 then
				task.wait()
			end
		end
		while true do
			task.wait(0.12)
			spawnConfetti(confettiLayer, random)
		end
	end))

	trove:Add(task.delay(Config.EasterEgg.AutoCloseSeconds, finish))
end

return Celebration
