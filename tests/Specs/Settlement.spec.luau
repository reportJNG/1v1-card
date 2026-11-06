--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settlement = require(Shared.Domain.Settlement)
local Economy = require(Shared.Config.Economy)
local Helpers = require(script.Parent.Parent.Helpers)

local M = Economy.Matches

local function input(overrides: { [string]: any }?): Settlement.Input
	local t: { [string]: any } = {
		matchId = "m-1",
		opponentId = 999,
		opponentTrophies = 0,
		won = true,
		rounds = 10,
		timeouts = 0,
		endedByForfeit = false,
		now = Helpers.NOW,
	}
	if overrides then
		for k, v in overrides do
			t[k] = v
		end
	end
	return t :: any
end

local function settle(p, overrides: { [string]: any }?): Settlement.Outcome
	local r = Settlement.settle(p, input(overrides))
	assert(r.ok, if r.ok then "" else r.err)
	return r.value
end

return function()
	describe("Settlement", function()
		it("pays a win the league purse and trophies, with no stake taken from anyone", function()
			local p = Helpers.profile()
			local o = settle(p)
			expect(o.coins).to.equal(M.purseByLeague.Bronze)
			expect(o.trophyDelta).to.equal(M.trophyWin)
			expect(p.coins).to.equal(M.purseByLeague.Bronze)
			expect(p.trophies).to.equal(M.trophyWin)
			expect(p.highestTrophies).to.equal(M.trophyWin)
			expect(p.stats.wins).to.equal(1)
			expect(p.daily.winsToday).to.equal(1)
			expect(o.reward).to.equal("Full")
		end)

		it("pays a loss the consolation Coins and takes trophies, never Coins", function()
			local p = Helpers.profile({ trophies = 100, highestTrophies = 100, coins = 50 })
			local o = settle(p, { won = false, opponentTrophies = 100 })
			expect(o.coins).to.equal(M.lossCoinsByLeague.Bronze)
			expect(p.coins).to.equal(50 + M.lossCoinsByLeague.Bronze)
			expect(p.trophies).to.equal(100 - M.trophyLoss)
			expect(p.highestTrophies).to.equal(100) -- worlds never re-lock
			expect(p.stats.losses).to.equal(1)
			expect(p.daily.winsToday).to.equal(0)
		end)

		it("is idempotent by matchId: a retried settlement pays nothing twice", function()
			local p = Helpers.profile()
			settle(p)
			local coins, trophies, ledger = p.coins, p.trophies, #p.ledger
			for _ = 1, 5 do
				local again = settle(p)
				expect(again.duplicate).to.equal(true)
				expect(again.coins).to.equal(0)
			end
			expect(p.coins).to.equal(coins)
			expect(p.trophies).to.equal(trophies)
			expect(#p.ledger).to.equal(ledger)
			expect(p.stats.matches).to.equal(1)
		end)

		it("adjusts trophies by the rating gap within the configured ranges", function()
			expect(Settlement.trophySwing(1000, 1000, true)).to.equal(M.trophyWin)
			expect(Settlement.trophySwing(1000, 1100, true)).to.equal(M.trophyWin + 4)
			expect(Settlement.trophySwing(1000, 900, true)).to.equal(M.trophyWin - 4)
			expect(Settlement.trophySwing(1000, 1100, false)).to.equal(M.trophyLoss - 4)
			expect(Settlement.trophySwing(1000, 3000, true)).to.equal(M.trophyWinRange[2])
			expect(Settlement.trophySwing(3000, 1000, true)).to.equal(M.trophyWinRange[1])
			expect(Settlement.trophySwing(1000, 3000, false)).to.equal(M.trophyLossRange[1])
			expect(Settlement.trophySwing(3000, 1000, false)).to.equal(M.trophyLossRange[2])
			-- a 24-trophy gap is under one divisor step either way
			expect(Settlement.trophySwing(1000, 976, true)).to.equal(M.trophyWin)
		end)

		it("never takes trophies below zero", function()
			local p = Helpers.profile({ trophies = 5 })
			local o = settle(p, { won = false })
			expect(p.trophies).to.equal(0)
			expect(o.trophyDelta).to.equal(-5)
		end)

		it("pays the reduced rate after the daily full-reward wins; trophies stay uncapped", function()
			local p = Helpers.profile()
			for i = 1, M.dailyFullRewardWins do
				settle(p, { matchId = `w{i}`, opponentId = 1000 + i })
			end
			local before = p.trophies
			local o = settle(p, { matchId = "extra", opponentId = 5000, opponentTrophies = p.trophies })
			expect(o.reward).to.equal("Reduced")
			expect(o.coins).to.equal(math.floor(M.purseByLeague.Bronze * M.reducedFactor))
			expect(p.trophies).to.equal(before + M.trophyWin)
		end)

		it("resets the daily cap and the same-opponent counts on a new UTC day", function()
			local p = Helpers.profile()
			for i = 1, M.dailyFullRewardWins do
				settle(p, { matchId = `w{i}`, opponentId = 1000 + i })
			end
			local o = settle(p, { matchId = "tomorrow", now = Helpers.NOW + 86400, opponentId = 1001 })
			expect(o.reward).to.equal("Full")
			expect(p.daily.winsToday).to.equal(1)
			expect(p.opponentsToday["1001"]).to.equal(1)
		end)

		it("voids the same pairing after the daily repeat limit, for winner and loser", function()
			local winner, loser =
				Helpers.profile(), Helpers.profile({ trophies = 500, highestTrophies = 500 })
			for i = 1, M.maxRepeatsPerDay do
				settle(winner, { matchId = `r{i}`, opponentId = 2 })
				settle(loser, { matchId = `r{i}`, opponentId = 1, won = false })
			end
			local wCoins, wTrophies, lTrophies = winner.coins, winner.trophies, loser.trophies
			local w = settle(winner, { matchId = "r-extra", opponentId = 2 })
			local l = settle(loser, { matchId = "r-extra", opponentId = 1, won = false })
			expect(w.voidReason).to.equal("RepeatOpponent")
			expect(l.voidReason).to.equal("RepeatOpponent")
			expect(winner.coins).to.equal(wCoins)
			expect(winner.trophies).to.equal(wTrophies)
			expect(loser.trophies).to.equal(lTrophies)
		end)

		it(
			"pays nothing for a forfeit before the minimum round, but the quitter still loses trophies",
			function()
				local winner = Helpers.profile()
				local quitter = Helpers.profile({ trophies = 200, highestTrophies = 200 })
				local w = settle(winner, { rounds = M.minRoundsForReward - 1, endedByForfeit = true })
				local q =
					settle(quitter, { rounds = M.minRoundsForReward - 1, endedByForfeit = true, won = false })
				expect(w.voidReason).to.equal("EarlyForfeit")
				expect(w.coins).to.equal(0)
				expect(w.trophyDelta).to.equal(0)
				expect(winner.daily.winsToday).to.equal(0)
				expect(q.coins).to.equal(0)
				expect(q.trophyDelta < 0).to.equal(true)
				-- a forfeit at or after the minimum round pays normally
				local late =
					settle(Helpers.profile(), { rounds = M.minRoundsForReward, endedByForfeit = true })
				expect(late.voidReason).to.equal(nil)
				expect(late.coins > 0).to.equal(true)
			end
		)

		it("pays nothing to a player who timed out on too many rounds", function()
			local p = Helpers.profile()
			local o = settle(p, { timeouts = M.timeoutsVoidReward })
			expect(o.voidReason).to.equal("Timeouts")
			expect(o.coins).to.equal(0)
			expect(o.trophyDelta).to.equal(0)
		end)

		it("reports the league change", function()
			local p = Helpers.profile({ trophies = 690, highestTrophies = 690 })
			local o = settle(p, { opponentTrophies = 690 })
			expect(o.leagueBefore).to.equal("Bronze")
			expect(o.leagueAfter).to.equal("Silver")
			expect(o.coins).to.equal(M.purseByLeague.Bronze) -- paid at the league the match was played in
		end)

		it("still settles when the wallet is at its cap, without the purse", function()
			local p = Helpers.profile({ coins = Economy.Wallet.maxCoins })
			local o = settle(p)
			expect(o.coins).to.equal(0)
			expect(p.trophies).to.equal(M.trophyWin)
			expect(p.settledMatches["m-1"]).to.equal(Helpers.NOW)
		end)

		it("rejects malformed input without changing the profile", function()
			local p = Helpers.profile()
			local bads: { { [string]: any } } =
				{ { matchId = "" }, { opponentId = 0 }, { rounds = -1 }, { timeouts = 0 / 0 } }
			for _, bad in bads do
				local r = Settlement.settle(p, input(bad))
				expect(r.ok).to.equal(false)
			end
			expect(p.stats.matches).to.equal(0)
			expect((next(p.settledMatches))).to.equal(nil)
		end)

		it("keeps the settled-match memory bounded, dropping the oldest", function()
			local p = Helpers.profile()
			for i = 1, M.settledMemory + 20 do
				settle(p, { matchId = `b{i}`, opponentId = 10_000 + i, now = Helpers.NOW + i })
			end
			local count = 0
			for _ in p.settledMatches do
				count += 1
			end
			expect(count).to.equal(M.settledMemory)
			expect(p.settledMatches.b1).to.equal(nil)
			expect(p.settledMatches[`b{M.settledMemory + 20}`]).to.equal(Helpers.NOW + M.settledMemory + 20)
		end)
	end)
end
