--!strict
-- Plot helper for widgets (not a widget itself): a data-space → pixel mapping, axes with tick
-- labels, and reusable line/dot primitives. Lines are Frames rotated between two points, so
-- anything that moves should be updated in place with setLine, not recreated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))

export type Options = {
	width: number,
	height: number,
	xMin: number,
	xMax: number,
	yMin: number,
	yMax: number,
	xTicks: { number }?,
	yTicks: { number }?,
	xLabel: string?,
	yLabel: string?,
	layoutOrder: number?,
}

export type Shape = "circle" | "square" | "ring"

local Plot = {}
Plot.__index = Plot

-- Numbers with a typographic minus sign and no trailing ".0".
function Plot.num(n: number, decimals: number?): string
	local s = if decimals then string.format(`%.{decimals}f`, n) else tostring(n)
	if n < 0 then
		s = "−" .. string.sub(s, 2)
	end
	return s
end

function Plot.new(ctx: Context.Ctx, opts: Options): any
	local left = ctx.metrics.text.caption * 3 + Theme.space.sm
	local bottom = ctx.metrics.text.caption * 2 + Theme.space.md
	local frame = Create("Frame", {
		Name = "Plot",
		LayoutOrder = opts.layoutOrder or 0,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(opts.width + left + Theme.space.lg, opts.height + bottom + Theme.space.sm),
	})
	local area = Create("Frame", {
		Name = "Area",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, Theme.space.sm),
		Size = UDim2.fromOffset(opts.width, opts.height),
		Parent = frame,
	})
	local self = setmetatable({ ctx = ctx, opts = opts, frame = frame, area = area }, Plot)

	local function caption(text: string, pos: Vector2, anchor: Vector2)
		Create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = anchor,
			Position = UDim2.fromOffset(pos.X, pos.Y),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = text,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.mono,
			TextSize = ctx.metrics.text.caption,
			Parent = area,
		})
	end

	-- Axes
	self:line(Vector2.new(opts.xMin, opts.yMin), Vector2.new(opts.xMax, opts.yMin), Theme.color.border, 2)
	self:line(Vector2.new(opts.xMin, opts.yMin), Vector2.new(opts.xMin, opts.yMax), Theme.color.border, 2)
	for _, x in opts.xTicks or {} do
		local p = self:toPx(x, opts.yMin)
		caption(Plot.num(x), p + Vector2.new(0, Theme.space.xs), Vector2.new(0.5, 0))
	end
	for _, y in opts.yTicks or {} do
		local p = self:toPx(opts.xMin, y)
		caption(Plot.num(y), p - Vector2.new(Theme.space.sm, 0), Vector2.new(1, 0.5))
	end
	if opts.xLabel then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0, left + opts.width / 2, 1, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = opts.xLabel,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.regular,
			TextSize = ctx.metrics.text.caption,
			Parent = frame,
		})
	end
	if opts.yLabel then
		caption(opts.yLabel, Vector2.new(Theme.space.sm, 0), Vector2.new(0, 0))
	end
	return self
end

function Plot.toPx(self: any, x: number, y: number): Vector2
	local o = self.opts
	return Vector2.new(
		(x - o.xMin) / (o.xMax - o.xMin) * o.width,
		(1 - (y - o.yMin) / (o.yMax - o.yMin)) * o.height
	)
end

-- Clamps a data point to the plot box.
function Plot.clamp(self: any, p: Vector2): Vector2
	local o = self.opts
	return Vector2.new(math.clamp(p.X, o.xMin, o.xMax), math.clamp(p.Y, o.yMin, o.yMax))
end

-- Repositions an existing line frame between two pixel points.
function Plot.setLinePx(_self: any, line: Frame, a: Vector2, b: Vector2, thickness: number?)
	local mid = (a + b) / 2
	local d = b - a
	line.Position = UDim2.fromOffset(mid.X, mid.Y)
	line.Size = UDim2.fromOffset(d.Magnitude + 1, thickness or line.Size.Y.Offset)
	line.Rotation = math.deg(math.atan2(d.Y, d.X))
end

function Plot.setLine(self: any, line: Frame, a: Vector2, b: Vector2, thickness: number?)
	self:setLinePx(line, self:toPx(a.X, a.Y), self:toPx(b.X, b.Y), thickness)
end

-- A line between two data points.
function Plot.line(self: any, a: Vector2, b: Vector2, color: Color3, thickness: number, transparency: number?, parent: Instance?): Frame
	local line = Create("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, thickness),
		Parent = parent or self.area,
	})
	self:setLine(line, a, b, thickness)
	return line
end

-- A marker at a data point. Shape carries meaning alongside color.
function Plot.dot(self: any, x: number, y: number, color: Color3, size: number, shape: Shape, parent: Instance?): Frame
	local p = self:toPx(x, y)
	local dot = Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.X, p.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = if shape == "ring" then 1 else 0,
		ZIndex = 3,
		Parent = parent or self.area,
	}, {
		Create("UIStroke", {
			Color = if shape == "ring" then color else Theme.color.surface,
			Thickness = if shape == "ring" then 3 else 2,
		}),
	})
	if shape ~= "square" then
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
	else
		Create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = dot })
	end
	return dot
end

-- A centered legend row of drawn markers (no font glyphs) with labels.
function Plot.legend(ctx: Context.Ctx, items: { { label: string, color: Color3, shape: Shape } }, layoutOrder: number?): Frame
	local row = Create("Frame", {
		Name = "Legend",
		LayoutOrder = layoutOrder or 0,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.space.md),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local size = math.max(10, math.floor(ctx.metrics.text.caption * 0.75))
	for i, item in items do
		local marker = Create("Frame", {
			LayoutOrder = 2 * i - 1,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = item.color,
			BackgroundTransparency = if item.shape == "ring" then 1 else 0,
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = if item.shape == "square" then UDim.new(0, 2) else UDim.new(0.5, 0) }),
		})
		if item.shape == "ring" then
			Create("UIStroke", { Color = item.color, Thickness = 2, Parent = marker })
		end
		Create("TextLabel", {
			LayoutOrder = 2 * i,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = item.label,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.regular,
			TextSize = ctx.metrics.text.caption,
			Parent = row,
		}, {
			Create("UIPadding", { PaddingRight = UDim.new(0, Theme.space.md) }),
		})
	end
	return row
end

-- A transparent full-size container, for groups of marks that get redrawn together.
function Plot.layer(self: any, name: string): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self.area,
	})
end

return Plot
