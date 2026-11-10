-- Run by run-in-roblox (edit mode): builds every client screen inside real Studio with a real
-- profile view (ProfileSchema + Cards + ClientView) and real battle states (MatchRunner), so
-- engine-level mistakes (bad property names, bad enums, runtime errors) show up. Each screen is
-- shown in the viewport for HOLD seconds (StarterGui renders in edit mode) for screenshots.
-- Also checks the Robux egg button follows the PaidRandomItemsAllowed attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local HOLD = tonumber(workspace:GetAttribute("UiCheckHold")) or 4

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
local Battle = require(Screens.Battle)
local Hatch = require(Screens.Hatch)
local OddsPopup = require(Screens.OddsPopup)

local NOW = os.time()

-- A mid-game profile: cards of every character, a deck, items, quests, some eggs in the bag.
local profile = ProfileSchema.new(1)
profile.coins = 48_250
profile.gems = 120
profile.trophies = 760
profile.highestTrophies = 760
profile.currentWorld = 2
for i, id in
	{
		"ren_emberfang",
		"yuki_frostveil",
		"rai_stormvolt",
		"vesper_shade",
		"aurelia_dawn",
		"brannok_ironhide",
		"taren_ashscale",
	}
do
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
profile.eggBag.egg_basic = { normal = 2, golden = 1 }
Quests.roll(profile, NOW)
Quests.track(profile, "WinRanked", 1, NOW)
Quests.track(profile, "Harvest", 12, NOW, 2)
profile.daily.streakDay = 3
profile.daily.lastClaimDay = NOW // 86400 - 1
profile.trials["1"] = NOW
local view = ClientView.build(profile)

local failures = 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print(`UI OK {name}`)
	else
		failures += 1
		print(`UI FAIL {name}: {err}`)
	end
end

local function overflow(root: Instance): { string }
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and not d.TextFits and d.Text ~= "" then
			table.insert(out, `{d:GetFullName():sub(-60)} "{d.Text:sub(1, 40)}"`)
		end
	end
	return out
end

local function makeApp(robux: boolean)
	local old = StarterGui:FindFirstChild("UiCheck")
	if old then
		old:Destroy()
	end
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
			return if name == "PaidRandomItemsAllowed" then robux else nil
		end,
		now = function()
			return NOW
		end,
		guid = function()
			return "00000000-0000-0000-0000-000000000000"
		end,
		screens = {
			Play = require(Screens.Play) :: any,
			Collection = require(Screens.Collection) :: any,
			Deck = require(Screens.Deck) :: any,
			Shop = require(Screens.Shop) :: any,
			Worlds = require(Screens.Worlds) :: any,
			Quests = require(Screens.Quests) :: any,
			Settings = require(Screens.Settings) :: any,
			Merchant = require(Screens.Merchant) :: any,
		},
	})
	handlers["Profile.Snapshot"](view)
	task.wait(0.2)
	return ctx, gui
end

local function hold(gui: Instance, name: string)
	task.wait(0.4)
	local o = overflow(gui)
	if #o > 0 then
		print(`UI TEXT-OVERFLOW {name}: {#o} label(s): {table.concat(o, " | ", 1, math.min(#o, 6))}`)
	end
	print(`UI SHOW {name}`)
	task.wait(HOLD)
end

