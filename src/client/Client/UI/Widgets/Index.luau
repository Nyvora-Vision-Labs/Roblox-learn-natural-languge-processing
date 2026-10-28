--!strict
-- Widget registry. A widget module exports new(ctx, props) -> Widget.

local Context = require(script.Parent.Parent:WaitForChild("Context"))

export type Widget = {
	root: GuiObject,
	illustrative: boolean?, -- true when it shows hand-authored numbers (adds the badge)
	reset: () -> (),
	destroy: () -> (),
}

export type Factory = { new: (ctx: Context.Ctx, props: { [string]: any }) -> Widget }

local Widgets = {}

function Widgets.get(name: string): Factory?
	local module = script.Parent:FindFirstChild(name)
	if module and module:IsA("ModuleScript") and module ~= script then
		return require(module) :: any
	end
	return nil
end

return Widgets
