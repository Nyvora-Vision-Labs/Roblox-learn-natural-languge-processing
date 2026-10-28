--!strict
-- Loads, validates, merges and saves player progress (CLAUDE.md §4.3–4.4).
-- If DataStores are unavailable (unpublished place, API access off, outages) the server
-- keeps playing from an in-memory store and tells clients persistent = false.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type Progress = Types.Progress
type ProgressPayload = Types.ProgressPayload
type Remotes = {
	GetProgress: RemoteFunction,
	ProgressChanged: RemoteEvent,
	ReportLesson: RemoteEvent,
	SaveSettings: RemoteEvent,
}

-- A key-value backend with DataStore-like semantics.
type Backend = {
	name: string,
	get: (key: string) -> any,
	update: (key: string, transform: (old: any) -> any) -> any,
}

type Session = {
	progress: Progress,
	loaded: boolean,
	persistent: boolean,
	canSave: boolean, -- false only when loading failed; never overwrite unread stored data
	dirty: boolean,
	saving: boolean,
	saveQueued: boolean,
	calls: { number }, -- timestamps for rate limiting
}

local ProgressService = {}

local backend: Backend
local remotes: Remotes? = nil
local sessions: { [Player]: Session } = {}
local started = false

---------------------------------------------------------------------------
-- Pure data helpers (exposed so execute_luau can check them)
---------------------------------------------------------------------------

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy :: any
end
ProgressService.deepCopy = deepCopy

function ProgressService.default(): Progress
	local modules = {}
	for _, id in Config.MODULE_ORDER do
		modules[id] = { completed = false, bestScore = 0, lastCard = 1 }
	end
	return {
		v = Config.DATA_VERSION,
		modules = modules,
		settings = { textScale = 1, reducedMotion = false, muted = false },
		seenIntro = false,
	}
end

local function isInteger(n: any, min: number, max: number): boolean
	return type(n) == "number" and n == n and n % 1 == 0 and n >= min and n <= max
end

local function isTextScale(n: any): boolean
	if type(n) ~= "number" then
		return false
	end
	for _, allowed in Config.TEXT_SCALES do
		if math.abs(n - allowed) < 1e-3 then
			return true
		end
	end
	return false
end

-- Turns anything read from storage into a valid Progress. Unknown or bad fields fall back to defaults.
function ProgressService.sanitize(raw: any): Progress
	local result = ProgressService.default()
	if type(raw) ~= "table" then
		return result
	end
	-- v = 1 is the only version so far; migrations go here when the schema changes.

	if type(raw.modules) == "table" then
		for _, id in Config.MODULE_ORDER do
			local m = raw.modules[id]
			if type(m) == "table" then
				local target = result.modules[id]
				if type(m.completed) == "boolean" then
					target.completed = m.completed
				end
				if isInteger(m.bestScore, 0, Config.QUIZ_LENGTH) then
					target.bestScore = m.bestScore
				end
				if isInteger(m.lastCard, 1, Config.MAX_CARDS) then
					target.lastCard = m.lastCard
				end
			end
		end
	end

	if type(raw.settings) == "table" then
		local s = raw.settings
		if isTextScale(s.textScale) then
			result.settings.textScale = s.textScale
		end
		if type(s.reducedMotion) == "boolean" then
			result.settings.reducedMotion = s.reducedMotion
		end
		if type(s.muted) == "boolean" then
			result.settings.muted = s.muted
		end
	end

	if type(raw.seenIntro) == "boolean" then
		result.seenIntro = raw.seenIntro
	end
	return result
end

-- Combines stored data with this session's data without ever losing progress:
-- completion and seenIntro are sticky, bestScore keeps the max, and the newer
-- lastCard and settings win.
function ProgressService.merge(old: Progress, new: Progress): Progress
	local result = ProgressService.default()
	for _, id in Config.MODULE_ORDER do
		local a, b = old.modules[id], new.modules[id]
		result.modules[id] = {
			completed = a.completed or b.completed,
			bestScore = math.max(a.bestScore, b.bestScore),
			lastCard = b.lastCard,
		}
	end
	result.settings = deepCopy(new.settings)
	result.seenIntro = old.seenIntro or new.seenIntro
	return result
end

-- Module N is open when N = 1 or module N−1 is completed.
function ProgressService.isUnlocked(progress: Progress, moduleId: string): boolean
	local index = Config.moduleIndex(moduleId)
	if not index then
		return false
	end
	if index == 1 then
		return true
	end
	return progress.modules[Config.MODULE_ORDER[index - 1]].completed
end

---------------------------------------------------------------------------
-- Backends
---------------------------------------------------------------------------

