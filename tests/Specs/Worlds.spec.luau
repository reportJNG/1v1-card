--!strict
-- M6: world layouts, farming (range, respawn, world, inventory), merchants, travel, daily quests,
-- achievements and the 7-day streak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Farming = require(Shared.Domain.Farming)
local WorldLayout = require(Shared.Domain.WorldLayout)
local Progress = require(Shared.Domain.Progress)
local Quests = require(Shared.Domain.Quests)
local Streak = require(Shared.Domain.Streak)
local Inventory = require(Shared.Domain.Inventory)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local QuestsCfg = require(Shared.Config.Quests)
local Items = require(Shared.Config.Items)
local Worlds = require(Shared.Config.Worlds)
local Eggs = require(Shared.Config.Eggs)
local Economy = require(Shared.Config.Economy)
local Helpers = require(script.Parent.Parent.Helpers)

local DAY = 86400

-- A fixed RNG: yields the minimum and never rolls a rare drop unless asked.
local function rng(rare: boolean?): any
	return {
		NextInteger = function(_, min: number, _max: number)
			return min
		end,
		NextNumber = function()
			return if rare then 0 else 0.99
		end,
	}
end

local function firstNode(world: number): WorldLayout.Node
	return WorldLayout.nodes(world)[1]
end

local function harvestAt(
	p,
	node: WorldLayout.Node,
	offset: number,
	last: number?,
	now: number?,
	rare: boolean?
)
	local pos = node.position
	if last then
		p.harvests[node.id] = last
	end
	return Farming.harvest(p, node.id, {
		playerPosition = { x = pos.x + offset, y = pos.y, z = pos.z },
		now = now or Helpers.NOW,
		rng = rng(rare),
	})
end

