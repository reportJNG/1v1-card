--!strict
-- In-memory stand-in for a GlobalDataStore with failure injection.
--   failNext(n)          - the next n UpdateAsync calls error before writing
--   failAfterWrite(n)    - the next n UpdateAsync calls write, then error (a "failed" write that landed)
--   failGets(n)          - the next n GetAsync calls error
-- Values are deep-copied in and out, like a real store.
local MockDataStore = {}
MockDataStore.__index = MockDataStore

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

function MockDataStore.new(): any
	return setmetatable({
		data = {} :: { [string]: any },
		updateCalls = 0,
		_failNext = 0,
		_failAfterWrite = 0,
		_failGets = 0,
	}, MockDataStore)
end

function MockDataStore.failNext(self: any, n: number)
	self._failNext = n
end

function MockDataStore.failAfterWrite(self: any, n: number)
	self._failAfterWrite = n
end

function MockDataStore.failGets(self: any, n: number)
	self._failGets = n
end

function MockDataStore.UpdateAsync(self: any, key: string, transform: (any, any) -> any): any
	self.updateCalls += 1
	if self._failNext > 0 then
		self._failNext -= 1
		error("MockDataStore: simulated request failure")
	end
	local result = transform(deepCopy(self.data[key]), nil)
	if result ~= nil then
		self.data[key] = deepCopy(result)
	end
	if self._failAfterWrite > 0 then
		self._failAfterWrite -= 1
		error("MockDataStore: simulated failure after write")
	end
	return deepCopy(self.data[key])
end

function MockDataStore.GetAsync(self: any, key: string, _options: any?): any
	if self._failGets > 0 then
		self._failGets -= 1
		error("MockDataStore: simulated read failure")
	end
	return deepCopy(self.data[key])
end

-- Test helper: raw stored record.
function MockDataStore.peek(self: any, key: string): any
	return deepCopy(self.data[key])
end

-- Test helper: write a raw record (e.g. simulate another server's lock).
function MockDataStore.poke(self: any, key: string, value: any)
	self.data[key] = deepCopy(value)
end

return MockDataStore
