--!strict
-- Profile shape, defaults and migrations. Every load passes through `load`, which migrates old
-- data forward, fills fields added since, and refuses data written by a newer game version
-- (so an old server can never overwrite it).
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Parent.Config.Economy)
local Result = require(script.Parent.Result)
local Cards = require(script.Parent.Cards)

export type Migration = (data: { [string]: any }) -> { [string]: any }

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 4

-- Migrations[n] upgrades a profile from version n to n + 1. Append only; never edit a shipped one.
ProfileSchema.Migrations = table.freeze({
	-- 1 -> 2: worlds, ranked anti-farming, quests, Guardian Trials, stats and settings.
	[1] = function(data: { [string]: any }): { [string]: any }
		data.currentWorld = data.currentWorld or 1
		data.opponentsToday = data.opponentsToday or {}
		data.questDay = data.questDay or -1
		data.trials = data.trials or {}
		data.stats = data.stats or { wins = 0, losses = 0, matches = 0, trialsCleared = 0 }
		data.settings = data.settings or { music = true, sfx = true, reducedMotion = false }
		return data
	end,
	-- 2 -> 3: per-node harvest times on the profile, so a server hop can't reset node respawns.
	[2] = function(data: { [string]: any }): { [string]: any }
		data.harvests = data.harvests or {}
		return data
	end,
	-- 3 -> 4: music and sound-effect volumes (whole percentages) in the settings.
	[3] = function(data: { [string]: any }): { [string]: any }
		data.settings = data.settings or { music = true, sfx = true, reducedMotion = false }
		data.settings.musicVolume = data.settings.musicVolume or 80
		data.settings.sfxVolume = data.settings.sfxVolume or 100
		return data
	end,
}) :: { [number]: Migration }

function ProfileSchema.new(userId: number): Types.PlayerProfile
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		coins = Economy.StartingCoins,
		gems = 0,
		trophies = 0,
		highestTrophies = 0,
		cards = {},
		cardSlots = Economy.CardStorage.startSlots,
		uidPrefix = tostring(userId),
		nextCardSerial = 1,
		deck = {},
		eggBag = {},
		items = { slots = Economy.ItemInventory.startSlots, stacks = {} },
		daily = { streakDay = 0, lastClaimDay = -1, freeEggDay = -1, winsToday = 0, dayKey = -1 },
		quests = {},
		settledMatches = {},
		processedReceipts = {},
		heldReceipts = {},
		recentTx = {},
		ledger = {},
		flags = {},
		currentWorld = 1,
		opponentsToday = {},
		questDay = -1,
		trials = {},
		stats = { wins = 0, losses = 0, matches = 0, trialsCleared = 0 },
		settings = { music = true, sfx = true, reducedMotion = false, musicVolume = 80, sfxVolume = 100 },
		harvests = {},
	}
end

-- Adds any top-level field the stored data is missing (fields added in later versions).
local function reconcile(data: { [string]: any }, defaults: { [string]: any })
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		elseif typeof(value) == "table" and typeof(data[key]) == "table" and next(value) ~= nil then
			-- shallow tables with fixed keys (items, daily)
			for subKey, subValue in value do
				if data[key][subKey] == nil then
					data[key][subKey] = subValue
				end
			end
		end
	end
end

-- Checks the fields every system relies on. Returns the first problem found.
function ProfileSchema.validate(profile: { [string]: any }): Types.Result<nil>
	local function isCount(v: any): boolean
		return typeof(v) == "number" and v == v and v >= 0 and v == math.floor(v)
	end
	for _, key in { "coins", "gems", "trophies", "highestTrophies", "cardSlots", "nextCardSerial" } do
		if not isCount(profile[key]) then
			return Result.fail(`BadField:{key}`)
		end
	end
	if typeof(profile.uidPrefix) ~= "string" or #profile.uidPrefix == 0 then
		return Result.fail("BadField:uidPrefix")
	end
	if typeof(profile.cards) ~= "table" or typeof(profile.deck) ~= "table" then
		return Result.fail("BadField:cards")
	end
	for uid, card in profile.cards do
		if typeof(card) ~= "table" or card.uid ~= uid or typeof(card.characterId) ~= "string" then
			return Result.fail(`BadCard:{uid}`)
		end
		if typeof(card.provenance) ~= "table" or typeof(card.provenance.paidLineage) ~= "boolean" then
			return Result.fail(`BadProvenance:{uid}`)
		end
		if card.favorite ~= nil and card.favorite ~= true then
			return Result.fail(`BadCard:{uid}`)
		end
		if card.origin == "Robux" and not card.provenance.paidLineage then
			return Result.fail(`LostPaidLineage:{uid}`)
		end
	end
	if typeof(profile.items) ~= "table" or not isCount(profile.items.slots) then
		return Result.fail("BadField:items")
	end
	for _, key in { "processedReceipts", "heldReceipts", "settledMatches", "recentTx" } do
		if typeof(profile[key]) ~= "table" then
			return Result.fail(`BadField:{key}`)
		end
	end
	return Result.ok(nil)
end

-- Gives a player who has never owned a card the starter cards (Economy.StarterCards) as a ready
-- deck, once. Card serials are never reused, so `nextCardSerial == 1` means no card ever existed;
-- nobody who has played can be topped up. Returns whether it granted.
function ProfileSchema.grantStarter(profile: Types.PlayerProfile, now: number): boolean
	if profile.flags.starterGranted or profile.nextCardSerial ~= 1 then
		return false
	end
	for _, characterId in Economy.StarterCards do
		local made = Cards.create(profile, characterId, "Reward", "starter", false, now)
		assert(made.ok, `starter card {characterId}`)
		table.insert(profile.deck, made.value.uid)
	end
	profile.flags.starterGranted = true
	return true
end

-- Migrates, reconciles and validates raw stored data. `userId` seeds a brand-new profile.
-- `migrations` is injectable for tests.
function ProfileSchema.load(
	raw: any,
	userId: number,
	migrations: { [number]: Migration }?
): Types.Result<Types.PlayerProfile>
	if raw == nil then
		return Result.ok(ProfileSchema.new(userId))
	end
	if typeof(raw) ~= "table" then
		return Result.fail("CorruptProfile")
	end
	local data: { [string]: any } = raw
	local steps = migrations or ProfileSchema.Migrations
	local version = data.schemaVersion
	if typeof(version) ~= "number" then
		return Result.fail("CorruptProfile")
	end
	local target = ProfileSchema.CURRENT_VERSION
	if migrations then
		-- Tests may supply migrations beyond the shipped version.
		local highest = target
		for n in migrations do
			highest = math.max(highest, n + 1)
		end
		target = highest
	end
	if version > target then
		return Result.fail("ProfileFromNewerVersion")
	end
	while version < target do
		local step = steps[version]
		if not step then
			return Result.fail(`MissingMigration:{version}`)
		end
		data = step(data)
		version += 1
		data.schemaVersion = version
	end
	reconcile(data, ProfileSchema.new(userId) :: any)
	local valid = ProfileSchema.validate(data)
	if not valid.ok then
		return Result.fail(valid.err)
	end
	return Result.ok(data :: any)
end

return table.freeze(ProfileSchema)
