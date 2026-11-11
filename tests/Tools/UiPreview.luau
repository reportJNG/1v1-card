--!strict
-- Studio-only preview harness (dev project): builds the real client App into StarterGui in EDIT
-- mode with a mid-game profile and a fake net, so any screen can be opened and screen-captured
-- without pressing Play. Used for the visual QA loop (docs/screens) and scripts/studio/ui-check.
--   local P = require(game.ServerScriptService.Tests.Tools.UiPreview)
--   P.show("Shop", { world = 1 })   -- or P.hatch(), P.battle(), P.result(), P.odds(), P.hud()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local Cards = require(Shared.Domain.Cards)
local Deck = require(Shared.Domain.Deck)
local ClientView = require(Shared.Domain.ClientView)
local Quests = require(Shared.Domain.Quests)
local Inventory = require(Shared.Domain.Inventory)
local Eggs = require(Shared.Config.Eggs)
local MatchRunner = require(ServerScriptService:WaitForChild("Server").Battle.MatchRunner)

local AppFolder = StarterPlayer.StarterPlayerScripts:WaitForChild("Client"):WaitForChild("App")
local App = require(AppFolder.App)
local Screens = AppFolder.Screens

local Preview = {}

Preview.NOW = os.time()

local LAUNCH = {
	"ren_emberfang",
	"yuki_frostveil",
	"rai_stormvolt",
	"vesper_shade",
	"aurelia_dawn",
	"brannok_ironhide",
	"taren_ashscale",
	"kael_voidbinder",
	"aurex_sunforge",
	"brann_cinderfall",
}

-- A mid-game profile: launch characters (some duplicates, one Golden, one Robux copy), a deck,
-- items, quests and eggs in the bag.
function Preview.profile(): (any, { string })
	local NOW = Preview.NOW
	local profile = ProfileSchema.new(1)
	profile.coins = 48_250
	profile.gems = 120
	profile.trophies = 760
	profile.highestTrophies = 760
	profile.currentWorld = 2
	for i, id in LAUNCH do
		for n = 1, if i <= 3 then 3 else 1 do
			local made = Cards.create(
				profile,
				id,
				if n == 3 then "Robux" else "Coins",
				`ref{i}{n}`,
				i == 2 and n == 1,
				NOW
			)
			assert(made.ok, "card")
		end
	end
	local uids = {}
	for uid in profile.cards do
		table.insert(uids, uid)
	end
	table.sort(uids)
	local deck = {}
	local seen = {}
	for _, uid in uids do
		local c = profile.cards[uid]
		if not seen[c.characterId] and #deck < 3 then
			seen[c.characterId] = true
			c.level = 6
			table.insert(deck, uid)
		end
	end
	assert(Deck.set(profile, deck).ok, "deck")
	Inventory.add(profile, "item_greenleaf", 34)
	Inventory.add(profile, "item_moonpetal", 12)
	Inventory.add(profile, "item_oak_log", 5)
	Inventory.add(profile, "item_meadow_crystal", 1)
	profile.eggBag.egg_basic = { normal = 2, golden = 1 }
	Quests.roll(profile, NOW)
	Quests.track(profile, "WinRanked", 1, NOW)
	Quests.track(profile, "Harvest", 12, NOW, 2)
	profile.daily.streakDay = 3
	profile.daily.lastClaimDay = NOW // 86400 - 1
	profile.trials["1"] = NOW
	return profile, deck
end

local state: { ctx: any, gui: ScreenGui, profile: any, deck: { string } }? = nil

