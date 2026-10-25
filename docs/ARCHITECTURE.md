# Architecture and rule decisions

Prepared from the supplied Summit Shards design on 2026-10-24. The active Android project is `SummitShards/project.godot` (Godot 4.7.2, GDScript, GL Compatibility). The unused Unity/C# prototype and its tooling have been removed from the repository.

Updated platform decision, 2026-10-25: **Android is the only shipping platform**. The Windows export and desktop build helper have been removed. Editor previews and tests on Windows are development tools. The complete implementation roadmap and instructions are in [ANDROID_GAME_BUILD_PLAN.md](../ANDROID_GAME_BUILD_PLAN.md).

## Active project boundaries

`round_model.gd` extends RefCounted. It owns board, shapes, seeded bag, score, round budget and serializable state. It has no node, rendering, time, filesystem or network dependency. `main.gd` draws the state, translates taps to model commands, and owns local persistence. The scene is a full-screen Control with a portrait reference layout. Touch emulates one mouse pointer, avoiding double submission of touch and mouse events.

A tap selects a tray slot; a second tap places its bounding-box origin. Mouse hover displays a valid placement and its projected score. Board cells, tray cards and buttons remain inside the Android display safe area. Five colors also carry distinct symbols. New Round and Reroll are at least 48 reference dp high at the 360 dp portrait width. Drag input, animation, haptics, sound and screen-reader semantics are later UI work.

`panel()` caches immutable styles for the finite palette instead of allocating a StyleBoxFlat for every tile on each redraw. Pointer movement redraws only while a piece is selected and the hovered cell changes. The project caps active rendering at 60 FPS, enables Android frame pacing and low-processor mode, and permits normal screen timeout. The current static board has no per-frame gameplay loop. Phone frame rate and battery changes are measurement tasks, not inferred outcomes of these settings. Future animated scenes must reassess low-processor mode with device traces.

Back first cancels the selected piece; a subsequent Back in this single-screen starter saves and exits. Pause/focus loss save; resume/focus return redraw to recalculate safe areas. A complete navigation/pause hierarchy is specified in the plan and is not implemented by this change.

## Rules

- 19 fixed shapes: dot, horizontal/vertical bars of lengths 2-5, four small-L rotations, four five-cell-L rotations, 2x2 and 3x3 squares. No runtime rotation or gravity.
- `(0,0)` is the top-left of the board. A shape's bounding-box origin can itself be empty for some L rotations.
- Rows and columns are inspected together before removal. Crossing tiles are removed/scored once. Each pure line earns its own bonus.
- Base = placed cells + cleared unique cells x10 + pure lines x50 + perfect-clear bonus 200.
- Mult starts at 1, adds one per line beyond the first and one per pure line, then streak and talismans. First clearing streak adds 0.5; the bonus caps at +3. A non-clear resets it.
- Talisman phases are additive before multiplicative; preserve slot order inside a phase. The GDD's suggested interleaved ordering conflicts with its explicit global phases. This starter follows the global phases. Ember Heart and Twin Rope are model scoring examples and tests, not equipped/draftable UI content.
- Perfect Clear multiplies the final Mult by 3. Score is floored only after Base x Mult. The supplied worked example yields 214 x17 = 3,638.
- A round ends immediately when score reaches 300. The eight-tray budget allows at most 24 placements. A blocked round with a reroll can still reroll; without one, it loses.
- Small shapes (up to three cells) have weight 2; others have weight 1 in a shuffled bag. Above 60% occupancy, half of large draws become dots. A wholly blocked new tray gets at most three retries. This does not guarantee every piece or full tray is solvable.
- A reroll replaces unused tray slots, spends the round's one reroll and does not grant an extra tray.

## Determinism and persistence

The active model pins nonzero xorshift32 with explicit 32-bit masks and rejection sampling. Known reference values are tested. All randomness comes from that state; the scene uses time only when choosing a new round seed. A save stores the remaining shuffled bag, RNG state, board, tray, seed, score, target, streak, tray budget, reroll and status.

JSON loads validate the schema and numeric types before mutating live state. Numeric fields are normalized to integers after JSON decoding so uninterrupted and restored snapshots match. Save envelopes contain the exact payload and its SHA-256, with a flushed temporary file and previous-save backup. A damaged primary falls back to the backup. This recovers corruption; it does not provide cheat resistance or guarantee survival of every possible filesystem/power failure. A recovered backup can be one move behind.

The adapter caches the last successfully saved state checksum and skips identical writes during repeated pause/focus notifications. After recovery it replaces the damaged primary while retaining the known-good backup. These paths are exercised through the actual scene adapter.

Replay schema version 1 is Godot-specific. Earlier experimental C# PCG32 saves are not seed/replay compatible and must not be imported. Later content changes need explicit replay/content versioning and separate streams for drafts, weather and shops.

## Validation scope

Native rules tests cover scoring, simultaneous clears, no gravity, atomic rejection, deterministic continuation, invalid saves and 1,000 terminating seeded rounds. Scene tests exercise selection, placement, buttons, save/resume and corrupt-primary backup recovery through the actual adapter. A rendered desktop viewport verifies layout separately from headless tests. Android export and signature/archive/manifest validation establish packaging, not phone performance or touch behavior. The current one-round bots cannot estimate full expedition balance or retention.
