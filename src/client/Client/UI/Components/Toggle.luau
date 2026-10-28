--!strict
-- A full-width settings row: label on the left, switch on the right. The whole row is the tap target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Button = require(script.Parent:WaitForChild("Button"))

export type Options = {
	label: string,
	value: boolean,
	onChanged: (value: boolean) -> (),
	layoutOrder: number?,
}

local TRACK_W, TRACK_H = 52, 28

local Toggle = {}

function Toggle.new(ctx: Context.Ctx, opts: Options): TextButton
	local value = opts.value
	local row = Create("TextButton", {
		Name = "Toggle",
		LayoutOrder = opts.layoutOrder or 0,
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.tap),
		Selectable = true,
		SelectionImageObject = Button.focusRing(Theme.radius.button),
	})
	Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(TRACK_W + Theme.space.lg), 1, 0),
		Text = opts.label,
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.regular,
		TextSize = ctx.metrics.text.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = row,
	})
	local track = Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		BackgroundColor3 = Theme.color.border,
		Parent = row,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(TRACK_H - 6, TRACK_H - 6),
		BackgroundColor3 = Theme.color.text,
		Parent = track,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	-- State word next to the switch so on/off never relies on color alone.
	local stateLabel = Create("TextLabel", {
		Name = "State",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(TRACK_W + Theme.space.sm), 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ctx.metrics.text.label),
		BackgroundTransparency = 1,
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local function render(animate: boolean)
		local goalTrack = { BackgroundColor3 = if value then ctx.accent else Theme.color.border }
		local goalKnob = { Position = UDim2.new(0, if value then TRACK_W - TRACK_H + 3 else 3, 0.5, 0) }
		stateLabel.Text = if value then "On" else "Off"
		if animate and not ctx.reducedMotion then
			TweenService:Create(track, Theme.ease.state, goalTrack):Play()
			TweenService:Create(knob, Theme.ease.state, goalKnob):Play()
		else
			track.BackgroundColor3 = goalTrack.BackgroundColor3
			knob.Position = goalKnob.Position
		end
	end
	render(false)

	row.Activated:Connect(function()
		value = not value
		render(true)
		opts.onChanged(value)
	end)
	return row
end

return Toggle
