--!strict
-- A character's cut-out art as image layers, back to front, for the card (App/Card) and the 3D
-- standee (Shared/Art/Standee) alike. With the owner's transparent card art
-- (CharacterDef.assets.cardArt) it is that one image with a rim light behind it; until then it is
-- the TEMP role silhouette in four layers tinted with the character's look colours
-- (art/ui/PROMPTS.md "Card cutouts (TEMP)"). Pure data from config: usable on client and server.
local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Art = require(Config.Art)
local UiAssets = require(Config.UiAssets)

local Cutout = {}

export type Layer = {
	name: string,
	image: string,
	color: Color3,
	transparency: number,
	offset: Vector2, -- fraction of the cut-out's size (the rim light sits slightly off)
}

local function asset(slot: string): string
	local def = UiAssets[slot]
	return if def.final and def.final ~= "" then def.final else def.temp
end

-- True while the character has no approved card art yet (the layers are TEMP).
function Cutout.isTemp(characterId: string): boolean
	local def = Characters.ById[characterId]
	return def == nil or def.assets.cardArt == nil
end

function Cutout.layers(characterId: string): { Layer }
	local def = Characters.ById[characterId]
	assert(def, `unknown character {characterId}`)
	local fam = Art.FamilyColors[def.family]
	local accent = Color3.fromHex(fam.accent)
	local rimOffset = Vector2.new(0.018, -0.012)
	if def.assets.cardArt then
		return {
			{
				name = "Rim",
				image = def.assets.cardArt,
				color = accent,
				transparency = 0.2,
				offset = rimOffset,
			},
			{
				name = "Art",
				image = def.assets.cardArt,
				color = Color3.new(1, 1, 1),
				transparency = 0,
				offset = Vector2.zero,
			},
		}
	end
	local role = string.lower(def.role)
	local colors = def.look and def.look.colors or {}
	local outfit = if colors[1] then Color3.fromHex(colors[1]) else Color3.fromHex(fam.body)
	local trim = if colors[2] then Color3.fromHex(colors[2]) else accent
	local white = Color3.new(1, 1, 1)
	return {
		{
			name = "Rim",
			image = asset(`cutout_{role}_line`),
			color = accent,
			transparency = 0.15,
			offset = rimOffset,
		},
		{
			name = "line",
			image = asset(`cutout_{role}_line`),
			color = white,
			transparency = 0,
			offset = Vector2.zero,
		},
		{
			name = "outfit",
			image = asset(`cutout_{role}_outfit`),
			color = outfit,
			transparency = 0,
			offset = Vector2.zero,
		},
		{
			name = "skin",
			image = asset(`cutout_{role}_skin`),
			color = white,
			transparency = 0,
			offset = Vector2.zero,
		},
		{
			name = "accent",
			image = asset(`cutout_{role}_accent`),
			color = trim,
			transparency = 0,
			offset = Vector2.zero,
		},
	}
end

return table.freeze(Cutout)
