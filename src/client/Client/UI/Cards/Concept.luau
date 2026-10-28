--!strict
-- concept: text in one centered column. With journey = true (card 1 of every module) it also shows
-- the five-module journey with this module highlighted, and the bridge from the previous module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))
local Config = require(Shared:WaitForChild("Config"))
local Index = require(Shared:WaitForChild("Lessons"):WaitForChild("Index"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Callout = require(UI:WaitForChild("Components"):WaitForChild("Callout"))
local Common = require(script.Parent:WaitForChild("Common"))

local NODE = 28

local Concept = {}

local function journey(ctx: Common.CardCtx, order: number, parent: Instance)
	local count = #Config.MODULE_ORDER
	local strip = Create("Frame", {
		Name = "Journey",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	-- The line behind the nodes, from the first node's center to the last's
	Create("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5 / count, 0, 0, NODE / 2),
		Size = UDim2.new(1 - 1 / count, 0, 0, 2),
		BackgroundColor3 = Theme.color.border,
		BorderSizePixel = 0,
		Parent = strip,
	})
	for i = 1, count do
		local meta = Index.at(i)
		local current = i == ctx.moduleOrder
		local done = i < ctx.moduleOrder
		local accent = Theme.accent[Config.MODULE_ORDER[i]]
		local column = Create("Frame", {
			Name = "Node" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale((i - 1) / count, 0),
			Size = UDim2.fromScale(1 / count, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = strip,
		}, {
			Create("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.space.sm),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		})
		Create("TextLabel", {
			Name = "Dot",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(NODE, NODE),
			BackgroundColor3 = if current then accent elseif done then Theme.color.textMuted else Theme.color.bg,
			Text = tostring(i),
			TextColor3 = if current or done then Theme.color.bg else Theme.color.textMuted,
			FontFace = Theme.font.bold,
			TextSize = math.min(ctx.metrics.text.caption, NODE - 8),
			Parent = column,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Create("UIStroke", {
				Color = if current then accent else Theme.color.border,
				Thickness = if current then 3 else 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		Text.new(ctx, "caption", if meta then meta.title else "", {
			LayoutOrder = 2,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if current then Theme.color.text else Theme.color.textMuted,
			FontFace = if current then Theme.font.bold else Theme.font.regular,
			Parent = column,
		})
	end
end

function Concept.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	local scroller, content = Common.scroller("ConceptScroll")
	local holder = Common.centered(
		scroller,
		if card.journey then 820 else Theme.textColumnMaxWidth,
		if ctx.metrics.compact then ctx.metrics.scale else nil
	)

	if card.journey then
		Text.new(ctx, "label", `Module {ctx.moduleOrder} of {#Config.MODULE_ORDER}`, {
			LayoutOrder = 0,
			TextColor3 = ctx.accent,
			Parent = content,
		})
	end
	if card.title then
		Common.title(ctx, card.title, 1, content)
	end
	if card.body then
		Common.body(ctx, card.body, 2, content)
	end
	if card.journey then
		journey(ctx, 3, content)
		if card.bridge then
			Callout.new(ctx, { kind = "info", heading = "How we got here", text = card.bridge, layoutOrder = 4 }).Parent =
				content
		end
	end
	Common.terms(ctx, card.terms, 5, content)
	local deeper = Common.deeper(ctx, card.deeper, 6, content)

	return {
		root = holder,
		primary = deeper,
		destroy = function()
			holder:Destroy()
		end,
	}
end

return Concept