-- Builds (or rebuilds) the App in StarterGui. `robux` drives the PaidRandomItemsAllowed attribute.
function Preview.app(robux: boolean?): (any, ScreenGui)
	local old = StarterGui:FindFirstChild("UiCheck")
	if old then
		old:Destroy()
	end
	local profile, deck = Preview.profile()
	local view = ClientView.build(profile)
	local gui = Instance.new("ScreenGui")
	gui.Name = "UiCheck"
	gui.Parent = StarterGui
	local handlers = {}
	local ctx = App.start({
		gui = gui,
		net = {
			request = function(name, _payload)
				if name == "Shop.BuyEgg" or name == "Bag.OpenEgg" then
					return { ok = true, value = { cards = { ClientView.card(profile.cards[deck[1]]) } } }
				end
				return { ok = true, value = {} }
			end,
			on = function(push, fn)
				handlers[push] = fn
			end,
		},
		attr = function(name)
			return if name == "PaidRandomItemsAllowed" then robux ~= false else nil
		end,
		now = function()
			return Preview.NOW
		end,
		guid = function()
			return "00000000-0000-0000-0000-000000000000"
		end,
		screens = {
			Play = require(Screens.Play) :: any,
			Cards = require(Screens.Cards) :: any,
			Inventory = require(Screens.Inventory) :: any,
			Deck = require(Screens.Deck) :: any,
			Shop = require(Screens.Shop) :: any,
			Worlds = require(Screens.Worlds) :: any,
			Quests = require(Screens.Quests) :: any,
			Settings = require(Screens.Settings) :: any,
			Merchant = require(Screens.Merchant) :: any,
		},
	})
	handlers["Profile.Snapshot"](view)
	state = { ctx = ctx, gui = gui, profile = profile, deck = deck }
	return ctx, gui
end

local function current(): (any, ScreenGui)
	if state == nil then
		return Preview.app(true)
	end
	local s = state :: any
	return s.ctx, s.gui
end

function Preview.hud()
	local ctx = Preview.app(true)
	ctx.close()
end

function Preview.show(name: string, arg: any?)
	local ctx = Preview.app(true)
	ctx.open(name, arg)
end

function Preview.odds()
	local ctx = Preview.app(true)
	require(Screens.OddsPopup).show(ctx, Eggs.ById.egg_basic, false)
end

function Preview.hatch(golden: boolean?)
	local ctx = Preview.app(true)
	local s = state :: any
	local c = ClientView.card(s.profile.cards[s.deck[2]])
	c.golden = golden == true
	require(Screens.Hatch).show(ctx, { c }, Eggs.ById.egg_basic, golden == true)
end

-- A real battle from MatchRunner: start and `rounds` resolved rounds, in `arena` (a Config/Arenas
-- id; default Sakura Courtyard). Returns the handle and runner.
function Preview.battle(rounds: number?, arena: string?): (any, any)
	local ctx = Preview.app(true)
	local s = state :: any
	local NOW = Preview.NOW
	local specs = {}
	for i, uid in s.deck do
		specs[i] = { characterId = s.profile.cards[uid].characterId, level = 6 }
	end
	local runner = MatchRunner.new({
		matchId = "ui",
		seed = 7,
		decks = {
			specs,
			{
				{ characterId = "vesper_shade", level = 6 },
				{ characterId = "aurelia_dawn", level = 6 },
				{ characterId = "brannok_ironhide", level = 6 },
			},
		},
		now = NOW,
	})
	local Battle = require(Screens.Battle)
	local first = runner:step(NOW)
	local b = Battle.open(ctx, {
		matchId = "ui",
		mode = "Ranked",
		arena = arena or "sakura",
		you = 1,
		seats = { { name = "You", trophies = 760 }, { name = "Kestrel_88", trophies = 790 } },
		view = runner:view(),
	})
	for _, m in first do
		b.round({ kind = m.kind, you = 1, data = m.data })
	end
	for r = 1, rounds or 4 do
		runner:pick(1, r, "Attack", NOW)
		runner:pick(2, r, if r % 2 == 0 then "Defend" else "Attack", NOW)
		for _, m in runner:step(NOW) do
			b.round({ kind = m.kind, you = 1, data = m.data })
		end
	end
	return b, runner
end

function Preview.result(win: boolean?)
	local b, runner = Preview.battle(4)
	b.finish({
		matchId = "ui",
		mode = "Ranked",
		you = 1,
		result = {
			winner = if win == false then 2 else 1,
			reason = "KO",
			rounds = 9,
			timeouts = { 0, 0 },
			endedByForfeit = false,
		},
		view = runner:view(),
		reward = {
			coins = if win == false then 60 else 220,
			trophyDelta = if win == false then -18 else 31,
			trophies = if win == false then 742 else 791,
			leagueBefore = "Silver",
			leagueAfter = "Silver",
			reward = "Full",
		},
	})
end

function Preview.clear()
	local old = StarterGui:FindFirstChild("UiCheck")
	if old then
		old:Destroy()
	end
	state = nil
end

Preview.current = current

return Preview
