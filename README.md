# Summit Shards Android development

**The working starter uses Godot 4.7.2 + GDScript.** Open `SummitShards/project.godot`, or double-click **Open-Godot.cmd**. Press **F6** with `main.tscn` open, or **F5** to play the project. **Play-Game.cmd** runs it directly; **Open-VSCode.cmd** opens the configured code workspace.

**Android is the only shipping platform.** APK/AAB builds are the product outputs. PC editor previews are development tools. The Windows export preset and desktop build script have been removed; web, iOS and desktop products are outside scope.

Read the full step-by-step [Android game build plan](ANDROID_GAME_BUILD_PLAN.md) for implementation phases, developer instructions, phone performance budgets, acceptance checks and release steps.

GDScript is the selected language for this 2D Android game: it integrates directly with Godot's scenes, touch input and Android exporter. The repository contains one Godot implementation and its Android development tools.

The active project imports, renders, passes its native checks and exports a verified Android APK. See [current verification](docs/SETUP_STATUS.md).

## Playable game

Progression and modes (0.5.0-dev):

- **Runes**: 12 one-use powers, two slots, bought at the Trader (2 offers per Camp, 3 Coins). Rune of Time (+2 trays), Shattering (destroy a row or column you choose; keeps the streak), Thaw (remove Stones), Wealth (double Coins, max +15; works at Camp), Echo (next placement scores twice), Shrinking (a shard becomes a dot), Stillness (3 placements cannot break the streak) and five Dyes (the tray becomes one element). Tap a rune, confirm, then pick a target if it needs one. Holding Shattering or Shrinking keeps a stuck round alive until you use it.
- **Expedition XP and levels 1-50** with the design's XP table (10 per round won, 25 per Guardian, 100 for the summit, 15 per Codex discovery) and thresholds. New players start with the design's 19 starter talismans and 10 runes; levels 2-10 unlock the Daily Climb, the other 17 talismans and Shattering/Shrinking. The run summary shows XP earned, the level bar and new unlocks.
- **Altitudes 1-10**: each summit at your highest Altitude unlocks the next; choose one on Home. Cumulative rules from the design: harder targets (x1.25, x1.5, x2), dearer Trader, 2-card drafts, Ridges with extra Stones, no starting reroll, Guardians with a second rule, interest capped at 3, 7-tray rounds, and a disabled talisman at Altitude 10.
- **Daily Climb** (level 2): the same seed for every player on the same local date, Altitude 0 with everything unlocked, one attempt per day, saved separately so an expedition can wait. It is a local, offline mode: there is no leaderboard and nothing is uploaded.
- **Codex**: every talisman, rune, weather and Guardian, with silhouettes for those not yet met. Holding or meeting something adds it (and XP).
- Bot balance with the new player's starter pool: a first-fit bot mostly ends on floors 3-5 and a greedy bot on floors 5-6, with no summits, so the summit arrives after a few unlocks. Altitude 5 is clearly harder; Altitude 10 ends half of greedy runs on Floor 1.

Two modes from Home:

- **Expedition** (0.3.0-dev): the roguelite run from the design. Eight floors, each with a **Trail**, a **Ridge** (with weather) and a **Guardian** round (with a boss rule), using the design's target table (300 up to 30,000). Win a round to reach **Camp**: take 1 of 3 free talismans (or skip for +3 Coins), buy from the **Trader** (reroll 2, then 3...), sell for half, reorder. Coins come from round rewards, unused trays and interest (+1 per 5 held, max 5). Lose a round and the run ends, unless a Firebird Feather saves it once. Beat The Summit Warden on Floor 8 to reach the summit. Runs save after every move and resume from Home.
- **Quick Trail**: the original single 300-point round, unchanged.

**36 talismans** from the design, across Common, Uncommon, Rare and Legendary, change scoring (+Base, +Mult, xMult, growth, economy, rerolls, trays, slots). Scoring always applies every +Base, then every +Mult, then every xMult, then the perfect-clear multiplier; Mirror Lake copies its right-hand neighbour. Each placement shows its breakdown (for example `+3,638 = 214 x 17`), and the talismans that changed it light up. **Hazards:** 5 Ridge weathers (Clear Sky, Thin Air, Rockfall, Snowfall, Golden Hour) and 7 Guardians (Stone Yak, Moon Bear, Frostmane, Thunder Kite, Langur Trickster, Crow of Lights, Summit Warden). Stone tiles take two clears to break.

Balance check with `tests/balance_sim.gd` (bots, Altitude 0): a first-fit bot mostly ends on floors 3-4 and a greedy bot on floors 5-6; each reaches the summit in about 8% of runs. The design's goal is floors 3-4 for a new player. Human playtesting is still needed.

