--!strict
-- Slider with a value label. Drag the track (mouse/touch), or use the − / + buttons, which are
-- selectable for keyboard and gamepad and meet the tap-target size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Button = require(script.Parent:WaitForChild("Button"))

export type Options = {
	label: string,
	min: number,
	max: number,
	step: number,
	value: number,
	color: Color3?,
	format: ((value: number) -> string)?,
	onChanged: (value: number) -> (),
	layoutOrder: number?,
}

export type Slider = {
	instance: Frame,
	get: (self: Slider) -> number,
	set: (self: Slider, value: number, silent: boolean?) -> (),
	destroy: (self: Slider) -> (),
}

local TRACK_H = 8
local KNOB = 24

local Slider = {}

local function snap(value: number, min: number, max: number, step: number): number
	local snapped = min + math.floor((value - min) / step + 0.5) * step
	-- Round away float noise so labels and comparisons stay clean.
	snapped = math.floor(snapped / step + 0.5) * step
	return math.clamp(snapped, min, max)
end

function Slider.new(ctx: Context.Ctx, opts: Options): Slider
	local color = opts.color or ctx.accent
	local format = opts.format or function(v: number): string
		return string.format("%.2f", v)
	end
	local value = snap(opts.value, opts.min, opts.max, opts.step)
	local connections: { RBXScriptConnection } = {}

	local root = Create("Frame", {
		Name = "Slider",
		LayoutOrder = opts.layoutOrder or 0,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.xs), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local header = Create("Frame", {
		Name = "Header",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.text.label + 6),
		Parent = root,
	})
	Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.6, 1),
		Text = opts.label,
		RichText = true,
		TextColor3 = color,
		FontFace = Theme.font.bold,
		TextSize = ctx.metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local valueLabel = Create("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.4, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	local row = Create("Frame", {
		Name = "Row",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.tap),
		Parent = root,
	})
	local tap = ctx.metrics.tap
	local track = Create("TextButton", {
		Name = "Track",
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(tap + Theme.space.md, 0),
		Size = UDim2.new(1, -2 * (tap + Theme.space.md), 1, 0),
		Parent = row,
	})
	local rail = Create("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, TRACK_H),
		BackgroundColor3 = Theme.color.border,
		BorderSizePixel = 0,
		Parent = track,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = rail,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		BackgroundColor3 = Theme.color.text,
		ZIndex = 2,
		Parent = rail,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIStroke", { Color = color, Thickness = 3 }),
	})

	local self: any = { instance = root }

	local function render()
		local t = (value - opts.min) / (opts.max - opts.min)
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		valueLabel.Text = format(value)
	end

	function self.get(_self: any): number
		return value
	end

	function self.set(_self: any, newValue: number, silent: boolean?)
		local snapped = snap(newValue, opts.min, opts.max, opts.step)
		if snapped == value then
			render()
			return
		end
		value = snapped
		render()
		if not silent then
			opts.onChanged(value)
		end
	end

	local minus = Button.new(ctx, {
		text = "−",
		variant = "secondary",
		name = "Decrease",
		onActivated = function()
			self:set(value - opts.step)
		end,
	})
	minus.instance.AutomaticSize = Enum.AutomaticSize.None
	minus.instance.Size = UDim2.fromOffset(tap, tap)
	minus.instance.Parent = row
	local plus = Button.new(ctx, {
		text = "+",
		variant = "secondary",
		name = "Increase",
		onActivated = function()
			self:set(value + opts.step)
		end,
	})
	plus.instance.AutomaticSize = Enum.AutomaticSize.None
	plus.instance.AnchorPoint = Vector2.new(1, 0)
	plus.instance.Position = UDim2.fromScale(1, 0)
	plus.instance.Size = UDim2.fromOffset(tap, tap)
	plus.instance.Parent = row
	for _, b in { minus, plus } do
		local padding = b.instance:FindFirstChildOfClass("UIPadding")
		if padding then
			padding:Destroy()
		end
	end

	-- Dragging: position along the rail in screen space, so UIScale is already accounted for.
	local dragging: InputObject? = nil
	local function fromScreenX(x: number)
		local left = rail.AbsolutePosition.X
		local width = math.max(1, rail.AbsoluteSize.X)
		local t = math.clamp((x - left) / width, 0, 1)
		self:set(opts.min + t * (opts.max - opts.min))
	end
	table.insert(
		connections,
		track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = input
				fromScreenX(input.Position.X)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or (input.UserInputType == Enum.UserInputType.Touch and input == dragging)
			then
				fromScreenX(input.Position.X)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input == dragging
				)
			then
				dragging = nil
			end
		end)
	)

	function self.destroy(_self: any)
		for _, c in connections do
			c:Disconnect()
		end
		root:Destroy()
	end

	render()
	return self :: Slider
end

return Slider
