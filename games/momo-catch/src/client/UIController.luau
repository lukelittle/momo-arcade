--!strict
--[[
	UIController: shows the right screen for each round state and turns button
	presses into the two allowed requests (StartRound / PlayAgain).

	Works with mouse, touch, keyboard (Enter) and gamepad (the main button is
	auto-selected, so A presses it).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Remotes = require(ReplicatedStorage.MomoCatch.Remotes)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local EffectsController = require(script.Parent.EffectsController)

-- UI builder modules live inside the MomoCatchGui ScreenGui in StarterGui.
local uiModules = StarterGui:WaitForChild("MomoCatchGui")
local Celebration = require(uiModules:WaitForChild("Celebration"))
local EndScreen = require(uiModules:WaitForChild("EndScreen"))
local Hud = require(uiModules:WaitForChild("Hud"))
local StartScreen = require(uiModules:WaitForChild("StartScreen"))

local localPlayer = Players.LocalPlayer
local PRIMARY_ACTION = "MomoPrimaryButton"

local UIController = {}

local gui: ScreenGui
local playerGui: Instance
local startScreen: StartScreen.StartScreen
local endScreen: EndScreen.EndScreen
local hud: Hud.Hud
local currentState: Types.RoundState = "Lobby"
local countdownThread: thread? = nil
local nextRequestAt = 0

--------------------------------------------------------------------------------
-- Requests (the server re-validates everything; this just avoids spamming it)
--------------------------------------------------------------------------------
local function sendRequest(remote: RemoteEvent)
	local now = os.clock()
	if now < nextRequestAt then
		return
	end
	nextRequestAt = now + Config.Remote.RequestCooldown + 0.1
	EffectsController.play("Click")
	remote:FireServer()
end

local function onPlay()
	if currentState == "Lobby" and localPlayer:GetAttribute("MomoDataReady") == true then
		sendRequest(Remotes.StartRound)
	end
end

local function onPlayAgain()
	if currentState == "GameOver" then
		sendRequest(Remotes.PlayAgain)
	end
end

--------------------------------------------------------------------------------
-- Gamepad / keyboard focus
--------------------------------------------------------------------------------
local function primaryButton(): TextButton?
	if currentState == "Lobby" then
		return startScreen.playButton
	elseif currentState == "GameOver" then
		return endScreen.playButton
	end
	return nil
end

local function focusPrimary()
	if Celebration.isOpen() then
		return
	end
	local button = primaryButton()
	if button and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = button
	elseif not button then
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
end

local function setEnterBinding(enabled: boolean)
	if enabled then
		ContextActionService:BindAction(PRIMARY_ACTION, function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin and not Celebration.isOpen() then
				if currentState == "Lobby" then
					onPlay()
				elseif currentState == "GameOver" then
					onPlayAgain()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter)
	else
		ContextActionService:UnbindAction(PRIMARY_ACTION)
	end
end

--------------------------------------------------------------------------------
-- Countdown
--------------------------------------------------------------------------------
local function cancelCountdown()
	local thread = countdownThread
	countdownThread = nil
	if thread and coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
	end
end

local function runCountdown(seconds: number)
	cancelCountdown()
	countdownThread = task.spawn(function()
		for n = math.floor(seconds), 1, -1 do
			hud.showCountdown(tostring(n))
			EffectsController.play("CountdownTick", 1 + (seconds - n) * 0.12)
			task.wait(1)
		end
	end)
end

--------------------------------------------------------------------------------
-- Stats from player attributes (set by the server's DataService)
--------------------------------------------------------------------------------
local function refreshStats()
	startScreen.setStats(
		tonumber(localPlayer:GetAttribute("MomoHighScore")) or 0,
		tonumber(localPlayer:GetAttribute("MomoTotalCaught")) or 0
	)
	startScreen.setReady(localPlayer:GetAttribute("MomoDataReady") == true)
end

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------
function UIController.onState(payload: Types.StatePayload)
	if typeof(payload) ~= "table" then
		return
	end
	local state: Types.RoundState = payload.state
	currentState = state
	cancelCountdown()

	if state == "Lobby" then
		hud.hide()
		endScreen.hide()
		startScreen.show()
	elseif state == "Countdown" then
		startScreen.hide()
		endScreen.hide()
		hud.reset(
			payload.maxLives or Config.Round.StartingLives,
			payload.roundLength or Config.Round.LengthSeconds
		)
		hud.show()
		runCountdown(payload.countdownSeconds or Config.Round.CountdownSeconds)
	elseif state == "Playing" then
		startScreen.hide()
		endScreen.hide()
		hud.show()
		hud.showCountdown("Go!")
		EffectsController.play("CountdownGo")
	elseif state == "GameOver" then
		hud.hide()
		startScreen.hide()
		endScreen.show(payload)
		EffectsController.play("RoundOver")
		if payload.isNewHighScore then
			task.delay(0.5, EffectsController.chime)
		end
	end

	setEnterBinding(state == "Lobby" or state == "GameOver")
	focusPrimary()
end

function UIController.onHud(payload: Types.HudPayload)
	if typeof(payload) ~= "table" then
		return
	end
	hud.setScore(payload.score or 0)
	hud.setTime(payload.timeLeft or 0)
	hud.setLives(payload.lives or 0, payload.maxLives or Config.Round.StartingLives)
end

function UIController.onCatch(payload: Types.CatchPayload)
	if typeof(payload) == "table" and payload.kind == "Burnt" then
		hud.flashDamage()
	end
end

function UIController.showEasterEgg(payload: Types.EasterEggPayload)
	if typeof(payload) ~= "table" then
		return
	end
	local text = if type(payload.text) == "string" then payload.text else Config.EasterEgg.Text
	local subtext = if type(payload.subtext) == "string" then payload.subtext else Config.EasterEgg.Subtext
	-- Let the end screen land first, then celebrate.
	task.delay(1.2, function()
		EffectsController.chime()
		Celebration.show(playerGui, text, subtext, function()
			task.defer(focusPrimary)
		end)
	end)
end

--------------------------------------------------------------------------------
function UIController.init(screenGui: ScreenGui, playerGuiInstance: Instance)
	gui = screenGui
	playerGui = playerGuiInstance

	startScreen = StartScreen.create(gui, onPlay)
	endScreen = EndScreen.create(gui, onPlayAgain)
	hud = Hud.create(gui)

	for _, attribute in { "MomoHighScore", "MomoTotalCaught", "MomoDataReady" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
	refreshStats()

	UserInputService.GamepadConnected:Connect(function()
		focusPrimary()
	end)

	-- Start on the title screen until the server says otherwise.
	UIController.onState({ state = "Lobby" })
end

return UIController
