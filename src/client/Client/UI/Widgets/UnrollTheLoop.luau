--!strict
-- UnrollTheLoop: an RNN drawn as one cell with a loop, then unrolled over the sentence. Each copy
-- shows its hidden state hₜ as a small bar vector, computed with the real recurrence
-- hₜ = tanh(Wₕ·hₜ₋₁ + Wₓ·xₜ + b) (Math/Linear). Tap a word to inspect its numbers.
-- props: rnn { words, embeddings, Wh, Wx, b }

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
local Button = require(Components:WaitForChild("Button"))
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local CELL = 56
local GAP = 14
local BAR_W, BAR_H = 10, 30 -- each bar's half-height is BAR_H for |value| = 1

local UnrollTheLoop = {}

local function sub(n: number): string
	local digits = { "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉" }
	local s = ""
	for ch in tostring(n):gmatch("%d") do
		s ..= digits[tonumber(ch) :: number + 1]
	end
	return s
end

local function vec(v: { number }): string
	local parts = {}
	for _, x in v do
		table.insert(parts, Plot.num(x, 2))
	end
	return "(" .. table.concat(parts, ", ") .. ")"
end

function UnrollTheLoop.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local rnn = props.rnn
	local words: { string } = rnn.words
	local xs = {}
	for t, w in words do
		xs[t] = rnn.embeddings[w]
	end
	local dim = #rnn.b
	local hs = Linear.rnnRun(table.create(dim, 0), xs, rnn.Wh, rnn.Wx, rnn.b)
	local hiddenColor = Theme.role.hidden
	local selected: number? = nil
	local cleanupThread: thread? = nil

	local root = Create("Frame", {
		Name = "UnrollTheLoop",
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

	local stageW = #words * CELL + (#words - 1) * GAP
	local stageH = 2 * BAR_H + 8 + CELL + 12 + ctx.metrics.text.caption + 10

	-- Rolled view: one cell with a self-loop
	local rolled = Create("Frame", {
		Name = "Rolled",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(stageW, stageH),
		Parent = root,
	})
	do
		local cx, cy = stageW / 2, stageH / 2 + 10
		Create("Frame", {
			Name = "Loop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx + CELL * 0.75, cy - CELL * 0.2),
			Size = UDim2.fromOffset(CELL * 1.3, CELL * 1.3),
			BackgroundTransparency = 1,
			Parent = rolled,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Create("UIStroke", { Color = hiddenColor, Thickness = 3 }),
		})
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(CELL * 1.6, CELL * 1.3),
			BackgroundColor3 = Theme.color.surfaceRaised,
			Text = "RNN\ncell",
			TextColor3 = Theme.color.text,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			ZIndex = 2,
			Parent = rolled,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UIStroke", { Color = Theme.role.weight, Thickness = 2 }),
		})
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(cx + CELL * 1.45, cy - CELL * 0.2),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = "h carried to\nthe next word",
			TextColor3 = hiddenColor,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = rolled,
		})
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(cx, cy + CELL * 0.75),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = "one word at a time: xₜ",
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			Parent = rolled,
		})
	end

	-- Unrolled view: one copy per word
	local unrolled = Create("Frame", {
		Name = "Unrolled",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(stageW, stageH),
		Visible = false,
		Parent = root,
	})
	local columns = {}
	local cellTop = 2 * BAR_H + 8
	for t, word in words do
		local x = (t - 1) * (CELL + GAP)
		local column = Create("TextButton", {
			Name = "Step" .. t,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(CELL, stageH),
			BackgroundTransparency = 1,
			Text = "",
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.chip),
			Parent = unrolled,
		})
		-- Hidden-state bars: centered on a zero line, up for positive, down for negative
		local barsW = dim * BAR_W + (dim - 1) * 3
		Create("Frame", {
			Name = "Zero",
			Position = UDim2.fromOffset((CELL - barsW) / 2 - 2, BAR_H),
			Size = UDim2.fromOffset(barsW + 4, 1),
			BackgroundColor3 = Theme.color.border,
			BorderSizePixel = 0,
			Parent = column,
		})
		for k, value in hs[t] do
			local height = math.max(2, math.abs(value) * BAR_H)
			Create("Frame", {
				Name = "Bar" .. k,
				AnchorPoint = Vector2.new(0, if value >= 0 then 1 else 0),
				Position = UDim2.fromOffset((CELL - barsW) / 2 + (k - 1) * (BAR_W + 3), BAR_H),
				Size = UDim2.fromOffset(BAR_W, height),
				BackgroundColor3 = hiddenColor,
				BackgroundTransparency = if value >= 0 then 0 else 0.35,
				BorderSizePixel = 0,
				Parent = column,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 2) }),
			})
		end
		local box = Create("Frame", {
			Name = "Cell",
			Position = UDim2.fromOffset(0, cellTop),
			Size = UDim2.fromOffset(CELL, CELL),
			BackgroundColor3 = Theme.color.surfaceRaised,
			Parent = column,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
			Create("UIStroke", { Name = "Edge", Color = Theme.role.weight, Thickness = 1 }),
			Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "h" .. sub(t),
				TextColor3 = hiddenColor,
				FontFace = Theme.font.monoBold,
				TextSize = ctx.metrics.text.label,
			}),
		})
		Create("TextLabel", {
			Name = "Word",
			Position = UDim2.fromOffset(-GAP / 2, cellTop + CELL + 8),
			Size = UDim2.fromOffset(CELL + GAP, ctx.metrics.text.caption + 6),
			BackgroundTransparency = 1,
			Text = word,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			Parent = column,
		})
		if t < #words then -- arrow carrying h to the next copy
			local y = cellTop + CELL / 2
			Create("Frame", {
				Name = "Carry",
				Position = UDim2.fromOffset(x + CELL, y - 1),
				Size = UDim2.fromOffset(GAP, 3),
				BackgroundColor3 = hiddenColor,
				BorderSizePixel = 0,
				Parent = unrolled,
			})
		end
		columns[t] = { button = column, box = box }
	end

	local inspect = Text.new(ctx, "body", "", {
		LayoutOrder = 3,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.caption + 2,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})
	Text.new(ctx, "caption", "Toy weights; every hidden value is computed with the real recurrence.", {
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textFaint,
		Parent = root,
	})

	local function renderInspect()
		for t, c in columns do
			local edge = c.box:FindFirstChild("Edge") :: UIStroke
			edge.Color = if t == selected then ctx.accent else Theme.role.weight
			edge.Thickness = if t == selected then 3 else 1
		end
		if not unrolled.Visible then
			inspect.Text = "Rolled up, the loop hides that the same cell runs once per word."
		elseif not selected then
			inspect.Text = "Eight copies, one set of weights. Tap a word to see its hidden state."
		else
			local t = selected :: number
			local prev = if t > 1 then "h" .. sub(t - 1) else "h₀ = (0, 0, 0)"
			inspect.Text = string.format(
				'After “%s”: h%s = %s\n= tanh(Wₕ·%s + Wₓ·x%s + b)',
				words[t],
				sub(t),
				vec(hs[t]),
				prev,
				sub(t)
			)
		end
	end

	for t, c in columns do
		c.button.Activated:Connect(function()
			selected = t
			renderInspect()
		end)
	end

	local function stopAnimation()
		if cleanupThread then
			pcall(task.cancel, cleanupThread)
			cleanupThread = nil
		end
	end

	local function show(unroll: boolean)
		stopAnimation()
		rolled.Visible = not unroll
		unrolled.Visible = unroll
		if unroll and not ctx.reducedMotion then
			-- Copies appear left to right, like the loop unwinding.
			for _, c in columns do
				c.button.Visible = false
			end
			cleanupThread = task.spawn(function()
				for _, c in columns do
					c.button.Visible = true
					c.box.BackgroundColor3 = hiddenColor:Lerp(Theme.color.surfaceRaised, 0.5)
					TweenService:Create(c.box, Theme.ease.state, { BackgroundColor3 = Theme.color.surfaceRaised }):Play()
					task.wait(0.07)
				end
				cleanupThread = nil
			end)
		else
			for _, c in columns do
				c.button.Visible = true
			end
		end
		renderInspect()
	end

	local switch = SegmentedControl.new(ctx, {
		options = { "Rolled", "Unrolled" },
		selected = 1,
		layoutOrder = 1,
		onChanged = function(index)
			show(index == 2)
		end,
	})
	switch.instance.Parent = root

	show(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			selected = nil
			switch:select(1)
			show(false)
		end,
		destroy = function()
			stopAnimation()
			root:Destroy()
		end,
	}
end

return UnrollTheLoop
