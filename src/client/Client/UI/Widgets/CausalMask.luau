--!strict
-- CausalMask: who can attend to whom. Rows are the attending token, columns the token attended to.
-- With the mask on, row i sees only columns j ≤ i. Tap a row to list what that token can see.
-- props: tokens

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Toggle = require(Components:WaitForChild("Toggle"))
local Glyph = require(Components:WaitForChild("Glyph"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local CELL, GAP = 46, 5
local LABEL_W = 70
local HEADER_H = 64

local CausalMask = {}

function CausalMask.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local tokens: { string } = props.tokens
	local n = #tokens
	local masked = true
	local selected = math.ceil(n / 2)

	local root = Create("Frame", {
		Name = "CausalMask",
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

	local gridW = LABEL_W + n * CELL + (n - 1) * GAP
	local grid = Create("Frame", {
		Name = "Grid",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, HEADER_H + n * CELL + (n - 1) * GAP),
		Parent = root,
	})
	for j, token in tokens do
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(LABEL_W + (j - 1) * (CELL + GAP) + CELL / 2 - 4, HEADER_H - 6),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = token,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			Rotation = -40,
			Parent = grid,
		})
	end

	local cells, rows = {}, {}
	for i, token in tokens do
		local y = HEADER_H + (i - 1) * (CELL + GAP)
		local rowButton = Create("TextButton", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(LABEL_W - 8, CELL),
			BackgroundColor3 = Theme.color.surfaceRaised,
			BackgroundTransparency = 1,
			Text = token,
			TextColor3 = Theme.role.query,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.caption,
			TextXAlignment = Enum.TextXAlignment.Right,
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.chip),
			Parent = grid,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
			Create("UIPadding", { PaddingRight = UDim.new(0, Theme.space.sm) }),
		})
		rows[i] = rowButton
		cells[i] = {}
		for j = 1, n do
			local cell = Create("Frame", {
				Name = `Cell{i}_{j}`,
				Position = UDim2.fromOffset(LABEL_W + (j - 1) * (CELL + GAP), y),
				Size = UDim2.fromOffset(CELL, CELL),
				BackgroundColor3 = Theme.color.surfaceRaised,
				Parent = grid,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Name = "Edge", Color = Theme.color.border, Thickness = 1 }),
			})
			-- A drawn ✕ marks blocked cells, so blocked never relies on color alone.
			local cross = Glyph.text(math.floor(CELL * 0.45), "✕", Theme.color.textFaint, Theme.font.bold)
			cross.Name = "Blocked"
			cross.AnchorPoint = Vector2.new(0.5, 0.5)
			cross.Position = UDim2.fromScale(0.5, 0.5)
			cross.Parent = cell
			cells[i][j] = cell
		end
	end

	Plot.legend(ctx, {
		{ label = "can attend", color = ctx.accent, shape = "square" },
		{ label = "blocked (future)", color = Theme.color.textFaint, shape = "ring" },
	}, 2).Parent = root

	local caption = Text.new(ctx, "body", "", {
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	local function render(animate: boolean)
		for i, row in cells do
			rows[i].BackgroundTransparency = if i == selected then 0 else 1
			for j, cell in row do
				local visible = not masked or j <= i
				local inRow = i == selected
				local color = if visible
					then (if inRow then ctx.accent else ctx.accent:Lerp(Theme.color.surfaceRaised, 0.55))
					else Theme.color.surfaceRaised
				if animate and not ctx.reducedMotion then
					TweenService:Create(cell, Theme.ease.state, { BackgroundColor3 = color }):Play()
				else
					cell.BackgroundColor3 = color
				end
				(cell:FindFirstChild("Blocked") :: Frame).Visible = not visible
				local edge = cell:FindFirstChild("Edge") :: UIStroke
				edge.Color = if inRow then Theme.color.focus else Theme.color.border
			end
		end
		local seen = {}
		for j = 1, n do
			if not masked or j <= selected then
				table.insert(seen, tokens[j])
			end
		end
		caption.Text = if masked
			then string.format('With the mask, “<b>%s</b>” can attend to: %s. Nothing after it.', tokens[selected], table.concat(seen, ", "))
			else string.format('Without the mask, “<b>%s</b>” sees every token, including ones it should be predicting.', tokens[selected])
	end

	for i, b in rows do
		b.Activated:Connect(function()
			selected = i
			render(true)
		end)
	end

	local toggle: TextButton? = nil
	local function buildToggle()
		if toggle then
			toggle:Destroy()
		end
		toggle = Toggle.new(ctx, {
			label = "Causal mask",
			value = masked,
			layoutOrder = 4,
			onChanged = function(on)
				masked = on
				render(true)
			end,
		})
		local t = toggle :: TextButton
		t.Size = UDim2.fromOffset(gridW, ctx.metrics.tap)
		t.Parent = root
	end
	buildToggle()
	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			masked, selected = true, math.ceil(n / 2)
			buildToggle()
			render(true)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return CausalMask
