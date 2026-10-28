--!strict
-- Keyboard and gamepad mapping while a lesson is open (CLAUDE.md §6.7).
-- ← / → or LB / RB change cards, Enter activates, 1–4 pick quiz options, X or B closes.
-- Movement and arrow keys are sunk so the character and camera stay put. Esc is never bound.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

export type Handlers = {
	prev: () -> (),
	next: () -> (),
	close: () -> (),
	activate: () -> (),
	option: (index: number) -> (),
	focus: () -> (),
}

local PRIORITY = Enum.ContextActionPriority.High.Value + 100

local ACTIONS = { "LessonPrev", "LessonNext", "LessonClose", "LessonEnter", "LessonOption", "LessonSink" }

local OPTION_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

local optionKeys: { Enum.KeyCode } = {}
for key in OPTION_KEYS do
	table.insert(optionKeys, key)
end

local InputController = {}

local active = false
local inputChanged: RBXScriptConnection? = nil

local function onBegin(fn: () -> ()): (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult
	return function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Sink
	end
end

function InputController.start(handlers: Handlers)
	if active then
		InputController.stop()
	end
	active = true
	inputChanged = UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType.Name:sub(1, 7) == "Gamepad" and not GuiService.SelectedObject then
			handlers.focus()
		end
	end)

	ContextActionService:BindActionAtPriority(
		"LessonPrev",
		onBegin(handlers.prev),
		false,
		PRIORITY,
		Enum.KeyCode.Left,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindActionAtPriority(
		"LessonNext",
		onBegin(handlers.next),
		false,
		PRIORITY,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindActionAtPriority(
		"LessonClose",
		onBegin(handlers.close),
		false,
		PRIORITY,
		Enum.KeyCode.X,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindActionAtPriority("LessonEnter", function(_, state)
		-- With a selected object, let Roblox's own selection handling activate it.
		if GuiService.SelectedObject then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			handlers.activate()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter)
	ContextActionService:BindActionAtPriority("LessonOption", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local index = OPTION_KEYS[input.KeyCode]
			if index then
				handlers.option(index)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, table.unpack(optionKeys))
	ContextActionService:BindActionAtPriority("LessonSink", function()
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Space)
	-- The thumbstick isn't sunk: gamepad GUI selection needs it, and character controls are disabled.
end

function InputController.stop()
	if not active then
		return
	end
	active = false
	if inputChanged then
		inputChanged:Disconnect()
		inputChanged = nil
	end
	for _, name in ACTIONS do
		ContextActionService:UnbindAction(name)
	end
end

-- True when the player's most recent input came from a gamepad.
function InputController.usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
		or (last == Enum.UserInputType.Focus and GuiService:IsTenFootInterface())
end

return InputController
