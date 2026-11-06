--!strict
-- Rarity odds per band, in percent. Each band must total exactly 100 (checked by ConfigValidator).
-- Inside a rarity, each character in an egg's pool gets an equal share. If an egg's pool has no
-- character at some rarity, that share is redistributed proportionally (Domain/Odds).
-- Golden eggs remove Common and redistribute it proportionally (Domain/Odds); no separate table.
local Types = require(script.Parent.Parent.Types)

return table.freeze({
	A = table.freeze({ Common = 72, Rare = 24, Epic = 3.6, Legendary = 0.4, Mythical = 0 }),
	B = table.freeze({ Common = 58, Rare = 32, Epic = 8.5, Legendary = 1.4, Mythical = 0.1 }),
	C = table.freeze({ Common = 45, Rare = 36, Epic = 15, Legendary = 3.5, Mythical = 0.5 }),
	D = table.freeze({ Common = 32, Rare = 38, Epic = 22, Legendary = 6.8, Mythical = 1.2 }),
	E = table.freeze({ Common = 20, Rare = 38, Epic = 28, Legendary = 11, Mythical = 3 }),
	-- Starting values for event eggs; each event may override in its own config later.
	Event = table.freeze({ Common = 40, Rare = 36, Epic = 18, Legendary = 5, Mythical = 1 }),
}) :: { [string]: Types.RarityOdds }
