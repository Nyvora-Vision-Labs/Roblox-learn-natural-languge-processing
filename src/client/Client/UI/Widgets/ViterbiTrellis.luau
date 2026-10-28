--!strict
-- ViterbiTrellis: states × days grid. Guess the hidden sequence, then Step / Back through the real
-- computation from Math/Viterbi. Each step fills one day's column and shows the arithmetic; the
-- final step traces the best path (Viterbi) or sums the last column (Forward).
-- props: model (Viterbi.HMM), obs { symbol indices }, compare (adds a Viterbi / Forward switch)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Viterbi = require(Shared:WaitForChild("Math"):WaitForChild("Viterbi"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local LABEL_W = 84
local CELL_W, CELL_H = 124, 58
local GAP_X, GAP_Y = 36, 16
local HEADER_H = 52

local ViterbiTrellis = {}

local function p4(x: number): string
	return string.format("%.4f", x)
end

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

function ViterbiTrellis.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local hmm: Viterbi.HMM = props.model
	local obs: { number } = props.obs
	local T, N = #obs, #hmm.states
	local mode: "viterbi" | "forward" = "viterbi"
	local step = 0 -- 0 = empty; 1..T = columns filled; T + 1 = finished
	local guesses: { number? } = {}
	local guessing = true
	local hiddenColor = Theme.role.hidden
	local obsColor = Theme.role.input

	local V, bp, path, best = Viterbi.decode(hmm, obs)
	local alpha, total = Viterbi.forward(hmm, obs)

	local root = Create("Frame", {
		Name = "ViterbiTrellis",
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

	-- Grid ---------------------------------------------------------------------
	local gridW = LABEL_W + T * CELL_W + (T - 1) * GAP_X
	local gridH = HEADER_H + N * CELL_H + (N - 1) * GAP_Y
	local grid = Create("Frame", {
		Name = "Grid",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, gridH),
		Parent = root,
	})
	local function cellPos(t: number, i: number): Vector2 -- top-left
		return Vector2.new(LABEL_W + (t - 1) * (CELL_W + GAP_X), HEADER_H + (i - 1) * (CELL_H + GAP_Y))
	end
	local function cellCenter(t: number, i: number): Vector2
		return cellPos(t, i) + Vector2.new(CELL_W, CELL_H) / 2
	end

	-- Column headers: day and its observation
	for t = 1, T do
		local x = cellPos(t, 1).X
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(CELL_W, HEADER_H),
			RichText = true,
			Text = string.format(
				'Day %d\n<font color="%s"><b>%s ice cream%s</b></font>',
				t,
				hex(obsColor),
				hmm.symbols[obs[t]],
				if hmm.symbols[obs[t]] == "1" then "" else "s"
			),
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			LineHeight = 1.15,
			Parent = grid,
		})
	end
	-- Row labels
	for i = 1, N do
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, cellPos(1, i).Y),
			Size = UDim2.fromOffset(LABEL_W - Theme.space.sm, CELL_H),
			Text = hmm.states[i],
			TextColor3 = hiddenColor,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = grid,
		})
	end

	-- Back-pointer lines (behind cells), one per cell from day 2 on
	local pointers: { { Frame } } = {}
	for t = 2, T do
		pointers[t] = {}
		for j = 1, N do
			pointers[t][j] = Create("Frame", {
				Name = "Pointer",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = hiddenColor,
				BorderSizePixel = 0,
				Visible = false,
				Parent = grid,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			})
		end
	end
	local function placeLine(frame: Frame, a: Vector2, b: Vector2, thickness: number)
		local mid, d = (a + b) / 2, b - a
		frame.Position = UDim2.fromOffset(mid.X, mid.Y)
		frame.Size = UDim2.fromOffset(d.Magnitude, thickness)
		frame.Rotation = math.deg(math.atan2(d.Y, d.X))
	end

	-- Cells
	local cells: { { { frame: Frame, value: TextLabel, stroke: UIStroke } } } = {}
	for t = 1, T do
		cells[t] = {}
		for i = 1, N do
			local pos = cellPos(t, i)
			local frame = Create("Frame", {
				Name = `Cell{t}_{i}`,
				Position = UDim2.fromOffset(pos.X, pos.Y),
				Size = UDim2.fromOffset(CELL_W, CELL_H),
				BackgroundColor3 = Theme.color.surfaceRaised,
				ZIndex = 2,
				Parent = grid,
			}, {
				Create("UICorner", { CornerRadius = Theme.radius.button }),
			})
			local stroke = Create("UIStroke", {
				Color = Theme.color.border,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = frame,
			})
			local value = Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = Theme.color.text,
				FontFace = Theme.font.mono,
				TextSize = ctx.metrics.text.body,
				ZIndex = 2,
				Parent = frame,
			})
			cells[t][i] = { frame = frame, value = value, stroke = stroke }
		end
	end

	-- Guess row (one button per day, cycles through the states)
	local guessRow = Create("Frame", {
		Name = "Guesses",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, ctx.metrics.tap),
		Parent = root,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(LABEL_W - Theme.space.sm, ctx.metrics.tap),
		Text = "Guess",
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = guessRow,
	})
	local guessButtons: { TextButton } = {}

	local explain = Text.new(ctx, "body", "", {
		LayoutOrder = 4,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.caption + 2,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})

	local controls = Create("Frame", {
		Name = "Controls",
		LayoutOrder = 5,
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

	-- Rendering --------------------------------------------------------------
	local backButton, stepButton

	local function valueAt(t: number, i: number): number
		return if mode == "viterbi" then V[t][i] else alpha[t][i]
	end

	local function arithmetic(t: number): string
		local lines = {}
		local o = obs[t]
		for j = 1, N do
			local name = hmm.states[j]
			local emit = hmm.B[j][o]
			local line
			if t == 1 then
				line = string.format("%s: π %.1f × B %.1f = %s", name, hmm.pi[j], emit, p4(valueAt(1, j)))
			else
				local terms = {}
				for i = 1, N do
					table.insert(terms, string.format("%s×%.1f", p4(valueAt(t - 1, i)), hmm.A[i][j]))
				end
				if mode == "viterbi" then
					line = string.format("%s: max(%s) × B %.1f = %s", name, table.concat(terms, ", "), emit, p4(V[t][j]))
				else
					line = string.format("%s: (%s) × B %.1f = %s", name, table.concat(terms, " + "), emit, p4(alpha[t][j]))
				end
			end
			table.insert(lines, line)
		end
		return table.concat(lines, "\n")
	end

	local function render(animate: boolean)
		local finished = step > T
		local onPath: { [string]: boolean } = {}
		if finished and mode == "viterbi" then
			for t, i in path do
				onPath[t .. "_" .. i] = true
			end
		end
		for t = 1, T do
			-- best cell in the column, for a subtle highlight
			local bestI = 1
			for i = 2, N do
				if valueAt(t, i) > valueAt(t, bestI) then
					bestI = i
				end
			end
			for i = 1, N do
				local c = cells[t][i]
				local filled = t <= step
				c.value.Text = if filled then p4(valueAt(t, i)) else "–"
				c.value.TextColor3 = if filled then Theme.color.text else Theme.color.textFaint
				local highlighted = onPath[t .. "_" .. i] == true
				c.stroke.Color = if highlighted then ctx.accent elseif filled and i == bestI then hiddenColor else Theme.color.border
				c.stroke.Thickness = if highlighted then 3 else 1
				local fill = if highlighted then ctx.accent:Lerp(Theme.color.surfaceRaised, 0.75) else Theme.color.surfaceRaised
				if animate and not ctx.reducedMotion and filled and t == step then
					c.frame.BackgroundColor3 = hiddenColor:Lerp(Theme.color.surfaceRaised, 0.4)
					TweenService:Create(c.frame, Theme.ease.state, { BackgroundColor3 = fill }):Play()
				else
					c.frame.BackgroundColor3 = fill
				end
			end
		end
		-- Back-pointers: Viterbi only
		for t = 2, T do
			for j = 1, N do
				local line = pointers[t][j]
				local visible = mode == "viterbi" and t <= step
				line.Visible = visible
				if visible then
					local from = cellCenter(t - 1, bp[t][j]) + Vector2.new(CELL_W / 2, 0)
					local to = cellCenter(t, j) - Vector2.new(CELL_W / 2, 0)
					local onBest = finished and path[t] == j and path[t - 1] == bp[t][j]
					placeLine(line, from, to, if onBest then 4 else 2)
					line.BackgroundColor3 = if onBest then ctx.accent else hiddenColor
					line.BackgroundTransparency = if onBest then 0 else 0.45
				end
			end
		end

		-- Explanation
		if guessing then
			explain.Text = "Make a guess for every day first. Then step through the algorithm."
		elseif step == 0 then
			explain.Text = if mode == "viterbi"
				then "Each cell will hold the probability of the best path ending there."
				else "Each cell will hold the total probability of all paths ending there."
		elseif not finished then
			explain.Text = `Day {step}:\n` .. arithmetic(step)
		elseif mode == "viterbi" then
			local names, matched = {}, 0
			for t, i in path do
				table.insert(names, hmm.states[i])
				if guesses[t] == i then
					matched += 1
				end
			end
			explain.Text = string.format(
				"Best path: %s, probability %s.\nFollow the highlighted arrows back from the best last cell. Your guess matched %d of %d days.",
				table.concat(names, ", "),
				p4(best),
				matched,
				T
			)
		else
			local terms = {}
			for i = 1, N do
				table.insert(terms, p4(alpha[T][i]))
			end
			explain.Text = string.format(
				"P(diary) = %s = %s.\nThat's the probability of these observations, summed over every weather sequence.",
				table.concat(terms, " + "),
				p4(total)
			)
		end

		-- Guess buttons
		for t, b in guessButtons do
			local g = guesses[t]
			b.Text = if g then hmm.states[g] else "?"
			b.BackgroundColor3 = if g then hiddenColor else Theme.color.surfaceRaised
			b.TextColor3 = if g then Theme.color.bg else Theme.color.textMuted
			b.Active = guessing
			b.AutoButtonColor = guessing
		end

		backButton:setEnabled(not guessing and step > 0)
		stepButton:setEnabled(not guessing and not finished)
	end

	for t = 1, T do
		local b = Create("TextButton", {
			Name = "Guess" .. t,
			Position = UDim2.fromOffset(cellPos(t, 1).X, 0),
			Size = UDim2.fromOffset(CELL_W, ctx.metrics.tap),
			BackgroundColor3 = Theme.color.surfaceRaised,
			Text = "?",
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.button),
			Parent = guessRow,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UIStroke", { Color = Theme.color.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		b.Activated:Connect(function()
			if not guessing then
				return
			end
			local g = guesses[t]
			guesses[t] = if g == nil then 1 else (g % N) + 1
			render(false)
		end)
		guessButtons[t] = b
	end

	local lockIn
	lockIn = Button.new(ctx, {
		text = "Lock in my guess",
		name = "LockIn",
		layoutOrder = 0,
		onActivated = function()
			for t = 1, T do
				if guesses[t] == nil then
					explain.Text = "Make a guess for every day first. Tap a day to choose Hot or Cold."
					return
				end
			end
			guessing = false
			lockIn.instance.Visible = false
			render(false)
		end,
	})
	lockIn.instance.Parent = controls

	backButton = Button.new(ctx, {
		text = "Back",
		name = "StepBack",
		variant = "secondary",
		layoutOrder = 1,
		onActivated = function()
			step = math.max(0, step - 1)
			render(false)
		end,
	})
	backButton.instance.Parent = controls
	stepButton = Button.new(ctx, {
		text = "Step",
		name = "Step",
		layoutOrder = 2,
		onActivated = function()
			step = math.min(T + 1, step + 1)
			render(true)
		end,
	})
	stepButton.instance.Parent = controls

	if props.compare then
		local switch = SegmentedControl.new(ctx, {
			options = { "Viterbi: best path", "Forward: all paths" },
			selected = 1,
			layoutOrder = 1,
			onChanged = function(index)
				mode = if index == 1 then "viterbi" else "forward"
				render(false)
			end,
		})
		switch.instance.Parent = root
		-- Comparing needs no guess; start with every column filled.
		guessing = false
		lockIn.instance.Visible = false
		guessRow.Visible = false
		step = T
	end

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			table.clear(guesses)
			if props.compare then
				step = T
			else
				guessing = true
				lockIn.instance.Visible = true
				step = 0
			end
			render(false)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return ViterbiTrellis
