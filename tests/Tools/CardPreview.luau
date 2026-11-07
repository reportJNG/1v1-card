--!strict
-- Studio-only (dev.project.json): galleries of the cards for screenshots and visual QA.
--   local G = require(game.ServerScriptService.Tests.Tools.CardPreview)
--   G.show()                                   -- every rarity: level 1, level 15 and Golden
--   G.show({ big = true, rarity = "Mythical" })  -- one rarity, large (inspect size)
--   G.grid({ size = Vector2.new(140, 196), rarities = {...}, variants = { { level = 5 } }, columns = 5 })
--   G.clear()
-- Cards are built with App/Card exactly as the screens build them, on the boards' background.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Characters = require(ReplicatedStorage.Shared.Config.Characters)

local AppFolder = StarterPlayer.StarterPlayerScripts:WaitForChild("Client"):WaitForChild("App")
local Card = require(AppFolder.Card) :: any
local Theme = require(AppFolder.Theme) :: any

local CardPreview = {}

local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

export type Variant = {
	level: number?,
	golden: boolean?,
	sticker: string?,
	favorite: boolean?,
	characterId: string?,
	tag: string?,
}

export type GridOptions = {
	size: Vector2?,
	rarities: { string }?,
	variants: { Variant }?,
	columns: number?,
	labels: boolean?,
	byVariant: boolean?, -- rows are variants (columns rarities) instead of rows of rarities
	interactive: boolean?,
}

-- The first enabled character of each rarity, in catalog order (stable between runs), or the first
-- one with card art when `withArt`.
function CardPreview.pick(rarity: string, withArt: boolean?): string
	for _, c in Characters.List do
		if c.rarity == rarity and c.enabled and (not withArt or c.assets.cardArt ~= nil) then
			return c.id
		end
	end
	if withArt then
		return CardPreview.pick(rarity, false)
	end
	error(`no {rarity} character`)
end

function CardPreview.clear()
	local old = StarterGui:FindFirstChild("CardPreview")
	if old then
		old:Destroy()
	end
end

function CardPreview.grid(o: GridOptions): string
	CardPreview.clear()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CardPreview"
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- as the game's own ScreenGui (App.start)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromHex("#08071E")
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local size = o.size or Vector2.new(140, 196)
	local labels = o.labels ~= false
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(size.X + 34, size.Y + (if labels then 40 else 26))
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = o.columns or 5
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.Parent = bg
	local rarities = o.rarities or RARITIES
	local variants: { Variant } = o.variants or { { level = 1 } }
	local made = {}
	local order = 0
	local function cell(rarity: string, v: Variant)
		order += 1
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = order
		holder.Parent = bg
		local id = v.characterId or CardPreview.pick(rarity, true)
		local card = Card.build(holder, {
			characterId = id,
			level = v.level or 1,
			golden = v.golden == true,
			sticker = v.sticker,
			favorite = v.favorite,
			size = size,
			interactive = o.interactive ~= false,
		})
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 14)
		if labels then
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Text = v.tag or `{rarity} · Lv {v.level or 1}{if v.golden then " · Golden" else ""}`
			label.TextColor3 = Theme.Color.Muted
			label.FontFace = Theme.Face.Bold
			label.TextSize = 12
			label.Position = UDim2.new(0, 0, 1, -16)
			label.Size = UDim2.new(1, 0, 0, 16)
			label.Parent = holder
		end
		table.insert(made, `{id}:{v.level or 1}`)
	end
	if o.byVariant then
		for _, v in variants do
			for _, rarity in rarities do
				cell(rarity, v)
			end
		end
	else
		for _, rarity in rarities do
			for _, v in variants do
				cell(rarity, v)
			end
		end
	end
	gui.Parent = StarterGui
	return table.concat(made, ", ")
end

function CardPreview.show(opts: { big: boolean?, rarity: string? }?): string
	local o: { big: boolean?, rarity: string? } = opts or {}
	return CardPreview.grid({
		size = if o.big then Vector2.new(220, 308) else Vector2.new(120, 168),
		rarities = if o.rarity then { o.rarity :: string } else nil,
		variants = { { level = 1 }, { level = 15 }, { level = 1, golden = true } },
		columns = if o.big then 3 else 5,
		byVariant = not o.big,
	})
end

return CardPreview
