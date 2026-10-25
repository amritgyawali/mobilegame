# SUMMIT SHARDS

## A Puzzle Roguelite for Android and PC: Full Game Design Document

**Version 1.0, October 2026**
**Working title.** Check the name with a trademark search and the Play Store before you use it publicly.

---

## How to use this document

This is the complete blueprint for building the game the research report recommended: a **block-puzzle roguelite** for Android first, with a PC (Steam) version. It covers everything a solo developer or small team needs:

- **Part A, the concept:** pitch, why it can win, setting and pillars.
- **Part B, the gameplay:** board, pieces, scoring maths, rounds, floors and full runs.
- **Part C, the content:** talismans, runes, special tiles, bosses, climbers and difficulty levels, all with numbers you can type straight into a spreadsheet.
- **Part D, retention and meta:** progression, modes, onboarding, daily systems and live ops.
- **Part E, the business:** economy, ethical monetization, prices and revenue scenarios.
- **Part F, how to build it:** art, audio, UX, technical architecture with code, analytics and anti-cheat.
- **Part G, how to ship it:** timeline, budget, team, marketing, launch gates and risks.

All numbers in the content sections (scores, prices, drop rates) are **starting values for tuning**, not final balance. Market figures come from the October 2026 research report and are cited there. Anything that is my own estimate is marked **(estimate)**.

---

# PART A: THE CONCEPT

## 1. The one-page pitch

**Elevator pitch:** *"Block Blast meets Balatro on a mythic Himalayan mountain."* You place block pieces on an 8×8 grid to clear lines, like the world's most downloaded puzzle game. After every round you choose a **talisman** that breaks the rules. Stack the right talismans and one clear can explode into a million-point combo. Climb eight floors, beat the mountain's Guardians and reach the summit, in short three-minute rounds.

| | |
|---|---|
| **Genre** | Puzzle roguelite (block puzzle + deckbuilder-style build-crafting) |
| **Platforms** | Android first (phones, tablets, Google Play Games on PC), then Steam (Windows, Steam Deck). iOS later. |
| **Orientation** | Portrait, playable with one thumb |
| **Session** | One round takes 2–4 minutes; a full run (the "Expedition") takes 25–35 minutes and saves after every round |
| **Audience** | Ages 13+. Main group: puzzle players aged 18–45 who already play Block Blast-style games. Second group: roguelite fans on PC and Steam Deck. |
| **Business model** | Free on Android: opt-in rewarded ads, a one-time "Supporter" purchase, an optional season pass, cosmetics. **No loot boxes, no paid randomness, no energy timers.** Premium paid game on Steam. |
| **Engine** | Unity 6 (2D) with a pure C# simulation core. Godot 4.6 is a valid alternative. |
| **Team** | 1 programmer-designer + 1 part-time 2D artist (+ freelance audio) |
| **Time to global launch** | 9–12 months (estimate) |

### The five design pillars

Every feature must support at least one pillar. If it supports none, cut it.

1. **Understand in 5 seconds, master in 100 hours.** The core action (drag a piece, clear a line) needs no tutorial. The depth comes from talisman combinations, not from complicated controls.
2. **"One more run."** Every run is different (random pieces, talismans, bosses), every run gives progress, and a run is never more than one round away from a save point.
3. **Big, shareable moments.** The game is built to create screenshot and video moments: a score counter exploding from 400 to 2.4 million, the whole board clearing at once. Players should *want* to show friends.
4. **Respect the player.** No paid randomness, no fake prices, no punishing streaks, no forced ads. Ads are always a choice that gives something real. This is a legal requirement as well as a design choice (see Section 22).
5. **Runs on any phone.** It runs at a smooth 60 fps on a 2 GB RAM Android phone, plays fully offline, and the download stays under 80 MB. That matters for South Asia, LATAM and Southeast Asia, where most players use budget Android phones.

## 2. Why this game can win in 2026

This is the short version of the research report.

