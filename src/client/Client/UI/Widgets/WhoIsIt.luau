--!strict
-- WhoIsIt (illustrative): tap any token to see where it attends; switch the last word between
-- "tired" and "wide" and watch "it" move between "animal" and "street". The weights are
-- hand-authored, so the widget carries the "Illustrative" badge.
-- props: tokens, endings { a, b }, focus (index of "it"), weights { [ending] = { per token } },
--        neighborWeight (share a non-focus token keeps on itself; the rest goes to neighbors)

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
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local WhoIsIt = {}

function WhoIsIt.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local base: { string } = props.tokens
	local endings: { string } = props.endings
	local focus: number = props.focus
	local ending = endings[1]
	local selected = focus
	local heat = Theme.role.query

	local root = Create("Frame", {
		Name = "WhoIsIt",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.lg),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local row = Create("Frame", {
		Name = "Tokens",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Wraps = true,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local caption = Text.new(ctx, "body", "", {
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})

	local tokens: { string } = {}
	local buttons: { { button: TextButton, weight: TextLabel, word: TextLabel } } = {}

	-- Weights for the selected token over all tokens (the ending token included).
	local function weightsFor(index: number): { number }
		local n = #tokens
		local out = table.create(n, 0)
		if index == focus then
			local authored = props.weights[ending]
			local sum = 0
			for k = 1, n do
				out[k] = authored[k] or 0
				sum += out[k]
			end
			for k = 1, n do
				out[k] /= sum
			end
			return out
		end
		-- Other tokens: mostly themselves, the rest split between neighbors (illustrative).
		local keep = props.neighborWeight or 0.5
		out[index] = keep
		local neighbors = {}
		if index > 1 then
			table.insert(neighbors, index - 1)
		end
		if index < n then
			table.insert(neighbors, index + 1)
		end
		for _, k in neighbors do
			out[k] = (1 - keep) / #neighbors
		end
		return out
	end

	local function render(animate: boolean)
		local w = weightsFor(selected)
		local best, bestK = -1, 1
		for k, value in w do
			if k ~= selected and value > best then
				best, bestK = value, k
			end
		end
		for k, b in buttons do
			local isSelected = k == selected
			local color = if isSelected then Theme.color.surfaceRaised else heat:Lerp(Theme.color.surfaceRaised, 1 - w[k])
			if animate and not ctx.reducedMotion then
				TweenService:Create(b.button, Theme.ease.state, { BackgroundColor3 = color }):Play()
			else
				b.button.BackgroundColor3 = color
			end
			local stroke = b.button:FindFirstChild("Edge") :: UIStroke
			stroke.Color = if isSelected then Theme.color.focus else Theme.color.border
			stroke.Thickness = if isSelected then 2 else 1
			b.word.TextColor3 = if w[k] > 0.45 and not isSelected then Theme.color.bg else Theme.color.text
			b.weight.Text = if isSelected then "query" else string.format("%.2f", w[k])
			b.weight.TextColor3 = if w[k] > 0.45 and not isSelected then Theme.color.bg else Theme.color.textMuted
		end
		caption.Text = string.format(
			'“<b>%s</b>” attends most to “<b>%s</b>” (%.2f).%s',
			tokens[selected],
			tokens[bestK],
			best,
			if selected == focus then "" else " Tap “it” to see the interesting one."
		)
	end

	local function build()
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(buttons)
		tokens = table.clone(base)
		table.insert(tokens, ending)
		for k, token in tokens do
			local b = Create("TextButton", {
				Name = "Token" .. k,
				LayoutOrder = k,
				AutoButtonColor = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, ctx.metrics.tap + ctx.metrics.text.caption),
				BackgroundColor3 = Theme.color.surfaceRaised,
				Text = "",
				Selectable = true,
				SelectionImageObject = Button.focusRing(Theme.radius.chip),
				Parent = row,
			}, {
				Create("UICorner", { CornerRadius = Theme.radius.chip }),
				Create("UIStroke", {
					Name = "Edge",
					Color = Theme.color.border,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Create("UIPadding", { PaddingLeft = UDim.new(0, Theme.space.md), PaddingRight = UDim.new(0, Theme.space.md) }),
				Create("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			local word = Create("TextLabel", {
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				Text = token,
				TextColor3 = Theme.color.text,
				FontFace = Theme.font.bold,
				TextSize = ctx.metrics.text.label,
				Parent = b,
			})
			local weight = Create("TextLabel", {
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				Text = "",
				TextColor3 = Theme.color.textMuted,
				FontFace = Theme.font.mono,
				TextSize = ctx.metrics.text.caption,
				Parent = b,
			})
			buttons[k] = { button = b, weight = weight, word = word }
			b.Activated:Connect(function()
				selected = k
				render(true)
			end)
		end
		render(false)
	end

	local labels = {}
	for _, e in endings do
		table.insert(labels, "…too " .. e)
	end
	local switch = SegmentedControl.new(ctx, {
		options = labels,
		selected = 1,
		layoutOrder = 1,
		onChanged = function(index)
			ending = endings[index]
			build()
		end,
	})
	switch.instance.Parent = root

	build()

	return {
		root = root,
		illustrative = true,
		reset = function()
			ending, selected = endings[1], focus
			switch:select(1)
			build()
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return WhoIsIt
