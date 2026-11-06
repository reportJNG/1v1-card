--!strict
-- Content that exists so the systems can run and be tested, but is NOT final design data.
-- ConfigValidator reports every entry as a warning in development and an error in release mode,
-- so none of this can reach a live server unnoticed. Remove an entry only when the content is final.

return table.freeze({
	Placeholder = table.freeze({
		eggPools = "All 24 eggs share the 7 launch characters until the 100-character roster and egg-specific pools are designed.",
		oddsBands = "Band odds (A-E) are design-doc proposals, not balanced values.",
		eventOdds = "The Party Egg uses a stand-in Event band until event design.",
		eggPrices = "Egg coin prices are starting values pending the economy simulation.",
		economyPrices = "Card storage, item slot and merge prices are starting values.",
		characterNumbers = "Character stats and abilities come from the reference simulation and need playtest tuning.",
		items = "Item names and merchant prices for all 10 worlds are starting values pending the economy simulation.",
		worldArt = "Worlds are data-driven blockouts (flat ground, node and NPC markers) until world art exists.",
		questRewards = "Quest targets and rewards are starting values.",
		guardianDecks = "Guardian Trial decks use the launch characters until the full roster exists.",
	}) :: { [string]: string },
})
