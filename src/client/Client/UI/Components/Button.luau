--!strict
-- Button: primary / secondary / ghost, with hover, pressed, focused (gamepad/keyboard selection)
-- and disabled states. Height is the context's tap target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))

export type Variant = "primary" | "secondary" | "ghost"

export type Options = {
	text: string,
	variant: Variant?,
	glyphLeft: string?,
	glyphRight: string?,
	onActivated: () -> (),
	layoutOrder: number?,
	fill: boolean?, -- stretch to the parent's width
	align: "center" | "left" | nil,
	name: string?,
}

export type Button = {
	instance: TextButton,
	label: TextLabel,
	setEnabled: (self: Button, on: boolean) -> (),
	setText: (self: Button, text: string) -> (),
	destroy: (self: Button) -> (),
}

local Button = {}

local function shade(color: Color3, amount: number): Color3
	-- amount > 0 lightens toward white, < 0 darkens toward black
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

-- A 2 px focus ring shown when the button is the selected object (gamepad or keyboard).
function Button.focusRing(radius: UDim): Frame
	return Create("Frame", {
		Name = "FocusRing",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromOffset(-4, -4),
	}, {
		Create("UICorner", { CornerRadius = UDim.new(radius.Scale, radius.Offset + 4) }),
		Create("UIStroke", {
			Color = Theme.color.focus,
			Thickness = Theme.focusThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

function Button.new(ctx: Context.Ctx, opts: Options): Button
	local variant: Variant = opts.variant or "primary"
	local base, fg, hoverAmount
	if variant == "primary" then
		base, fg, hoverAmount = ctx.accent, Theme.color.bg, 0.15
	elseif variant == "secondary" then
		base, fg, hoverAmount = Theme.color.surfaceRaised, Theme.color.text, 0.08
	else
		base, fg, hoverAmount = Theme.color.surfaceRaised, Theme.color.textMuted, 0.08
	end
	local restTransparency = if variant == "ghost" then 1 else 0

	local button = Create("TextButton", {
		Name = opts.name or "Button",
		LayoutOrder = opts.layoutOrder or 0,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = base,
		BackgroundTransparency = restTransparency,
		Size = if opts.fill then UDim2.new(1, 0, 0, ctx.metrics.tap) else UDim2.fromOffset(0, ctx.metrics.tap),
		AutomaticSize = if opts.fill then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
		Selectable = true,
		SelectionImageObject = Button.focusRing(Theme.radius.button),
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.xl),
			PaddingRight = UDim.new(0, Theme.space.xl),
			PaddingTop = UDim.new(0, Theme.space.sm),
			PaddingBottom = UDim.new(0, Theme.space.sm),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if opts.align == "left"
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if variant == "secondary" then
		Create("UIStroke", {
			Color = Theme.color.border,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
	end

	local function glyph(char: string, order: number)
		if char == "▸" or char == "▾" or char == "✓" or char == "✕" then
			local icon = Glyph.text(ctx.metrics.text.label, char, fg, Theme.font.bold)
			icon.Name = "Glyph"
			icon.LayoutOrder = order
			icon.Parent = button
			return
		end
		Create("TextLabel", {
			Name = "Glyph",
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = char,
			TextColor3 = fg,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Parent = button,
		})
	end
	if opts.glyphLeft then
		glyph(opts.glyphLeft, 1)
	end
	local label = Create("TextLabel", {
		Name = "Label",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Text = opts.text,
		RichText = true,
		TextColor3 = fg,
		FontFace = Theme.font.bold,
		TextSize = ctx.metrics.text.label,
		TextWrapped = opts.fill == true,
		TextXAlignment = if opts.align == "left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		Parent = button,
	})
	if opts.fill then
		-- Full-width buttons wrap long labels instead of growing sideways.
		label.AutomaticSize = Enum.AutomaticSize.Y
		local glyphCount = (if opts.glyphLeft then 1 else 0) + (if opts.glyphRight then 1 else 0)
		label.Size = UDim2.new(1, -glyphCount * (ctx.metrics.text.label + Theme.space.sm), 0, 0)
	end
	if opts.glyphRight then
		glyph(opts.glyphRight, 3)
	end

	local enabled = true
	local hovered, pressed = false, false
	local function refresh()
		local color, transparency = base, restTransparency
		if not enabled then
			transparency = if variant == "ghost" then 1 else 0.6
		elseif pressed then
			color, transparency = shade(base, -0.12), 0
		elseif hovered then
			color, transparency = shade(base, hoverAmount), 0
		end
		local info = if ctx.reducedMotion then TweenInfo.new(0) else Theme.ease.hover
		TweenService:Create(button, info, { BackgroundColor3 = color, BackgroundTransparency = transparency }):Play()
		local alpha = if enabled then 0 else 0.55
		for _, child in button:GetChildren() do
			if child:IsA("TextLabel") then
				child.TextTransparency = alpha
			end
		end
	end

	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh()
	end)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = true
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = false
			refresh()
		end
	end)
	button.Activated:Connect(function()
		if enabled then
			opts.onActivated()
		end
	end)

	local self = {
		instance = button,
		label = label,
	}

	function self.setEnabled(_self: any, on: boolean)
		enabled = on
		button.Active = on
		button.Selectable = on
		refresh()
	end

	function self.setText(_self: any, text: string)
		label.Text = text
	end

	function self.destroy(_self: any)
		button:Destroy()
	end

	return (self :: any) :: Button
end

return Button
