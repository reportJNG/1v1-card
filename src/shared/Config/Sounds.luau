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
	music_menu = { id = "rbxassetid://1837864564", volume = 0.25, kind = "music", looped = true }, -- APM "Team of Heroes (Mus)"
	music_hub = { id = "rbxassetid://1840401478", volume = 0.25, kind = "music", looped = true }, -- APM "Yachiyo-Jishi"
	music_battle = { id = "rbxassetid://9048541013", volume = 0.25, kind = "music", looped = true }, -- APM "Battleground"
	-- One track per world (App/AreaFx plays music_world<n>). Picked from APMOfficial by title and
	-- description only; the owner should listen and confirm (docs/WAITING_ON_YOU.md).
	music_world1 = { id = "rbxassetid://1836352521", volume = 0.25, kind = "music", looped = true }, -- APM "Sunny Sights"
	music_world2 = { id = "rbxassetid://1838926651", volume = 0.25, kind = "music", looped = true }, -- APM "Natural Planet"
	music_world3 = { id = "rbxassetid://1840540809", volume = 0.25, kind = "music", looped = true }, -- APM "Sunset Song"
	music_world4 = { id = "rbxassetid://9039666736", volume = 0.25, kind = "music", looped = true }, -- APM "Magical Night (b)"
	music_world5 = { id = "rbxassetid://1839685565", volume = 0.25, kind = "music", looped = true }, -- APM "Light The Fire"
	music_world6 = { id = "rbxassetid://9043600381", volume = 0.25, kind = "music", looped = true }, -- APM "Mystery Mansion (b)"
	music_world7 = { id = "rbxassetid://1844581845", volume = 0.25, kind = "music", looped = true }, -- APM "Space Fantasy"
	music_world8 = { id = "rbxassetid://1838829561", volume = 0.25, kind = "music", looped = true }, -- APM "Mysterious Gate"
	music_world9 = { id = "rbxassetid://9044407121", volume = 0.25, kind = "music", looped = true }, -- APM "Back to the Shadows Underscore"
	music_world10 = { id = "rbxassetid://1840939025", volume = 0.25, kind = "music", looped = true }, -- APM "Ideal World (a)"
}

return table.freeze(Sounds)
