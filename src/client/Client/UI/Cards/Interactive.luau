--!strict
-- interactive: text column + a widget with a one-line instruction above it and a Reset button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Callout = require(Components:WaitForChild("Callout"))
local Widgets = require(UI:WaitForChild("Widgets"):WaitForChild("Index"))
local Common = require(script.Parent:WaitForChild("Common"))

local Interactive = {}

function Interactive.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	local root, textParent, visualParent = Common.twoColumn(ctx)
	Common.textColumn(ctx, card, textParent)

	local scroller, content = Common.scroller("VisualScroll")
	scroller.Parent = visualParent

	if card.instruction then
		Text.new(ctx, "label", card.instruction, { LayoutOrder = 1, TextColor3 = Theme.color.textMuted, Parent = content })
	end

	local panel = Common.panel("WidgetPanel", 2)
	panel.Parent = content

	local widget: Widgets.Widget? = nil
	local factory = if card.widget then Widgets.get(card.widget) else nil
	if factory then
		widget = factory.new(ctx, card.widgetProps or {})
	end

	local inner = Common.list("Inner", Theme.space.lg, { Parent = panel })
	if widget then
		if widget.illustrative then
			local badgeRow = Create("Frame", {
				Name = "BadgeRow",
				LayoutOrder = 0,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = inner,
			}, {
				Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
			})
			Callout.badge(ctx).Parent = badgeRow
		end
		widget.root.LayoutOrder = 1
		widget.root.Parent = inner
	else
		Text.new(ctx, "body", `Widget "{card.widget or "?"}" isn't built yet.`, {
			LayoutOrder = 1,
			TextColor3 = Theme.color.textMuted,
			Parent = inner,
		})
	end

	local footer = Create("Frame", {
		Name = "Footer",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	local reset = Button.new(ctx, {
		text = "Reset",
		variant = "secondary",
		onActivated = function()
			if widget then
				widget.reset()
			end
		end,
	})
	reset.instance.Parent = footer

	return {
		root = root,
		primary = reset.instance,
		destroy = function()
			if widget then
				widget.destroy()
			end
			root:Destroy()
		end,
	}
end

return Interactive
