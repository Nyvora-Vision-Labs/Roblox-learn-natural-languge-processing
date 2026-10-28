--!strict
-- Run through execute_luau in the Server play DataModel. All storage is an isolated
-- in-memory fake in copies of ProgressService; this never touches production keys.
-- Two intentional failures exercise the real retry loop and log expected warnings.

local Players = game:GetService("Players")
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local player = assert(Players:GetPlayers()[1], "Start a playtest first")
local source = game.ServerScriptService.Server.ProgressService.Source
local checks: { [string]: boolean } = {}

local mockStorage = [[
local auditRoot = script.Parent
local DataStoreService = {}
function DataStoreService:GetDataStore(_name)
	local data = {}
	return {
		GetAsync = function(_, key)
			if auditRoot:GetAttribute("FailReads") then error("Expected audit read failure") end
			return data[key]
		end,
		UpdateAsync = function(_, key, transform)
			auditRoot:SetAttribute("Writes", (auditRoot:GetAttribute("Writes") or 0) + 1)
			if auditRoot:GetAttribute("FailWrites") then error("Expected audit write failure") end
			data[key] = transform(data[key])
			return data[key]
		end,
	}
end
]]

local function fixture(name: string, memory: boolean?): any
	local root = Instance.new("Folder")
	root.Name = "Audit_" .. name
	root.Parent = game.ServerScriptService
	local module = Instance.new("ModuleScript")
	module.Name = "IsolatedProgressService"
	local replaced, count = source:gsub('local DataStoreService = game:GetService%("DataStoreService"%)', function()
		return mockStorage
	end, 1)
	assert(count == 1, "Storage injection point changed")
	if memory then
		replaced = replaced:gsub("if game.PlaceId == 0 then", "if true then", 1)
	end
	module.Source = replaced
	module.Parent = root
	local service = require(module)
	local callbacks: { [string]: any } = {}
	local history = {}
	local remotes = {
		GetProgress = {},
		ProgressChanged = {
			FireClient = function(_self, _player, payload)
				table.insert(history, payload)
			end,
		},
		ReportLesson = {
			OnServerEvent = { Connect = function(_self, fn) callbacks.report = fn end },
		},
		SaveSettings = {
			OnServerEvent = { Connect = function(_self, fn) callbacks.settings = fn end },
		},
	}
	service.start(remotes)
	return { root = root, service = service, callbacks = callbacks, history = history }
end

local f = fixture("StorageFailures")
local service = f.service
local original = service.default()
local sanitized = service.sanitize({
	modules = { classifiers = { completed = "yes", bestScore = 99, lastCard = -3 } },
	settings = { textScale = 0 / 0, reducedMotion = 1, muted = "yes" },
})
checks.invalidStoredDataUsesDefaults = sanitized.modules.classifiers.completed == false
	and sanitized.modules.classifiers.bestScore == 0
	and sanitized.modules.classifiers.lastCard == 1
	and sanitized.settings.textScale == 1
	and sanitized.settings.reducedMotion == false
	and sanitized.settings.muted == false
original.modules.classifiers.completed = true
original.modules.classifiers.bestScore = 5
local newer = service.default()
newer.modules.classifiers.bestScore = 1
newer.modules.classifiers.lastCard = 3
newer.settings.textScale = 1.15
local merged = service.merge(original, newer)
checks.mergeKeepsBestAndCompletion = merged.modules.classifiers.completed
	and merged.modules.classifiers.bestScore == 5
	and merged.modules.classifiers.lastCard == 3
	and merged.settings.textScale == 1.15

f.callbacks.report(player, { kind = "completed", moduleId = "hmm", score = 5 })
f.callbacks.report(player, { kind = "completed", moduleId = "classifiers", score = 6 })
f.callbacks.report(player, { kind = "completed", moduleId = "classifiers", score = 0 / 0 })
f.callbacks.report(player, { kind = "card", moduleId = "classifiers", cardIndex = 0 })
f.callbacks.settings(player, { textScale = 99, muted = "yes" })
local clean = service.getPayload(player)
checks.invalidRemoteArgumentsRejected = clean.progress.modules.classifiers.bestScore == 0
	and clean.progress.modules.classifiers.lastCard == 1
	and clean.progress.settings.textScale == 1
	and clean.progress.settings.muted == false
checks.unlockOrderEnforced = clean.progress.modules.hmm.completed == false
	and service.isUnlocked(clean.progress, "classifiers")
	and not service.isUnlocked(clean.progress, "hmm")

f.callbacks.settings(player, { textScale = 1.15 })
f.root:SetAttribute("FailWrites", true)
service.saveNow(player)
local failed = service.getPayload(player)
checks.writeFailureReportedToClient = failed.persistent == false and f.history[#f.history].persistent == false
checks.writeFailureKeepsInMemoryProgress = failed.progress.settings.textScale == 1.15
checks.writeFailureRetried = f.root:GetAttribute("Writes") == 4
f.root:SetAttribute("FailWrites", false)
service.saveNow(player)
checks.writesRecoverAfterOutage = service.getPayload(player).persistent == true
	and f.history[#f.history].persistent == true

f.root:SetAttribute("FailReads", true)
local readFailure = service.reload(player)
checks.readFailureDisablesPersistence = readFailure.persistent == false
local before = f.root:GetAttribute("Writes")
service.saveNow(player)
checks.unreadStoredDataNeverOverwritten = before == f.root:GetAttribute("Writes")
f.root:SetAttribute("FailReads", false)
local recovered = service.reload(player)
checks.readRecoveryRetainsStoredProgress = recovered.persistent == true
	and recovered.progress.settings.textScale == 1.15

local rate = fixture("RateLimit")
for index = 1, 21 do
	rate.callbacks.report(player, { kind = "card", moduleId = "classifiers", cardIndex = index })
end
checks.writeRateLimitEnforced = rate.service.getPayload(player).progress.modules.classifiers.lastCard == 20

local memory = fixture("MemoryFallback", true)
memory.callbacks.report(player, { kind = "completed", moduleId = "classifiers", score = 4 })
memory.callbacks.settings(player, { textScale = 1.3, seenIntro = true })
local roundTrip = memory.service.reload(player)
checks.memoryFallbackStillPlayable = roundTrip.persistent == false
	and roundTrip.progress.modules.classifiers.completed
	and roundTrip.progress.modules.classifiers.bestScore == 4
checks.memoryFallbackSettingsRoundTrip = roundTrip.progress.settings.textScale == 1.3
	and roundTrip.progress.seenIntro

local count, failures = 0, {}
for name, passed in checks do
	count += 1
	if not passed then table.insert(failures, name) end
end
table.sort(failures)
return { checks = checks, count = count, failures = failures, allPassed = #failures == 0 }
