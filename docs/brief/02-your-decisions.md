I want us to make the decisions properly before writing code. The goal is to build a real, polished Roblox game, not just a collection of UI panels and disconnected systems.

Here are my decisions and the direction I want you to follow.

## 1. Battle system

**Option A: turn-based tactical 1v1.**

This is the core of the game. I do not want automatic battles where the player with 2,770 power simply beats the player with 2,500 power.

Each player brings exactly 3 cards into battle.

My proposed gameplay:
- Each player has one active character at a time.
- Players make tactical decisions during their turns.
- Actions include Attack, Defend and the character's Special Ability.
- Characters have HP, Attack, Defense, Speed and a unique ability.
- Energy or another resource limits powerful abilities.
- When a character is defeated, the next character enters.
- Family synergy provides a bonus, but it must never guarantee victory.
- Winning should depend on decisions, timing, abilities, team composition and some controlled randomness, not just card rarity or total power.

I want you to design and present the complete battle rules, turn sequence, damage formula, abilities, energy system and balancing approach before implementation.

The battles should feel exciting, with character animations, attacks, abilities, impact effects and satisfying victory animations. The gameplay itself must remain readable on mobile.

## 2. Character art and models

Use **original 3D Roblox characters rendered inside the card design** as our main direction.

I want:
- Original characters, not Gojo, Naruto, Luffy, Itachi or copied anime characters.
- Distinct silhouettes, faces, clothing, weapons, personalities and abilities.
- High-quality 3D models and materials.
- Original character artwork for the card presentation, generated from our own models.
- Different animations and VFX for each character.
- Consistent visual quality across every rarity.

The card should look premium and anime-inspired. We can use 3D renders for the card artwork, while the actual 3D character model is used in battle.

Do not start creating 100 characters randomly. First establish a character art direction, model standards and a small group of original example characters. Get the quality right before scaling up.

## 3. Rarity system

Use these five rarities:

1. Common
2. Rare
3. Epic
4. Legendary
5. Mythical

No SR, SSR or UR for now.

**Families and rarities are separate concepts.** Dragon, Shadow, Demon, Divine, Warrior, Flame, Ice, Lightning, Spirit, Beast, Ninja, Royal, Cosmic, Ancient and Mystic are families, not rarities.

Every character has one family and one rarity.

The rarity affects acquisition probability and potentially the character's progression ceiling, but a Mythical character should not automatically beat every Common or Rare character. We need competitive balancing.

## 4. Golden eggs

Use Golden as a special visual variant of the same egg, not a completely separate egg category.

For the first version:
- Golden eggs are obtainable through gameplay.
- They are not a Robux-purchased random product.
- Their exact effect on rewards and odds must be defined before implementation.
- Do not create a separate Golden version of every egg's entire economy without a clear reason.

I want the normal and Golden egg artwork retained, because both can be useful visually.

## 5. Coins and gems

We need two currencies with separate purposes.

**Coins:**
- Earned from winning battles.
- Earned from farming items and selling them to NPCs.
- Earned from quests, achievements and daily rewards.
- Used for ordinary eggs, inventory expansions and normal progression.

**Gems:**
- A rarer progression currency.
- Earned through achievements, milestones, events and special rewards.
- Used for premium-looking cosmetics and other clearly defined rewards.

For now, do not allow players to buy gems with Robux and then spend them on randomized eggs. I want the first economy to avoid unnecessary paid-random-item compliance problems.

No AFK farming as a core income source. Players should earn through actual gameplay.

## 6. Betting and match rewards

**Remove player-versus-player betting and wagers.**

I do not want players risking their currency or items against another player.

Instead:
- Competitive matches have no entry fee.
- Winners receive a fixed, clearly defined reward.
- Rewards depend on match mode and progression.
- Add daily reward limits and anti-farming protections where necessary.
- Trophies determine competitive progression and world unlocks.

This is safer and gives us a much cleaner economy.

Important: Roblox's current policies specifically address gambling and paid random items. We must design around the official rules, not assume that calling a wager "coins" makes it safe. Also account for paid-random-item restrictions and odds disclosures if our monetization model ever changes.

## 7. Matchmaking

Use **cross-server matchmaking**.

Players should be able to find opponents across different servers rather than only matching people inside their current server.

Requirements:
- Server-authoritative matchmaking.
- Fair matchmaking based on trophies or skill rating.
- Server-authoritative battle state and rewards.
- Protection against disconnect abuse, duplicate rewards and match manipulation.

No bots in competitive matchmaking for the first version. If no opponent is available, let the player wait or cancel the queue. We can add a separate practice mode against AI later.

## 8. Worlds and progression

I want 10 progressive worlds, unlocked through trophies.

For the first version, make them areas inside one main experience, connected through a clean world-selection interface and portals. Design the world system so that we can separate them into individual places later if performance or scale requires it.

