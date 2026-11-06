--!strict
-- The Guardian Trial AI is the "adaptive" reader from sim/balance.py; this checks the Luau port
-- against the Python policy on 300 seeded reader-vs-reader matches (sim/ai_parity.py).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local BattleRules = require(Shared.Battle.BattleRules)
local Prng = require(Shared.Battle.Prng)
local BattleAI = require(ServerScriptService.Server.Battle.BattleAI)
local Fixture = require(script.Parent.Parent.Fixtures.AIParity)

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

local function play(seed: number): BattleRules.Match
	local a, b = deckFor(seed)
	local m = BattleRules.new(a, b, seed)
	local g = Prng.new(seed * 7 + 3)
	local pa, pb = BattleAI.reader(), BattleAI.reader()
	while BattleRules.outcome(m) == nil do
		local x: BattleRules.Action = pa(m, 1, g)
		local y: BattleRules.Action = pb(m, 2, g)
		BattleRules.resolve(m, x, y)
		for side = 1, 2 do
			if BattleRules.needsNext(m, side) then
				BattleRules.chooseNext(m, side, BattleRules.defaultNext(m, side) :: number)
			end
		end
	end
	return m
end

return function()
	describe("Guardian AI parity with sim/balance.py", function()
		it("plays all 300 reader-vs-reader matches exactly like the Python policy", function()
			local mismatches = {}
			for seed, row in Fixture do
				local m = play(seed)
				if
					BattleRules.outcome(m) ~= row[1]
					or m.round ~= row[2]
					or BattleRules.signature(m) ~= row[3]
				then
					table.insert(mismatches, seed)
				end
			end
			expect(#Fixture).to.equal(300)
			expect(#mismatches).to.equal(0)
		end)

		it("only ever picks a legal action", function()
			for seed = 1, 50 do
				local a, b = deckFor(seed)
				local m = BattleRules.new(a, b, seed)
				local g = Prng.new(seed)
				local ai = BattleAI.reader()
				while BattleRules.outcome(m) == nil do
					local act: BattleRules.Action = ai(m, 2, g)
					expect(table.find(BattleRules.legal(m, 2), act) ~= nil).to.equal(true)
					BattleRules.resolve(m, "Attack", act)
					for side = 1, 2 do
						if BattleRules.needsNext(m, side) then
							BattleRules.chooseNext(m, side, BattleRules.defaultNext(m, side) :: number)
						end
					end
				end
			end
		end)
	end)
end
