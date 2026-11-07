--!strict
-- Which evolution stage (Config/Progression) a card level shows, and what the next one needs.
-- Pure; display only.
local Progression = require(script.Parent.Parent.Config.Progression)

local Evolution = {}

export type Stage = Progression.Stage

-- The stage for a level: the last stage whose minLevel is at or below it. Index 1 = Base.
function Evolution.stageAt(level: number): (Stage, number)
	local stages = Progression.evolutionStages
	local index = 1
	for i, s in stages do
		if level >= s.minLevel then
			index = i
		end
	end
	return stages[index], index
end

-- The next stage and the level it needs, or nil at the last stage.
function Evolution.next(level: number): Stage?
	local _, index = Evolution.stageAt(level)
	return Progression.evolutionStages[index + 1]
end

return table.freeze(Evolution)
