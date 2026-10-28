--!strict
-- Client entry point. Everything else under Client is a ModuleScript.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent
local Controllers = Client:WaitForChild("Controllers")

local ProgressClient = require(Client:WaitForChild("ProgressClient"))
local DebugHooks = require(Client:WaitForChild("DebugHooks"))
local PortalController = require(Controllers:WaitForChild("PortalController"))
local LessonController = require(Controllers:WaitForChild("LessonController"))
local Toast = require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("Toast"))

local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
ProgressClient.start(remotes)

local function toast(text: string, kind: string?)
	local settings = ProgressClient.get().progress.settings
	Toast.show(text, { kind = kind :: any, reducedMotion = settings.reducedMotion, textScale = settings.textScale })
end

LessonController.start({
	progress = ProgressClient,
	portals = PortalController,
	toast = toast,
})

PortalController.start({
	progress = ProgressClient,
	onEnterOpen = function(moduleId: string)
		task.spawn(LessonController.open, moduleId)
	end,
	onEnterLocked = function(_moduleId: string, message: string)
		toast(message, "locked")
	end,
})

-- Reduced motion changes how portals animate.
local lastReducedMotion = ProgressClient.get().progress.settings.reducedMotion
ProgressClient.onSettingsChanged(function(settings)
	if settings.reducedMotion ~= lastReducedMotion then
		lastReducedMotion = settings.reducedMotion
		PortalController.refreshAll()
	end
end)

DebugHooks.start({
	openLesson = function(moduleId: string, cardIndex: number)
		task.spawn(LessonController.open, moduleId, cardIndex, { instant = true })
	end,
})

local payload = ProgressClient.get()
if not payload.persistent then
	toast("Progress won't be saved this session.", "warning")
end