local function countNamed(root: Instance, prefix: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

-- Robux button follows the attribute (World 1 egg tab, Basic Egg selected).
check("robux button hidden when PaidRandomItemsAllowed=false", function()
	local ctx, gui = makeApp(false)
	ctx.open("Shop", { world = 1 })
	assert(countNamed(gui, "Robux") == 0, "Robux button shown to a restricted player")
	assert(countNamed(gui, "Odds") >= 1, "no Odds button")
	assert(countNamed(gui, "BuyCoins") == 1, "no Coin buy button")
end)
check("robux button shown when PaidRandomItemsAllowed=true", function()
	local ctx, gui = makeApp(true)
	ctx.open("Shop", { world = 1 })
	assert(countNamed(gui, "Robux") >= 1, "Robux button missing for an eligible player")
end)

local ctx, gui = makeApp(true)
for _, name in { "Shop", "Collection", "Deck", "Play", "Worlds", "Quests", "Settings", "Merchant" } do
	check(name, function()
		ctx.open(name, if name == "Shop" then { world = 1 } else nil)
	end)
	hold(gui, name)
end
ctx.close()

check("Odds", function()
	OddsPopup.show(ctx, Eggs.ById.egg_basic, false)
end)
hold(gui, "Odds")

check("Hatch (golden)", function()
	local c = ClientView.card(profile.cards[deck[2]])
	c.golden = true
	Hatch.show(ctx, { c }, Eggs.ById.egg_basic, true)
end)
task.wait(2)
hold(gui, "Hatch")

-- A real battle from MatchRunner: start, a few resolved rounds, a KO choice, then the end.
check("Battle", function()
	local specs = {}
	for i, uid in deck do
		specs[i] = { characterId = profile.cards[uid].characterId, level = 6 }
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
	local first = runner:step(NOW)
	local b = Battle.open(ctx, {
		matchId = "ui",
		mode = "Ranked",
		arena = "sakura",
		you = 1,
		seats = { { name = "You", trophies = 760 }, { name = "Kestrel_88", trophies = 790 } },
		view = runner:view(),
	})
	for _, m in first do
		b.round({ kind = m.kind, you = 1, data = m.data })
	end
	for r = 1, 4 do
		runner:pick(1, r, "Attack", NOW)
		runner:pick(2, r, if r % 2 == 0 then "Defend" else "Attack", NOW)
		for _, m in runner:step(NOW) do
			b.round({ kind = m.kind, you = 1, data = m.data })
		end
	end
	hold(gui, "Battle")
	b.finish({
		matchId = "ui",
		mode = "Ranked",
		you = 1,
		result = { winner = 1, reason = "KO", rounds = 9, timeouts = { 0, 0 }, endedByForfeit = false },
		view = runner:view(),
		reward = {
			coins = 220,
			trophyDelta = 31,
			trophies = 791,
			leagueBefore = "Silver",
			leagueAfter = "Silver",
			reward = "Full",
		},
	})
end)
hold(gui, "Result")

-- Characters in 3D: every character's standee builds in the real engine, two parts (the art
-- panel and its base, never a stack of primitives) with the art on both faces, marked TEMP while
-- the character has no card art.
local Characters = require(Shared.Config.Characters)
local Standee = require(Shared.Art.Standee)
check("standees for all 100 characters", function()
	local layers = 0
	for _, def in Characters.List do
		local standee = Standee.build(def.id)
		local parts = 0
		for _, d in standee:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("ImageLabel") then
				layers += 1
			end
		end
		assert(parts == 2, `{def.id}: {parts} parts`)
		assert(standee:GetAttribute("Placeholder") == (def.assets.cardArt == nil), `{def.id} TEMP mark`)
		standee:Destroy()
	end
	print(`UI STANDEES {#Characters.List} standees, {layers} art layers`)
end)

check("art gallery", function()
	ctx.close()
	local Visuals = require(AppFolder.Visuals)
	local Ui = require(AppFolder.Ui)
	local root = gui:FindFirstChild("Root", true) :: Frame
	local gallery = Ui.frame(
		{ Name = "Gallery", BackgroundColor3 = Color3.fromHex("#080B18"), Parent = root.Overlays },
		{
			Ui.pad(12),
			Ui.grid(Vector2.new(150, 200), 10),
		}
	)
	local picks = {}
	local seenRole, seenRarity = {}, {}
	for _, def in Characters.List do
		if
			not seenRole[def.role .. def.rarity] and (not seenRole[def.role] or not seenRarity[def.rarity])
		then
			seenRole[def.role] = true
			seenRarity[def.rarity] = true
			seenRole[def.role .. def.rarity] = true
			table.insert(picks, def)
		end
		if #picks >= 10 then
			break
		end
	end
	for i, def in picks do
		Visuals.portrait(gallery, def.id, i == 10, Vector2.new(150, 200), true).LayoutOrder = i
	end
end)
hold(gui, "Gallery")

print(`UI CHECK DONE: {failures} failure(s)`)
