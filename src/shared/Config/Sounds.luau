--!strict
-- Every sound slot the game plays (docs/ART_STYLE.md section 7). `id` is a Creator Store audio asset
-- listed in docs/ASSETS.md; a slot with no id stays silent (the game never plays a stand-in sound).
-- Only Roblox's licensed libraries are used: APMOfficial (APM Music) and ProSoundEffects (PSE).
-- Volumes are relative (0-1); the client applies the player's music/SFX settings on top.

export type Sound = { id: string?, volume: number, kind: "sfx" | "music", looped: boolean? }

local Sounds: { [string]: Sound } = {
	-- UI
	click = { id = "rbxassetid://9119717523", volume = 0.5, kind = "sfx" }, -- PSE "Switch Click On Or Off Toggle Button 2"
	hover = { id = "rbxassetid://9119717529", volume = 0.12, kind = "sfx" }, -- PSE "Switch Click On Or Off Toggle Button 1"
	open = { id = "rbxassetid://1837834196", volume = 0.25, kind = "sfx" }, -- APM "Reverse Quick Swipe - Light Swipe 02"
	close = { id = "rbxassetid://9120972321", volume = 0.25, kind = "sfx" }, -- PSE "Wood Whoosh Slicing Air Quick Swings 4"
	coin = { id = "rbxassetid://9113849492", volume = 0.45, kind = "sfx" }, -- PSE "Coins Or Keys Jingle 6"
	error = { id = "rbxassetid://9113085764", volume = 0.25, kind = "sfx" }, -- PSE "Alarm Buzzer 5"
	purchase = { id = "rbxassetid://9113704038", volume = 0.45, kind = "sfx" }, -- PSE "Candy Machine Coin Drops Insert Vending 4"
	-- MISSION 9 slots. Each reuses an id from the licensed APM / PSE set above (already checked to
	-- load), so no unvetted audio enters the game; all are "unreviewed" for the owner (ASSETS.md).
	confirm = { id = "rbxassetid://9116395089", volume = 0.3, kind = "sfx" }, -- PSE "Magic Glows ... Chiming Hits 4"
	tab = { id = "rbxassetid://9125434359", volume = 0.15, kind = "sfx" }, -- PSE (as tick)
	toast = { id = "rbxassetid://9116394545", volume = 0.22, kind = "sfx" }, -- PSE "Magic Glows ... Chiming Hits 1"
	equip = { id = "rbxassetid://9119072660", volume = 0.3, kind = "sfx" }, -- PSE "Shield Clang ..." (as parry, softer)
	leave = { id = "rbxassetid://9120972321", volume = 0.35, kind = "sfx" }, -- PSE "Wood Whoosh ... 4" (as close)
	queue_search = { id = "rbxassetid://9125434359", volume = 0.12, kind = "sfx" }, -- PSE (as tick), each second while searching
	queue_found = { id = "rbxassetid://9116395085", volume = 0.5, kind = "sfx" }, -- PSE "Magic Glows ... Chiming Hits 5"
	pick_attack = { id = "rbxassetid://9120972444", volume = 0.35, kind = "sfx" }, -- PSE "Wood Whoosh ... 1"
	pick_defend = { id = "rbxassetid://9119072660", volume = 0.25, kind = "sfx" }, -- PSE "Shield Clang ..."
	pick_special = { id = "rbxassetid://9125648149", volume = 0.35, kind = "sfx" }, -- PSE "Magic Zoom Up ... Whoosh 8"
	-- Rewards
	merge = { id = "rbxassetid://9116406610", volume = 0.55, kind = "sfx" }, -- PSE "Magic Poofs Thumpy Wheezy Exhale 1"
	level_up = { id = "rbxassetid://94590027038118", volume = 0.5, kind = "sfx" }, -- APM "Victorious Journey Sting"
	-- Hatching (Screens/Hatch): every beat, then one reveal per best rarity
	hatch_summon = { id = "rbxassetid://9116395085", volume = 0.35, kind = "sfx" }, -- PSE "Magic Glows ... 5" (summon)
	sparkle = { id = "rbxassetid://9116394545", volume = 0.25, kind = "sfx" }, -- PSE "Magic Glows ... 1"
	hatch_shake = { id = "rbxassetid://9116797024", volume = 0.3, kind = "sfx" }, -- PSE "Metal Rattle Thick Shake 2"
	hatch_crack = { id = "rbxassetid://9113959343", volume = 0.7, kind = "sfx" }, -- PSE "Crack Egg Crunchy 11"
	hatch_burst = { id = "rbxassetid://9125648149", volume = 0.6, kind = "sfx" }, -- PSE "Magic Zoom Up Sharp Tubular Whoosh Fast Hiss 8"
	card_flip = { id = "rbxassetid://9120972444", volume = 0.3, kind = "sfx" }, -- PSE "Wood Whoosh Slicing Air Quick Swings 1"
	reveal_common = { id = "rbxassetid://9116394545", volume = 0.4, kind = "sfx" }, -- PSE "Magic Glows Soft Clusters Of Chiming Hits 1"
	reveal_rare = { id = "rbxassetid://9116395089", volume = 0.5, kind = "sfx" }, -- PSE "Magic Glows Soft Clusters Of Chiming Hits 4"
	reveal_epic = { id = "rbxassetid://9116395085", volume = 0.6, kind = "sfx" }, -- PSE "Magic Glows Soft Clusters Of Chiming Hits 5"
	reveal_legendary = { id = "rbxassetid://9042730928", volume = 0.6, kind = "sfx" }, -- APM "Homeland (sting)"
	reveal_mythical = { id = "rbxassetid://9045742086", volume = 0.65, kind = "sfx" }, -- APM "To the Fray (sting b)"
	-- Battle
	tick = { id = "rbxassetid://9125434359", volume = 0.2, kind = "sfx" }, -- PSE "Cell Phone Volume Button Pressing Double Clicks 36"
	hit = { id = "rbxassetid://9120728815", volume = 0.6, kind = "sfx" }, -- PSE "Whoosh Heavy Punches 1"
	hit_special = { id = "rbxassetid://9125404320", volume = 0.6, kind = "sfx" }, -- PSE "Boom Impact Deep Distant Thumping Hits Booming 36"
	parry = { id = "rbxassetid://9119072660", volume = 0.6, kind = "sfx" }, -- PSE "Shield Clang As Hit Metal Sword Hubcap 1"
	ko = { id = "rbxassetid://9113225986", volume = 0.7, kind = "sfx" }, -- PSE "Axe Impact Giant Thuddy Hits On Wood Floor 5"
	thunder = { id = "rbxassetid://9120016256", volume = 0.45, kind = "sfx" }, -- PSE "Thunder Cracks Big Rumbling Blasts Booming 3" (Storm Rooftop)
	victory = { id = "rbxassetid://1844384292", volume = 0.5, kind = "sfx" }, -- APM "Sports Fanfare"
	defeat = { id = "rbxassetid://125909120236588", volume = 0.5, kind = "sfx" }, -- APM "Mounting Consequences StingA"
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
	-- One track per battle arena (Config/Arenas). APMOfficial, picked by title and description;
	-- the owner should listen and confirm (docs/WAITING_ON_YOU.md).
	music_arena_sakura = { id = "rbxassetid://9038221558", volume = 0.25, kind = "music", looped = true }, -- APM "Tairitsu" (taiko hybrid)
	music_arena_frozen = { id = "rbxassetid://9039666736", volume = 0.25, kind = "music", looped = true }, -- APM "Magical Night (b)"
	music_arena_volcano = { id = "rbxassetid://1839685565", volume = 0.25, kind = "music", looped = true }, -- APM "Light The Fire"
	music_arena_celestial = { id = "rbxassetid://9038610306", volume = 0.25, kind = "music", looped = true }, -- APM "A Heroic Legend No Choir"
	music_arena_storm = { id = "rbxassetid://9046674561", volume = 0.25, kind = "music", looped = true }, -- APM "Taiko Thunderstorm--ALT. 1"
	-- Lobby ambience (FIX_LOBBY_2 B3): looped, placed at their spots (Config/LobbyDecor.Ambient), SFX volume
	ambient_fountain = { id = "rbxassetid://9120557629", volume = 0.35, kind = "sfx", looped = true }, -- PSE "Water Fountain 1"
	ambient_waterfall = { id = "rbxassetid://9120552550", volume = 0.45, kind = "sfx", looped = true }, -- PSE waterfall, steady stream
	ambient_chimes = { id = "rbxassetid://9120750072", volume = 0.3, kind = "sfx", looped = true }, -- PSE wind chimes
	ambient_wind = { id = "rbxassetid://9119643864", volume = 0.3, kind = "sfx", looped = true }, -- PSE "Storm Drain Presence" (soft wind)
}

return table.freeze(Sounds)
