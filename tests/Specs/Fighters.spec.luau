--!strict
-- 3D fighters (MAKE_3D_EGGS_AND_FIGHTERS.md section 2): only approved characters are modelled, a
-- fighter shows in 3D only when every identity mesh is uploaded, and the animation set covers every
-- action with valid R15 joints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fighters = require(Shared.Config.Fighters)
local FighterPoses = require(Shared.Config.FighterPoses)
local Characters = require(Shared.Config.Characters)
local Cutout = require(Shared.Art.Cutout)

local MOTORS = {
	Root = true,
	Waist = true,
	Neck = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightHip = true,
	RightKnee = true,
	RightAnkle = true,
	LeftHip = true,
	LeftKnee = true,
	LeftAnkle = true,
}
local R15 = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	RightUpperArm = true,
	LeftUpperArm = true,
	RightHand = true,
	LeftHand = true,
}

return function()
	describe("Fighters", function()
		it("models only characters whose card art is approved, and the six approved ones", function()
			local n = 0
			for id in Fighters.ById do
				n += 1
				expect(Characters.ById[id]).to.be.ok()
				expect(Cutout.isTemp(id)).to.equal(false)
			end
			expect(n).to.equal(6)
			for _, held in { "rai_stormvolt", "aurelia_dawn" } do -- Zephyr Volt, Solaris: not approved
				expect(Fighters.ById[held]).to.equal(nil)
			end
		end)

		it("attaches every identity mesh to a real R15 part and has valid body colours", function()
			local defs = { Fighters.Guardian }
			for _, d in Fighters.ById do
				table.insert(defs, d)
			end
			for _, def in defs do
				for _, c in def.colors :: any do
					expect(Color3.fromHex(c :: string)).to.be.ok()
				end
				for _, p in def.parts do
					expect(R15[p.attach]).to.equal(true)
				end
			end
			expect(Fighters.Guardian.scale).to.equal(1.8)
			expect(#Fighters.GuardianTheme).to.equal(10)
		end)

		it("shows a fighter in 3D only when all its meshes are uploaded", function()
			expect(Fighters.ready(nil)).to.equal(false)
			local def = Fighters.ById.yuki_frostveil
			expect(Fighters.ready(def)).to.equal(false) -- nothing is uploaded before the owner's OK
			local full = table.clone(def)
			full.parts = {}
			for name, p in def.parts do
				full.parts[name] = { attach = p.attach, mesh = "rbxassetid://1" }
			end
			expect(Fighters.ready(full)).to.equal(true)
			local partial = table.clone(full)
			partial.parts = table.clone(full.parts)
			partial.parts.Head = { attach = "Head" }
			expect(Fighters.ready(partial)).to.equal(false)
		end)
	end)

	describe("Fighter animation set", function()
		it(
			"has idle, attack, defend, special, hit, KO and win, keys in time order, R15 joints only",
			function()
				for _, name in FighterPoses.ORDER do
					local action = FighterPoses.Actions[name]
					expect(action).to.be.ok()
					expect(#action.keys >= 2).to.equal(true)
					for i, key in action.keys do
						if i > 1 then
							expect(key.t > action.keys[i - 1].t).to.equal(true)
						end
						for joint, v in key.pose do
							expect(MOTORS[joint]).to.equal(true)
							expect(#v).to.equal(3)
						end
					end
					-- actions stay short (the battle plays them between events); idle loops
					expect(action.keys[#action.keys].t <= 2.2).to.equal(true)
				end
				expect(FighterPoses.Actions.idle.loop).to.equal(true)
			end
		)
	end)
end
