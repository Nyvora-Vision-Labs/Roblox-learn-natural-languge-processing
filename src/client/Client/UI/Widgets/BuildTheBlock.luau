--!strict
-- BuildTheBlock: a stepper that assembles one Transformer block from the bottom up, one piece per
-- step with one line of explanation, ending with "× N". Residual connections are drawn as side
-- arrows around the sublayer they skip.
-- props: pieces { { name, line } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Button = require(UI:WaitForChild("Components"):WaitForChild("Button"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local BOX_W, BOX_H, GAP = 300, 40, 10
local STACK_W = 440

local BuildTheBlock = {}

-- Which pieces get which color: embeddings/positions are inputs, attention is the query role,
-- feed-forward is a weight block, norms are neutral.
local function colorFor(name: string, accent: Color3): Color3
	if name:find("attention") then
		return Theme.role.query
	elseif name:find("Feed") then
		return Theme.role.weight
	elseif name:find("embed") or name:find("Positional") then
		return Theme.role.input
	elseif name:find("×") then
		return accent
	end
	return Theme.color.textMuted
end

function BuildTheBlock.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local pieces = props.pieces
	local count = #pieces
	local shown = 1

	local root = Create("Frame", {
		Name = "BuildTheBlock",
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

	local stackH = count * BOX_H + (count - 1) * GAP
	-- Vertical center of piece k; pieces stack bottom-up.
	local function cy(k: number): number
		return stackH - (k - 1) * (BOX_H + GAP) - BOX_H / 2
	end
	local stack = Create("Frame", {
		Name = "Stack",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(STACK_W, stackH),
		Parent = root,
	})
	-- The block outline wraps pieces 3–6 (the repeated layer).
	local blockFrame = Create("Frame", {
		Name = "Block",
		BackgroundTransparency = 1,
		Visible = false,
		Parent = stack,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.card }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = 2 }),
	})

	local boxes: { Frame } = {}
	for k, piece in pieces do
		local y = stackH - k * BOX_H - (k - 1) * GAP -- bottom-up
		local color = colorFor(piece.name, ctx.accent)
		local isRepeat = piece.name:find("×") ~= nil
		local box = Create("TextLabel", {
			Name = "Piece" .. k,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(STACK_W / 2, y),
			Size = UDim2.fromOffset(if isRepeat then 90 else BOX_W, BOX_H),
			BackgroundColor3 = color:Lerp(Theme.color.surfaceRaised, 0.78),
			Text = piece.name,
			TextColor3 = Theme.color.text,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.caption + 2,
			Visible = false,
			ZIndex = 2,
			Parent = stack,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UIStroke", { Name = "Edge", Color = color, Thickness = 2 }),
		})
		if isRepeat then
			-- "× N" sits beside the repeated layer rather than on top of it.
			box.AnchorPoint = Vector2.new(0, 0.5)
			box.Position = UDim2.fromOffset(STACK_W / 2 + BOX_W / 2 + 20, (cy(3) + cy(6)) / 2)
		end
		boxes[k] = box :: any
	end

	-- Residual arrows: from below each sublayer to its Add & norm, drawn on the right side.
	local residuals: { Frame } = {}
	-- Each skips one sublayer: from the sublayer's input (the piece below it) to its Add & norm.
	for r, pair in { { 2, 4 }, { 4, 6 } } do
		local x = STACK_W / 2 - BOX_W / 2 - 8 - (r - 1) * 4
		local arrow = Create("Frame", {
			Name = "Residual",
			Position = UDim2.fromOffset(x, cy(pair[2])),
			Size = UDim2.fromOffset(3, cy(pair[1]) - cy(pair[2])),
			BackgroundColor3 = ctx.accent,
			BorderSizePixel = 0,
			Visible = false,
			Parent = stack,
		})
		residuals[#residuals + 1] = arrow
	end

	local explain = Text.new(ctx, "body", "", {
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

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

	local backButton, nextButton
	local function render(animate: boolean)
		for k, box in boxes do
			local visible = k <= shown
			local wasVisible = box.Visible
			box.Visible = visible
			local edge = box:FindFirstChild("Edge") :: UIStroke
			edge.Thickness = if k == shown then 3 else 2
			if visible and not wasVisible and animate and not ctx.reducedMotion then
				local target = box.Position
				box.Position = target + UDim2.fromOffset(0, 12)
				TweenService:Create(box, Theme.ease.enter, { Position = target }):Play()
			end
		end
		residuals[1].Visible = shown >= 4
		residuals[2].Visible = shown >= 6
		local top, bottom = cy(6) - BOX_H / 2 - 8, cy(3) + BOX_H / 2 + 8
		blockFrame.Visible = shown >= count
		blockFrame.Position = UDim2.fromOffset(STACK_W / 2 - BOX_W / 2 - 18, top)
		blockFrame.Size = UDim2.fromOffset(BOX_W + 36, bottom - top)
		explain.Text = string.format("<b>%s</b>: %s", pieces[shown].name, pieces[shown].line)
		backButton:setEnabled(shown > 1)
		nextButton:setEnabled(shown < count)
	end

	backButton = Button.new(ctx, {
		text = "Back",
		name = "PieceBack",
		variant = "secondary",
		layoutOrder = 1,
		onActivated = function()
			shown = math.max(1, shown - 1)
			render(false)
		end,
	})
	backButton.instance.Parent = controls
	nextButton = Button.new(ctx, {
		text = "Add the next piece",
		name = "PieceNext",
		layoutOrder = 2,
		onActivated = function()
			shown = math.min(count, shown + 1)
			render(true)
		end,
	})
	nextButton.instance.Parent = controls

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			shown = 1
			render(false)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return BuildTheBlock
