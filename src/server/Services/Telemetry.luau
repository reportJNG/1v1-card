--!strict
-- Gameplay telemetry for balance and the M7 closed test: hatches, merges, match results,
-- coin flow. Live servers send Roblox custom analytics events (at most three custom fields);
-- every server also keeps counters that tests and the Studio command bar can read.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Telemetry = {}

local counters: { [string]: number } = {}
local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

function Telemetry.event(player: Player?, name: string, fields: { [string]: any }?)
	counters[name] = (counters[name] or 0) + 1
	if RunService:IsStudio() or player == nil then
		return
	end
	local custom: { [any]: string } = {}
	if fields then
		local keys = {}
		for k in fields do
			table.insert(keys, k)
		end
		table.sort(keys)
		for i, k in keys do
			if i > #FIELD_KEYS then
				break
			end
			custom[(Enum.AnalyticsCustomFieldKeys :: any)[FIELD_KEYS[i]].Name] = `{k}={fields[k]}`
		end
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player :: Player, name, 1, custom)
	end)
end

function Telemetry.count(name: string): number
	return counters[name] or 0
end

function Telemetry.snapshot(): { [string]: number }
	return table.clone(counters)
end

return Telemetry