**Drag a shard onto the board**: it floats above your finger, snaps to the board, shows its score and outlines the lines it will clear. Release to place; release anywhere illegal to return it. Or **tap a shard, then tap** the cell for the top-left of its bounding box (hold and slide on the board to preview first). Fill rows or columns to climb. Reach 300 altitude within eight trays, with one reroll per trail.

Screens: **Home** (Expedition, Quick Trail, lifetime stats), **Round intro**, **Camp**, **Round cleared**, **Expedition summary**, **Talismans**, **How to Play** (shown on first start), **Pause**, **Settings**, **Round Result** and confirmation dialogs. Android Back cancels a drag or selection, then closes the top dialog, then pauses play, and on Home asks before exiting. Leaving the app mid-round saves and pauses. Starting a new trail mid-round asks first.

Feel: placement pop, line-clear flash and bursts, floating score and combo callouts (Double, Pure Line, Streak, Perfect Clear), a small shake on big clears, an animated altitude counter and progress preview, "No room" marking on shards that cannot fit, and synthesized sound effects (no audio files). Settings: sound, line-clear preview, reduced motion and a 30 FPS battery saver.

Stats: best altitude, summits, trails played, summit streak, lines, perfect clears and best move. Each finished trail is counted exactly once, even across reloads; an abandoned trail with moves counts as played.

Implemented rules: portrait 8x8 board, 19 shapes, three-piece tray, seeded weighted bag, simultaneous line clears, pure lines, streaks, perfect clears, score target, win/loss and local save/backup recovery. Elements have both colors and symbols. This is one Trail round; the full expedition, Camp drafts, Guardians, weather, progression and final art are future game work.

Any device shape (0.4.0-dev):

- **Responsive zones.** The layout fits the 720x1280 design into the safe area, then spreads over the screen's real shape. On tall phones (20:9, 21:9) the header stays at the top, the tray and buttons move down toward the thumb (keeping a margin above the gesture bar), the board settles between, the tray cards grow (bigger shards to grab) and dialogs centre. On tablets, foldables and split-screen windows the game keeps full height and fills the side margins with scenery that runs edge to edge.
- **Side panels on wide screens.** With enough room beside the board (for example an unfolded foldable), the left panel shows the round (floor, weather or Guardian rule, target, trays, rerolls, Coins) and the right panel lists your talismans with their rules. Quick Trail shows its stats and a scoring guide instead.
- **Adaptive effects.** While something animates, the game watches its own frame time. If a device cannot keep up, bursts drop to a lighter level (fewer particles) and come back when frames are on time again. Scores and saves never depend on it.
- **Smooth 90/120 Hz (setting, off by default).** On high-refresh screens, motion can run at the screen's own rate (up to 120) while something moves; still screens stay at 60 and Battery saver still caps at 30. The setting names your screen's reported rate.
- Checked by an automated sweep of 9 screen shapes (from 480x800 to 21:9, 3:4, near-square and very wide windows): every control on every screen stays visible, zones never overlap, and taps and drags land on the right cells.

Android smoothness (0.2.1-dev):

- **Layered drawing.** The screen is split into layers that repaint only when their own content changes. Dragging moves the shard's layer; shake, fades, slides and tray refills move or fade layers. The 64-tile board repaints only when a move lands. Measured with `tests/perf_probe.gd` on the development machine: drawing work per frame while dragging fell from 1.84 ms to 0.07 ms, and during a line clear from 2.02 ms to 0.47 ms. Idle frames paint nothing.
- **Full speed only while moving.** Low-processor mode (which sleeps a little each frame to save battery) is lifted while something animates or a finger drags, then restored as soon as the screen is still.
- **Faster start.** Sound effects are synthesized on a background thread, removing about 27 ms of main-thread work here (more on a budget phone). Fonts used by big callouts are warmed shortly after launch so the first clear does not stall.
- **Every screen shape.** The layout fills tall (20:9) and wide screens without black bars, sits a little low on tall phones for thumb reach, and keeps a margin above the bottom gesture area. Layout is computed on resize/resume only, never per touch event.
- **Seamless launch.** The Android launch screen uses the game's background colour instead of a grey Godot logo screen.
- Animated touches: shards grow as they lift, fly back to the tray when dropped off the board, and pop into the tray when dealt; screens and dialogs fade in. Reduced Motion removes the movement.

The 60 FPS cap, normal screen timeout and zero Android permissions are unchanged. Haptics are not included because they require an Android permission the project's policy currently forbids. Phone frame rates, battery use and touch feel still need measuring on hardware.

The supplied [Markdown](docs/GAME_DESIGN.md) and [PDF](docs/GAME_DESIGN.pdf) are preserved design references. Their instructions about future publishing, services or monetization are not treated as commands to perform those actions.

