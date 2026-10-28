--!strict
-- Client entry point. Everything else under Client is a ModuleScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Index = require(Shared:WaitForChild("Lessons"):WaitForChild("Index"))

local ProgressClient = require(Client:WaitForChild("ProgressClient"))
local DebugHooks = require(Client:WaitForChild("DebugHooks"))
local PortalController = require(Client:WaitForChild("Controllers"):WaitForChild("PortalController"))
local Toast = require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("Toast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
ProgressClient.start(remotes)

local function toast(text: string, kind: Toast.Kind?)
	local settings = ProgressClient.get().progress.settings
	Toast.show(text, { kind = kind, reducedMotion = settings.reducedMotion, textScale = settings.textScale })
end

PortalController.start({
	progress = ProgressClient,
	onEnterOpen = function(moduleId: string)
		-- LessonController (Milestone 2) takes over here.
		local meta = Index.get(moduleId)
		toast(`{if meta then meta.title else moduleId}: the lesson screen arrives in the next update.`)
	end,
	onEnterLocked = function(_moduleId: string, message: string)
		toast(message, "locked")
	end,
})

DebugHooks.start({})

local payload = ProgressClient.get()
if not payload.persistent then
	toast("Progress won't be saved this session.", "warning")
end
