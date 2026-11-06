--!strict
-- A MemoryStore sorted map in server memory: SetAsync, GetAsync, RemoveAsync, UpdateAsync and
-- GetRangeAsync with expirations on an injected clock. It is the Studio-only fallback when
-- MemoryStore is unavailable (an unpublished place) and the mock the specs use; `failNext(n)`
-- makes the next n calls throw, like a throttled MemoryStore. A live server never uses it.
local InMemoryMap = {}
InMemoryMap.__index = InMemoryMap

InMemoryMap.Ascending = "Ascending"
InMemoryMap.Descending = "Descending"

type Entry = { value: any, sortKey: any, expires: number }

export type InMemoryMap = typeof(setmetatable(
	{} :: { _entries: { [string]: Entry }, _clock: { t: number }, _fail: number, calls: number },
	InMemoryMap
))

local function deepCopy(v: any): any
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

function InMemoryMap.new(clock: { t: number }): InMemoryMap
	return setmetatable({ _entries = {}, _clock = clock, _fail = 0, calls = 0 }, InMemoryMap)
end

function InMemoryMap.failNext(self: InMemoryMap, n: number)
	self._fail = n
end

local function enter(self: InMemoryMap)
	self.calls += 1
	if self._fail > 0 then
		self._fail -= 1
		error("MemoryStore request throttled")
	end
end

local function live(self: InMemoryMap, key: string): Entry?
	local e = self._entries[key]
	if e and e.expires <= self._clock.t then
		self._entries[key] = nil
		return nil
	end
	return e
end

function InMemoryMap.SetAsync(
	self: InMemoryMap,
	key: string,
	value: any,
	expiration: number,
	sortKey: any?
): boolean
	enter(self)
	self._entries[key] = { value = deepCopy(value), sortKey = sortKey, expires = self._clock.t + expiration }
	return true
end

function InMemoryMap.GetAsync(self: InMemoryMap, key: string): (any, any)
	enter(self)
	local e = live(self, key)
	if e == nil then
		return nil, nil
	end
	return deepCopy(e.value), e.sortKey
end

function InMemoryMap.RemoveAsync(self: InMemoryMap, key: string)
	enter(self)
	self._entries[key] = nil
end

function InMemoryMap.UpdateAsync(
	self: InMemoryMap,
	key: string,
	transform: (any, any) -> (any, any),
	expiration: number
): any
	enter(self)
	local e = live(self, key)
	local new, sortKey = transform(if e then deepCopy(e.value) else nil, if e then e.sortKey else nil)
	if new == nil then
		return nil
	end
	self._entries[key] = {
		value = deepCopy(new),
		sortKey = if sortKey ~= nil then sortKey elseif e then e.sortKey else nil,
		expires = self._clock.t + expiration,
	}
	return deepCopy(new)
end

function InMemoryMap.GetRangeAsync(self: InMemoryMap, direction: any, count: number): { any }
	enter(self)
	local rows = {}
	for key in self._entries do
		local e = live(self, key)
		if e then
			table.insert(rows, { key = key, value = deepCopy(e.value), sortKey = e.sortKey })
		end
	end
	table.sort(rows, function(a, b)
		local sa, sb = a.sortKey or 0, b.sortKey or 0
		if sa == sb then
			return a.key < b.key
		end
		if direction == InMemoryMap.Descending then
			return sa > sb
		end
		return sa < sb
	end)
	local out = {}
	for i = 1, math.min(count, #rows) do
		out[i] = rows[i]
	end
	return out
end

return InMemoryMap
