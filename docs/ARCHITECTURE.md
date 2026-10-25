# Architecture and rule decisions

Prepared from the supplied Summit Shards design on 2026-10-24. The active Android project is `SummitShards/project.godot` (Godot 4.7.2, GDScript, GL Compatibility). The unused Unity/C# prototype and its tooling have been removed from the repository.

Updated platform decision, 2026-10-25: **Android is the only shipping platform**. The Windows export and desktop build helper have been removed. Editor previews and tests on Windows are development tools. The complete implementation roadmap and instructions are in [ANDROID_GAME_BUILD_PLAN.md](../ANDROID_GAME_BUILD_PLAN.md).

## Active project boundaries

`round_model.gd` extends RefCounted. It owns board, shapes, seeded bag, score, round budget and serializable state. It has no node, rendering, time, filesystem or network dependency. `main.gd` draws the state, translates taps to model commands, and owns local persistence. The scene is a full-screen Control with a portrait reference layout. Touch emulates one mouse pointer, avoiding double submission of touch and mouse events.

Input is one pointer: press, move and release. Pressing a tray shard and moving past a 14-pixel threshold starts a drag; the shard floats 130 reference pixels above the finger and its top-left snaps to the nearest board cell. Release commits once if legal, otherwise the shard returns. A tap without movement selects or deselects a shard; with a shard selected, pressing the board previews at the cell under the finger and release places there. Pause, focus loss, resize and Back cancel any gesture without consuming a piece. Desktop mouse hover previews too. Board cells, tray cards and buttons remain inside the Android display safe area. Five colors also carry distinct symbols. Every button's touch area is at least 96 reference pixels (48 dp at the 360 dp reference width) high; the pause icon draws smaller than its touch area. Haptics and screen-reader semantics are later work.

Routing: the scene has two routes (Home, Play) and a dialog stack (How to Play, Pause, Settings, Result, confirmations). `current_buttons()` returns the on-screen controls; drawing and hit-testing share it, and while a dialog is open only its controls exist, so nothing beneath it can be tapped. The Result dialog ignores taps during its 0.8 s entrance (none with Reduced Motion).

Presentation: a move is committed and saved before it is animated. `ui/effects.gd` holds pops, clear flashes, particles (max 144), floating text (max 6) and shake, all expiring. `_process` runs only while effects, the score counter or a dialog entrance are active. `ui/sfx.gd` synthesizes eight short sounds once at startup and plays them through four reused players; headless runs skip playback. Settings and profile live in `user://settings-v1.json` and `user://profile-v1.json` through `persistence/json_store.gd` (checksum envelope, temp file, previous-write backup), separate from the round save.

`panel()` caches immutable styles for the finite palette instead of allocating a StyleBoxFlat for every tile on each redraw; alpha is quantized to sixteenths so fades reuse a bounded set. Pointer movement redraws only while a piece is selected and the hovered cell changes, or while a drag moves. The project caps active rendering at 60 FPS, enables Android frame pacing and low-processor mode, and permits normal screen timeout. The current static board has no per-frame gameplay loop. Phone frame rate and battery changes are measurement tasks, not inferred outcomes of these settings. Future animated scenes must reassess low-processor mode with device traces.

Back cancels a drag or selection, then closes the top dialog, then opens Pause during play, and on Home asks before exiting. Pause/focus loss save; app pause mid-round also opens Pause. Resume/focus return redraw to recalculate safe areas.

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

Round snapshots also carry `moves`, `lines_total`, `best_move` and `perfect_count`. They are optional on load (missing means zero) so saves from 0.1.x still restore; present values must be non-negative integers. The profile records a finished round once, keyed by its seed, so reloading or relaunching on a finished round never double counts it.

JSON loads validate the schema and numeric types before mutating live state. Numeric fields are normalized to integers after JSON decoding so uninterrupted and restored snapshots match. Save envelopes contain the exact payload and its SHA-256, with a flushed temporary file and previous-save backup. A damaged primary falls back to the backup. This recovers corruption; it does not provide cheat resistance or guarantee survival of every possible filesystem/power failure. A recovered backup can be one move behind.

The adapter caches the last successfully saved state checksum and skips identical writes during repeated pause/focus notifications. After recovery it replaces the damaged primary while retaining the known-good backup. These paths are exercised through the actual scene adapter.

Replay schema version 1 is Godot-specific. Earlier experimental C# PCG32 saves are not seed/replay compatible and must not be imported. Later content changes need explicit replay/content versioning and separate streams for drafts, weather and shops.

## Validation scope

Native rules tests cover scoring, simultaneous clears, no gravity, atomic rejection, deterministic continuation, invalid saves and 1,000 terminating seeded rounds. Scene tests exercise selection, placement, buttons, save/resume and corrupt-primary backup recovery through the actual adapter. A rendered desktop viewport verifies layout separately from headless tests. Android export and signature/archive/manifest validation establish packaging, not phone performance or touch behavior. The current one-round bots cannot estimate full expedition balance or retention.
