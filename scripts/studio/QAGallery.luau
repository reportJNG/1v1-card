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

return Gallery
