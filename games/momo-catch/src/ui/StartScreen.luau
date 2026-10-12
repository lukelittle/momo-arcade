--!strict
-- StartScreen: title card with how-to-play, the Play button, and personal stats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local TweenHelpers = require(ReplicatedStorage.Shared.TweenHelpers)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)
local MomoIcon = require(script.Parent.MomoIcon)

local Colors = Config.Colors
local Fonts = UIHelpers.Fonts
local create = UIHelpers.create

export type StartScreen = {
	root: Frame,
	playButton: TextButton,
	show: () -> (),
	hide: () -> (),
	setStats: (highScore: number, totalCaught: number) -> (),
	setReady: (ready: boolean) -> (),
}

local StartScreen = {}

function StartScreen.create(parent: Instance, onPlay: () -> ()): StartScreen
	local root = create("Frame", {
		Name = "StartScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame

	-- The holder fits the card to the screen; the card itself is free to pop/animate.
	-- (Two UIScales on one object conflict, so they live on different frames.)
	local holder = create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 600),
		BackgroundTransparency = 1,
		Parent = root,
	}) :: Frame
	UIHelpers.autoScale(holder, 760, 0.45, 1.3)

	local card = create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.UiCream,
		BackgroundTransparency = 0.04,
		Parent = holder,
	}) :: Frame
	UIHelpers.corner(card, UDim.new(0, 40))
	UIHelpers.stroke(card, Colors.UiPink, 6)
	UIHelpers.padding(card, 28)
	UIHelpers.list(card, Enum.FillDirection.Vertical, 14)

	-- The title sits in its own frame so it can bob without fighting the list layout.
	local titleSlot = create("Frame", {
		Name = "TitleSlot",
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = card,
	})
	local title = UIHelpers.label({
		Text = "Momo Catch",
		Size = UDim2.fromScale(1, 1),
		TextSize = 96,
		Font = Fonts.Title,
		TextColor = Colors.UiPink,
		Parent = titleSlot,
	})
	UIHelpers.stroke(title, Colors.UiPinkDark, 3)

	-- "How to play" row: one icon per momo type with its value.
	local row = create("Frame", {
		Name = "Legend",
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = card,
	}) :: Frame
	UIHelpers.list(row, Enum.FillDirection.Horizontal, 36)
	local legend: { { kind: Types.MomoKind, caption: string } } = {
		{ kind = "Normal", caption = `+{Config.Points.Normal}` },
		{ kind = "Golden", caption = `+{Config.Points.Golden}` },
		{ kind = "Burnt", caption = "Ouch! -1 life" },
	}
	for index, entry in legend do
		local cell = create("Frame", {
			Size = UDim2.fromOffset(150, 120),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = row,
		})
		local icon = MomoIcon.create(84, entry.kind)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0)
		icon.Parent = cell
		UIHelpers.label({
			Text = entry.caption,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 80),
			TextSize = 26,
			Font = Fonts.BodyHeavy,
			TextColor = if entry.kind == "Burnt" then Colors.UiPinkDark else Colors.UiBrown,
			Parent = cell,
		})
	end

	UIHelpers.label({
		Text = "Move under the falling momos to catch them in your basket. Dodge the burnt ones!",
		Size = UDim2.new(1, 0, 0, 72),
		TextSize = 26,
		TextColor = Colors.UiBrown,
		LayoutOrder = 3,
		Parent = card,
	})

	local ready = false
	local playButton = UIHelpers.button({
		Text = "Play!",
		Size = UDim2.fromOffset(300, 92),
		Color = Colors.UiMint,
		TextColor = Color3.new(1, 1, 1),
		StrokeColor = Colors.UiMintDark,
		TextSize = 54,
		LayoutOrder = 4,
		Parent = card,
		OnActivated = function()
			if ready then
				onPlay()
			end
		end,
	})

	local stats = UIHelpers.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 24,
		TextColor = Colors.UiBrown,
		LayoutOrder = 5,
		Parent = card,
	})

	local bobTween: Tween? = nil

	local screen: StartScreen = {
		root = root,
		playButton = playButton,
		show = function()
			root.Visible = true
			TweenHelpers.popIn(card, 0.45)
			if not bobTween then
				bobTween = TweenHelpers.bob(title, 6, 1.6)
			end
		end,
		hide = function()
			root.Visible = false
		end,
		setStats = function(highScore: number, totalCaught: number)
			stats.Text = `Best score: {highScore}   ·   Momos caught: {totalCaught}`
		end,
		setReady = function(isReady: boolean)
			ready = isReady
			playButton.Text = if isReady then "Play!" else "Loading…"
			playButton.BackgroundColor3 = if isReady then Colors.UiMint else Colors.UiGrey
		end,
	}
	screen.setReady(false)
	screen.setStats(0, 0)
	return screen
end

return StartScreen
