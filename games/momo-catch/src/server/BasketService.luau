--!strict
--[[
	BasketService: gives every character a bamboo steamer basket held out in front.

	The basket is (re)attached on every CharacterAdded, so respawning mid-round just
	works. Catch detection asks for the basket's catch point each frame, so it always
	uses whatever basket the player currently has (or none while they're dead).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)

local Colors = Config.Colors
local BASKET_NAME = "MomoBasket"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

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
	return part
end

local function buildBasket(rootPart: BasePart): Model
	local spec = Config.Basket
	local model = Instance.new("Model")
	model.Name = BASKET_NAME

	local center = rootPart.CFrame * spec.Offset
	local h, d = spec.Height, spec.Diameter

	local base = basketPart("Base", h, d, Colors.Bamboo)
	base.CFrame = center * UPRIGHT
	base.Parent = model
	model.PrimaryPart = base

	local function add(part: BasePart, offsetY: number)
		part.CFrame = center * CFrame.new(0, offsetY, 0) * UPRIGHT
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	add(basketPart("Rim", 0.3, d + 0.35, Colors.BambooDark), h / 2)
	add(basketPart("Band", 0.22, d + 0.12, Colors.BambooDark), -h * 0.15)
	-- Darker disc just above the top face so it reads as the inside of the basket.
	add(basketPart("Inside", 0.06, d - 0.5, Colors.BasketInside), h / 2 + 0.01)

	-- Where momos are "caught": the centre of the basket's opening.
	local catchPoint = Instance.new("Attachment")
	catchPoint.Name = "CatchPoint"
	catchPoint.Position = Vector3.new(h / 2, 0, 0) -- cylinder's local X is "up"
	catchPoint.Parent = base

	-- Hold it in front of the character.
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoldWeld"
	weld.Part0 = rootPart
	weld.Part1 = base
	weld.Parent = base

	return model
end

local function onCharacterAdded(player: Player, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	-- The character may have been replaced or removed while we waited.
	if
		not rootPart
		or not rootPart:IsA("BasePart")
		or player.Character ~= character
		or not character.Parent
	then
		return
	end
	local old = character:FindFirstChild(BASKET_NAME)
	if old then
		old:Destroy()
	end
	buildBasket(rootPart).Parent = character
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
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

-- Where momos should drop around: the player's position, if they have one.
function BasketService.getPlayerPosition(player: Player): Vector3?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position
	end
	return nil
end

return BasketService
