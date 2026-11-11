--!strict
-- One source for every card number on screen (BAD_GUI_9 section 3): the card's power plate, the
-- Cards inspect panel and the stats panel all read Power.stats, which is the unit a battle fields.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Power = require(Shared.Domain.Power)
local BattleRules = require(Shared.Battle.BattleRules)
local Roster = require(Shared.Config.Roster)
local Characters = require(Shared.Config.Characters)
local AbilityText = require(Shared.Domain.AbilityText)

return function()
	describe("Card numbers", function()
		it(
			"gives the same Power and Health as the battle unit, at every level, for every active card",
			function()
				for _, id in Roster.active do
					for _, level in { 1, 4, 8, 12, 15 } do
						local st = Power.stats(id, level)
						local unit = BattleRules.preview({ { characterId = id, level = level } })[1]
						expect(st.hp).to.equal(unit.maxHp)
						expect(st.atk).to.equal(math.floor(unit.atk + 0.5))
						expect(st.power).to.equal(Power.card(id, level))
						-- the deck builder's numbers for a one-card deck are the same numbers
						local deck = Power.deck({ { characterId = id, level = level } }).units[1]
						expect(deck.power).to.equal(st.power)
						expect(deck.hp).to.equal(st.hp)
					end
				end
			end
		)

		it("grows with level, so a merge always shows a bigger number", function()
			for _, id in Roster.active do
				expect(Power.stats(id, 15).power > Power.stats(id, 1).power).to.equal(true)
				expect(Power.stats(id, 15).hp > Power.stats(id, 1).hp).to.equal(true)
			end
		end)

		it("describes every Skill in one short line", function()
			for _, c in Characters.List do
				local line = AbilityText.short(c.special)
				expect(#line > 5).to.equal(true)
				expect((string.find(line, ",", 1, true))).to.equal(nil)
				expect(string.sub(line, -1)).to.equal(".")
			end
		end)
	end)
end