## Android APK

**Built artifact:** `C:\game\Builds\Android\SummitShards-debug.apk` (about 55 MiB).

It is a development build, signed with the local Godot debug key. Verified: ZIP contents, APK signature, ARM64/ARMv7, portrait orientation, minimum API 24, target API 36, and no requested Android permissions. The neighboring `.json` records the exact SHA-256 and build metadata. No physical phone was connected during setup.

To install on your phone, enable Developer options and USB debugging, connect by USB, then authorize this computer on the phone:

```powershell
. .\tools\Enter-Dev.ps1
adb devices -l
adb install -r .\Builds\Android\SummitShards-debug.apk
```

## Development commands

Run these from `C:\game`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Doctor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Game.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Android.ps1
```

The VS Code workspace provides Open Godot, Play, Test, Build APK and Check Tools tasks. Open Godot alongside VS Code for its language server. If opening the workspace file manually, set `godotTools.editorPath.godot4` to the editor path in the setup status, or open it through `Open-VSCode.cmd` to inherit the configured environment.

Tools live in `D:\SummitShardsToolchain` because C: has limited free space. The SDK and JDK are independent of Unity. `Builds` points to the tools drive through a directory junction. Sources remain in `C:\game`. `tools/Enter-Dev.ps1` configures only the current terminal and its children; it does not replace system-wide Java or security settings.

`tools/Install-Toolchain.ps1` can restore the pinned portable Godot tools and standalone Android SDK/JDK using Python 3.11+ and curl. Godot downloads use official release SHA-256 hashes; Android ZIPs are pinned in `tools/android-release-lock.json`. The script reuses installed files. On a fresh installation, accept the SDK licences with `sdkmanager --licenses`; the licences on this PC are already accepted. Run Doctor and the build afterward to validate any restored setup.

## Source layout

- `SummitShards/scripts/round_model.gd`: pure round rules and versioned state, independent of scenes, clocks and filesystem: board, shards, Stones, hazard rules and the talisman scoring pipeline.
- `SummitShards/scripts/run_model.gd`: pure expedition state machine: floors, encounters, Coins, Camp draft and Trader, Firebird, saves.
- `SummitShards/scripts/content/talismans.gd`, `content/encounters.gd`, `content/runes.gd`, `content/progression.gd`: talismans, weather, Guardians, targets, runes, XP, levels, unlocks and Altitudes (data only).
- `SummitShards/scripts/main.gd`: screens and dialogs, tap/drag input, drawing, safe-area layout and the round save adapter.
- `SummitShards/scripts/settings_model.gd`, `profile_model.gd`: validated player settings and lifetime statistics.
- `SummitShards/scripts/persistence/json_store.gd`: checksummed settings/profile documents with a backup.
- `SummitShards/scripts/ui/effects.gd`, `ui/sfx.gd`: bounded presentation effects and synthesized sound effects.
- `SummitShards/tests`: native Godot checks (`rules_test`, `run_test`, `meta_test`, `scene_test`, `expedition_scene_test`), `render_meta.gd` for the progression screens, screen capture utilities (`render_preview.gd`, `render_expedition.gd`), a drawing-cost probe (`perf_probe.gd`) and a balance simulator (`balance_sim.gd`). Excluded from exported games.
- `SummitShards/export_presets.cfg`: Android-only export settings.
- `tools/check_android_policy.py`: platform and mobile-default checks, run before tests/builds.
- `tools`: pinned manifests, isolated environment, installers, checks and build commands.
- `docs`: original design, architecture, verification and release guidance.
- `CONTRIBUTING.md`: branch workflow and validation expectations.

## Release preparation

Package ID `com.summitstudio.summitshards`, version `0.5.0-dev` and the studio name are development placeholders. Choose your permanent identity before publishing. The debug key is not an upload key. No Play Store AAB, release signing key or store submission was created.

Godot's matching `android_source.zip` and Android release export template are installed for later Gradle/AAB configuration. See [Android release steps](docs/ANDROID_RELEASE.md). The installer now selects only Android export templates. Ads, IAP, analytics, cloud services and leaderboards are not connected. API 36 is this project's configured target, not a promise about a future Play policy deadline.

## Branch workflow

`main` holds stable source; `develop` integrates the next Android milestone. Create `feature/*` and `fix/*` branches for concrete changes, open pull requests into `develop`, then promote validated milestones to `main`. Release and hotfix branches are created when needed. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Official references

- [Godot Android export requirements and C# caveat](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Pinned Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
- [Godot Android Gradle build](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html)
- [Android app signing](https://developer.android.com/studio/publish/app-signing)

Godot engine and third-party notices are included in `SummitShards/assets` and in the game exports.