local function withRetries<T>(label: string, fn: () -> T): (boolean, T | string)
	local delay = Config.DATASTORE_BACKOFF
	local lastErr: any = nil
	for attempt = 1, Config.DATASTORE_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < Config.DATASTORE_RETRIES then
			task.wait(delay)
			delay *= 2
		end
	end
	warn(`[ProgressService] {label} failed after {Config.DATASTORE_RETRIES} tries: {lastErr}`)
	return false, tostring(lastErr)
end

local function memoryBackend(): Backend
	local data: { [string]: any } = {}
	return {
		name = "memory",
		get = function(key: string): any
			return deepCopy(data[key])
		end,
		update = function(key: string, transform: (any) -> any): any
			local nextValue = transform(deepCopy(data[key]))
			if nextValue ~= nil then
				data[key] = deepCopy(nextValue)
			end
			return deepCopy(data[key])
		end,
	}
end

local function dataStoreBackend(store: DataStore): Backend
	return {
		name = "datastore",
		get = function(key: string): any
			return (store:GetAsync(key))
		end,
		update = function(key: string, transform: (any) -> any): any
			return (store:UpdateAsync(key, function(old)
				return transform(old)
			end))
		end,
	}
end

local function chooseBackend(): Backend
	if game.PlaceId == 0 then
		print("[ProgressService] Place isn't published; progress is kept in memory for this session.")
		return memoryBackend()
	end
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DATASTORE_NAME)
	if ok then
		local dsBackend = dataStoreBackend(store)
		-- Probe once so a config problem (e.g. Studio API access off) degrades to memory immediately.
		local probeOk = withRetries("DataStore probe", function()
			return dsBackend.get("probe")
		end)
		if probeOk then
			return dsBackend
		end
	end
	warn("[ProgressService] DataStore unavailable; progress is kept in memory for this session.")
	return memoryBackend()
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------

local function keyFor(player: Player): string
	return Config.KEY_PREFIX .. tostring(player.UserId)
end

local function payloadFor(session: Session): ProgressPayload
	return { progress = deepCopy(session.progress), persistent = session.persistent }
end

local function pushProgress(player: Player, session: Session)
	if remotes and player.Parent then
		remotes.ProgressChanged:FireClient(player, payloadFor(session))
	end
end

local function rateLimited(player: Player, session: Session): boolean
	local now = os.clock()
	local calls = session.calls
	while #calls > 0 and now - calls[1] > Config.RATE_LIMIT_WINDOW do
		table.remove(calls, 1)
	end
	if #calls >= Config.RATE_LIMIT_COUNT then
		return true
	end
	table.insert(calls, now)
	return false
end

local function load(player: Player)
	local session: Session = {
		progress = ProgressService.default(),
		loaded = false,
		persistent = backend.name == "datastore",
		canSave = true,
		dirty = false,
		saving = false,
		saveQueued = false,
		calls = {},
	}
	sessions[player] = session

	local ok, raw = withRetries(`load {keyFor(player)}`, function()
		return backend.get(keyFor(player))
	end)
	if sessions[player] ~= session then
		return -- left (or reloaded) while loading
	end
	if ok then
		session.progress = ProgressService.sanitize(raw)
	else
		-- Never save over data we couldn't read.
		session.persistent = false
		session.canSave = false
	end
	session.loaded = true
	pushProgress(player, session)
end

-- Writes the session to the backend. overwrite = true replaces stored data (used by reset).
local function save(player: Player, session: Session, overwrite: boolean?)
	if not session.canSave then
		return
	end
	if session.saving then
		session.saveQueued = true
		return
	end
	session.saving = true
	session.dirty = false
	local snapshot = deepCopy(session.progress)

	local ok, stored = withRetries(`save {keyFor(player)}`, function()
		return backend.update(keyFor(player), function(old)
			if overwrite then
				return snapshot
			end
			return ProgressService.merge(ProgressService.sanitize(old), snapshot)
		end)
	end)

	local wasPersistent = session.persistent
	if ok then
		-- Pick up anything another server saved, keeping changes made during the save.
		session.progress = ProgressService.merge(ProgressService.sanitize(stored), session.progress)
		session.persistent = backend.name == "datastore"
	else
		session.dirty = true
		session.persistent = false
	end
	session.saving = false
	if session.persistent ~= wasPersistent then
		pushProgress(player, session)
	end

	if session.saveQueued then
		session.saveQueued = false
		save(player, session)
	end
end

local function waitForSaves(session: Session)
	while session.saving do
		task.wait()
	end
end

---------------------------------------------------------------------------
-- Remote handlers (every argument is untrusted)
---------------------------------------------------------------------------

local REPORT_KINDS = { opened = true, card = true, completed = true }

