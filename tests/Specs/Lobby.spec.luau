--!strict
-- The lobby (FIX_LOBBY.md): every place has its prompt and world text, the lights stay within the
-- budget, the spawn faces an open path to the plaza, the eggs on the pedestals exist, and the
-- lobby's merchant point matches its stall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared.Config.HubLayout)
local WorldProps = require(Shared.Config.WorldProps)
local Eggs = require(Shared.Config.Eggs)
local UiAssets = require(Shared.Config.UiAssets)
local Sounds = require(Shared.Config.Sounds)

local function modelOf(key: string): any
	return HubLayout.Models[key] or WorldProps.Models[key]
end

return function()
	describe("Lobby", function()
		it("has every place from the brief, each with a prompt and a sign", function()
			for _, key in { "arena", "portal", "egg_stall", "merchant", "quests", "daily" } do
				local f = HubLayout.Features[key]
				expect(f).to.be.ok()
				expect(f.prompt).to.be.ok()
				expect(f.sign).to.be.ok()
				if f.sign and f.sign.icon then
					expect(UiAssets[f.sign.icon]).to.be.ok()
				end
			end
		end)

		it("uses only meshes the game already has", function()
			for _, piece in HubLayout.Pieces do
				expect(modelOf(piece.model)).to.be.ok()
			end
		end)

		it("keeps the dynamic lights within the mobile budget (40)", function()
			local lights = 0
			for _, piece in HubLayout.Pieces do
				if piece.light then
					lights += 1
				end
			end
			for _, prim in HubLayout.Prims do
				if prim.light then
					lights += 1
				end
			end
			expect(lights <= 40).to.equal(true)
		end)

		it("leaves the walk from the spawn to the plaza open", function()
			local spawn = HubLayout.SPAWN
			for _, prim in HubLayout.Prims do
				if prim.collide and prim.shape == "Block" then
					local x, y, z = prim.at[1], prim.at[2], prim.at[3]
					local top = y + prim.size[2] / 2
					local inPath = math.abs(x - spawn[1]) < prim.size[1] / 2 + 2
						and z > 36 - prim.size[3] / 2
						and z < spawn[3] + prim.size[3] / 2
					if inPath then
						-- only floors (paths, the bridge) may cross the walk, never a wall
						expect(top <= 1).to.equal(true)
					end
				end
			end
			for _, piece in HubLayout.Pieces do
				local x, z = piece.at[1], piece.at[3]
				expect(math.abs(x) < 8 and z > 36 and z < spawn[3]).to.equal(false)
			end
		end)

		it("stands the spawn on top of the spawn shrine (FIX_LOBBY_2 B1)", function()
			local spawn = HubLayout.SPAWN
			local top = -math.huge
			for _, prim in HubLayout.Prims do
				local d = math.sqrt((prim.at[1] - spawn[1]) ^ 2 + (prim.at[3] - spawn[3]) ^ 2)
				if prim.collide and prim.shape == "Cylinder" and d < 1 then
					top = math.max(top, prim.at[2] + prim.size[2] / 2)
				end
			end
			expect(math.abs(top - spawn[2]) < 0.01).to.equal(true)
		end)

		it("stays within the part budget (about 3,000-4,500, at most 6,000)", function()
			local parts = #HubLayout.Pieces
			for _, prim in HubLayout.Prims do
				parts += if prim.shape == "Ring" then prim.size[3] else 1
			end
			expect(parts >= 2500).to.equal(true)
			expect(parts <= 4500).to.equal(true)
		end)

		it(
			"gives every ambient zone a looping licensed sound and every moving shape a known motion",
			function()
				for _, zone in HubLayout.Ambient do
					local def = Sounds[zone.sound]
					expect(def).to.be.ok()
					expect(def.id).to.be.ok()
					expect(def.looped).to.equal(true)
				end
				local known = {
					Spin = true,
					Sway = true,
					Pulse = true,
					Orbit = true,
					Koi = true,
					Bob = true,
					Brazier = true,
					Jet = true,
					Mist = true,
					GoldMotes = true,
				}
				for _, prim in HubLayout.Prims do
					if prim.tag then
						expect(known[prim.tag]).to.equal(true)
					end
				end
			end
		)

		it("puts real eggs on the pedestals and the merchant point at its stall", function()
			for _, spot in HubLayout.EggPedestals do
				expect(Eggs.ById[spot.egg]).to.be.ok()
			end
			local m, f = HubLayout.MERCHANT, HubLayout.Features.merchant.at
			local d = math.sqrt((m[1] - f[1]) ^ 2 + (m[3] - f[3]) ^ 2)
			expect(d < 4).to.equal(true)
		end)
	end)
end
