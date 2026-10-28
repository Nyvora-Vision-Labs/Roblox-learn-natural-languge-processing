--!strict
-- The render context every component and card receives. Sizes are in reference px (the stage's
-- UIScale converts them to screen px), already multiplied for compact mode and the text-size setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Scale = require(script.Parent:WaitForChild("Scale"))

export type Metrics = {
	scale: number,
	compact: boolean,
	tap: number, -- minimum height of anything tappable
	bar: number, -- height of the lesson top and bottom bars
	text: { [string]: number }, -- display, h1, h2, body, label, caption, mono
}

export type Ctx = {
	metrics: Metrics,
	accent: Color3,
	reducedMotion: boolean,
}

local Context = {}

function Context.metrics(state: Scale.ScaleState, textScale: number): Metrics
	local text = {}
	for name, style in Theme.text do
		text[name] = math.floor(style.size * state.textMultiplier * textScale + 0.5)
	end
	-- Controls grow with their label so larger text never overflows a button.
	local tap = math.max(state.minTapTarget, text.label + 2 * Theme.space.lg)
	return {
		scale = state.scale,
		compact = state.compact,
		tap = math.ceil(tap),
		bar = math.ceil(tap + 2 * Theme.lesson.barPadding),
		text = text,
	}
end

return Context
