--!strict
--[[
	CameraController: a slow, scenic orbit around the arena behind the menus (Lobby
	and GameOver), and the normal follow camera while playing. Character movement is
	paused while a menu is open so the thumbstick/jump button don't get in the way.

	When a round starts the follow camera is placed behind the character and tilted up
	a little, so the sky where momos appear is on screen (the orbit looks down at the
	arena, and the follow camera would otherwise keep that downward tilt).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)

local localPlayer = Players.LocalPlayer
local Visuals = Config.Visuals
local CENTER = Vector3.new(Config.Arena.Center.X, Config.Arena.GroundY, Config.Arena.Center.Z)
local ORBIT_BINDING = "MomoLobbyOrbit"

local CameraController = {}

local orbiting = false
local orbitAngle = math.rad(90) -- start looking at the tea house

-- The default PlayerModule exposes Enable/Disable for movement controls.
local controlsRequest = 0
local function setControlsEnabled(enabled: boolean)
	controlsRequest += 1
	local request = controlsRequest
	task.spawn(function()
		local playerScripts = localPlayer:WaitForChild("PlayerScripts", 10)
		local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
		-- Only the most recent request wins (an older one may finish waiting later).
		if request ~= controlsRequest or not module or not module:IsA("ModuleScript") then
			return
		end
		pcall(function()
			local controls = (require :: any)(module):GetControls()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
	end)
end

local function startOrbit()
	if orbiting then
		return
	end
	orbiting = true
	setControlsEnabled(false)
	RunService:BindToRenderStep(ORBIT_BINDING, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		orbitAngle += dt * Visuals.LobbyCameraSpeed
		local eye = CENTER
			+ Vector3.new(
				math.cos(orbitAngle) * Visuals.LobbyCameraRadius,
				Visuals.LobbyCameraHeight,
				math.sin(orbitAngle) * Visuals.LobbyCameraRadius
			)
		camera.CFrame = CFrame.lookAt(eye, CENTER + Vector3.new(0, 4, 0))
	end)
end

-- Behind the character, slightly above, aiming up toward the sky. The default camera
-- scripts take their angle from whatever CFrame the camera has, so this sets the starting
-- angle (they keep their own zoom) and players can still swipe/drag to look around.
local function framePlayCamera(camera: Camera, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local eye = root.Position
		- forward * Visuals.PlayCameraDistance
		+ Vector3.yAxis * Visuals.PlayCameraHeight
	local target = root.Position
		+ forward * Visuals.PlayCameraDistance
		+ Vector3.yAxis * Visuals.PlayCameraLookUp
	camera.CFrame = CFrame.lookAt(eye, target)
end

local function stopOrbit()
	if not orbiting then
		return
	end
	orbiting = false
	RunService:UnbindFromRenderStep(ORBIT_BINDING)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid then
			camera.CameraSubject = humanoid
			framePlayCamera(camera, character)
		end
	end
	setControlsEnabled(true)
end

function CameraController.onState(state: Types.RoundState)
	if state == "Lobby" or state == "GameOver" then
		startOrbit()
	else
		stopOrbit()
	end
end

function CameraController.init()
	startOrbit()
end

return CameraController
