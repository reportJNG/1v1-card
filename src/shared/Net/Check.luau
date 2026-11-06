--!strict
-- Payload validators for client requests. Every remote payload passes through one of these on
-- the server before any handler sees it. They return the cleaned value or nil.
local Check = {}

local ID_PATTERN = "^[%w_%-:%.]+$"

function Check.id(v: unknown, maxLen: number?): string?
	if typeof(v) ~= "string" then
		return nil
	end
	local s = v :: string
	if #s == 0 or #s > (maxLen or 64) or string.match(s, ID_PATTERN) == nil then
		return nil
	end
	return s
end

function Check.int(v: unknown, min: number, max: number): number?
	if typeof(v) ~= "number" then
		return nil
	end
	local n = v :: number
	if n ~= n or n ~= math.floor(n) or n < min or n > max then
		return nil
	end
	return n
end

function Check.bool(v: unknown): boolean?
	if typeof(v) ~= "boolean" then
		return nil
	end
	return v :: boolean
end

-- An array of ids, 1..maxCount long, no holes, no duplicates.
function Check.idList(v: unknown, maxCount: number): { string }?
	if typeof(v) ~= "table" then
		return nil
	end
	local t = v :: { [any]: any }
	local n = #t
	if n == 0 or n > maxCount then
		return nil
	end
	local count = 0
	for _ in t do
		count += 1
	end
	if count ~= n then
		return nil
	end
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for i = 1, n do
		local id = Check.id(t[i])
		if id == nil or seen[id] then
			return nil
		end
		seen[id] = true
		out[i] = id
	end
	return out
end

-- A table payload with only the given keys.
function Check.shape(v: unknown, keys: { string }): { [string]: any }?
	if typeof(v) ~= "table" then
		return nil
	end
	local t = v :: { [any]: any }
	for k in t do
		if typeof(k) ~= "string" or not table.find(keys, k) then
			return nil
		end
	end
	return t
end

return table.freeze(Check)
