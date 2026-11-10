--!strict
-- The first-session tutorial (BAD_GUI_5_INGAME_HUD section 2.3): server-tracked steps shown in the
-- HUD's quest panel until all are done, then the dailies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local Quests = require(Shared.Domain.Quests)
local QuestsCfg = require(Shared.Config.Quests)
local HudBadges = require(Shared.Ui.HudBadges)

local NOW = 20_000 * 86400 + 3600

local KIND_AMOUNT: { [string]: number } = {}
for _, def in QuestsCfg.Tutorial do
	KIND_AMOUNT[def.kind] = math.max(KIND_AMOUNT[def.kind] or 0, def.target)
end

return function()
	describe("Tutorial", function()
		it("starts at step 1 of 7 in the quest panel", function()
			local p = ProfileSchema.new(1)
			Quests.roll(p, NOW)
			local card = HudBadges.questCard(p) :: any
			expect(card.title).to.equal("Tutorial")
			expect(card.done).to.equal(0)
			expect(card.total).to.equal(#QuestsCfg.Tutorial)
			expect(card.rows[1].text).to.equal(QuestsCfg.Tutorial[1].text)
		end)

		it("ticks a step from the server's tracking, and shows the next two", function()
			local p = ProfileSchema.new(1)
			Quests.track(p, "Travel", 1, NOW)
			local card = HudBadges.questCard(p) :: any
			expect(card.done).to.equal(1)
			expect(card.rows[1].text).to.equal(QuestsCfg.Tutorial[2].text)
		end)

		it("finishes, sets tutorialDone, and the panel goes back to the dailies", function()
			local p = ProfileSchema.new(1)
			for kind, amount in KIND_AMOUNT do
				Quests.track(p, kind, amount, NOW)
			end
			expect(p.flags.tutorialDone).to.equal(true)
			local card = HudBadges.questCard(p) :: any
			expect(card.title).to.equal("Daily")
		end)

		it("can't be claimed for rewards", function()
			local p = ProfileSchema.new(1)
			Quests.track(p, "Travel", 1, NOW)
			local r = Quests.claim(p, "t_travel", NOW)
			expect(r.ok).to.equal(false)
		end)
	end)
end
