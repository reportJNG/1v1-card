--!strict
-- The characters in play right now ("5-card mode", PLAN.md section 5). Eggs drop only these
-- (Shared/Domain/Odds), the starter deck and the Guardians use only these. The other characters
-- stay in Config/Characters, inactive: nothing is deleted and every card a player already owns
-- stays owned and usable. Turning a character on is adding its id here, after its art is approved.
-- One per rarity so the hatch shows variety (PLAN.md section 5).

return table.freeze({
	active = table.freeze({
		"rai_stormvolt", -- Common
		"ren_emberfang", -- Rare
		"yuki_frostveil", -- Epic
		"vesper_shade", -- Legendary
		"aurelia_dawn", -- Mythical
	}) :: { string },
})
