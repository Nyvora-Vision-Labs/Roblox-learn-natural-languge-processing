--!strict
-- Studio-only, attribute-driven debug hooks (CLAUDE.md §4.5). Trigger from execute_luau (Client):
--   game.Players.LocalPlayer:SetAttribute("Debug_OpenLesson", "hmm:4")
-- The attribute clears itself once handled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type Handlers = {
	openLesson: ((moduleId: string, cardIndex: number) -> ())?,
}

local DebugHooks = {}

-- "hmm:4" -> "hmm", 4. Card defaults to 1.
function DebugHooks.parseLessonTarget(value: string): (string?, number?)
	local moduleId, card = string.match(value, "^%s*([%w_]+)%s*:?%s*(%d*)%s*$")
	if not moduleId or not Config.moduleIndex(moduleId) then
		return nil, nil
	end
	local cardIndex = tonumber(card) or 1
	if cardIndex < 1 or cardIndex > Config.MAX_CARDS then
		return nil, nil
	end
	return moduleId, cardIndex
end

function DebugHooks.start(handlers: Handlers)
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Debug_OpenLesson"):Connect(function()
		local value = player:GetAttribute("Debug_OpenLesson")
		if type(value) ~= "string" then
			return
		end
		player:SetAttribute("Debug_OpenLesson", nil)

		local moduleId, cardIndex = DebugHooks.parseLessonTarget(value)
		if not (moduleId and cardIndex) then
			print(`[Debug] Debug_OpenLesson: couldn't parse "{value}"; expected "<moduleId>:<card>"`)
		elseif handlers.openLesson then
			handlers.openLesson(moduleId, cardIndex)
		else
			print(`[Debug] Debug_OpenLesson {moduleId}:{cardIndex} (LessonController isn't built yet)`)
		end
	end)
end

return DebugHooks
