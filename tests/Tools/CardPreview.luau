--!strict
-- Studio-only (dev.project.json): a gallery of the layered cards for screenshots and visual QA.
--   local G = require(game.ServerScriptService.Tests.Tools.CardPreview)
--   G.show()            -- one character per rarity: level 1, level 15 and Golden, side by side
--   G.show({ big = true, rarity = "Mythical" })  -- one rarity, large (inspect size)
--   G.clear()
-- Cards are built with App/Card exactly as the screens build them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Characters = require(ReplicatedStorage.Shared.Config.Characters)

local AppFolder = StarterPlayer.StarterPlayerScripts:WaitForChild("Client"):WaitForChild("App")
local Card = require(AppFolder.Card) :: any
local Theme = require(AppFolder.Theme) :: any

local CardPreview = {}

local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

-- The first enabled character of each rarity, in catalog order (stable between runs).
local function pick(rarity: string): string
	for _, c in Characters.List do
		if c.rarity == rarity and c.enabled then
			return c.id
		end
	end
	error(`no {rarity} character`)
end

function CardPreview.clear()
	local old = StarterGui:FindFirstChild("CardPreview")
	if old then
		old:Destroy()
	end
end

function CardPreview.show(opts: { big: boolean?, rarity: string? }?): string
	CardPreview.clear()
	local o: { big: boolean?, rarity: string? } = opts or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "CardPreview"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- as the game's own ScreenGui (App.start)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Color.Background
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grid = Instance.new("UIGridLayout")
	local size = if o.big then Vector2.new(220, 308) else Vector2.new(120, 168)
	grid.CellSize = UDim2.fromOffset(size.X + 10, size.Y + 26)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = if o.big then 3 else 5
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.Parent = bg
	local rows: { string } = if o.rarity then { o.rarity :: string } else RARITIES
	local made = {}
	local order = 0
	-- Columns are rarities in the compact gallery (rows: level 1, level 15, Golden level 1).
	local variants = {
		{ level = 1, golden = false, tag = "Lv 1" },
		{ level = 15, golden = false, tag = "Lv 15" },
		{
			level = 1,
			golden = true,
			tag = "Golden",
		},
	}
	local function cell(rarity: string, v: { level: number, golden: boolean, tag: string })
		order += 1
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = order
		holder.Parent = bg
		local id = pick(rarity)
		Card.build(
			holder,
			{ characterId = id, level = v.level, golden = v.golden, size = size, interactive = true }
		)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Text = `{rarity} · {v.tag}`
		label.TextColor3 = Theme.Color.Muted
		label.FontFace = Theme.Face.Bold
		label.TextSize = 13
		label.Position = UDim2.new(0, 0, 1, -20)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Parent = holder
		table.insert(made, `{id}:{v.tag}`)
	end
	if o.big then
		for _, rarity in rows do
			for _, v in variants do
				cell(rarity, v)
			end
		end
	else
		for _, v in variants do
			for _, rarity in rows do
				cell(rarity, v)
			end
		end
	end
	gui.Parent = StarterGui
	return table.concat(made, ", ")
end

return CardPreview
