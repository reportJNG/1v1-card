--!strict
-- The main menu's own scene (FIX_LOBBY_2.md section A): far from everything players walk in, so the
-- menu never shows the lobby (or a world or an arena), built only from the game's existing meshes,
-- with its own lighting preset.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuStage = require(Shared.Config.MenuStage)
local HubLayout = require(Shared.Config.HubLayout)
local WorldProps = require(Shared.Config.WorldProps)
local UiAssets = require(Shared.Config.UiAssets)
local Lighting = require(Shared.Config.Lighting)
local WorldLayout = require(Shared.Domain.WorldLayout)
local ArenaLayout = require(Shared.Domain.ArenaLayout)

local FAR = 5000 -- studs: well past every billboard's MaxDistance and the menu's haze

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

return function()
	describe("MenuStage", function()
		it("sits far from the lobby, every world and the battle arenas", function()
			local o = MenuStage.ORIGIN
			expect(dist(o, HubLayout.ORIGIN) > FAR).to.equal(true)
			for w = 1, 10 do
				local p = WorldLayout.origin(w)
				expect(dist(o, { p.x, p.y, p.z }) > FAR).to.equal(true)
			end
			-- the arenas are built at BattleStage's origin (0, 800, 6000)
			expect(dist(o, { 0, 800, 6000 }) > FAR).to.equal(true)
			expect(ArenaLayout.PLATFORM < FAR).to.equal(true)
		end)

		it("uses only meshes and images the game already has", function()
			for _, piece in MenuStage.Pieces do
				expect(HubLayout.Models[piece.model] or WorldProps.Models[piece.model]).to.be.ok()
			end
			for _, spec in MenuStage.Particles do
				expect(UiAssets[spec.texture]).to.be.ok()
			end
		end)

		it("has its own lighting preset", function()
			expect(Lighting.menu).to.be.ok()
		end)
	end)
end