return function()
	describe("World layouts", function()
		it("gives every world 2-3 resource types whose items exist and belong to it", function()
			for _, world in Worlds.List do
				local layout = WorldLayouts.ByWorld[world.id]
				expect(layout).to.be.ok()
				expect(#layout.resources >= 2 and #layout.resources <= 3).to.equal(true)
				for _, res in layout.resources do
					local item = Items.ById[res.itemId]
					expect(item).to.be.ok()
					expect(item.world).to.equal(world.id)
					if res.rareItemId then
						expect(Items.ById[res.rareItemId]).to.be.ok()
					end
				end
			end
		end)

		it("places every node inside its world, with unique stable ids", function()
			local seen = {}
			local half = WorldLayouts.WORLD_SIZE / 2
			for _, world in Worlds.List do
				local o = WorldLayout.origin(world.id)
				for _, node in WorldLayout.nodes(world.id) do
					expect(seen[node.id]).to.equal(nil)
					seen[node.id] = true
					expect(math.abs(node.position.x - o.x) <= half).to.equal(true)
					expect(math.abs(node.position.z - o.z) <= half).to.equal(true)
					expect(WorldLayout.node(node.id)).to.equal(node)
				end
			end
		end)

		it("keeps nodes clear of the spawn, the merchant and the Guardian", function()
			for _, world in Worlds.List do
				for _, node in WorldLayout.nodes(world.id) do
					expect(WorldLayout.distance(node.position, WorldLayout.spawn(world.id)) > 20).to.equal(
						true
					)
					expect(WorldLayout.distance(node.position, WorldLayout.merchant(world.id)) > 20).to.equal(
						true
					)
					expect(WorldLayout.distance(node.position, WorldLayout.guardian(world.id)) > 20).to.equal(
						true
					)
					expect(WorldLayout.distance(node.position, WorldLayout.lobbyPortal(world.id)) > 20).to.equal(
						true
					)
				end
			end
		end)

		it(
			"places each world's scenery inside its walls, clear of nodes, NPCs, the spawn and the path",
			function()
				local half = WorldLayouts.WORLD_SIZE / 2
				for _, world in Worlds.List do
					local o = WorldLayout.origin(world.id)
					local placed = WorldLayout.decor(world.id)
					local wanted = 0
					for _, d in WorldLayouts.ByWorld[world.id].theme.decor do
						wanted += d.count
					end
					expect(#placed).to.equal(wanted)
					local spots = {
						WorldLayout.spawn(world.id),
						WorldLayout.merchant(world.id),
						WorldLayout.guardian(world.id),
						WorldLayout.lobbyPortal(world.id),
					}
					for _, d in placed do
						local p = d.position
						expect(math.abs(p.x - o.x) < half and math.abs(p.z - o.z) < half).to.equal(true)
						for _, node in WorldLayout.nodes(world.id) do
							local flat = { x = node.position.x, y = 0, z = node.position.z }
							expect(WorldLayout.distance(p, flat) >= WorldLayout.CLEAR_NODE).to.equal(true)
						end
						for _, s in spots do
							local flat = { x = s.x, y = 0, z = s.z }
							expect(WorldLayout.distance(p, flat) >= WorldLayout.CLEAR_SPOT).to.equal(true)
						end
					end
				end
			end
		)

		it("never gives a terrain material two colours (material colours are shared by the place)", function()
			local seen: { [string]: string } = {}
			for _, layout in WorldLayouts.List do
				for material, hex in layout.theme.terrain.colors do
					if seen[material] then
						expect(`{material} {hex}`).to.equal(`{material} {seen[material]}`)
					end
					seen[material] = hex
				end
			end
		end)

		it("lays out the same scenery every time (every server builds the same map)", function()
			local a = WorldLayout.decor(3)
			local b = WorldLayout.decor(3)
			expect(a).to.equal(b) -- cached
			for i, d in a do
				expect(d.model).to.equal(b[i].model)
				expect(d.position.x).to.equal(b[i].position.x)
			end
		end)

		it("gives every world its node meshes, scenery, lighting preset and music", function()
			local WorldProps = require(Shared.Config.WorldProps)
			local Lighting = require(Shared.Config.Lighting)
			local Sounds = require(Shared.Config.Sounds)
			for _, world in Worlds.List do
				local layout = WorldLayouts.ByWorld[world.id]
				for _, res in layout.resources do
					expect(WorldProps.Models[res.model]).to.be.ok()
				end
				for _, d in layout.theme.decor do
					expect(WorldProps.Models[d.model]).to.be.ok()
				end
				local preset = Lighting[`world{world.id}`]
				expect(preset).to.be.ok()
				expect(preset.sky).to.be.ok()
				expect(Sounds[`music_world{world.id}`]).to.be.ok()
			end
			expect(WorldProps.Models.merchant_cart).to.be.ok()
			expect(WorldProps.Models.guardian_gate).to.be.ok()
		end)
	end)

	describe("Farming", function()
		it("harvests a node in range and adds the items", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			local r = harvestAt(p, node, 5)
			assert(r.ok, if r.ok then "" else r.err)
			expect(r.value.count).to.equal(node.resource.yield[1])
			expect(Inventory.countOf(p, node.resource.itemId)).to.equal(node.resource.yield[1])
			expect(r.value.readyAt).to.equal(Helpers.NOW + node.resource.respawnSeconds)
		end)

		it("rejects a harvest from out of range or with no character", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			local far = harvestAt(p, node, WorldLayouts.HARVEST_RANGE + 0.5)
			expect(if far.ok then "" else far.err).to.equal("TooFar")
			local none = Farming.harvest(p, node.id, { playerPosition = nil, now = Helpers.NOW, rng = rng() })
			expect(if none.ok then "" else none.err).to.equal("TooFar")
			expect(#p.items.stacks).to.equal(0)
		end)

		it("keeps respawn timers on the profile, so a server hop doesn't reset them", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			assert(harvestAt(p, node, 0).ok, "first harvest")
			expect(p.harvests[node.id]).to.equal(Helpers.NOW)
			-- the same profile loaded on another server: still on cooldown
			local again = harvestAt(p, node, 0, nil, Helpers.NOW + 1)
			expect(if again.ok then "" else again.err).to.equal("NotReady")
		end)

		it("rejects a node that hasn't respawned for this player yet", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			local respawn = node.resource.respawnSeconds
			local early = harvestAt(p, node, 0, Helpers.NOW, Helpers.NOW + respawn - 1)
			expect(if early.ok then "" else early.err).to.equal("NotReady")
			expect(harvestAt(p, node, 0, Helpers.NOW, Helpers.NOW + respawn).ok).to.equal(true)
		end)

		it("rejects unknown nodes and nodes in another or a locked world", function()
			local p = Helpers.profile()
			local unknown = Farming.harvest(
				p,
				"w1_nope_1",
				{ playerPosition = { x = 0, y = 0, z = 0 }, now = 0, rng = rng() }
			)
			expect(if unknown.ok then "" else unknown.err).to.equal("UnknownNode")
			local other = harvestAt(p, firstNode(2), 0)
			expect(if other.ok then "" else other.err).to.equal("WrongWorld")
			p.currentWorld = 2 -- somehow, without unlocking it
			local locked = harvestAt(p, firstNode(2), 0)
			expect(if locked.ok then "" else locked.err).to.equal("WrongWorld")
		end)

		it("stops at a full inventory and never destroys items", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			for i = 1, p.items.slots do
				local other = Items.List[3 + i]
				p.items.stacks[i] = { itemId = other.id, count = other.maxStack }
			end
			local r = harvestAt(p, node, 0)
			expect(if r.ok then "" else r.err).to.equal("InventoryFull")
		end)

		it("rolls a rare drop at the configured chance", function()
			local p = Helpers.profile()
			local node = firstNode(1)
			local r = harvestAt(p, node, 0, nil, nil, true)
			assert(r.ok, "harvest")
			expect(r.value.rareItemId).to.equal(node.resource.rareItemId)
			expect(Inventory.countOf(p, node.resource.rareItemId :: string)).to.equal(1)
		end)

		it("only trades with the merchant of the player's world, in range", function()
			local p = Helpers.profile()
			local m = WorldLayout.merchant(1)
			expect(Farming.nearMerchant(p, { x = m.x + 5, y = m.y, z = m.z })).to.equal(true)
			expect(Farming.nearMerchant(p, { x = m.x + 40, y = m.y, z = m.z })).to.equal(false)
			expect(Farming.nearMerchant(p, nil)).to.equal(false)
			-- in the lobby only the lobby's merchant trades
			local h = WorldLayout.hubMerchant()
			expect(Farming.nearMerchant(p, { x = h.x + 4, y = h.y, z = h.z }, 0)).to.equal(true)
			expect(Farming.nearMerchant(p, { x = m.x + 5, y = m.y, z = m.z }, 0)).to.equal(false)
			expect(Farming.nearMerchant(p, { x = h.x + 4, y = h.y, z = h.z }, p.currentWorld)).to.equal(false)
		end)
	end)

	describe("World travel", function()
		it("travels only to unlocked worlds", function()
			local p = Helpers.profile()
			local locked = Progress.travel(p, 2)
			expect(if locked.ok then "" else locked.err).to.equal("WorldLocked")
			p.highestTrophies = Worlds.ById[2].trophiesToUnlock
			expect(Progress.travel(p, 2).ok).to.equal(true)
			expect(p.currentWorld).to.equal(2)
			local unknown = Progress.travel(p, 11)
			expect(if unknown.ok then "" else unknown.err).to.equal("UnknownWorld")
		end)
	end)

	describe("Quests", function()
		it("rolls 3 distinct dailies per day, the same ones on a re-roll", function()
			local p = Helpers.profile()
			Quests.roll(p, Helpers.NOW)
			local first = Quests.dailyFor(p, Helpers.NOW // DAY)
			expect(#first).to.equal(QuestsCfg.dailyCount)
			local seen = {}
			for _, id in first do
				expect(seen[id]).to.equal(nil)
				seen[id] = true
				expect(p.quests[id]).to.be.ok()
			end
			Quests.roll(p, Helpers.NOW + 60)
			expect(table.concat(Quests.dailyFor(p, Helpers.NOW // DAY), ",")).to.equal(
				table.concat(first, ",")
			)
		end)

		it("drops yesterday's dailies on a new day, but keeps achievements", function()
			local p = Helpers.profile()
			Quests.track(p, "WinRanked", 1, Helpers.NOW)
			local today = Quests.dailyFor(p, Helpers.NOW // DAY)
			Quests.roll(p, Helpers.NOW + DAY)
			local tomorrow = Quests.dailyFor(p, Helpers.NOW // DAY + 1)
			for id in p.quests do
				if string.sub(id, 1, 2) == "d_" then
					expect(table.find(tomorrow, id) ~= nil).to.equal(true)
				end
			end
			expect(p.quests.a_first_win.progress).to.equal(1)
			expect(#today).to.equal(3)
		end)

		it("tracks progress up to the target and pays a completed quest once", function()
			local p = Helpers.profile()
			Quests.track(p, "WinRanked", 5, Helpers.NOW)
			expect(p.quests.a_first_win.progress).to.equal(1)
			local early = Quests.claim(p, "a_wins_25", Helpers.NOW)
			expect(if early.ok then "" else early.err).to.equal("NotComplete")
			local r = Quests.claim(p, "a_first_win", Helpers.NOW)
			assert(r.ok, if r.ok then "" else r.err)
			expect(p.gems).to.equal(QuestsCfg.ById.a_first_win.gems)
			local again = Quests.claim(p, "a_first_win", Helpers.NOW)
			expect(if again.ok then "" else again.err).to.equal("AlreadyClaimed")
			expect(p.gems).to.equal(QuestsCfg.ById.a_first_win.gems)
		end)

		it("pays today's daily quests in Coins and ignores dailies not rolled today", function()
			local p = Helpers.profile()
			Quests.roll(p, Helpers.NOW)
			local id = Quests.dailyFor(p, Helpers.NOW // DAY)[1]
			local def = QuestsCfg.ById[id]
			Quests.track(p, def.kind, def.target, Helpers.NOW, 1)
			local r = Quests.claim(p, id, Helpers.NOW)
			assert(r.ok, if r.ok then "" else r.err)
			expect(p.coins).to.equal(def.coins)
			local notToday = nil
			for _, q in QuestsCfg.Daily do
				if p.quests[q.id] == nil then
					notToday = q.id
				end
			end
			assert(notToday, "a daily not rolled today")
			local c = Quests.claim(p, notToday, Helpers.NOW)
			expect(if c.ok then "" else c.err).to.equal("UnknownQuest")
		end)

		it("reveals the Secret Egg only after harvesting in the Shadow Dimension", function()
			local p = Helpers.profile({ highestTrophies = Worlds.ById[9].trophiesToUnlock })
			local secret = Eggs.ById.egg_secret
			expect(Progress.isEggAvailable(p, secret)).to.equal(false)
			Quests.track(p, "Harvest", 500, Helpers.NOW, 1) -- elsewhere: doesn't count
			expect(p.quests.quest_reveal_secret_egg).to.equal(nil)
			Quests.track(p, "Harvest", 150, Helpers.NOW, 9)
			assert(Quests.claim(p, "quest_reveal_secret_egg", Helpers.NOW).ok, "claim")
			expect(Progress.isEggAvailable(p, secret)).to.equal(true)
		end)
	end)

	describe("7-day streak", function()
		it("pays Coins on days 1-6 and Gems plus a Golden egg on day 7, then restarts", function()
			local p = Helpers.profile()
			local coins = 0
			for day = 1, 6 do
				local r = Streak.claim(p, Helpers.NOW + (day - 1) * DAY)
				assert(r.ok, if r.ok then "" else r.err)
				expect(r.value.day).to.equal(day)
				coins += Economy.Streak.coins[day]
			end
			expect(p.coins).to.equal(coins)
			local seventh = Streak.claim(p, Helpers.NOW + 6 * DAY)
			assert(seventh.ok, "day 7")
			expect(seventh.value.day).to.equal(7)
			expect(p.gems).to.equal(Economy.Streak.day7Gems)
			expect(p.eggBag[Economy.Streak.day7Egg].golden).to.equal(1)
			local eighth = Streak.claim(p, Helpers.NOW + 7 * DAY)
			assert(eighth.ok, "day 8")
			expect(eighth.value.day).to.equal(1)
		end)

		it("allows one claim a day and restarts after a missed day", function()
			local p = Helpers.profile()
			Streak.claim(p, Helpers.NOW)
			local twice = Streak.claim(p, Helpers.NOW + 60)
			expect(if twice.ok then "" else twice.err).to.equal("AlreadyClaimed")
			Streak.claim(p, Helpers.NOW + DAY)
			expect(p.daily.streakDay).to.equal(2)
			local after = Streak.claim(p, Helpers.NOW + 3 * DAY)
			assert(after.ok, "claim")
			expect(after.value.day).to.equal(1)
		end)
	end)
end
