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

-- Short amounts for the HUD (MISSION 3.1): 950, 1.04K, 12.5K, 125K, 1.2M (three significant
-- digits, trailing zeros dropped).
function Format.short(n: number): string
	local a = math.abs(n)
	if a < 1000 then
		return tostring(math.floor(n))
	end
	local units: { { n: number, s: string } } =
		{ { n = 1e9, s = "B" }, { n = 1e6, s = "M" }, { n = 1e3, s = "K" } }
	for _, u in units do
		if a >= u.n then
			local v = n / u.n
			local decimals = if math.abs(v) >= 100 then 0 elseif math.abs(v) >= 10 then 1 else 2
			local s = string.format(`%.{decimals}f`, math.floor(v * 10 ^ decimals) / 10 ^ decimals)
			if string.find(s, ".", 1, true) then
				s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "")
			end
			return s .. u.s
		end
	end
	return tostring(n)
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
	NotPlaying = "Press PLAY on the main menu first.",
	CardFavorite = "This card is a favourite. Unmark it to sell it.",
	SpareFavorite = "Favourite cards can't be used as spares. Unmark it first.",
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

-- The same errors as a pop (BAD_GUI_THINKING_AND_UI): 1-3 big words and an icon, shown beside the
-- button that was pressed.
local ERROR_POPS: { [string]: { text: string, icon: string? } } = {
	InsufficientFunds = { text = "NEED COINS", icon = "icon_coin" },
	StorageFull = { text = "STORAGE FULL", icon = "icon_cards" },
	CardStorageFull = { text = "STORAGE FULL", icon = "icon_cards" },
	InventoryFull = { text = "BAG FULL" },
	WorldLocked = { text = "LOCKED", icon = "icon_lock" },
	EggNotAvailable = { text = "NOT YET", icon = "icon_lock" },
	RateLimited = { text = "SLOW DOWN" },
	ProfileNotLoaded = { text = "LOADING..." },
	ServerError = { text = "TRY AGAIN" },
	NoDeck = { text = "BUILD A DECK", icon = "icon_deck" },
	AlreadyQueued = { text = "SEARCHING", icon = "icon_play" },
	AlreadyInMatch = { text = "IN A MATCH", icon = "icon_play" },
	TrialCooldown = { text = "WAIT A BIT" },
	TooFar = { text = "GET CLOSER" },
	NotReady = { text = "NOT READY" },
	NotNearMerchant = { text = "GET CLOSER", icon = "icon_coin" },
	AlreadyClaimed = { text = "CLAIMED", icon = "icon_check" },
	NotComplete = { text = "NOT DONE", icon = "icon_quests" },
	PaidRandomItemsRestricted = { text = "NOT AVAILABLE", icon = "icon_lock" },
	PolicyUnknown = { text = "NOT AVAILABLE", icon = "icon_lock" },
	QueueUnavailable = { text = "BUSY, RETRY" },
	EggBagFull = { text = "BAG FULL", icon = "icon_shop" },
	EggLocked = { text = "LOCKED", icon = "icon_lock" },
	AlreadyClaimedToday = { text = "BACK TOMORROW", icon = "icon_calendar" },
	ProductNotPublished = { text = "NOT ON SALE", icon = "icon_lock" },
	SpareNotBaseCopy = { text = "NOT A SPARE", icon = "icon_cards" },
	SpareInDeck = { text = "IN YOUR DECK", icon = "icon_deck" },
	CardInDeck = { text = "IN YOUR DECK", icon = "icon_deck" },
	NotPlaying = { text = "PRESS PLAY", icon = "icon_play" },
	CardFavorite = { text = "FAVOURITE" },
	SpareFavorite = { text = "FAVOURITE" },
	NoMaxedCopy = { text = "MAX ONE FIRST", icon = "icon_cards" },
	StorageAtMax = { text = "MAX STORAGE", icon = "icon_cards" },
	AlreadyMaxLevel = { text = "MAX LEVEL" },
	NoSpares = { text = "NO SPARES", icon = "icon_cards" },
	NotSoldForCoins = { text = "NOT FOR COINS", icon = "icon_coin" },
	NotInMatch = { text = "MATCH OVER" },
	TooLate = { text = "TOO LATE" },
	AlreadyPicked = { text = "PICKED", icon = "icon_check" },
	InQueue = { text = "LEAVE QUEUE FIRST" },
}

function Format.errorPop(code: string?): { text: string, icon: string? }
	local base = if code then string.split(code, ":")[1] else "ServerError"
	return ERROR_POPS[base] or { text = "TRY AGAIN" }
end

return Format
