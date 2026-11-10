--!strict
-- Studio-only (qa.project.json, under ReplicatedStorage.QA): builds card galleries in the Play-mode
-- client with the game's own App/Card, for the CARDS_EGGS_MISSION comparison images.
--   require(game.ReplicatedStorage.QA.QAGallery).rows({ size = Vector2.new(112, 157), rows = {
--     { label = "Base Lv 1", level = 1 }, ... } })
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Characters = require(ReplicatedStorage:WaitForChild("Shared").Config.Characters)

local Gallery = {}

local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

function Gallery.pick(rarity: string): string
	for _, c in Characters.List do
		if c.rarity == rarity and c.assets.cardArt ~= nil then
			return c.id
		end
	end
	for _, c in Characters.List do
		if c.rarity == rarity then
			return c.id
		end
	end
	error(rarity)
end

export type Row = { label: string, level: number?, golden: boolean?, sticker: string?, size: Vector2? }

function Gallery.clear()
	local p = Players.LocalPlayer
	local old = p.PlayerGui:FindFirstChild("Gallery")
	if old then
		old:Destroy()
	end
end

function Gallery.rows(o: { size: Vector2, rows: { Row }, gap: number?, ids: { string }? }): number
	local p = Players.LocalPlayer
	local Card = require((p :: any).PlayerScripts.Client.App.Card)
	Gallery.clear()
	local g = Instance.new("ScreenGui")
	g.Name = "Gallery"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 100
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("#08071E")
	bg.Parent = g
	local y = 30
	for _, row in o.rows do
		local size = row.size or o.size
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = row.label
		label.TextColor3 = Color3.fromHex("#C8C0FF")
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.Position = UDim2.fromOffset(16, y + size.Y / 2 - 9)
		label.Size = UDim2.fromOffset(160, 18)
		label.Parent = bg
		for i, rarity in RARITIES do
			local h = Instance.new("Frame")
			h.BackgroundTransparency = 1
			h.Position = UDim2.fromOffset(190 + (i - 1) * (size.X + (o.gap or 70)), y)
			h.Size = UDim2.fromOffset(size.X, size.Y)
			h.Parent = bg
			Card.build(h, {
				characterId = if o.ids then o.ids[i] else Gallery.pick(rarity),
				level = row.level or 1,
				golden = row.golden == true,
				sticker = row.sticker,
				size = size,
				stats = size.Y >= 150,
			})
		end
		y += size.Y + 30
	end
	g.Parent = p.PlayerGui
	return y
end

-- Plays the real hatch screen (Screens/Hatch) with injected cards, for screenshots of the rare
-- outcomes a real roll almost never gives. The cards never touch the profile: only the animation
-- runs, in its own ScreenGui. Screenshots made this way are labelled "injected".
function Gallery.hatch(eggId: string, rarities: { string }, golden: boolean?, skip: boolean?)
	local p = Players.LocalPlayer
	local App = (p :: any).PlayerScripts.Client.App
	local Hatch = require(App.Screens.Hatch) :: any
	local Eggs = require(ReplicatedStorage.Shared.Config.Eggs) :: any
	local old = p.PlayerGui:FindFirstChild("QAHatch")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "QAHatch"
	gui.DisplayOrder = 150
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(960, 540)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	local vp = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.min(vp.X / 960, vp.Y / 540)
	root.Size = UDim2.fromOffset(vp.X / scale.Scale, vp.Y / scale.Scale)
	scale.Parent = root
	gui.Parent = p.PlayerGui
	local cards = {}
	for i, r in rarities do
		table.insert(cards, { uid = `qa-{i}`, characterId = Gallery.pick(r), golden = golden == true, level = 1 })
	end
	local ctx = {
		reducedMotion = function()
			return skip == true
		end,
		overlay = function(build: (Frame) -> any)
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Size = UDim2.fromScale(1, 1)
			f.Parent = root
			local screen = build(f)
			return {
				destroy = function()
					screen.destroy()
					gui:Destroy()
				end,
			}
		end,
		request = function()
			return { ok = false, err = "QA" }
		end,
		say = function() end,
		cheer = function() end,
		warn = function() end,
		fail = function() end,
		near = function() end,
		popAt = function() end,
		fly = function() end,
		hudTarget = function() end,
		state = { view = nil },
	}
	Hatch.show(ctx, cards, Eggs.ById[eggId], golden == true, { known = {} })
end

return Gallery
