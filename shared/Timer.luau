--!strict
--[[
	Timer: a countdown you tick yourself (no RunService inside, so it is easy to test
	and never outlives its owner).

		local timer = Timer.new(60)
		timer:Start()
		-- every frame:
		if timer:Update(dt) then print("done!") end
		print(timer:GetWholeSeconds(), timer:GetProgress())
]]

local Timer = {}
Timer.__index = Timer

type TimerData = {
	duration: number,
	remaining: number,
	running: boolean,
}

export type Timer = typeof(setmetatable({} :: TimerData, Timer))

function Timer.new(duration: number): Timer
	assert(duration >= 0, "Timer duration must be >= 0")
	return setmetatable({ duration = duration, remaining = duration, running = false } :: TimerData, Timer)
end

function Timer.Start(self: Timer)
	self.remaining = self.duration
	self.running = true
end

function Timer.Stop(self: Timer)
	self.running = false
end

function Timer.IsRunning(self: Timer): boolean
	return self.running
end

-- Advances the timer. Returns true only on the update where it reaches zero.
function Timer.Update(self: Timer, dt: number): boolean
	if not self.running then
		return false
	end
	self.remaining = math.max(0, self.remaining - dt)
	if self.remaining <= 0 then
		self.running = false
		return true
	end
	return false
end

function Timer.GetRemaining(self: Timer): number
	return self.remaining
end

-- Remaining time rounded up, which is what players expect to see on a clock.
function Timer.GetWholeSeconds(self: Timer): number
	return math.ceil(self.remaining)
end

function Timer.GetElapsed(self: Timer): number
	return self.duration - self.remaining
end

-- 0 at the start, 1 when finished.
function Timer.GetProgress(self: Timer): number
	if self.duration <= 0 then
		return 1
	end
	return math.clamp(1 - self.remaining / self.duration, 0, 1)
end

return Timer
