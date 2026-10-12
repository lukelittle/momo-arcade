--!strict
--[[
	Momo Catch: every tunable lives here.

	Safe to edit while `rojo serve` is running: save the file, then stop and press
	Play again in Studio. Numbers are in seconds and studs unless noted.
]]

local Config = {}

--------------------------------------------------------------------------------
-- Rounds
--------------------------------------------------------------------------------
Config.Round = {
	LengthSeconds = 60, -- how long a round lasts
	CountdownSeconds = 3, -- "3, 2, 1, Go!" before momos start falling
	StartingLives = 3, -- burnt momos caught before game over
}

--------------------------------------------------------------------------------
-- Difficulty: each value eases from Start to End over the round.
--------------------------------------------------------------------------------
Config.Difficulty = {
	SpawnIntervalStart = 1.1, -- seconds between momos at the start
	SpawnIntervalEnd = 0.38, -- ...and by the end of the round
	FallSpeedStart = 11, -- studs per second at the start
	FallSpeedEnd = 24, -- ...and by the end of the round
	RampExponent = 1.4, -- 1 = linear ramp; >1 = gentle start, spicier finish
}

--------------------------------------------------------------------------------
-- Momo variants and points
--------------------------------------------------------------------------------
Config.Variants = {
	GoldenChance = 0.08, -- ~8% of momos are golden
	BurntChanceStart = 0.15, -- ~15% burnt at the start...
	BurntChanceEnd = 0.28, -- ...rising to this by the end
}

Config.Points = {
	Normal = 1,
	Golden = 5,
}

Config.BurntLivesLost = 1

--------------------------------------------------------------------------------
-- Spawning and catching
--------------------------------------------------------------------------------
Config.Spawning = {
	Height = 42, -- studs above the ground where momos appear
	RadiusAroundPlayer = 18, -- momos drop within this distance of their player
	MaxActivePerPlayer = 24, -- hard cap on falling momos per player
	MaxLifetimeSeconds = 12, -- safety net: anything older is removed
	SpinSpeed = 2.2, -- radians/second around the vertical axis
	WobbleAmount = 1.6, -- how much they tip side to side while falling
	SwayStuds = 1.2, -- gentle horizontal drift (studs/second)
}

Config.Catch = {
	Radius = 4.5, -- forgiving horizontal catch distance from the basket centre
	BelowTolerance = 1.5, -- a momo slightly below the rim still counts
	AboveTolerance = 3.5, -- ...and so does one just above it
}

Config.Basket = {
	-- Where the basket sits relative to the HumanoidRootPart (forward is -Z).
	Offset = CFrame.new(0, 0.25, -2.3),
	Diameter = 3.6,
	Height = 1.2,
}

--------------------------------------------------------------------------------
-- Arena
--------------------------------------------------------------------------------
Config.Arena = {
	Center = Vector3.new(0, 0, 0),
	Radius = 55, -- grassy circle players can walk on
	GroundY = 0, -- top surface of the arena
	DespawnMargin = 12, -- momos this far outside the arena are removed
}

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------
Config.Data = {
	StoreName = "MomoCatch_v1", -- change the suffix to wipe everyone's progress
	KeyPrefix = "player_",
	Retries = 3,
	RetryBaseDelay = 1, -- seconds; doubles each retry
}

Config.Remote = {
	RequestCooldown = 1, -- StartRound / PlayAgain can be sent at most once per second
}

--------------------------------------------------------------------------------
-- Easter egg
--------------------------------------------------------------------------------
Config.EasterEgg = {
	Threshold = 100, -- all-time momos caught needed to trigger it (once, ever)
	Text = "Dherai maya, Sujan! 🥟",
	Subtext = "100 momos caught. You're the momo champion!",
	AutoCloseSeconds = 12,
}

--------------------------------------------------------------------------------
-- Sounds
-- Only Roblox's built-in rbxasset:// sounds (they ship with every Roblox client),
-- so nothing can be moderated away or go missing. Pitch is changed with
-- PlaybackSpeed to make cute variations.
-- To use a Roblox-made sound from the Creator Store instead, swap Id for
-- "rbxassetid://<number>".
--------------------------------------------------------------------------------
export type SoundSpec = {
	Id: string,
	Volume: number,
	PlaybackSpeed: number,
}

