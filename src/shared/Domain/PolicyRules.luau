--!strict
-- Roblox PolicyService decisions, kept as two separate eligibilities (requirement 2):
--   * purchase: may this player buy paid random items (Robux eggs)?   ArePaidRandomItemsRestricted
--   * trading:  may this player trade paid items (V2 player store)?   IsPaidItemTradingAllowed
-- Both fail closed: unknown or malformed policy data means "not allowed".
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Eggs = require(Config.Eggs)
local Result = require(script.Parent.Result)
local Progress = require(script.Parent.Progress)
local Cards = require(script.Parent.Cards)

export type PolicyState = {
	known: boolean, -- false until PolicyService answered
	paidRandomItemsRestricted: boolean,
	paidItemTradingAllowed: boolean,
}

local PolicyRules = {}

PolicyRules.UNKNOWN = table.freeze({
	known = false,
	paidRandomItemsRestricted = true,
	paidItemTradingAllowed = false,
}) :: PolicyState

function PolicyRules.fromPolicyInfo(info: any): PolicyState
	if typeof(info) ~= "table" then
		return PolicyRules.UNKNOWN
	end
	local restricted = info.ArePaidRandomItemsRestricted
	local trading = info.IsPaidItemTradingAllowed
	return {
		known = true,
		paidRandomItemsRestricted = if typeof(restricted) == "boolean" then restricted else true,
		paidItemTradingAllowed = if typeof(trading) == "boolean" then trading else false,
	}
end

function PolicyRules.canPurchasePaidRandomItems(state: PolicyState): boolean
	return state.known and not state.paidRandomItemsRestricted
end

function PolicyRules.canTradePaidItems(state: PolicyState): boolean
	return state.known and state.paidItemTradingAllowed
end

-- May the server show this Robux egg offer? Restricted players keep the Coin path to the same
-- egg (Hatch.buyWithCoins), which is Roblox's "unpaid, earnable path" alternative.
function PolicyRules.robuxEggOffer(
	state: PolicyState,
	profile: Types.PlayerProfile,
	product: Types.RobuxEggProduct
): Types.Result<nil>
	if not PolicyRules.canPurchasePaidRandomItems(state) then
		return Result.fail("PaidRandomItemsRestricted")
	end
	if product.productId == nil then
		return Result.fail("ProductNotPublished")
	end
	local egg = Eggs.ById[product.eggId]
	if egg == nil or not egg.robuxPurchasable then
		return Result.fail("NotARobuxEgg")
	end
	if not Progress.isEggAvailable(profile, egg) then
		return Result.fail("EggLocked") -- Q10: Robux eggs only in unlocked worlds
	end
	if Cards.freeSlots(profile) < product.quantity then
		return Result.fail("CardStorageFull")
	end
	return Result.ok(nil)
end

-- V2 player store eligibility for one copy. A copy with any Robux-egg lineage counts as a paid
-- item; restricted players can't trade it. Kept here so the rule exists before the store does.
function PolicyRules.isCopyTradeEligible(state: PolicyState, copy: Types.CardCopy): boolean
	if copy.provenance.paidLineage then
		return PolicyRules.canTradePaidItems(state)
	end
	return true
end

return table.freeze(PolicyRules)
