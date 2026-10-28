--!strict
-- A row of mutually exclusive options. The selected one is filled with the accent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Button = require(script.Parent:WaitForChild("Button"))

export type Options = {
	options: { string },
	selected: number,
	onChanged: (index: number) -> (),
	layoutOrder: number?,
	fill: boolean?, -- stretch to the parent's width (default true)
}

export type SegmentedControl = {
	instance: Frame,
	select: (self: SegmentedControl, index: number) -> (),
}

local SegmentedControl = {}

function SegmentedControl.new(ctx: Context.Ctx, opts: Options): SegmentedControl
	local fill = opts.fill ~= false
	local count = #opts.options
	local root = Create("Frame", {
		Name = "Segmented",
		LayoutOrder = opts.layoutOrder or 0,
		BackgroundColor3 = Theme.color.surfaceRaised,
		-- The inset belongs outside the minimum target height, not inside it.
		Size = if fill then UDim2.new(1, 0, 0, ctx.metrics.tap + 8) else UDim2.fromOffset(0, ctx.metrics.tap + 8),
		AutomaticSize = if fill then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIStroke", {
			Color = Theme.color.border,
			Thickness = Theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local selected = opts.selected
	local buttons: { TextButton } = {}

	local function render(animate: boolean)
		for i, b in buttons do
			local on = i == selected
			local goal = {
				BackgroundTransparency = if on then 0 else 1,
				TextColor3 = if on then Theme.color.bg else Theme.color.textMuted,
			}
			if animate and not ctx.reducedMotion then
				TweenService:Create(b, Theme.ease.state, goal):Play()
			else
				b.BackgroundTransparency = goal.BackgroundTransparency
				b.TextColor3 = goal.TextColor3
			end
		end
	end

	for i, text in opts.options do
		local b = Create("TextButton", {
			Name = "Option" .. i,
			LayoutOrder = i,
			AutoButtonColor = false,
			BackgroundColor3 = ctx.accent,
			BackgroundTransparency = 1,
			Size = if fill then UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0) else UDim2.fromScale(0, 1),
			AutomaticSize = if fill then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Text = text,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Selectable = true,
			SelectionImageObject = Button.focusRing(UDim.new(0, 8)),
			Parent = root,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, Theme.space.lg), PaddingRight = UDim.new(0, Theme.space.lg) }),
		})
		buttons[i] = b
		b.Activated:Connect(function()
			if selected ~= i then
				selected = i
				render(true)
				opts.onChanged(i)
			end
		end)
	end
	render(false)

	local self = { instance = root }
	function self.select(_self: any, index: number)
		selected = index
		render(true)
	end
	return (self :: any) :: SegmentedControl
end

return SegmentedControl
