--!strict
-- Token buckets per (player, remote). Pure: the clock is passed in.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, at: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { _buckets: { [any]: { [string]: Bucket } } },
	RateLimiter
))

function RateLimiter.new(): RateLimiter
	return setmetatable({ _buckets = {} }, RateLimiter)
end

function RateLimiter.allow(
	self: RateLimiter,
	who: any,
	name: string,
	rate: number,
	burst: number,
	now: number
): boolean
	local mine = self._buckets[who]
	if mine == nil then
		mine = {}
		self._buckets[who] = mine
	end
	local b = mine[name]
	if b == nil then
		b = { tokens = burst, at = now }
		mine[name] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.at) * rate)
	b.at = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, who: any)
	self._buckets[who] = nil
end

return RateLimiter
