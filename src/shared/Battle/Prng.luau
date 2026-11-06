--!strict
-- Park-Miller "minimal standard" generator. Every product stays below 2^53, so it is exact in
-- doubles and gives the same stream in Luau and in the Python reference model (sim/engine.py).
-- Battles use it instead of Random so a match can be replayed and checked from its seed.
local M = 2147483647

local Prng = {}
Prng.__index = Prng

export type Prng = typeof(setmetatable({} :: { s: number }, Prng))

function Prng.new(seed: number): Prng
	local s = math.floor(seed) % M
	if s <= 0 then
		s += M - 1
	end
	return setmetatable({ s = s }, Prng)
end

function Prng.next(self: Prng): number
	self.s = (self.s * 48271) % M
	return self.s / M
end

function Prng.uniform(self: Prng, a: number, b: number): number
	return a + (b - a) * self:next()
end

return Prng
