--!strict
-- Card actions shared by the Inventory inspect pane and the card stats panel (Screens/CardStats):
-- which copies are spares, the merge to the next level, equip into the deck, favourite. The client
-- only proposes: the server validates every request (Cards.Merge, Deck.Set, Cards.SetFavorite).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Power = require(Shared.Domain.Power)
local Ui = require(script.Parent.Ui)

local CardActions = {}

function CardActions.inDeck(view: any, uid: string): boolean
	return table.find(view.deck, uid) ~= nil
end

-- Level-1, never-merged spares of the same character, not in the deck, locked or favourite.
function CardActions.spares(view: any, target: any): { string }
	local out = {}
	for _, c in view.cards do
		if
			c.uid ~= target.uid
			and c.characterId == target.characterId
			and c.level == 1
			and c.mergePoints == 0
			and not c.locked
			and not c.favorite
			and not CardActions.inDeck(view, c.uid)
		then
			table.insert(out, c.uid)
		end
	end
	table.sort(out)
	return out
end

export type MergePlan = { use: { string }, fee: number, need: number }

-- The spares a merge toward the next level would use and its coin fee; nil at max level.
function CardActions.mergePlan(view: any, card: any): MergePlan?
	local need = Economy.Progression.mergePointsToNext[card.level]
	if need == nil then
		return nil
	end
	local def = Characters.ById[card.characterId]
	local per = Rarities.Defs[def.rarity].mergePoints
	local wanted = math.max(1, math.ceil((need - card.mergePoints) / per))
	local list = CardActions.spares(view, card)
	local use = {}
	for i = 1, math.min(wanted, #list) do
		use[i] = list[i]
	end
	return { use = use, fee = Economy.Progression.coinFeeToNext[card.level], need = need }
end

-- The deck with `card` equipped: it replaces the weakest card unless its character is already in
-- the deck, and an incomplete deck is filled with the strongest other characters owned. Nil when
-- there aren't 3 different characters yet. The server validates the result (Deck.Set).
function CardActions.equipped(view: any, card: any): { string }?
	local deck: { string } = {}
	local used: { [string]: boolean } = { [card.characterId] = true }
	for _, uid in view.deck do
		local other = view.cards[uid]
		if other and not used[other.characterId] then
			used[other.characterId] = true
			table.insert(deck, uid)
		end
	end
	if #deck >= 3 then
		local weakest, weakestPower = 1, math.huge
		for i, uid in deck do
			local other = view.cards[uid]
			local pw = Power.card(other.characterId, other.level)
			if pw < weakestPower then
				weakest, weakestPower = i, pw
			end
		end
		table.remove(deck, weakest)
	end
	table.insert(deck, 1, card.uid)
	if #deck < 3 then
		local pool = {}
		for _, c in view.cards do
			if not used[c.characterId] and not c.locked then
				table.insert(pool, c)
			end
		end
		table.sort(pool, function(a, b)
			return Power.card(a.characterId, a.level) > Power.card(b.characterId, b.level)
		end)
		for _, c in pool do
			if #deck >= 3 then
				break
			end
			if not used[c.characterId] then
				used[c.characterId] = true
				table.insert(deck, c.uid)
			end
		end
	end
	return if #deck == 3 then deck else nil
end

-- Merges toward the next level. Returns the server's plan on success (fromLevel, toLevel).
function CardActions.merge(ctx: any, card: any): any?
	local plan = CardActions.mergePlan(ctx.state.view, card)
	if plan == nil or #plan.use == 0 then
		return nil
	end
	local reply =
		ctx.request("Cards.Merge", { targetUid = card.uid, spareUids = plan.use, requestId = ctx.guid() })
	if not reply.ok then
		return nil
	end
	Ui.sound("merge")
	local def = Characters.ById[card.characterId]
	if reply.value.toLevel > card.level then
		task.delay(0.4, Ui.sound, "level_up")
		ctx.toast(`{def.displayName} is now level {reply.value.toLevel}!`, "good")
	else
		ctx.toast(`{def.displayName} gained merge points.`, "good")
	end
	return reply.value
end

function CardActions.equip(ctx: any, card: any): boolean
	local deck = CardActions.equipped(ctx.state.view, card)
	if deck == nil then
		ctx.toast("A deck needs 3 different characters: hatch more eggs first.", "error")
		return false
	end
	local reply = ctx.request("Deck.Set", { uids = deck })
	if reply.ok then
		Ui.sound("card_flip")
		ctx.toast(`{Characters.ById[card.characterId].displayName} is in your deck.`, "good")
	end
	return reply.ok
end

function CardActions.setFavorite(ctx: any, card: any, on: boolean): boolean
	local reply = ctx.request("Cards.SetFavorite", { uid = card.uid, on = on })
	if reply.ok then
		Ui.sound(if on then "purchase" else "tick")
	end
	return reply.ok
end

return table.freeze(CardActions)
