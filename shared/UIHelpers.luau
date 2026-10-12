--!strict
--[[
	UIHelpers: small builders for rounded, friendly, mobile-safe UI made in code.

	Everything is sized in offsets at a 1080p-ish reference and then scaled for the
	player's screen with `UIHelpers.autoScale`, so text stays readable on phones.
]]

local TweenHelpers = require(script.Parent.TweenHelpers)

local UIHelpers = {}

export type Props = { [string]: any }

-- Creates an instance, applies properties, then parents children and finally itself.
-- (Parent is applied last so property changes don't replicate/redraw one by one.)
function UIHelpers.create(className: string, props: Props?, children: { Instance }?): Instance
	local instance = Instance.new(className :: any)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIHelpers.font(family: string, weight: Enum.FontWeight?): Font
	return Font.new(`rbxasset://fonts/families/{family}.json`, weight or Enum.FontWeight.Regular)
end

UIHelpers.Fonts = {
	Title = UIHelpers.font("FredokaOne"),
	Body = UIHelpers.font("Nunito", Enum.FontWeight.Bold),
	BodyHeavy = UIHelpers.font("Nunito", Enum.FontWeight.ExtraBold),
}

function UIHelpers.corner(parent: Instance, radius: UDim?): UICorner
	return UIHelpers.create("UICorner", {
		CornerRadius = radius or UDim.new(0, 16),
		Parent = parent,
	}) :: UICorner
end

function UIHelpers.stroke(
	parent: Instance,
	color: Color3,
	thickness: number?,
	transparency: number?
): UIStroke
	return UIHelpers.create("UIStroke", {
		Color = color,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextBox")
			then Enum.ApplyStrokeMode.Contextual
			else Enum.ApplyStrokeMode.Border,
		Parent = parent,
	}) :: UIStroke
end

function UIHelpers.padding(parent: Instance, pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UIHelpers.create("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
		Parent = parent,
	}) :: UIPadding
end

function UIHelpers.list(
	parent: Instance,
	direction: Enum.FillDirection,
	gap: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	return UIHelpers.create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	}) :: UIListLayout
end

function UIHelpers.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return UIHelpers.create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	}) :: UIGradient
end

export type LabelOptions = {
	Text: string,
	Size: UDim2,
	TextSize: number?,
	TextColor: Color3?,
	Font: Font?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- A transparent, auto-fitting text label.
function UIHelpers.label(options: LabelOptions): TextLabel
	local label = UIHelpers.create("TextLabel", {
		BackgroundTransparency = 1,
		Text = options.Text,
		Size = options.Size,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		FontFace = options.Font or UIHelpers.Fonts.Body,
		TextColor3 = options.TextColor or Color3.new(1, 1, 1),
		TextSize = options.TextSize or 28,
		TextWrapped = true,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	}) :: TextLabel
	-- Shrink (never grow) long text so it always fits on small screens.
	UIHelpers.create("UITextSizeConstraint", {
		MaxTextSize = options.TextSize or 28,
		MinTextSize = 10,
		Parent = label,
	})
	label.TextScaled = true
	return label
end

export type ButtonOptions = {
	Text: string,
	Size: UDim2,
	Color: Color3,
	TextColor: Color3,
	StrokeColor: Color3?,
	TextSize: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnActivated: () -> (),
}

-- A pill-shaped, squishy button that works with mouse, touch and gamepad selection.
function UIHelpers.button(options: ButtonOptions): TextButton
	local button = UIHelpers.create("TextButton", {
		Text = options.Text,
		Size = options.Size,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		BackgroundColor3 = options.Color,
		TextColor3 = options.TextColor,
		FontFace = UIHelpers.Fonts.Title,
		TextSize = options.TextSize or 36,
		AutoButtonColor = false,
		Selectable = true,
		LayoutOrder = options.LayoutOrder or 0,
	}) :: TextButton
	UIHelpers.corner(button, UDim.new(0.5, 0))
	UIHelpers.stroke(button, options.StrokeColor or Color3.new(1, 1, 1), 4)

	-- Gamepad selection highlight: a soft rounded ring instead of the default box.
	local selection = UIHelpers.create("Frame", {
		Name = "SelectionRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 12, 1, 12),
		Position = UDim2.fromOffset(-6, -6),
	})
	UIHelpers.corner(selection, UDim.new(0.5, 0))
	UIHelpers.stroke(selection, Color3.fromRGB(255, 255, 255), 5)
	button.SelectionImageObject = selection :: GuiObject

	local scale = TweenHelpers.getScale(button)
	local function scaleTo(target: number)
		TweenHelpers.play(scale, TweenHelpers.info(0.12, Enum.EasingStyle.Quad), { Scale = target })
	end
	button.MouseEnter:Connect(function()
		scaleTo(1.05)
	end)
	button.MouseLeave:Connect(function()
		scaleTo(1)
	end)
	button.SelectionGained:Connect(function()
		scaleTo(1.05)
	end)
	button.SelectionLost:Connect(function()
		scaleTo(1)
	end)
	button.MouseButton1Down:Connect(function()
		scaleTo(0.93)
	end)
	button.MouseButton1Up:Connect(function()
		scaleTo(1)
	end)
	button.Activated:Connect(function()
		options.OnActivated()
	end)

	if options.Parent then
		button.Parent = options.Parent
	end
	return button
end

--[[
	Adds a UIScale to `root` that keeps offset-sized UI proportional to the screen.
	`referenceHeight` is the screen height the UI was designed at.
	Returns the UIScale and a function that stops listening.
]]
function UIHelpers.autoScale(
	root: Instance,
	referenceHeight: number,
	minScale: number?,
	maxScale: number?
): (UIScale, () -> ())
	local uiScale = UIHelpers.create("UIScale", { Name = "AutoScale", Parent = root }) :: UIScale
	local cameraConnection: RBXScriptConnection? = nil

	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		-- Use the shorter side so phones in landscape or portrait both look right.
		local shortSide = math.min(viewport.X, viewport.Y * 1.6)
		local raw = math.min(viewport.Y / referenceHeight, shortSide / (referenceHeight * 1.6))
		uiScale.Scale = math.clamp(raw, minScale or 0.5, maxScale or 1.5)
	end

	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end

	local workspaceConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	return uiScale,
		function()
			workspaceConnection:Disconnect()
			if cameraConnection then
				cameraConnection:Disconnect()
			end
		end
end

return UIHelpers
