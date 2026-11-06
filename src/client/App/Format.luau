--!strict
-- Text formatting and the player-facing wording of server error codes.
local Format = {}

function Format.number(n: number): string
	local a = math.abs(n)
	if a >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif a >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif a >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(math.floor(n))
	local out = string.reverse(s):gsub("(%d%d%d)", "%1,")
	out = string.reverse(out)
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return out
end

function Format.seconds(s: number): string
	s = math.max(0, math.ceil(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

function Format.percent(f: number): string
	return `{math.floor(f * 100 + 0.5)}%`
end

local ERRORS: { [string]: string } = {
	InsufficientFunds = "Not enough Coins.",
	StorageFull = "Card storage is full. Expand it or merge spares.",
	CardStorageFull = "Card storage is full. Expand it or merge spares.",
	InventoryFull = "Your item inventory is full. Sell items or expand it.",
	WorldLocked = "Reach more trophies to unlock this world.",
	EggNotAvailable = "This egg isn't available yet.",
	RateLimited = "Slow down a little.",
	ProfileNotLoaded = "Still loading your data...",
	ServerError = "Something went wrong. Try again.",
	NoDeck = "Build a 3-card deck first.",
	AlreadyQueued = "You're already searching.",
	AlreadyInMatch = "You're already in a match.",
	TrialCooldown = "Catch your breath: try the Trial again in a few seconds.",
	TooFar = "Get closer.",
	NotReady = "Not ready yet.",
	NotNearMerchant = "Walk up to the merchant to sell.",
	AlreadyClaimed = "Already claimed.",
	NotComplete = "Not finished yet.",
	PaidRandomItemsRestricted = "Robux eggs aren't available for your account. Coin eggs are.",
	PolicyUnknown = "Robux eggs aren't available right now.",
	QueueUnavailable = "Matchmaking is busy. Try again shortly.",
	EggBagFull = "Your Egg Bag stack is full.",
	EggLocked = "Unlock this egg's world first.",
	AlreadyClaimedToday = "Come back tomorrow for another free egg.",
	ProductNotPublished = "This Robux egg isn't on sale yet.",
	SpareNotBaseCopy = "Only level-1 copies that were never merged can be used as spares.",
	SpareInDeck = "A spare can't be in your deck.",
	CardInDeck = "Take the card out of your deck first.",
	NoMaxedCopy = "You can sell spares only once you have this character at max level.",
	StorageAtMax = "Card storage is already at its maximum.",
	AlreadyMaxLevel = "This card is already max level.",
	NoSpares = "No spare copies to merge.",
	NotSoldForCoins = "This egg can't be bought with Coins.",
	NotInMatch = "That match is over.",
	TooLate = "Too late for that pick.",
	AlreadyPicked = "You already picked.",
	InQueue = "Leave the queue first.",
}

function Format.error(code: string?): string
	if code == nil then
		return "Something went wrong."
	end
	local base = string.split(code, ":")[1]
	return ERRORS[base] or base:gsub("(%l)(%u)", "%1 %2")
end

return Format
