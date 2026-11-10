# 1v1 CARD — Game Design & Technical Foundation

 · 

## Summary and where I'm challenging the brief

Your twelve decisions hold up, with four changes I'm recommending after testing the battle rules in more than 150,000 simulated matches. Nothing has been built in Studio yet. Place1 is still empty and stays that way until you sign off on this doc.

Decisions locked on 6 Nov 2026:

| # | Decision | What it changes |
| --- | --- | --- |
| Q1 | Guardian Trials: yes | One PvE trial per world with a one-time trophy grant. It stays outside competitive matchmaking |
| Q2 | Max level 15 for every rarity | +0.75% per level (max +10.5%). Ranked league caps 4 / 8 / 12 / 15 (section 2) |
| Q3 | Counter-loop battle rules: yes | They're the base for the Luau battle engine in M3 |
| Q4 | Robux buys eggs and cosmetics only | Robux eggs are paid random items: exact odds, a PolicyService gate and safe receipts. No Coin packs, XP boosts or trophy boosts (sections 2 and 7) |
| Q11 | Player store: players sell cards to each other for Coins | Opens in V2. The save format, listing locks and Coin fee are designed now and built in M1 (section 2) |
| — | Card model: copies plus merging | Each hatch is a card copy, and spare copies merge into a card to level it. This replaces Fragments |

What the simulation changed:
- 

Attack / Defend / Special as first drafted turned into "spam Special". A player who used Special whenever it was ready beat careful play 73% of the time. The fixed rules make the three actions a counter loop: Special beats Attack, Defend parries Special, Attack beats Defend (section 3).
- 

A different max level per rarity breaks competition. Max levels of 6 to 12 by rarity gave a maxed high-rarity team 93–100% wins. Decided: every rarity shares max level 15 (Q2), at +0.75% per level. Rarity changes drop odds, a small stat budget (+0–8%) and ability depth, not the progression ceiling.
- 

Speed as a strict turn order was a cliff. In mirror matches, a 6% speed edge won 98% of games. Speed now raises your chance to act first, capped at 80%.
- 

Family synergy must stay small. +6% to one stat swung random matchups to 62–64%. Recommended: 2 of a family +2%, 3 of a family +3% (51–56% in tests).

Contradictions that need your call:
- 

Trophies gate worlds, there are no bots, and matchmaking is cross-server only. At low player counts, a new player can be stuck in World 1 with nobody to fight. I propose one PvE "Guardian Trial" per world that awards a one-time trophy grant. It stays outside competitive matchmaking. Agreed (Q1).
- 

The reference boards show features you've ruled out. They show Bet & Fight, AFK Farm, eggs priced in gems (Open Again 399 gems), "+" buttons that sell currency, a VIP pass and a trading panel. They stay mood boards only. Building to them as screens would reintroduce what you removed.
- 

Coins can't be sold for Robux in V1. Robux eggs (Q4) are already paid random items. Keeping Coins unsold stops every coin price and coin egg from falling under the same rules as well (section 7).
- 

The egg license forbids editing the icons in a commercial game. So there's no recoloured Golden Rainbow (the pack has none) and no cracks painted onto icons. Hatch effects become separate overlays (section 1).
- 

Your setup file's project constitution contradicts these decisions. Its "Core game rules" still list wagers, 40 egg types, 100 launch characters, trading in core, combining 5 eggs, and 5 slots without saying they're item-only. I'll write the project CLAUDE.md from this doc once you approve it, so the two can't disagree.
- 

Some tools in your setup plan already exist here. This session already has the Roblox Studio connection and Roblox skills for architecture, security, data stores, UI, testing, performance and strict typing. Creating 17 overlapping custom skills would duplicate them. Blender MCP has to be installed on your PC, and I can't install it from here.

## 1. Asset audit

The egg pack is usable as-is for the shop, hatch screen and inventory icons. It has 24 egg types and 236 PNGs, and every file is a 256×256 or 64×64 palette PNG with transparency. The UI kit gives us colour tokens and design rules. Its catalog, script and SVGs have to be replaced.

### Egg pack (Eggs Icon Pack v2 (Basic), by gvesster)

| Variant set | Eggs | Files per size |
| --- | --- | --- |
| 8 variants: Normal, Outline, Golden, Golden Outline, Alt ("2"), Alt Outline, Golden Alt, Golden Alt Outline | Angel, Demon, Dragon, Kraken, Royal, Sandcastle | 48 |
| 4 variants: Normal, Outline, Golden, Golden Outline | AngelDemon, Basic, Black Hole, Cat, Coconut, Cracked, Dog, Dominus, Glitched, Ice, Legendary, Mine, Mythical, Party, Secret, Spotted, Yeti | 68 |
| 2 variants: Normal, Outline ( no Golden ) | Rainbow | 2 |

Findings that affect the build:
- 

The file naming is inconsistent.
- 

Basic Egg files are called "Egg" and "Golden Egg", with Golden as a prefix.
- 

AngelDemon files drop the word "Egg".
- 

The alternate versions read "Egg2", with no space.
- 

So the game will key eggs by stable IDs in config (egg_angel) and map each one to a file, never parse file names.
- 

The visible size varies a lot between icons.
- 

Angel's artwork fills 232×164 px of its canvas, while Basic fills 190×228 px.
- 

Placed in identical slots, the eggs would look like different sizes.
- 

Each egg's content box goes into config, and the UI scales from that box. The images themselves stay untouched.
- 

