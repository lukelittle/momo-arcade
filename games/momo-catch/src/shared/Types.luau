--!strict
-- Shared types for Momo Catch. Payload tables are what the server sends to clients.

export type RoundState = "Lobby" | "Countdown" | "Playing" | "GameOver"

export type MomoKind = "Normal" | "Golden" | "Burnt"

export type EndReason = "TimeUp" | "OutOfLives"

-- RemoteEvent StateChanged
export type StatePayload = {
	state: RoundState,
	-- Countdown
	countdownSeconds: number?,
	-- Countdown / Playing
	maxLives: number?,
	roundLength: number?,
	-- GameOver
	reason: EndReason?,
	score: number?,
	highScore: number?,
	isNewHighScore: boolean?,
	totalCaught: number?,
}

-- RemoteEvent HudUpdate
export type HudPayload = {
	score: number,
	lives: number,
	maxLives: number,
	timeLeft: number,
}

-- RemoteEvent MomoCaught
export type CatchPayload = {
	kind: MomoKind,
	position: Vector3,
	points: number,
	lives: number,
}

-- RemoteEvent EasterEgg
export type EasterEggPayload = {
	text: string,
	subtext: string,
	totalCaught: number,
}

return nil
