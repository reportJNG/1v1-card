--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayState = require(Shared.Domain.PlayState)
local ReturnSpot = require(Shared.Domain.ReturnSpot)
local WorldLayout = require(Shared.Domain.WorldLayout)
local BattleEnd = require(game:GetService("ServerScriptService"):WaitForChild("Server").Battle.BattleEnd)

local function unlocked(...: number): (number) -> boolean
	local set = {}
	for _, w in { ... } do
		set[w] = true
	end
	return function(w: number): boolean
		return set[w] == true
	end
end

return function()
	describe("PlayState", function()
		it("refuses world actions on the main menu and during battles", function()
			for _, action in { "travel", "hub", "harvest", "sell", "queue", "trial" } do
				expect(PlayState.allows("menu", action)).to.equal(false)
				expect(PlayState.allows("battling", action)).to.equal(false)
				expect(PlayState.allows("playing", action)).to.equal(true)
			end
		end)

		it("lets menu panels (shop, cards, deck) work on the main menu", function()
			for _, action in { "shop", "merge", "deck", "favorite" } do
				expect(PlayState.allows("menu", action)).to.equal(true)
			end
		end)

		it("moves menu -> playing -> battling -> playing -> menu", function()
			local s: PlayState.State = "menu"
			s = PlayState.next(s, "battleStart")
			expect(s).to.equal("menu") -- no battle from the menu
			s = PlayState.next(s, "play")
			expect(s).to.equal("playing")
			s = PlayState.next(s, "battleStart")
			expect(s).to.equal("battling")
			expect(PlayState.next(s, "play")).to.equal("battling")
			s = PlayState.next(s, "battleEnd")
			expect(s).to.equal("playing")
			expect(PlayState.next(s, "leave")).to.equal("menu")
			expect(PlayState.next("battling", "leave")).to.equal("menu")
			expect(PlayState.next("menu", "battleEnd")).to.equal("menu") -- left mid-battle: stays on the menu
		end)
	end)

	describe("ReturnSpot", function()
		local w1 = WorldLayout.origin(1)

		it("returns to the exact spot in an unlocked world", function()
			local c =
				ReturnSpot.choose({ world = 1, x = w1.x + 20, y = 5, z = w1.z - 30, yaw = 1.2 }, unlocked(1))
			expect(c.kind).to.equal("spot")
			expect(c.spot.world).to.equal(1)
			expect(c.spot.x).to.equal(w1.x + 20)
			expect(c.spot.yaw).to.equal(1.2)
		end)

		it("falls back to the world's spawn when the spot is out of bounds", function()
			local c = ReturnSpot.choose({ world = 1, x = w1.x + 5000, y = 5, z = 0, yaw = 0 }, unlocked(1))
			expect(c.kind).to.equal("worldSpawn")
			expect(c.spot.world).to.equal(1)
			local fell = ReturnSpot.choose({ world = 1, x = w1.x, y = -500, z = 0, yaw = 0 }, unlocked(1))
			expect(fell.kind).to.equal("worldSpawn")
		end)

		it("falls back to the lobby when the world is locked now", function()
			local c = ReturnSpot.choose(
				{ world = 3, x = WorldLayout.origin(3).x, y = 5, z = 0, yaw = 0 },
				unlocked(1)
			)
			expect(c.kind).to.equal("lobby")
			expect(c.spot.world).to.equal(0)
		end)

		it("returns to a spot in the lobby, or the lobby spawn when it is off the plaza", function()
			local lobby = ReturnSpot.lobby()
			local here = ReturnSpot.choose(
				{ world = 0, x = lobby.x + 10, y = lobby.y, z = lobby.z - 10, yaw = 0 },
				unlocked()
			)
			expect(here.kind).to.equal("spot")
			local off = ReturnSpot.choose(
				{ world = 0, x = lobby.x + 900, y = lobby.y, z = lobby.z, yaw = 0 },
				unlocked()
			)
			expect(off.kind).to.equal("lobby")
		end)

		it("treats a missing or malformed spot (teleport data) as the lobby", function()
			local bads: { any } = {
				"x",
				{ world = 1 },
				{ world = 1.5, x = 0, y = 0, z = 0, yaw = 0 },
				{ world = 99, x = 0, y = 0, z = 0, yaw = 0 },
				{ world = 1, x = 0 / 0, y = 0, z = 0, yaw = 0 },
			}
			for _, bad in bads do
				expect(ReturnSpot.choose(bad, unlocked(1, 99)).kind).to.equal("lobby")
			end
			expect(ReturnSpot.choose(nil, unlocked(1)).kind).to.equal("lobby")
		end)
	end)
	describe("BattleEnd (every player leaves a finished battle)", function()
		local result = { winner = 2, reason = "KO", rounds = 9, timeouts = { 0, 0 }, endedByForfeit = false }

		it("sends both ranked players back, with the right result", function()
			local record = {
				matchId = "m1",
				mode = "Ranked",
				seed = 1,
				seats = { { userId = 11, name = "A", deck = {} }, { userId = 22, name = "B", deck = {} } },
			}
			local out = BattleEnd.leavers(record :: any, result :: any)
			expect(#out).to.equal(2)
			expect(out[1].userId).to.equal(11)
			expect(out[1].won).to.equal(false)
			expect(out[2].userId).to.equal(22)
			expect(out[2].won).to.equal(true)
		end)

		it("sends the Trial player back and never the Guardian", function()
			local record = {
				matchId = "t1",
				mode = "Trial",
				seed = 1,
				worldId = 1,
				seats = { { userId = 11, name = "A", deck = {} }, { name = "Warden", deck = {} } } :: { any },
			}
			local out = BattleEnd.leavers(record :: any, result :: any)
			expect(#out).to.equal(1)
			expect(out[1].userId).to.equal(11)
			expect(out[1].won).to.equal(false)
		end)
	end)
end
