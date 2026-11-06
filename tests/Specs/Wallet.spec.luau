--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Wallet = require(Shared.Domain.Wallet)
local Economy = require(Shared.Config.Economy)
local Helpers = require(script.Parent.Parent.Helpers)

return function()
	describe("Wallet", function()
		it("credits and debits, recording each change in the ledger", function()
			local p = Helpers.profile()
			expect(Wallet.apply(p, "coins", 500, "test", "a", Helpers.NOW).ok).to.equal(true)
			expect(Wallet.apply(p, "coins", -200, "test", "b", Helpers.NOW).ok).to.equal(true)
			expect(p.coins).to.equal(300)
			expect(#p.ledger).to.equal(2)
			expect(p.ledger[2].balance).to.equal(300)
		end)

		it("never goes negative", function()
			local p = Helpers.profile({ coins = 100 })
			local r = Wallet.apply(p, "coins", -101, "test", "a", Helpers.NOW)
			expect(r.ok).to.equal(false)
			expect(p.coins).to.equal(100)
			expect(#p.ledger).to.equal(0)
		end)

		it("rejects a repeated transaction ref", function()
			local p = Helpers.profile()
			Wallet.apply(p, "gems", 10, "test", "same", Helpers.NOW)
			local again = Wallet.apply(p, "gems", 10, "test", "same", Helpers.NOW)
			expect(again.ok).to.equal(false)
			expect(if again.ok then "" else again.err).to.equal("DuplicateTransaction")
			expect(p.gems).to.equal(10)
		end)

		it("rejects zero, fractional, NaN and infinite amounts", function()
			local p = Helpers.profile({ coins = 100 })
			for i, amount in { 0, 1.5, 0 / 0, math.huge, -math.huge } do
				expect(Wallet.apply(p, "coins", amount, "test", `bad{i}`, Helpers.NOW).ok).to.equal(false)
			end
			expect(p.coins).to.equal(100)
		end)

		it("rejects unknown currencies and balances above the cap", function()
			local p = Helpers.profile()
			expect(Wallet.apply(p, "robux" :: any, 1, "test", "x", Helpers.NOW).ok).to.equal(false)
			expect(Wallet.apply(p, "coins", Economy.Wallet.maxCoins + 1, "test", "y", Helpers.NOW).ok).to.equal(
				false
			)
		end)

		it("keeps the ledger and idempotency memory bounded", function()
			local p = Helpers.profile()
			for i = 1, Economy.Wallet.recentTxLength + 50 do
				Wallet.apply(p, "coins", 1, "test", `r{i}`, Helpers.NOW + i)
			end
			local remembered = 0
			for _ in p.recentTx do
				remembered += 1
			end
			expect(remembered).to.equal(Economy.Wallet.recentTxLength)
			expect(#p.ledger).to.equal(Economy.Wallet.ledgerLength)
			expect(p.recentTx[`r{Economy.Wallet.recentTxLength + 50}`]).to.be.ok()
		end)
	end)
end
