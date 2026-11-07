--!strict
-- Shared type definitions for 1v1 CARD.
-- Content types describe read-only config. Profile types describe what is persisted.
-- Nothing here holds a value the server would trust from a client.

-- ---------------------------------------------------------------- content

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythical"

export type Family =
	"Dragon"
	| "Shadow"
	| "Demon"
	| "Divine"
	| "Warrior"
	| "Flame"
	| "Ice"
	| "Lightning"
	| "Spirit"
	| "Beast"
	| "Ninja"
	| "Royal"
	| "Cosmic"
	| "Ancient"
	| "Mystic"

export type Role = "Striker" | "Guardian" | "Skirmisher" | "Trickster" | "Support" | "Bruiser"

export type StatName = "hp" | "atk" | "def" | "spd" | "crit"

export type Stats = { hp: number, atk: number, def: number, spd: number }

export type StatusName = "Burn" | "Chill" | "Weaken" | "Shield" | "Reflect"

-- status and target are plain strings for the type checker; ConfigValidator enforces the values.
export type StatusApplication = {
	status: string, -- StatusName
	target: string, -- "Self" | "Opponent"
	rounds: number,
	value: number, -- meaning depends on status: Burn = fraction of max HP per round, Shield = fraction of max HP
}

export type AbilityKind = "Damage" | "Shield" | "Heal" | "Stance"

export type AbilityDef = {
	id: string,
	displayName: string,
	cost: number, -- energy, 2..4
	kind: AbilityKind,
	multiplier: number?, -- Damage abilities
	priority: boolean?, -- resolves before normal actions
	pierceGuard: number?, -- 0..1 of the opponent's guard ignored
	armorPen: number?, -- 0..1 of the opponent's DEF ignored
	healFraction: number?, -- Heal abilities: fraction of max HP
	shieldFraction: number?, -- Shield abilities: absorb equal to this fraction of max HP (lasts until used up)
	blockFraction: number?, -- Stance abilities: damage blocked this round
	reflectFraction: number?, -- Stance abilities: fraction of the incoming hit reflected
	recoilFraction: number?, -- fraction of own max HP lost after use
	cleanse: boolean?,
	applies: { StatusApplication }?,
}

-- What a passive does in battle. kind is a plain string for the type checker; the validator
-- enforces the values:
--   BonusVsStatus  +value damage against a target that has `status`
--   CritBonus      +value crit chance (points, 0.05 = +5%)
--   Lifesteal      basic Attacks heal for value x damage dealt
--   LowHpStat      +value to `stat` ("atk" | "def") while HP < threshold x max HP
--   EnergyOnFirst  +value Energy when this card acts first in a round
export type PassiveEffect = {
	kind: string,
	value: number,
	status: string?,
	stat: string?,
	threshold: number?,
}

export type PassiveDef = {
	id: string,
	displayName: string,
	description: string,
	effect: PassiveEffect,
}

-- The written art brief for a character. Colours are hex: the family body and accent colours
-- (Config/Art.FamilyColors) plus one personal colour.
export type CharacterLook = {
	personality: string,
	outfit: string,
	colors: { string },
	weapon: string,
	silhouette: string,
}

export type CharacterDef = {
	id: string, -- stable forever, never reused
	displayName: string,
	family: Family,
	rarity: Rarity,
	role: Role,
	special: AbilityDef,
	passive: PassiveDef,
	enabled: boolean, -- false hides a character from pools without touching saves
	look: CharacterLook, -- art brief (docs/ART_STYLE.md section 5, art/characters/PROMPTS.md)
	assets: {
		model: string?, -- rbxassetid, set when the model is approved (M2)
		cardArt: string?,
		portrait: string?,
	},
}

export type RarityDef = {
	order: number,
	color: Color3,
	statBudget: number, -- fraction added to role base stats
	mergePoints: number, -- points a spare copy gives when merged
}

export type RoleDef = {
	base: Stats, -- level 1, Common
}

export type FamilyDef = {
	bonusStat: string, -- StatName; ConfigValidator enforces the values
}

export type OddsBandId = "A" | "B" | "C" | "D" | "E" | "Event"

export type RarityOdds = { [string]: number } -- Rarity -> percent, each band totals 100

export type EggIcon = {
	normalFile: string, -- path inside the Eggs Icon Pack, for the asset pipeline
	goldenFile: string?,
	normalAssetId: string?, -- rbxassetid://..., set after upload + moderation
	goldenAssetId: string?,
	contentBox: { x: number, y: number, width: number, height: number }, -- visible pixels in the 256 px file
}

-- "Placeholder" content is structurally valid but not final design data. Release mode refuses it.
export type ContentStatus = "Placeholder" | "Final"

