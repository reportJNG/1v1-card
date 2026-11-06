--!strict
-- Turning eggs into card copies. Four entry points, one per origin:
--   buyWithCoins   - shop purchase (Coins), origin "Coins"
--   grantRobux     - Developer Product receipt, origin "Robux" (paid random item)
--   openFromBag    - earned eggs (Golden and event eggs), origin "Reward"
--   claimDailyFree - one free Basic egg per day, origin "Daily"
-- Each validates everything first, then applies changes that cannot fail.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Eggs = require(Config.Eggs)
local EconomyCfg = require(Config.Economy)
local Result = require(script.Parent.Result)
local Odds = require(script.Parent.Odds)
local Wallet = require(script.Parent.Wallet)
local Cards = require(script.Parent.Cards)
local Progress = require(script.Parent.Progress)

export type HatchResult = { cards: { Types.CardCopy }, alreadyProcessed: boolean }

local Hatch = {}

local function rollInto(
	profile: Types.PlayerProfile,
	egg: Types.EggDef,
	golden: boolean,
	count: number,
	origin: Types.Origin,
	originRef: string,
	rng: Random,
	now: number,
	allowOverflow: boolean
): { Types.CardCopy }
	local out = {}
	for _ = 1, count do
		local rolled = Odds.roll(egg, golden, rng)
		local created =
			Cards.create(profile, rolled.characterId, origin, originRef, golden, now, allowOverflow)
		assert(created.ok, "card creation failed after validation")
		table.insert(out, created.value)
	end
	return out
end

function Hatch.buyWithCoins(
	profile: Types.PlayerProfile,
	eggId: string,
	requestId: string,
	rng: Random,
	now: number
): Types.Result<HatchResult>
	local egg = Eggs.ById[eggId]
	if egg == nil then
		return Result.fail("UnknownEgg")
	end
	if egg.coinPrice == nil then
		return Result.fail("NotSoldForCoins")
	end
	if not Progress.isEggAvailable(profile, egg) then
		return Result.fail("EggLocked")
	end
	if Cards.freeSlots(profile) < 1 then
		return Result.fail("CardStorageFull")
	end
	local price = egg.coinPrice :: number
	local check = Wallet.check(profile, "coins", -price, requestId)
	if not check.ok then
		return Result.fail(check.err)
	end
	Wallet.apply(profile, "coins", -price, `egg:{eggId}`, requestId, now)
	local cards = rollInto(profile, egg, false, 1, "Coins", eggId, rng, now, false)
	return Result.ok({ cards = cards, alreadyProcessed = false })
end

-- Grants a Robux egg receipt. Idempotent by PurchaseId: a replayed receipt grants nothing and
-- reports alreadyProcessed, so ProcessReceipt can safely return PurchaseGranted again.
-- Eligibility is checked twice on the server: before the prompt (PolicyRules.robuxEggOffer) and
-- again at delivery (server/Purchases/ReceiptProcessor), because a client can open a prompt by
-- itself. Storage overflow is allowed here: a paid grant is never lost to a full collection.
function Hatch.grantRobux(
	profile: Types.PlayerProfile,
	product: Types.RobuxEggProduct,
	purchaseId: string,
	rng: Random,
	now: number
): Types.Result<HatchResult>
	if typeof(purchaseId) ~= "string" or #purchaseId == 0 then
		return Result.fail("InvalidPurchaseId")
	end
	if profile.processedReceipts[purchaseId] ~= nil then
		return Result.ok({ cards = {}, alreadyProcessed = true })
	end
	local egg = Eggs.ById[product.eggId]
	if egg == nil or not egg.robuxPurchasable then
		return Result.fail("NotARobuxEgg")
	end
	if product.quantity < 1 then
		return Result.fail("InvalidQuantity")
	end
	local cards = rollInto(profile, egg, false, product.quantity, "Robux", purchaseId, rng, now, true)
	profile.processedReceipts[purchaseId] = now
	return Result.ok({ cards = cards, alreadyProcessed = false })
end

-- Adds an earned egg to the Egg Bag (quest, trial, streak, event rewards).
function Hatch.addToBag(
	profile: Types.PlayerProfile,
	eggId: string,
	golden: boolean,
	count: number
): Types.Result<number>
	local egg = Eggs.ById[eggId]
	if egg == nil then
		return Result.fail("UnknownEgg")
	end
	if golden and not egg.goldenAllowed then
		return Result.fail("NoGoldenVersion")
	end
	if count < 1 or count ~= math.floor(count) then
		return Result.fail("InvalidQuantity")
	end
	local stack = profile.eggBag[eggId] or { normal = 0, golden = 0 }
	local current = if golden then stack.golden else stack.normal
	if current + count > EconomyCfg.EggBag.maxPerStack then
		return Result.fail("EggBagFull")
	end
	if golden then
		stack.golden += count
	else
		stack.normal += count
	end
	profile.eggBag[eggId] = stack
	return Result.ok(current + count)
end

function Hatch.openFromBag(
	profile: Types.PlayerProfile,
	eggId: string,
	golden: boolean,
	rng: Random,
	now: number
): Types.Result<HatchResult>
	local egg = Eggs.ById[eggId]
	local stack = profile.eggBag[eggId]
	if egg == nil or stack == nil then
		return Result.fail("NotOwned")
	end
	local have = if golden then stack.golden else stack.normal
	if have < 1 then
		return Result.fail("NotOwned")
	end
	if golden and not egg.goldenAllowed then
		return Result.fail("NoGoldenVersion")
	end
	if Cards.freeSlots(profile) < 1 then
		return Result.fail("CardStorageFull")
	end
	if golden then
		stack.golden -= 1
	else
		stack.normal -= 1
	end
	if stack.golden == 0 and stack.normal == 0 then
		profile.eggBag[eggId] = nil
	end
	local cards = rollInto(profile, egg, golden, 1, "Reward", eggId, rng, now, false)
	return Result.ok({ cards = cards, alreadyProcessed = false })
end

-- One free egg per UTC day. `dayKey` = os.time() // 86400 on the server.
function Hatch.claimDailyFree(
	profile: Types.PlayerProfile,
	dayKey: number,
	rng: Random,
	now: number
): Types.Result<HatchResult>
	if profile.daily.freeEggDay == dayKey then
		return Result.fail("AlreadyClaimedToday")
	end
	if Cards.freeSlots(profile) < 1 then
		return Result.fail("CardStorageFull")
	end
	local egg = Eggs.ById[Eggs.DailyFreeEgg]
	profile.daily.freeEggDay = dayKey
	local cards = rollInto(profile, egg, false, 1, "Daily", `daily:{dayKey}`, rng, now, false)
	return Result.ok({ cards = cards, alreadyProcessed = false })
end

return table.freeze(Hatch)
