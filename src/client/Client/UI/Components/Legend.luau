--!strict
-- A plain-language legend: one row per symbol, symbol in its role color, meaning beside it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))

local SYMBOL_COLUMN = 0.3

local Legend = {}

function Legend.new(ctx: Context.Ctx, rows: { Types.LegendRow }, layoutOrder: number?): Frame
	local root = Create("Frame", {
		Name = "Legend",
		LayoutOrder = layoutOrder or 0,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.md), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, row in rows do
		local line = Create("Frame", {
			Name = "Row" .. i,
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = root,
		})
		Text.new(ctx, "mono", row.symbol, {
			Size = UDim2.fromScale(SYMBOL_COLUMN, 0),
			TextSize = ctx.metrics.text.body,
			TextColor3 = Text.roleColor(row.role),
			FontFace = Theme.font.monoBold,
			Parent = line,
		})
		Text.new(ctx, "body", row.meaning, {
			Position = UDim2.fromScale(SYMBOL_COLUMN, 0),
			Size = UDim2.fromScale(1 - SYMBOL_COLUMN, 0),
			TextColor3 = Theme.color.textMuted,
			Parent = line,
		})
	end
	return root
end

return Legend
