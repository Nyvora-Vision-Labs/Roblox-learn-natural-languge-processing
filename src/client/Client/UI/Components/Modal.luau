--!strict
-- Centered panel over a dimmed scrim. The scrim swallows clicks; the ✕ button or the caller closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local IconButton = require(script.Parent:WaitForChild("IconButton"))

export type Options = {
	title: string,
	parent: GuiObject,
	width: number?,
	onClose: () -> (),
}

export type Modal = {
	content: Frame, -- add rows here; vertical list layout
	closeButton: TextButton,
	destroy: (self: Modal) -> (),
}

local Modal = {}

function Modal.new(ctx: Context.Ctx, opts: Options): Modal
	local scrim = Create("TextButton", {
		Name = "Modal",
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
	})
	local panel = Create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(opts.width or 560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.color.surface,
		ZIndex = 51,
		Parent = scrim,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.card }),
		Create("UIStroke", {
			Color = Theme.color.border,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.cardPadding),
			PaddingRight = UDim.new(0, Theme.cardPadding),
			PaddingTop = UDim.new(0, Theme.space.xl),
			PaddingBottom = UDim.new(0, Theme.cardPadding),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.lg),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local header = Create("Frame", {
		Name = "Header",
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.tap),
		Parent = panel,
	})
	Text.new(ctx, "h2", opts.title, {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -ctx.metrics.tap, 1, 0),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = header,
	})
	local close = IconButton.new(ctx, { glyph = "✕", name = "Close", onActivated = opts.onClose })
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Parent = header

	local content = Create("Frame", {
		Name = "Content",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.lg),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	scrim.Parent = opts.parent
	if ctx.reducedMotion then
		scrim.BackgroundTransparency = 0.45
	else
		TweenService:Create(scrim, Theme.ease.state, { BackgroundTransparency = 0.45 }):Play()
	end

	local self = { content = content, closeButton = close }
	function self.destroy(_self: any)
		scrim:Destroy()
	end
	return (self :: any) :: Modal
end

return Modal
