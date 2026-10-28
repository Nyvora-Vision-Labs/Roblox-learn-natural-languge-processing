--!strict
-- compare: a short intro, then two side-by-side panels (stacked in compact mode).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Common = require(script.Parent:WaitForChild("Common"))

local Compare = {}

local function side(ctx: Common.CardCtx, data: Types.CompareSide, order: number): Frame
	local panel = Common.panel("Side" .. order, order)
	local inner = Common.list("Inner", Theme.space.md, { Parent = panel })
	Text.new(ctx, "h2", data.title, { LayoutOrder = 1, TextColor3 = ctx.accent, Parent = inner })
	Text.new(ctx, "body", data.body, { LayoutOrder = 2, Parent = inner })
	if data.points then
		for i, point in data.points do
			Text.new(ctx, "body", "•  " .. point, {
				LayoutOrder = 2 + i,
				TextColor3 = Theme.color.textMuted,
				Parent = inner,
			})
		end
	end
	return panel
end

function Compare.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	local scroller, content = Common.scroller("CompareScroll")
	local holder = Common.centered(
		scroller,
		1080,
		if ctx.metrics.compact then ctx.metrics.scale else nil
	)

	if card.title then
		Common.title(ctx, card.title, 1, content)
	end
	if card.body then
		Common.body(ctx, card.body, 2, content)
	end

	local row = Create("Frame", {
		Name = "Sides",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = if ctx.metrics.compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.space.xl),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, data in { card.left, card.right } do
		if data then
			local panel = side(ctx, data, i)
			if not ctx.metrics.compact then
				panel.Size = UDim2.new(0.5, -Theme.space.xl / 2, 0, 0)
			end
			panel.Parent = row
		end
	end

	Common.terms(ctx, card.terms, 4, content)
	local deeper = Common.deeper(ctx, card.deeper, 5, content)

	return {
		root = holder,
		primary = deeper,
		destroy = function()
			holder:Destroy()
		end,
	}
end

return Compare