The proposed egg distribution is a good starting point, but fix the duplicate world numbering:

| World | Name | Eggs |
|---|---|---|
| 1 | Green Plains | Basic, Spotted, Cracked, Cat, Dog |
| 2 | Enchanted Forest | Rainbow |
| 3 | Desert Kingdom | Sandcastle, Coconut, Royal |
| 4 | Frozen Lands | Ice, Yeti |
| 5 | Volcano | Dragon, Mine |
| 6 | Demon Realm | Demon |
| 7 | Celestial Islands | Angel, Kraken |
| 8 | Ancient Kingdom | Dominus, Legendary |
| 9 | Shadow Dimension | Black Hole, Glitched, Secret |
| 10 | Divine World | AngelDemon, Mythical |
| Event | Special Events | Party |

This is a proposed distribution, not a rule that every egg can only drop one family. Eggs should have their own character pools and probabilities. Some eggs can contain characters from multiple families.

All 24 egg types should be accounted for. Do not silently remove any from the pack.

World progression should introduce better farming opportunities, new eggs, new items and new challenges. It should not simply increase every number without meaningful progression.

## 9. Duplicates and inventory

Duplicates should have a useful purpose.

My preferred direction:
- Duplicate cards become character-specific fragments.
- Fragments can be used to upgrade that character.
- Upgrades have a defined maximum level and controlled stat increases.
- Do not automatically turn duplicates into a higher rarity.
- Do not let duplicate farming create an unlimited competitive advantage.

Important distinction: the initial 5 inventory slots should apply to farmable items and resources, not limit the player's entire card collection to five cards.

Cards should have their own collection system. Eggs and stackable resources should also be handled sensibly.

When the item inventory is full, farming should not silently destroy rewards. Give a clear warning and allow the player to sell, use or expand their inventory.

## 10. First release scope

I agree that trade and the marketplace should come later.

**Version 1 should include:**
1. Main lobby.
2. Player profile and currencies.
3. All 24 egg types integrated into the egg system.
4. Egg shop and hatching animations.
5. Card collection and inventory.
6. Three-card deck builder.
7. Tactical 1v1 battle system.
8. Matchmaking and trophies.
9. Ten progressive worlds.
10. Farming, items and NPC selling.
11. Daily rewards and basic quests.
12. Settings and mobile-friendly UI.

**Version 2:**
- Player-to-player trading.
- Marketplace.
- More characters and eggs.
- Events and additional competitive modes.

Trading and marketplace must eventually use secure server-side transactions, item reservation, ownership validation and duplication protection. Do not rush them into version 1.

## 11. Target devices and UI

**Mobile-first, with full PC support.**

The UI must adapt to:
- Phones.
- Tablets.
- PC.

Do not simply shrink the PC layout for mobile.

I want a premium dark fantasy interface:
- Deep navy and near-black backgrounds.
- Purple, blue and gold accents.
- Clear typography and strong visual hierarchy.
- High-quality card frames and 3D character presentations.
- Smooth animations and polished interactions.
- No clutter, oversized panels or generic-looking UI.

The actual battle interface must prioritize readability and easy interaction on a phone.

---

## 12. Important technical and production requirements

Before implementation, I want you to establish the architecture.

Everything important must be server-authoritative:
- Currency balances and transactions.
- Egg purchases and hatching results.
- Card ownership and upgrades.
- Inventory capacity and item ownership.
- Deck validation.
- Matchmaking and battle results.
- Trophy rewards and world unlocks.

The client must never decide its own rewards, hatching results, damage, currency balance or match outcome.

Use clean modular Luau architecture. Separate server systems, shared definitions, client controllers, UI, data persistence and configuration.

Design for data validation, rate limiting, exploit prevention, error handling, reconnects and safe saving. Do not put all game logic into one giant script.

We also need a proper asset pipeline. The egg pack should be integrated consistently, but the card art, characters, world environments, animations and VFX need their own production standards.

## 13. Before you build anything

I want you to do these things first:

1. Inspect the actual egg assets and UI kit, including their dimensions, variants and naming.
2. Establish the final game design document covering the gameplay, progression, currencies, eggs, rarity, families and world unlocks.
3. Design the complete battle system and demonstrate how a match works with example cards.
4. Define the character data structure and egg probability configuration.
5. Present the server/client architecture and data persistence design.
6. Identify Roblox policy and technical risks, especially around random rewards, trading and monetization.
7. Propose a development roadmap with clear milestones and acceptance criteria.

Do not start building the full game before we agree on these foundations.

I want you to challenge bad ideas, identify contradictions and explain why a system needs changing. Do not invent completed assets, pretend a prototype is production-ready or implement temporary logic that we will have to rewrite.

**The goal is to build 1v1 CARD as a complete, polished, maintainable Roblox game, with a consistent visual identity and genuinely enjoyable competitive gameplay.**