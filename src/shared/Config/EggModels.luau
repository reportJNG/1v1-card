--!strict
-- The 3D eggs (MAKE_3D_EGGS_AND_FIGHTERS.md section 1): our own Blender models
-- (scripts/blender/eggs.py), one per egg in Eggs.RequiredIds. The icon pack's images are never put on
-- a mesh (its licence forbids editing them); they stay in the UI only.
--   body, accent  the egg's toon colours (the same palette as the Blender script)
--   mesh, texture the uploaded mesh and its baked texture. Empty until the owner approves
--                 docs/review/3d_eggs.png and the upload is done; until then Shared/Art/EggModel draws
--                 a TEMP egg shape in these colours (ContentStatus "eggModels")
-- Golden is the same mesh with the gold material and sparkles, never a separate model.
export type EggModel = { body: string, accent: string, mesh: string?, texture: string? }

local Models: { [string]: EggModel } = {
	egg_basic = { body = "#F4EBDD", accent = "#D9C7AE" },
	egg_spotted = { body = "#FFE7B8", accent = "#E07A3A" },
	egg_cracked = { body = "#E8DCC8", accent = "#FFB43C" },
	egg_cat = { body = "#F2A65A", accent = "#FFE1C4" },
	egg_dog = { body = "#C8935C", accent = "#6E4428" },
	egg_rainbow = { body = "#FF5A6E", accent = "#2FB7FF" },
	egg_sandcastle = { body = "#EBCB8B", accent = "#C79A55" },
	egg_coconut = { body = "#7A4A2A", accent = "#D9B07A" },
	egg_royal = { body = "#6A3DD8", accent = "#FFC93C" },
	egg_ice = { body = "#A9E6FF", accent = "#E9FBFF" },
	egg_yeti = { body = "#E9F2FF", accent = "#9EC6E8" },
	egg_mine = { body = "#7C7F8C", accent = "#B06BFF" },
	egg_dragon = { body = "#2FA35B", accent = "#F2D35B" },
	egg_demon = { body = "#7A1630", accent = "#FF2E5C" },
	egg_angel = { body = "#FFF8EC", accent = "#FFD86B" },
	egg_kraken = { body = "#2C6E9E", accent = "#E0607A" },
	egg_dominus = { body = "#1F2347", accent = "#F2C14E" },
	egg_legendary = { body = "#FF9F1C", accent = "#FFE27A" },
	egg_glitched = { body = "#2B2E4A", accent = "#FF3EA5" },
	egg_black_hole = { body = "#120C24", accent = "#A35BFF" },
	egg_secret = { body = "#2A2633", accent = "#7DF9FF" },
	egg_angel_demon = { body = "#FFF8EC", accent = "#3A0F22" },
	egg_mythical = { body = "#16C27D", accent = "#FFE27A" },
	egg_party = { body = "#7B5CFF", accent = "#FFD23F" },
}

return table.freeze({
	ById = table.freeze(Models),
	Gold = "#FFC21A",
	HEIGHT = 3.4, -- studs, the egg standing on a lobby pedestal
	LABEL = table.freeze({ 5.2, 2.5 }), -- the label over a pedestal egg, studs (narrower than the gap)
})
