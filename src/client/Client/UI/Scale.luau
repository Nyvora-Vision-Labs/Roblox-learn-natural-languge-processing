--!strict
-- Fits a 1280×720 reference stage into a ScreenGui (CLAUDE.md §6.2).
-- scale = min(w / 1280, h / 720, 1.35). Below 0.75 the stage switches to compact mode:
-- it fills the whole safe area instead of letterboxing and text gets a multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

export type ScaleState = {
	scale: number,
	compact: boolean,
	textMultiplier: number,
	minTapTarget: number, -- reference px
}

export type ScaleHandle = {
	get: (self: ScaleHandle) -> ScaleState,
	onChanged: (self: ScaleHandle, fn: (ScaleState) -> ()) -> () -> (),
	destroy: (self: ScaleHandle) -> (),
}

local Scale = {}

-- Pure calculation, exposed for checks via execute_luau.
function Scale.compute(viewport: Vector2): ScaleState
	local w, h = viewport.X, viewport.Y
	local scale = math.min(w / Theme.stage.X, h / Theme.stage.Y, Theme.maxScale)
	if scale <= 0 then
		scale = 1 -- not laid out yet
	end
	local compact = scale < Theme.compactBelow
	return {
		scale = scale,
		compact = compact,
		textMultiplier = if compact then Theme.compactTextMultiplier else 1,
		minTapTarget = math.max(Theme.minTapTarget, Theme.minTapPoints / scale),
	}
end

-- Sizes and centers `stage` inside `screenGui` and keeps it updated on resize.
-- `stage` must be a direct child of `screenGui`; a UIScale is added to it.
function Scale.attach(screenGui: ScreenGui, stage: GuiObject): ScaleHandle
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = stage

	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)

	local listeners: { (ScaleState) -> () } = {}
	local state = Scale.compute(screenGui.AbsoluteSize)

	local function apply()
		local viewport = screenGui.AbsoluteSize
		local nextState = Scale.compute(viewport)
		uiScale.Scale = nextState.scale
		if nextState.compact then
			stage.Size = UDim2.fromOffset(viewport.X / nextState.scale, viewport.Y / nextState.scale)
		else
			stage.Size = UDim2.fromOffset(Theme.stage.X, Theme.stage.Y)
		end

		local changed = nextState.scale ~= state.scale or nextState.compact ~= state.compact
		state = nextState
		if changed then
			for _, fn in table.clone(listeners) do
				task.spawn(fn, state)
			end
		end
	end

	local connection = screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()

	local handle = {}

	function handle.get(_self: any): ScaleState
		return state
	end

	function handle.onChanged(_self: any, fn: (ScaleState) -> ()): () -> ()
		table.insert(listeners, fn)
		return function()
			local i = table.find(listeners, fn)
			if i then
				table.remove(listeners, i)
			end
		end
	end

	function handle.destroy(_self: any)
		connection:Disconnect()
		table.clear(listeners)
		uiScale:Destroy()
	end

	return (handle :: any) :: ScaleHandle
end

return Scale
