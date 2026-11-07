--!strict
-- Content that exists so the systems can run and be tested, but is NOT final design data.
-- ConfigValidator reports every entry as a warning in development and an error in release mode,
-- so none of this can reach a live server unnoticed. Remove an entry only when the content is final.

return table.freeze({
	Placeholder = table.freeze({
		eggPools = "Egg pools are designed (themed, 8-10 characters each, every character in at least one egg) but await owner review and playtest.",
		oddsBands = "Band odds (A-E) are design-doc proposals, not balanced values.",
		eventOdds = "The Party Egg uses a stand-in Event band until event design.",
		eggPrices = "Egg coin prices are starting values pending the economy simulation.",
		economyPrices = "Card storage, item slot and merge prices are starting values.",
		characterNumbers = "All 100 characters pass sim/balance.py (47-53% win rate each), but numbers need real playtest tuning.",
		items = "Item names and merchant prices for all 10 worlds are starting values pending the economy simulation.",
		worldArt = "Worlds are a first art pass (generated terrain, generate_mesh props, code-drawn skies, picker thumbnails captured in Studio) awaiting the owner's review and a hero pass.",
		questRewards = "Quest targets and rewards are starting values.",
		characterArt = "Characters are procedural placeholder rigs in 3D (Shared/Art/RigBuilder) and TEMP role-silhouette cutouts on cards, tinted with each character's colours, until the owner's transparent card art (art/characters/<id>/card.png) and models exist.",
		cardFrames = "The layered card (App/Card) uses TEMP layers: one code-drawn frame tinted per rarity (card_border), 15 family backgrounds, glow, holo foil and badges, until final card art exists (art/ui/PROMPTS.md, Card layers).",
		hubArt = "The hub plaza uses generated meshes (Config/HubLayout) and a code-drawn sky; awaiting the owner's vertical-slice approval.",
		uiArt = "Every UI image is a TEMP stand-in drawn by scripts/art/make_temp_ui.py until the owner's final art (art/ui/PROMPTS.md) is uploaded.",
		guardianDecks = "Guardian decks come from each world's own eggs; the difficulty curve needs playtesting.",
	}) :: { [string]: string },
})
