--!strict
-- Pops for what the server just changed (Shared/Ui/Moments): a quest ticking up shows "+N" beside
-- the quest card, a finished quest a big "QUEST COMPLETE!", a new world "WORLD N UNLOCKED!" that
-- then flies to the Worlds button. Battles stay quiet (the HUD is hidden there).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Moments = require(Shared.Ui.Moments)
local Ui = require(script.Parent.Ui)

local Feedback = {}

function Feedback.start(ctx: any)
	local last: Moments.Snap? = nil
	ctx.state.changed:connect(function(what: string)
		if what ~= "profile" or ctx.state.view == nil then
			return
		end
		local view = ctx.state.view
		local moments = Moments.diff(last, view)
		last = Moments.snap(view)
		if ctx.state.battle ~= nil then
			return
		end
		for _, m in moments do
			if m.kind == "questProgress" then
				ctx.near(ctx.hudTarget("quests"), { text = `+{(m :: any).delta}`, tone = "green", size = 28 })
			elseif m.kind == "questComplete" then
				Ui.sound("confirm")
				ctx.say("QUEST COMPLETE!", "gold", "icon_quests")
			elseif m.kind == "worldUnlocked" then
				local world = (m :: any).world
				task.delay(0.6, function()
					Ui.sound("level_up")
					ctx.say(`WORLD {world} UNLOCKED!`, "violet", "icon_worlds")
					task.delay(1.2, function()
						ctx.fly("center", "worlds", { icon = "icon_worlds", count = 1 })
					end)
				end)
			end
		end
	end)
end

return Feedback
