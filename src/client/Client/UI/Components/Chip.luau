--!strict
-- Small rounded label (key terms, badges). Not interactive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))

export type Options = {
	text: string,
	color: Color3?, -- text and stroke tint; default muted
	fill: Color3?,
	layoutOrder: number?,
}

local Chip = {}

function Chip.new(ctx: Context.Ctx, opts: Options): Frame
	local tint = opts.color or Theme.color.textMuted
	local chip = Create("Frame", {
		Name = "Chip",
		LayoutOrder = opts.layoutOrder or 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = opts.fill or Theme.color.surfaceRaised,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.chip }),
		Create("UIStroke", {
			Color = if opts.color then tint else Theme.color.border,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.md),
			PaddingRight = UDim.new(0, Theme.space.md),
			PaddingTop = UDim.new(0, Theme.space.xs),
			PaddingBottom = UDim.new(0, Theme.space.xs),
		}),
		Create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Text = opts.text,
			TextColor3 = if opts.color then tint else Theme.color.textMuted,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
		}),
	})
	return chip
end

return Chip
