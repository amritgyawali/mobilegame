# Architecture and rule decisions

Prepared from the supplied Summit Shards design on 2026-10-24. The active Android project is `SummitShards/project.godot` (Godot 4.7.2, GDScript, GL Compatibility). The unused Unity/C# prototype and its tooling have been removed from the repository.

Updated platform decision, 2026-10-25: **Android is the only shipping platform**. The Windows export and desktop build helper have been removed. Editor previews and tests on Windows are development tools. The complete implementation roadmap and instructions are in [ANDROID_GAME_BUILD_PLAN.md](../ANDROID_GAME_BUILD_PLAN.md).

## Active project boundaries

`round_model.gd` extends RefCounted. It owns board, shapes, seeded bag, score, round budget and serializable state. It has no node, rendering, time, filesystem or network dependency. `main.gd` draws the state, translates taps to model commands, and owns local persistence. The scene is a full-screen Control with a portrait reference layout. Touch emulates one mouse pointer, avoiding double submission of touch and mouse events.

Input is one pointer: press, move and release. Pressing a tray shard and moving past a 14-pixel threshold starts a drag; the shard floats 130 reference pixels above the finger and its top-left snaps to the nearest board cell. Release commits once if legal, otherwise the shard returns. A tap without movement selects or deselects a shard; with a shard selected, pressing the board previews at the cell under the finger and release places there. Pause, focus loss, resize and Back cancel any gesture without consuming a piece. Desktop mouse hover previews too. Board cells, tray cards and buttons remain inside the Android display safe area. Five colors also carry distinct symbols. Every button's touch area is at least 96 reference pixels (48 dp at the 360 dp reference width) high; the pause icon draws smaller than its touch area. Haptics and screen-reader semantics are later work.

Routing: the scene has two routes (Home, Play) and a dialog stack (How to Play, Pause, Settings, Result, confirmations). `current_buttons()` returns the on-screen controls; drawing and hit-testing share it, and while a dialog is open only its controls exist, so nothing beneath it can be tapped. The Result dialog ignores taps during its 0.8 s entrance (none with Reduced Motion).

Layers (0.2.1-dev): `main.gd` draws only the background itself. Node2D layers under a `Content` node hold the layout transform: chrome (static frame), board (tiles), preview (ghost, clear outlines, collisions), hud (tray cards, buttons, labels), score (counting altitude, progress, hint), three tray slots, fx (pops, clears, particles, floating text) and drag (the lifted shard). The dialog layer sits under a separate `Overlay` node. Layers are Node2D because a Control repaints when its scale changes. `refresh_view()` repaints the layers a command can affect, once per tap or command. Per frame, only the fx layer and, when the shown number changes, the score layer repaint. A drag moves its layer with the finger and repaints preview/score only when the snapped cell changes; the board repaints when a move lands and once when placement pops end. Slot refills, the drag lift and return, screen transitions and dialog entrances are tweens on position, scale and modulate. The delayed result dialog stays hidden, and so unpainted, until its entrance. `perf` counts repaints and time per layer for tests and `tests/perf_probe.gd`.

Power: low-processor mode (project setting, required by the Android policy check) sleeps about 7 ms each frame. `start_animation()` lifts it while effects, tweens or a drag run; `_process` restores the project value when everything is still and stops itself. The setting is read from ProjectSettings, so a scene freed mid-animation cannot leave a later one with the wrong default.

Layout: `display/window/stretch/aspect` is `expand`, so tall and wide screens get more viewport instead of black bars. `update_layout()` fits the 720x1280 reference into the Android safe area (centred horizontally, 65% of spare height above it) and runs on start, resize and resume only; pointer events reuse the cached transform instead of querying the display through JNI per event. The launch splash and clear colour match the background.

Presentation: a move is committed and saved before it is animated. `ui/effects.gd` holds pops, clear flashes, particles (max 144), floating text (max 6) and shake, all expiring. `_process` runs only while effects, the score counter or a dialog entrance are active. `ui/sfx.gd` synthesizes eight short sounds on a WorkerThreadPool task at startup and adopts them when the task completes (a sound requested before then is skipped); it plays them through four reused players, and headless runs skip playback. Shortly after launch the chrome layer draws the callout glyphs invisibly once so the font cache is warm before the first big clear. Settings and profile live in `user://settings-v1.json` and `user://profile-v1.json` through `persistence/json_store.gd` (checksum envelope, temp file, previous-write backup), separate from the round save.

