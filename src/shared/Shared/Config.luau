--!strict
-- Game-wide constants. Colors and sizes live in Theme, lesson content in Lessons/.

local Config = {}

-- Portal order. Index in this list is the module's Order attribute.
Config.MODULE_ORDER = { "classifiers", "hmm", "rnn", "attention", "transformers" } :: { string }

Config.QUIZ_LENGTH = 5
Config.PASS_MARK = 4
Config.MAX_CARDS = 40 -- upper bound for any cardIndex the server accepts

-- Settings
Config.TEXT_SCALES = { 1, 1.15, 1.3 } :: { number }

-- Persistence
Config.DATA_VERSION = 1
Config.DATASTORE_NAME = "Progress_v1"
Config.KEY_PREFIX = "u_"
Config.AUTOSAVE_INTERVAL = 180 -- seconds; only saves when dirty
Config.DATASTORE_RETRIES = 4
Config.DATASTORE_BACKOFF = 1 -- seconds; doubles each retry
Config.LOAD_TIMEOUT = 20 -- seconds GetProgress waits for a player's data

-- Remote rate limit: at most RATE_LIMIT_COUNT calls per RATE_LIMIT_WINDOW seconds per player
Config.RATE_LIMIT_COUNT = 20
Config.RATE_LIMIT_WINDOW = 5

-- Portals
Config.PORTAL_POLL_INTERVAL = 0.1
Config.PORTAL_REENTRY_COOLDOWN = 2

local indexById: { [string]: number } = {}
for i, id in Config.MODULE_ORDER do
	indexById[id] = i
end

-- Returns the 1-based position of a module, or nil for unknown ids.
function Config.moduleIndex(moduleId: string): number?
	return indexById[moduleId]
end

return Config
