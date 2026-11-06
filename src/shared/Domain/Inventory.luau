--!strict
-- Farmed-item inventory: slots hold one stack each. When full, adding returns what didn't fit
-- (`rejected`) and the caller leaves it on the resource node; nothing is destroyed.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Items = require(Config.Items)
local Economy = require(Config.Economy)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)

export type AddResult = { added: number, rejected: number }

local Inventory = {}

function Inventory.countOf(profile: Types.PlayerProfile, itemId: string): number
	local n = 0
	for _, stack in profile.items.stacks do
		if stack.itemId == itemId then
			n += stack.count
		end
	end
	return n
end

function Inventory.spaceFor(profile: Types.PlayerProfile, itemId: string): number
	local def = Items.ById[itemId]
	if def == nil then
		return 0
	end
	local space = (profile.items.slots - #profile.items.stacks) * def.maxStack
	for _, stack in profile.items.stacks do
		if stack.itemId == itemId then
			space += def.maxStack - stack.count
		end
	end
	return math.max(0, space)
end

function Inventory.add(profile: Types.PlayerProfile, itemId: string, count: number): Types.Result<AddResult>
	local def = Items.ById[itemId]
	if def == nil then
		return Result.fail("UnknownItem")
	end
	if count < 1 or count ~= math.floor(count) then
		return Result.fail("InvalidQuantity")
	end
	local remaining = count
	for _, stack in profile.items.stacks do
		if remaining == 0 then
			break
		end
		if stack.itemId == itemId and stack.count < def.maxStack then
			local moved = math.min(remaining, def.maxStack - stack.count)
			stack.count += moved
			remaining -= moved
		end
	end
	while remaining > 0 and #profile.items.stacks < profile.items.slots do
		local moved = math.min(remaining, def.maxStack)
		table.insert(profile.items.stacks, { itemId = itemId, count = moved })
		remaining -= moved
	end
	return Result.ok({ added = count - remaining, rejected = remaining })
end

function Inventory.remove(profile: Types.PlayerProfile, itemId: string, count: number): Types.Result<number>
	if count < 1 or count ~= math.floor(count) then
		return Result.fail("InvalidQuantity")
	end
	if Inventory.countOf(profile, itemId) < count then
		return Result.fail("NotEnoughItems")
	end
	local remaining = count
	for i = #profile.items.stacks, 1, -1 do
		local stack = profile.items.stacks[i]
		if stack.itemId == itemId and remaining > 0 then
			local taken = math.min(remaining, stack.count)
			stack.count -= taken
			remaining -= taken
			if stack.count == 0 then
				table.remove(profile.items.stacks, i)
			end
		end
	end
	return Result.ok(count)
end

-- Sells items to the NPC merchant at the configured price.
function Inventory.sell(
	profile: Types.PlayerProfile,
	itemId: string,
	count: number,
	txRef: string,
	now: number
): Types.Result<number>
	local def = Items.ById[itemId]
	if def == nil then
		return Result.fail("UnknownItem")
	end
	if count < 1 or count ~= math.floor(count) then
		return Result.fail("InvalidQuantity")
	end
	if Inventory.countOf(profile, itemId) < count then
		return Result.fail("NotEnoughItems")
	end
	local earned = def.sellPrice * count
	local check = Wallet.check(profile, "coins", earned, txRef)
	if not check.ok then
		return Result.fail(check.err)
	end
	Inventory.remove(profile, itemId, count)
	Wallet.apply(profile, "coins", earned, `sell:{itemId}`, txRef, now)
	return Result.ok(earned)
end

function Inventory.expand(profile: Types.PlayerProfile, txRef: string, now: number): Types.Result<number>
	local cfg = Economy.ItemInventory
	if profile.items.slots >= cfg.maxSlots then
		return Result.fail("InventoryAtMax")
	end
	local index = (profile.items.slots - cfg.startSlots) // cfg.slotsPerExpansion + 1
	local price = cfg.expansionPrices[index]
	if price == nil then
		return Result.fail("NoPriceConfigured")
	end
	local paid = Wallet.apply(profile, "coins", -price, "item_slot_expansion", txRef, now)
	if not paid.ok then
		return Result.fail(paid.err)
	end
	profile.items.slots = math.min(cfg.maxSlots, profile.items.slots + cfg.slotsPerExpansion)
	return Result.ok(profile.items.slots)
end

return table.freeze(Inventory)
