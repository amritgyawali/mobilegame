# Setup verification

Updated: 2026-10-25 (Asia/Katmandu). Sources: `C:\game`. Active project: `C:\game\SummitShards`. Tools: `D:\SummitShardsToolchain`.

## 0.3.0-dev Expedition (2026-10-25)

Version code 5, version `0.3.0-dev`. Verified in the Linux container with the official Godot 4.7.2 Linux editor.

- `tools/check_android_policy.py` passed; still no Android permissions.
- **1,156 rules checks** (Quick Trail unchanged: same 1,000-seed fixture, 996 first-fit wins), **114 expedition rule checks** (`run_test`: every talisman's scoring, phases and the design's 3,638 example; Stones, Ice Axe, Rainbow Scarf; each hazard; preview equals commit across 40 seeded rounds with a 9-talisman build and every hazard; deterministic runs; rewards and interest; draft, Trader, swap, sell, Ninth Peak, reorder; Camp choices never change upcoming hazards or shards; Firebird; the Warden and summit; run and round save round trips and rejection of damaged saves), **91 scene checks** and **35 expedition scene checks** (Home, tutorial over the intro, Back on every expedition screen, Round cleared to Camp, draft, buy, move, sell, relaunch in Camp, Firebird, run over counted once, abandon, Quick Trail kept, 48 dp targets). No script errors or warnings. CI and `tools/Test-Game.ps1` now run all four suites.
- Bot balance (`tests/balance_sim.gd`, Altitude 0): first-fit, 60 runs: mostly floors 3-4, 5 summits; greedy, 40 runs: mostly floors 5-6, 3 summits. Most common run-enders: Snowfall and Thin Air Ridges on floors 5-6, the Langur on floor 5.
- Rendered and inspected Home, round intro, Round cleared, Camp draft, Trader, play with talismans and Stones, Talismans list and Expedition summary (`tests/render_expedition.gd`). Drawing cost unchanged: dragging about 0.08 ms per frame on this machine.

Not done: no APK rebuild and no phone testing; no human playtest of the balance.

## 0.2.1-dev Android smoothness (2026-10-25)

Version code 4, version `0.2.1-dev`. Verified in the same Linux container with the official Godot 4.7.2 Linux editor.

Drawing cost, measured with `tests/perf_probe.gd` (Mesa llvmpipe under Xvfb, 450x800). This is GDScript CPU time spent building each frame's draw commands on this machine, not phone frame time:

| Situation | 0.2.0-dev | 0.2.1-dev |
| --- | --- | --- |
| Idle | 0 ms, no repaints | 0 ms, no repaints |
| Dragging a shard | 1.84 ms per frame | 0.07 ms per frame |
| Line-clear animation | 2.02 ms per frame | 0.47 ms per frame |
| Scene ready (warm) | 27 ms | under 1 ms; sounds finish on a worker 30-50 ms later |

- `tools/check_android_policy.py` passed (no permissions, 60 FPS cap and low-processor mode unchanged).
- **1,156 rules assertions** and **91 scene checks** passed with no script errors or warnings. New scene checks: still screens repaint nothing and return to low-processor mode; dragging lifts low-processor mode; moving within a cell repaints nothing; a new cell repaints only the preview and hint; the dragged shard paints once; a move repaints the board at most twice; a dropped shard flies back to its slot; refills paint once per slot; the result stays hidden and unpainted during the clear and fades in once; tall and wide layouts.
- Rendered every screen at 450x800 (9:16), 432x960 (20:9) and 600x800 (3:4) and inspected them: no black bars, no clipped controls, continuous home scenery on wide screens.

Not done: the APK was **not rebuilt** and nothing ran on a phone. Before calling this verified on Android, rebuild with `tools/Build-Android.ps1`, then on a budget and a high-refresh phone capture the Godot profiler and a Perfetto trace while dragging and clearing lines, check the launch screen colour, and compare battery drain idle on the board.

## 0.2.0-dev interaction shell (2026-10-25)

Added Home, How to Play, Pause, Settings, Result and confirmation screens; the Back hierarchy; drag-to-place alongside tap placement; settings and lifetime statistics in separate checksummed saves; animations, synthesized sound effects, Reduced Motion and a 30 FPS battery saver. Touch targets are 96 reference pixels (48 dp). Version code 3, version `0.2.0-dev`.

Verified in a Linux cloud container with the official Godot 4.7.2 Linux editor (`4.7.2.stable.official.ed1daf0bf`):

- `tools/check_android_policy.py` passed: Android-only, ARM64, portrait, GL Compatibility, 60 FPS cap, low-processor mode, **no permissions**.
- Project import passed. **1,156 rules assertions passed**, including preview-equals-commit on every move of 1,000 seeded rounds, statistics, loading saves written before statistics existed, profile/settings validation and the checksummed store.
- **69 scene checks passed** through the real scene: tutorial on first start, dialogs blocking input, tap and drag placement, drag cancellation (off-board, app pause, late release), held board preview, Back at every level, Continue, New Trail confirmation, settings persistence, result recorded once across reloads, relaunch restoring trail/settings/profile, 48 dp targets on every screen, and bounded style/effect pools. No script errors or leak warnings.
- Rendered every screen with Mesa llvmpipe through Xvfb (`tests/render_preview.gd`) and inspected the captures; the style cache stayed stable across 20 unchanged redraws.

