--!strict
--[[
	RoundService: one RoundSession per player (individual rounds and scores, so any
	number of friends can play side by side), plus the only two client -> server
	requests: StartRound and PlayAgain.

	Requests carry no data we trust: the server checks rate limits, the session's
	current state, and that the player's save data has loaded.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Remotes = require(ReplicatedStorage.MomoCatch.Remotes)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local DataService = require(script.Parent.DataService)
local RoundSession = require(script.Parent.RoundSession)

local RoundService = {}

local sessions: { [Player]: RoundSession.RoundSession } = {}

function RoundService.init()
	local limiter = RateLimiter.new(Config.Remote.RequestCooldown)

	local function onRequest(player: Player, requiredState: Types.RoundState)
		if not limiter:Check(player) then
			return
		end
		local session = sessions[player]
		if not session or session:GetState() ~= requiredState then
			return
		end
		if not DataService.isReady(player) then
			return
		end
		session:Start()
	end

	-- Any arguments a client sends are ignored on purpose.
	Remotes.StartRound.OnServerEvent:Connect(function(player: Player)
		onRequest(player, "Lobby")
	end)
	Remotes.PlayAgain.OnServerEvent:Connect(function(player: Player)
		onRequest(player, "GameOver")
	end)

	local function onPlayerAdded(player: Player)
		if not sessions[player] then
			sessions[player] = RoundSession.new(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		local session = sessions[player]
		sessions[player] = nil
		if session then
			session:Destroy()
		end
		limiter:Forget(player)
	end)
end

return RoundService
