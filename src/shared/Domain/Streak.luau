--!strict
-- The 7-day daily streak. One claim per UTC day. Claiming the day after the last claim moves the
-- streak on; missing a day restarts it at day 1. Day 7 pays Gems and a Golden egg, then the
-- streak starts over.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Economy = require(Config.Economy)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)
local Hatch = require(script.Parent.Hatch)

export type Claim = { day: number, coins: number, gems: number, goldenEgg: string? }

local Streak = {}

local DAY = 86400

-- The streak day the next claim would be (1..7), for the UI.
function Streak.nextDay(profile: Types.PlayerProfile, now: number): number
	local today = now // DAY
	local d = profile.daily
	if d.lastClaimDay == today - 1 then
		return d.streakDay % 7 + 1
	end
	if d.lastClaimDay == today then
		return d.streakDay
	end
	return 1
end

function Streak.claim(profile: Types.PlayerProfile, now: number): Types.Result<Claim>
	local cfg = Economy.Streak
	local today = now // DAY
	if profile.daily.lastClaimDay == today then
		return Result.fail("AlreadyClaimed")
	end
	local day = Streak.nextDay(profile, now)
	local ref = `streak:{today}`
	local coins = if day < 7 then cfg.coins[day] else 0
	local gems = if day == 7 then cfg.day7Gems else 0
	local egg: string? = if day == 7 then cfg.day7Egg else nil
	if coins > 0 and not Wallet.check(profile, "coins", coins, ref).ok then
		return Result.fail("BalanceCap")
	end
	if gems > 0 and not Wallet.check(profile, "gems", gems, ref).ok then
		return Result.fail("BalanceCap")
	end
	if egg then
		local stack = profile.eggBag[egg]
		if stack and stack.golden >= Economy.EggBag.maxPerStack then
			egg = nil -- a full Golden stack keeps the streak and the Gems
		end
	end
	if coins > 0 then
		assert(Wallet.apply(profile, "coins", coins, "Streak", ref, now).ok, "validated")
	end
	if gems > 0 then
		assert(Wallet.apply(profile, "gems", gems, "Streak", ref, now).ok, "validated")
	end
	if egg then
		assert(Hatch.addToBag(profile, egg, true, 1).ok, "validated")
	end
	profile.daily.streakDay = day
	profile.daily.lastClaimDay = today
	return Result.ok({ day = day, coins = coins, gems = gems, goldenEgg = egg })
end

return table.freeze(Streak)