Not done in this session: the Android APK was **not rebuilt** (no Android SDK/templates in the container), and nothing was tested on a phone. Rebuild with `tools/Build-Android.ps1` and check drag feel, sound, safe areas, Back and lifecycle on hardware before calling Phase 1 complete.

## Android-only scope and implementation plan

The shipping project targets **Android only**. The Windows export and unused Unity/C# prototype, .NET projects, obsolete installer scripts and old CI job have been removed from the repository. A local legacy backup is retained outside the workspace. The portable installer selects only Android export templates; earlier installed tools/artifacts remain outside Git. Windows editor previews continue to support Android development.

The complete new [Android build plan](../ANDROID_GAME_BUILD_PLAN.md) specifies the implementation order, developer instructions, full-game milestones, Android performance goals, device checks and release steps. Most full-game content remains planned; the current implementation is a single Trail-round starter.

## Working Godot development path

- Godot 4.7.2 official Windows development editor and matching Android export templates installed. Editor CLI reports `4.7.2.stable.official.ed1daf0bf`. Official release SHA-256 hashes verified before extraction; locked in `tools/godot-release-lock.json`.
- OpenJDK 17.0.18+8, Android platform-tools 37.0.1, SDK command-line tools 16.0, API 36 and build-tools 36.0.0 installed independently of the game editor. SDK licences accepted. The minimal five-component bootstrap is pinned in `tools/android-release-lock.json`; prebuilt APK export does not require an NDK or CMake installation.
- Native Godot project import passed. **1,133 rules assertions passed**, including 1,000 seeded first-fit rounds (996 wins). This is only a Floor 1 Trail smoke result, not full expedition balance.
- **12 scene interaction/lifecycle/save/cache checks passed**, including repeated pause/focus saves, corrupt-primary repair, Back selection cancellation and reused style resources. Latest test logs contain no script errors.
- Real desktop rendering passed on the NVIDIA GTX 1650 via OpenGL compatibility. Inspected `Builds/SummitShards-preview.png`; no clipped board, tray, labels or buttons at the 450x800 capture size.
- Rendered 20 repeated board redraws with a stable cache of **10 style resources**; no new styles were created for the unchanged scene. This establishes resource reuse, not a measured phone CPU/battery improvement.
- Configured a 60 FPS cap, Android frame pacing, low-processor mode, normal idle screen timeout and conditional pointer redraws. No claim of sustained 60 FPS on hardware has been made.
- Android debug APK export passed. ZIP integrity, required game scripts, both ARM architectures, portrait orientation, minimum API 24, target API 36 and zero requested Android permissions verified. Android apksigner verifies v2 and v3 signatures. Tests are excluded from the APK.
- Working shortcuts and PowerShell commands cover editor launch, gameplay, VS Code, tool checks, native tests and rebuilds. Godot Tools VS Code extension 2.7.1 installed; Godot Tools is the repository's only recommended editor extension.
- Build outputs live on D: through the `C:\game\Builds` junction. Godot editor data is portable under its installation directory. No system security/approval settings were disabled.
- Original supplied MD/PDF preserved under `docs`. Repository workflow uses `main` for stable source and `develop` for integration, with short-lived feature/fix/release/hotfix branches when needed. Local tests and APK checks are separate from remote CI evidence.

## Android artifact

`C:\game\Builds\Android\SummitShards-debug.apk`

The neighboring `SummitShards-debug.json` contains the exact size, SHA-256, identity, static 16 KB ELF/ZIP-layout checks and manifest facts for the latest successful build. Package `com.summitstudio.summitshards`, version code 2, version `0.1.1-dev`. The debug key is local development signing, not an upload identity. Current signature validation runs as part of `Build-Android.ps1`; `Logs/android-signature.txt` is the earlier setup's detailed certificate report.

`adb devices -l` reports no connected phone. Physical-device installation, touch, lifecycle, Android safe-area behavior, frame rate, memory and battery use have not been measured. No Play Store AAB or release key has been generated.

## Evidence

- `Logs/godot-import.log`
- `Logs/godot-rules.log` and `Logs/godot-scene.log`
- `Logs/godot-preview.log` and `Builds/SummitShards-preview.png`
- `Logs/godot-android-export.log` and `Logs/godot-android-export-errors.log`
- `Builds/Android/SummitShards-debug.json` and `.manifest.txt`
- `Logs/android-signature.txt`
- `tools/godot-release-lock.json` and `tools/android-release-lock.json`

Logs, credentials, generated engine state and builds are ignored by Git. Source setup is complete for the active Godot starter. The rest of the game design is future implementation work.
