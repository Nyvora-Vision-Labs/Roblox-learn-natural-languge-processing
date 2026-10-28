--!strict
-- Asset ids (icons, sounds). Only free assets.

local Assets = {}

Assets.sound = {
	locked = "rbxassetid://17582213219", -- "Click - Soft UI" (Creator Store, free)
	incorrect = "rbxassetid://17582213219", -- same soft click: gentle, never a penalty buzz
	correct = "rbxassetid://113645757352689", -- notification chime (Creator Store, free)
	complete = "rbxassetid://85188102085028", -- "LevelUp" (Creator Store, free)
	unlock = "rbxassetid://71491555548135", -- "GlowUp" (Creator Store, free)
}

Assets.volume = {
	locked = 0.35,
	incorrect = 0.3,
	correct = 0.4,
	complete = 0.45,
	unlock = 0.4,
}

return Assets