Config.Sounds = {
	-- Short UI blip pitched up: a soft "pop" when a momo lands in the basket.
	Catch = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.8, PlaybackSpeed = 1.5 } :: SoundSpec,
	-- Same blip, higher still: a sparkly "ding" for golden momos.
	GoldenCatch = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 1, PlaybackSpeed = 2.1 } :: SoundSpec,
	-- Roblox's built-in "ouch", slowed a little so it sounds sad rather than hurt.
	Burnt = { Id = "rbxasset://sounds/ouch.ogg", Volume = 0.7, PlaybackSpeed = 0.85 } :: SoundSpec,
	-- Low blip for each countdown number.
	CountdownTick = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.7, PlaybackSpeed = 1 } :: SoundSpec,
	-- Bouncy jump sound for "Go!".
	CountdownGo = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.8, PlaybackSpeed = 1.2 } :: SoundSpec,
	-- Soft landing thump when the round ends.
	RoundOver = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, PlaybackSpeed = 0.8 } :: SoundSpec,
	-- Button clicks.
	Click = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.6, PlaybackSpeed = 1.2 } :: SoundSpec,
	-- Note used for the little rising chime on a new high score / easter egg.
	Chime = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.8, PlaybackSpeed = 1 } :: SoundSpec,
}

--------------------------------------------------------------------------------
-- Colours (soft pastels)
--------------------------------------------------------------------------------
Config.Colors = {
	-- Momos
	MomoNormal = Color3.fromRGB(255, 244, 226),
	MomoNormalPleat = Color3.fromRGB(240, 222, 196),
	MomoGolden = Color3.fromRGB(255, 206, 84),
	MomoGoldenPleat = Color3.fromRGB(245, 180, 60),
	MomoBurnt = Color3.fromRGB(92, 58, 40),
	MomoBurntPleat = Color3.fromRGB(64, 40, 28),

	-- Basket
	Bamboo = Color3.fromRGB(226, 190, 128),
	BambooDark = Color3.fromRGB(186, 142, 86),
	BasketInside = Color3.fromRGB(140, 102, 62),

	-- World
	Grass = Color3.fromRGB(150, 214, 140),
	Meadow = Color3.fromRGB(128, 196, 128),
	ArenaRim = Color3.fromRGB(214, 176, 138),
	Wood = Color3.fromRGB(176, 124, 86),
	WoodDark = Color3.fromRGB(112, 72, 50),
	Wall = Color3.fromRGB(252, 238, 222),
	Roof = Color3.fromRGB(222, 116, 104),
	Mountain = Color3.fromRGB(176, 170, 214),
	MountainDark = Color3.fromRGB(150, 146, 196),
	Snow = Color3.fromRGB(250, 250, 255),
	-- Prayer flags in their traditional order: blue, white, red, green, yellow.
	PrayerFlags = {
		Color3.fromRGB(110, 160, 235),
		Color3.fromRGB(250, 250, 250),
		Color3.fromRGB(240, 110, 110),
		Color3.fromRGB(110, 200, 130),
		Color3.fromRGB(250, 220, 90),
	},
	Flowers = {
		Color3.fromRGB(255, 182, 206),
		Color3.fromRGB(255, 240, 160),
		Color3.fromRGB(200, 180, 255),
		Color3.fromRGB(255, 255, 255),
	},

	-- UI
	UiCream = Color3.fromRGB(255, 249, 240),
	UiPink = Color3.fromRGB(255, 143, 171),
	UiPinkDark = Color3.fromRGB(214, 92, 128),
	UiMint = Color3.fromRGB(120, 210, 170),
	UiMintDark = Color3.fromRGB(70, 160, 125),
	UiGold = Color3.fromRGB(255, 200, 80),
	UiBrown = Color3.fromRGB(110, 76, 62),
	UiGrey = Color3.fromRGB(200, 190, 185),
}

return Config
