--!strict
-- A minimal signal: connect returns a disconnect function.
local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable({} :: { _handlers: { (T...) -> () } }, Signal))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.connect<T...>(self: Signal<T...>, fn: (T...) -> ()): () -> ()
	table.insert(self._handlers, fn)
	return function()
		local i = table.find(self._handlers, fn)
		if i then
			table.remove(self._handlers, i)
		end
	end
end

function Signal.fire<T...>(self: Signal<T...>, ...: T...)
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

return Signal
