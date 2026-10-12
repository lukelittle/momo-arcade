--!strict
--[[
	Score: a never-negative points counter with a Changed signal.

		local score = Score.new()
		score.Changed:Connect(function(newValue, delta) ... end)
		score:Add(5)
]]

local Signal = require(script.Parent.Signal)

local Score = {}
Score.__index = Score

type ScoreData = {
	value: number,
	Changed: Signal.Signal<number, number>,
}

export type Score = typeof(setmetatable({} :: ScoreData, Score))

function Score.new(initial: number?): Score
	return setmetatable(
		{
			value = math.max(0, initial or 0),
			Changed = Signal.new() :: Signal.Signal<number, number>,
		} :: ScoreData,
		Score
	)
end

function Score.Get(self: Score): number
	return self.value
end

-- Adds (or subtracts) points, clamped at zero. Returns the new value.
function Score.Add(self: Score, delta: number): number
	local newValue = math.max(0, self.value + delta)
	local applied = newValue - self.value
	self.value = newValue
	if applied ~= 0 then
		self.Changed:Fire(newValue, applied)
	end
	return newValue
end

function Score.Reset(self: Score)
	local old = self.value
	self.value = 0
	if old ~= 0 then
		self.Changed:Fire(0, -old)
	end
end

function Score.Destroy(self: Score)
	self.Changed:DisconnectAll()
end

return Score
