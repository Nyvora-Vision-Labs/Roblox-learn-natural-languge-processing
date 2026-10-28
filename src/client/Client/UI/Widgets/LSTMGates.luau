--!strict
-- LSTMGates: a one-number cell state carried across the sentence by the real LSTM update
-- cₜ = f·cₜ₋₁ + i·gₜ and, at the verb, h = o·tanh(c) (Math/Linear.lstmCell). The subject writes
-- +1 ("plural") fully; the sliders set f and i for every word after it, and o at the verb.
-- props: story { words, candidates, writeAt, readAt }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Linear = require(Shared:WaitForChild("Math"):WaitForChild("Linear"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Slider = require(Components:WaitForChild("Slider"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local COL_W, GAP = 58, 8
local HALF = 46 -- bar half-height for |c| = 1
local START = { f = 0.5, i = 0.5, o = 1 }
local THRESHOLD = 0.3

local LSTMGates = {}

function LSTMGates.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local story = props.story
	local words: { string } = story.words
	local writeIndex = table.find(words, story.writeAt) or 1
	local readIndex = table.find(words, story.readAt) or #words
	local f, i, o = START.f, START.i, START.o
	local pluralColor, singularColor = Theme.role.output, Theme.role.input

	local root = Create("Frame", {
		Name = "LSTMGates",
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

	local verdict = Text.new(ctx, "body", "", {
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	-- Cell-state chart: one column per word, bar up = plural (+), down = singular (−)
	local chartW = #words * COL_W + (#words - 1) * GAP
	local chart = Create("Frame", {
		Name = "Chart",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(chartW, 2 * HALF + 2 * ctx.metrics.text.caption + 24),
		Parent = root,
	})
	Create("Frame", {
		Name = "Zero",
		Position = UDim2.fromOffset(0, HALF),
		Size = UDim2.fromOffset(chartW, 1),
		BackgroundColor3 = Theme.color.border,
		BorderSizePixel = 0,
		Parent = chart,
	})
	local bars, values = {}, {}
	for t, word in words do
		local x = (t - 1) * (COL_W + GAP)
		local isRead = t == readIndex
		bars[t] = Create("Frame", {
			Name = "Bar" .. t,
			Position = UDim2.fromOffset(x + COL_W * 0.2, HALF),
			Size = UDim2.fromOffset(COL_W * 0.6, 0),
			BackgroundColor3 = pluralColor,
			BorderSizePixel = 0,
			Visible = t >= writeIndex and t <= readIndex,
			Parent = chart,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
		})
		values[t] = Create("TextLabel", {
			Position = UDim2.fromOffset(x - GAP / 2, 2 * HALF + 4),
			Size = UDim2.fromOffset(COL_W + GAP, ctx.metrics.text.caption + 4),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.mono,
			TextSize = ctx.metrics.text.caption,
			Parent = chart,
		})
		Create("TextLabel", {
			Position = UDim2.fromOffset(x - GAP / 2, 2 * HALF + ctx.metrics.text.caption + 10),
			Size = UDim2.fromOffset(COL_W + GAP, ctx.metrics.text.caption + 6),
			BackgroundColor3 = Theme.color.surfaceRaised,
			BackgroundTransparency = if isRead or t == writeIndex then 0 else 1,
			Text = word,
			TextColor3 = if isRead or t == writeIndex then Theme.color.text else Theme.role.input,
			FontFace = if isRead or t == writeIndex then Theme.font.bold else Theme.font.regular,
			TextSize = ctx.metrics.text.caption,
			Parent = chart,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
		})
	end

	Plot.legend(ctx, {
		{ label = "+ plural memory", color = pluralColor, shape = "square" },
		{ label = "− singular memory", color = singularColor, shape = "square" },
	}, 3).Parent = root

	local function render(animate: boolean)
		local c = 0
		local h = 0
		for t, word in words do
			local g = story.candidates[word] or 0
			if t == writeIndex then
				c = Linear.lstmCell(c, 1, 1, g, 1) -- the subject is written in fully
			elseif t > writeIndex and t < readIndex then
				c = Linear.lstmCell(c, f, i, g, 1)
			elseif t == readIndex then
				-- The verb only reads the memory: keep c as is, reveal it through o.
				c, h = Linear.lstmCell(c, 1, 0, 0, o)
			end
			if t >= writeIndex and t <= readIndex then
				local height = math.min(1, math.abs(c)) * HALF
				local goal = {
					Size = UDim2.fromOffset(COL_W * 0.6, math.max(2, height)),
					Position = UDim2.fromOffset((t - 1) * (COL_W + GAP) + COL_W * 0.2, if c >= 0 then HALF - height else HALF),
				}
				local bar = bars[t]
				bar.BackgroundColor3 = if c >= 0 then pluralColor else singularColor
				if animate and not ctx.reducedMotion then
					TweenService:Create(bar, Theme.ease.state, goal):Play()
				else
					bar.Size, bar.Position = goal.Size, goal.Position
				end
				values[t].Text = Plot.num(c, 2)
			end
		end
		local word, tone
		if h >= THRESHOLD then
			word, tone = "“were”: plural. You kept the memory alive.", Theme.color.success
		elseif h <= -THRESHOLD then
			word, tone = "“was”: singular. “dog” overwrote the memory.", Theme.color.danger
		else
			word, tone = "Unsure: the memory faded before the verb.", Theme.color.warning
		end
		verdict.Text = string.format(
			'At “%s”: h = o·tanh(c) = <b>%s</b>.  <font color="#%s">%s</font>',
			story.readAt,
			Plot.num(h, 2),
			tone:ToHex(),
			word
		)
	end

	local sliders = {}
	local specs = {
		{ key = "f", label = "forget gate f (keep old memory)", value = f, order = 4 },
		{ key = "i", label = "input gate i (write new content)", value = i, order = 5 },
		{ key = "o", label = "output gate o (reveal at the verb)", value = o, order = 6 },
	}
	for _, spec in specs do
		local s = Slider.new(ctx, {
			label = spec.label,
			min = 0,
			max = 1,
			step = 0.05,
			value = spec.value,
			color = Theme.role.weight,
			layoutOrder = spec.order,
			onChanged = function(v)
				if spec.key == "f" then
					f = v
				elseif spec.key == "i" then
					i = v
				else
					o = v
				end
				render(true)
			end,
		})
		s.instance.Parent = root
		sliders[spec.key] = s
	end

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			f, i, o = START.f, START.i, START.o
			sliders.f:set(f, true)
			sliders.i:set(i, true)
			sliders.o:set(o, true)
			render(true)
		end,
		destroy = function()
			for _, s in sliders do
				s:destroy()
			end
			root:Destroy()
		end,
	}
end

return LSTMGates
