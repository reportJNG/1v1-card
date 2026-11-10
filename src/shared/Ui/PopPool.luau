--!strict
-- Bookkeeping for pooled world/screen pops (BAD_GUI_THINKING_AND_UI section 4): pops are reused,
-- never created and destroyed each time, and at most `cap` are active at once; asking for one more
-- recycles the oldest active pop. Pure (the caller makes and shows the instances), so it is tested
-- headlessly.
local PopPool = {}
PopPool.__index = PopPool

export type Pool<T> = typeof(setmetatable(
	{} :: {
		cap: number,
		make: () -> T,
		free: { T },
		active: { T }, -- oldest first
		made: number,
		uses: { [any]: number }, -- item -> how many times it was handed out (its current use)
	},
	PopPool
))

function PopPool.new<T>(cap: number, make: () -> T): Pool<T>
	assert(cap >= 1, "PopPool cap must be at least 1")
	return setmetatable({ cap = cap, make = make, free = {}, active = {}, made = 0, uses = {} }, PopPool)
end

-- An item to show now, the item that was recycled to make room (the caller cancels its
-- animation), if any, and this use's token for `release`.
function PopPool.acquire<T>(self: Pool<T>): (T, T?, number)
	local recycled: T? = nil
	local item: T
	if #self.active >= self.cap then
		item = table.remove(self.active, 1) :: T
		recycled = item
	elseif #self.free > 0 then
		item = table.remove(self.free) :: T
	else
		item = self.make()
		self.made += 1
	end
	table.insert(self.active, item)
	local use = (self.uses[item] or 0) + 1
	self.uses[item] = use
	return item, recycled, use
end

-- Gives an item back once its animation ends. `use` is the token from acquire: the animation of
-- a pop that was recycled since then ends late, and must not free the pop's new use.
function PopPool.release<T>(self: Pool<T>, item: T, use: number)
	if self.uses[item] ~= use then
		return
	end
	local i = table.find(self.active, item)
	if i then
		table.remove(self.active, i)
		table.insert(self.free, item)
	end
end

-- Whether `use` is still the item's current use (delayed steps of a recycled pop check this).
function PopPool.current<T>(self: Pool<T>, item: T, use: number): boolean
	return self.uses[item] == use
end

function PopPool.activeCount<T>(self: Pool<T>): number
	return #self.active
end

function PopPool.createdCount<T>(self: Pool<T>): number
	return self.made
end

return PopPool
