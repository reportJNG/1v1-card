--!strict
-- Robux receipt delivery against real ProfileManager/SessionStore code on a mock DataStore:
-- idempotency, duplicate receipts on one and on two servers, crashes during the save,
-- delivery after reconnecting, and server-side eligibility at delivery time.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Cards = require(Shared.Domain.Cards)
local PolicyRules = require(Shared.Domain.PolicyRules)
local Server = ServerScriptService:WaitForChild("Server")
local SessionStore = require(Server.Persistence.SessionStore)
local ProfileManager = require(Server.Persistence.ProfileManager)
local ReceiptProcessor = require(Server.Purchases.ReceiptProcessor)
local MockDataStore = require(script.Parent.Parent.Mocks.MockDataStore)

local USER = 777
local KEY = `player_{USER}`
local BASIC_X3 = 9001 -- world 1 egg, 3-pack
local LOCKED_X1 = 9002 -- world 2 egg, 1-pack

local lockedEgg: any = nil
for _, egg in Eggs.List do
	if egg.world == 2 and egg.robuxPurchasable and egg.hiddenUntilQuest == nil then
		lockedEgg = egg
		break
	end
end
assert(lockedEgg, "needs a world-2 Robux egg")

local PRODUCTS = {
	[BASIC_X3] = { key = "egg_basic_x3", eggId = "egg_basic", quantity = 3, productId = BASIC_X3 },
	[LOCKED_X1] = { key = `{lockedEgg.id}_x1`, eggId = lockedEgg.id, quantity = 1, productId = LOCKED_X1 },
}

local ALLOWED =
	PolicyRules.fromPolicyInfo({ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true })

local function receipt(purchaseId: string, productId: number?): any
	return { PlayerId = USER, ProductId = productId or BASIC_X3, PurchaseId = purchaseId, CurrencySpent = 49 }
end

-- A simulated server: ProfileManager on the shared mock store, plus receipt deps wired to it.
local function server(store: any, jobId: string, clock: { t: number }, policy: any?): any
	local now = function()
		return clock.t
	end
	local pm = ProfileManager.new(
		SessionStore.new(store, {
			jobId = jobId,
			now = now,
			sleep = function(s)
				clock.t += s
			end,
		}) :: any,
		{ now = now }
	)
	local srv = { pm = pm, policy = policy or ALLOWED }
	srv.deps = {
		getProfile = function(id: number)
			return pm:get(id)
		end,
		getPolicy = function(_id: number)
			return srv.policy
		end,
		saveNow = function(id: number)
			return pm:saveNow(id)
		end,
		markDirty = function(id: number)
			pm:markDirty(id)
		end,
		products = PRODUCTS,
		rng = Random.new(11),
		now = now,
	}
	function srv.deliver(r: any): (string, string)
		return ReceiptProcessor.process(r, srv.deps)
	end
	return srv
end

local function stored(store: any): any
	return store:peek(KEY).data
end

local function countStored(store: any): number
	local n = 0
	for _ in stored(store).cards do
		n += 1
	end
	return n
end

