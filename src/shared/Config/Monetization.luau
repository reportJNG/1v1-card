--!strict
-- Robux products (Q4): eggs from unlocked worlds, sold as Developer Products, and fixed-price
-- cosmetics. Never sold for Robux: Coins, Gems, Golden eggs, boosts, odds changes, levels, trophies.
--
-- Robux eggs are paid random items: the odds shown before purchase come from Domain/Odds, the
-- same function the roll uses. Restricted players (PolicyService) never see Robux egg offers and
-- keep the Coin path to the same eggs.
local Types = require(script.Parent.Parent.Types)
local Eggs = require(script.Parent.Eggs)

-- Developer Product ids, filled in after the products are created on the Creator Dashboard.
-- Key format: "<eggId>_x<quantity>". A product without an id is never offered.
local PRODUCT_IDS: { [string]: number } = {}

local QUANTITIES = table.freeze({ 1, 3 })

local RobuxEggs: { Types.RobuxEggProduct } = {}
local ByKey: { [string]: Types.RobuxEggProduct } = {}
for _, egg in Eggs.List do
	if egg.robuxPurchasable then
		for _, quantity in QUANTITIES do
			local key = `{egg.id}_x{quantity}`
			local product: Types.RobuxEggProduct = {
				key = key,
				eggId = egg.id,
				quantity = quantity,
				productId = PRODUCT_IDS[key],
			}
			table.insert(RobuxEggs, product)
			ByKey[key] = product
		end
	end
end

local ByProductId: { [number]: Types.RobuxEggProduct } = {}
for _, product in RobuxEggs do
	if product.productId then
		ByProductId[product.productId] = product
	end
end

return table.freeze({
	RobuxEggs = table.freeze(RobuxEggs),
	RobuxEggsByKey = table.freeze(ByKey),
	RobuxEggsByProductId = table.freeze(ByProductId),
	Quantities = QUANTITIES,
})
