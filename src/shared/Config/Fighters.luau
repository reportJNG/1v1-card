--!strict
-- 3D fighters (MAKE_3D_EGGS_AND_FIGHTERS.md section 2). Cards decide who fights; these say what the
-- fighter looks like in 3D: the standard R15 rig (Roblox's own, built from a HumanoidDescription, so
-- no body mesh is uploaded) in the character's BodyColors, plus the identity meshes made in Blender
-- (scripts/blender/fighters.py): hair, coat, scarf or collar, chains, armour and the weapon.
--   colors   BodyColors: head (skin), torso, arms, legs
--   parts    one mesh per R15 part it is welded to (exported with that part's centre as origin);
--            `mesh` / `texture` stay empty until the owner approves docs/review/3d_fighters.png and
--            the upload is done
-- Only approved characters are listed. Until every part of a fighter has its mesh, the battle stage
-- shows the character's standee (Shared/Art/Standee): primitive parts are never stacked into a
-- stand-in character.
export type Part = { attach: string, mesh: string?, texture: string? }
export type Fighter = {
	colors: { head: string, torso: string, arms: string, legs: string },
	parts: { [string]: Part },
	scale: number,
}

local SKIN = "#F2D2BC"

local function parts(names: { [string]: string }): { [string]: Part }
	local out: { [string]: Part } = {}
	for name, attach in names do
		out[name] = { attach = attach }
	end
	return out
end

-- The groups every fighter exports: head (hair, mask), chest (collar or scarf, lapels, chains),
-- hips (coat, belt), shoulders (pads) and the weapon or effect in the hands.
local STANDARD = {
	Head = "Head",
	Chest = "UpperTorso",
	Hips = "LowerTorso",
	Weapon = "RightHand",
}

local function with(extra: { [string]: string }): { [string]: string }
	local t = table.clone(STANDARD)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local ById: { [string]: Fighter } = {
	ren_emberfang = { -- Rook Emberforge
		colors = { head = SKIN, torso = "#1C1214", arms = "#1C1214", legs = "#1C1214" },
		parts = parts(with({ WeaponLeft = "LeftHand" })), -- a fire fist on each hand
		scale = 1,
	},
	yuki_frostveil = { -- Halvard Frostwarden
		colors = { head = SKIN, torso = "#141822", arms = "#141822", legs = "#141822" },
		parts = parts(with({ PadRight = "RightUpperArm", PadLeft = "LeftUpperArm" })),
		scale = 1,
	},
	vesper_shade = { -- Nox Veilstrider
		colors = { head = SKIN, torso = "#121018", arms = "#121018", legs = "#121018" },
		parts = parts(STANDARD),
		scale = 1,
	},
	kael_voidbinder = {
		colors = { head = SKIN, torso = "#1A1426", arms = "#2A2140", legs = "#121018" },
		parts = parts(with({ PadRight = "RightUpperArm", PadLeft = "LeftUpperArm" })),
		scale = 1,
	},
	brann_cinderfall = {
		colors = { head = SKIN, torso = "#1A1012", arms = "#1A1012", legs = "#1A1012" },
		parts = parts(STANDARD),
		scale = 1,
	},
	aurex_sunforge = {
		colors = { head = SKIN, torso = "#F4EEDF", arms = "#1A1612", legs = "#1A1612" },
		parts = parts(with({ PadRight = "RightUpperArm", PadLeft = "LeftUpperArm", Halo = "UpperTorso" })),
		scale = 1,
	},
}

-- The Guardian: an original stone-and-light golem knight, 1.8x, with its world's colour on the
-- glowing seams, visor and crest (a runtime tint; one set of meshes).
local Guardian: Fighter = {
	colors = { head = "#8A8F9E", torso = "#8A8F9E", arms = "#5A5E6C", legs = "#5A5E6C" },
	parts = parts({
		Helm = "Head",
		Chest = "UpperTorso",
		Hips = "LowerTorso",
		PadRight = "RightUpperArm",
		PadLeft = "LeftUpperArm",
		Sword = "RightHand",
		Shield = "LeftHand",
	}),
	scale = 1.8,
}

-- The Guardian's glow colour per world (1-10).
local GuardianTheme = {
	"#7CFF6B",
	"#C77DFF",
	"#FFB45A",
	"#5BE0FF",
	"#FF6A3D",
	"#FF2E5C",
	"#9CFFD6",
	"#FF6A3D",
	"#B9A0FF",
	"#FFE27A",
}

local Fighters = {}

Fighters.ById = table.freeze(ById)
Fighters.Guardian = Guardian
Fighters.GuardianTheme = table.freeze(GuardianTheme)
Fighters.SKIN = SKIN

-- Whether a fighter's identity meshes are all uploaded (then the stage shows the 3D rig).
function Fighters.ready(def: Fighter?): boolean
	if def == nil then
		return false
	end
	local any = false
	for _, p in def.parts do
		any = true
		if p.mesh == nil or p.mesh == "" then
			return false
		end
	end
	return any
end

return table.freeze(Fighters)
