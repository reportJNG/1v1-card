--!strict
-- PLACEHOLDER art direction data (ContentStatus: characterArt, cardFrames). Until real models and
-- card art exist, characters are TEMP cut-outs (Shared/Art/Cutout, Standee in 3D): the silhouette
-- and prop come from the role, the colours from the family, the trim from the rarity. Card frames
-- differ by rarity in border, gradient and shine only (design rule 6: same card silhouette).

export type FrameStyle = {
	border: number, -- px
	colors: { string }, -- border gradient stops (hex)
	shine: boolean, -- animated light sweep
	inner: boolean, -- second inner border
}

local FamilyColors: { [string]: { body: string, accent: string } } = {
	Flame = { body = "#C2412D", accent = "#FFB347" },
	Ice = { body = "#7FB8E0", accent = "#E8F6FF" },
	Lightning = { body = "#3A55C8", accent = "#FFE14D" },
	Shadow = { body = "#2B2540", accent = "#9B7BFF" },
	Divine = { body = "#F1E6C8", accent = "#FFD45C" },
	Beast = { body = "#8A5A3B", accent = "#D9B48A" },
	Dragon = { body = "#2F7A4D", accent = "#FF6A2B" },
	Warrior = { body = "#7B8794", accent = "#D2462E" },
	Ninja = { body = "#22303F", accent = "#4FD1C5" },
	Royal = { body = "#5B2A86", accent = "#FFC54B" },
	Cosmic = { body = "#1C1F4A", accent = "#FF7BE5" },
	Ancient = { body = "#9C8B6E", accent = "#5FD3A0" },
	Mystic = { body = "#3E2A6B", accent = "#B98CFF" },
	Spirit = { body = "#A9D8D0", accent = "#FFFFFF" },
	Demon = { body = "#4A1022", accent = "#FF3B3B" },
}

local Frames: { [string]: FrameStyle } = {
	Common = { border = 2, colors = { "#B9C7DC", "#8C99AE" }, shine = false, inner = false },
	Rare = { border = 2, colors = { "#45BEFF", "#1E6FB8" }, shine = false, inner = true },
	Epic = { border = 3, colors = { "#C9A2FF", "#A469FF", "#6A35C9" }, shine = false, inner = true },
	Legendary = { border = 3, colors = { "#FFE9A8", "#FFC54B", "#B8791A" }, shine = true, inner = true },
	Mythical = {
		border = 4,
		colors = { "#FF9BB8", "#FF668F", "#A469FF", "#45BEFF" },
		shine = true,
		inner = true,
	},
}

-- Golden copies: a gold foil over the rarity frame (cosmetic only).
local GoldenFoil = { colors = { "#FFF4C2", "#FFC54B", "#C98A1C", "#FFE08A" } }

return table.freeze({
	FamilyColors = table.freeze(FamilyColors),
	Frames = table.freeze(Frames),
	GoldenFoil = table.freeze(GoldenFoil),
})
