--!strict
-- math: text column + the formula with a plain-language legend for every symbol.
-- In compact mode everything stacks in one scrolling column.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Components = UI:WaitForChild("Components")
local FormulaBlock = require(Components:WaitForChild("FormulaBlock"))
local Legend = require(Components:WaitForChild("Legend"))
local Text = require(UI:WaitForChild("Text"))
local Common = require(script.Parent:WaitForChild("Common"))

local MathCard = {}

local function formulaParts(ctx: Common.CardCtx, card: Types.Card, parent: Instance, order: number)
	if card.formula then
		FormulaBlock.new(ctx, card.formula, order).Parent = parent
	end
	if card.legend and #card.legend > 0 then
		Text.new(ctx, "label", "What each symbol means", {
			LayoutOrder = order + 1,
			TextColor3 = Theme.color.textMuted,
			Parent = parent,
		})
		Legend.new(ctx, card.legend, order + 2).Parent = parent
	end
end

function MathCard.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	if ctx.metrics.compact then
		local scroller, content = Common.scroller("MathScroll")
		if card.title then
			Common.title(ctx, card.title, 1, content)
		end
		if card.body then
			Common.body(ctx, card.body, 2, content)
		end
		formulaParts(ctx, card, content, 3)
		Common.terms(ctx, card.terms, 6, content)
		local deeper = Common.deeper(ctx, card.deeper, 7, content)
		return {
			root = scroller,
			primary = deeper,
			destroy = function()
				scroller:Destroy()
			end,
		}
	end

	local root, textParent, visualParent = Common.twoColumn(ctx)
	local deeper = Common.textColumn(ctx, card, textParent)
	local scroller, content = Common.scroller("FormulaScroll")
	scroller.Parent = visualParent
	formulaParts(ctx, card, content, 1)

	return {
		root = root,
		primary = deeper,
		destroy = function()
			root:Destroy()
		end,
	}
end

return MathCard
