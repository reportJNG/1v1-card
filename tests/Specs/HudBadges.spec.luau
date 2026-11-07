--!strict
-- POLISH_MISSION C: the HUD's notification dots and quest tracker (Shared/Ui/HudBadges).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudBadges = require(ReplicatedStorage:WaitForChild("Shared").Ui.HudBadges)

local NOW = 20_000 * 86400 + 3600
local TODAY = NOW // 86400

local function view(over: { [string]: any }?): any
	local v: any = {
		deck = { "a", "b", "c" },
		eggBag = {},
		daily = { lastClaimDay = TODAY, freeEggDay = TODAY },
		quests = {},
	}
	for k, x in (over or {}) :: { [string]: any } do
		v[k] = x
	end
	return v
end

return function()
	describe("HUD badges", function()
		it("shows no dots when nothing is waiting", function()
			local d = HudBadges.dots(view(), NOW)
			expect(d.Quests).to.equal(false)
			expect(d.Shop).to.equal(false)
			expect(d.Deck).to.equal(false)
		end)

		it("dots Quests for a finished, unclaimed quest or today's streak", function()
			expect(
				HudBadges.dots(view({ quests = { d_hatch3 = { progress = 3, claimed = false } } }), NOW).Quests
			).to.equal(true)
			expect(
				HudBadges.dots(view({ quests = { d_hatch3 = { progress = 3, claimed = true } } }), NOW).Quests
			).to.equal(false)
			expect(
				HudBadges.dots(view({ quests = { d_hatch3 = { progress = 2, claimed = false } } }), NOW).Quests
			).to.equal(false)
			local streak = view({ daily = { lastClaimDay = TODAY - 1, freeEggDay = TODAY } })
			expect(HudBadges.dots(streak, NOW).Quests).to.equal(true)
		end)

		it("dots Shop for today's free egg or eggs in the bag, and Deck for an incomplete deck", function()
			expect(
				HudBadges.dots(view({ daily = { lastClaimDay = TODAY, freeEggDay = TODAY - 1 } }), NOW).Shop
			).to.equal(true)
			expect(HudBadges.dots(view({ eggBag = { egg_basic = { normal = 1, golden = 0 } } }), NOW).Shop).to.equal(
				true
			)
			expect(HudBadges.dots(view({ deck = { "a" } }), NOW).Deck).to.equal(true)
		end)

		it("tracks today's first unfinished daily quest, else an achievement", function()
			local v = view({
				quests = {
					a_hatch_50 = { progress = 4, claimed = false },
					d_hatch3 = { progress = 1, claimed = false },
					d_play3 = { progress = 3, claimed = false }, -- finished: skipped
				},
			})
			local t = HudBadges.tracker(v)
			expect(t).to.be.ok()
			expect((t :: any).text).to.equal("Daily: Hatch 3 eggs")
			expect((t :: any).progress).to.equal(1)
			expect((t :: any).target).to.equal(3)
			local only =
				HudBadges.tracker(view({ quests = { a_hatch_50 = { progress = 4, claimed = false } } }))
			expect((only :: any).text).to.equal("Goal: Hatch 50 eggs")
			expect(HudBadges.tracker(view())).to.equal(nil)
		end)
	end)
end