local function onReportLesson(player: Player, payload: any)
	local session = sessions[player]
	if not (session and session.loaded) or rateLimited(player, session) then
		return
	end
	if type(payload) ~= "table" or type(payload.kind) ~= "string" or not REPORT_KINDS[payload.kind] then
		return
	end
	local moduleId = payload.moduleId
	if type(moduleId) ~= "string" or not Config.moduleIndex(moduleId) then
		return
	end
	if not ProgressService.isUnlocked(session.progress, moduleId) then
		return
	end

	local module = session.progress.modules[moduleId]
	local kind = payload.kind

	if kind == "opened" then
		if payload.cardIndex ~= nil and isInteger(payload.cardIndex, 1, Config.MAX_CARDS) then
			module.lastCard = payload.cardIndex
			session.dirty = true
		end
	elseif kind == "card" then
		if not isInteger(payload.cardIndex, 1, Config.MAX_CARDS) then
			return
		end
		module.lastCard = payload.cardIndex
		session.dirty = true
	elseif kind == "completed" then
		if not isInteger(payload.score, 0, Config.QUIZ_LENGTH) then
			return
		end
		module.bestScore = math.max(module.bestScore, payload.score)
		if payload.score >= Config.PASS_MARK then
			module.completed = true
		end
		session.dirty = true
		pushProgress(player, session)
		task.spawn(save, player, session)
	end
end

local function onSaveSettings(player: Player, payload: any)
	local session = sessions[player]
	if not (session and session.loaded) or rateLimited(player, session) then
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local settings = session.progress.settings
	if payload.textScale ~= nil and isTextScale(payload.textScale) then
		settings.textScale = payload.textScale
	end
	if type(payload.reducedMotion) == "boolean" then
		settings.reducedMotion = payload.reducedMotion
	end
	if type(payload.muted) == "boolean" then
		settings.muted = payload.muted
	end
	-- seenIntro can only be turned on from the client.
	if payload.seenIntro == true then
		session.progress.seenIntro = true
	end
	session.dirty = true
end

local function onGetProgress(player: Player): ProgressPayload?
	local deadline = os.clock() + Config.LOAD_TIMEOUT
	local session = sessions[player]
	while not (session and session.loaded) and os.clock() < deadline and player.Parent do
		task.wait(0.1)
		session = sessions[player]
	end
	if session and session.loaded then
		return payloadFor(session)
	end
	return nil
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function ProgressService.start(remotesIn: Remotes)
	assert(not started, "ProgressService already started")
	started = true
	remotes = remotesIn
	backend = chooseBackend()

	remotesIn.GetProgress.OnServerInvoke = onGetProgress
	remotesIn.ReportLesson.OnServerEvent:Connect(onReportLesson)
	remotesIn.SaveSettings.OnServerEvent:Connect(onSaveSettings)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if not session then
			return
		end
		if session.loaded then
			waitForSaves(session)
			save(player, session)
		end
		sessions[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			if session.loaded then
				pending += 1
				task.spawn(function()
					waitForSaves(session)
					save(player, session)
					pending -= 1
				end)
			end
		end
		while pending > 0 do
			task.wait()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, session in sessions do
				if session.loaded and session.dirty then
					task.spawn(save, player, session)
				end
			end
		end
	end)
end

function ProgressService.backendName(): string
	return backend and backend.name or "none"
end

function ProgressService.getPayload(player: Player): ProgressPayload?
	local session = sessions[player]
	return if session and session.loaded then payloadFor(session) else nil
end

-- Saves now and waits for it to finish.
function ProgressService.saveNow(player: Player)
	local session = sessions[player]
	if session and session.loaded then
		waitForSaves(session)
		save(player, session)
		waitForSaves(session)
	end
end

-- Drops the in-memory session and loads it again from the backend (used to verify round-trips).
function ProgressService.reload(player: Player): ProgressPayload?
	ProgressService.saveNow(player)
	sessions[player] = nil
	load(player)
	return ProgressService.getPayload(player)
end

-- Debug: mark every module completed (unlocks every portal).
function ProgressService.unlockAll(player: Player)
	local session = sessions[player]
	if not (session and session.loaded) then
		return
	end
	for _, id in Config.MODULE_ORDER do
		session.progress.modules[id].completed = true
	end
	pushProgress(player, session)
	task.spawn(save, player, session)
end

-- Debug: wipe progress, including what's stored.
function ProgressService.resetProgress(player: Player)
	local session = sessions[player]
	if not (session and session.loaded) then
		return
	end
	task.spawn(function()
		-- Let in-flight saves finish first; their merge would otherwise bring old progress back.
		waitForSaves(session)
		session.progress = ProgressService.default()
		pushProgress(player, session)
		save(player, session, true)
	end)
end

return ProgressService
