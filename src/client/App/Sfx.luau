--!strict
-- Every UI and game sound goes through here (MISSION 9): the slot's id and volume from
-- Config/Sounds, times the player's SFX volume from Settings; the same sound never plays twice
-- within 50 ms (debounce); "press" sounds get a ±5% random pitch so repeats don't sound robotic.
-- Claude can't listen to audio: every pick is "unreviewed" in docs/ASSETS.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local Sfx = {}

local DEBOUNCE = 0.05
local VARY: { [string]: boolean } = { click = true, tick = true, tab = true, hover = true, card_flip = true }

local volume = 1
local cache: { [string]: Sound } = {}
local last: { [string]: number } = {}

function Sfx.setVolume(v: number)
	volume = math.clamp(v, 0, 1)
end

function Sfx.volume(): number
	return volume
end

-- Plays a slot. `pitch` scales the playback speed (1 = as recorded).
function Sfx.play(name: string, pitch: number?)
	local def = Sounds[name]
	if def == nil or def.id == nil or volume <= 0 then
		return
	end
	local now = os.clock()
	if last[name] and now - last[name] < DEBOUNCE then
		return
	end
	last[name] = now
	local snd: Sound? = cache[name]
	if snd == nil then
		local made = Instance.new("Sound")
		made.Name = `Ui_{name}`
		made.SoundId = def.id
		made.Parent = SoundService
		cache[name] = made
		snd = made
	end
	local s = snd :: Sound
	s.Volume = def.volume * volume
	s.PlaybackSpeed = (pitch or 1) * (if VARY[name] then 0.95 + math.random() * 0.1 else 1)
	SoundService:PlayLocalSound(s)
end

-- Coins gained: the chime rises in pitch for bigger amounts (up to +25%).
function Sfx.coins(amount: number)
	Sfx.play("coin", 1 + math.clamp(math.log10(math.max(1, amount)) / 16, 0, 0.25))
end

return Sfx
