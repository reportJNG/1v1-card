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
		worldArt = "Worlds are data-driven blockouts (flat ground, node and NPC markers) until world art exists.",
		questRewards = "Quest targets and rewards are starting values.",
		characterArt = "Characters are procedural placeholder rigs (Shared/Art/RigBuilder); hero-quality models and card art need a 3D artist.",
		cardFrames = "Rarity card frames are TEMP stand-in images (Config/UiAssets card_frame_*) until final frame art exists.",
		uiArt = "Every UI image is a TEMP stand-in drawn by scripts/art/make_temp_ui.py until the owner's final art (art/ui/PROMPTS.md) is uploaded.",
		guardianDecks = "Guardian decks come from each world's own eggs; the difficulty curve needs playtesting.",
	}) :: { [string]: string },
})
