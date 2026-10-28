--!strict
-- AlignmentHeatmap (illustrative): rows are target (French) words, columns source (English) words;
-- cell brightness is a hand-authored attention weight. Tap a French word to highlight its row.
-- props: source, target, weights (rows sum to 1)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Button = require(UI:WaitForChild("Components"):WaitForChild("Button"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local CELL = 74
local GAP = 6
local LABEL_W = 150
local HEADER_H = 76

local AlignmentHeatmap = {}

function AlignmentHeatmap.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local source: { string } = props.source
	local target: { string } = props.target
	local weights: { { number } } = props.weights
	local selected: number? = nil
	local heat = Theme.role.query

	local root = Create("Frame", {
		Name = "AlignmentHeatmap",
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

	local gridW = LABEL_W + #source * CELL + (#source - 1) * GAP
	local gridH = HEADER_H + #target * CELL + (#target - 1) * GAP
	local grid = Create("Frame", {
		Name = "Grid",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, gridH),
		Parent = root,
	})
	-- English column headers (tilted so long words fit)
	for j, word in source do
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(LABEL_W + (j - 1) * (CELL + GAP) + CELL / 2 - 6, HEADER_H - 6),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = word,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			Rotation = -35,
			Parent = grid,
		})
	end

	local cells, rowButtons = {}, {}
	for i, word in target do
		local y = HEADER_H + (i - 1) * (CELL + GAP)
		local rowButton = Create("TextButton", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(LABEL_W - Theme.space.md, CELL),
			BackgroundColor3 = Theme.color.surfaceRaised,
			BackgroundTransparency = 1,
			Text = word,
			TextColor3 = Theme.role.output,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			TextXAlignment = Enum.TextXAlignment.Right,
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.chip),
			Parent = grid,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
			Create("UIPadding", { PaddingRight = UDim.new(0, Theme.space.md) }),
		})
		rowButtons[i] = rowButton
		cells[i] = {}
		for j = 1, #source do
			local w = weights[i][j]
			local cell = Create("Frame", {
				Name = `Cell{i}_{j}`,
				Position = UDim2.fromOffset(LABEL_W + (j - 1) * (CELL + GAP), y),
				Size = UDim2.fromOffset(CELL, CELL),
				BackgroundColor3 = heat:Lerp(Theme.color.surfaceRaised, 1 - w),
				Parent = grid,
			}, {
				Create("UICorner", { CornerRadius = Theme.radius.chip }),
				Create("UIStroke", { Name = "Edge", Color = Theme.color.border, Thickness = 1 }),
				Create("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = string.format("%.2f", w),
					TextColor3 = if w > 0.5 then Theme.color.bg else Theme.color.textMuted,
					FontFace = Theme.font.mono,
					TextSize = ctx.metrics.text.caption,
				}),
			})
			cells[i][j] = cell
		end
	end

	local caption = Text.new(ctx, "body", "", {
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	local function render()
		for i, row in cells do
			local on = selected == i
			rowButtons[i].BackgroundTransparency = if on then 0 else 1
			for _, cell in row do
				local edge = cell:FindFirstChild("Edge") :: UIStroke
				edge.Color = if on then Theme.color.focus else Theme.color.border
				edge.Thickness = if on then 2 else 1
			end
		end
		if not selected then
			caption.Text = "Bright cells off the diagonal show the reordering: adjectives come after the noun in French."
			return
		end
		local i = selected :: number
		local best = 1
		for j, w in weights[i] do
			if w > weights[i][best] then
				best = j
			end
		end
		caption.Text = string.format(
			'“<b>%s</b>” attends mostly to “<b>%s</b>” (%.2f).',
			target[i],
			source[best],
			weights[i][best]
		)
	end

	for i, b in rowButtons do
		b.Activated:Connect(function()
			selected = if selected == i then nil else i
			render()
		end)
	end
	render()

	return {
		root = root,
		illustrative = true,
		reset = function()
			selected = nil
			render()
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return AlignmentHeatmap
