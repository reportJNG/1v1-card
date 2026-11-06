--!strict
-- M3 acceptance: the Luau engine and the Python reference model give identical results on
-- 1,000 seeded matches (same decks, levels, picks and replacements from the same seeds).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local BattleRules = require(Shared.Battle.BattleRules)
local Prng = require(Shared.Battle.Prng)
local Fixture = require(script.Parent.Parent.Fixtures.BattleParity)

local IDS = {}
for _, c in Characters.List do
	table.insert(IDS, c.id)
end

local function deckFor(seed: number): ({ BattleRules.UnitSpec }, { BattleRules.UnitSpec })
	local g = Prng.new(seed * 3 + 1)
	local function one()
		local pool = table.clone(IDS)
		local out = {}
		for _ = 1, 3 do
			local i = math.floor(g:next() * #pool) + 1
			local id = table.remove(pool, i) :: string
			table.insert(out, { characterId = id, level = 1 + math.floor(g:next() * 15) })
		end
		return out
	end
	local a = one()
	return a, one()
end

local function scriptedPick(m: BattleRules.Match, side: number, prng: Prng.Prng): BattleRules.Action
	local x = prng:next()
	if BattleRules.canSpecial(m, side) and x < 0.45 then
		return "Special"
	end
	if x < 0.75 then
		return "Attack"
	end
	return "Defend"
end

local function play(seed: number): BattleRules.Match
	local a, b = deckFor(seed)
	local m = BattleRules.new(a, b, seed)
	local pol = Prng.new(seed + 7919)
	while BattleRules.outcome(m) == nil do
		local pa: BattleRules.Action = scriptedPick(m, 1, pol)
		local pb: BattleRules.Action = scriptedPick(m, 2, pol)
		BattleRules.resolve(m, pa, pb)
		for side = 1, 2 do
			if BattleRules.needsNext(m, side) then
				BattleRules.chooseNext(m, side, BattleRules.defaultNext(m, side) :: number)
			end
		end
	end
	return m
end

return function()
	describe("Battle engine parity with the Python reference model", function()
		it("replays seed 1 event for event", function()
			local m = play(1)
			for i, text in Fixture.seed1 do
				expect(BattleRules.eventText(m.events[i])).to.equal(text)
			end
			expect(#m.events).to.equal(#Fixture.seed1)
		end)

		it("matches all 1,000 seeded matches exactly", function()
			local mismatches = {}
			for seed, row in Fixture.matches do
				local m = play(seed)
				if
					BattleRules.outcome(m) ~= row[1]
					or m.round ~= row[2]
					or BattleRules.signature(m) ~= row[3]
				then
					table.insert(mismatches, seed)
				end
			end
			expect(#Fixture.matches).to.equal(1000)
			expect(#mismatches).to.equal(0)
		end)
	end)
end