`panel()` caches immutable styles for the finite palette instead of allocating a StyleBoxFlat for every tile on each redraw; alpha is quantized to sixteenths so fades reuse a bounded set. Pointer movement redraws only while a piece is selected and the hovered cell changes, or while a drag moves. The project caps active rendering at 60 FPS, enables Android frame pacing and low-processor mode, and permits normal screen timeout. The current static board has no per-frame gameplay loop. Phone frame rate and battery changes are measurement tasks, not inferred outcomes of these settings. Future animated scenes must reassess low-processor mode with device traces.

Back cancels a drag or selection, then closes the top dialog, then opens Pause during play, and on Home asks before exiting. Pause/focus loss save; app pause mid-round also opens Pause. Resume/focus return redraw to recalculate safe areas.

## Expedition (0.3.0-dev)

`run_model.gd` (RefCounted, pure) owns the run: floor (0-7), stage (Trail, Ridge, Guardian), phase (`intro`, `round`, `camp`, `won`, `lost`), Coins, talismans in slot order, the current round, Camp offers and counters that persist across rounds (Snowball stacks, Eternal Glacier lines). `after_round_command()` settles a finished round exactly once: rewards and Camp, the summit, a Firebird restart, or the end of the run. The scene saves the run (`user://run-v1.json`, checksummed with a backup) after every command. A run saved between a finished round and its settlement is settled on load; a finished run is recorded in the profile once, keyed by its seed.

Randomness: each round's seed is mixed from the run seed, the encounter index and the Firebird attempt. Weather and Guardians are mixed from the run seed and the encounter. Camp offers use a separate run stream. Taking a draft or rerolling the Trader therefore never changes the next round's hazard or shards (tested).

Content lives in `content/talismans.gd` and `content/encounters.gd` as plain data. Talisman effects are a bounded `match` on the id in `round_model.calculate_score()` and in `run_model` (rerolls, trays, Coins, slots, Firebird); content strings are never evaluated. Targets use the design's table directly.

Round configuration: an expedition round receives its talismans, rules (`stones_start`, `rockfall`, `frost`, `min_cells`, `streak_cap_halves`, `langur`, `crow`, `golden_hour`), reroll limit and Coins. Snapshots store the config and counters; saves without them (Quick Trail and 0.2.x) load with empty defaults. Quick Trail passes no config and deals exactly as before (the 1,000-seed fixture is unchanged).

Scoring pipeline (`calculate_score`): Base (placed cells, removed cells x10, pure lines x50, Stones broken, +Base talismans, perfect +200); then Mult (1, extra lines, pure lines, capped streak, +Mult talismans); then each xMult talisman; then the perfect-clear multiplier (x3, Clean Slate x5). This keeps the project's global-phase decision, so slot order matters only for Mirror Lake (copies the talisman to its right), the Langur (one disabled slot, moving right every tray) and the Crow (shuffles the order every tray). `evaluate()` computes a move on a copy of the board and is shared by the preview and the real move, so they always agree; Golden Hour Coins are rolled after scoring.

Tiles: 0 empty, 1-5 elements (Sky, Wind, Fire, Water, Earth), 6 Stone, 7 Cracked Stone. A clear cracks Stone and removes Cracked Stone (Ice Axe: Stone breaks at once). Stones complete lines but never make them pure. Stones are placed by choosing among empty cells with a bounded shuffle, never by retrying random positions.

Simplifications versus the design, kept explicit: the Summit Warden applies the rules of the last two Guardians beaten instead of three phases; Snowfall and Frostmane use Stone rather than Frozen tiles; 12 talismans that need systems not built yet (bonus tiles, Frozen tiles, interest changes, rotation) are not included; there are no runes, Forge, climbers, Altitudes or unlocks yet.

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
