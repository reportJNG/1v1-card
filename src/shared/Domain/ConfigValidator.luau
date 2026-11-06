--!strict
-- Validates all content config. The server runs it at boot and refuses to start on errors;
-- the test suite runs it too. `release = true` also turns warnings about unfinished launch data
-- (missing asset ids, unpublished Developer Products) into errors.
local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Rarities = require(Config.Rarities)
local Families = require(Config.Families)
local Roles = require(Config.Roles)
local OddsBands = require(Config.OddsBands)
local Eggs = require(Config.Eggs)
local Worlds = require(Config.Worlds)
local Economy = require(Config.Economy)
local Leagues = require(Config.Leagues)
local Items = require(Config.Items)
local Monetization = require(Config.Monetization)
local Market = require(Config.Market)
local ContentStatus = require(Config.ContentStatus)
local Odds = require(script.Parent.Odds)

export type Report = { errors: { string }, warnings: { string } }

local EPSILON = 1e-9
local STATUSES: { [string]: boolean } = table.freeze({
	Burn = true,
	Chill = true,
	Weaken = true,
	Shield = true,
	Reflect = true,
})
local STATS: { [string]: boolean } =
	table.freeze({ hp = true, atk = true, def = true, spd = true, crit = true })

local ConfigValidator = {}

local function isPositiveInt(v: any): boolean
	return typeof(v) == "number" and v > 0 and v == math.floor(v)
end

