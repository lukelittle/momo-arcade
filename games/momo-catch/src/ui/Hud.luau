--!strict
-- Hud: score, timer and lives (as little momo icons), plus the countdown and a
-- soft red flash when a burnt momo is caught.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local TweenHelpers = require(ReplicatedStorage.Shared.TweenHelpers)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)
local MomoIcon = require(script.Parent.MomoIcon)

local Colors = Config.Colors
local Fonts = UIHelpers.Fonts
local create = UIHelpers.create

export type Hud = {
	root: Frame,
	show: () -> (),
	hide: () -> (),
	reset: (maxLives: number, roundLength: number) -> (),
	setScore: (score: number) -> (),
	setTime: (secondsLeft: number) -> (),
	setLives: (lives: number, maxLives: number) -> (),
	showCountdown: (text: string) -> (),
	flashDamage: () -> (),
}

local Hud = {}

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function pill(name: string, width: number, order: number, parent: Instance): Frame
	local frame = create("Frame", {
		Name = name,
		Size = UDim2.fromOffset(width, 76),
		BackgroundColor3 = Colors.UiCream,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		Parent = parent,
	}) :: Frame
	UIHelpers.corner(frame, UDim.new(0.5, 0))
	UIHelpers.stroke(frame, Colors.UiPink, 4)
	UIHelpers.list(frame, Enum.FillDirection.Horizontal, 8)
	return frame
end

function Hud.create(parent: Instance): Hud
	local root = create("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	}) :: Frame

	-- Damage flash (behind everything else in the HUD)
	local flash = create("Frame", {
		Name = "DamageFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 120, 120),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = root,
	}) :: Frame

	-- Top bar
	local bar = create("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(660, 84),
		BackgroundTransparency = 1,
		Parent = root,
	}) :: Frame
	UIHelpers.list(bar, Enum.FillDirection.Horizontal, 16)
	-- Min 0.4 so the whole bar fits a 320px-wide phone. The ScreenGui keeps clear of the
	-- Roblox top bar and notches (IgnoreGuiInset = false, ScreenInsets = CoreUISafeInsets).
	UIHelpers.autoScale(bar, 900, 0.4, 1.2)

	-- Score
	local scorePill = pill("Score", 200, 1, bar)
	local scoreIcon = MomoIcon.create(52)
	scoreIcon.LayoutOrder = 1
	scoreIcon.Parent = scorePill
	local scoreLabel = UIHelpers.label({
		Text = "0",
		Size = UDim2.fromOffset(110, 60),
		TextSize = 48,
		Font = Fonts.Title,
		TextColor = Colors.UiBrown,
		LayoutOrder = 2,
		Parent = scorePill,
	})

	-- Timer
	local timerPill = pill("Timer", 180, 2, bar)
	local timerLabel = UIHelpers.label({
		Text = "1:00",
		Size = UDim2.fromOffset(150, 60),
		TextSize = 48,
		Font = Fonts.Title,
		TextColor = Colors.UiBrown,
		Parent = timerPill,
	})

	-- Lives
	local livesPill = pill("Lives", 240, 3, bar)
	local lifeIcons: { Frame } = {}

	-- Countdown in the middle of the screen
	local countdown = UIHelpers.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(500, 220),
		TextSize = 170,
		Font = Fonts.Title,
		TextColor = Color3.new(1, 1, 1),
		Parent = root,
	})
	UIHelpers.stroke(countdown, Colors.UiPinkDark, 6)
	countdown.Visible = false

	local shownScore = 0
	local shownSeconds = -1
	local shownLives = -1

	local function buildLives(maxLives: number)
		for _, icon in lifeIcons do
			icon:Destroy()
		end
		table.clear(lifeIcons)
		for i = 1, maxLives do
			local icon = MomoIcon.create(56)
			icon.LayoutOrder = i
			icon.Parent = livesPill
			table.insert(lifeIcons, icon)
		end
		livesPill.Size = UDim2.fromOffset(math.max(120, maxLives * 64 + 32), 76)
	end

	local hud: Hud
	hud = {
		root = root,
		show = function()
			root.Visible = true
		end,
		hide = function()
			root.Visible = false
			countdown.Visible = false
		end,
		reset = function(maxLives: number, roundLength: number)
			shownScore = 0
			shownSeconds = -1
			shownLives = -1
			scoreLabel.Text = "0"
			timerLabel.Text = formatTime(roundLength)
			timerLabel.TextColor3 = Colors.UiBrown
			flash.BackgroundTransparency = 1
			buildLives(maxLives)
			hud.setLives(maxLives, maxLives)
		end,
		setScore = function(score: number)
			if score == shownScore then
				return
			end
			local increased = score > shownScore
			shownScore = score
			scoreLabel.Text = tostring(score)
			if increased then
				TweenHelpers.pop(scorePill, 1.15)
			end
		end,
		setTime = function(secondsLeft: number)
			if secondsLeft == shownSeconds then
				return
			end
			shownSeconds = secondsLeft
			timerLabel.Text = formatTime(secondsLeft)
			local hurry = secondsLeft <= 10
			timerLabel.TextColor3 = if hurry then Colors.UiPinkDark else Colors.UiBrown
			if hurry and secondsLeft > 0 then
				TweenHelpers.pop(timerPill, 1.12)
			end
		end,
		setLives = function(lives: number, maxLives: number)
			if #lifeIcons ~= maxLives then
				buildLives(maxLives)
			end
			local lostOne = shownLives > lives
			for i, icon in lifeIcons do
				if i <= lives then
					MomoIcon.paint(icon, Colors.MomoNormal, Colors.MomoNormalPleat, 0)
				else
					MomoIcon.paint(icon, Colors.UiGrey, Colors.UiGrey, 0.7)
				end
			end
			if lostOne then
				local lost = lifeIcons[lives + 1]
				if lost then
					TweenHelpers.pop(lost, 1.5)
				end
			end
			shownLives = lives
		end,
		showCountdown = function(text: string)
			countdown.Text = text
			countdown.Visible = true
			countdown.TextTransparency = 0
			TweenHelpers.pop(countdown, 1.6)
			TweenHelpers.play(
				countdown,
				TweenHelpers.info(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					TextTransparency = 1,
				}
			)
		end,
		flashDamage = function()
			flash.BackgroundTransparency = 0.55
			TweenHelpers.play(flash, 0.45, { BackgroundTransparency = 1 })
		end,
	}
	return hud
end

return Hud