export type EggDef = {
	id: string,
	status: ContentStatus, -- pool, odds band and price are all placeholders until the roster is designed
	displayName: string,
	world: number?, -- 1..10; nil for event eggs
	oddsBand: OddsBandId,
	coinPrice: number?, -- nil = not sold for Coins
	pool: { [string]: { string } }, -- Rarity -> character ids; equal share inside a rarity
	goldenAllowed: boolean,
	robuxPurchasable: boolean, -- sold as Developer Products (only ever for unlocked worlds)
	hiddenUntilQuest: string?, -- quest id that reveals the egg (Secret Egg)
	icon: EggIcon,
}

export type WorldDef = {
	id: number,
	displayName: string,
	trophiesToUnlock: number,
	eggs: { string },
}

export type LeagueDef = {
	id: string,
	minTrophies: number,
	rankedLevelCap: number,
}

export type RobuxEggProduct = {
	key: string, -- stable key used in receipts handling, e.g. "egg_dragon_x1"
	eggId: string,
	quantity: number,
	productId: number?, -- Developer Product id; nil until created on the Creator Dashboard
}

export type ItemDef = {
	id: string,
	displayName: string,
	world: number,
	maxStack: number,
	sellPrice: number, -- Coins per unit at the NPC merchant
	rare: boolean, -- the world's rare resource (shown in gold at the merchant)
}

-- ---------------------------------------------------------------- persisted

-- How a single card copy entered the game. Never changes after creation.
export type Origin = "Coins" | "Robux" | "Reward" | "Daily"

-- Provenance of everything merged into a card. Kept forever, so a card that ever
-- absorbed a Robux-egg copy stays identifiable as paid, whatever happens later.
export type Provenance = {
	absorbed: { [string]: number }, -- Origin -> count of copies merged in
	paidRefs: { string }, -- Robux PurchaseIds of this copy and every copy merged into it
	paidLineage: boolean, -- true if this copy or anything merged into it came from a Robux egg
}

export type CardCopy = {
	uid: string,
	characterId: string,
	level: number, -- 1..MaxLevel
	mergePoints: number, -- toward the next level
	golden: boolean, -- cosmetic foil
	origin: Origin,
	originRef: string?, -- PurchaseId for Robux, egg id / reward id otherwise
	obtainedAt: number,
	provenance: Provenance,
	lockedBy: string?, -- reserved for V2 marketplace listings; locked copies can't be merged, sold or decked
}

export type ItemStack = { itemId: string, count: number }

-- A Robux receipt that arrived while the player was not eligible (restricted, unknown policy,
-- locked world). It stays unresolved with Roblox and is logged here for support.
export type HeldReceipt = {
	productId: number,
	reason: string,
	firstSeen: number,
	lastSeen: number,
	count: number,
}

export type LedgerEntry = {
	t: number,
	currency: string,
	delta: number,
	balance: number,
	reason: string,
	ref: string,
}

export type PlayerProfile = {
	schemaVersion: number,
	coins: number,
	gems: number,
	trophies: number,
	highestTrophies: number, -- worlds unlock from this, so a lost match never re-locks a world
	cards: { [string]: CardCopy }, -- uid -> copy
	cardSlots: number,
	uidPrefix: string, -- the owner's UserId at creation; makes card uids unique across all players
	nextCardSerial: number, -- uid generator; uids are never reused
	deck: { string }, -- 3 card uids
	eggBag: { [string]: { normal: number, golden: number } },
	items: { slots: number, stacks: { ItemStack } },
	daily: { streakDay: number, lastClaimDay: number, freeEggDay: number, winsToday: number, dayKey: number },
	quests: { [string]: { progress: number, claimed: boolean } },
	settledMatches: { [string]: number }, -- matchId -> time; settlement idempotency
	processedReceipts: { [string]: number }, -- Robux PurchaseId -> time; receipt idempotency
	heldReceipts: { [string]: HeldReceipt }, -- receipts the player wasn't eligible for; never granted until eligible
	recentTx: { [string]: number }, -- transaction ref -> time; request idempotency (pruned)
	ledger: { LedgerEntry }, -- last N currency events, for support
	flags: { tutorialDone: boolean?, starterGranted: boolean? },
	-- schema v2
	currentWorld: number, -- world the player last travelled to (must be unlocked)
	opponentsToday: { [string]: number }, -- opponent userId -> ranked matches today (anti-farming)
	questDay: number, -- day the daily quests were rolled
	trials: { [string]: number }, -- worldId -> first Guardian Trial clear time
	stats: { wins: number, losses: number, matches: number, trialsCleared: number },
	settings: { music: boolean, sfx: boolean, reducedMotion: boolean, musicVolume: number, sfxVolume: number },
	-- schema v3
	harvests: { [string]: number }, -- nodeId -> os.time of this player's last harvest (respawn timers)
}

-- ---------------------------------------------------------------- results

export type Result<T> = { ok: true, value: T } | { ok: false, err: string }

return nil
