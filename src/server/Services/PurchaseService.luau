--!strict
-- Robux egg purchases.
--   * Offer: the client asks for a product key; the server checks PolicyRules.robuxEggOffer
--     (policy, published product, unlocked world, storage) and only then opens the prompt.
--     Restricted players are refused here and keep the Coin path to the same egg.
--   * Delivery: MarketplaceService.ProcessReceipt -> Purchases/ReceiptProcessor, which re-checks
--     eligibility because a client can open a prompt without asking us.
-- The client is never trusted: it sends a product key, nothing else, and the policy attributes
-- on the Player are for UI only.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local PolicyRules = require(Shared.Domain.PolicyRules)
local ReceiptProcessor = require(script.Parent.Parent:WaitForChild("Purchases").ReceiptProcessor)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PolicyGate = require(script.Parent.PolicyGate)

local OFFER_COOLDOWN = 2 -- seconds between offer requests per player
local DELIVERY_WAIT = 15 -- seconds a receipt waits for the profile and policy after join

local PurchaseService = {}

local lastOffer: { [Player]: number } = {}

local function onOfferRequested(player: Player, productKey: unknown)
	local now = os.clock()
	if now - (lastOffer[player] or -math.huge) < OFFER_COOLDOWN then
		return
	end
	lastOffer[player] = now
	if typeof(productKey) ~= "string" or #productKey > 64 then
		return
	end
	local product = Monetization.RobuxEggsByKey[productKey]
	local profile = PlayerDataService.getProfile(player.UserId)
	if product == nil or profile == nil then
		return
	end
	local offer = PolicyRules.robuxEggOffer(PolicyGate.get(player), profile, product)
	if not offer.ok then
		print(`[Purchase] offer refused for {player.UserId} {productKey}: {offer.err}`)
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.productId :: number)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local userId = if typeof(receipt) == "table" then receipt.PlayerId else nil
	local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if player then
		-- Just joined: give the profile load and the policy lookup a moment to finish.
		PlayerDataService.waitForProfile(player.UserId, DELIVERY_WAIT)
		PolicyGate.waitUntilSettled(player, DELIVERY_WAIT)
	end
	local ok, decision, reason = pcall(ReceiptProcessor.process, receipt, {
		getProfile = function(id: number)
			return if Players:GetPlayerByUserId(id) then PlayerDataService.getProfile(id) else nil
		end,
		getPolicy = function(id: number)
			local p = Players:GetPlayerByUserId(id)
			return if p then PolicyGate.get(p) else PolicyRules.UNKNOWN
		end,
		saveNow = PlayerDataService.saveNow,
		markDirty = PlayerDataService.markDirty,
		products = Monetization.RobuxEggsByProductId,
		rng = Random.new(),
		now = os.time,
	})
	if not ok then
		warn(`[Purchase] receipt error: {decision}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = if typeof(receipt) == "table" then tostring(receipt.PurchaseId) else "?"
	print(`[Purchase] receipt {purchaseId} user {userId}: {decision} ({reason})`)
	return if decision == "Granted"
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function PurchaseService.init()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "RequestRobuxEgg"
	request.Parent = remotes
	request.OnServerEvent:Connect(onOfferRequested)
	Players.PlayerRemoving:Connect(function(player)
		lastOffer[player] = nil
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