- **Puzzle is the growth genre.** Puzzle in-app revenue grew about **+20% in H1 2026** (to ~$8.1B) while the total mobile market *fell* 2%. Block puzzles (Block Blast was the #1 most downloaded game in the world in Q1 2026) and sorting puzzles (Pixel Flow, ~$198M in its first year) are the hottest formats.
- **Puzzle keeps players longer.** Puzzle, board and card games have the strongest D1, D7 and D28 retention across the GameAnalytics benchmarks.
- **Hybrid-casual is the fastest-growing model.** Simple core + progression meta + ads *and* purchases grew ~20–23% a year. Mixing ads and purchases earns far more on Android than either alone.
- **Roguelites are how indies break through.** Vampire Survivors (5M mobile downloads in ~3 months, no paid marketing) and Balatro (~$9M+ on mobile) spread through word of mouth and video, not ad budgets. A deep roguelite gives streamers something to show and players something to master.
- **The clone problem has a solution: depth.** A plain block puzzle can be copied in a week. A balanced roguelite with 48 talismans, 12 Guardians and hundreds of synergies is much harder to copy well, and its community (codex, leaderboards, seeds, builds) cannot be copied at all.
- **Paid installs rarely pay back for a small team** (an average puzzle install earns well under $1 in a year against a $1.20–3.00 US Android install cost). So this game is designed to **spread for free**: daily seeds, shareable clips, a Steam community and Google Play featuring.

**Positioning in one line:** *Block Blast is the game you play without thinking. Summit Shards is the one you think about after you stop playing.*

### Competition map

| Game | What it does well | What Summit Shards takes | Where Summit Shards is different |
|---|---|---|---|
| Block Blast! | Instant, relaxing, endless block placement | 8×8 grid, 3-piece tray, satisfying clears | Has goals, builds, bosses and a reason to come back beyond high score |
| Balatro | Build-crafting, exponential score, "jokers" | Score = Base × Mult, rule-breaking talismans, shop between rounds | Spatial puzzle instead of cards; no poker/casino theme (keeps a clean 13+ rating and avoids gambling concerns) |
| Archero 2 / Capybara Go (Habby) | "Pick 1 of 3 skills" loop for casual players | Draft after every round | No paid gacha, no power-selling |
| Royal Match | Polish, light meta that never gets in the way | Light, optional cosmetic hub (Base Camp) | No lives or energy system |
| Tetris-like and "block roguelite" indies on Steam | Prove the hybrid is fun | Validation of the idea | Mobile-first, portrait, three-minute rounds, strong theme |

## 3. Setting and story

**The fantasy:** You are a climber on **the Mountain of a Thousand Shards**, a mythic Himalayan-style peak above the clouds. A great storm shattered the mountain's ancient **Sky Stones** into pieces, and the path to the summit crumbled. Climbers rebuild the path one stone at a time. The mountain tests every climber with its **Guardians**, ancient spirits of snow, wind and stone, who must be beaten in puzzle duels.

**Tone:** Warm, bright and hopeful, not dark. Think of a children's picture book drawn by a mountain-loving illustrator: soft clouds, colourful flags snapping in the wind, glowing stones, friendly but powerful spirit animals.

**Story delivery:** Almost no text. One short animated intro (15 seconds, skippable). Each Guardian has one line of dialogue before and after its fight. Each climber has a short bio in the codex. Extra lore is unlocked through the codex for players who care, and never blocks players who don't.

### Using the Himalayan setting respectfully

The setting is the game's strongest visual identity. It makes the game stand out in a store full of generic candy art, and it fits a Nepal-based studio. Use it with care:

- The **five tile colours** take inspiration from the colours of mountain prayer flags and landscapes (sky blue, cloud white, fire red, river green, earth yellow). They are presented as **natural elements (Sky, Wind, Fire, Water, Earth)**, not as religious symbols.
- **Never** put real sacred script, mantras, deity figures or religious objects on tiles, items or anything you click, break or sell.
- All Guardians are **invented spirits** (a snow leopard, a yak, a glacier), not real deities.
- Climbers have Nepali and Sherpa names. Write them as skilled, modern, confident people, not as stereotypes or guides who only exist to serve outsiders.
- Before launch, ask 3–5 people from the communities you portray to review the art and text. Credit them.

---

# PART B: THE GAMEPLAY

## 4. The core loop

```
           ┌──────────────── A RUN ("Expedition", 25–35 min) ────────────────┐
           │                                                                 │
  Choose   │   FLOOR 1 ──► FLOOR 2 ──► ... ──► FLOOR 8 ──► SUMMIT (win)      │
  climber  │     │                                                           │
  ───────► │     ├─ Round 1: Trail      (normal target)                      │
           │     ├─ Camp: draft 1 of 3 talismans + shop                      │
           │     ├─ Round 2: Ridge      (higher target, 1 modifier)          │
           │     ├─ Camp                                                     │
           │     └─ Round 3: GUARDIAN   (boss rule, biggest target)          │
           │                                                                 │
           └── Run ends (win or lose) ──► Expedition XP ──► unlocks ──► next run
```

Three loops run inside each other:

| Loop | Length | What the player does | What keeps them going |
|---|---|---|---|
| **Moment** | 3–10 seconds | Drag a piece onto the grid; see lines clear and the score jump | Tactile feel, sound, combo numbers |
| **Round** | 2–4 minutes | Reach the target score before trays run out | Tension near the end, talisman triggers, near-wins |
| **Run** | 25–35 minutes | Build a talisman combo, beat 8 Guardians | Build discovery, "this build is broken!", summit reward |
| **Meta** | Days to months | Unlock climbers, talismans, altitudes; daily seeds; seasons | Collection, mastery, social comparison |

## 5. The board and pieces

### The grid

- **8×8 cells.** This is the size block-puzzle players already know.
- Every cell is either empty or holds a **tile**. Each tile has an **element colour** and may have a **special type** (Section 11).
- **No gravity by default.** Tiles stay where you place them. Gravity is a boss rule and a talisman effect.

### Pieces

- Pieces are made of 1 to 9 cells. The standard set has **19 shapes**:

| Group | Shapes | Count |
|---|---|---|
| Tiny | 1-cell dot; 2-cell bar (horizontal, vertical) | 3 |
| Bars | 3-bar, 4-bar, 5-bar (horizontal and vertical) | 6 |
| Corners | small L (3 cells, 4 rotations) | 4 |
| Big L | 5-cell L (4 rotations) | 4 |
| Squares | 2×2, 3×3 | 2 |

- Every cell of a piece has an **element** (Sky, Wind, Fire, Water, Earth). By default a piece is **all one element**. Talismans and runes can create mixed pieces.
- **No rotation by default.** Like Block Blast, the shape you get is the shape you place. (The Climber "Asha" and some talismans add rotation; this becomes a powerful build tool.)

### The tray

- You get **3 pieces at a time** (a "tray"). Place all three in any order to get the next tray.
- A normal round gives you **8 trays (24 pieces)**. The number of trays is your "time limit".
- **Reroll:** Swap the current unused pieces for new ones. You start each round with **1 reroll**.
- **Blocked:** If none of the remaining pieces fit on the board, you are blocked. You can use a reroll if you have one. If you can't, the round ends and you lose the run (unless you revive, Section 21).

### Piece generation (important for fairness)

Pure randomness in block puzzles creates "impossible" trays that feel unfair. Use a **"fair bag" generator**:

1. Pieces are drawn from a weighted bag that refills when empty (like the "7-bag" in modern Tetris).
2. When a tray is generated, the game checks that **at least one piece fits the current board**. If none fits, it redraws up to 3 times. This "mercy rule" is not shown to the player.
3. Big pieces (3×3, 5-bars) appear less often when the board is more than 60% full.
4. All randomness uses a **seeded random generator** (Section 27), so daily runs are identical for every player and replays can be checked.

## 6. Scoring: the heart of the game

Scoring uses a **Base × Mult** system, the same structure that makes Balatro's numbers grow exponentially and feel amazing.

### The formula

Every time you place a piece, the game scores that placement:

```
Placement Score = Base × Mult
```

**Base** (the "chips") comes from:

| Source | Base gained |
|---|---|
| Each cell of the placed piece | +1 |
| Each cell removed by a line clear | +10 |
| A "Pure Line" (all 8 tiles in the cleared line are the same element) | +50 per pure line |
| Perfect Clear (board is completely empty after the clear) | +200 |

**Mult** starts at **1** for every placement and grows from:

| Source | Mult gained |
|---|---|
| Each line cleared **beyond the first** in the same placement | +1 |
| Each Pure Line | +1 |
| **Streak**: each consecutive placement that cleared at least one line | +0.5 per step (max +3 without talismans) |
| Perfect Clear | ×3 (multiplies, applied last) |

Talismans add to Base (**+Base**), add to Mult (**+Mult**) or multiply Mult (**×Mult**). The order of operations is fixed and shown in the "score breakdown" panel:

```
1. Add all +Base
2. Add all +Mult
3. Apply all ×Mult (left to right, in talisman slot order)
4. Score = Base × Mult, rounded down
```

> **Why slot order matters:** Players can drag talismans to reorder them. A ×Mult talisman placed *after* +Mult talismans is much stronger. That is a simple, visible skill decision.

### Worked example

The player places a 4-cell piece that completes **2 rows**. One row is all Fire. They are on a **3-placement streak**. They hold two talismans: **Ember Heart** (+4 Mult for each Fire line) and **Twin Rope** (×2 Mult on multi-line clears).

| Step | Calculation | Running total |
|---|---|---|
| Piece cells | 4 × 1 | Base 4 |
| Cleared cells | 16 × 10 | Base 164 |
| Pure line bonus | +50 | **Base 214** |
| Starting Mult | 1 | Mult 1 |
| Extra line | +1 | Mult 2 |
| Pure line | +1 | Mult 3 |
| Streak (3 steps) | +1.5 | Mult 4.5 |
| Ember Heart (1 Fire line) | +4 | Mult 8.5 |
| Twin Rope | ×2 | **Mult 17** |
| **Score** | 214 × 17 | **3,638** |

Without talismans the same move scores 214 × 4.5 = **963**. Talismans are how the player turns a good move into a huge one, and they must be able to *see why*.

### Score display ("juice")

- Base (blue) and Mult (red) numbers fly from the cleared lines into two counters, then "slam" together into the score.
- Every talisman that triggers **shakes and glows in its slot** with a "+4" or "×2" popup. Players learn their build by watching it trigger.
- Scores above the round target trigger a short slow-motion moment and a gong sound.
- Very large scores switch to short notation (1.2M, 34.5B), with the full number in the breakdown.

## 7. Rounds, floors and the full run

### Round types

Each floor has three rounds:

| Round | Target | Trays | Special |
|---|---|---|---|
| **Trail** | 1.0 × floor base | 8 | None |
| **Ridge** | 1.5 × floor base | 8 | One random **Weather** modifier (see below) |
| **Guardian** | 2.0 × floor base | 9 | Boss rule (Section 12) |

### Target score curve (starting values)

The floor base grows by about ×1.75 per floor. Talisman builds should grow faster than this, so a strong build feels powerful while a weak build gets caught by Floor 5–6.

| Floor | Name | Floor base | Trail | Ridge | Guardian |
|---|---|---|---|---|---|
| 1 | Rhododendron Forest | 300 | 300 | 450 | 600 |
| 2 | Prayer-Flag Bridge | 525 | 525 | 790 | 1,050 |
| 3 | Yak Pastures | 920 | 920 | 1,380 | 1,840 |
| 4 | Glacier Gate | 1,600 | 1,600 | 2,400 | 3,200 |
| 5 | Storm Ridge | 2,800 | 2,800 | 4,200 | 5,600 |
| 6 | Ice Cathedral | 4,900 | 4,900 | 7,350 | 9,800 |
| 7 | Death Zone | 8,600 | 8,600 | 12,900 | 17,200 |
| 8 | The Summit | 15,000 | 15,000 | 22,500 | 30,000 |

Higher difficulty levels ("Altitudes", Section 14) multiply these targets. **Endless mode** continues past Floor 8 at ×1.9 per floor.

> **Tuning rule:** On Altitude 0, an average new player should reach Floor 3–4 on their first run and win their first full run around run 5–8. If first-run players reach the summit, the game is too easy. If they don't reach Floor 3, it is too hard. Use the bot simulator (Section 27) and soft-launch data to tune.

### Weather modifiers (Ridge rounds)

Weather gives Ridge rounds variety. It is shown before the round starts.

| Weather | Effect |
|---|---|
| Clear Sky | No modifier, but +2 Coins reward |
| Snowfall | 4 random cells start Frozen (need 2 clears to remove) |
| Gusty Wind | After every 3rd placement, the bottom row shifts 1 cell to the right (wrapping) |
| Thin Air | Only 7 trays |
| Monsoon | Water tiles give +1 Mult when cleared; Fire tiles give no Base |
| Golden Hour | Every cleared tile has a 10% chance to drop 1 Coin |
| Fog | You can see only 2 of the 3 pieces in each tray until you place one |
| Rockfall | 3 Stone tiles fall onto random empty cells at the start of trays 3 and 6 |

### Between rounds: Camp

After every won round the player goes to **Camp**. This is where builds are made.

1. **Reward:** Coins for the round (see Section 20).
2. **Talisman draft:** Choose **1 of 3** free talismans, or skip it for +3 Coins. After a Guardian round, the draft offers higher-rarity talismans.
3. **Trader (shop):** 3 talismans for sale, 2 runes for sale, 1 "Forge" service (upgrade a piece type). Reroll the shop for 2 Coins (+1 each time, resets each Camp).
4. **Manage build:** Reorder talisman slots, sell talismans (for half their price), view the full codex and synergy hints.

### Run end

- **Win:** Beat the Floor 8 Guardian. Show the summit animation, a "flag on the summit" photo with the run stats, and a share button. Offer Endless mode.
- **Lose:** The run ends when you miss a target or get blocked with no reroll. Show the run summary: floor reached, best placement score, talismans used, a "your build" card, and the Expedition XP earned.
- Every run, win or lose, gives **Expedition XP** (Section 15). There are no "wasted" runs.

---

# PART C: THE CONTENT

## 8. Build archetypes

A good roguelite has several clear "ways to win" that players discover and get attached to. Summit Shards launches with **nine archetypes**. Every talisman belongs to at least one of them, and the draft is weighted so a player who has started an archetype sees matching talismans a bit more often (+25% weight).

| Archetype | Fantasy | How it scores | Key pieces |
|---|---|---|---|
| **Combo** | "Clear four lines at once" | Huge Mult from multi-line clears | Twin Rope, Thunderclap, Porter's Basket |
| **Streak** | "Never stop clearing" | Mult grows with every consecutive clear | Momentum, Sturdy Boots, Storm Crown |
| **Element** | "The pure Fire build" | Pure Lines of one element | Ember Heart (and the other 4), Snow Leopard's Fang, Dye Runes |
| **Rainbow** | "Every colour at once" | Lines with all 5 elements count as pure | Rainbow Scarf, Crystal tiles |
| **Gold** | "Get rich, then get strong" | Coins become Mult | Gold Leaf, Interest Jar, Golden Yak, Golden Summit |
| **Demolition** | "Blow up the board" | Bombs destroy tiles for Base and Mult | Fuse Box, Chain Lightning, Sonam |
| **Glass** | "High risk, high reward" | Glass tiles multiply Mult but can break | Glassblower's Pipe, Mira |
| **Minimalist** | "Keep the board empty" | Perfect Clears and near-empty boards | Clean Slate, Minimalist's Stone |
| **Growth** | "Start weak, end unstoppable" | Talismans that grow every round | Snowball, Avalanche, Eternal Glacier, Summit Flag |

The best runs mix two archetypes (for example Element + Streak). Discovering such pairs is what players will talk about, write guides for and make videos about.

## 9. Talismans (48 at launch)

**Rules:**

- **5 talisman slots** (some climbers change this).
- Prices in Coins: **Common 4, Uncommon 6, Rare 8, Legendary 12.** Sell for half, rounded down.
- Draft rarity odds: Common 60%, Uncommon 30%, Rare 9%, Legendary 1%. After a Guardian: Uncommon 50%, Rare 40%, Legendary 10%.
- New players start with **20 talismans unlocked** (marked ★). The other 28 unlock through Expedition levels (Section 15).
- You can't be offered a talisman you already hold, unless a talisman says so.

### Common (price 4)

| # | Name | Effect | Archetype |
|---|---|---|---|
| 1 ★ | Climbing Rope | +20 Base on any placement that clears a line | Combo |
| 2 ★ | Tea Thermos | +2 Mult on any placement that clears a line | Combo |
| 3 ★ | Ember Heart | +4 Mult for each Pure **Fire** line | Element |
| 4 ★ | River Pearl | +4 Mult for each Pure **Water** line | Element |
| 5 ★ | Sky Feather | +4 Mult for each Pure **Sky** line | Element |
| 6 ★ | Wind Chime | +4 Mult for each Pure **Wind** line | Element |
| 7 ★ | Earth Drum | +4 Mult for each Pure **Earth** line | Element |
| 8 ★ | Trail Map | +1 Reroll every round | Utility |
| 9 ★ | Coin Purse | +1 extra Coin for each unused tray at round end | Gold |
| 10 ★ | Sturdy Boots | Streak bonus cap +2 (max +5 Mult) | Streak |
| 11 ★ | Stone Collector | +15 Base for each Stone or Frozen tile you break | Demolition |
| 12 ★ | Camp Lantern | The first clear of every tray gets +3 Mult | Streak |
| 13 ★ | Porter's Basket | Pieces with 5+ cells give +40 Base when placed | Combo |
| 14 ★ | Little Pebble | 1-cell pieces give +30 Base when placed | Minimalist |
| 15 ★ | Haggler's Beads | Everything in the Trader costs 1 Coin less (minimum 1) | Gold |

### Uncommon (price 6)

| # | Name | Effect | Archetype |
|---|---|---|---|
| 16 ★ | Twin Rope | ×2 Mult when you clear 2+ lines in one placement | Combo |
| 17 ★ | Avalanche | +1 Mult for every line cleared so far this round (resets each round) | Growth |
| 18 | Snowball | Gains +1 Mult for the rest of the run each time you clear 3+ lines at once | Growth |
| 19 | Glassblower's Pipe | Glass tiles give ×2 Mult instead of ×1.5 | Glass |
| 20 ★ | Gold Leaf | Gold tiles give 2 Coins instead of 1 | Gold |
| 21 | Interest Jar | Interest cap raised from 5 to 10 Coins | Gold |
| 22 | Fuse Box | Bombs explode in a 5×5 area instead of 3×3 | Demolition |
| 23 ★ | Clean Slate | Perfect Clears give ×5 Mult instead of ×3 | Minimalist |
| 24 | Minimalist's Stone | +6 Mult if 10 or fewer tiles remain on the board after the placement | Minimalist |
| 25 | Cairn | +1 Mult for each talisman you hold (including this one) | Utility |
| 26 ★ | Momentum | Each Streak step gives +1 Mult instead of +0.5 | Streak |
| 27 | Rainbow Scarf | A line containing all 5 elements counts as a Pure Line | Rainbow |
| 28 | Echo Valley | Pure Line bonuses (+50 Base, +1 Mult) count twice | Element |
| 29 | Ice Axe | Stone and Frozen tiles break after 1 clear instead of 2 | Demolition |
| 30 | Star Chart | If all 3 pieces of a tray each clear a line, the third gets ×3 Mult | Streak |

### Rare (price 8)

| # | Name | Effect | Archetype |
|---|---|---|---|
| 31 | Thunderclap | ×3 Mult when you clear 3+ lines in one placement | Combo |
| 32 | Mirror Lake | Copies the effect of the talisman in the slot to its right | Utility |
| 33 | Snow Leopard's Fang | ×1.5 Mult for each Pure Line in the placement (2 Pure Lines = ×2.25) | Element |
| 34 | Golden Yak | ×(1 + Coins ÷ 20) Mult. Example: 30 Coins = ×2.5 | Gold |
| 35 | Glacier Heart | Gains ×0.1 Mult for the rest of the run each time a Frozen tile breaks | Growth / Demolition |
| 36 | Sherpa's Compass | Tap a piece to rotate it, once per tray | Utility |
| 37 | Chain Lightning | Bombs set off other Bombs in their blast; each Bomb gives ×1.5 Mult | Demolition |
| 38 | Summit Flag | Win a round with 3+ trays left: +2 Mult on every placement for the rest of the run (stacks) | Growth |
| 39 | Hourglass | +2 trays every round, but the Streak bonus is disabled | Utility |
| 40 | Lantern Festival | Every 5th clear in a round gets ×4 Mult | Streak |
| 41 | Crystal Loom | 1 random cell of every tray becomes a Crystal tile (counts as every element) | Rainbow / Element |
| 42 | Glass Cannon | ×3 Mult on every placement, but each Glass tile cleared has a 1-in-3 chance to destroy this talisman | Glass |

### Legendary (price 12; mostly from Guardian drafts)

| # | Name | Effect | Archetype |
|---|---|---|---|
| 43 | Heart of the Mountain | ×2 Mult on every placement | Any |
| 44 | Storm Crown | Your Streak never breaks; it only stops growing on a placement with no clear | Streak |
| 45 | Eternal Glacier | Gains ×0.05 Mult for the rest of the run every time you clear a line | Growth |
| 46 | The Ninth Peak | +2 talisman slots | Utility |
| 47 | Golden Summit | Interest is paid at the end of every **tray**, not every round | Gold |
| 48 | Firebird Feather | Once per run, when you would lose, restart the round with full trays instead. Then this talisman is destroyed | Safety |

### Rules for designing new talismans (for live ops)

1. **One sentence.** If the effect can't be written in one short sentence, simplify it.
2. **Visible trigger.** The player must be able to see *when* it triggers (it shakes and shows a number).
3. **Enables or pays off.** Every talisman either helps you *create* a situation (Crystal Loom makes Pure Lines easier) or *rewards* it (Ember Heart). Good sets have both.
4. **No dead talismans.** In bot simulation, every talisman must appear in at least 5% of winning runs at Altitude 0. If it doesn't, buff it or rework it.
5. **Ship in themed packs** of 4–6 talismans that together create a new archetype (for example "Monsoon Pack: Water and Gravity").

## 10. Runes (consumables)

Runes are one-use power-ups. You can hold **2** at a time. They cost **3 Coins** in the Trader, and some Weather and Guardian rewards give them for free. Use them during a round with a tap.

| Rune | Effect |
|---|---|
| Dye Runes (×5: Fire, Water, Sky, Wind, Earth) | Every piece in the next tray becomes that element |
| Rune of Shattering | Destroy one row or column of your choice (no Base, but it keeps your Streak) |
| Rune of Hands | Rotate any one piece |
| Rune of Time | +2 trays this round |
| Rune of Wealth | Double your Coins (maximum +15) |
| Rune of Forging | Give one piece shape a random tile upgrade for the rest of the run |
| Rune of Thaw | Remove every Stone and Frozen tile on the board |
| Rune of the Seer | See the next 3 trays |
| Rune of Echo | Your next placement scores twice |
| Rune of Shrinking | Turn one piece in the tray into a 1-cell dot |
| Rune of Stillness | Your next 3 placements can't break your Streak |
| Rune of Kinship (rare) | Copy a random talisman you hold (needs an empty slot) |

## 11. Special tiles and the Forge

### Piece shapes are your "deck"

Each run has a **Piece Bag** containing the 19 shapes in set amounts. The **Forge** service in Camp lets the player change this bag. That works like adding, removing and upgrading cards in a deckbuilder. It is the most "advanced" system in the game and the deepest source of strategy.

| Forge service | Cost | Effect |
|---|---|---|
| **Upgrade** | 5 Coins | Add a special tile (Gold, Glass, Bomb, Crystal, Iron or Seed) to one cell of a chosen shape. Every future copy of that shape has it |
| **Remove** | 4 Coins | Remove one shape from your bag completely (for example, remove 5-bars if you hate them) |
| **Duplicate** | 4 Coins | Add another copy of a shape to make it appear more often |
| **Attune** | 3 Coins | Lock a shape to one element (for example, all 2×2 squares are Fire) |

The Trader offers **one** random Forge service each Camp (rerolls with the shop).

### Bonus tiles (from the Forge, runes and talismans)

| Tile | Look | Effect when cleared |
|---|---|---|
| **Gold** | Shiny gold rim | +1 Coin |
| **Glass** | See-through, sparkling | ×1.5 Mult; 1-in-6 chance the upgrade breaks off its shape |
| **Bomb** | Small fuse | Destroys every tile in the 3×3 area around it. Each destroyed tile gives +10 Base (like a clear) |
| **Crystal** | Rainbow shine | Counts as every element (helps make Pure Lines) |
| **Iron** | Riveted metal | +30 Base |
| **Seed** | Tiny sprout | +1 Mult, and that shape's Seed gains +1 more for the rest of the run (it grows) |

### Hazard tiles (from Weather and Guardians)

| Tile | Effect |
|---|---|
| **Stone** | A grey tile that takes **2** clears to remove (the first clear cracks it) |
| **Frozen** | An ice-covered tile. It needs **2** clears to remove and gives no Base |
| **Ember** | A Fire hazard. After each tray, it spreads to 1 random empty neighbouring cell |
| **Fog** | Hides the cell's element until a line through it is cleared |

## 12. Guardians (bosses)

Every third round is a Guardian round. Each Guardian has **one clear rule**, shown with a big icon and one sentence before the round starts. Floor 8 is always the **Summit Warden**. The other floors draw from pools so runs stay different.

| Guardian | Pool (floors) | Rule | How to beat it |
|---|---|---|---|
| **The Stone Yak** | 1–3 | Starts the round with 6 Stone tiles on the board | Clear around them; Ice Axe, Stone Collector |
| **The Moon Bear** | 1–3 | No pieces smaller than 4 cells | Combo builds love it; Minimalist builds struggle |
| **Mist Weaver** (giant moth) | 1–4 | You see only 1 piece of each tray at a time | Plan for flexibility; Rune of the Seer |
| **Frostmane, the Snow Leopard** | 2–5 | After every 2nd tray, 2 random tiles freeze | Clear fast; Glacier Heart turns this into power |
| **Thunder Kite** (storm bird) | 2–6 | Streak bonus is capped at +0.5 | Use non-Streak scoring |
| **The Ember Wyrm** | 3–6 | 3 Ember tiles spawn; Fire lines give no Base | Clear the embers early; Water builds shine |
| **The Langur Trickster** | 3–7 | Your leftmost talisman is disabled; it moves 1 slot right every tray | Talisman order and spare slots matter |
| **Old Glacier** | 4–7 | Every 3 trays, the outer ring of the board freezes (the board shrinks) | Score early; Minimalist builds |
| **The Avalanche King** | 4–7 | Gravity: after every clear, tiles fall down | Chain reactions can score huge; chaos |
| **The Cloud Serpent** | 5–7 | Only Pure Lines score | Element and Rainbow builds; Dye Runes |
| **The Crow of Lights** | 5–7 | Your talisman order is shuffled after every tray | Builds that don't depend on order |
| **The Summit Warden** | 8 (always) | Three phases, each with ⅓ of the target. Phases 2 and 3 add the rule of a Guardian you beat earlier in this run | Your build must be complete |

**Guardian rewards:** a higher-rarity talisman draft, +5 Coins, and the first time you beat each Guardian, a codex entry and a cosmetic trophy for Base Camp.

## 13. Climbers (playable characters)

Climbers change the starting rules. They give long-term variety and mastery goals, and they make good season content.

| Climber | Style | Starting kit and rule | How to unlock |
|---|---|---|---|
| **Pemba, the Guide** | Balanced starter | Climbing Rope; +1 Reroll every round | Start |
| **Asha, the Cartographer** | Puzzle purist | Can rotate every piece freely, but only 7 trays per round | Reach Floor 3 |
| **Dorje, the Yak Herder** | Gold | Starts with 10 Coins and Interest Jar; only 4 talisman slots | Hold 40 Coins at once |
| **Mira, the Glassblower** | Glass / high risk | Two starting shapes have a Glass tile; Glass breaks 1-in-4 instead of 1-in-6 | Score 5,000 in one placement |
| **Kiran, the Firestarter** | Element (Fire) | Ember Heart; Fire pieces appear twice as often; Water tiles give no Base | Clear 25 Pure Fire lines (all runs) |
| **Sonam, the Engineer** | Demolition | 2×2 squares start with a Bomb tile; each Bomb exploding gives +1 Mult | Beat the Avalanche King |
| **Lhakpa, the Runner** *(Season 1)* | Speed | A 20-second timer per tray; every placement gives +0.5 Mult | Season 1 free track |
| **Ang, the Collector** *(Season 2)* | Growth | Starts with Snowball; talismans cost +1 Coin | Season 2 free track |

Every climber has **10 Altitude badges** (see below), a codex page and 3–5 cosmetic outfits.

## 14. Altitudes (difficulty levels)

After the first summit, players unlock **Altitude 1**. Each Altitude adds a rule *on top of* all previous ones, and each is tracked per climber. This is the long-term mastery ladder for the top 10% of players, the ones who make guides and videos.

| Altitude | New rule |
|---|---|
| 0 | Normal game |
| 1 | Targets ×1.25 |
| 2 | Trader prices +1 Coin |
| 3 | Talisman drafts show only 2 choices |
| 4 | Every Ridge round has Weather **and** 2 Stone tiles |
| 5 | Start each round with 0 Rerolls |
| 6 | Targets ×1.5 (replaces Altitude 1) |
| 7 | Guardians get a second rule (chosen from the Guardian pool) |
| 8 | Interest cap reduced to 3 |
| 9 | Trail and Ridge rounds have 7 trays |
| 10 | **Death Zone:** targets ×2; one random talisman is disabled each round |

---

# PART D: RETENTION AND META

## 15. Meta progression

### Expedition XP and levels

Every run gives **Expedition XP**, win or lose:

| Action | XP |
|---|---|
| Each round won | 10 |
| Each Guardian beaten | 25 |
| Reaching the summit | 100 |
| Each new codex discovery (talisman, Guardian, synergy) | 15 |
| Daily quest | 30–60 |

Levels 1–50 at launch. The early levels come fast (one or two runs each), so new players feel steady progress in their first week.

| Level | XP needed (cumulative) | Unlock example |
|---|---|---|
| 2 | 60 | **Daily Climb** mode |
| 3 | 150 | 3 new talismans + Rune of the Seer |
| 4 | 270 | Forge: Duplicate and Remove services |
| 5 | 420 | **Zen Mode** + 3 talismans |
| 6–10 | +180 per level | Talismans, runes, Weather types, Climber Asha |
| 11–30 | +300 per level | Remaining talismans, Guardians, Forge upgrades, cosmetics |
| 31–50 | +450 per level | Cosmetics, Base Camp buildings, profile titles |

Unlocks are **mostly variety, not raw power.** The small power unlocks (+1 starting Coin, +1 Reroll on Floor 1) are capped so skill always matters more.

### The Codex

A collection book with a silhouette for every talisman, rune, tile, Guardian, climber and Weather. It also has a **Synergy page**: when two talismans trigger in the same placement for the first time, a synergy is "discovered" and recorded with the score. There are 150+ discoverable synergies at launch. Completion percentages give collectors a long-term goal.

### Base Camp (light, optional meta)

A small village at the foot of the mountain that players restore with **Shards** (the meta currency, earned only by playing). It has a tea house, a trophy wall for Guardians beaten, a climber gear shop (cosmetics), flag lines that show your best Altitude, and a lookout showing your Daily Climb rank. Base Camp is **purely cosmetic and emotional**, following Royal Match's lesson: the meta should never get in the way of the puzzle. It gives players a place that feels like *theirs*, and it is a good surface for season decorations.

### Achievements

60 achievements through Google Play Games Services and Steam, for example: "Score 1,000,000 in one placement", "Win with 3 Glass talismans", "Reach the summit without rerolling", "Discover 50 synergies".

## 16. Game modes

| Mode | Unlock | What it is | Why it matters |
|---|---|---|---|
| **Expedition** | Start | The main roguelite run | Core experience |
| **Daily Climb** | Level 2 | Same seed (pieces, talismans, Guardians) for every player in the world; **one scored attempt per day**; global, country and friend leaderboards | The main daily habit; free social competition; natural content for short videos ("today's seed is insane") |
| **Zen Mode** | Level 5 | Classic endless block puzzle, no targets, calming music; only one "Zen talisman" | Wins over Block Blast players; a relaxing session for days without time for a run |
| **Weekly Trial** | Level 8 | A fixed set of strange rules (for example "everything is Glass"), 3 attempts, reward tiers | Live-ops content with no new art |
| **Endless** | First summit | Continue past Floor 8 with scaling targets | Score-chasing and streamers |
| **Custom Seed** | First summit | Type or share a seed code | Community challenges, Discord events |
| **Peaks** *(post-launch)* | Update 2 | 100 handcrafted puzzles ("clear the board in exactly 4 pieces") | Content for puzzle lovers |
| **Ghost Duel** *(post-launch)* | Update 3 | Asynchronous PvP: play the same seed as a matched opponent and watch their "ghost" score | Competitive retention, no real-time servers needed |
| **Rope Teams** *(post-launch)* | Update 4 | Friend groups of up to 5 with a shared weekly goal | Social retention without the pressure of guilds |

## 17. Onboarding: the first 10 minutes and the first week

**Goal:** Tutorial completion of 85%+ and D1 retention of 30%+. The player should feel the "big score" moment **within the first 3 minutes**.

### The first 10 minutes

| Time | What happens | Design note |
|---|---|---|
| 0:00 | The app opens **straight onto the board**. No login, no menus, no permission requests. A hand cursor shows a piece being dragged | Nothing gets between the player and the fun |
| 0:10 | The player places the first piece and completes a pre-set line. Big clear, flying numbers | First "juicy" moment within 15 seconds |
| 0:40 | The target bar appears ("Reach 150 to climb"). A shortened tutorial Trail round | One new idea at a time |
| 1:30 | Round won → first **Camp**. Scripted draft: 3 easy-to-understand talismans | Teach the draft |
| 2:00 | The chosen talisman triggers visibly on the very next clear ("+20!") | Show cause and effect |
| 3:00 | A scripted big moment: a 3-line clear with the talisman → score ×5 → slow motion | **The "aha" moment** |
| 4:00 | The first Guardian: a softened **Stone Yak** | Teaches hazards and boss rules |
| 5:00 | Floor 2 begins; tutorial prompts stop; the Trader opens | Freedom |
| ~10:00 | The first run usually ends around Floor 2–3. The run summary shows the XP bar filling and **level 2 unlocks Daily Climb** | Losing feels like progress |
| After run 1 | Optional sign-in to Play Games ("save your progress to the cloud"); notification permission asked **with a reason** ("Tell me when tomorrow's Daily Climb starts") | Ask only once there is value |

**No ads appear during the first two runs.** The first rewarded-ad offer (revive) appears in run 3.

### The first week

| Day | Planned "hook" |
|---|---|
| Day 1 | 2–4 runs; levels 1–3; first Daily Climb; maybe first Floor 4 |
| Day 2 | Daily gift + 3 daily quests; Daily Climb leaderboard result ("You beat 61% of players in Nepal yesterday") |
| Day 3 | Forge Remove/Duplicate unlock (a new layer of depth); likely first Guardian kill on Floor 4+ |
| Day 4 | Zen Mode and new talismans; second climber close to unlocking |
| Day 5–6 | First summit attempt for engaged players; Weekly Trial becomes available |
| Day 7 | 7-day gift (a cosmetic climber outfit); first summit or close; Altitude 1 preview |

## 18. Daily and weekly systems (the honest version)

| System | Design | Anti-manipulation rule |
|---|---|---|
| **Daily gift** | A 7-step gift track (Shards, a rune for your next run, a cosmetic on day 7) | **Missing a day does not reset it.** It pauses and continues |
| **Daily quests** | 3 quests per day ("Clear 6 Pure Lines", "Beat a Guardian with Kiran"); one free reroll | Quests keep for 2 days if not done |
| **Daily Climb streak** | Shows consecutive days played | **2 free streak freezes** per week, earned automatically. A broken streak gives a "welcome back" reward, never a punishment message |
| **Weekly Trial** | New rules every Monday | 3 attempts, with no paid extra attempts |
| **Notifications** | Opt-in only. **Maximum 1 per day**, always useful: Daily Climb ready, leaderboard result, season ending | No guilt messages ("Your yak misses you!") and no fake urgency |

## 19. Live ops and seasons

### The cadence

| Rhythm | What | Work needed |
|---|---|---|
| **Daily** | Daily Climb seed + daily quests | Automatic (server generates them) |
| **Weekly** | Weekly Trial from a library of rule templates (via Remote Config) | 1 hour to set up |
| **Every 2–3 weeks** | A small drop: 2–3 new talismans or a new Weather | A few days |
| **Every 6 weeks** | A **Season**: new climber, a themed talisman pack (4–6), a new Guardian, season pass, Base Camp decorations | 3–4 weeks of production, prepared ahead |
| **Yearly festival events** | Lights Festival (around Tihar and Diwali), New Year, World Mountain Day, Summer Monsoon | Reuse season templates |

The research suggests seasons of 4–8 weeks. **Six weeks** is a sustainable choice for a team of one or two. Always build **two seasons ahead** before launch, so a sick week never breaks the schedule.

### The Season Pass

- 30 tiers, earned with Season XP from runs and quests.
- **Free track:** the season's new climber (around tier 15), Shards, a cosmetic or two.
- **Premium track ($3.99):** cosmetics only: climber outfit, board theme, tile skin, Base Camp decoration, animated flag, profile frame.
- **Nothing in the premium track gives power.** Unfinished tiers can be bought with real money only in the final week, and only as a plain, clearly priced option.

### Example first-year season plan

| Season | Theme | New climber | Talisman pack | New Guardian |
|---|---|---|---|---|
| S1 (launch) | "First Ascent" | Lhakpa, the Runner | Speed pack (timer synergies) | none (launch set) |
| S2 | "Monsoon" | Ang, the Collector | Water + Gravity pack | The River Dragon (rising water fills the bottom row) |
| S3 | "Lights Festival" | Deepa, the Lamplighter | Light pack (glowing tiles that chain) | The Night Owl (board goes dark between trays) |
| S4 | "Ice Age" | Tenzing, the Ice Climber | Frozen pack (freeze-for-power) | The Glacier Mother |
| S5 | "Trade Route" | Maya, the Merchant | Gold pack 2 | The Bandit Crow (steals Coins) |
| S6 | "Sky Fortress" | Rinzi, the Sky Watcher | Wind + Sky pack | The Thunder Serpent |
| S7 | "Anniversary" | Fan-voted climber | Community-designed talismans | Remix of fan favourites |
| S8 | "Yeti Winter" | The Yeti (playable!) | Snow pack | The Blizzard Spirit |

---

# PART E: THE BUSINESS

## 20. Economy

The game has **two currencies**, and **neither can be bought with real money.** This is deliberate. Selling a virtual currency is exactly what EU consumer authorities started investigating King, Supercell and others for in September 2026. With no paid currency, every real-money item has a real-money price, and the problem never exists.

### Coins (in-run currency, reset every run)

| Source | Amount |
|---|---|
| Starting Coins | 4 |
| Win Trail / Ridge / Guardian round | 3 / 4 / 5 |
| Each unused tray when a round is won | +1 |
| **Interest:** at round end, +1 for every 5 Coins held | max +5 (Interest Jar: +10) |
| Skip a talisman draft | +3 |
| Gold tiles, Golden Hour Weather | +1 each |
| Selling a talisman | half its price |

| Sink | Cost |
|---|---|
| Talismans | 4 / 6 / 8 / 12 |
| Runes | 3 |
| Forge services | 3–5 |
| Trader reroll | 2, then +1 each time (resets every Camp) |

> **Interest creates a real decision:** spend now to get stronger, or save to earn more later. It is one of the strongest "thinking" moments in this type of game, and it costs nothing to build.

**Target pacing (estimate, tune with the bot):** an average player has 8–14 Coins to spend at each Camp and can afford about one talisman plus one rune or Forge service.

### Shards (meta currency, permanent)

| Source | Amount |
|---|---|
| Run end | 5 per floor reached (+50% if summit) |
| Daily gift | 20–100 |
| Daily quest | 25 each |
| Season pass tiers | 50–200 |
| Codex milestones | 100 |

| Sink | Cost |
|---|---|
| Base Camp buildings and decorations | 200–2,000 |
| Climber outfits (non-premium) | 500–1,500 |
| Board themes and tile skins (non-premium) | 800–2,000 |
| Unlock a climber early (instead of meeting its challenge) | 1,500 |

## 21. Monetization

### Principle: "pay for joy and convenience, never for victory"

Revenue comes from three places: **rewarded ads** (most players), **a one-time Supporter Pack** (fans) and **cosmetics and the season pass** (collectors). The research showed that mixing ads and purchases earns far more on Android than either alone, and that one respected end-of-run ad is how Vampire Survivors kept players' goodwill.

### Rewarded ads (all optional)

| Placement | Reward | Limit |
|---|---|---|
| **Rope Rescue** (revive) | When you would lose: continue with 3 random rows cleared and +1 tray | 1 per run |
| **Trader's Favour** | One free shop reroll | 1 per Camp |
| **Double Haul** | ×2 Shards at run end | 1 per run |
| **Gift Boost** | ×2 daily gift | 1 per day |
| **Quest Swap** | Replace a daily quest | 1 per day |

- Daily cap: **about 8 rewarded ads** per player.
- **No banner ads. No interstitials at launch.** During the test launch, run one A/B test with a single interstitial *between runs only* (never during a run, never in the first 3 days, at most once every 10 minutes, removed by the Supporter Pack). Keep it only if D7 retention drops by less than 1 point. Otherwise remove it for good.
- Ads never appear in the middle of a round.
- Use an ad mediation layer (AdMob mediation, AppLovin MAX or Unity LevelPlay) to get the best ad prices from several networks.

### In-app purchases (all priced in real money)

| Product | Price (US; use Google's local price tiers elsewhere) | What you get |
|---|---|---|
| **Supporter Pack** | $4.99 one-time | Every rewarded-ad reward becomes a free tap (no ad needed); exclusive "Golden Rope" Pemba outfit and board theme; supporter badge; removes any test interstitials. **The main purchase.** |
| **Season Pass** | $3.99 per season | Premium cosmetic track (Section 19) |
| **Cosmetic packs** | $0.99–2.99 | Board themes, tile skins, climber outfits, score effects. Shown in the shop with full previews |
| **Welcome Pack** | $1.99 | One outfit + one board theme + 1,000 Shards. **No countdown timer.** Shown in the shop, never as a pop-up |
| **Tip the Climber** | $1.99 / $4.99 | A thank-you message and a profile flag. Many indie fans like to support a solo developer |

**Regional pricing:** use Google Play's automatic local prices, and lower them by hand for South Asia, LATAM and Southeast Asia (for example, a Supporter Pack around US$1.50–2.50 in local currency). Low prices in low-income markets turn many more players into buyers.

### Steam (premium)

- **$7.99** (the price range of Balatro and Vampire Survivors at launch). Launch discount of 10–15%.
- Includes all game content. No ads. Season cosmetics come as small, optional cosmetic DLC, or for free.
- The Steam version is not only for revenue. It earns **reviews, press, streamers and wishlists**, which mobile can't buy.

### Target monetization KPIs (estimate)

| KPI | Target |
|---|---|
| Blended ARPDAU (Android) | $0.10–0.20 |
| Share of daily players watching ≥1 rewarded ad | 35–55% |
| Rewarded ads per ad-watching player per day | 3–5 |
| Payer conversion (any purchase, lifetime) | 1.5–3% |
| Revenue split (Android) | ~55–65% ads / 35–45% purchases |

These targets are reasonable guesses based on genre benchmarks for hybrid-casual puzzle games. Measure them during the test launch and replace them with your own data.

## 22. Ethics and compliance checklist

| Rule | Why | Status in this design |
|---|---|---|
| No loot boxes or paid random items | Brazil's Digital ECA (since March 2026); EU action on random rewards; Belgian law; FTC's $20M Genshin Impact case | ✅ Nothing random is ever sold |
| No paid virtual currency | EU consumer action (September 2026) against hiding real prices behind currencies | ✅ Shards and Coins are earned only |
| Real prices always shown | EU consumer law; Google Play policy | ✅ |
| No fake urgency (countdown offers, "only 2 left!") | EU dark-pattern rules; upcoming Digital Fairness Act | ✅ |
| Forgiving streaks, no loss-framed guilt messages | Research shows that stacking streaks, timers and loss messages is what creates harmful pull | ✅ Freezes, pause-don't-reset |
| No casino or gambling theme | Google Play simulated-gambling policy; keeps the 13+ rating | ✅ Mountain theme, not poker |
| Ads are opt-in, with honest close buttons | Google Play ad policy; player trust | ✅ |
| Not directed at children | Google Play Families policy and COPPA require certified ad SDKs and strict data rules | ✅ Rated 13+; neutral age gate; no child-directed marketing |
| Privacy policy + Data Safety form + consent | Google Play; GDPR (EU); UMP consent for ads | ☐ To do before test launch |
| Healthy play | Player wellbeing; good press | ✅ Optional "take a break" reminder after 60 minutes, playtime stats in settings |

## 23. Revenue scenarios (estimate)

These are illustrations to help you plan. They are not forecasts. Most indie games end up near the **Low** case. Use these numbers to decide how long you can afford to work on the game.

### Android

| Scenario | Average daily players (DAU) | ARPDAU | Gross revenue per month | Gross per year |
|---|---|---|---|---|
| Low | 2,000 | $0.06 | $3,600 | ~$43,000 |
| Medium | 20,000 | $0.12 | $72,000 | ~$864,000 |
| High (a real hit) | 100,000 | $0.18 | $540,000 | ~$6.5M |

### Steam

| Scenario | Copies in year 1 | Price after discounts (average) | Gross | After Steam's 30% cut |
|---|---|---|---|---|
| Low | 3,000 | $6.00 | $18,000 | $12,600 |
| Medium | 30,000 | $6.00 | $180,000 | $126,000 |
| High | 300,000 | $6.00 | $1.8M | $1.26M |

Before tax. Subtract store fees (Google: 15% on the first $1M per year in most markets; 10% plus 5% for Play Billing in the US, UK and EEA from June 2026), ad-network revenue share (already included in ad revenue), and VAT or GST where it applies. **Check how Google pays out to Nepal before relying on IAP revenue** (Section 31, step 0).

---

# PART F: HOW TO BUILD IT

## 24. Art direction

### Style

- **Flat 2D with soft gradients and gentle grain**, like a modern travel poster. Clean, readable and cheap to produce. Small assets keep the download small and the game fast on budget phones.
- The **board is the hero**: a dark, deep-blue slate "stone tablet" with glowing tile edges. Tiles are slightly rounded, with a soft bevel and a clear symbol.
- Backgrounds change per floor (rhododendron forest → bridges → pastures → glacier → storm → ice → death zone → summit) and slowly scroll upward through a run, so the player *feels* the climb.
- Guardians are big, friendly-scary animal spirits with simple shapes, drawn in a style that works as a phone wallpaper.

### Colour palette (starting values)

| Use | Name | Hex | Symbol on tile (for colour-blind players) |
|---|---|---|---|
| Element | Sky | `#2F7FD8` | ✦ star |
| Element | Wind | `#E9EEF3` | ≋ swirl |
| Element | Fire | `#E2483B` | ▲ flame |
| Element | Water | `#22A971` | ● drop |
| Element | Earth | `#F2B632` | ◆ stone |
| Board | Slate | `#18203A` | — |
| Base number | Ice blue | `#7CC4FF` | — |
| Mult number | Ember red | `#FF6B57` | — |
| Gold | Gold | `#FFD15C` | — |

**Every element has its own symbol, not only a colour.** Test all screens with a colour-blindness simulator.

### Asset list for launch (estimate)

| Asset | Count |
|---|---|
| Tile sets (5 elements + 6 bonus + 4 hazard), with clear/break animations | 15 |
| Talisman icons | 48 |
| Rune icons | 16 |
| Guardians (idle + attack + defeat poses) | 12 |
| Climbers (portrait + 2 poses) | 6 (+2 seasonal) |
| Floor backgrounds (layered for parallax) | 8 |
| Base Camp buildings | 10–15 |
| Cosmetic board themes / tile skins | 6 / 6 |
| UI kit (buttons, panels, icons) | 1 set |
| VFX (clear, combo, perfect clear, bomb, freeze, glass shatter) | ~20 |

## 25. Audio and haptics

- **Music:** calm, uplifting tracks built on **bansuri flute, madal drum and sarangi** blended with soft synth pads. This gives an instant, unique identity. One track per two floors, a Guardian theme and a summit theme. Music rises in intensity during the last 2 trays of a round.
- **Clear sounds rise in pitch with each streak step** (a pentatonic scale, so it always sounds good). This is one of the most satisfying audio tricks in puzzle games.
- **Score "slam":** a deep drum hit when Base × Mult combine. A gong and a short choir swell (non-religious, wordless) for a round win.
- **Haptics:** a light tick when you place a piece, a strong pulse on multi-line clears, a long rumble on a Perfect Clear. Use Android's `VibrationEffect` presets. Haptics can be turned off.
- **Budget option:** commission 5–6 tracks from a Nepali musician (a great story for local press too), and use royalty-free sound libraries for effects.

## 26. UX, UI and accessibility

### Screen layout (portrait)

```
┌──────────────────────────────┐
│ Floor 4 · Ridge   ☁ Snowfall │  ← round info + weather
│ Target 2,400   ███████░░ 1,870│  ← progress bar
│ [T1][T2][T3][T4][T5]  🪙 12   │  ← talisman slots + coins
│                              │
│      ┌────────────────┐      │
│      │                │      │
│      │   8 × 8 BOARD  │      │  ← thumb-friendly, centred
│      │                │      │
│      └────────────────┘      │
│    BASE 214  ×  MULT 17      │  ← score breakdown (live)
│                              │
│   [piece]  [piece]  [piece]  │  ← tray (drag from here)
│ Trays left: 3   ↻ 1  [R1][R2]│  ← trays, rerolls, runes
└──────────────────────────────┘
```

### Key UX rules

- **Drag offset:** the dragged piece floats **above the finger** so the player can see where it goes. A ghost preview shows exactly which lines will clear and **the score it would make**, before release. This preview is a huge quality-of-life feature and helps players learn the scoring.
- **Tap any talisman** to see its effect; long-press to see its stats this run.
- **Undo:** no undo by default (it would break the tension), except via a talisman or rune in future packs.
- **Speed:** every animation can be sped up (×1, ×2, ×4) for experienced players.
- **Accessibility:** colour-blind symbols, large-text mode, reduced-motion mode (no screen shake), left-hand mode, one-tap placement option (tap piece, then tap cell), and full controller support on Steam Deck.

### Screens list

Splash → (first launch) Tutorial board → Main menu (Expedition, Daily Climb, Zen, Trial, Base Camp, Codex, Shop, Season) → Climber select → Round → Camp (Draft, Trader, Forge, Build) → Run summary → Codex → Base Camp → Shop → Season Pass → Leaderboards → Settings → Profile.

## 27. Technical architecture

### Engine and tools

| Need | Choice | Notes |
|---|---|---|
| Engine | **Unity 6 LTS** (2D, URP) | Free under $200K revenue/funding; strongest ad/IAP plugin support. Godot 4.6 is a fine alternative, especially for a PC-first approach |
| Language | C# | Same language for client, server checks and bots |
| Tweening | PrimeTween or DOTween | For "juice" |
| Content loading | Addressables | Download season art after install to keep the APK small |
| Localization | Unity Localization package | Text-light design keeps this cheap |
| Input | Unity Input System | Touch + mouse + controller |
| Builds | Android App Bundle (AAB), IL2CPP, ARM64 + ARMv7 | Required by Google Play |
| Android targets | **Target API 36** (Google Play rule from Aug 2026); minimum API 24 (Android 7.0) | Covers almost every active device |
| CI | GitHub Actions + GameCI | Automatic builds and tests on every push |

### The most important decision: a pure C# simulation core

All game rules (board, pieces, scoring, talismans, runes, Guardians, RNG, run state) live in one **plain C# library with no Unity code** (`Summit.Core`). Unity only *shows* what the core decides. This one decision makes these advanced features possible:

1. **Unit tests** for every talisman and rule, run in seconds.
2. **Balance bots** that play 100,000 runs overnight (see below).
3. **Server-side score checks** for Daily Climb leaderboards, by running the same core on a server.
4. **Perfect replays and auto-generated clips**: a replay is just the seed + the list of player inputs.
5. **Easy porting** to Steam, iOS or even a different engine later.

```
Summit.Core      (pure C#, .NET Standard 2.1)  rules, scoring, RNG, run state
Summit.Content   (JSON + ScriptableObjects)     talisman/rune/guardian data
Summit.Game      (Unity)                        views, input, animation, audio
Summit.Services  (Unity, behind interfaces)     ads, IAP, analytics, cloud save
Summit.Sim       (.NET console app)             balance bots
Summit.Server    (.NET on Cloud Run)            Daily Climb score verification
```

### The event pipeline (how talismans work)

Every rule is an **event**. The core raises events in a fixed order, and each talisman reacts to the events it cares about. New talismans are new small classes. The engine itself never needs to change.

```csharp
public enum GameEventType {
    RoundStart, TrayDealt, PiecePlaced, LinesCleared,
    TileDestroyed, PerfectClear, ScoreCalculated, TrayEnd, RoundEnd, CampEnter
}

public sealed class ScoreContext {
    public long   Base;
    public double Mult = 1.0;
    public int    LinesCleared;
    public int    PureLines;
    public Element[] PureLineElements;
    public int    Streak;
    public RunState Run;            // coins, talismans, board, rng streams
    public List<TriggerInfo> Triggers = new();  // read by the UI to animate slots
}

public abstract class Talisman {
    public string Id;
    public virtual ScorePhase Phase => ScorePhase.AddMult;
    public virtual void OnEvent(GameEventType type, ScoreContext ctx) { }
    protected void Trigger(ScoreContext ctx, string popup) =>
        ctx.Triggers.Add(new TriggerInfo(Id, popup));
}

// Example: Ember Heart: +4 Mult for each Pure Fire line
public sealed class EmberHeart : Talisman {
    public int MultPerLine = 4;     // loaded from JSON (see below)

    public override void OnEvent(GameEventType type, ScoreContext ctx) {
        if (type != GameEventType.ScoreCalculated) return;
        int fireLines = 0;
        foreach (var e in ctx.PureLineElements)    // plain loop: no allocations
            if (e == Element.Fire) fireLines++;
        if (fireLines == 0) return;
        ctx.Mult += MultPerLine * fireLines;
        Trigger(ctx, $"+{MultPerLine * fireLines} Mult");
    }
}
```

**Scoring order** is handled by running talismans in phases (AddBase → AddMult → MultiplyMult), in slot order inside each phase. That matches the rule shown to players in Section 6.

### Deterministic random numbers

- Use a small, fast, **seeded** generator (for example PCG32 or xoshiro128\*\*). Never use `UnityEngine.Random` or `System.Random` inside the core: their results can differ between platforms and versions.
- Use **separate streams** for each system (pieces, drafts, Trader, Weather, tile effects). Then a player buying a rune doesn't change which pieces they will get, which keeps daily seeds fair and comparable.

```csharp
public struct Pcg32 {
    ulong state, inc;
    public Pcg32(ulong seed, ulong stream) {
        state = 0; inc = (stream << 1) | 1; Next(); state += seed; Next();
    }
    public uint Next() {
        ulong old = state;
        state = old * 6364136223846793005UL + inc;
        uint xorshifted = (uint)(((old >> 18) ^ old) >> 27);
        int rot = (int)(old >> 59);
        return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
    }
    public int Range(int min, int maxExclusive) =>
        min + (int)(Next() % (uint)(maxExclusive - min));
}

// One run = one seed; each system gets its own stream
var pieces  = new Pcg32(runSeed, stream: 1);
var drafts  = new Pcg32(runSeed, stream: 2);
var trader  = new Pcg32(runSeed, stream: 3);
var weather = new Pcg32(runSeed, stream: 4);
```

(`Range` uses a simple modulo, which is fine for small ranges. Use rejection sampling if you need perfect uniformity.)

### Data-driven content

Talisman numbers live in JSON, so balance patches go out through **Firebase Remote Config** without an app update:

```json
{
  "id": "ember_heart",
  "rarity": "common",
  "price": 4,
  "archetypes": ["element"],
  "params": { "element": "fire", "multPerLine": 4 },
  "unlockLevel": 0
}
```

### Save system

- Save the full run state **after every tray** to a local file, with a checksum. If the app is killed (very common on budget Android phones), the player resumes exactly where they were.
- Cloud save through **Google Play Games Services Saved Games**, and Steam Cloud on PC. Cross-progress between Android and Steam is a post-launch feature (it needs an account system).

### Balance bots (the secret weapon)

Build simple AI players in `Summit.Sim`:

| Bot | Strategy |
|---|---|
| **Greedy bot** | Places each piece where it scores the most right now |
| **Lookahead bot** | Searches all orderings of the current tray (3! = 6 orders × positions) and picks the best |
| **Archetype bots** | Like Lookahead, but they draft and shop toward one archetype |

Run **100,000+ simulated runs** after every balance change and generate a report showing win rate per floor, average score per round compared with targets, pick rate and win rate for every talisman, Coins at each Camp, and how often players get blocked. Flag any talisman whose win-rate impact is far above or below the average. This is how a solo developer can balance 48 talismans × 8 climbers × 10 Altitudes, which would be impossible by hand.

### Performance budget

| Item | Target |
|---|---|
| Frame rate | 60 fps on a 2 GB RAM, 2020-era budget Android phone |
| Install size | < 80 MB base AAB; season art downloaded later via Addressables |
| RAM | < 350 MB |
| Cold start to board | < 4 seconds |
| Battery | No heavy shaders; cap at 60 fps; 30 fps in menus |
| Offline | 100% playable offline (except Daily Climb submission and the shop) |
| Hot path | Zero garbage-collection allocations per placement (pool all VFX and score popups) |

## 28. Backend, leaderboards and anti-cheat

| Service | Use | Cost at launch (estimate) |
|---|---|---|
| Firebase Analytics + Crashlytics | Events, funnels, crash reports | Free |
| Firebase Remote Config + A/B Testing | Balance values, weekly trials, experiments | Free |
| Firebase Cloud Messaging | The 1-per-day useful notification | Free |
| Firebase Auth (anonymous + Play Games) | Player ID for leaderboards and cloud save | Free |
| Firestore | Leaderboards, daily seeds, player profiles | Free tier, then low cost |
| Cloud Run (.NET) | Re-simulates Daily Climb submissions to verify scores | Very low cost at indie scale |
| Google Play Games Services | Sign-in, achievements, cloud save, simple leaderboards | Free |
| Play Integrity API | Checks that the app and device are genuine before accepting a leaderboard score | Free within quota |

### How Daily Climb scores are verified

1. The server publishes today's seed at 00:00 UTC.
2. The player's game records every input (piece index, position, draft choice, purchase, rune use) as a compact list.
3. At the end of the run, the game sends: player ID, seed, input list, claimed score, and a Play Integrity token.
4. The server runs `Summit.Core` with the same seed and inputs. If the result matches the claimed score, it is accepted. If not, it is rejected.
5. Cheating then requires actually playing that well, and a re-simulation costs milliseconds.

## 29. Analytics and A/B testing

### Event plan (core events)

| Event | Key parameters |
|---|---|
| `tutorial_step` | step_id, time_since_install |
| `run_start` | mode, climber, altitude, seed, run_number |
| `round_end` | floor, round_type, result, score, target, trays_left, rerolls_used, guardian_id, weather_id |
| `talisman_offered` / `talisman_picked` | ids offered, id picked, floor, coins |
| `trader_purchase` | item_id, price, coins_before |
| `forge_used` | service, shape, tile_type |
| `run_end` | floor_reached, cause (missed_target / blocked / win), duration, best_placement_score, talismans[] |
| `ad_offer_shown` / `ad_reward_granted` | placement, run_number |
| `iap_view` / `iap_purchase` | product_id, price, currency, entry_point |
| `daily_climb_submit` | score, rank_percentile, verified |
| `session_start` / `session_end` | session_number, length |

### Dashboards to check every week

1. **Retention:** D1, D3, D7, D14, D30, by install week and country.
2. **FTUE funnel:** each tutorial step; where people quit.
3. **Run funnel:** % of runs reaching each floor; most common causes of losing.
4. **Talisman table:** pick rate, win rate, average run score with/without each talisman.
5. **Economy:** Coins at each Camp, what they buy, how often they skip.
6. **Monetization:** ad opt-in rate per placement, ARPDAU, payer conversion, revenue per country.

### First A/B tests (in this order)

1. **First-run difficulty:** tutorial target 150 vs 200; Floor 1 base 300 vs 250. Metric: D1.
2. **Trays per round:** 8 vs 9 on Trail rounds. Metric: run length, D7.
3. **Draft size:** 3 vs 4 choices. Metric: runs per day, D7.
4. **Revive offer:** at loss vs never. Metric: ad revenue *and* D7 (a revive should never hurt retention).
5. **Supporter Pack price:** $3.99 vs $4.99 vs $5.99. Metric: revenue per user.
6. **Interstitial test** (Section 21). Metric: D7 and ARPDAU together.

## 30. Localization and device reach

- **Launch languages (11):** English, Hindi, Nepali, Spanish (Latin America), Portuguese (Brazil), Indonesian, Turkish, German, French, Japanese, Korean. The game uses very little text (talisman sentences, menus), so the total is about 4,000–6,000 words: affordable with professional translators for the key markets plus community review.
- **Number formatting:** use local formats (1,000 vs 1.000) and short forms (1.2M, 3.4B).
- **Reach beyond phones:** Google Play Games on PC (Android games on Windows, almost free to support if mouse controls work), tablets (centred board with side panels), Chromebooks, and Steam Deck (controller support).

---

# PART G: HOW TO SHIP IT

## 31. Production timeline (12 months, estimate)

| Phase | Months | Deliverables | Gate to pass before moving on |
|---|---|---|---|
| **0. Paperwork** | Weeks 0–2 | Confirm Google Play merchant payouts for Nepal (or choose a fallback: ads-only, a company in a supported country, or a publisher); register the developer account and complete identity verification; reserve the game name; open AdMob; set up a privacy policy | A confirmed way to get paid |
| **1. Prototype** | 1–2 | Grey-box board, pieces, scoring, 15 talismans, 3 Guardians, Camp; core in pure C#; first bots | 20+ people playtest; most ask "one more run" **without being asked**; bots show working Coin pacing |
| **2. Vertical slice** | 3–5 | Final art style on Floors 1–3; 30 talismans; Forge; 2 climbers; full juice and audio; FTUE; analytics | The FTUE works with fresh players; first 10 seconds-of-gameplay videos look great |
| **3. Content + audience** | 4–7 | All 8 floors, 48 talismans, 12 Guardians, 6 climbers, Altitudes, Daily Climb with verification, Zen; Steam page live; weekly devlogs; Discord | Steam wishlists and social followers growing every week |
| **4. Closed + open test (soft launch)** | 6–9 | Google Play closed test (meet Google's tester requirement for new personal accounts), then open testing in low-CPI markets (South Asia, Philippines, Brazil, Mexico); $500–2,000 of small paid tests; fix, tune, repeat | **D1 ≥ 30% (≥ 27% acceptable on Android), D7 ≥ 10%, D30 ≥ 4%**, crash-free users ≥ 99.5% |
| **5. Global launch** | 9–12 | Android (+ Google Play Games on PC) and Steam in the same window; Season 1 live; Seasons 2–3 content ready; press and creator outreach | — |
| **6. Live ops** | Ongoing | Weekly trials, 6-week seasons, monthly balance patches, new modes (Section 36) | — |

**Kill rule:** if Phase 4 retention is far below target after **three** rounds of changes, stop. Rethink the core loop, or move to a new prototype. Don't add more content to a game that isn't retaining. That is the most common way indie developers lose a year.

## 32. Team and budget (estimate)

### Team

| Role | Who | Time |
|---|---|---|
| Programmer + game designer | You | Full time |
| 2D artist (tiles, icons, Guardians, backgrounds, UI) | Freelancer or partner | Part time (~40–60% over 9 months) |
| Composer + sound designer | Freelance (ideally a Nepali musician) | ~4–6 weeks of work in total |
| Translators | Freelance per language + community review | Phase 4 |
| Playtesters | Friends, local game dev community, Discord | Ongoing |
| Community manager | You at first; a part-time helper after launch | — |

### Budget

| Item | Low | Comfortable |
|---|---|---|
| Unity Personal, Firebase free tier, GitHub | $0 | $0 |
| Google Play developer account | $25 | $25 |
| Steam Direct fee | $100 | $100 |
| Test devices (2–3 budget + 1 mid-range Android) | $300 | $700 |
| 2D art (freelance) | $3,000 | $10,000 |
| Music and sound | $500 | $2,500 |
| Translation (11 languages) | $800 | $3,000 |
| Paid retention tests (soft launch) | $500 | $2,000 |
| Trademark search, legal templates, privacy policy | $100 | $800 |
| Marketing (trailer, press kit, festival fees) | $200 | $1,500 |
| **Total (excluding your living costs)** | **≈ $5,500** | **≈ $20,600** |

Local freelancers in Nepal and South Asia can make the art and audio budget go much further. Use AI tools for concept exploration and ad-creative variants, but keep final game art made or edited by an artist, so the style stays consistent and there are no rights problems.

## 33. Marketing and community

**The strategy: earn players, don't buy them.** The research showed that paid installs rarely pay back for small teams, so every system is built to create free visibility.

### Before launch (start in month 3)

- **Short videos 3–4 times a week** on TikTok, YouTube Shorts and Instagram Reels. The formats that work: "watch this score go from 400 to 2 million", "this talisman combo is broken", "can you solve this board?" polls, "solo dev from Nepal builds a mountain game" journey stories. Only gameplay is needed, with the score explosion in the first 2 seconds.
- **Steam page by month 5**, with a 30-second trailer that shows gameplay in the first 3 seconds. Join a **Steam Next Fest** with a demo (Floors 1–3). Wishlists are the best early sign that the game is working.
- **Reddit:** r/roguelites, r/roguelikes, r/puzzlevideogames, r/AndroidGaming, r/IndieDev, r/gamedev (devlogs, never spam).
- **Discord server** from the prototype stage. Early testers become the community that defends and spreads the game.
- **Google Play pre-registration** about 6–8 weeks before launch. Pre-registered users are notified at launch.
- **Local angle:** Nepal's tech and gaming press, universities, game dev meetups. "The first Nepali roguelite on Steam" is a story, whether or not it is literally the first. Check before you claim it.
- **Google programs:** apply to Google Play's indie developer programs and festivals (for example the Indie Games Accelerator or Indie Games Festival) when your region is eligible. Check each year's rules.

### At launch

- Send keys and a short press kit to **50–100 puzzle and roguelite creators** on YouTube and Twitch, especially mid-sized ones who love Balatro-likes.
- A **launch-week community event**: a special Daily Climb seed with a global target ("together, climb 1 billion points").
- **Store page (ASO):** title "Summit Shards: Block Roguelite"; short description with "block puzzle", "roguelite" and "offline"; first screenshot shows a huge combo score; use Google Play store listing experiments to test icons and screenshots.

### Built-in sharing (free growth)

- **Clip export:** after a huge placement or a summit, one tap exports a 10–15-second vertical video of the moment, rebuilt from the deterministic replay, with a small watermark and the seed code.
- **Shareable run cards:** an image of your build, score and seed: "Can you beat my Ember build? Seed: K2-YAK-7741".
- **Daily Climb results** shared as a simple emoji grid (like Wordle), which costs nothing and spreads in group chats.

## 34. Success metrics by phase

| Phase | Metric | Target |
|---|---|---|
| Prototype | Voluntary replays per tester | ≥ 3 runs in a sitting |
| Vertical slice | FTUE completion | ≥ 85% |
| Soft launch | D1 / D7 / D30 retention | ≥ 30% / ≥ 10% / ≥ 4% |
| Soft launch | Average session length | 6–10 minutes |
| Soft launch | Sessions per day per DAU | ≥ 3 |
| Soft launch | Crash-free users | ≥ 99.5% |
| Soft launch | Blended ARPDAU | ≥ $0.08 in test markets |
| Pre-launch | Steam wishlists | 7,000+ is a good indie benchmark; 20,000+ is strong (estimate) |
| Launch | Store rating | ≥ 4.5 on Google Play; ≥ 85% positive on Steam |
| Month 3 | DAU trend | Flat or growing without paid ads |

## 35. Risks and how to handle them

| Risk | Chance | Impact | What to do |
|---|---|---|---|
| **Clones copy the game after launch** | High | Medium | Depth (48+ talismans, bots for balance), fast seasons, community, Steam reviews, and a strong name and look. Launch on Android and Steam together so the original is everywhere first |
| **Retention misses targets** | Medium | High | Kill points (Section 31); test the core loop very early with real strangers |
| **Google Play payouts unavailable for Nepal** | Unknown | High | Check in week 1. Fallbacks: ads-only, register a company in a supported country, or partner with a publisher |
| **Low ad revenue in South Asian markets** | High | Medium | Global focus for revenue; South Asia for testing and community; low regional IAP prices |
| **Scope creep** (too many features) | High | High | The 5 pillars; launch with this document's scope; post-launch features stay post-launch |
| **Broken balance** (one build always wins) | Medium | Low–Medium | Bots + Remote Config hotfixes. Roguelite players often *enjoy* broken builds; nerf gently |
| **Cultural misrepresentation** | Low | High | Section 3 rules; community review; invented spirits, no sacred symbols |
| **Burnout** (solo dev) | High | High | Six-week seasons, two seasons built ahead, rest weeks in the live-ops calendar |
| **Policy changes** (Google Play, EU, Brazil) | Medium | Medium | No paid randomness or paid currency means most new rules won't affect you |
| **Name or trademark conflict** | Medium | Medium | Trademark and store search before any public post |

## 36. Post-launch roadmap: the "advanced" features

These features make Summit Shards feel like a premium, modern game. They are planned **after** launch so the core ships on time.

| Update | Timing (after launch) | Feature |
|---|---|---|
| 1.1 | Month 1 | Balance patch from launch data; quality-of-life fixes; Season 1 events |
| 1.2 | Month 2 | **Peaks**: 100 handcrafted puzzles |
| 1.3 | Month 3 | **Ghost Duel**: asynchronous PvP on shared seeds, with skill-based matching and weekly leagues |
| 1.4 | Month 5 | **Rope Teams**: friend groups with weekly shared goals and team leaderboards |
| 1.5 | Month 6 | **Cross-progress** between Android and Steam (account linking) |
| 1.6 | Month 7 | **iOS launch** (the same core; iOS players spend more per user) |
| 2.0 | Month 9–12 | **Steam Workshop and a custom-talisman editor**: players design talismans with a simple visual rule builder (trigger → condition → effect), share them and vote; the best ones join the official game in "Community Seasons" |
| Ongoing | — | New climbers, talisman packs, Guardians every season; accessibility upgrades; more languages |

---

# APPENDICES

## Appendix A: Google Play launch checklist

- ☐ Developer account created; **identity verification** completed (Google's verification programme started in September 2026 in four countries and goes global in 2027)
- ☐ **Payments profile / merchant account** confirmed for your country (check Nepal first)
- ☐ App built as an **Android App Bundle**, signed with Play App Signing
- ☐ **Target API level 36** (required for new apps and updates since 31 August 2026)
- ☐ **Closed testing** with the minimum number of testers and days that Google requires for new personal developer accounts before production access (check the current rule in Play Console)
- ☐ Content rating questionnaire (IARC) completed (aim: 12+/Teen); target audience set to **13+**, not "children"
- ☐ **Data Safety** form filled in honestly (analytics, ads ID, crash data)
- ☐ Privacy policy URL; GDPR/UMP consent for ads in the EU and UK
- ☐ Ads declaration ("contains ads"); in-app purchases declared
- ☐ Store listing: icon, feature graphic, 8 screenshots, 30-second video, localized descriptions
- ☐ Pre-registration campaign set up
- ☐ Play Games Services: sign-in, achievements, leaderboards, Saved Games
- ☐ Pre-launch report checked (crashes, accessibility warnings)
- ☐ Crashlytics + Analytics verified in the release build

## Appendix B: Glossary

| Term | Meaning |
|---|---|
| **ARPDAU** | Average revenue per daily active user, per day |
| **CPI** | Cost per install, the price of getting one player through ads |
| **D1 / D7 / D30** | % of new players who come back 1, 7 or 30 days after installing |
| **DAU** | Daily active users |
| **FTUE** | First-time user experience: the first minutes of play |
| **Hybrid-casual** | Simple casual gameplay + deeper progression + both ads and purchases |
| **Live ops** | Updating a live game with events, seasons and content |
| **Meta** | Systems outside the core gameplay (progression, collection, Base Camp) |
| **Remote Config** | Changing game values from a server without an app update |
| **Roguelite** | A game of repeated runs with random content, where each run gives some permanent progress |
| **Soft launch** | Releasing in a few test countries before the global launch |

## Appendix C: Key sources (from the October 2026 research report)

- Sensor Tower, *State of Gaming 2026* and H1 2026 analysis: market size, puzzle +20%, strategy, hybrid-casual growth.
- GameAnalytics, *2026 Mobile & PC Gaming Benchmarks*: D1/D7/D30 medians and top quartile; session length.
- Liftoff, *2025 Casual Gaming Apps Report*: Android vs iOS CPI and ROAS.
- AppsFlyer data (via Game Growth Advisor): hybrid vs IAP-only vs ad-only ROAS.
- MobileGamer.biz: Vampire Survivors mobile, 5M downloads with no paid UA.
- PocketGamer.biz: Pixel Flow ~$198M first year; India 8.45B installs; Archero 2.
- Business Wire: Block Blast #1 downloads Q1 2026; 70M DAU, 10,000+ A/B tests.
- Naavik and Deconstructor of Fun: Royal Match's light meta; hybrid-casual progression; Habby's template; Voodoo's prototyping.
- FTC (Genshin Impact settlement, January 2025); Mayer Brown (Brazil Digital ECA); Lewis Silkin and Irish Times (EU action, September 2026); Google Play policy pages.
- Unity pricing updates; Godot 4.5.2 and GABE releases; Android Developers (target API 36; Play billing changes, June 2026).

The full report with every link: `reports/Best Android game to build 2026.md`.

---

*End of document. Build the prototype first. Everything in this document becomes real only when strangers play it and ask for one more run.*
