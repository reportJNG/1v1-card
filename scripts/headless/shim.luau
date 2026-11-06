-- Headless test host: a minimal stand-in for the parts of the Roblox engine the domain code,
-- the server persistence/purchase modules and TestEZ touch (instance tree, require by
-- instance, Random, TestService). It is NOT Roblox: anything engine-specific (DataStores,
-- PolicyService, MarketplaceService, Players) is out of scope here and is tested in Studio.
-- bundle.py prepends `local FILES = {...}` (every module's path, class and source).
local FILES: { { path: string, class: string, src: string? } } = FILES :: any

local Node = {}
local methods = {}

local function newNode(name: string, class: string, parent: any?): any
	local node =
		setmetatable({ Name = name, ClassName = class, Parent = parent, _children = {}, _src = nil }, Node)
	if parent then
		table.insert(rawget(parent, "_children"), node)
	end
	return node
end

Node.__index = function(self, key)
	local m = methods[key]
	if m then
		return m
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	return nil
end
Node.__tostring = function(self)
	return self.Name
end

function methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local c = methods.FindFirstChild(self, name)
	if c == nil then
		error(`headless: {methods.GetFullName(self)} has no child {name}`, 2)
	end
	return c
end
function methods.IsA(self, class)
	if class == "Instance" or class == self.ClassName then
		return true
	end
	if class == "LuaSourceContainer" or class == "BaseScript" then
		return self.ClassName == "ModuleScript"
			or self.ClassName == "Script"
			or self.ClassName == "LocalScript"
	end
	return false
end
function methods.GetFullName(self)
	local parts = {}
	local n = self
	while n and n.ClassName ~= "DataModel" do
		table.insert(parts, 1, n.Name)
		n = n.Parent
	end
	return table.concat(parts, ".")
end

local game = newNode("Game", "DataModel", nil)
function methods.GetService(self, name)
	return methods.FindFirstChild(self, name) or newNode(name, name, self)
end

local testService = methods.GetService(game, "TestService")
function methods.Error(_self, msg)
	print(`[TestService] {msg}`)
end
function methods.Message(_self, msg)
	print(`[TestService] {msg}`)
end
local _ = testService

-- Random: deterministic per seed (xorshift); same interface the code uses.
local Random = {}
Random.__index = Random
local seedCounter = 0
function Random.new(seed: number?)
	seedCounter += 1
	local s = math.floor(seed or (os.clock() * 1e6 + seedCounter)) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ _s = s }, Random)
end
local function step(self)
	-- Park-Miller minimal standard generator
	self._s = (self._s * 48271) % 2147483647
	return self._s / 2147483647
end
function Random.NextNumber(self, min: number?, max: number?)
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * step(self)
end
function Random.NextInteger(self, min: number, max: number)
	return min + math.floor(step(self) * (max - min + 1))
end

-- Color3: only the constructor config uses; values are inert in tests.
local Color3 = {}
function Color3.fromHex(hex: string)
	return table.freeze({ hex = hex })
end

-- Build the tree.
for _, f in FILES do
	local parent = game
	local parts = string.split(f.path, "/")
	for i = 1, #parts - 1 do
		parent = methods.FindFirstChild(parent, parts[i])
			or newNode(parts[i], if i == 1 then parts[i] else "Folder", parent)
	end
	local leaf = methods.FindFirstChild(parent, parts[#parts])
	if leaf == nil then
		leaf = newNode(parts[#parts], f.class, parent)
	else
		rawset(leaf, "ClassName", f.class)
	end
	rawset(leaf, "_src", f.src)
end

local cache = {}
local loading = {}
local baseEnv = getfenv(1)
local sharedG = {} -- engine-like writable _G (the CLI sandbox freezes its own)
local function requireNode(node: any): any
	if typeof(node) ~= "table" or getmetatable(node) ~= Node then
		error("headless: require expects a ModuleScript", 2)
	end
	if cache[node] ~= nil then
		return cache[node]
	end
	assert(node.ClassName == "ModuleScript", `headless: {methods.GetFullName(node)} is not a ModuleScript`)
	assert(not loading[node], `headless: require cycle at {methods.GetFullName(node)}`)
	loading[node] = true
	local fn, err = loadstring(rawget(node, "_src"), "=" .. methods.GetFullName(node))
	if not fn then
		error(err, 0)
	end
	local env = setmetatable({
		script = node,
		game = game,
		require = nil :: any,
		Random = Random,
		Color3 = Color3,
		_G = sharedG,
		tick = os.clock,
		warn = function(...)
			print("[warn]", ...)
		end,
	}, { __index = baseEnv })
	env.require = requireNode
	setfenv(fn, env)
	local result = fn()
	loading[node] = nil
	cache[node] = result
	return result
end

local entryPath: string = (ENTRY :: any) or "ServerScriptService/Tests/RunTests"
local node: any = game
for _, part in string.split(entryPath, "/") do
	node = methods.WaitForChild(node, part)
end
local entry = requireNode(node)
if entryPath ~= "ServerScriptService/Tests/RunTests" then
	print(entry())
	return
end
local summary = entry()
print(summary.report)
if summary.failed > 0 then
	for _, f in summary.failures do
		print(f)
	end
	error(`{summary.failed} test(s) failed`, 0)
end
