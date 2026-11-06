--!strict
-- A short leader lease on a MemoryStore key, so only one Hub server runs the matchmaker at a
-- time (two leaders could pair the same ticket twice). The holder renews it every tick; if the
-- holder dies, the lease runs out and another server takes over.
local Lease = {}

export type Store = {
	UpdateAsync: (self: any, key: string, transform: (old: any) -> any, expiration: number) -> any,
}

-- Returns true when `holder` holds the lease after this call.
function Lease.tryAcquire(store: Store, key: string, holder: string, now: number, ttl: number): boolean
	local ok, result = pcall(function()
		return store:UpdateAsync(key, function(old: any)
			if
				old == nil
				or typeof(old) ~= "table"
				or typeof(old.expires) ~= "number"
				or old.expires <= now
				or old.holder == holder
			then
				return { holder = holder, expires = now + ttl }
			end
			return nil -- someone else holds a live lease
		end, math.max(1, math.ceil(ttl * 2)))
	end)
	return ok and typeof(result) == "table" and result.holder == holder
end

return table.freeze(Lease)
