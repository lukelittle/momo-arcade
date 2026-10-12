--!strict
--[[
	RateLimiter: allows one action per key per cooldown window.
	Use it on the server for any client -> server RemoteEvent.

		local limiter = RateLimiter.new(1) -- once per second
		remote.OnServerEvent:Connect(function(player)
			if not limiter:Check(player) then return end
			...
		end)
		Players.PlayerRemoving:Connect(function(player) limiter:Forget(player) end)
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type RateLimiterData = {
	cooldown: number,
	lastUsed: { [any]: number },
}

export type RateLimiter = typeof(setmetatable({} :: RateLimiterData, RateLimiter))

function RateLimiter.new(cooldownSeconds: number): RateLimiter
	return setmetatable(
		{
			cooldown = cooldownSeconds,
			-- Weak keys so a forgotten Player can still be garbage collected.
			lastUsed = setmetatable({}, { __mode = "k" }) :: any,
		} :: RateLimiterData,
		RateLimiter
	)
end

-- Returns true (and records the use) if the key is allowed to act now.
function RateLimiter.Check(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local last = self.lastUsed[key]
	if last and now - last < self.cooldown then
		return false
	end
	self.lastUsed[key] = now
	return true
end

function RateLimiter.Forget(self: RateLimiter, key: any)
	self.lastUsed[key] = nil
end

return RateLimiter
