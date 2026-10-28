--!strict
-- TwoWaysToClassify: one 2-D dataset seen two ways.
--   Generative: a Gaussian cloud per class (fitted mean and spread), and "Generate an example",
--   which picks a class by its prior and samples a new point from that class's Gaussian.
--   Discriminative: only the logistic-regression boundary σ(w·x + b) = 0.5, fitted by gradient
--   descent. There is nothing to generate from.
-- props: points { {x1, x2, label} } (label 1 = spam), xLabel, yLabel

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Prob = require(Shared:WaitForChild("Math"):WaitForChild("Prob"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local MIN, MAX = 0, 10
local ELLIPSE_SEGMENTS = 40
local MAX_GENERATED = 6

local TwoWaysToClassify = {}

function TwoWaysToClassify.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local points: { { number } } = props.points
	local spamColor = ctx.accent
	local hamColor = Theme.role.input
	local rng = Random.new()
	local generated: { Frame } = {}

	-- Fit both models once, from the same data.
	local byClass: { [number]: { { number } } } = { [0] = {}, [1] = {} }
	for _, pt in points do
		table.insert(byClass[pt[3]], pt)
	end
	local fits = {}
	for label, list in byClass do
		local mean, sd = Prob.fitGaussian2D(list)
		fits[label] = { mean = mean, sd = sd, prior = #list / #points }
	end
	local w1, w2, b = Prob.fitLogistic2D(points, 0.05, 50000, 1e-4)

	local root = Create("Frame", {
		Name = "TwoWays",
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

	local plot = Plot.new(ctx, {
		width = 360,
		height = 300,
		xMin = MIN,
		xMax = MAX,
		yMin = MIN,
		yMax = MAX,
		xTicks = { 0, 5, 10 },
		yTicks = { 0, 5, 10 },
		xLabel = props.xLabel,
		yLabel = props.yLabel,
		layoutOrder = 2,
	})
	plot.frame.Parent = root

	-- Generative layer: 1σ and 2σ outlines per class (axis-aligned ellipses, clamped to the box)
	local generative = plot:layer("Generative")
	for label, fit in fits do
		local color = if label == 1 then spamColor else hamColor
		for _, k in { 1, 2 } do
			local previous: Vector2? = nil
			for i = 0, ELLIPSE_SEGMENTS do
				local a = i / ELLIPSE_SEGMENTS * 2 * math.pi
				local p = plot:clamp(
					Vector2.new(fit.mean.X + k * fit.sd.X * math.cos(a), fit.mean.Y + k * fit.sd.Y * math.sin(a))
				)
				if previous then
					plot:line(previous, p, color, 2, if k == 1 then 0.25 else 0.6, generative)
				end
				previous = p
			end
		end
		-- Mean marker
		plot:line(fit.mean - Vector2.new(0.25, 0), fit.mean + Vector2.new(0.25, 0), color, 2, 0, generative)
		plot:line(fit.mean - Vector2.new(0, 0.25), fit.mean + Vector2.new(0, 0.25), color, 2, 0, generative)
	end

	-- Discriminative layer: the line w1·x1 + w2·x2 + b = 0, clipped to the box
	local discriminative = plot:layer("Discriminative")
	do
		local hits: { Vector2 } = {}
		local function add(p: Vector2)
			if p.X >= MIN - 1e-9 and p.X <= MAX + 1e-9 and p.Y >= MIN - 1e-9 and p.Y <= MAX + 1e-9 then
				for _, q in hits do
					if (q - p).Magnitude < 1e-6 then
						return
					end
				end
				table.insert(hits, p)
			end
		end
		if math.abs(w2) > 1e-9 then
			add(Vector2.new(MIN, -(w1 * MIN + b) / w2))
			add(Vector2.new(MAX, -(w1 * MAX + b) / w2))
		end
		if math.abs(w1) > 1e-9 then
			add(Vector2.new(-(w2 * MIN + b) / w1, MIN))
			add(Vector2.new(-(w2 * MAX + b) / w1, MAX))
		end
		if #hits >= 2 then
			plot:line(hits[1], hits[2], Theme.role.weight, 3, 0, discriminative)
		end
		-- Label each side by the sign of the score there, not by assumption.
		local high, low = plot:toPx(9, 9), plot:toPx(1, 1)
		local highIsSpam = w1 * 9 + w2 * 9 + b > 0
		local spamSide = if highIsSpam then high else low
		local hamSide = if highIsSpam then low else high
		for _, info in { { spamSide, "spam side", spamColor, Vector2.new(1, 0) }, { hamSide, "not-spam side", hamColor, Vector2.new(0, 1) } } do
			Create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = info[4],
				Position = UDim2.fromOffset((info[1] :: Vector2).X, (info[1] :: Vector2).Y),
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				Text = info[2],
				TextColor3 = info[3],
				FontFace = Theme.font.medium,
				TextSize = ctx.metrics.text.caption,
				Parent = discriminative,
			})
		end
	end

	-- Data points on top of both layers
	local dataLayer = plot:layer("Data")
	for _, pt in points do
		local spam = pt[3] == 1
		plot:dot(pt[1], pt[2], if spam then spamColor else hamColor, 12, if spam then "square" else "circle", dataLayer)
	end
	local generatedLayer = plot:layer("Generated")

	Plot.legend(ctx, {
		{ label = "not spam", color = hamColor, shape = "circle" },
		{ label = "spam", color = spamColor, shape = "square" },
		{ label = "generated", color = Theme.color.text, shape = "ring" },
	}, 3).Parent = root

	local status = Text.new(ctx, "caption", "", {
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})

	local generate
	local mode = 1
	local function render()
		generative.Visible = mode == 1
		generatedLayer.Visible = mode == 1
		discriminative.Visible = mode == 2
		generate:setEnabled(mode == 1)
		if mode == 2 then
			status.Text = "This model only knows the line. There's nothing to generate from."
		elseif #generated == 0 then
			status.Text = "Each cloud is fitted to one class. Generate a new example from them."
		end
	end

	local switch = SegmentedControl.new(ctx, {
		options = { "Generative", "Discriminative" },
		selected = 1,
		layoutOrder = 1,
		onChanged = function(index)
			mode = index
			render()
		end,
	})
	switch.instance.Parent = root

	generate = Button.new(ctx, {
		text = "Generate an example",
		layoutOrder = 5,
		onActivated = function()
			-- Pick a class by its prior, then sample each feature from that class's Gaussian.
			local label = if rng:NextNumber() < fits[1].prior then 1 else 0
			local fit = fits[label]
			local x = fit.mean.X + fit.sd.X * Prob.standardNormal(rng)
			local y = fit.mean.Y + fit.sd.Y * Prob.standardNormal(rng)
			local p = plot:clamp(Vector2.new(x, y))
			local marker = plot:dot(p.X, p.Y, if label == 1 then spamColor else hamColor, 18, "ring", generatedLayer)
			table.insert(generated, marker)
			if #generated > MAX_GENERATED then
				table.remove(generated, 1):Destroy()
			end
			status.Text = string.format(
				"Generated a %s example at (%s, %s).",
				if label == 1 then "spam" else "not-spam",
				Plot.num(p.X, 1),
				Plot.num(p.Y, 1)
			)
		end,
	})
	generate.instance.Parent = root

	render()

	return {
		root = root,
		illustrative = false,
		reset = function()
			for _, marker in generated do
				marker:Destroy()
			end
			table.clear(generated)
			mode = 1
			switch:select(1)
			render()
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return TwoWaysToClassify
