--!strict
-- Where a player is in the four-screen flow (MISSION section 2), as the server sees it:
--   menu      on the main menu: no character, no gameplay (menu panels still work)
--   playing   in the lobby or a world
--   battling  in a ranked match or a Guardian Trial
-- The server keeps this per player (Services/SessionService), exposes it as the player's "Session"
-- attribute, and every gameplay remote that needs a character checks it here. Pure.
local PlayState = {}

export type State = "menu" | "playing" | "battling"
export type Event = "play" | "leave" | "battleStart" | "battleEnd"

-- Actions that need the player to be playing (a character in the lobby or a world).
local NEEDS_PLAYING: { [string]: boolean } = {
	travel = true, -- World.Travel
	hub = true, -- World.Hub
	harvest = true, -- Farm.Harvest
	sell = true, -- Merchant.SellItem (the merchant stands in a world)
	queue = true, -- Queue.Join
	trial = true, -- Trial.Start
}

-- Whether `state` allows `action`. Unknown actions are allowed (menu panels: shop, deck, cards).
function PlayState.allows(state: State, action: string): boolean
	if NEEDS_PLAYING[action] then
		return state == "playing"
	end
	return true
end

-- The state after `event`. Events that don't apply leave it unchanged.
function PlayState.next(state: State, event: Event): State
	if event == "play" then
		return if state == "menu" then "playing" else state
	elseif event == "leave" then
		return "menu"
	elseif event == "battleStart" then
		return if state == "playing" then "battling" else state
	elseif event == "battleEnd" then
		return if state == "battling" then "playing" else state
	end
	return state
end

return table.freeze(PlayState)
