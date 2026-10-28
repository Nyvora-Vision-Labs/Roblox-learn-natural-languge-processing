--!strict
-- Client-side copy of this player's progress. The server is the source of truth;
-- this module fetches it once, then follows ProgressChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type Progress = Types.Progress
type ProgressPayload = Types.ProgressPayload

local ProgressClient = {}

local current: ProgressPayload? = nil
local listeners: { (ProgressPayload) -> () } = {}
local settingsListeners: { (Types.Settings) -> () } = {}
local remotes: Folder

local function set(payload: ProgressPayload)
	local previous = current and current.progress.settings
	local settings = payload.progress.settings
	current = payload
	if previous and (
		previous.textScale ~= settings.textScale
		or previous.reducedMotion ~= settings.reducedMotion
		or previous.muted ~= settings.muted
	) then
		for _, fn in table.clone(settingsListeners) do
			task.spawn(fn, settings)
		end
	end
	for _, fn in table.clone(listeners) do
		task.spawn(fn, payload)
	end
end

-- Yields until the server has sent this player's progress.
function ProgressClient.start(remotesFolder: Folder)
	remotes = remotesFolder
	local changed = remotes:WaitForChild("ProgressChanged") :: RemoteEvent
	changed.OnClientEvent:Connect(set)

	local getProgress = remotes:WaitForChild("GetProgress") :: RemoteFunction
	while not current do
		local ok, payload = pcall(getProgress.InvokeServer, getProgress)
		if ok and payload then
			if not current then
				set(payload)
			end
		else
			task.wait(1)
		end
	end
end

function ProgressClient.get(): ProgressPayload
	assert(current, "ProgressClient.start hasn't finished")
	return current
end

-- Subscribes to progress updates; returns an unsubscribe function.
function ProgressClient.onChanged(fn: (ProgressPayload) -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

function ProgressClient.isUnlocked(moduleId: string): boolean
	local index = Config.moduleIndex(moduleId)
	if not (index and current) then
		return false
	end
	return index == 1 or current.progress.modules[Config.MODULE_ORDER[index - 1]].completed
end

function ProgressClient.report(report: Types.LessonReport)
	(remotes:WaitForChild("ReportLesson") :: RemoteEvent):FireServer(report)
end

-- Applies settings locally right away (the server doesn't echo them back), then saves them.
function ProgressClient.setSettings(patch: { [string]: any })
	assert(current, "ProgressClient.start hasn't finished")
	local settings = current.progress.settings :: any
	for key, value in patch do
		if key ~= "seenIntro" then
			settings[key] = value
		end
	end
	if patch.seenIntro == true then
		current.progress.seenIntro = true
	end
	for _, fn in table.clone(settingsListeners) do
		task.spawn(fn, current.progress.settings)
	end
	(remotes:WaitForChild("SaveSettings") :: RemoteEvent):FireServer(patch)
end

function ProgressClient.onSettingsChanged(fn: (Types.Settings) -> ()): () -> ()
	table.insert(settingsListeners, fn)
	return function()
		local i = table.find(settingsListeners, fn)
		if i then
			table.remove(settingsListeners, i)
		end
	end
end

return ProgressClient
