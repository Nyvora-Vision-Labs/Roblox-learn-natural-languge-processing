--!strict
-- recap: the module's key points, one per line, each with a check mark.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Glyph = require(UI:WaitForChild("Components"):WaitForChild("Glyph"))
local Common = require(script.Parent:WaitForChild("Common"))

local Recap = {}

function Recap.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	local scroller, content = Common.scroller("RecapScroll")
	local holder = Common.centered(
		scroller,
		760,
		if ctx.metrics.compact then ctx.metrics.scale else nil
	)

	Common.title(ctx, card.title or "Recap", 1, content)
	if card.body then
		Common.body(ctx, card.body, 2, content)
	end
	local glyphSize = ctx.metrics.text.body + 8
	for i, point in card.points or {} do
		local row = Create("Frame", {
			Name = "Point" .. i,
			LayoutOrder = 2 + i,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = content,
		})
		local check = Create("Frame", {
			Name = "Check",
			Size = UDim2.fromOffset(glyphSize, glyphSize),
			BackgroundColor3 = ctx.accent,
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
		local mark = Glyph.text(ctx.metrics.text.label, "✓", Theme.color.bg, Theme.font.extraBold)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.Parent = check
		Text.new(ctx, "body", point, {
			Position = UDim2.fromOffset(glyphSize + Theme.space.lg, 2),
			Size = UDim2.new(1, -(glyphSize + Theme.space.lg), 0, 0),
			Parent = row,
		})
	end

	return {
		root = holder,
		destroy = function()
			holder:Destroy()
		end,
	}
end

return Recap
