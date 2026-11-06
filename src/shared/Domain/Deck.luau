--!strict
-- Deck rules: exactly 3 owned, unlocked copies of 3 different, enabled characters.
local Types = require(script.Parent.Parent.Types)
local Characters = require(script.Parent.Parent.Config.Characters)
local Result = require(script.Parent.Result)

local Deck = {}

Deck.SIZE = 3

function Deck.validate(profile: Types.PlayerProfile, uids: { any }): Types.Result<nil>
	if typeof(uids) ~= "table" or #uids ~= Deck.SIZE then
		return Result.fail("DeckSize")
	end
	local count = 0
	for _ in uids do
		count += 1
	end
	if count ~= Deck.SIZE then
		return Result.fail("DeckSize") -- rejects sparse or keyed tables from a client
	end
	local seenUid: { [string]: boolean } = {}
	local seenCharacter: { [string]: boolean } = {}
	for _, uid in uids do
		if typeof(uid) ~= "string" then
			return Result.fail("BadUid")
		end
		if seenUid[uid] then
			return Result.fail("DuplicateCard")
		end
		seenUid[uid] = true
		local copy = profile.cards[uid]
		if copy == nil then
			return Result.fail("NotOwned")
		end
		if copy.lockedBy ~= nil then
			return Result.fail("CardLocked")
		end
		local def = Characters.ById[copy.characterId]
		if def == nil or not def.enabled then
			return Result.fail("CharacterDisabled")
		end
		if seenCharacter[copy.characterId] then
			return Result.fail("DuplicateCharacter")
		end
		seenCharacter[copy.characterId] = true
	end
	return Result.ok(nil)
end

function Deck.set(profile: Types.PlayerProfile, uids: { any }): Types.Result<nil>
	local valid = Deck.validate(profile, uids)
	if valid.ok then
		profile.deck = { uids[1], uids[2], uids[3] }
	end
	return valid
end

return table.freeze(Deck)
