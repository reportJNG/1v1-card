--!strict
-- V2 player store (Q11/Q12). Configuration only: no V1 code reads `enabled = true`.
-- Card copies already carry what the store needs (uid, provenance, lockedBy).

return table.freeze({
	enabled = false,
	currency = "coins",
	feeRate = 0.10, -- fraction of the sale price removed from the economy
	maxActiveListingsPerPlayer = 1,
})
