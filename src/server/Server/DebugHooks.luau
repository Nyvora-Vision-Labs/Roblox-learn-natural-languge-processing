--!strict
-- Studio-only, attribute-driven debug hooks (CLAUDE.md §4.5). Trigger from execute_luau (Server):
--   game.Players:GetPlayers()[1]:SetAttribute("Debug_UnlockAll", true)
--   game.Players:GetPlayers()[1]:SetAttribute("Debug_ResetProgress", true)
--   game.Players:GetPlayers()[1]:SetAttribute("Debug_ReloadProgress", true) -- save, drop session, load again
-- Each attribute clears itself once handled.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProgressService = require(script.Parent:WaitForChild("ProgressService"))

local DebugHooks = {}

local HOOKS: { [string]: (Player) -> () } = {
	Debug_UnlockAll = ProgressService.unlockAll,
	Debug_ResetProgress = ProgressService.resetProgress,
	Debug_ReloadProgress = function(player: Player)
		ProgressService.reload(player)
	end,
}

local function watch(player: Player)
	for attribute, handler in HOOKS do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if player:GetAttribute(attribute) == true then
				player:SetAttribute(attribute, nil)
				print(`[Debug] {attribute} for {player.Name}`)
				handler(player)
			end
		end)
	end
end

function DebugHooks.start()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DebugHooks
