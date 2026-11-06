--!strict
-- Shared test fixtures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ProfileSchema = require(Shared.Domain.ProfileSchema)

local Helpers = {}

Helpers.NOW = 1_800_000_000

function Helpers.profile(overrides: { [string]: any }?): Types.PlayerProfile
	local p = ProfileSchema.new(123456)
	if overrides then
		for k, v in overrides do
			(p :: any)[k] = v
		end
	end
	return p
end

-- Adds copies of a character directly (bypasses hatching) and returns their uids.
function Helpers.giveCards(
	profile: Types.PlayerProfile,
	characterId: string,
	count: number,
	origin: Types.Origin?,
	ref: string?
): { string }
	local Cards = require(Shared.Domain.Cards)
	local uids = {}
	for i = 1, count do
		local o: Types.Origin = origin or "Coins"
		local r = ref or (if o == "Robux" then `purchase-{characterId}-{i}` else "test")
		local made = Cards.create(profile, characterId, o, r, false, Helpers.NOW)
		assert(made.ok, if made.ok then "" else made.err)
		table.insert(uids, made.value.uid)
	end
	return uids
end

local txCounter = 0
function Helpers.tx(): string
	txCounter += 1
	return `tx-{txCounter}`
end

return Helpers
