--!strict
-- The request pipeline (Server/Net/Dispatcher), payload validators and the client view.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Check = require(Shared.Net.Check)
local Remotes = require(Shared.Net.Remotes)
local ClientView = require(Shared.Domain.ClientView)
local Cards = require(Shared.Domain.Cards)
local Net = ServerScriptService:WaitForChild("Server").Net
local Dispatcher = require(Net.Dispatcher)
local RateLimiter = require(Net.RateLimiter)
local Helpers = require(script.Parent.Parent.Helpers)

local function setup(profile: any?)
	local log = { dirty = 0, saved = 0, pushed = 0, messages = {} :: { string } }
	local clock = { t = 0 }
	local deps = {
		limiter = RateLimiter.new(),
		now = function()
			return clock.t
		end,
		userIdOf = function()
			return 1
		end,
		getProfile = function()
			return profile
		end,
		markDirty = function()
			log.dirty += 1
		end,
		saveNow = function()
			log.saved += 1
			return Result.ok(nil)
		end,
		push = function()
			log.pushed += 1
		end,
		log = function(m: string)
			table.insert(log.messages, m)
		end,
	}
	return deps, log, clock
end

local OK = function()
	return Result.ok("done")
end

return function()
	describe("Dispatcher", function()
		it("runs a valid request, marks dirty, saves when asked and pushes a delta", function()
			local deps, log = setup(Helpers.profile())
			local reply = Dispatcher.run(
				"Shop.BuyEgg",
				OK,
				{ saveNow = true },
				"p",
				{ eggId = "egg_basic", requestId = "r1" },
				deps
			)
			expect(reply.ok).to.equal(true)
			expect(reply.value).to.equal("done")
			expect(log.dirty).to.equal(1)
			expect(log.saved).to.equal(1)
			expect(log.pushed).to.equal(1)
		end)

		it("rejects malformed payloads before the handler runs", function()
			local deps = setup(Helpers.profile())
			local ran = false
			local handler = function()
				ran = true
				return Result.ok(nil)
			end
			local bad: { any } = {
				nil,
				"egg_basic",
				{ eggId = "egg_basic" },
				{ eggId = "egg basic!", requestId = "r" },
				{ eggId = "egg_basic", requestId = string.rep("x", 41) },
				{ eggId = "egg_basic", requestId = "r", extra = true },
				{ eggId = 5, requestId = "r" },
				{ eggId = "egg_basic", requestId = "r", count = 9 },
				{ eggId = "egg_basic", requestId = "r", count = 2.5 },
				{ eggId = "egg_basic", requestId = "r", count = "3" },
			}
			for i = 1, #bad + 1 do
				local reply = Dispatcher.run("Shop.BuyEgg", handler, nil, `p{i}`, bad[i], deps)
				expect(reply.err).to.equal("BadRequest")
			end
			expect(ran).to.equal(false)
		end)

		it("rate-limits per player and remote, then refills", function()
			local deps, _, clock = setup(Helpers.profile())
			local payload = { eggId = "egg_basic", requestId = "r" }
			for _ = 1, Remotes.Requests["Shop.BuyEgg"].burst do
				expect(Dispatcher.run("Shop.BuyEgg", OK, nil, "p", payload, deps).ok).to.equal(true)
			end
			expect(Dispatcher.run("Shop.BuyEgg", OK, nil, "p", payload, deps).err).to.equal("RateLimited")
			expect(Dispatcher.run("Shop.BuyEgg", OK, nil, "other", payload, deps).ok).to.equal(true)
			clock.t += 1
			expect(Dispatcher.run("Shop.BuyEgg", OK, nil, "p", payload, deps).ok).to.equal(true)
		end)

		it("hides handler errors from the client and refuses players without a profile", function()
			local deps, log = setup(Helpers.profile())
			local reply = Dispatcher.run("Deck.Set", function()
				error("secret internals")
			end, nil, "p", { uids = { "a", "b", "c" } }, deps)
			expect(reply.err).to.equal("ServerError")
			expect(string.find(log.messages[1], "secret internals", 1, true) ~= nil).to.equal(true)
			local noProfile = setup(nil)
			expect(Dispatcher.run("Deck.Set", OK, nil, "p", { uids = { "a", "b", "c" } }, noProfile).err).to.equal(
				"ProfileNotLoaded"
			)
			expect(Dispatcher.run("Nope.Nope", OK, nil, "p", {}, deps).err).to.equal("NotAvailable")
		end)

		it("does not mark dirty or push when the handler fails", function()
			local deps, log = setup(Helpers.profile())
			local reply = Dispatcher.run("Deck.Set", function()
				return Result.fail("DuplicateCharacter")
			end, nil, "p", { uids = { "a", "b", "c" } }, deps)
			expect(reply.err).to.equal("DuplicateCharacter")
			expect(log.dirty + log.pushed).to.equal(0)
		end)
	end)

	describe("Check", function()
		it("accepts only clean ids, integers and lists", function()
			expect(Check.id("egg_basic")).to.equal("egg_basic")
			expect(Check.id("")).to.equal(nil)
			expect(Check.id("a b")).to.equal(nil)
			expect(Check.id(12)).to.equal(nil)
			expect(Check.int(3, 1, 5)).to.equal(3)
			expect(Check.int(0 / 0, 1, 5)).to.equal(nil)
			expect(Check.int(2.5, 1, 5)).to.equal(nil)
			expect(Check.int(math.huge, 1, 5)).to.equal(nil)
			expect(Check.idList({ "a", "b" }, 3)).to.be.ok()
			expect(Check.idList({ "a", "a" }, 3)).to.equal(nil)
			expect(Check.idList({ "a", nil :: any, "c" }, 3)).to.equal(nil)
			local mixed: { [any]: any } = { "a" }
			mixed.x = "b"
			expect(Check.idList(mixed, 3)).to.equal(nil)
			expect(Check.idList({ "a", "b", "c", "d" }, 3)).to.equal(nil)
		end)

		it("parses Cards.SetFavorite only with a card id and a boolean", function()
			local parse = Remotes.Requests["Cards.SetFavorite"].parse
			expect(parse({ uid = "1-1", on = true })).to.be.ok()
			expect(parse({ uid = "1-1", on = false })).to.be.ok()
			expect(parse({ uid = "1-1", on = "yes" })).to.equal(nil)
			expect(parse({ uid = 5, on = true })).to.equal(nil)
			expect(parse({ uid = "1-1", on = true, extra = 1 })).to.equal(nil)
		end)

		it("parses every battle action and nothing else", function()
			local parse = Remotes.Requests["Battle.Pick"].parse
			for _, action in { "Attack", "Defend", "Special" } do
				expect(parse({ round = 1, action = action })).to.be.ok()
			end
			expect(parse({ round = 1, action = "Win" })).to.equal(nil)
			expect(parse({ round = 0, action = "Attack" })).to.equal(nil)
		end)
	end)

	describe("ClientView", function()
		it("never exposes receipts, ledger, provenance refs or idempotency memory", function()
			local p = Helpers.profile({ coins = 500 })
			Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-SECRET")
			p.processedReceipts["PURCHASE-SECRET"] = 1
			local view: any = ClientView.build(p)
			expect(view.processedReceipts).to.equal(nil)
			expect(view.ledger).to.equal(nil)
			expect(view.recentTx).to.equal(nil)
			expect(view.heldReceipts).to.equal(nil)
			for _, card in view.cards do
				expect(card.paid).to.equal(true)
				expect(card.provenance).to.equal(nil)
				expect(card.originRef).to.equal(nil)
			end
		end)

		it("produces deltas that rebuild the new view exactly", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 4)
			local before = ClientView.build(p)
			local clientCopy = ClientView.build(p)
			Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			p.trophies = 30
			local after = ClientView.build(p)
			local delta = ClientView.diff(before, after)
			expect(delta).to.be.ok()
			ClientView.apply(clientCopy, delta :: any)
			expect(ClientView.diff(clientCopy, after)).to.equal(nil)
			expect(clientCopy.cards[uids[2]]).to.equal(nil)
			expect(clientCopy.cards[uids[1]].level).to.equal(2)
			expect(ClientView.diff(after, ClientView.build(p))).to.equal(nil)
		end)
	end)

	describe("Selling spare cards", function()
		it("only sells base spares of a character already owned at max level", function()
			local p = Helpers.profile({ coins = 0 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			expect((Cards.sellSpares(p, { uids[2] }, Helpers.tx(), Helpers.NOW) :: any).err).to.equal(
				"NoMaxedCopy"
			)
			p.cards[uids[1]].level = 15
			local sold = Cards.sellSpares(p, { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			expect(sold.ok).to.equal(true)
			expect(p.coins).to.equal(300)
			expect(p.cards[uids[2]]).to.equal(nil)
			-- The maxed copy itself is not a spare.
			local other = Helpers.giveCards(p, "rai_stormvolt", 1)[1]
			p.cards[other].level = 15
			expect((Cards.sellSpares(p, { other }, Helpers.tx(), Helpers.NOW) :: any).err).to.equal(
				"NotASpare"
			)
		end)

		it("refuses deck cards, locked cards and duplicates in the list, changing nothing", function()
			local p = Helpers.profile({ coins = 0 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			p.cards[uids[1]].level = 15
			p.cards[uids[2]].lockedBy = "listing-1"
			expect((Cards.sellSpares(p, { uids[3], uids[2] }, Helpers.tx(), Helpers.NOW) :: any).err).to.equal(
				"CardLocked"
			)
			expect((Cards.sellSpares(p, { uids[3], uids[3] }, Helpers.tx(), Helpers.NOW) :: any).err).to.equal(
				"BadCardList"
			)
			expect(p.cards[uids[3]]).to.be.ok()
			expect(p.coins).to.equal(0)
		end)
	end)
end
