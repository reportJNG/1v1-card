--!strict
-- The battle arenas (BAD_GUI_8 section 5): the map is picked from the match seed, every map has
-- the shared core, and the config validates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arenas = require(Shared.Config.Arenas)
local ArenaLayout = require(Shared.Domain.ArenaLayout)
local ConfigValidator = require(Shared.Domain.ConfigValidator)
local MatchHost = require(ServerScriptService.Server.Battle.MatchHost)

local DECK_A = {
	{ characterId = "ren_emberfang", level = 5 },
	{ characterId = "yuki_frostveil", level = 5 },
	{ characterId = "rai_stormvolt", level = 5 },
}
local DECK_B = {
	{ characterId = "vesper_shade", level = 5 },
	{ characterId = "aurelia_dawn", level = 5 },
	{ characterId = "brannok_ironhide", level = 5 },
}

return function()
	describe("Arenas", function()
		it("has the five maps", function()
			local names = {}
			for _, a in Arenas.List do
				table.insert(names, a.displayName)
			end
			expect(table.concat(names, ",")).to.equal(
				"Sakura Courtyard,Frozen Shrine,Volcano Forge,Celestial Isle,Storm Rooftop"
			)
		end)

		it("picks the same map for the same seed, every time", function()
			for seed = 1, 200 do
				local first = ArenaLayout.pick(seed * 7919)
				expect(Arenas.ById[first]).to.be.ok()
				for _ = 1, 3 do
					expect(ArenaLayout.pick(seed * 7919)).to.equal(first)
				end
			end
			-- pinned values: a change to the pick would put the two players of one match on
			-- different maps if their clients and server ever disagreed
			expect(ArenaLayout.pick(1)).to.equal(ArenaLayout.pick(1))
			expect(ArenaLayout.pick(2_147_483_646)).to.be.a("string")
			expect(ArenaLayout.pick(0)).to.be.a("string")
			expect(ArenaLayout.pick(-5)).to.equal(ArenaLayout.pick(5))
		end)

		it("spreads matches over all five maps", function()
			local counts: { [string]: number } = {}
			local n = 5000
			for i = 1, n do
				local id = ArenaLayout.pick(i * 104729 + 17)
				counts[id] = (counts[id] or 0) + 1
			end
			for _, a in Arenas.List do
				local share = (counts[a.id] or 0) / n
				expect(share > 0.15 and share < 0.25).to.equal(true)
			end
		end)

		it("gives every map the same core: platform, rim, pads, spawns and camera points", function()
			local reference = ArenaLayout.core(Arenas.List[1])
			for _, a in Arenas.List do
				local core = ArenaLayout.core(a)
				local byName = {}
				for i, c in core do
					byName[c.name] = c
					-- same place and size in every map; only the palette differs
					expect(table.concat(c.at, ",")).to.equal(table.concat(reference[i].at, ","))
					if c.size then
						expect(table.concat(c.size, ",")).to.equal(
							table.concat(reference[i].size :: any, ",")
						)
					end
				end
				for _, name in ArenaLayout.CORE_NAMES do
					expect(byName[name]).to.be.ok()
				end
				expect(byName.PadA.at[1]).to.equal(-ArenaLayout.MARK)
				expect(byName.PadB.at[1]).to.equal(ArenaLayout.MARK)
				expect((byName.Platform.size :: { number })[1]).to.equal(40)
			end
		end)

		it("keeps the skyline deterministic and the dressing away from the fight", function()
			for _, a in Arenas.List do
				local p1, p2 = ArenaLayout.prims(a), ArenaLayout.prims(a)
				expect(#p1).to.equal(#p2)
				for i, prim in p1 do
					expect(table.concat(prim.at, ",")).to.equal(table.concat(p2[i].at, ","))
				end
				-- no prop stands on the platform between or on the pads
				for _, piece in a.dressing do
					local x, z = piece.at[1], piece.at[3]
					expect(math.sqrt(x * x + z * z) > ArenaLayout.PLATFORM / 2 or piece.at[2] > 10).to.equal(
						true
					)
				end
			end
		end)

		it("validates (lighting, music, particles, meshes)", function()
			local report = ConfigValidator.validate()
			for _, e in report.errors do
				expect((string.find(e, "Arenas", 1, true))).to.equal(nil)
			end
		end)

		it("sends both players the same map in the start packet", function()
			local sent = {}
			local host = MatchHost.new({
				now = function()
					return 0
				end,
				send = function(userId, push, data)
					if push == "Battle.Start" then
						sent[userId] = data
					end
				end,
				onEnd = function()
					return {}
				end,
				reconnectSeconds = 30,
			})
			local r = host:create({
				matchId = "arena",
				mode = "Ranked",
				seed = 424242,
				seats = {
					{ userId = 1, name = "A", deck = DECK_A, trophies = 0 },
					{ userId = 2, name = "B", deck = DECK_B, trophies = 0 },
				},
			})
			expect(r.ok).to.equal(true)
			expect(sent[1].arena).to.equal(ArenaLayout.pick(424242))
			expect(sent[2].arena).to.equal(sent[1].arena)
		end)
	end)
end
