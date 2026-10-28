--!strict
-- SigmoidPeek: step a score z and see σ(z) on the real sigmoid curve. Every number is computed.
-- props: min, max, step (defaults −6, 6, 1)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Prob = require(Shared:WaitForChild("Math"):WaitForChild("Prob"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Button = require(UI:WaitForChild("Components"):WaitForChild("Button"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local PLOT_W, PLOT_H = 520, 200
local SEGMENTS = 60
local LINE = 3
local DOT = 16

local SigmoidPeek = {}

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

-- Integers with a typographic minus sign.
local function signed(n: number): string
	return if n < 0 then "−" .. tostring(-n) else tostring(n)
end

function SigmoidPeek.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local zMin: number = props.min or -6
	local zMax: number = props.max or 6
	local step: number = props.step or 1
	local z = 0

	local root = Create("Frame", {
		Name = "SigmoidPeek",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.lg),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Readout
	local readout = Text.new(ctx, "mono", "", {
		LayoutOrder = 1,
		TextSize = ctx.metrics.text.h2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	-- Plot: x ∈ [zMin, zMax] → [0, PLOT_W], σ ∈ [0, 1] → [PLOT_H, 0]
	local plot = Create("Frame", {
		Name = "Plot",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(PLOT_W, PLOT_H + ctx.metrics.text.caption * 1.5 + Theme.space.md),
		ClipsDescendants = false,
		Parent = root,
	})
	local function toPlot(x: number, y: number): Vector2
		return Vector2.new((x - zMin) / (zMax - zMin) * PLOT_W, (1 - y) * PLOT_H)
	end
	local function line(a: Vector2, b: Vector2, color: Color3, thickness: number, transparency: number?): Frame
		local mid = (a + b) / 2
		local d = b - a
		return Create("Frame", {
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(mid.X, mid.Y),
			Size = UDim2.fromOffset(d.Magnitude + 1, thickness),
			Rotation = math.deg(math.atan2(d.Y, d.X)),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency or 0,
			BorderSizePixel = 0,
			Parent = plot,
		})
	end

	-- Axes and the 0.5 threshold
	line(toPlot(zMin, 0), toPlot(zMax, 0), Theme.color.border, 2)
	line(toPlot(0, 0), toPlot(0, 1), Theme.color.border, 2)
	line(toPlot(zMin, 0.5), toPlot(zMax, 0.5), Theme.color.textFaint, 1, 0.3)
	line(toPlot(zMin, 1), toPlot(zMax, 1), Theme.color.border, 1, 0.5)
	local function axisLabel(text: string, pos: Vector2, anchor: Vector2)
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
			Parent = plot,
		})
	end
	axisLabel("1", toPlot(zMin, 1) - Vector2.new(8, 0), Vector2.new(1, 0.5))
	axisLabel("0.5", toPlot(zMin, 0.5) - Vector2.new(8, 0), Vector2.new(1, 0.5))
	axisLabel("0", toPlot(zMin, 0) - Vector2.new(8, 0), Vector2.new(1, 0.5))
	axisLabel(signed(zMin), toPlot(zMin, 0) + Vector2.new(0, 8), Vector2.new(0.5, 0))
	axisLabel("0", toPlot(0, 0) + Vector2.new(0, 8), Vector2.new(0.5, 0))
	axisLabel(signed(zMax), toPlot(zMax, 0) + Vector2.new(0, 8), Vector2.new(0.5, 0))
	axisLabel("z", toPlot(zMax, 0) + Vector2.new(14, 0), Vector2.new(0, 0.5))

	-- The curve σ(z), from the real formula
	for i = 0, SEGMENTS - 1 do
		local x0 = zMin + (zMax - zMin) * i / SEGMENTS
		local x1 = zMin + (zMax - zMin) * (i + 1) / SEGMENTS
		line(toPlot(x0, Prob.sigmoid(x0)), toPlot(x1, Prob.sigmoid(x1)), Theme.role.output, LINE)
	end

	-- Current point with a guide down to the axis
	local guide = Create("Frame", {
		Name = "Guide",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(2, 0),
		BackgroundColor3 = Theme.role.weight,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = plot,
	})
	local dot = Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(DOT, DOT),
		BackgroundColor3 = Theme.role.output,
		ZIndex = 3,
		Parent = plot,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIStroke", { Color = Theme.color.bg, Thickness = 3 }),
	})

	-- Controls
	local controls = Create("Frame", {
		Name = "Controls",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.space.md),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local minus, plus
	local function render(animate: boolean)
		local s = Prob.sigmoid(z)
		readout.Text = string.format(
			'<font color="%s">z = %s</font>    σ(z) = <font color="%s">%.2f</font>',
			hex(Theme.role.weight),
			signed(z),
			hex(Theme.role.output),
			s
		)
		local p = toPlot(z, s)
		local base = toPlot(z, 0)
		local dotGoal = { Position = UDim2.fromOffset(p.X, p.Y) }
		local guideGoal = { Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(2, base.Y - p.Y) }
		if animate and not ctx.reducedMotion then
			TweenService:Create(dot, Theme.ease.state, dotGoal):Play()
			TweenService:Create(guide, Theme.ease.state, guideGoal):Play()
		else
			dot.Position = dotGoal.Position
			guide.Position = guideGoal.Position
			guide.Size = guideGoal.Size
		end
		minus:setEnabled(z > zMin)
		plus:setEnabled(z < zMax)
	end

	minus = Button.new(ctx, {
		text = "z − " .. step,
		variant = "secondary",
		layoutOrder = 1,
		onActivated = function()
			z = math.max(zMin, z - step)
			render(true)
		end,
	})
	minus.instance.Parent = controls
	plus = Button.new(ctx, {
		text = "z + " .. step,
		variant = "secondary",
		layoutOrder = 2,
		onActivated = function()
			z = math.min(zMax, z + step)
			render(true)
		end,
	})
	plus.instance.Parent = controls

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			z = 0
			render(true)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return SigmoidPeek
