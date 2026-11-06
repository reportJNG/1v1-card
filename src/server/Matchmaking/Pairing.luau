--!strict
-- Pure pairing over queue tickets. Two tickets pair when they are in the same league (so both
-- decks play under the same level cap) and their trophies are within the search band. The band
-- starts at ±100 and widens by 50 every 10 seconds of waiting, up to ±400. The oldest ticket is
-- served first and gets the closest opponent available.
local Pairing = {}

Pairing.BAND_START = 100
Pairing.BAND_STEP = 50
Pairing.BAND_STEP_SECONDS = 10
Pairing.BAND_MAX = 400

export type Ticket = {
	userId: number,
	trophies: number,
	league: string,
	queuedAt: number,
}

function Pairing.band(waitSeconds: number): number
	local steps = math.max(0, waitSeconds) // Pairing.BAND_STEP_SECONDS
	return math.min(Pairing.BAND_MAX, Pairing.BAND_START + Pairing.BAND_STEP * steps)
end

local function older(a: Ticket, b: Ticket): boolean
	if a.queuedAt == b.queuedAt then
		return a.userId < b.userId
	end
	return a.queuedAt < b.queuedAt
end

function Pairing.pair(tickets: { Ticket }, now: number): { { Ticket } }
	local order = table.clone(tickets)
	table.sort(order, older)
	local used: { [number]: boolean } = {}
	local pairs: { { Ticket } } = {}
	for _, a in order do
		if used[a.userId] then
			continue
		end
		local best: Ticket? = nil
		local bestGap = math.huge
		for _, b in order do
			if b.userId == a.userId or used[b.userId] or b.league ~= a.league then
				continue
			end
			local gap = math.abs(a.trophies - b.trophies)
			local band = math.max(Pairing.band(now - a.queuedAt), Pairing.band(now - b.queuedAt))
			if gap <= band and gap < bestGap then
				best, bestGap = b, gap
			end
		end
		if best then
			used[a.userId] = true
			used[best.userId] = true
			table.insert(pairs, { a, best })
		end
	end
	return pairs
end

return table.freeze(Pairing)
