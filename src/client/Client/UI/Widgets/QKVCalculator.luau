--!strict
-- QKVCalculator: scaled dot-product attention for three tokens with 2-number vectors, one stage at
-- a time: Q, K, V → QKᵀ → ÷ √dₖ → softmax of each row → × V. Sliders edit the first token's
-- query; every number is recomputed with Math/Linear.attention.
-- props: tokens, Q, K, V

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Linear = require(Shared:WaitForChild("Math"):WaitForChild("Linear"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Slider = require(Components:WaitForChild("Slider"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local CELL_W, CELL_H = 78, 36
local ROW_LABEL = 84

local STAGES = {
	{ title = "1 · Inputs", note = "Each token has a query, a key and a value (dₖ = 2)." },
	{ title = "2 · Scores QKᵀ", note = "Row i, column j: how well token i's query matches token j's key." },
	{ title = "3 · Scale ÷ √dₖ", note = "Divide every score by √2 ≈ 1.41 so softmax doesn't saturate." },
	{ title = "4 · Softmax each row", note = "Each row becomes weights: non-negative, summing to 1." },
	{ title = "5 · Weights × V", note = "Each token's output is its weighted blend of the values." },
}

local QKVCalculator = {}

function QKVCalculator.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local tokens: { string } = props.tokens
	local K: { { number } } = props.K
	local V: { { number } } = props.V
	local startQ: { { number } } = props.Q
	local Q = { table.clone(startQ[1]), table.clone(startQ[2]), table.clone(startQ[3]) }
	local stage = 1

	local root = Create("Frame", {
		Name = "QKVCalculator",
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

	local title = Text.new(ctx, "label", "", {
		LayoutOrder = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = ctx.accent,
		Parent = root,
	})
	local note = Text.new(ctx, "caption", "", {
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})
	local matrices = Create("Frame", {
		Name = "Matrices",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.space.lg),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- One labeled matrix: rows are tokens, `headers` label the columns.
	local function matrix(order: number, name: string, color: Color3, data: { { number } }, headers: { string }, rowLabels: boolean, highlightMax: boolean?)
		local cols = #data[1]
		local w = (if rowLabels then ROW_LABEL else 0) + cols * CELL_W
		local frame = Create("Frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(w, CELL_H * (#data + 2)),
			Parent = matrices,
		})
		Create("TextLabel", {
			Position = UDim2.fromOffset(if rowLabels then ROW_LABEL else 0, 0),
			Size = UDim2.fromOffset(cols * CELL_W, CELL_H),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = color,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Parent = frame,
		})
		for j, h in headers do
			Create("TextLabel", {
				Position = UDim2.fromOffset((if rowLabels then ROW_LABEL else 0) + (j - 1) * CELL_W, CELL_H),
				Size = UDim2.fromOffset(CELL_W, CELL_H),
				BackgroundTransparency = 1,
				Text = h,
				TextColor3 = Theme.color.textMuted,
				FontFace = Theme.font.regular,
				TextSize = ctx.metrics.text.caption,
				Parent = frame,
			})
		end
		for i, rowValues in data do
			local y = CELL_H * (i + 1)
			if rowLabels then
				Create("TextLabel", {
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.fromOffset(ROW_LABEL - 8, CELL_H),
					BackgroundTransparency = 1,
					Text = tokens[i],
					TextColor3 = Theme.role.input,
					FontFace = Theme.font.bold,
					TextSize = ctx.metrics.text.caption,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = frame,
				})
			end
			local rowMax = -math.huge
			for _, x in rowValues do
				rowMax = math.max(rowMax, x)
			end
			for j, x in rowValues do
				local isMax = highlightMax and x == rowMax
				Create("TextLabel", {
					Position = UDim2.fromOffset((if rowLabels then ROW_LABEL else 0) + (j - 1) * CELL_W + 2, y + 2),
					Size = UDim2.fromOffset(CELL_W - 4, CELL_H - 4),
					BackgroundColor3 = if isMax then color:Lerp(Theme.color.surfaceRaised, 0.55) else Theme.color.surfaceRaised,
					Text = Plot.num(x, 2),
					TextColor3 = Theme.color.text,
					FontFace = Theme.font.mono,
					TextSize = ctx.metrics.text.caption,
					Parent = frame,
				}, {
					Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			end
		end
	end

	local backButton, nextButton

	local function render()
		for _, child in matrices:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local result = Linear.attention(Q, K, V)
		title.Text = STAGES[stage].title
		note.Text = STAGES[stage].note
		local dims = { "1", "2" }
		if stage == 1 then
			matrix(1, "Q", Theme.role.query, Q, dims, true)
			matrix(2, "K", Theme.role.query, K, dims, false)
			matrix(3, "V", Theme.role.output, V, dims, false)
		elseif stage == 2 then
			matrix(1, "QKᵀ", Theme.role.query, result.scores, tokens, true, true)
		elseif stage == 3 then
			matrix(1, "QKᵀ / √2", Theme.role.query, result.scaled, tokens, true, true)
		elseif stage == 4 then
			matrix(1, "weights", Theme.role.query, result.weights, tokens, true, true)
		else
			matrix(1, "weights", Theme.role.query, result.weights, tokens, true, true)
			matrix(2, "output", Theme.role.output, result.output, dims, false)
		end
		backButton:setEnabled(stage > 1)
		nextButton:setEnabled(stage < #STAGES)
	end

	local controls = Create("Frame", {
		Name = "Controls",
		LayoutOrder = 4,
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
	backButton = Button.new(ctx, {
		text = "Previous stage",
		name = "PrevStage",
		variant = "secondary",
		layoutOrder = 1,
		onActivated = function()
			stage = math.max(1, stage - 1)
			render()
		end,
	})
	backButton.instance.Parent = controls
	nextButton = Button.new(ctx, {
		text = "Next stage",
		name = "NextStage",
		layoutOrder = 2,
		onActivated = function()
			stage = math.min(#STAGES, stage + 1)
			render()
		end,
	})
	nextButton.instance.Parent = controls

	local sliders = {}
	for d = 1, 2 do
		local s = Slider.new(ctx, {
			label = `query of “{tokens[1]}”, entry {d}`,
			min = -2,
			max = 2,
			step = 0.1,
			value = Q[1][d],
			color = Theme.role.query,
			format = function(v)
				return Plot.num(v, 1)
			end,
			layoutOrder = 4 + d,
			onChanged = function(v)
				Q[1][d] = v
				render()
			end,
		})
		s.instance.Parent = root
		sliders[d] = s
	end

	render()

	return {
		root = root,
		illustrative = false,
		reset = function()
			Q = { table.clone(startQ[1]), table.clone(startQ[2]), table.clone(startQ[3]) }
			stage = 1
			for d, s in sliders do
				s:set(Q[1][d], true)
			end
			render()
		end,
		destroy = function()
			for _, s in sliders do
				s:destroy()
			end
			root:Destroy()
		end,
	}
end

return QKVCalculator
