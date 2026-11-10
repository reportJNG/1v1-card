--!strict
-- Who leaves a finished battle, and whether they won. Every human seat goes back to their saved
-- spot (SessionService) and out of the "battling" state, whatever settlement did: a missing
-- profile or a refused settlement once left a player stuck in the arena (MASTER_FIX_PLAN Phase 1).
-- Pure: BattleService runs its end hooks for each entry after settling.
local MatchHost = require(script.Parent.MatchHost)
local MatchRunner = require(script.Parent.MatchRunner)

local BattleEnd = {}

export type Leaver = { userId: number, side: number, won: boolean }

function BattleEnd.leavers(record: MatchHost.Record, result: MatchRunner.EndInfo): { Leaver }
	local out: { Leaver } = {}
	for side, seat in record.seats do
		if seat.userId ~= nil then
			table.insert(out, { userId = seat.userId :: number, side = side, won = result.winner == side })
		end
	end
	return out
end

return table.freeze(BattleEnd)