return function()
	describe("Receipt delivery", function()
		it("grants, records the PurchaseId and saves before answering Granted", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			local decision = a.deliver(receipt("P-1"))
			expect(decision).to.equal("Granted")
			-- Already persisted at the moment Granted is returned.
			expect(stored(store).processedReceipts["P-1"]).to.be.ok()
			expect(countStored(store)).to.equal(3)
			for _, card in stored(store).cards do
				expect(card.origin).to.equal("Robux")
				expect(card.originRef).to.equal("P-1")
				expect(card.provenance.paidLineage).to.equal(true)
			end
		end)

		it("grants a duplicate receipt on the same server only once", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			a.deliver(receipt("P-1"))
			local decision, reason = a.deliver(receipt("P-1"))
			expect(decision).to.equal("Granted")
			expect(reason).to.equal("AlreadyGranted")
			expect(Cards.count(a.pm:get(USER))).to.equal(3)
			expect(countStored(store)).to.equal(3)
		end)

		it("grants a duplicate receipt delivered on another server only once", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			a.deliver(receipt("P-1"))
			a.pm:release(USER) -- player hops to server B; Roblox redelivers the receipt there
			local b = server(store, "B", clock)
			b.pm:load(USER)
			local decision, reason = b.deliver(receipt("P-1"))
			expect(decision).to.equal("Granted")
			expect(reason).to.equal("AlreadyGranted")
			expect(Cards.count(b.pm:get(USER))).to.equal(3)
		end)

		it("answers NotProcessedYet when the save fails, then acknowledges without a second grant", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			store:failNext(4)
			local decision, reason = a.deliver(receipt("P-1"))
			expect(decision).to.equal("NotProcessedYet")
			expect(reason).to.equal("SaveFailed")
			expect(countStored(store)).to.equal(0)
			-- Roblox redelivers; the store is back.
			decision, reason = a.deliver(receipt("P-1"))
			expect(decision).to.equal("Granted")
			expect(reason).to.equal("AlreadyGranted")
			expect(countStored(store)).to.equal(3)
		end)

		it("grants exactly once on a new server after a crash during the save", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			store:failNext(100) -- save never lands; server A dies
			expect((a.deliver(receipt("P-1")))).to.equal("NotProcessedYet")
			store:failNext(0)
			clock.t += 601 -- A's lock goes stale
			local b = server(store, "B", clock)
			expect(b.pm:load(USER).ok).to.equal(true)
			expect((b.deliver(receipt("P-1")))).to.equal("Granted")
			expect(countStored(store)).to.equal(3)
			expect((b.deliver(receipt("P-1")))).to.equal("Granted")
			expect(countStored(store)).to.equal(3)
		end)

		it("does not grant again when the save landed but the server died before answering", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			a.deliver(receipt("P-1")) -- saved; pretend Roblox never got the answer
			clock.t += 601
			local b = server(store, "B", clock)
			b.pm:load(USER)
			local decision, reason = b.deliver(receipt("P-1"))
			expect(decision).to.equal("Granted")
			expect(reason).to.equal("AlreadyGranted")
			expect(countStored(store)).to.equal(3)
		end)

		it(
			"leaves the receipt unresolved while the profile isn't loaded, and delivers after reconnect",
			function()
				local store, clock = MockDataStore.new(), { t = 1000 }
				local a = server(store, "A", clock)
				local decision, reason = a.deliver(receipt("P-9"))
				expect(decision).to.equal("NotProcessedYet")
				expect(reason).to.equal("ProfileNotLoaded")
				-- The player reconnects (here, on another server) and Roblox redelivers.
				local b = server(store, "B", clock)
				b.pm:load(USER)
				expect((b.deliver(receipt("P-9")))).to.equal("Granted")
				expect(countStored(store)).to.equal(3)
			end
		)

		it("rejects malformed receipts and unknown products without touching the profile", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			for _, bad in
				{
					nil :: any,
					5,
					{},
					{ PlayerId = USER, ProductId = BASIC_X3 },
					{ PlayerId = USER, ProductId = BASIC_X3, PurchaseId = "" },
				}
			do
				local d, r = a.deliver(bad)
				expect(d).to.equal("NotProcessedYet")
				expect(r).to.equal("BadReceipt")
			end
			local d, r = a.deliver(receipt("P-2", 123))
			expect(d).to.equal("NotProcessedYet")
			expect(r).to.equal("UnknownProduct")
			expect(Cards.count(a.pm:get(USER))).to.equal(0)
		end)
	end)

	describe("Eligibility at delivery (server-side, never from the client)", function()
		it("holds a receipt for an egg in a locked world and delivers it once the world unlocks", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			a.pm:load(USER)
			local decision, reason = a.deliver(receipt("P-3", LOCKED_X1))
			expect(decision).to.equal("NotProcessedYet")
			expect(reason).to.equal("EggLocked")
			local profile = a.pm:get(USER)
			expect(profile.heldReceipts["P-3"].reason).to.equal("EggLocked")
			expect(Cards.count(profile)).to.equal(0)

			profile.highestTrophies = 10_000
			expect((a.deliver(receipt("P-3", LOCKED_X1)))).to.equal("Granted")
			expect(profile.heldReceipts["P-3"]).to.equal(nil)
			expect(Cards.count(profile)).to.equal(1)
		end)

		it("holds a receipt while the policy is unknown", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock, PolicyRules.UNKNOWN)
			a.pm:load(USER)
			local decision, reason = a.deliver(receipt("P-4"))
			expect(decision).to.equal("NotProcessedYet")
			expect(reason).to.equal("PolicyUnknown")
			expect(a.pm:get(USER).heldReceipts["P-4"].count).to.equal(1)
			a.deliver(receipt("P-4"))
			expect(a.pm:get(USER).heldReceipts["P-4"].count).to.equal(2)
		end)

		it("keeps held receipts across a save and reload", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock, PolicyRules.UNKNOWN)
			a.pm:load(USER)
			a.deliver(receipt("P-5"))
			a.pm:release(USER)
			expect(stored(store).heldReceipts["P-5"].productId).to.equal(BASIC_X3)
		end)
	end)
end
