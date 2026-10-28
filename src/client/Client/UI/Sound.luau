--!strict
-- UI sounds. Respects the player's Sound setting through a getter set once at startup.
-- Sound instances are created on first use and reused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Sound = {}

local sounds: { [string]: Sound } = {}
local isMuted: () -> boolean = function()
	return false
end

function Sound.setMutedGetter(fn: () -> boolean)
	isMuted = fn
end

function Sound.play(name: string)
	if isMuted() then
		return
	end
	local id = (Assets.sound :: any)[name]
	if not id then
		return
	end
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "UI_" .. name
		sound.SoundId = id
		sound.Volume = (Assets.volume :: any)[name] or 0.4
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound:Play()
end

-- For QA: whether each sound has loaded.
function Sound.status(): { [string]: boolean }
	local out = {}
	for name, sound in sounds do
		out[name] = sound.IsLoaded
	end
	return out
end

return Sound