256 px is the ceiling. That's sharp for normal icon sizes, but the large hero egg in the shop will look soft on high-density phones. The "(Basic)" in the pack name suggests a higher tier might exist. Worth checking with the author.
- 

License: commercial use is allowed. Editing is only allowed in personal projects, and reselling or building asset packs is forbidden.
- 

We use the files exactly as supplied: no recolours and no cracks painted onto the icons.
- 

Glow, cracks and shine come from separate UI and VFX layers on top.
- 

Rainbow therefore has no Golden version (Q5).
- 

The style gap is real. The icons are flat cartoon with heavy outlines, and the references are glossy anime.
- 

Treatment: each egg sits as a clean "sticker" on a lit pedestal plate, with a rarity light behind it.
- 

The gloss lives in the UI, and we don't fake 3D on the icon.
- 

Upload plan: 47 images, all at 256 px: 24 Normal plus 23 Golden.
- 

Roblox scales them down for small slots, so the 64 px files aren't needed.
- 

Normal vs Outline gets decided by a side-by-side on a navy panel in Studio. The Outline border is dark navy and may disappear on our background.
- 

The six "Alt" sets are held back for V2 limited re-runs. Only 6 of 24 eggs have them, so using them in V1 would look uneven.
- 

Roblox moderates every uploaded image before it appears.

### UI kit (onevone_card_roblox_ui_kit)

