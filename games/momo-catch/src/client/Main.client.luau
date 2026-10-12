--!strict
-- Momo Catch client entry point. Clients only do visuals; the server owns the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.MomoCatch.Remotes)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local UIController = require(script.Parent.UIController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("MomoCatchGui")
assert(screenGui:IsA("ScreenGui"), "MomoCatchGui should be a ScreenGui")

EffectsController.init()
CameraController.init()
UIController.init(screenGui, playerGui)

-- Connect after the UI exists; events fired before this are queued by Roblox.
Remotes.StateChanged.OnClientEvent:Connect(function(payload: Types.StatePayload)
	UIController.onState(payload)
	if typeof(payload) == "table" then
		CameraController.onState(payload.state)
	end
end)

Remotes.HudUpdate.OnClientEvent:Connect(function(payload: Types.HudPayload)
	UIController.onHud(payload)
end)

Remotes.MomoCaught.OnClientEvent:Connect(function(payload: Types.CatchPayload)
	EffectsController.onCatch(payload)
	UIController.onCatch(payload)
end)

Remotes.EasterEgg.OnClientEvent:Connect(function(payload: Types.EasterEggPayload)
	UIController.showEasterEgg(payload)
end)
