--!strict
-- Studio-only stand-in used when DataStore access is unavailable (API access off, or an
-- unpublished place). Data lives only for this play session. PlayerDataService refuses to use
-- it on a live server.
local InMemoryDataStore = {}
InMemoryDataStore.__index = InMemoryDataStore

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

function InMemoryDataStore.new(): any
	return setmetatable({ _data = {} :: { [string]: any } }, InMemoryDataStore)
end

function InMemoryDataStore.UpdateAsync(self: any, key: string, transform: (any, any) -> any): any
	local result = transform(deepCopy(self._data[key]), nil)
	if result ~= nil then
		self._data[key] = deepCopy(result)
	end
	return deepCopy(self._data[key])
end

function InMemoryDataStore.GetAsync(self: any, key: string, _options: any?): any
	return deepCopy(self._data[key])
end

return InMemoryDataStore
