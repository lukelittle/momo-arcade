--!strict
--[[
	RoundSession: one player's game of Momo Catch. The server owns all of it.

	State machine:
		Lobby --Start()--> Countdown --(timer)--> Playing --(time up / no lives)--> GameOver
		GameOver --Start()--> Countdown ...

	Everything round-related (the Heartbeat connection and every falling momo) lives in
	`roundTrove`, so ending the round, the player leaving, or Destroy() all clean up
	the same way. Nothing in here yields, so there are no races with players leaving
	mid-wait: each Heartbeat simply checks the session is still alive first.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Remotes = require(ReplicatedStorage.MomoCatch.Remotes)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local Score = require(ReplicatedStorage.Shared.Score)
local Timer = require(ReplicatedStorage.Shared.Timer)
local Trove = require(ReplicatedStorage.Shared.Trove)

local BasketService = require(script.Parent.BasketService)
local DataService = require(script.Parent.DataService)
local MomoFactory = require(script.Parent.MomoFactory)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ARENA = Config.Arena
local CENTER = Vector3.new(ARENA.Center.X, ARENA.GroundY, ARENA.Center.Z)
local DESPAWN_RADIUS = ARENA.Radius + ARENA.DespawnMargin
local WOBBLE_UPDATE_INTERVAL = 0.2 -- seconds; keeps replication traffic low

type ActiveMomo = {
	momo: MomoFactory.Momo,
	age: number,
	phase: number,
	speed: number,
	swayDirection: Vector3,
	nextWobbleUpdate: number,
}

type SessionData = {
	player: Player,
	state: Types.RoundState,
	roundTrove: Trove.Trove,
	countdown: Timer.Timer,
	timer: Timer.Timer,
	score: Score.Score,
	lives: number,
	momos: { ActiveMomo },
	spawnIn: number,
	lastSecondSent: number,
	random: Random,
	destroyed: boolean,
}

local RoundSession = {}
RoundSession.__index = RoundSession

export type RoundSession = typeof(setmetatable({} :: SessionData, RoundSession))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- 0..1 round progress -> 0..1 difficulty, eased by Config.Difficulty.RampExponent.
local function difficultyAt(progress: number): number
	return math.clamp(progress, 0, 1) ^ Config.Difficulty.RampExponent
end

local function rollKind(random: Random, difficulty: number): Types.MomoKind
	local roll = random:NextNumber()
	local golden = Config.Variants.GoldenChance
	local burnt = lerp(Config.Variants.BurntChanceStart, Config.Variants.BurntChanceEnd, difficulty)
	if roll < golden then
		return "Golden" :: Types.MomoKind
	elseif roll < golden + burnt then
		return "Burnt" :: Types.MomoKind
	end
	return "Normal" :: Types.MomoKind
end

function RoundSession.new(player: Player): RoundSession
	local self = setmetatable(
		{
			player = player,
			state = "Lobby" :: Types.RoundState,
			roundTrove = Trove.new(),
			countdown = Timer.new(Config.Round.CountdownSeconds),
			timer = Timer.new(Config.Round.LengthSeconds),
			score = Score.new(),
			lives = Config.Round.StartingLives,
			momos = {},
			spawnIn = 0,
			lastSecondSent = -1,
			random = Random.new(),
			destroyed = false,
		} :: SessionData,
		RoundSession
	)

	self.score.Changed:Connect(function()
		if self.state == "Playing" then
			self:_sendHud()
		end
	end)

	self:_sendState({ state = "Lobby" })
	return self
end

function RoundSession.GetState(self: RoundSession): Types.RoundState
	return self.state
end

--------------------------------------------------------------------------------
-- Networking (server -> this player only)
--------------------------------------------------------------------------------
function RoundSession._fire(self: RoundSession, remote: RemoteEvent, payload: any)
	-- Never fire to a player who has left (FireClient would error).
	if self.destroyed or self.player.Parent ~= Players then
		return
	end
	remote:FireClient(self.player, payload)
end

function RoundSession._sendState(self: RoundSession, payload: Types.StatePayload)
	self:_fire(Remotes.StateChanged, payload)
end

function RoundSession._sendHud(self: RoundSession)
	local timeLeft = if self.state == "Playing"
		then self.timer:GetWholeSeconds()
		else Config.Round.LengthSeconds
	self.lastSecondSent = timeLeft
	local payload: Types.HudPayload = {
		score = self.score:Get(),
		lives = self.lives,
		maxLives = Config.Round.StartingLives,
		timeLeft = timeLeft,
	}
	self:_fire(Remotes.HudUpdate, payload)
end

--------------------------------------------------------------------------------
-- State transitions
--------------------------------------------------------------------------------
function RoundSession.Start(self: RoundSession)
	if self.destroyed or (self.state ~= "Lobby" and self.state ~= "GameOver") then
		return
	end

	self.roundTrove:Clean() -- defensive: nothing from a previous round survives
	self.score:Reset()
	self.lives = Config.Round.StartingLives
	self.spawnIn = 0.4
	self.countdown = Timer.new(Config.Round.CountdownSeconds)
	self.countdown:Start()
	self.timer = Timer.new(Config.Round.LengthSeconds)
	self.state = "Countdown"

	self.roundTrove:Connect(RunService.Heartbeat, function(dt: number)
		self:_step(dt)
	end)
	self.roundTrove:Add(function()
		self:_clearMomos()
	end)

	self:_sendState({
		state = "Countdown",
		countdownSeconds = Config.Round.CountdownSeconds,
		maxLives = Config.Round.StartingLives,
		roundLength = Config.Round.LengthSeconds,
	})
	self:_sendHud()
end

function RoundSession._beginPlaying(self: RoundSession)
	self.state = "Playing"
	self.timer:Start()
	self:_sendState({
		state = "Playing",
		maxLives = Config.Round.StartingLives,
		roundLength = Config.Round.LengthSeconds,
	})
	self:_sendHud()
end

function RoundSession._endRound(self: RoundSession, reason: Types.EndReason)
	if self.state ~= "Playing" then
		return
	end
	self.state = "GameOver"
	self.timer:Stop()
	self.roundTrove:Clean() -- stops Heartbeat and removes all momos

	local player = self.player
	local finalScore = self.score:Get()
	local isNewHighScore = DataService.submitScore(player, finalScore)
	local profile = DataService.getProfile(player)

	self:_sendState({
		state = "GameOver",
		reason = reason,
		score = finalScore,
		highScore = if profile then profile.highScore else finalScore,
		isNewHighScore = isNewHighScore,
		totalCaught = if profile then profile.totalCaught else 0,
	})

	if DataService.claimEasterEgg(player) then
		local payload: Types.EasterEggPayload = {
			text = Config.EasterEgg.Text,
			subtext = Config.EasterEgg.Subtext,
			totalCaught = if profile then profile.totalCaught else Config.EasterEgg.Threshold,
		}
		self:_fire(Remotes.EasterEgg, payload)
	end

	DataService.saveAsync(player)
end

--------------------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------------------
function RoundSession._step(self: RoundSession, dt: number)
	if self.destroyed then
		return
	end
	if self.player.Parent ~= Players then
		-- Player left; RoundService will also call Destroy, which is safe to repeat.
		self:Destroy()
		return
	end

	if self.state == "Countdown" then
		if self.countdown:Update(dt) then
			self:_beginPlaying()
		end
	elseif self.state == "Playing" then
		self:_stepPlaying(dt)
	end
end

function RoundSession._stepPlaying(self: RoundSession, dt: number)
	if self.timer:Update(dt) then
		self:_endRound("TimeUp")
		return
	end

	local difficulty = difficultyAt(self.timer:GetProgress())
	self.spawnIn -= dt
	if self.spawnIn <= 0 then
		self:_spawnMomo(difficulty)
		local interval =
			lerp(Config.Difficulty.SpawnIntervalStart, Config.Difficulty.SpawnIntervalEnd, difficulty)
		-- Never "catch up" with a burst of momos after a server hitch.
		self.spawnIn = math.max(self.spawnIn + interval, interval * 0.5)
	end

	if self:_updateMomos(dt) then
		return -- the round ended during the update
	end

	if self.timer:GetWholeSeconds() ~= self.lastSecondSent then
		self:_sendHud()
	end
end

--------------------------------------------------------------------------------
-- Momos
--------------------------------------------------------------------------------
function RoundSession._spawnMomo(self: RoundSession, difficulty: number)
	if #self.momos >= Config.Spawning.MaxActivePerPlayer then
		return
	end

	-- Pick a random point near the player (uniform over a disc), kept inside the arena.
	local around = BasketService.getPlayerPosition(self.player) or CENTER
	local distance = Config.Spawning.RadiusAroundPlayer * math.sqrt(self.random:NextNumber())
	local angle = self.random:NextNumber(0, math.pi * 2)
	local offset = Vector3.new(
		around.X + math.cos(angle) * distance - CENTER.X,
		0,
		around.Z + math.sin(angle) * distance - CENTER.Z
	)
	local maxRadius = ARENA.Radius - 4
	if offset.Magnitude > maxRadius then
		offset = offset.Unit * maxRadius
	end
	local position = CENTER + offset + Vector3.new(0, Config.Spawning.Height, 0)

	local kind: Types.MomoKind = rollKind(self.random, difficulty)
	local momo = MomoFactory.create(
		kind,
		CFrame.new(position) * CFrame.Angles(0, self.random:NextNumber(0, math.pi * 2), 0),
		self.player.UserId
	)
	momo.model.Parent = WorldBuilder.getMomoFolder()

	local speed = lerp(Config.Difficulty.FallSpeedStart, Config.Difficulty.FallSpeedEnd, difficulty)
		* self.random:NextNumber(0.9, 1.1)
	MomoFactory.launch(momo, Vector3.new(0, -speed, 0))

	local swayAngle = self.random:NextNumber(0, math.pi * 2)
	table.insert(self.momos, {
		momo = momo,
		age = 0,
		phase = self.random:NextNumber(0, math.pi * 2),
		speed = speed,
		swayDirection = Vector3.new(math.cos(swayAngle), 0, math.sin(swayAngle)),
		nextWobbleUpdate = 0,
	})
end

function RoundSession._removeMomoAt(self: RoundSession, index: number)
	local active = table.remove(self.momos, index)
	if active then
		active.momo.model:Destroy()
	end
end

function RoundSession._clearMomos(self: RoundSession)
	for _, active in self.momos do
		active.momo.model:Destroy()
	end
	table.clear(self.momos)
end

-- Moves/wobbles momos and checks catches. Returns true if the round ended.
function RoundSession._updateMomos(self: RoundSession, dt: number): boolean
	local catchPoint = BasketService.getCatchPoint(self.player)
	local catch = Config.Catch
	local radiusSquared = catch.Radius * catch.Radius
	local spawning = Config.Spawning

	-- Iterate backwards so removing entries is safe.
	for index = #self.momos, 1, -1 do
		local active = self.momos[index]
		local momo = active.momo
		if not momo.body.Parent then
			-- Removed by something else (e.g. fell out of the world): tidy up the rest.
			self:_removeMomoAt(index)
			continue
		end

		active.age += dt
		local position = momo.body.Position

		-- Gentle spin, wobble and sway (updated a few times a second, not every frame).
		if active.age >= active.nextWobbleUpdate then
			active.nextWobbleUpdate = active.age + WOBBLE_UPDATE_INTERVAL
			local t = active.age + active.phase
			momo.spin.AngularVelocity = Vector3.new(
				math.cos(t * 3) * spawning.WobbleAmount,
				spawning.SpinSpeed,
				math.sin(t * 2.6) * spawning.WobbleAmount
			)
			local sway = active.swayDirection * (math.sin(t * 1.7) * spawning.SwayStuds)
			momo.fall.VectorVelocity = Vector3.new(sway.X, -active.speed, sway.Z)
		end

		-- Distance check against the basket (no .Touched: fast parts can skip it).
		local caught = false
		if catchPoint then
			local dx = position.X - catchPoint.X
			local dz = position.Z - catchPoint.Z
			local dy = position.Y - catchPoint.Y
			caught = dx * dx + dz * dz <= radiusSquared
				and dy >= -catch.BelowTolerance
				and dy <= catch.AboveTolerance
		end

		if caught then
			self:_removeMomoAt(index)
			if self:_onCatch(momo.kind, position) then
				return true
			end
		else
			local flat = Vector3.new(position.X - CENTER.X, 0, position.Z - CENTER.Z)
			local hitGround = position.Y <= ARENA.GroundY + 0.5
			local leftArena = flat.Magnitude > DESPAWN_RADIUS
			if hitGround or leftArena or active.age > spawning.MaxLifetimeSeconds then
				self:_removeMomoAt(index)
			end
		end
	end
	return false
end

-- Applies a catch. Returns true if it ended the round.
function RoundSession._onCatch(self: RoundSession, kind: Types.MomoKind, position: Vector3): boolean
	local payload: Types.CatchPayload
	if kind == "Burnt" then
		self.lives = math.max(0, self.lives - Config.BurntLivesLost)
		payload = { kind = kind, position = position, points = 0, lives = self.lives }
		self:_fire(Remotes.MomoCaught, payload)
		self:_sendHud()
		if self.lives <= 0 then
			self:_endRound("OutOfLives")
			return true
		end
		return false
	end

	local points = if kind == "Golden" then Config.Points.Golden else Config.Points.Normal
	DataService.addCaught(self.player, 1)
	payload = { kind = kind, position = position, points = points, lives = self.lives }
	self:_fire(Remotes.MomoCaught, payload)
	self.score:Add(points) -- also sends the HUD update
	return false
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------
function RoundSession.Destroy(self: RoundSession)
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.roundTrove:Clean()
	self.score:Destroy()
end

return RoundSession
