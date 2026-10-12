--!strict
--[[
	BasketService: gives every character a small bamboo steamer basket held at chest
	height, just in front of the hands.

	The basket is welded to the upper torso (R15 UpperTorso / R6 Torso) with an
	explicit Weld offset, so where it sits never depends on physics timing. Every part
	is Massless and CanCollide = false, so it can't trip the character or push momos.

	It is (re)attached on CharacterAdded, again once the avatar's appearance loads, and
	whenever the torso part is swapped out (appearance loading can replace body parts,
	which would take the old weld with it). Catch detection asks for the basket's catch
	point each frame, so it always uses the current basket (or none while dead).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)

local Colors = Config.Colors
local BASKET_NAME = "MomoBasket"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local TORSO_NAMES = { UpperTorso = true, Torso = true }

local BasketService = {}

local function basketPart(name: string, height: number, diameter: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.Color = color
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = false
	return part
end

local function weld(name: string, part0: BasePart, part1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
end

local function buildBasket(torso: BasePart): Model
	local spec = Config.Basket
	local model = Instance.new("Model")
	model.Name = BASKET_NAME

	local h, d = spec.Height, spec.Diameter

	local base = basketPart("Base", h, d, Colors.Bamboo)
	base.CFrame = torso.CFrame * spec.Offset * UPRIGHT
	base.Parent = model
	model.PrimaryPart = base

	-- The base cylinder's local X is "up", so offsets along X stack rings vertically.
	local function add(part: BasePart, offsetUp: number)
		part.CFrame = base.CFrame * CFrame.new(offsetUp, 0, 0)
		weld("Weld", base, part, CFrame.new(offsetUp, 0, 0))
		part.Parent = model
	end

	add(basketPart("Rim", h * 0.25, d + 0.12, Colors.BambooDark), h / 2)
	add(basketPart("Band", h * 0.18, d + 0.04, Colors.BambooDark), -h * 0.15)
	-- Darker disc just above the top face so it reads as the inside of the basket.
	add(basketPart("Inside", 0.05, d * 0.8, Colors.BasketInside), h / 2 + 0.01)

	-- Where momos are "caught": the centre of the basket's opening.
	local catchPoint = Instance.new("Attachment")
	catchPoint.Name = "CatchPoint"
	catchPoint.Position = Vector3.new(h / 2, 0, 0)
	catchPoint.Parent = base

	-- Hold it against the chest.
	weld("HoldWeld", torso, base, spec.Offset * UPRIGHT)

	return model
end

local function findTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

-- Replaces any existing basket with a fresh one welded to the current torso.
local function attach(player: Player, character: Model)
	if player.Character ~= character or not character.Parent then
		return
	end
	local torso = findTorso(character)
	if not torso then
		return
	end
	local old = character:FindFirstChild(BASKET_NAME)
	if old then
		old:Destroy()
	end
	buildBasket(torso).Parent = character
end

local function onCharacterAdded(player: Player, character: Model)
	-- A torso swapped in later (avatar appearance loading) gets the basket moved onto it.
	-- The connection dies with the character.
	character.ChildAdded:Connect(function(child)
		if TORSO_NAMES[child.Name] and child:IsA("BasePart") then
			attach(player, character)
		end
	end)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"
	character:WaitForChild(torsoName, 10)
	-- The character may have been replaced or removed while we waited (attach checks).
	attach(player, character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Belt and braces: re-attach once the avatar has fully loaded.
	player.CharacterAppearanceLoaded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function BasketService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

-- World position of the basket opening, or nil if the player has no living character.
function BasketService.getCatchPoint(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local basket = character:FindFirstChild(BASKET_NAME)
	local base = basket and basket:FindFirstChild("Base")
	local catchPoint = base and base:FindFirstChild("CatchPoint")
	if catchPoint and catchPoint:IsA("Attachment") then
		return catchPoint.WorldPosition
	end
	return nil
end

-- Where momos should drop around: the player's root CFrame (position and facing),
-- if they have one.
function BasketService.getPlayerCFrame(player: Player): CFrame?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.CFrame
	end
	return nil
end

return BasketService
