--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Helpers = require(script.Parent.Parent.Helpers)

return function()
	describe("Item inventory", function()
		it("starts with 5 slots", function()
			expect(Helpers.profile().items.slots).to.equal(5)
		end)

		it("fills existing stacks before opening new slots", function()
			local p = Helpers.profile()
			Inventory.add(p, "item_greenleaf", 30)
			Inventory.add(p, "item_greenleaf", 30)
			expect(#p.items.stacks).to.equal(2) -- 50 + 10
			expect(Inventory.countOf(p, "item_greenleaf")).to.equal(60)
		end)

		it("returns what doesn't fit instead of destroying it", function()
			local p = Helpers.profile()
			local max = Items.ById.item_greenleaf.maxStack
			local r = Inventory.add(p, "item_greenleaf", 5 * max + 7)
			expect(r.ok).to.equal(true)
			expect(if r.ok then r.value.added else -1).to.equal(5 * max)
			expect(if r.ok then r.value.rejected else -1).to.equal(7)
			expect(Inventory.spaceFor(p, "item_oak_log")).to.equal(0)
			local full = Inventory.add(p, "item_oak_log", 1)
			expect(if full.ok then full.value.rejected else -1).to.equal(1)
		end)

		it("removes from stacks and frees empty slots", function()
			local p = Helpers.profile()
			Inventory.add(p, "item_greenleaf", 60)
			expect(Inventory.remove(p, "item_greenleaf", 15).ok).to.equal(true)
			expect(Inventory.countOf(p, "item_greenleaf")).to.equal(45)
			expect(#p.items.stacks).to.equal(1)
			expect(Inventory.remove(p, "item_greenleaf", 46).ok).to.equal(false)
		end)

		it("sells to the NPC at the configured price", function()
			local p = Helpers.profile()
			Inventory.add(p, "item_meadow_crystal", 4)
			local r = Inventory.sell(p, "item_meadow_crystal", 4, "sell-1", Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(p.coins).to.equal(4 * Items.ById.item_meadow_crystal.sellPrice)
			expect(Inventory.countOf(p, "item_meadow_crystal")).to.equal(0)
			expect(Inventory.sell(p, "item_meadow_crystal", 1, "sell-2", Helpers.NOW).ok).to.equal(false)
		end)

		it("expands at configured prices up to the cap", function()
			local cfg = Economy.ItemInventory
			local p = Helpers.profile({ coins = 1e9 })
			local first = Inventory.expand(p, "e1", Helpers.NOW)
			expect(first.ok).to.equal(true)
			expect(p.items.slots).to.equal(cfg.startSlots + cfg.slotsPerExpansion)
			expect(p.coins).to.equal(1e9 - cfg.expansionPrices[1])
			for i = 2, #cfg.expansionPrices do
				expect(Inventory.expand(p, `e{i}`, Helpers.NOW).ok).to.equal(true)
			end
			expect(p.items.slots).to.equal(cfg.maxSlots)
			expect(Inventory.expand(p, "e-over", Helpers.NOW).ok).to.equal(false)
		end)

		it("refuses an expansion it can't pay for", function()
			local p = Helpers.profile({ coins = 0 })
			expect(Inventory.expand(p, "e1", Helpers.NOW).ok).to.equal(false)
			expect(p.items.slots).to.equal(5)
		end)
	end)
end
