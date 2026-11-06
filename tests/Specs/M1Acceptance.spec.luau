--!strict
-- M1 acceptance checks from the design doc (section 8):
--   * 10,000 scripted purchases show odds within statistical tolerance
--   * killing the server mid-purchase never duplicates or loses coins (50 forced crashes)
--   * a Robux receipt replayed 100 times grants once
-- (Two servers can't both write one profile: ProfileManager.spec / SessionStore.spec.)
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Odds = require(Shared.Domain.Odds)
local Hatch = require(Shared.Domain.Hatch)
local Cards = require(Shared.Domain.Cards)
local PolicyRules = require(Shared.Domain.PolicyRules)
local Server = ServerScriptService:WaitForChild("Server")
local SessionStore = require(Server.Persistence.SessionStore)
local ProfileManager = require(Server.Persistence.ProfileManager)
local ReceiptProcessor = require(Server.Purchases.ReceiptProcessor)
local MockDataStore = require(script.Parent.Parent.Mocks.MockDataStore)
local Helpers = require(script.Parent.Parent.Helpers)

local USER = 31337

local function server(store: any, jobId: string, clock: { t: number }): any
	local now = function()
		return clock.t
	end
	return ProfileManager.new(
		SessionStore.new(store, {
			jobId = jobId,
			now = now,
			sleep = function(s)
				clock.t += s
			end,
		}) :: any,
		{ now = now }
	)
end

-- Chi-square critical values at p = 0.001 for df 1..30 (upper tail).
local CHI2_001 = {
	10.83,
	13.82,
	16.27,
	18.47,
	20.52,
	22.46,
	24.32,
	26.12,
	27.88,
	29.59,
	31.26,
	32.91,
	34.53,
	36.12,
	37.70,
	39.25,
	40.79,
	42.31,
	43.82,
	45.31,
	46.80,
	48.27,
	49.73,
	51.18,
	52.62,
	54.05,
	55.48,
	56.89,
	58.30,
	59.70,
}

return function()
	describe("M1: 10,000 scripted purchases", function()
		for _, eggId in { "egg_basic", "egg_dragon" } do
			it(`{eggId}: results fit the disclosed odds (chi-square, p = 0.001)`, function()
				local egg = Eggs.ById[eggId]
				local p = Helpers.profile({ coins = 1e11, highestTrophies = 10_000, cardSlots = 20_000 })
				local rng = Random.new(20261106)
				local counts: { [string]: number } = {}
				local N = 10_000
				for i = 1, N do
					local r = Hatch.buyWithCoins(p, eggId, `buy-{i}`, rng, Helpers.NOW)
					assert(r.ok, if r.ok then "" else r.err)
					local c = r.value.cards[1].characterId
					counts[c] = (counts[c] or 0) + 1
				end
				expect(Cards.count(p)).to.equal(N)
				expect(p.coins).to.equal(1e11 - N * (egg.coinPrice :: number))
				local odds = Odds.forEgg(egg, false)
				local chi2, cells, pooled = 0, 0, 0
				local pooledExpected = 0
				for _, row in odds.characters do
					local expected = N * row.percent / 100
					local observed = counts[row.characterId] or 0
					if expected >= 5 then
						chi2 += (observed - expected) ^ 2 / expected
						cells += 1
					else
						pooled += observed
						pooledExpected += expected
					end
					counts[row.characterId] = nil
				end
				if pooledExpected > 0 then
					chi2 += (pooled - pooledExpected) ^ 2 / pooledExpected
					cells += 1
				end
				expect((next(counts))).to.equal(nil) -- nothing outside the disclosed table
				expect(chi2 < CHI2_001[cells - 1]).to.equal(true)
			end)
		end
	end)

	describe("M1: 50 forced crashes mid-purchase", function()
		it("never duplicates or loses Coins or cards", function()
			local rng = Random.new(7)
			local egg = Eggs.ById.egg_basic
			local price = egg.coinPrice :: number
			local store, clock = MockDataStore.new(), { t = 1000 }
			-- Seed the profile with Coins.
			local seed = server(store, "seed", clock)
			local p0 = seed:load(USER)
			assert(p0.ok, "seed load")
			p0.value.coins = 1_000_000
			p0.value.cardSlots = 1000
			assert(seed:release(USER).ok, "seed release")

			local purchasesAttempted = 0
			for crash = 1, 50 do
				local srv = server(store, `server-{crash}`, clock)
				local loaded = srv:load(USER)
				assert(loaded.ok, if loaded.ok then "" else loaded.err)
				local profile = loaded.value
				local buys = rng:NextInteger(1, 6)
				local crashAt = rng:NextInteger(1, buys)
				for b = 1, buys do
					purchasesAttempted += 1
					-- Random DataStore trouble on the save after this purchase.
					local trouble = rng:NextInteger(1, 4)
					if trouble == 1 then
						store:failNext(rng:NextInteger(1, 8))
					elseif trouble == 2 then
						store:failAfterWrite(rng:NextInteger(1, 4))
					end
					Hatch.buyWithCoins(profile, "egg_basic", `c{crash}-b{b}`, rng, clock.t)
					if b == crashAt and rng:NextNumber() < 0.5 then
						break -- crash before this purchase is saved
					end
					srv:saveNow(USER)
					store:failNext(0)
					store:failAfterWrite(0)
					if b == crashAt then
						break -- crash right after the save
					end
				end
				store:failNext(0)
				store:failAfterWrite(0)
				-- The server dies without releasing; the next one waits out the stale lock.
				clock.t += 601

				local record = store:peek(`player_{USER}`).data
				local cardCount = 0
				for _ in record.cards do
					cardCount += 1
				end
				-- Coins and cards always move together: every Coin spent is a card owned.
				expect(1_000_000 - record.coins).to.equal(cardCount * price)
				expect(record.coins >= 0).to.equal(true)
				expect(cardCount <= purchasesAttempted).to.equal(true)
			end
		end)
	end)

	describe("M1: a Robux receipt replayed 100 times", function()
		it("grants once, on one server and across servers", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local product = { key = "egg_basic_x3", eggId = "egg_basic", quantity = 3, productId = 42 }
			local policy = PolicyRules.fromPolicyInfo({
				ArePaidRandomItemsRestricted = false,
				IsPaidItemTradingAllowed = true,
			})
			local granted = 0
			local srv: any = nil
			for replay = 1, 100 do
				-- Every 10 replays the player hops to a new server.
				if replay % 10 == 1 then
					srv = server(store, `s{replay}`, clock)
					assert(srv:load(USER).ok, "load")
				end
				local decision = ReceiptProcessor.process(
					{ PlayerId = USER, ProductId = 42, PurchaseId = "REPLAYED" },
					{
						getProfile = function(id)
							return srv:get(id)
						end,
						getPolicy = function()
							return policy
						end,
						saveNow = function(id)
							return srv:saveNow(id)
						end,
						markDirty = function() end,
						products = { [42] = product },
						rng = Random.new(replay),
						now = function()
							return clock.t
						end,
					}
				)
				if decision == "Granted" then
					granted += 1
				end
				if replay % 10 == 0 then
					srv:release(USER)
				end
			end
			expect(granted).to.equal(100) -- acknowledged every time...
			local count = 0
			for _ in store:peek(`player_{USER}`).data.cards do
				count += 1
			end
			expect(count).to.equal(3) -- ...but granted once
		end)
	end)
end
