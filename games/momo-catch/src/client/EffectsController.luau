--!strict
--[[
	EffectsController: everything the player sees/hears that doesn't affect the game.
	- Sounds (local only)
	- Catch bursts, floating "+1" / "+5" text, burnt smoke puff
	- Camera shake on a burnt catch
	- Drop markers under your own falling momos; other players' momos fade out
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.MomoCatch.Config)
local Types = require(ReplicatedStorage.MomoCatch.Types)
local TweenHelpers = require(ReplicatedStorage.Shared.TweenHelpers)
local UIHelpers = require(ReplicatedStorage.Shared.UIHelpers)

local localPlayer = Players.LocalPlayer
local Colors = Config.Colors
local Visuals = Config.Visuals
local GROUND_Y = Config.Arena.GroundY
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local EffectsController = {}

local sounds: { [string]: Config.SoundSpec } = Config.Sounds :: any
local fxFolder: Folder

--------------------------------------------------------------------------------
-- Sounds
--------------------------------------------------------------------------------
function EffectsController.play(name: string, pitchMultiplier: number?)
	local spec = sounds[name]
	if not spec then
		warn(`[MomoCatch] Unknown sound "{name}"`)
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.PlaybackSpeed = spec.PlaybackSpeed * (pitchMultiplier or 1)
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- A little rising four-note chime (do-mi-sol-do).
function EffectsController.chime()
	task.spawn(function()
		for _, ratio in { 1, 1.26, 1.5, 2 } do
			EffectsController.play("Chime", ratio)
			task.wait(0.11)
		end
	end)
end

--------------------------------------------------------------------------------
-- World effects
--------------------------------------------------------------------------------
local function anchorAt(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Name = "FxAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = fxFolder
	task.delay(lifetime, function()
		part:Destroy()
	end)
	return part
end

local function burst(anchor: Part, texture: string, color: ColorSequence, count: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Rate = 0
	emitter.Color = color
	emitter.LightEmission = 0.5
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Parent = anchor
	emitter:Emit(count)
end

local function floatingText(anchor: Part, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 70)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = UIHelpers.Fonts.Title
	label.TextColor3 = color
	label.Parent = billboard
	local stroke = UIHelpers.stroke(label, Color3.new(1, 1, 1), 3)

	TweenHelpers.pop(label, 1.6)
	TweenHelpers.play(billboard, TweenHelpers.info(1, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 5.5, 0),
	})
	task.delay(0.45, function()
		TweenHelpers.play(label, 0.5, { TextTransparency = 1 })
		TweenHelpers.play(stroke, 0.5, { Transparency = 1 })
	end)
end

--------------------------------------------------------------------------------
-- Camera shake (applied after the default camera each frame)
--------------------------------------------------------------------------------
local shakeUntil = 0
local shakeBound = false

function EffectsController.shake(intensity: number, seconds: number)
	shakeUntil = os.clock() + seconds
	if shakeBound then
		return
	end
	shakeBound = true
	local random = Random.new()
	RunService:BindToRenderStep("MomoShake", Enum.RenderPriority.Camera.Value + 1, function()
		local remaining = shakeUntil - os.clock()
		local camera = Workspace.CurrentCamera
		if remaining <= 0 or not camera then
			RunService:UnbindFromRenderStep("MomoShake")
			shakeBound = false
			return
		end
		local strength = intensity * (remaining / seconds)
		local offset = random:NextUnitVector() * strength
		camera.CFrame = camera.CFrame
			* CFrame.new(offset)
			* CFrame.Angles(0, 0, random:NextNumber(-1, 1) * strength * 0.04)
	end)
end

--------------------------------------------------------------------------------
-- Catch feedback
--------------------------------------------------------------------------------
function EffectsController.onCatch(payload: Types.CatchPayload)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local anchor = anchorAt(payload.position, 2)

	if payload.kind == "Burnt" then
		EffectsController.play("Burnt")
		burst(anchor, SMOKE_TEXTURE, ColorSequence.new(Color3.fromRGB(90, 80, 80)), 12, 6)
		floatingText(anchor, "Ouch!", Colors.MomoBurnt)
		EffectsController.shake(Visuals.ShakeIntensity, Visuals.ShakeSeconds)
	elseif payload.kind == "Golden" then
		EffectsController.play("GoldenCatch")
		burst(anchor, SPARKLE_TEXTURE, ColorSequence.new(Colors.UiGold, Color3.new(1, 1, 1)), 32, 14)
		floatingText(anchor, `+{payload.points}`, Colors.UiGold)
	else
		EffectsController.play("Catch", 0.95 + math.random() * 0.15)
		burst(anchor, SPARKLE_TEXTURE, ColorSequence.new(Colors.UiPink, Colors.UiCream), 16, 10)
		floatingText(anchor, `+{payload.points}`, Colors.UiPinkDark)
	end
end

--------------------------------------------------------------------------------
-- Momo markers / fading
--------------------------------------------------------------------------------
type Tracked = { model: Model, body: BasePart, marker: Part }
local tracked: { Tracked } = {}

local function markerColor(kind: any): Color3
	if kind == "Golden" then
		return Colors.UiGold
	elseif kind == "Burnt" then
		return Colors.MomoBurnt
	end
	return Color3.new(1, 1, 1)
end

local function onMomoAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local owner = model:GetAttribute("OwnerUserId")
	if owner ~= localPlayer.UserId then
		-- Someone else's momo: fade it so your own stand out. Parts can stream in
		-- after the model, so fade late arrivals too (the connection dies with the model).
		local function fade(descendant: Instance)
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = Visuals.OtherPlayersMomoTransparency
			end
		end
		for _, descendant in model:GetDescendants() do
			fade(descendant)
		end
		model.DescendantAdded:Connect(fade)
		return
	end
	if not Visuals.DropMarkers then
		return
	end
	local body = model:WaitForChild("Body", 3)
	if not body or not body:IsA("BasePart") or not model.Parent then
		return
	end
	local marker = Instance.new("Part")
	marker.Name = "DropMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.SmoothPlastic
	marker.Color = markerColor(model:GetAttribute("Kind"))
	marker.Transparency = 0.55
	marker.Size = Vector3.new(0.05, 1.5, 1.5)
	marker.Parent = fxFolder
	table.insert(tracked, { model = model, body = body, marker = marker })
end

local function updateMarkers()
	local height = Config.Spawning.Height
	for index = #tracked, 1, -1 do
		local entry = tracked[index]
		if not entry.model.Parent or not entry.body.Parent then
			entry.marker:Destroy()
			table.remove(tracked, index)
			continue
		end
		local position = entry.body.Position
		local closeness = math.clamp(1 - (position.Y - GROUND_Y) / height, 0, 1)
		local diameter = 1.2 + closeness * 2.4
		entry.marker.Size = Vector3.new(0.05, diameter, diameter)
		entry.marker.CFrame = CFrame.new(position.X, GROUND_Y + 0.05, position.Z) * UPRIGHT
	end
end

--------------------------------------------------------------------------------
function EffectsController.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "MomoClientFx"
	fxFolder.Parent = Workspace

	-- Preload sounds so the first catch isn't silent.
	task.spawn(function()
		local preload: { Instance } = {}
		for name, spec in sounds do
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = spec.Id
			table.insert(preload, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)

	task.spawn(function()
		local momoFolder = Workspace:WaitForChild("MomoCatchMomos")
		momoFolder.ChildAdded:Connect(function(child)
			task.spawn(onMomoAdded, child)
		end)
		for _, child in momoFolder:GetChildren() do
			task.spawn(onMomoAdded, child)
		end
	end)

	RunService.RenderStepped:Connect(updateMarkers)
end

return EffectsController
