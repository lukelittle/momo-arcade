--!strict
-- EndScreen: final score (counts up), a "New high score!" badge, stats and Play Again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local TweenHelpers = require(ReplicatedStorage.Shared.TweenHelpers)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)

local Colors = Config.Colors
local Fonts = UIHelpers.Fonts
local create = UIHelpers.create

export type EndScreen = {
	root: Frame,
	playButton: TextButton,
	show: (payload: Types.StatePayload) -> (),
	hide: () -> (),
}

local EndScreen = {}

function EndScreen.create(parent: Instance, onPlayAgain: () -> ()): EndScreen
	local root = create("Frame", {
		Name = "EndScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	}) :: Frame

	local holder = create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 580),
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
	UIHelpers.padding(card, 26)
	UIHelpers.list(card, Enum.FillDirection.Vertical, 10)

	local heading = UIHelpers.label({
		Text = "Time's up!",
		Size = UDim2.new(1, 0, 0, 80),
		TextSize = 66,
		Font = Fonts.Title,
		TextColor = Colors.UiPink,
		LayoutOrder = 1,
		Parent = card,
	})
	UIHelpers.stroke(heading, Colors.UiPinkDark, 2)

	UIHelpers.label({
		Text = "Your score",
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		TextColor = Colors.UiBrown,
		LayoutOrder = 2,
		Parent = card,
	})

	local scoreLabel = UIHelpers.label({
		Text = "0",
		Size = UDim2.new(1, 0, 0, 120),
		TextSize = 120,
		Font = Fonts.Title,
		TextColor = Colors.UiBrown,
		LayoutOrder = 3,
		Parent = card,
	})

	-- Badge slot keeps the layout steady whether or not the badge is visible.
	local badgeSlot = create("Frame", {
		Name = "BadgeSlot",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = card,
	}) :: Frame
	local badge = create("TextLabel", {
		Name = "NewHighScore",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 58),
		Rotation = -4,
		BackgroundColor3 = Colors.UiGold,
		Text = "New high score! ✨",
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = Fonts.Title,
		TextSize = 34,
		Visible = false,
		Parent = badgeSlot,
	}) :: TextLabel
	UIHelpers.corner(badge, UDim.new(0.5, 0))
	UIHelpers.stroke(badge, Color3.fromRGB(230, 160, 40), 4)

	local stats = UIHelpers.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 24,
		TextColor = Colors.UiBrown,
		LayoutOrder = 5,
		Parent = card,
	})

	local playButton = UIHelpers.button({
		Text = "Play Again",
		Size = UDim2.fromOffset(320, 90),
		Color = Colors.UiMint,
		TextColor = Color3.new(1, 1, 1),
		StrokeColor = Colors.UiMintDark,
		TextSize = 46,
		LayoutOrder = 6,
		Parent = card,
		OnActivated = onPlayAgain,
	})

	-- Animated count-up for the score.
	local counter = Instance.new("NumberValue")
	counter.Parent = root
	counter.Changed:Connect(function(value: number)
		scoreLabel.Text = tostring(math.floor(value + 0.5))
	end)
	local badgeTween: Tween? = nil

	return {
		root = root,
		playButton = playButton,
		show = function(payload: Types.StatePayload)
			local score = payload.score or 0
			heading.Text = if payload.reason == "OutOfLives" then "Out of lives!" else "Time's up!"
			stats.Text =
				`Best score: {payload.highScore or score}   ·   Momos caught: {payload.totalCaught or 0}`

			root.Visible = true
			TweenHelpers.popIn(card, 0.45)

			counter.Value = 0
			scoreLabel.Text = "0"
			TweenHelpers.play(counter, TweenHelpers.info(math.clamp(score / 40, 0.4, 1.4)), { Value = score })

			if badgeTween then
				badgeTween:Cancel()
				badgeTween = nil
			end
			badge.Visible = payload.isNewHighScore == true
			if badge.Visible then
				badge.Rotation = -4
				TweenHelpers.popIn(badge, 0.6)
				badgeTween = TweenHelpers.play(
					badge,
					TweenHelpers.info(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Rotation = 4 }
				)
			end
		end,
		hide = function()
			root.Visible = false
			if badgeTween then
				badgeTween:Cancel()
				badgeTween = nil
			end
		end,
	}
end

return EndScreen
