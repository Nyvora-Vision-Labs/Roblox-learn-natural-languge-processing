--!strict
-- Client entry point. Everything else under Client is a ModuleScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent

local ProgressClient = require(Client:WaitForChild("ProgressClient"))
local DebugHooks = require(Client:WaitForChild("DebugHooks"))

local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
ProgressClient.start(remotes)

-- Controllers (Portal, Lesson, Hud, Input) start here from Milestone 1 on.

DebugHooks.start({})

local payload = ProgressClient.get()
print(`[Client] Progress ready (persistent = {payload.persistent})`)
