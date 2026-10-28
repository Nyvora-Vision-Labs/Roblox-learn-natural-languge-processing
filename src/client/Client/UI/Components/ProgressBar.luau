--!strict
-- Segmented progress bar: one segment per card; segments up to `current` fill with the accent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))

export type ProgressBar = {
	instance: Frame,
	set: (self: ProgressBar, current: number) -> (),
}

local GAP = 4
local HEIGHT = 6

local ProgressBar = {}

function ProgressBar.new(ctx: Context.Ctx, count: number): ProgressBar
	local root = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEIGHT),
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local segments = {}
	for i = 1, count do
		segments[i] = Create("Frame", {
			Name = "Seg" .. i,
			LayoutOrder = i,
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.color.border,
			Size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
			Parent = root,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
	end

	local self = { instance = root }
	function self.set(_self: any, current: number)
		for i, seg in segments do
			local color = if i <= current then ctx.accent else Theme.color.border
			if ctx.reducedMotion then
				seg.BackgroundColor3 = color
			else
				TweenService:Create(seg, Theme.ease.state, { BackgroundColor3 = color }):Play()
			end
		end
	end
	return (self :: any) :: ProgressBar
end

return ProgressBar
