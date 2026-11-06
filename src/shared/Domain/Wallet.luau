--!strict
-- Every Coin and Gem change goes through here. Rules:
--   * integer, finite, non-zero deltas only; balances never go below 0 or above the cap
--   * every change carries a unique ref; a repeated ref is rejected (idempotency)
--   * every change is written to the profile ledger
-- `check` validates without mutating, so multi-step operations can validate everything first
-- and then apply changes that cannot fail.
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Parent.Config.Economy)
local Result = require(script.Parent.Result)

export type Currency = "coins" | "gems"

local Wallet = {}

local function cap(currency: Currency): number
	return if currency == "coins" then Economy.Wallet.maxCoins else Economy.Wallet.maxGems
end

function Wallet.balance(profile: Types.PlayerProfile, currency: Currency): number
	return if currency == "coins" then profile.coins else profile.gems
end

function Wallet.check(
	profile: Types.PlayerProfile,
	currency: Currency,
	delta: number,
	ref: string
): Types.Result<number>
	if currency ~= "coins" and currency ~= "gems" then
		return Result.fail("UnknownCurrency")
	end
	if typeof(delta) ~= "number" or delta ~= delta or delta == math.huge or delta == -math.huge then
		return Result.fail("InvalidAmount")
	end
	if delta == 0 or delta ~= math.floor(delta) then
		return Result.fail("InvalidAmount")
	end
	if typeof(ref) ~= "string" or #ref == 0 or #ref > 100 then
		return Result.fail("InvalidRef")
	end
	if profile.recentTx[ref] ~= nil then
		return Result.fail("DuplicateTransaction")
	end
	local after = Wallet.balance(profile, currency) + delta
	if after < 0 then
		return Result.fail("InsufficientFunds")
	end
	if after > cap(currency) then
		return Result.fail("BalanceCap")
	end
	return Result.ok(after)
end

local function pruneRecent(profile: Types.PlayerProfile)
	local limit = Economy.Wallet.recentTxLength
	local entries: { { ref: string, t: number } } = {}
	for ref, t in profile.recentTx do
		table.insert(entries, { ref = ref, t = t })
	end
	if #entries <= limit then
		return
	end
	table.sort(entries, function(a, b)
		if a.t == b.t then
			return a.ref < b.ref
		end
		return a.t < b.t
	end)
	for i = 1, #entries - limit do
		profile.recentTx[entries[i].ref] = nil
	end
end

function Wallet.apply(
	profile: Types.PlayerProfile,
	currency: Currency,
	delta: number,
	reason: string,
	ref: string,
	now: number
): Types.Result<number>
	local checked = Wallet.check(profile, currency, delta, ref)
	if not checked.ok then
		return checked
	end
	local after = checked.value
	if currency == "coins" then
		profile.coins = after
	else
		profile.gems = after
	end
	profile.recentTx[ref] = now
	pruneRecent(profile)
	table.insert(profile.ledger, {
		t = now,
		currency = currency :: string,
		delta = delta,
		balance = after,
		reason = reason,
		ref = ref,
	})
	local overflow = #profile.ledger - Economy.Wallet.ledgerLength
	if overflow > 0 then
		for _ = 1, overflow do
			table.remove(profile.ledger, 1)
		end
	end
	return Result.ok(after)
end

return table.freeze(Wallet)
