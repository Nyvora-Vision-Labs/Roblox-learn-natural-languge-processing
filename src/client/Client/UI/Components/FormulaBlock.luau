--!strict
-- A formula on a raised panel. Variables marked {role|x} take their diagram-role color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))

local FormulaBlock = {}

function FormulaBlock.new(ctx: Context.Ctx, formula: string, layoutOrder: number?): Frame
	local root = Create("Frame", {
		Name = "Formula",
		LayoutOrder = layoutOrder or 0,
		BackgroundColor3 = Theme.color.surfaceRaised,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = Theme.strokeThickness }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.xl),
			PaddingRight = UDim.new(0, Theme.space.xl),
			PaddingTop = UDim.new(0, Theme.space.lg),
			PaddingBottom = UDim.new(0, Theme.space.lg),
		}),
	})
	Text.new(ctx, "mono", Text.formula(formula), {
		TextSize = ctx.metrics.text.h2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = root,
	})
	return root
end

return FormulaBlock
