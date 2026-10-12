--!strict
--[[
	Typed access to Momo Catch's RemoteEvents.

	The RemoteEvents themselves are declared as files in ./Events (so they exist before
	any script runs; no "create on the server, wait on the client" race).

	Direction rules (anti-cheat):
	  Server -> client only: StateChanged, HudUpdate, MomoCaught, EasterEgg
	  Client -> server (rate-limited, no arguments trusted): StartRound, PlayAgain
]]

local events = script.Parent:WaitForChild("Events")

local function get(name: string): RemoteEvent
	local remote = events:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} must be a RemoteEvent`)
	return remote
end

return {
	-- server -> client
	StateChanged = get("StateChanged"),
	HudUpdate = get("HudUpdate"),
	MomoCaught = get("MomoCaught"),
	EasterEgg = get("EasterEgg"),
	-- client -> server
	StartRound = get("StartRound"),
	PlayAgain = get("PlayAgain"),
}
