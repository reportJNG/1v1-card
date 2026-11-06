--!strict
-- Exports the battle content (rules + characters) as JSON for the Python reference model:
--   python3 scripts/headless/bundle.py --entry=ServerScriptService/Tests/Tools/ExportContent
--   luau build/entry.luau > sim/characters.json
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Battle = require(Shared.Config.Battle)
local Roles = require(Shared.Config.Roles)
local Rarities = require(Shared.Config.Rarities)
local Families = require(Shared.Config.Families)

local function encode(v: any): string
	local t = typeof(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then
			return string.format("%d", v)
		end
		return string.format("%.17g", v)
	elseif t == "string" then
		return '"'
			.. string.gsub(v, '[%c"\\]', function(c)
				return string.format("\\u%04x", string.byte(c))
			end)
			.. '"'
	end
	-- table: array if 1..n keys, else object with sorted keys
	local n = #v
	local count = 0
	for _ in v do
		count += 1
	end
	if n > 0 and n == count then
		local parts = {}
		for i = 1, n do
			parts[i] = encode(v[i])
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	local parts = {}
	for _, k in keys do
		table.insert(parts, encode(k) .. ":" .. encode(v[k]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

return function(): string
	local out = {}
	for _, c in Characters.List do
		table.insert(out, {
			id = c.id,
			family = c.family,
			rarity = c.rarity,
			role = c.role,
			special = c.special,
			passive = c.passive.effect,
		})
	end
	local roles, budget, familyStat = {}, {}, {}
	for name, def in Roles do
		roles[name] = def.base
	end
	for name, def in Rarities.Defs do
		budget[name] = def.statBudget
	end
	for name, def in Families.Defs do
		familyStat[name] = def.bonusStat
	end
	return encode({
		rules = Battle,
		roles = roles,
		rarityBudget = budget,
		familyStat = familyStat,
		synergy = {
			["1"] = Families.SynergyBonus[1],
			["2"] = Families.SynergyBonus[2],
			["3"] = Families.SynergyBonus[3],
		},
		characters = out,
	})
end
