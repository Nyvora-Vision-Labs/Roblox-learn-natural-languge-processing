--!strict
-- Square, glyph-only button (⚙ ✕). Same states as Button; size is the tap target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Button = require(script.Parent:WaitForChild("Button"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))

export type Options = {
	glyph: string,
	name: string,
	onActivated: () -> (),
	layoutOrder: number?,
}

local IconButton = {}

function IconButton.new(ctx: Context.Ctx, opts: Options): TextButton
	local size = ctx.metrics.tap
	local button = Create("TextButton", {
		Name = opts.name,
		LayoutOrder = opts.layoutOrder or 0,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.color.surfaceRaised,
		BackgroundTransparency = 1,
		Text = opts.glyph,
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.bold,
		TextSize = math.floor(ctx.metrics.text.h2 * 0.9 + 0.5),
		Selectable = true,
		SelectionImageObject = Button.focusRing(Theme.radius.button),
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
	})
	if opts.glyph == "✕" then
		button.Text = ""
		local icon = Glyph.text(ctx.metrics.text.h2, opts.glyph, Theme.color.textMuted, Theme.font.bold)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = button
	end

	local info = if ctx.reducedMotion then TweenInfo.new(0) else Theme.ease.hover
	button.MouseEnter:Connect(function()
		TweenService:Create(button, info, { BackgroundTransparency = 0, TextColor3 = Theme.color.text }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, info, { BackgroundTransparency = 1, TextColor3 = Theme.color.textMuted }):Play()
	end)
	button.Activated:Connect(opts.onActivated)
	return button
end

return IconButton
