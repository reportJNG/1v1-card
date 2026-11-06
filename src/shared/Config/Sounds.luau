--!strict
-- Every sound slot the game plays (docs/ART_STYLE.md section 7). `id` is a Creator Store audio asset
-- listed in docs/ASSETS.md; a slot with no id stays silent (the game never plays a stand-in sound).
-- Volumes are relative (0-1); the client applies the player's music/SFX settings on top.

export type Sound = { id: string?, volume: number, kind: "sfx" | "music", looped: boolean? }

local Sounds: { [string]: Sound } = {
	-- UI
	click = { id = nil, volume = 0.5, kind = "sfx" },
	hover = { id = nil, volume = 0.2, kind = "sfx" },
	open = { id = "rbxassetid://1837834196", volume = 0.25, kind = "sfx" }, -- APM "Reverse Quick Swipe - Light Swipe 02"
	close = { id = nil, volume = 0.3, kind = "sfx" },
	coin = { id = nil, volume = 0.5, kind = "sfx" },
	error = { id = nil, volume = 0.4, kind = "sfx" },
	-- Hatching
	hatch_shake = { id = nil, volume = 0.5, kind = "sfx" },
	hatch_crack = { id = nil, volume = 0.6, kind = "sfx" },
	reveal = { id = nil, volume = 0.6, kind = "sfx" },
	reveal_rare = { id = nil, volume = 0.7, kind = "sfx" }, -- Epic and above
	-- Battle
	tick = { id = nil, volume = 0.25, kind = "sfx" },
	hit = { id = nil, volume = 0.6, kind = "sfx" },
	hit_special = { id = nil, volume = 0.7, kind = "sfx" },
	parry = { id = nil, volume = 0.6, kind = "sfx" },
	ko = { id = nil, volume = 0.7, kind = "sfx" },
	victory = { id = "rbxassetid://1844384292", volume = 0.5, kind = "sfx" }, -- APM "Sports Fanfare"
	defeat = { id = nil, volume = 0.6, kind = "sfx" },
	-- Music
	music_hub = { id = "rbxassetid://1840401478", volume = 0.25, kind = "music", looped = true }, -- APM "Yachiyo-Jishi"
	music_battle = { id = "rbxassetid://9048541013", volume = 0.25, kind = "music", looped = true }, -- APM "Battleground"
}

return table.freeze(Sounds)
