--!strict
-- GradientTelephone: how much gradient reaches each earlier step of a 20-step chain, in the
-- simplified scalar case where every step multiplies it by the same factor: size ∝ factorᵏ.
-- Optional clipping caps the size at props.clip. Labeled as a simplification in the UI.
-- props: steps, clip

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Slider = require(Components:WaitForChild("Slider"))
local Toggle = require(Components:WaitForChild("Toggle"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local CHART_W, CHART_H = 540, 170
local START_FACTOR = 0.8

local GradientTelephone = {}

local function size(x: number): string
	if x >= 1000 then
		return string.format("%.0f", x)
	elseif x >= 0.01 then
		return string.format("%.2f", x)
	end
	return string.format("%.1e", x):gsub("e%-0?", "×10⁻"):gsub("e%+0?", "×10^")
end

function GradientTelephone.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local steps: number = props.steps or 20
	local clipAt: number = props.clip or 5
	local factor = START_FACTOR
	local clipping = false

	local root = Create("Frame", {
		Name = "GradientTelephone",
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

	local readout = Text.new(ctx, "body", "", {
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	-- Chart: bar k is the word k steps before the end. Heights use a cap so explosions stay on screen.
	local chart = Create("Frame", {
		Name = "Chart",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(CHART_W, CHART_H + 26),
		Parent = root,
	})
	local barW = math.floor((CHART_W - (steps - 1) * 4) / steps)
	local bars: { Frame } = {}
	for k = 0, steps - 1 do
		local index = steps - k -- leftmost = earliest word
		local x = (index - 1) * (barW + 4)
		bars[k] = Create("Frame", {
			Name = "Bar" .. k,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(x, CHART_H),
			Size = UDim2.fromOffset(barW, 2),
			BackgroundColor3 = ctx.accent,
			BorderSizePixel = 0,
			Parent = chart,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 2) }),
		})
	end
	-- Reference line at size 1 (no change)
	local oneLine = Create("Frame", {
		Name = "One",
		Size = UDim2.fromOffset(CHART_W, 1),
		BackgroundColor3 = Theme.color.textFaint,
		BorderSizePixel = 0,
		Parent = chart,
	})
	Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "×1",
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.caption,
		Parent = oneLine,
	})
	for _, info in { { 0, Vector2.new(0, 0), "earliest word" }, { 1, Vector2.new(1, 0), "where the error is" } } do
		Create("TextLabel", {
			AnchorPoint = info[2],
			Position = UDim2.new(info[1], 0, 0, CHART_H + 6),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = info[3],
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.regular,
			TextSize = ctx.metrics.text.caption,
			Parent = chart,
		})
	end

	local cap = clipAt * 1.2 -- chart top
	local function render(animate: boolean)
		oneLine.Position = UDim2.fromOffset(0, CHART_H * (1 - 1 / cap))
		local farthest = 0
		for k = 0, steps - 1 do
			local raw = factor ^ k
			local value = if clipping then math.min(raw, clipAt) else raw
			if k == steps - 1 then
				farthest = value
			end
			local h = math.max(2, math.min(value, cap) / cap * CHART_H)
			local bar = bars[k]
			local goal = { Size = UDim2.fromOffset(barW, h) }
			if animate and not ctx.reducedMotion then
				TweenService:Create(bar, Theme.ease.state, goal):Play()
			else
				bar.Size = goal.Size
			end
			bar.BackgroundColor3 = if value > cap then Theme.color.danger elseif value < 0.05 then Theme.color.textFaint else ctx.accent
		end
		local verdict
		if farthest < 0.05 then
			verdict = "vanishing: early words barely learn"
		elseif farthest > clipAt then
			verdict = "exploding: training becomes unstable"
		elseif clipping and factor > 1 then
			verdict = "clipped: capped at ×" .. clipAt
		else
			verdict = "steady"
		end
		readout.Text = string.format(
			'Gradient reaching the first word: <b>×%s</b> (%s)',
			size(farthest),
			verdict
		)
	end

	local slider = Slider.new(ctx, {
		label = "factor per step",
		min = 0.5,
		max = 1.5,
		step = 0.05,
		value = factor,
		format = function(v)
			return string.format("×%.2f", v)
		end,
		layoutOrder = 3,
		onChanged = function(v)
			factor = v
			render(true)
		end,
	})
	slider.instance.Parent = root

	local clipToggle: TextButton? = nil
	local function buildToggle()
		if clipToggle then
			clipToggle:Destroy()
		end
		clipToggle = Toggle.new(ctx, {
			label = `Gradient clipping (cap at ×{clipAt})`,
			value = clipping,
			layoutOrder = 4,
			onChanged = function(on)
				clipping = on
				render(true)
			end,
		})
		;(clipToggle :: TextButton).Parent = root
	end
	buildToggle()

	Text.new(ctx, "caption", "Simplified scalar case: the gradient shrinks or grows by the same factor each step.", {
		LayoutOrder = 5,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textFaint,
		Parent = root,
	})

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			factor, clipping = START_FACTOR, false
			slider:set(factor, true)
			buildToggle()
			render(true)
		end,
		destroy = function()
			slider:destroy()
			root:Destroy()
		end,
	}
end

return GradientTelephone
