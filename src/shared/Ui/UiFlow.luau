--!strict
-- The client's UI state machine (POLISH_MISSION A), pure so it can be unit-tested headless. The
-- client App feeds it events and applies the view it derives (HUD mode, blur, input lock, camera).
-- It only decides presentation: every gameplay action still goes through the server's remotes.
--
--   Loading ──loaded──▶ MainMenu ──play──▶ Playing ◀──queueLeave── Queue
--                          ▲                  │ ──queueJoin──▶
--                          └──────menu────────┘
--   Over MainMenu / Playing / Queue:   Panel (one modal at a time; opening one replaces the other)
--   Full screen, over anything:        Hatching → back to what was under it
--                                       Battle → Result → Playing (the server puts the character
--                                       back where it stood before the battle)
--   leave (the Menu button's leaving screen): from anything but Loading → MainMenu, all cleared
-- `back` (Esc, gamepad B, the X button) closes the top layer: a panel, or skips the result screen.

export type Base = "Loading" | "MainMenu" | "Playing" | "Queue"
export type Top = "None" | "Panel" | "Hatching" | "Battle" | "Result"
export type State = "Loading" | "MainMenu" | "Playing" | "Queue" | "Panel" | "Hatching" | "Battle" | "Result"

export type View = {
	state: State,
	hud: "full" | "currencies" | "hidden", -- currencies: only the Coins/Gems/Trophies bar
	inputLocked: boolean, -- movement and camera input off
	blur: boolean,
	menuShot: boolean, -- the camera holds the main menu's cinematic shot
}

export type Flow = {
	base: Base,
	top: Top,
	panel: string?, -- the open panel's name while top == "Panel"
	resume: Top, -- what Hatching returns to (a panel stays open under a hatch)
	resumePanel: string?,
}

local UiFlow = {}

function UiFlow.new(): Flow
	return { base = "Loading", top = "None", panel = nil, resume = "None", resumePanel = nil }
end

function UiFlow.state(f: Flow): State
	if f.top ~= "None" then
		return f.top :: any
	end
	return f.base :: any
end

function UiFlow.view(f: Flow): View
	local s: State = UiFlow.state(f)
	local hud: "full" | "currencies" | "hidden" = "full"
	local locked, blur = false, false
	if s == "Loading" or s == "Hatching" or s == "Battle" or s == "Result" then
		hud = "hidden"
		locked = true
		blur = s == "Loading" -- the hatch runs its own focus blur
	elseif s == "MainMenu" then
		-- The main menu is its own screen (an opaque backdrop, not the lobby): no HUD, no world blur.
		hud = "hidden"
		locked = true
	elseif s == "Panel" then
		hud = "currencies"
		locked = true
		blur = true
	end
	return {
		state = s,
		hud = hud,
		inputLocked = locked,
		blur = blur,
		menuShot = f.base == "MainMenu" or f.base == "Loading",
	}
end

export type Event =
	"loaded"
	| "play"
	| "menu"
	| "open"
	| "close"
	| "back"
	| "hatchStart"
	| "hatchEnd"
	| "leave"
	| "queueJoin"
	| "queueLeave"
	| "battleStart"
	| "battleEnd"
	| "resultDone"

-- Applies an event. Returns true when the state changed; events that don't apply in the current
-- state are ignored (a double click, a late callback), so callers never need to guard them.
function UiFlow.send(f: Flow, event: Event, arg: string?): boolean
	local before = UiFlow.state(f)
	local beforePanel = f.panel
	if event == "loaded" then
		if f.base == "Loading" then
			f.base = "MainMenu"
		end
	elseif event == "play" then
		if f.base == "MainMenu" and f.top ~= "Hatching" and f.top ~= "Battle" and f.top ~= "Result" then
			f.base = "Playing"
			f.top = "None"
			f.panel = nil
		end
	elseif event == "menu" then
		if (f.base == "Playing" or f.base == "Queue") and (f.top == "None" or f.top == "Panel") then
			f.base = "MainMenu"
			f.top = "None"
			f.panel = nil
		end
	elseif event == "leave" then
		-- The leaving screen (MISSION 2.5): from anywhere but loading, back to the main menu with
		-- nothing left open (the server has forfeited any battle and cleared the queue).
		if f.base ~= "Loading" then
			f.base = "MainMenu"
			f.top = "None"
			f.panel = nil
			f.resume, f.resumePanel = "None", nil
		end
	elseif event == "open" then
		if arg and f.base ~= "Loading" and (f.top == "None" or f.top == "Panel") then
			f.top = "Panel"
			f.panel = arg
		end
	elseif event == "close" or event == "back" then
		if f.top == "Panel" then
			f.top = "None"
			f.panel = nil
		elseif f.top == "Result" then
			f.top = "None"
		end
	elseif event == "hatchStart" then
		if f.top == "None" or f.top == "Panel" then
			f.resume = f.top
			f.resumePanel = f.panel
			f.top = "Hatching"
		end
	elseif event == "hatchEnd" then
		if f.top == "Hatching" then
			f.top = f.resume
			f.panel = f.resumePanel
			f.resume, f.resumePanel = "None", nil
		end
	elseif event == "queueJoin" then
		if f.base == "Playing" then
			f.base = "Queue"
		end
	elseif event == "queueLeave" then
		if f.base == "Queue" then
			f.base = "Playing"
		end
	elseif event == "battleStart" then
		-- A battle pushed by the server always takes over (a panel or a hatch closes under it).
		f.top = "Battle"
		f.panel = nil
		f.resume, f.resumePanel = "None", nil
		if f.base == "Queue" or f.base == "Loading" or f.base == "MainMenu" then
			f.base = "Playing"
		end
	elseif event == "battleEnd" then
		if f.top == "Battle" then
			f.top = "Result"
		end
	elseif event == "resultDone" then
		if f.top == "Result" or f.top == "Battle" then
			f.top = "None"
		end
	end
	return UiFlow.state(f) ~= before or f.panel ~= beforePanel
end

return table.freeze(UiFlow)