function ConfigValidator.validate(options: { release: boolean? }?): Report
	local release = options ~= nil and options.release == true
	local errors: { string } = {}
	local warnings: { string } = {}
	local function err(msg: string)
		table.insert(errors, msg)
	end
	local function launchGap(msg: string)
		table.insert(if release then errors else warnings, msg)
	end

	-- Characters
	local seen: { [string]: boolean } = {}
	if #Characters.List > Characters.MaxCatalogSize then
		err(`Characters: {#Characters.List} exceeds the design capacity of {Characters.MaxCatalogSize}`)
	end
	for _, c in Characters.List do
		if seen[c.id] then
			err(`Characters: duplicate id {c.id}`)
		end
		seen[c.id] = true
		if not string.match(c.id, "^[a-z][a-z0-9_]*$") then
			err(`Characters: id {c.id} must be lower_snake_case`)
		end
		if Rarities.Defs[c.rarity] == nil then
			err(`Characters: {c.id} has unknown rarity {c.rarity}`)
		end
		if Families.Defs[c.family] == nil then
			err(`Characters: {c.id} has unknown family {c.family}`)
		end
		if Roles[c.role] == nil then
			err(`Characters: {c.id} has unknown role {c.role}`)
		end
		local s = c.special
		if s.cost < 2 or s.cost > 4 then
			err(`Characters: {c.id} special cost {s.cost} outside 2..4`)
		end
		if s.kind == "Damage" and not (typeof(s.multiplier) == "number" and s.multiplier > 0) then
			err(`Characters: {c.id} damage special needs a multiplier`)
		end
		if s.kind == "Heal" and not (typeof(s.healFraction) == "number" and s.healFraction > 0) then
			err(`Characters: {c.id} heal special needs healFraction`)
		end
		if s.kind == "Stance" and not (typeof(s.blockFraction) == "number" and s.blockFraction > 0) then
			err(`Characters: {c.id} stance special needs blockFraction`)
		end
		local applies = s.applies
		if applies then
			for _, application in applies do
				if not STATUSES[application.status] then
					err(`Characters: {c.id} applies unknown status {application.status}`)
				end
				if application.target ~= "Self" and application.target ~= "Opponent" then
					err(`Characters: {c.id} status target must be Self or Opponent`)
				end
				if application.rounds < 1 or application.value <= 0 then
					err(`Characters: {c.id} status needs rounds >= 1 and value > 0`)
				end
			end
		end
		if c.enabled and c.assets.model == nil then
			launchGap(`Characters: {c.id} has no approved model asset yet`)
		end
	end

	-- Families
	for name, family in Families.Defs do
		if not STATS[family.bonusStat] then
			err(`Families: {name} has unknown bonus stat {family.bonusStat}`)
		end
	end

	-- Odds bands
	for bandId, band in OddsBands do
		local total = 0
		for _, rarity in Rarities.Order do
			local p = band[rarity]
			if typeof(p) ~= "number" or p < 0 then
				err(`OddsBands: {bandId}.{rarity} must be a non-negative number`)
			else
				total += p
			end
		end
		if math.abs(total - 100) > EPSILON then
			err(`OddsBands: band {bandId} totals {total}, not 100`)
		end
	end

	-- Eggs: exactly the 24 required ids
	local required: { [string]: boolean } = {}
	for _, id in Eggs.RequiredIds do
		required[id] = true
		if Eggs.ById[id] == nil then
			err(`Eggs: required egg {id} is missing`)
		end
	end
	if #Eggs.RequiredIds ~= 24 then
		err(`Eggs: RequiredIds lists {#Eggs.RequiredIds} eggs, expected 24`)
	end
	local seenEgg: { [string]: boolean } = {}
	for _, egg in Eggs.List do
		if seenEgg[egg.id] then
			err(`Eggs: duplicate id {egg.id}`)
		end
		seenEgg[egg.id] = true
		if not required[egg.id] then
			err(`Eggs: {egg.id} is not one of the 24 pack eggs`)
		end
		if OddsBands[egg.oddsBand] == nil then
			err(`Eggs: {egg.id} uses unknown band {egg.oddsBand}`)
		end
		for rarity, ids in egg.pool do
			if Rarities.Defs[rarity] == nil then
				err(`Eggs: {egg.id} pool has unknown rarity {rarity}`)
			end
			for _, id in ids do
				local def = Characters.ById[id]
				if def == nil then
					err(`Eggs: {egg.id} pool references unknown character {id}`)
				elseif def.rarity ~= rarity then
					err(`Eggs: {egg.id} lists {id} under {rarity}, but it is {def.rarity}`)
				end
			end
		end
		if OddsBands[egg.oddsBand] ~= nil then
			for _, golden in { false, true } do
				if golden and not egg.goldenAllowed then
					continue
				end
				local ok, result = pcall(Odds.forEgg, egg, golden)
				if not ok then
					err(`Eggs: {egg.id} odds failed: {result}`)
				else
					local total = 0
					for _, entry in result.characters do
						total += entry.percent
					end
					if math.abs(total - 100) > 1e-6 then
						err(`Eggs: {egg.id} ({if golden then "golden" else "normal"}) odds total {total}`)
					end
				end
			end
		end
		if egg.goldenAllowed ~= (egg.icon.goldenFile ~= nil) then
			err(`Eggs: {egg.id} goldenAllowed must match whether Golden art exists`)
		end
		if egg.world == nil then
			if egg.coinPrice ~= nil or egg.robuxPurchasable then
				err(`Eggs: event egg {egg.id} must not be sold in the shop`)
			end
		else
			local world = Worlds.ById[egg.world]
			if world == nil then
				err(`Eggs: {egg.id} is in unknown world {egg.world}`)
			elseif not table.find(world.eggs, egg.id) then
				err(`Eggs: {egg.id} is not listed by world {egg.world}`)
			end
			if egg.coinPrice ~= nil and not isPositiveInt(egg.coinPrice) then
				err(`Eggs: {egg.id} coinPrice must be a positive integer`)
			end
		end
		local box = egg.icon.contentBox
		if box.x < 0 or box.y < 0 or box.x + box.width > 256 or box.y + box.height > 256 then
			err(`Eggs: {egg.id} contentBox is outside the 256 px canvas`)
		end
		if egg.icon.normalAssetId == nil then
			launchGap(`Eggs: {egg.id} icon not uploaded yet`)
		end
	end

	-- Placeholder content: one summary line per area, plus every placeholder egg in release mode.
	local placeholderEggs = 0
	for _, egg in Eggs.List do
		if egg.status ~= "Final" then
			placeholderEggs += 1
			if release then
				err(`Eggs: {egg.id} is placeholder content`)
			end
		end
	end
	if placeholderEggs > 0 and not release then
		table.insert(warnings, `Eggs: {placeholderEggs} of {#Eggs.List} eggs are placeholder content`)
	end
	for area, note in ContentStatus.Placeholder do
		launchGap(`Placeholder ({area}): {note}`)
	end

	-- Worlds
	local lastThreshold = -1
	for i, world in Worlds.List do
		if world.id ~= i then
			err(`Worlds: entry {i} has id {world.id}`)
		end
		if world.trophiesToUnlock <= lastThreshold then
			err(`Worlds: thresholds must increase (world {world.id})`)
		end
		lastThreshold = world.trophiesToUnlock
		for _, eggId in world.eggs do
			local egg = Eggs.ById[eggId]
			if egg == nil or egg.world ~= world.id then
				err(`Worlds: world {world.id} lists {eggId}, which does not belong to it`)
			end
		end
	end
	if #Worlds.List ~= 10 then
		err(`Worlds: expected 10 worlds, found {#Worlds.List}`)
	elseif Worlds.List[1].trophiesToUnlock ~= 0 then
		err("Worlds: world 1 must be open from the start")
	end

	-- Economy
	local function checkLadder(name: string, cfg: any)
		local steps = (cfg.maxSlots - cfg.startSlots) / cfg.slotsPerExpansion
		if steps ~= math.floor(steps) then
			err(`Economy: {name} slot range is not a whole number of expansions`)
		elseif #cfg.expansionPrices ~= steps then
			err(`Economy: {name} has {#cfg.expansionPrices} prices for {steps} expansions`)
		end
		for i, price in cfg.expansionPrices do
			if not isPositiveInt(price) then
				err(`Economy: {name} price {i} must be a positive integer`)
			end
		end
	end
	checkLadder("CardStorage", Economy.CardStorage)
	checkLadder("ItemInventory", Economy.ItemInventory)
	local prog = Economy.Progression
	if #prog.mergePointsToNext ~= prog.maxLevel - 1 or #prog.coinFeeToNext ~= prog.maxLevel - 1 then
		err("Economy: Progression tables must have maxLevel - 1 entries")
	end
	for i = 1, prog.maxLevel - 1 do
		if not isPositiveInt(prog.mergePointsToNext[i]) or not isPositiveInt(prog.coinFeeToNext[i]) then
			err(`Economy: Progression level {i} costs must be positive integers`)
		end
	end

	-- Leagues
	local lastMin = -1
	for _, league in Leagues.List do
		if league.minTrophies <= lastMin then
			err(`Leagues: {league.id} must start above the previous league`)
		end
		lastMin = league.minTrophies
		if league.rankedLevelCap < 1 or league.rankedLevelCap > prog.maxLevel then
			err(`Leagues: {league.id} cap outside 1..{prog.maxLevel}`)
		end
	end
	if Leagues.List[1].minTrophies ~= 0 then
		err("Leagues: the first league must start at 0 trophies")
	end
	if Leagues.List[#Leagues.List].rankedLevelCap ~= prog.maxLevel then
		err("Leagues: the top league must allow max level")
	end

	-- Items
	for _, item in Items.List do
		if Worlds.ById[item.world] == nil then
			err(`Items: {item.id} is in unknown world {item.world}`)
		end
		if not isPositiveInt(item.maxStack) or not isPositiveInt(item.sellPrice) then
			err(`Items: {item.id} needs positive integer maxStack and sellPrice`)
		end
	end

	-- Monetization
	local seenProduct: { [number]: string } = {}
	for _, product in Monetization.RobuxEggs do
		local egg = Eggs.ById[product.eggId]
		if egg == nil or not egg.robuxPurchasable then
			err(`Monetization: {product.key} sells {product.eggId}, which is not a Robux egg`)
		end
		if product.productId == nil then
			launchGap(`Monetization: {product.key} has no Developer Product id`)
		elseif seenProduct[product.productId] then
			err(
				`Monetization: product id {product.productId} used by {product.key} and {seenProduct[product.productId]}`
			)
		else
			seenProduct[product.productId] = product.key
		end
	end

	-- Market (V2)
	if Market.enabled then
		err("Market: the player store is a V2 feature and must stay disabled in V1")
	end
	if Market.feeRate < 0 or Market.feeRate >= 1 then
		err("Market: feeRate must be in [0, 1)")
	end
	if not isPositiveInt(Market.maxActiveListingsPerPlayer) then
		err("Market: maxActiveListingsPerPlayer must be a positive integer")
	end

	return { errors = errors, warnings = warnings }
end

return table.freeze(ConfigValidator)