| File | State | Keep / replace |
| --- | --- | --- |
| Theme.lua , DESIGN_SYSTEM.md | 9 colour tokens, rarity colours, 7 UX rules | Keep the tokens and rules. Drop the Uncommon colour, since we have 5 rarities |
| OneVOneCardUI.client.lua (6.9 KB) | One LocalScript that builds static panels, not connected to anything | Replace with modular, responsive UI controllers |
| ContentCatalog.json | 12 eggs that aren't in the pack. Lists Shadow, Flame, Ice and Nature as rarities | Replace with the typed config in section 5 |
| assets/eggs/*.svg , assets/cards/*_frame.svg | 12 eggs and 5 frames, vector | Roblox can't display SVG. The eggs are superseded by the pack, and the frames are a layout reference only |
| assets/references/*.png (4) | Concept boards. ui_board_alt_03 is the same file as ui_concept_board and the image you sent | Mood reference only: they contain copyrighted characters and features you've ruled out |

## 2. Game design

The core loop is farm, sell, hatch, build, battle, unlock. Each world adds new resources, eggs, NPC prices and a Guardian Trial, so progress means new options rather than just bigger numbers. All prices and odds below are starting values. They get tuned with an economy simulation in milestone M3.

### Core loop
- 

Farm resource nodes in your current world. It's active play, with cooldowns and walking between nodes.
- 

Sell items to that world's NPC merchant for Coins.
- 

Hatch eggs with Coins (or Robux). Each hatch gives a card copy.
- 

Upgrade a card by merging spare copies of the same character into it, plus Coins (max level 15).
- 

Build a 3-card deck.
- 

Battle in ranked 1v1 to earn Trophies and Coins.
- 

Unlock the next world at its trophy threshold. A world stays unlocked even if your trophies drop later.

### Currencies

| Currency | Earned from | Spent on | Never used for |
| --- | --- | --- | --- |
| Coins | Battle wins (daily-capped), NPC selling, quests, achievements, daily streak, V2 store sales | Eggs, item slots, card storage, merge fees, V2 store purchases | Sold for Robux |
| Gems | Achievements, world first-clears, season milestones, events, day 7 of the streak | Cosmetics with a fixed outcome: card foils, frames, titles, battle intros, emotes | Anything random: eggs, rerolls, luck boosts |
| Trophies | Ranked wins (+), losses (−), one-time Guardian Trial grants | Not spent. Sets league, matchmaking and world unlocks | Sold or boosted for Robux |
| Robux | The player's own Robux | Eggs from unlocked worlds, cosmetics | Coins, Gems, boosts, levels, trophies |

### Rarity

Five rarities: Common, Rare, Epic, Legendary, Mythical, using the design-system colours (#B9C7DC, #45BEFF, #A469FF, #FFC54B, #FF668F). Rarity sets four things:
- 

the drop odds
- 

a stat budget of +0%, +2%, +4%, +6% or +8%
- 

ability depth: Commons get one clear special, and Legendary and up add a conditional passive
- 

presentation: frame, foil and particles

Every rarity shares max level 15. A spare copy merged into a card is worth 1, 2, 4, 8 or 15 merge points by rarity, so rare cards need far fewer copies to level.

### Upgrades

Levels 2–15 cost 2, 3, 4, 5, 6, 8, 10, 12, 15, 18, 21, 25, 30 and 35 merge points (194 total) plus a coin fee. Each level adds +0.75% to all stats, so the cap is +10.5%. That limits how much duplicate farming can help: at these settings each level of difference was worth about 2–5 points of win rate (15 vs 14: 55%, 15 vs 13: 58%, 15 vs 11: 68%, 15 vs 8: 77%). Ranked also caps the levels that count, by league:

| League | Trophies | Highest level that counts in ranked |
| --- | --- | --- |
| Bronze | 0–699 | 4 |
| Silver | 700–1,349 | 8 |
| Gold | 1,350–2,199 | 12 |
| Diamond | 2,200+ | 15 |

Spare copies of a maxed card can be sold to the NPC merchant for Coins or, from V2, listed in the player store.

### Families

Fifteen families, each with one bonus stat. Two of a family in the deck give +2% to that stat for the whole deck, and three give +3%. The bonus never stacks across families.

| Bonus | Families |
| --- | --- |
| Attack | Dragon, Flame, Warrior |
| Speed | Shadow, Lightning, Ninja |
| Defense | Ice, Beast, Ancient |
| HP | Divine, Spirit, Royal |
| Crit chance (+2 / +3 points) | Demon, Cosmic, Mystic |

The tests showed Attack and HP bonuses hit harder than Defense and Speed at the same percentage. Playtests may justify +3/+4% for the weaker two.

### Eggs and odds

Odds come in bands by world. Inside a rarity, each character in that egg's pool gets an equal share, and the shop shows every character's exact %. Each egg has its own pool of about 6–10 characters, which can mix families.

| Band | Worlds | Common | Rare | Epic | Legendary | Mythical |
| --- | --- | --- | --- | --- | --- | --- |
| A | 1–2 | 72% | 24% | 3.6% | 0.4% | 0% |
| B | 3–4 | 58% | 32% | 8.5% | 1.4% | 0.1% |
| C | 5–6 | 45% | 36% | 15% | 3.5% | 0.5% |
| D | 7–8 | 32% | 38% | 22% | 6.8% | 1.2% |
| E | 9–10 | 20% | 38% | 28% | 11% | 3% |

All 24 eggs, placed:

| World | Trophies to unlock | Eggs | Band |
| --- | --- | --- | --- |
| 1 Green Plains | 0 | Basic (also the daily free egg), Spotted, Cracked, Cat, Dog | A |
| 2 Enchanted Forest | 100 | Rainbow | A |
| 3 Desert Kingdom | 250 | Sandcastle, Coconut, Royal | B |
| 4 Frozen Lands | 450 | Ice, Yeti | B |
| 5 Volcano | 700 | Dragon, Mine | C |
| 6 Demon Realm | 1,000 | Demon | C |
| 7 Celestial Islands | 1,350 | Angel, Kraken | D |
| 8 Ancient Kingdom | 1,750 | Dominus, Legendary | D |
| 9 Shadow Dimension | 2,200 | Black Hole, Glitched, Secret | E |
| 10 Divine World | 2,700 | AngelDemon, Mythical | E |
| Event | — | Party | set per event |

Within a world, the eggs differ by price and pool, not by band. For example, Dog has a Beast-heavy pool and Cat a Ninja-heavy one. Secret is hidden until a World 9 quest reveals it. Worlds 2 and 6 have a single egg, so they lean on their farming and Guardian Trial.

### Golden eggs

A Golden egg is the same egg with the same pool and one rule: Common is removed and its share is spread across the other rarities in proportion. For Band A that gives Rare 85.7%, Epic 12.9%, Legendary 1.4%. The card also gets a cosmetic gold foil, with no stat change.

Golden eggs are earned only, never sold:
- 

a world's first Guardian Trial clear
- 

day 7 of the daily streak
- 

quest milestones
- 

season rewards

They sit in the Egg Bag until opened. One rule applies to every egg, so there's no second economy.

### Collection and inventory

These are three separate stores:
- 

Card Storage: holds individual card copies, each with its own level, merge points, Golden foil and origin (earned or Robux egg). It starts at 300 copies and expands with Coins up to 1,000. The deck uses three specific copies of different characters. When storage is full, buying eggs is paused with a prompt to merge, sell or expand. Nothing is deleted.
- 

Egg Bag: holds earned eggs (Golden and event eggs), stacking up to 99 each. Bought eggs hatch straight away.
- 

Item Inventory: starts at 5 slots, and each slot holds one stack of up to 50 of a farmed item.
- 

Coins buy more slots, up to 30, with rising prices. Some milestones grant slots too.
- 

When it's full, harvesting is blocked, never deleted. A clear prompt offers Sell, Use or Expand, and the resource stays on the node.

### Matches and rewards
- 

No entry fee and no wagers. A win gives a fixed number of Coins by league, plus Trophies (about +30 for a win and −20 for a loss, adjusted by the rating gap).
- 

Daily anti-farming cap. The first 10 wins each day pay full Coins, and later wins pay 25%. Trophies are never capped.
- 

No reward for low-quality matches:
- 

matches that end before round 3 by forfeit
- 

a repeat of the same two players more than 3 times a day
- 

a player who timed out on 3 or more rounds
- 

Leaving early counts as a loss once the 30-second reconnect window runs out.

### Robux shop (Q4)

Robux can buy eggs and cosmetics. Robux eggs are paid random items under Roblox policy, so these rules are fixed for V1 (section 7):
- 

Robux eggs: sold as Developer Products, 1 or 3 normal eggs per purchase, only for worlds the player has unlocked (assumed, Q10).
- 

The odds are the same as the coin price, with every character's exact % on the buy screen before payment.
- 

Cosmetics: card foils, frames, titles, battle intros and emotes at fixed Robux prices. No randomness and no stats.
- 

Never sold for Robux: Coins, Gems, Golden eggs, XP or trophy boosts, luck boosts or anything that changes odds, levels, world unlocks.
- 

Restricted players: when Roblox flags a player (ArePaidRandomItemsRestricted), the Robux egg button is hidden.
- 

The same eggs stay buyable with Coins, which is one of Roblox's accepted alternatives.
- 

Cosmetics stay on sale, because they aren't random.
- 

Every card copy records whether it came from a Robux egg. The V2 player store needs that to block paid copies for restricted players.
- 

Competitive impact: paying speeds up collecting and merging, but ranked league caps and the small rarity bonus limit the gain. Level 15 vs 13 measured 58%.
- 

Prices: Robux prices are set in M7 from telemetry, not guessed now.

### Player store (V2, designed now)

Players list spare card copies for other players to buy with Coins. The store opens in V2, but M1 builds the save format for it, so nothing needs migrating later.
- 

One active listing per player at launch, with a 10% Coin fee that drains Coins from the economy. Both are starting values.
- 

A listed copy is locked: it can't be merged, sold, put in the deck or listed twice.
- 

A sale is one server-side update that moves the copy and the Coins together. It's recorded with a sale ID, so a retry can't pay twice.
- 

Players Roblox flags with IsPaidItemTradingAllowed = false can't list or buy copies that came from Robux eggs.
- 

To review before V2: selling Robux-egg cards for Coins creates a route from Robux to Coins. Roblox allows trading paid items for players who aren't flagged, but we re-check the policy at that point.

### Farming, quests and daily rewards
- 

Farming: each world has 2–3 resource types, each with nodes, a respawn timer and rare drops. Harvesting needs the player in range and is rate-checked on the server. There's no idle income.
- 

Quests: 3 daily quests (for example, win 2 battles, harvest 30 items, hatch 3 eggs) plus an achievement track.
- 

Daily rewards: a 7-day streak of Coins, then Gems and a Golden Basic egg on day 7.
- 

Daily free egg: one free Basic egg per day.

## 3. Battle system

The battle is a simultaneous-pick, turn-based 3v3 relay. A match runs about 15 rounds, roughly 2–3 minutes on a phone. In testing, random play won 7% and an adapting player won 49–64% of matches against six fixed play-styles. The numbers below come from a Python reference model of these exact rules, so they're measured rather than guessed. The Luau battle engine will be a port of that model.

### Rules
- 

Deck: 3 owned cards, checked on the server. The player picks the order in which their cards enter, one active card per side.
- 

Each round, both players secretly pick one action within a 12-second timer:
- 

Attack: 1.0× damage, +1 Energy.
- 

Defend: +1 Energy. Softens a basic Attack by 25%. Parries a damaging Special: 80% blocked, the defender gains +1 Energy, the attacker loses 1 Energy, and the defender counter-hits for 0.5×. Defending twice in a row works at half strength.
- 

Special: the character's ability. It costs 2–4 Energy.
- 

Energy: one pool per player. It starts at 1, caps at 5, and only comes from actions, never as passive income.
- 

The counter loop: Special beats Attack, Defend beats Special, Attack beats Defend. Both players can see both energy bars, so a ready Special is a visible threat to read, block or bait.
- 

Order: Defend and guard stances always resolve first. Otherwise, the faster card's chance to act first is 50% + 2.5 × the relative speed gap, capped at 20–80%. The UI shows that chance (for example, "You act first: 64%").
- 

KO: a defeated card leaves. At the start of the next round its owner picks the next card from the two left (5-second pick, with a sensible default). Damage never carries over to the next card.
- 

Timeouts: a missed pick becomes Attack. Three missed picks in a match is a forfeit.
- 

End: the first player to lose all 3 cards loses. At round 30 the winner is whoever has more total HP left, as a share of max HP.

### Turn sequence (server)
- 

Open the round and send both clients the state plus the timer deadline.
- 

Collect each player's pick. Picks are accepted once and only from that match's two players, and a missing pick becomes Attack.
- 

Lock the picks, then charge Special costs. A Special the player can't afford becomes Attack.
- 

Resolve guard actions, then the two actions in initiative order.
- 

Apply end-of-round effects (Burn ticks, status timers), then KOs and replacement picks.
- 

Send one result packet: the actions taken, each damage event and the new state. Clients only animate it.

### Damage formula

```

```

The terms:
- 

M is the move multiplier: 1.0 for Attack, 1.3–2.2 for Specials.
- 

C is 1.5 on a critical hit. The base crit chance is 5%.
- 

G is the guard reduction: 0.25 against Attack, 0.80 against Special, halved when Defending twice in a row.

There are no misses. Randomness comes only from the ±8% roll, the 5% crit and initiative, which is enough to keep matches lively without deciding them.

Status effects, kept to six for readability:
- 

Burn: 6% of max HP per round.
- 

Chill: −25% speed.
- 

Weaken: −20% attack.
- 

Shield: absorbs damage.
- 

Reflect: sends damage back to the attacker.
- 

Heal

No stuns, because losing turns feels bad on mobile.

### Example cards: the first seven original characters

The stats below are Level 1 Common base values by role. Rarity adds +0–8%.

Five of them were renamed on 2026-11-10 (`NEW_5_CHARACTERS.md`); ids and stats are unchanged. The
sample match below still uses the launch names: Ren = Rook Emberforge, Yuki = Halvard
Frostwarden, Rai = Zephyr Volt, Vesper = Nox Veilstrider, Aurelia = Solaris Dawnbringer.

| Character | Family | Rarity | Role | HP / ATK / DEF / SPD | Special (cost) | Passive |
| --- | --- | --- | --- | --- | --- | --- |
| Rook Emberforge | Flame | Rare | Striker | 585 / 340 / 90 / 110 | Ember Rush (3): 1.65× and Burn for 2 rounds | +10% damage to Burning targets |
| Halvard Frostwarden | Ice | Epic | Guardian | 748 / 260 / 140 / 85 | Glacier Ward (3): shield of 25% max HP, and the target is Chilled | +10% damage to Chilled targets |
| Zephyr Volt | Lightning | Common | Skirmisher | 553 / 300 / 90 / 135 | Static Step (2): 1.45× and acts first | +1 Energy when acting first |
| Nox Veilstrider | Shadow | Legendary | Trickster | 585 / 300 / 100 / 120 | Umbral Mark (3): 1.4× and Weaken; partly pierces Defend | 10% crit chance |
| Solaris Dawnbringer | Divine | Mythical | Support | 650 / 260 / 110 / 100 | Radiant Mend (3): heal 30% and cleanse | Attacks heal him for 10% of the damage dealt |
| Brannok Ironhide | Beast | Common | Guardian | 748 / 260 / 140 / 85 | Thick Hide (2): 50% block and reflect 80% | +30% DEF below half HP |
| Taren Ashscale | Dragon | Epic | Bruiser | 683 / 320 / 110 / 95 | Dragon's Wrath (4): 2.2×, ignores 30% DEF, 10% recoil | +10% ATK below half HP |

### Example match (both decks at level 5)

Player 1 runs Ren, Vesper and Rai. Player 2 runs Yuki, Taren and Aurelia. Player 1 led 2–1 after round 10 and lost, because their last card kept firing a Special the opponent could see was ready.

| Round | Player 1 | Player 2 | What happened |
| --- | --- | --- | --- |
| 1–3 | Ren attacks ×3 | Yuki attacks, attacks, then Glacier Ward | Ren crits (327) and drives Yuki down to 79 HP, but now faces a 202-point shield and Chill |
| 4 | Ren: Ember Rush | Yuki: Defend | Parry. The shield soaks the rest of the hit and Yuki counter-hits for 112. Ren is staggered to 0 Energy. Burn still ticks on Yuki |
| 5 | Ren attacks | Yuki attacks | Ren finishes Yuki. Taren enters |
| 6 | Ren attacks | Taren attacks | Ren hits first (240), but Taren's reply KOs him on 123 HP . Vesper enters |
| 8–9 | Vesper defends, then attacks | Taren attacks, then Dragon's Wrath | Taren had Energy for Wrath but feinted with an Attack. When Vesper stopped guarding, Wrath landed for 567 . KO |
| 10 | Rai: Static Step | Taren: Defend | Parried, but Taren was on 34 HP, so it still lands for the KO. Aurelia enters. 1 card each |
| 11–12 | Rai: Special, then attacks | Aurelia attacks ×2 | An even trade: Rai 179 HP, Aurelia 301 HP |
| 13 | Rai: Static Step | Aurelia: Defend | Parry again. Rai's Special was visibly ready |
| 14 | Rai attacks | Aurelia attacks | Aurelia acts first and wins |

### Balance test results

Each result is 1,500–3,000 simulated matches on random decks.

| Test | Result | Target | Status |
| --- | --- | --- | --- |
| Random play vs any sensible style | 4–10% wins |  55% | Met |
| Match length | mean 15 rounds, 90th percentile 19 | 12–16 | Met |
| Character win-rate spread | 45–57% | 45–55% | Tune. Vesper and Taren 57%, Rai 45% |
| Same level: Mythical/Legendary/Epic deck vs Common/Common/Rare | 63–64% | ≤ 58% | Tune. This mostly reflects the Vesper/Taren strength |
| Level 1 5 vs 14 / 13 / 11 (at +0.75% per level ) | 55% / 58% / 68 % | — | Why ranked uses league level caps |
| 3-of-a-family bonus at +3% | 52–56% | ≤ 56% | Met |

The bots are a balancing proxy, not a skill ceiling. Human playtests from M4 onward, and the M7 closed test, replace these numbers. The next tuning pass trims Vesper and Taren specials by about 5%, raises Rai's to 1.5×, and makes a basic Attack into an un-guarded target give +0 Energy instead of +1, to cut the "always Attack" habit.

## 4. Characters: art direction and model standards

The plan is to get one character to final quality in Studio before making a second, then the other six from the example roster, and only then scale up. The roster in section 3 was designed on paper first: names were checked against the anime and game casts I know, and four drafts were renamed because they clashed. A formal name search is still due before launch.

### Art direction
- 

Look: stylised anime proportions on a Roblox-compatible rig. Heads are slightly large, hands and feet chunky, with crisp colour blocking. One signature silhouette per character, such as a weapon, hair shape, cape or horns, readable at 48 px in the deck slot.
- 

Colour: each character uses a 3-colour scheme led by its family colour. The rarity shows only in the card frame, foil and particles, never in the model's palette. That keeps a Common as handsome as a Mythical.
- 

Faces: expressive 2D faces painted as texture decals, swappable for expressions. That suits Roblox's toon style better than sculpted 3D faces.
- 

Avoid: copies of any existing character's costume, hair or emblem. That includes Akatsuki-style cloaks, bandaged eyes and straw hats. Every design starts from a written brief, never a reference character.

### Model standards (draft, to confirm in M2)

| Item | Standard |
| --- | --- |
| Rig | R15-compatible with custom MeshParts, so Roblox animation tools and the avatar pipeline work |
| Triangles | ≤ 10k per battle model. A lobby or inventory display copy may be the same model |
| Textures | One 1024² colour atlas per character plus a shared toon ramp. Glow is done with Neon parts and particles, not extra maps |
| Scale | Roughly 5.5 studs tall, feet at the origin, facing −Z |
| Animations | Idle, ready, attack, defend, parry, hit, special, KO, victory, about 0.6–1.6 s each. The special has a 1.2 s cap so rounds stay quick |
| VFX | Per family: a shared particle kit plus 1–2 unique effects for the Special. A mobile particle budget is set in M2 |
| Card art | Rendered from the same model in a fixed "photo booth" scene (lighting, camera, background), exported once per pose and uploaded as an image |

Cards in grids use the rendered image. A live 3D model in the UI only appears on the inspect screen and the battle stage, because many live 3D views on a phone cost frame rate.

### What I can and can't produce here
- 

I can: write every system, the UI, VFX and lighting, build blockout worlds, write the render-booth tooling in Studio, and use Studio's generation tools (mesh, material, texture) for props and environment pieces.
- 

The gap: hero-quality anime characters and their animations need a 3D artist or a Blender pipeline. Generated meshes are a starting point, not a final character.
- 

The test: M2 makes one character end to end. If that generated or modelled result doesn't meet the standard above, we commission or buy original models with clear rights before going further.

## 5. Data structures

All content is typed Luau config held in ReplicatedStorage, so the client can display it and the server enforces it. A build-time check rejects:
- 

any egg whose odds don't sum to exactly 100%
- 

any pool entry pointing to a missing character
- 

any of the 24 egg types missing from config

Player data stores only IDs and counts, never stats, prices or odds.

### Content definitions (shared, read-only)

```

```

### Probability config

```

```

### Player profile (persisted)

```
 copy
	cardSlots: number,                 -- 300 to start, up to 1,000]]> unix time; idempotency ledger, pruned after 7 days]]> unix time; a receipt is granted once]]>
```

## 6. Architecture and persistence

The game is one Roblox experience with two places: a Hub place (lobby plus the 10 worlds) and a Battle place. Every 1v1 runs in a reserved Battle server. The server owns every number, and the client only sends intents such as "buy egg_dragon" or "pick Defend".

### At a glance

Hub and Battle servers never trust each other's messages for anything of value. Both read the same match record from MemoryStore and the same profiles from data stores.

### Code layout (Rojo project, strict Luau)

```
 unit-testable, used by server + replay UI
    Odds.luau             one function for both the roll and the odds display
    Net/                  remote definitions + payload schemas
  server/                 ServerScriptService
    Bootstrap.server.luau starts services in dependency order
    Services/
      P]]> roll -> grant, atomically on the profile
      C]]>
```

### Remotes (all validated on the server)

| Remote | Payload | Server checks |
| --- | --- | --- |
| Shop.BuyEgg | eggId, requestId | Egg exists and is sold, world unlocked, coins ≥ price, card storage has room, rate limit (4 per second), requestId not seen before |
| Bag.OpenEgg | eggId, golden | Owned count > 0, golden allowed, card storage has room |
| Cards.Merge | target uid, spare uids | All owned, same character, none in the deck or listed, target below level 15, coins enough |
| Deck.Set | 3 card uids | All owned, 3 different characters, enabled |
| Farm.Harvest | nodeId | Node exists and is ready, player within 12 studs, cooldown passed, inventory space |
| Merchant.Sell | itemId and count, or card uids | Owned, not locked, price taken from server config |
| Queue.Join / Queue.Leave | — | Valid deck, not already queued or in a match |
| Battle.Pick | round, action | Player is in this match, round is current, one pick per round, before the deadline |

The server sends to clients: profile deltas, odds tables, hatch results (after they're saved), and battle round results.

Robux purchases come through MarketplaceService.ProcessReceipt, not a remote. The handler:
- 

Checks the receipt's user and product.
- 

Grants the purchase inside the profile update and records the PurchaseId in processedReceipts.
- 

Saves, and only then returns PurchaseGranted.

Any failure returns NotProcessedYet, so Roblox retries the next time the player joins. (developer products)

### Cross-server matchmaking
- 

Queue.Join writes a ticket to a MemoryStore sorted map: player, trophies, league and time queued. It expires after 120 seconds as a safety net.
- 

A matchmaker loop runs in every Hub server, about every 2 seconds, but only the one holding a short lease does the work. It pairs tickets within ±100 trophies, widening by 50 every 10 seconds up to ±400, in the same league for level caps.
- 

On a pair, it removes both tickets in one update and calls ReserveServer. It writes the match record (matchId, both players, decks as snapshots of IDs and levels, access code) to a MemoryStore hash map, then teleports both players.
- 

The Battle server reads the match record by matchId. It never uses teleport data for anything that matters. It loads both profiles (taking the session lock), re-validates the decks and starts once both players arrive. If one player hasn't arrived within 30 seconds, the match is cancelled with no reward.
- 

Disconnects: a player who drops gets a 30-second window to rejoin through the stored access code. Their timer keeps running and missed picks become Attack. After that, they forfeit.
- 

Settlement: the result is written to both profiles with the matchId. A profile that already lists the matchId in settledMatches is skipped, so retries and crashes can't pay out twice. Players then teleport back to the Hub.

The player-count maths: MemoryStore allows 1,000 + 120 × concurrent users request units per minute, and a sorted map lives on one partition, throttling at around 30,000 units a minute. At about 5 requests per queued player that's ample, even at 10,000 concurrent players. The matchmaker lease stops servers from double-matching the same players. (memory stores)

### Persistence
- 

One profile key per player, written with UpdateAsync and a session lock: lock owner (jobId) plus a heartbeat timestamp.
- 

A server refuses to write a profile it doesn't own.
- 

A lock left by a crashed server is stolen only after it goes stale, 5–10 minutes without a heartbeat.
- 

We can use the community ProfileStore library (which does exactly this) or write the same pattern ourselves. That's decided in M1 after a code review.
- 

Autosave every 60–90 seconds, on every purchase, hatch or settlement, and on leave. BindToClose flushes everything on shutdown.
- 

Each save is checked: a write that reports failure is re-read before retrying, because the Roblox docs note a failed write may still have landed. (data store limits)
- 

Schema version and migrations: every profile has schemaVersion, and loading runs the migrations in order. Old saves are never loaded raw.
- 

Budgets: 60 + 40 × players reads and writes per minute per server, and 4 MB a minute written per key. Our profile is a few KB, so the limits only bite if something saves in a loop. A save queue merges repeated requests.
- 

Recovery: the transaction ledger plus data store version history let us restore a player after a bug.

### Toolchain

Rojo, StyLua, Selene, Luau LSP, TestEZ and GitHub, as in your setup file. Studio stays connected through its MCP connection for building and playtests. Blender plus its MCP connection is for character and prop production, installed on your PC (M2).

## 7. Policy and technical risks

Selling eggs for Robux (Q4) puts the game under Roblox's paid random items policy from day one. That means three things:
- 

exact odds shown before every Robux egg purchase
- 

a PolicyService check on every player
- 

trade limits on paid items in V2

Coins stay unsold and no paid item changes odds, which keeps those rules from spreading to the coin economy. I'm not a lawyer. This is a reading of Roblox's published policies as of today. (paid random items)

### Roblox policy

| Risk | What the policy says | Our rule |
| --- | --- | --- |
| Paid random items, direct or indirect | Covers eggs, chests and spins paid for with Robux or currency bought with Robux . That includes luck boosts, pity systems and "combine for a chance" items. Odds must be shown as exact percentages before purchase, and a bare (i) icon isn't enough | Applies to Robux eggs. Every character's exact % appears on the buy screen before payment, behind a button labelled "Odds". The display and the roll share one function. No pity system or luck boost in V1. Adding one later needs its effect shown in numbers |
| Odds that change with ownership | If an outcome can only be won once, the displayed odds must update | Not used: duplicates are kept as copie s, so odds never depend on what you own |
| Odds for free rewards | Not required for random rewards that cost no Robux or currency | Shown anyway, for coin eggs and Golden eggs too |
| Region and age restrictions | PolicyService returns ArePaidRandomItemsRestricted . Flagged users can't access paid random items, and creators must offer an earnable path, direct purchase, or hide or block the item | Checked for every player on join. Restricted players see no Robux egg button, and the same eggs stay buyable with Coins (the earnable path). Tested with a forced flag in M1 |
| Trading paid items | IsPaidItemTradingAllowed . For restricted users, outcomes of paid random items and other paid items can't be traded | V2 player store checks the flag per player. Each card copy stores its origin , so copies from Robux egg s can be blocked |
| Robux receipts | Grant before returning PurchaseGranted . Return NotProcessedYet on failure, and Roblox retries on the next join | Grant, record the PurchaseId and save before PurchaseGranted . Tested with replayed receipts in M1 ( developer products ) |
| Gambling | Roblox has banned simulated gambling (virtual chips, simulated betting) since September 2023. Exchanging Robux or items of value in gambling is prohibited | Wagers removed. No item or currency is ever staked between players. The "Bet & Fight" copy is gone from all UI ( announcement ) |
| "Combine 5 eggs" (from your setup file) | A combination with a chance of a better result is a paid random item when the inputs were paid for. Robux eggs now make them paid | Not in V1. If it's added, the result is fixed and shown before combining |
| Maturity questionnaire | Every experience must complete it, and paid random items must be declared | Declare Robux eggs. Complete it before the first public test (M7) |
| Age-based accounts | Kids (5–8) and Select (9–15) tiers were announced for June 2026, and chat is age-gated | Chat isn't required for any feature. Purchase prompts never appear mid-battle or during a hatch reveal |
| IP | Anime characters, names and likenesses can't be used | Original roster only. Run a name check before launch, and keep the reference boards out of the build |

### Technical risks

| Risk | Mitigation |
| --- | --- |
| Profile loss or duplication from two servers writing at once | Session lock, UpdateAsync only, a write check after failures, migrations, ledger |
| Double reward from a battle retry or crash | settledMatches idempotency by matchId, so settlement only happens inside the profile update |
| Exploited remotes (speed farming, buy spam, fake picks) | Server range and rate checks, request IDs, one pick per round, a server-only RNG seed per match |
| Teleport failures (Hub ↔ Battle) | Retry with backoff, then cancel the match cleanly, with no trophies changed |
| Empty queues at low player counts | Guardian Trials for progress (Q1), a queue timer with an estimate, and a cancel button |
| Mobile performance (3D cards, VFX) | Card grids use pre-rendered images. Per-device particle budgets, StreamingEnabled in the Hub, and profiling in M6 |
| Art scope (anime-quality characters) | Prove one character end to end in M2 before committing to the roster size |
| Balance drift as the roster grows | The Python model becomes a CI check. Every new character runs the balance suite before it ships |

## 8. Roadmap

There are eight milestones. Each one ends with a playable Studio build and a short report of what was tested. The milestones are ordered so the riskiest unknowns come first: data safety, character art quality and whether the battles are actually fun. Each can only start once you've accepted the one before.
- 

M0 Foundations. Rojo project, strict Luau, lint and format, TestEZ, GitHub repo, and the project CLAUDE.md generated from this doc. Typed config for all 24 eggs and the 7 characters, plus the odds check.
- 

Accept when: CI passes. The odds check rejects a bad band, and a missing egg fails the build.
- 

M1 Profiles and economy core. Session-locked profiles, migrations, the ledger, EconomyService, the 5-slot item inventory, card copies and merging, the egg purchase → roll → grant flow, Robux receipt handling and the PolicyService gate (no UI polish).
- 

Accept when: 10,000 scripted purchases show odds within statistical tolerance. Killing the server mid-purchase never duplicates or loses coins, checked over 50 forced crashes in Studio. Two servers can't both write one profile. A Robux receipt replayed 100 times grants once, and a restricted test account sees no Robux egg button.
- 

M2 Vertical slice: art. One character (Ren) at final quality: model, rig, 9 animations, Special VFX, card render, plus the battle stage and card frame for all 5 rarities.
- 

Accept when: you approve it visually. It runs at ≥ 50 fps on a mid-range phone in the Studio device emulator plus one real-device test, and it meets the model standards in section 4.
- 

M3 Battle engine. BattleRules ported to Luau and unit-tested against the Python model on the same seeds, then BattleService with timers, picks, KO and settlement in a local 1v1.
- 

Accept when: the Luau and Python engines give identical results on 1,000 seeded matches. No remote can change the outcome, verified by a scripted exploit test. Economy simulation v1 sets the prices.
- 

M4 Matchmaking and battle place. Queue, lease, reserved servers, teleports, reconnect, forfeit, trophies, leagues and level caps.
- 

Accept when: about 40 test accounts pair correctly across servers within the trophy band. Disconnects at each phase settle correctly, and no double reward appears in 200 forced-failure runs.
- 

M5 Hub, UI and hatch. Lobby, egg shop with odds pop-up, hatch animation with normal and Golden variants, collection, deck builder, settings. Layouts are built separately for phone, tablet and PC.
- 

Accept when: every screen passes a readability check at 360×640 and 1920×1080. A first-time player reaches their first battle in under 3 minutes in a playtest.
- 

M6 Worlds 1–3, farming, NPCs, quests, daily rewards and Guardian Trials, then Worlds 4–10 as a content pass once the template is proven.
- 

Accept when: each world has its resources, merchant, eggs, trial and unlock threshold. The full-bag flow is tested, and the Hub keeps frame rate with StreamingEnabled.
- 

M7 Closed test. 20–50 players, telemetry (match length, win rate by character, pick rates, coin flow), a balance pass, a security review and the maturity questionnaire.
- 

Accept when: no character falls outside 45–55% in real play, there are no open critical bugs, and you approve the go/no-go.

Next come 3 more characters to test the pipeline, then scaling the roster in batches of 6–8. V2 adds trading, the marketplace, events and new modes.

## 9. Open questions for you

Q1–Q4 are answered. Q10 and Q11 affect M1. The rest can be settled during M2–M5.
- 

Q1. Guardian Trials: yes, one PvE trial per world with a one-time trophy grant.
- 

Q2. Max level: 15 for every rarity, at +0.75% per level.
- 

Q3. Battle rules: the counter loop is the base.
- 

Q4. Robux: buys eggs (paid random items, under the section 7 rules) and cosmetics. No Coin packs, XP boosts or trophy boosts.
- 

Q5. Golden Rainbow: the pack has no Golden Rainbow and the license bars editing. Should Rainbow stay the one egg without a Golden version, or should we ask the artist for one?
- 

Q6. Larger egg art: will you check whether the egg pack has a higher tier with art above 256 px for the hero shop display?
- 

Q7. Character production: who makes the hero models and animations, you or a hired artist with Blender, or do we try Studio generation first and judge it in M2?
- 

Q8. Launch roster size: 7 example characters are designed, while your setup file says 100. My recommendation is 24–30 for V1, enough to fill every egg pool without duplicates across the 24 eggs.
- 

Q9. Secret and Glitched eggs: keep Secret quest-revealed and Glitched as a normal World 9 egg?
- 

Q10. Robux eggs and world locks: I've assumed Robux only buys eggs from worlds you've unlocked, so paying can't skip progression. Is that right?
- 

Q11. Player store: players sell spare card copies to each other for Coins. It opens in V2, and its save format is built in M1.
- 

Q12. Store fee and listing limit: start with a 10% Coin fee and one active listing per player?

## Sources
- 

Paid random items policy guidelines (Roblox Creator Hub, updated 2026-10-15)
- 

Create Experiences for People 17 and Older (simulated gambling update) (Roblox DevForum)
- 

Memory stores: limits and matchmaking guidance (Roblox Creator Hub)
- 

Data store error codes and limits (Roblox Creator Hub)
- 

Roblox launches age-based accounts (Khaleej Times, 13 April 2026)
- 

Eggs Icon Pack v2 (Basic) License.txt, and the onevone_card_roblox_ui_kit files on your PC
- 

Battle model and balance runs: Python reference simulation (available on request)
