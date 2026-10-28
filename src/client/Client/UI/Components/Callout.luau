--!strict
-- Callout: a tinted note with an icon and a word, so meaning never depends on color alone.
-- Kinds: info, success, danger, warning, illustrative (marks hand-authored numbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))

export type Kind = "info" | "success" | "danger" | "warning" | "illustrative"

export type Options = {
	kind: Kind,
	text: string,
	heading: string?, -- defaults per kind
	layoutOrder: number?,
}

local STYLE: { [string]: { glyph: string, heading: string } } = {
	info = { glyph = "i", heading = "" },
	success = { glyph = "✓", heading = "Correct" },
	danger = { glyph = "✕", heading = "Not quite" },
	warning = { glyph = "!", heading = "Note" },
	illustrative = { glyph = "~", heading = "Illustrative" },
}

local Callout = {}

function Callout.color(ctx: Context.Ctx, kind: Kind): Color3
	if kind == "success" then
		return Theme.color.success
	elseif kind == "danger" then
		return Theme.color.danger
	elseif kind == "warning" or kind == "illustrative" then
		return Theme.color.warning
	end
	return ctx.accent
end

function Callout.new(ctx: Context.Ctx, opts: Options): Frame
	local style = STYLE[opts.kind]
	local tint = Callout.color(ctx, opts.kind)
	local root = Create("Frame", {
		Name = "Callout",
		LayoutOrder = opts.layoutOrder or 0,
		BackgroundColor3 = Theme.color.surfaceRaised,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIStroke", { Color = tint, Thickness = Theme.strokeThickness, Transparency = 0.4 }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.lg),
			PaddingRight = UDim.new(0, Theme.space.lg),
			PaddingTop = UDim.new(0, Theme.space.md),
			PaddingBottom = UDim.new(0, Theme.space.md),
		}),
	})
	local iconSize = ctx.metrics.text.label + 8
	local icon = Create("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundColor3 = tint,
		Text = style.glyph,
		TextColor3 = Theme.color.bg,
		FontFace = Theme.font.extraBold,
		TextSize = ctx.metrics.text.label,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	if style.glyph == "✓" or style.glyph == "✕" then
		icon.Text = ""
		local mark = Glyph.text(ctx.metrics.text.label, style.glyph, Theme.color.bg, Theme.font.extraBold)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.Parent = icon
	end
	local column = Create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(iconSize + Theme.space.md, 0),
		Size = UDim2.new(1, -(iconSize + Theme.space.md), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.xs), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local heading = opts.heading or style.heading
	if heading ~= "" then
		Text.new(ctx, "label", heading, { LayoutOrder = 1, TextColor3 = tint, Parent = column })
	end
	Text.new(ctx, "body", opts.text, { LayoutOrder = 2, Parent = column })
	return root
end

-- A compact "Illustrative" badge for widget panels.
function Callout.badge(ctx: Context.Ctx): Frame
	local tint = Theme.color.warning
	return Create("Frame", {
		Name = "IllustrativeBadge",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.color.surfaceRaised,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.chip }),
		Create("UIStroke", { Color = tint, Thickness = Theme.strokeThickness }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.sm),
			PaddingRight = UDim.new(0, Theme.space.sm),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Create("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = "Illustrative",
			TextColor3 = tint,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.caption,
		}),
	})
end

return Callout
