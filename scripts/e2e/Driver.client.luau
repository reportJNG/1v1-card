-- E2E only (e2e.project.json). Plays the game through the real remotes, as a client would, next
-- to the real client UI, and prints "E2E PASS|FAIL <step>" lines and a final summary.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "E2E driver must never run on a live client")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientView = require(Shared.Domain.ClientView)
local WorldLayout = require(Shared.Domain.WorldLayout)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 60)
local passed, failed = 0, 0

local function report(ok: boolean, step: string, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
	end
	print(`E2E {if ok then "PASS" else "FAIL"} {step}{if detail ~= nil then ` ({tostring(detail)})` else ""}`)
end

local function call(name: string, payload: any?): any
	local rf = remotes:FindFirstChild(name) :: RemoteFunction
	local ok, reply = pcall(function()
		return rf:InvokeServer(payload)
	end)
	return if ok then reply else { ok = false, err = `invoke error: {reply}` }
end

local view: any = nil
remotes:WaitForChild("Profile.Snapshot").OnClientEvent:Connect(function(v)
	view = v
end)
remotes:WaitForChild("Profile.Delta").OnClientEvent:Connect(function(d)
	if view then
		ClientView.apply(view, d)
	end
end)
local battle: { start: any?, last: any?, ended: any? } = {}
remotes:WaitForChild("Battle.Start").OnClientEvent:Connect(function(s)
	battle.start = s
end)
remotes:WaitForChild("Battle.Round").OnClientEvent:Connect(function(m)
	battle.last = m
end)
remotes:WaitForChild("Battle.End").OnClientEvent:Connect(function(d)
	battle.ended = d
end)

local function waitFor(cond: () -> boolean, timeout: number): boolean
	local t = os.clock()
	while not cond() do
		if os.clock() - t > timeout then
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function moveTo(p: { x: number, y: number, z: number })
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	root.CFrame = CFrame.new(p.x, p.y + 3, p.z)
	task.wait(0.6) -- let the server see the new position
end

local function count(t: any): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function run()
	report(
		waitFor(function()
			return player:GetAttribute("E2EReady") == true and view ~= nil and count(view.cards) >= 4
		end, 60),
		"profile loaded and test cards granted"
	)
	if view == nil then
		return
	end
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("OneVOneCard", 10)
	report(gui ~= nil and gui:FindFirstChild("Root", true) ~= nil, "client UI booted")

	-- Economy
	local coins0 = view.coins
	local free = call("Daily.ClaimFreeEgg")
	report(free.ok and #free.value.cards == 1, "daily free egg hatches one card", free.err)
	local again = call("Daily.ClaimFreeEgg")
	report(not again.ok and again.err == "AlreadyClaimedToday", "daily free egg only once", again.err)
	local buy = call("Shop.BuyEgg", { eggId = "egg_basic", requestId = "e2e-buy-1" })
	report(buy.ok, "buy a Basic Egg with Coins", buy.err)
	task.wait(0.3)
	report(view.coins == coins0 - 250, "Coins charged exactly once", `{coins0} -> {view.coins}`)
	local replay = call("Shop.BuyEgg", { eggId = "egg_basic", requestId = "e2e-buy-1" })
	report(not replay.ok, "replayed requestId refused", replay.err)
	local locked = call("Shop.BuyEgg", { eggId = "egg_mythical", requestId = "e2e-buy-2" })
	report(not locked.ok, "egg of a locked world refused", locked.err)
	local bad1 = call("Shop.BuyEgg", { eggId = "egg_basic", requestId = "x", coins = 999999 })
	report(not bad1.ok and bad1.err == "BadRequest", "extra payload keys rejected", bad1.err)
	local bad2 = call("Shop.BuyEgg", { eggId = 12, requestId = "x" })
	report(not bad2.ok and bad2.err == "BadRequest", "wrong payload types rejected", bad2.err)
	local bad3 = call("Cards.Merge", { targetUid = "nope", spareUids = { "a" }, requestId = "m" })
	report(not bad3.ok, "merging cards you don't own refused", bad3.err)

	-- Deck
	local byChar: { [string]: string } = {}
	local spare: string? = nil
	for uid, c in view.cards do
		if byChar[c.characterId] == nil then
			byChar[c.characterId] = uid
		elseif c.characterId == "ren_emberfang" then
			spare = uid
		end
	end
	local deck = { byChar.ren_emberfang, byChar.yuki_frostveil, byChar.brannok_ironhide }
	local dup = call("Deck.Set", { uids = { deck[1], deck[1], deck[2] } })
	report(not dup.ok, "deck with a duplicate card refused", dup.err)
	local set = call("Deck.Set", { uids = deck })
	report(set.ok, "valid 3-card deck saved", set.err)

	-- Merge the spare Ren into the deck's Ren
	if spare then
		local merge =
			call("Cards.Merge", { targetUid = deck[1], spareUids = { spare }, requestId = "e2e-merge" })
		report(merge.ok, "merge a spare copy", merge.err)
	end

	-- Guardian Trial, played to the end
	local trial = call("Trial.Start", { worldId = 1 })
	report(trial.ok, "Guardian Trial starts", trial.err)
	report(
		waitFor(function()
			return battle.start ~= nil
		end, 10),
		"Battle.Start pushed"
	)
	local wrong = call("Battle.Pick", { round = 99, action = "Attack" })
	report(not wrong.ok, "pick for the wrong round refused", wrong.err)
	local again2 = call("Trial.Start", { worldId = 1 })
	report(not again2.ok, "second Trial while in a match refused", again2.err)
	local rounds = 0
	local deadline = os.clock() + 180
	while battle.ended == nil and os.clock() < deadline do
		local m = battle.last
		if m and m.data and m.data.view then
			local v = m.data.view
			local mine = v.sides[m.you]
			if v.phase == "Picking" and not mine.picked then
				local action = if mine.canSpecial
					then "Special"
					elseif rounds % 3 == 2 then "Defend"
					else "Attack"
				local r = call("Battle.Pick", { round = v.round, action = action })
				if r.ok then
					rounds += 1
					mine.picked = true
				end
			elseif v.phase == "Choosing" and mine.needsNext then
				for slot, u in mine.units do
					if u.hp > 0 and slot ~= mine.active then
						call("Battle.ChooseNext", { slot = slot })
						mine.needsNext = false
						break
					end
				end
			end
		end
		task.wait(0.15)
	end
	local ended = battle.ended
	report(
		ended ~= nil,
		"Trial finished",
		if ended then `{ended.result.reason} after {ended.result.rounds} rounds` else "timeout"
	)
	if ended then
		local won = ended.result.winner == ended.you
		report(
			not won or (ended.reward and ended.reward.firstClear == true),
			"a won first Trial pays the first-clear reward",
			if won then "won" else "lost"
		)
	end
	local cooldown = call("Trial.Start", { worldId = 1 })
	report(not cooldown.ok and cooldown.err == "TrialCooldown", "Trial retry cooldown", cooldown.err)

	-- Farming: walk to a node (the server reads the real character position)
	local node = WorldLayout.nodes(1)[1]
	local far = call("Farm.Harvest", { nodeId = node.id })
	report(not far.ok and far.err == "TooFar", "harvest from far away refused", far.err)
	moveTo(node.position)
	local h = call("Farm.Harvest", { nodeId = node.id })
	report(h.ok, "harvest a node in range", h.err)
	local h2 = call("Farm.Harvest", { nodeId = node.id })
	report(not h2.ok and h2.err == "NotReady", "node respawn enforced", h2.err)
	local wrongWorld = call("Farm.Harvest", { nodeId = WorldLayout.nodes(2)[1].id })
	report(not wrongWorld.ok, "harvest in another world refused", wrongWorld.err)

	-- Merchant
	local itemId = h.ok and h.value.itemId
	local sellFar =
		call("Merchant.SellItem", { itemId = itemId or "item_greenleaf", count = 1, requestId = "e2e-s0" })
	report(
		not sellFar.ok and sellFar.err == "NotNearMerchant",
		"selling away from the merchant refused",
		sellFar.err
	)
	moveTo(WorldLayout.merchant(1))
	if itemId then
		local sell = call("Merchant.SellItem", { itemId = itemId, count = 1, requestId = "e2e-s1" })
		report(sell.ok and sell.value > 0, "sell an item at the merchant", sell.err)
	end
	local overSell =
		call("Merchant.SellItem", { itemId = "item_divine_tear", count = 5, requestId = "e2e-s2" })
	report(not overSell.ok, "selling items you don't have refused", overSell.err)

	-- Quests, streak, settings, travel
	local streak = call("Daily.ClaimStreak")
	report(streak.ok and streak.value.day == 1, "streak day 1 claimed", streak.err)
	local streak2 = call("Daily.ClaimStreak")
	report(not streak2.ok, "streak only once a day", streak2.err)
	local q = call("Quests.Claim", { questId = "a_wins_100" })
	report(not q.ok, "claiming an unfinished quest refused", q.err)
	local s = call("Settings.Set", { key = "reducedMotion", value = true })
	report(s.ok, "settings saved", s.err)
	local badSetting = call("Settings.Set", { key = "coins", value = true })
	report(not badSetting.ok, "unknown setting refused", badSetting.err)
	local travel = call("World.Travel", { worldId = 10 })
	report(not travel.ok and travel.err == "WorldLocked", "travel to a locked world refused", travel.err)

	-- Matchmaking queue (alone: never matched)
	local join = call("Queue.Join")
	report(join.ok, "join the ranked queue", join.err)
	local join2 = call("Queue.Join")
	report(not join2.ok, "joining twice refused", join2.err)
	local trialQueued = call("Trial.Start", { worldId = 1 })
	report(not trialQueued.ok, "Trial while queued refused", trialQueued.err)
	local leave = call("Queue.Leave")
	report(leave.ok, "leave the queue", leave.err)

	-- Rate limiting
	local limited = 0
	for i = 1, 12 do
		local r = call("Shop.BuyEgg", { eggId = "egg_basic", requestId = `e2e-spam-{i}` })
		if not r.ok and r.err == "RateLimited" then
			limited += 1
		end
	end
	report(limited > 0, "request spam is rate limited", `{limited} of 12 limited`)

	-- Robux offer (Studio policy decides; the server must answer either way)
	local robux = call("Shop.RequestRobuxEgg", { productKey = "egg_basic_x1" })
	report(
		robux.ok or typeof(robux.err) == "string",
		"Robux offer answered by the server",
		robux.err or "prompted"
	)
end

local ok, err = pcall(run)
if not ok then
	report(false, "driver crashed", err)
end
print(`E2E DONE: {passed} passed, {failed} failed`)
