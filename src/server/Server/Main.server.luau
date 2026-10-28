--!strict
-- Server entry point. Everything else under Server is a ModuleScript.

local Server = script.Parent

local Remotes = require(Server:WaitForChild("Remotes"))
local ProgressService = require(Server:WaitForChild("ProgressService"))
local DebugHooks = require(Server:WaitForChild("DebugHooks"))

local remotes = Remotes.create()
ProgressService.start(remotes)
DebugHooks.start()
