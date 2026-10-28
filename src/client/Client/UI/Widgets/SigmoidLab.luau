--!strict
-- SigmoidLab: 1-D logistic regression. Sliders for w and b draw σ(wx + b) over the data, the 0.5
-- threshold, the decision boundary x = −b/w and the live log-loss. With showTraining, Step takes
-- one gradient-descent step and Auto runs until the gradient is tiny.
-- props: data { xs, ys }, xLabel, start { w, b }, showTraining

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Prob = require(Shared:WaitForChild("Math"):WaitForChild("Prob"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Slider = require(Components:WaitForChild("Slider"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local X_MIN, X_MAX = 0, 6
local W_RANGE = { -1, 4, 0.05 }
local B_RANGE = { -12, 4, 0.1 }
local SEGMENTS = 48
local RATE = 0.5
local MAX_AUTO_STEPS = 4000
local STEPS_PER_FRAME = 20
local TOLERANCE = 1e-3

local SigmoidLab = {}

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

function SigmoidLab.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local xs: { number } = props.data.xs
	local ys: { number } = props.data.ys
	local start = props.start or { w = 1, b = 0 }
	local showTraining = props.showTraining == true
	local w, b = start.w, start.b
	local steps = 0
	local autoConnection: RBXScriptConnection? = nil

	local root = Create("Frame", {
		Name = "SigmoidLab",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.md),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local readout = Text.new(ctx, "mono", "", {
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	local plot = Plot.new(ctx, {
		width = 520,
		height = 200,
		xMin = X_MIN,
		xMax = X_MAX,
		yMin = 0,
		yMax = 1,
		xTicks = { 0, 1, 2, 3, 4, 5, 6 },
		yTicks = { 0, 0.5, 1 },
		xLabel = props.xLabel,
		layoutOrder = 2,
	})
	plot.frame.Parent = root

	-- 0.5 threshold
	plot:line(Vector2.new(X_MIN, 0.5), Vector2.new(X_MAX, 0.5), Theme.color.textFaint, 1, 0.3)
	-- Data: passed = circle at 1, not passed = square at 0
	for i, x in xs do
		local passed = ys[i] == 1
		plot:dot(x, ys[i], if passed then Theme.role.output else Theme.color.textMuted, 14, if passed then "circle" else "square")
	end
	-- Curve segments, created once and moved on every change
	local curve = {}
	for i = 1, SEGMENTS do
		curve[i] = plot:line(Vector2.new(0, 0), Vector2.new(0, 0), Theme.role.output, 3)
	end
	local boundary = plot:line(Vector2.new(0, 0), Vector2.new(0, 1), Theme.role.weight, 2, 0.2)
	local boundaryLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Text = "boundary",
		TextColor3 = Theme.role.weight,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.caption,
		Parent = plot.area,
	})

	Plot.legend(ctx, {
		{ label = "passed (1)", color = Theme.role.output, shape = "circle" },
		{ label = "not passed (0)", color = Theme.color.textMuted, shape = "square" },
	}, 3).Parent = root

	local wSlider, bSlider
	local stepButton, autoButton

	local function render()
		local loss, gw, gb = Prob.logistic1D(xs, ys, w, b)
		for i, seg in curve do
			local x0 = X_MIN + (X_MAX - X_MIN) * (i - 1) / SEGMENTS
			local x1 = X_MIN + (X_MAX - X_MIN) * i / SEGMENTS
			plot:setLine(seg, Vector2.new(x0, Prob.sigmoid(w * x0 + b)), Vector2.new(x1, Prob.sigmoid(w * x1 + b)), 3)
		end
		local text = string.format(
			'<font color="%s">w = %s</font>   <font color="%s">b = %s</font>   log-loss = %.3f',
			hex(Theme.role.weight),
			Plot.num(w, 2),
			hex(Theme.role.weight),
			Plot.num(b, 2),
			loss
		)
		local hasBoundary = math.abs(w) > 1e-9 and -b / w >= X_MIN and -b / w <= X_MAX
		boundary.Visible = hasBoundary
		boundaryLabel.Visible = hasBoundary
		if hasBoundary then
			local x = -b / w
			plot:setLine(boundary, Vector2.new(x, 0), Vector2.new(x, 1), 2)
			local p = plot:toPx(x, 1)
			boundaryLabel.Position = UDim2.fromOffset(p.X + 6, p.Y)
			boundaryLabel.Text = `boundary x = {Plot.num(x, 2)}`
		end
		if showTraining then
			text ..= string.format("\nsteps = %d   |gradient| = %.3f", steps, math.sqrt(gw * gw + gb * gb))
		end
		readout.Text = text
	end

	local function stopAuto()
		if autoConnection then
			autoConnection:Disconnect()
			autoConnection = nil
		end
		if autoButton then
			autoButton:setText("Auto")
		end
	end

	local function setParams(newW: number, newB: number)
		w, b = newW, newB
		-- Sliders show the nearest step; training keeps full precision internally.
		wSlider:set(math.clamp(w, W_RANGE[1], W_RANGE[2]), true)
		bSlider:set(math.clamp(b, B_RANGE[1], B_RANGE[2]), true)
		render()
	end

	wSlider = Slider.new(ctx, {
		label = "weight w",
		min = W_RANGE[1],
		max = W_RANGE[2],
		step = W_RANGE[3],
		value = w,
		color = Theme.role.weight,
		format = function(v)
			return Plot.num(v, 2)
		end,
		layoutOrder = 4,
		onChanged = function(v)
			stopAuto()
			w = v
			render()
		end,
	})
	wSlider.instance.Parent = root
	bSlider = Slider.new(ctx, {
		label = "bias b",
		min = B_RANGE[1],
		max = B_RANGE[2],
		step = B_RANGE[3],
		value = b,
		color = Theme.role.weight,
		format = function(v)
			return Plot.num(v, 1)
		end,
		layoutOrder = 5,
		onChanged = function(v)
			stopAuto()
			b = v
			render()
		end,
	})
	bSlider.instance.Parent = root

	if showTraining then
		local controls = Create("Frame", {
			Name = "Training",
			LayoutOrder = 6,
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
		stepButton = Button.new(ctx, {
			text = "Step",
			name = "Step",
			variant = "secondary",
			layoutOrder = 1,
			onActivated = function()
				stopAuto()
				local nw, nb = Prob.logisticStep1D(xs, ys, w, b, RATE)
				steps += 1
				setParams(nw, nb)
			end,
		})
		stepButton.instance.Parent = controls
		autoButton = Button.new(ctx, {
			text = "Auto",
			name = "Auto",
			layoutOrder = 2,
			onActivated = function()
				if autoConnection then
					stopAuto()
					return
				end
				autoButton:setText("Stop")
				autoConnection = RunService.Heartbeat:Connect(function()
					local nw, nb = w, b
					for _ = 1, STEPS_PER_FRAME do
						nw, nb = Prob.logisticStep1D(xs, ys, nw, nb, RATE)
						steps += 1
					end
					setParams(nw, nb)
					local _, gw, gb = Prob.logistic1D(xs, ys, w, b)
					if math.sqrt(gw * gw + gb * gb) < TOLERANCE or steps >= MAX_AUTO_STEPS then
						stopAuto()
					end
				end)
			end,
		})
		autoButton.instance.Parent = controls
	end

	render()

	return {
		root = root,
		illustrative = false,
		reset = function()
			stopAuto()
			steps = 0
			setParams(start.w, start.b)
		end,
		destroy = function()
			stopAuto()
			wSlider:destroy()
			bSlider:destroy()
			root:Destroy()
		end,
	}
end

return SigmoidLab
