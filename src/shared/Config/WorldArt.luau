--!strict
-- Art for the world picker (Screens/Worlds): one thumbnail per world. Until the owner's key art
-- exists these are Studio captures of each built world (docs/screens/worlds, cropped to 384x216 in
-- art/worlds/TEMP_world_thumb_<n>.png and uploaded). TEMP: they show the first-pass world art
-- (ContentStatus: worldArt). A world with no thumbnail shows its theme colours.

local thumbnails: { [number]: string } = {
	[1] = "rbxassetid://138457136896744",
	[2] = "rbxassetid://76971398451649",
	[3] = "rbxassetid://115565083153034",
	[4] = "rbxassetid://71229341370515",
	[5] = "rbxassetid://121851373581660",
	[6] = "rbxassetid://96863356027227",
	[7] = "rbxassetid://110642474516329",
	[8] = "rbxassetid://95400898165081",
	[9] = "rbxassetid://133193596349476",
	[10] = "rbxassetid://137546851733432",
}

return table.freeze({ thumbnails = table.freeze(thumbnails) })
