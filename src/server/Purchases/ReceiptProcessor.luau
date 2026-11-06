--!strict
-- Decides what to do with one Robux receipt. Pure: every dependency is injected, so the exact
-- logic MarketplaceService.ProcessReceipt runs is the logic the tests run.
--
-- Rules
--   1. Answer "Granted" only after a save that includes the grant has succeeded.
--   2. Idempotent by PurchaseId: a receipt already in processedReceipts grants nothing new;
--      it is acknowledged once the profile (with that record) is saved.
--   3. Eligibility is re-checked here, on the server, at delivery time, because a client can open
--      a purchase prompt by itself:
--        * paid random items restricted (or policy unknown)  -> not granted
--        * egg not available (world locked / not revealed)     -> not granted
--      An ineligible receipt is held: logged on the profile and left unresolved (NotProcessedYet),
--      which Roblox documents for products the player is not eligible for. It is redelivered on
--      a later join and granted only if the player has become eligible.
--   4. If the profile isn't loaded on this server, leave it unresolved: Roblox redelivers it when
--      the player joins a server again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Eggs = require(Shared.Config.Eggs)
local Hatch = require(Shared.Domain.Hatch)
local Progress = require(Shared.Domain.Progress)
local PolicyRules = require(Shared.Domain.PolicyRules)

export type Decision = "Granted" | "NotProcessedYet"

export type Deps = {
	getProfile: (userId: number) -> Types.PlayerProfile?,
	getPolicy: (userId: number) -> PolicyRules.PolicyState,
	saveNow: (userId: number) -> Types.Result<nil>,
	markDirty: (userId: number) -> (),
	products: { [number]: Types.RobuxEggProduct }, -- by Developer Product id
	rng: Random,
	now: () -> number,
}

local ReceiptProcessor = {}

local function hold(
	profile: Types.PlayerProfile,
	purchaseId: string,
	productId: number,
	reason: string,
	now: number
)
	local held = profile.heldReceipts[purchaseId]
	if held then
		held.reason = reason
		held.lastSeen = now
		held.count += 1
	else
		profile.heldReceipts[purchaseId] = {
			productId = productId,
			reason = reason,
			firstSeen = now,
			lastSeen = now,
			count = 1,
		}
	end
end

-- Returns the decision and a short reason for logs.
function ReceiptProcessor.process(receipt: any, deps: Deps): (Decision, string)
	if typeof(receipt) ~= "table" then
		return "NotProcessedYet", "BadReceipt"
	end
	local userId, productId, purchaseId = receipt.PlayerId, receipt.ProductId, receipt.PurchaseId
	if typeof(userId) ~= "number" or typeof(productId) ~= "number" then
		return "NotProcessedYet", "BadReceipt"
	end
	if typeof(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 100 then
		return "NotProcessedYet", "BadReceipt"
	end

	local profile = deps.getProfile(userId)
	if profile == nil then
		return "NotProcessedYet", "ProfileNotLoaded"
	end

	-- Already granted (possibly on another server, or before a failed save): acknowledge after a save.
	if profile.processedReceipts[purchaseId] ~= nil then
		local saved = deps.saveNow(userId)
		return if saved.ok then "Granted" else "NotProcessedYet",
			if saved.ok then "AlreadyGranted" else "SaveFailed"
	end

	local product = deps.products[productId]
	if product == nil then
		return "NotProcessedYet", "UnknownProduct"
	end
	local egg = Eggs.ById[product.eggId]
	local now = deps.now()

	local policy = deps.getPolicy(userId)
	local reason: string? = nil
	if not policy.known then
		reason = "PolicyUnknown"
	elseif not PolicyRules.canPurchasePaidRandomItems(policy) then
		reason = "PaidRandomItemsRestricted"
	elseif egg == nil or not egg.robuxPurchasable then
		reason = "NotARobuxEgg"
	elseif not Progress.isEggAvailable(profile, egg) then
		reason = "EggLocked"
	end
	if reason then
		hold(profile, purchaseId, productId, reason, now)
		deps.markDirty(userId)
		return "NotProcessedYet", reason
	end

	local granted = Hatch.grantRobux(profile, product, purchaseId, deps.rng, now)
	if not granted.ok then
		return "NotProcessedYet", granted.err
	end
	profile.heldReceipts[purchaseId] = nil
	deps.markDirty(userId)
	local saved = deps.saveNow(userId)
	if not saved.ok then
		-- The grant stays in memory with its PurchaseId recorded; the next delivery acknowledges it
		-- only after a successful save (rule 1), and never grants it twice (rule 2).
		return "NotProcessedYet", "SaveFailed"
	end
	return "Granted", "Granted"
end

return table.freeze(ReceiptProcessor)
