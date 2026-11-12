--!strict
-- The fighters' animation set as joint poses (MAKE_3D_EGGS_AND_FIGHTERS.md section 2): idle,
-- attack, defend (+ parry), special, hit, KO and win. Joints are the R15 Motor6D names; each pose is
-- { joint = { x, y, z } } in degrees, applied to Motor6D.Transform on the client (App/FighterAnim),
-- so no animation asset is uploaded. `root` moves the whole fighter (studs, + = toward the foe).
-- Roblox axes: +X on a shoulder raises the arm forward, -Z is forward. Hits and KOs are body motion
-- plus effects; faces never change (CLAUDE.md Asset safety rule 2).
export type Pose = { [string]: { number } }
export type Key = { t: number, pose: Pose, root: number? }
export type Action = { keys: { Key }, loop: boolean? }

local IDLE: Pose = {
	RightShoulder = { 8, 0, -6 },
	LeftShoulder = { 4, 0, 6 },
	RightElbow = { 22, 0, 0 },
	LeftElbow = { 14, 0, 0 },
	RightHip = { 0, 0, -4 },
	LeftHip = { 0, 0, 4 },
}
local IDLE_IN: Pose = table.clone(IDLE) -- breathing in: chest up, arms out a touch
IDLE_IN.Waist = { -3, 0, 0 }
IDLE_IN.Neck = { 2, 0, 0 }
IDLE_IN.RightShoulder = { 10, 0, -9 }
IDLE_IN.LeftShoulder = { 6, 0, 9 }

local Actions: { [string]: Action } = {
	idle = {
		loop = true,
		keys = { { t = 0, pose = IDLE }, { t = 1.1, pose = IDLE_IN }, { t = 2.2, pose = IDLE } },
	},
	-- a dash and a strike: wind-up, dash in, strike across, recover
	attack = {
		keys = {
			{ t = 0, pose = IDLE, root = 0 },
			{
				t = 0.14,
				root = -0.3,
				pose = {
					Waist = { 0, 25, 0 },
					RightShoulder = { 120, 0, -20 },
					RightElbow = { 50, 0, 0 },
					LeftShoulder = { -20, 0, 20 },
				},
			},
			{
				t = 0.3,
				root = 0.85,
				pose = {
					Waist = { -10, -20, 0 },
					RightShoulder = { 60, 0, 40 },
					RightElbow = { 5, 0, 0 },
					LeftShoulder = { 30, 0, 15 },
					RightHip = { 30, 0, 0 },
					LeftHip = { -25, 0, 0 },
					LeftKnee = { 30, 0, 0 },
				},
			},
			{
				t = 0.55,
				root = 0.6,
				pose = { Waist = { -5, -10, 0 }, RightShoulder = { 40, 0, 20 }, RightElbow = { 15, 0, 0 } },
			},
			{ t = 0.85, root = 0, pose = IDLE },
		},
	},
	-- guard up: both forearms crossed in front of the chest
	defend = {
		keys = {
			{ t = 0, pose = IDLE },
			{
				t = 0.12,
				pose = {
					Waist = { 6, 0, 0 },
					RightShoulder = { 80, 0, 35 },
					RightElbow = { 85, 0, 0 },
					LeftShoulder = { 80, 0, -35 },
					LeftElbow = { 85, 0, 0 },
					RightHip = { 10, 0, -6 },
					LeftHip = { -8, 0, 6 },
					RightKnee = { 15, 0, 0 },
					LeftKnee = { 15, 0, 0 },
				},
			},
			{
				t = 0.6,
				pose = {
					Waist = { 6, 0, 0 },
					RightShoulder = { 80, 0, 35 },
					RightElbow = { 85, 0, 0 },
					LeftShoulder = { 80, 0, -35 },
					LeftElbow = { 85, 0, 0 },
				},
			},
			{ t = 0.85, pose = IDLE },
		},
	},
	-- a charge (arms pulled in, crouch), then the release (arms thrown forward, the element effect)
	special = {
		keys = {
			{ t = 0, pose = IDLE },
			{
				t = 0.3,
				pose = {
					Waist = { 12, 0, 0 },
					RightShoulder = { -20, 0, -30 },
					RightElbow = { 90, 0, 0 },
					LeftShoulder = { -20, 0, 30 },
					LeftElbow = { 90, 0, 0 },
					RightHip = { 20, 0, 0 },
					LeftHip = { 20, 0, 0 },
					RightKnee = { 30, 0, 0 },
					LeftKnee = { 30, 0, 0 },
				},
			},
			{
				t = 0.45,
				root = 0.4,
				pose = {
					Waist = { -12, 0, 0 },
					Neck = { -6, 0, 0 },
					RightShoulder = { 95, 0, 10 },
					LeftShoulder = { 95, 0, -10 },
				},
			},
			{
				t = 0.8,
				root = 0.2,
				pose = { Waist = { -6, 0, 0 }, RightShoulder = { 80, 0, 10 }, LeftShoulder = { 80, 0, -10 } },
			},
			{ t = 1.1, root = 0, pose = IDLE },
		},
	},
	-- knocked back: the body rocks away, arms fly out (no face change; sparks come from the stage)
	hit = {
		keys = {
			{ t = 0, pose = IDLE, root = 0 },
			{
				t = 0.08,
				root = -0.7,
				pose = {
					Waist = { -18, 0, 0 },
					Neck = { -10, 0, 0 },
					RightShoulder = { -25, 0, -35 },
					LeftShoulder = { -25, 0, 35 },
				},
			},
			{ t = 0.45, root = 0, pose = IDLE },
		},
	},
	-- falls back to the knees and down; the stage then dissolves the fighter into element particles
	ko = {
		keys = {
			{ t = 0, pose = IDLE },
			{
				t = 0.3,
				root = -0.4,
				pose = {
					Waist = { -20, 0, 0 },
					RightShoulder = { -10, 0, -40 },
					LeftShoulder = { -10, 0, 40 },
					RightHip = { 70, 0, 0 },
					LeftHip = { 70, 0, 0 },
					RightKnee = { 90, 0, 0 },
					LeftKnee = { 90, 0, 0 },
				},
			},
			{
				t = 0.6,
				root = -0.6,
				pose = {
					Root = { -60, 0, 0 },
					Waist = { -10, 0, 0 },
					RightHip = { 40, 0, 0 },
					LeftHip = { 40, 0, 0 },
				},
			},
		},
	},
	-- the win pose: weapon arm up, the other on the hip
	win = {
		keys = {
			{ t = 0, pose = IDLE },
			{
				t = 0.35,
				pose = {
					Waist = { -6, 0, 0 },
					Neck = { -8, 0, 0 },
					RightShoulder = { 170, 0, -10 },
					RightElbow = { 10, 0, 0 },
					LeftShoulder = { 10, 0, 40 },
					LeftElbow = { 70, 0, 0 },
				},
			},
		},
	},
}

return table.freeze({
	Actions = table.freeze(Actions),
	IDLE = IDLE,
	ORDER = table.freeze({ "idle", "attack", "defend", "special", "hit", "ko", "win" }),
})
