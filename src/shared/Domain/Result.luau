--!strict
-- Small helpers for the Result<T> type used by every domain operation.
local Types = require(script.Parent.Parent.Types)

local Result = {}

function Result.ok<T>(value: T): Types.Result<T>
	return { ok = true, value = value }
end

function Result.fail<T>(err: string): Types.Result<T>
	return { ok = false, err = err }
end

return table.freeze(Result)
