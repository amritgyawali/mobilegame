# Summit Shards: Android-only build plan and developer instructions

Updated: **2026-10-25**, Asia/Katmandu. Workspace: `C:\game`.

This is the implementation plan for the Android game. Follow the phases in order, complete their acceptance checks, and update the progress checklist as work is verified. The original game design remains in `docs/GAME_DESIGN.md` and `.pdf`; this plan applies the user's newer **Android-only** scope to that design.

## 1. Product and platform decisions

- Build an installed **Android mobile game**, using **Godot 4.7.2 and GDScript**.
- Ship Android APKs for development/testing and a signed Android App Bundle for Google Play release.
- Build a portrait, touch-first, offline-capable puzzle roguelite with short sessions and reliable interruption recovery.
- Support ARM64. Keep ARMv7 while it remains compatible with the selected engine and passes testing on the intended budget phones.
- Current baseline: minimum Android API 24, target API 36, OpenGL ES compatibility renderer. Recheck the current Play requirements at release time instead of treating these values as permanent policy.
- The Windows PC is a development workstation. Editor previews and command-line tests on it do not create a Windows product target.
- Do not add web/PWA, iOS, macOS, Windows, Steam, Chromebook-specific, console or Play Games on PC deliverables to this project. Android tablet layout may adapt the same Android app later; phone usability comes first.
- Keep one shipping implementation in `SummitShards`. The unused C#/Unity prototype and tooling have been removed from the repository; do not introduce a competing implementation to maintain.

The original design includes PC/Steam ideas and Unity-specific examples. They are reference material, not instructions to expand this project's platform scope. Its service, marketing and monetization proposals are future product decisions; writing this plan does not connect or publish those services.

## 2. Starting point: implemented versus remaining

Already implemented and checked:

- [x] Android-only export preset and an automated check that rejects other export platforms.
- [x] Godot editor, matching Android templates, Java 17, Android SDK, adb and VS Code tools.
- [x] One playable Trail round: 8x8 board, 19 shapes, five elements, three-piece tray, eight-tray budget, one reroll and 300-point target.
- [x] Seeded generation, occupancy relief, bounded mercy retries, simultaneous row/column clearing and no default gravity.
- [x] Pure-line, streak and perfect-clear scoring, including the design's 3,638-point worked example.
- [x] Versioned local round save, checksum, previous-move backup and corruption recovery.
- [x] Portrait layout, safe-area calculation, color-plus-symbol tiles and tap-to-place input.
- [x] Cached drawing styles, conditional hover redraw, 60 FPS cap, low-processor mode and normal Android screen timeout.
- [x] Pause/focus save coalescing, backup repair, and Back cancelling a selected piece before saved exit from the current single-screen prototype.
- [x] Native automated rules and scene checks; APK export and signature/archive/manifest checks.
- [x] Expedition (0.3.0-dev): 8 floors x Trail/Ridge/Guardian with the design's targets; Camp with free draft or +3 Coins, Trader, reroll, sell and reorder; Coins, unused-tray rewards and interest; 36 of the 48 launch talismans; Stone hazards; 5 weathers and 7 Guardians (simplified Summit Warden); Firebird; run saves and profile stats; Quick Trail kept. Bot balance: floors 3-4 (weak) and 5-6 (greedy), ~8% summits. Not yet: runes, Forge and bonus tiles, Frozen/Ember/Fog hazards, the other 3 weathers and 5 Guardians, 12 talismans, climbers, Altitudes, XP and unlocks.
- [x] Smoothness pass (0.2.1-dev): layered drawing so motion moves layers instead of repainting; low-processor mode lifted only while animating or dragging; sound synthesis off the main thread; font cache warm-up; expand aspect for tall/wide screens; themed launch screen; cached layout. Desktop drawing-cost measurements are in `docs/SETUP_STATUS.md`; phone traces are still pending.
- [x] Phase 1 shell (0.2.0-dev): Home, How to Play, Pause, Settings, Result and confirmation dialogs; Back hierarchy; drag-to-place with tap placement retained; separate settings and profile saves; abandon confirmation; animations, sound effects and Reduced Motion. Device checks for this phase are still pending.

Still to build: runes, the Forge and bonus tiles; Frozen, Ember and Fog hazards; the remaining weathers, Guardians and 12 talismans; climbers, Altitudes, Expedition XP and unlocks; an interactive tutorial; final art and audio; localization; and the release workflow. Systems not listed as implemented above do not exist yet.

Real-device performance, battery, touch feel, lifecycle behavior and accessibility remain unverified until measured on Android hardware.

## 3. Daily development instructions

1. Open `Open-Godot.cmd`; the project is `SummitShards/project.godot`. Open `Open-VSCode.cmd` for editing. Use F5 for a local editor preview.
2. Read this plan, `docs/ARCHITECTURE.md` and the relevant section of `docs/GAME_DESIGN.md` before changing a mechanic.
3. Implement one small, playable slice. Keep rules separate from nodes, rendering, input and storage.
4. Run the relevant rules/scene checks. Run all game checks before handing off a milestone.
5. Build an APK after changes to export settings, runtime code, plugins or imported assets. Verify the resulting artifact rather than reusing a previous APK.
6. Test the slice on a connected phone; record device, Android version, build SHA-256 and result. If a phone is unavailable, explicitly leave the device check pending.
7. Update `docs/SETUP_STATUS.md` with actual results and mark the phase complete only after its acceptance checks pass.
8. Use Git for focused, reviewable source changes. Keep generated caches, builds and credentials out of source control.

From `C:\game`:

```powershell
# Check tools, Android-only scope, rules and actual scene adapter.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Doctor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Game.ps1

# Build a fresh debug APK and verify its signature and manifest.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Android.ps1

# Device installation: authorize USB debugging on the phone first.
. .\tools\Enter-Dev.ps1
adb devices -l
adb install -r .\Builds\Android\SummitShards-debug.apk
```

With several devices connected, specify `adb -s <serial>` for each device command. Do not uninstall or clear game data as a routine test step; that destroys the save being tested.

## 4. Architecture to grow toward

Retain the current files until a phase requires a split. When splitting, move the existing implementation and update imports/tests together; do not leave two live rule engines.

```text
SummitShards/
  project.godot
  export_presets.cfg                 # Android presets only
  scripts/
    round_model.gd                   # Current pure round model
    main.gd                          # Current prototype adapter
    core/                            # Later: board, scoring, RNG, events
    run/                             # Later: expedition, Camp, economy
    content/                         # Later: typed content loading/validation
    persistence/                     # Later: save envelopes and migrations
    ui/                              # Later: screens, board, tray, dialogs
    platform/android/                # Only Android-specific integrations
  scenes/                            # Reusable screens and UI scenes
  data/                              # Versioned, validated content definitions
  assets/                            # Art, fonts, audio and required notices
  tests/                             # Excluded from exported game
```

Rules for every feature:

- Pure models accept explicit commands and return results/events. Models must not call `Time`, global random functions, nodes, file APIs, ads or billing.
- Only the UI adapter interprets gestures. Only persistence code reads/writes saves. Android plugins remain behind small interfaces.
- Use stable content IDs and an explicit content version. Saves store IDs and state, not scene paths or object references.
- Use separate deterministic RNG streams for pieces, drafts, Trader, weather, Guardians and tile effects. Introducing streams changes replay compatibility: version it and test known fixtures.
- GDScript's current xorshift32 saves are not interchangeable with the historical C# PCG32 model. Do not use the C# bot/server to validate Godot replays without an explicitly tested compatible implementation.
- Keep game state independent of animation. Award a move once, then display its result; interrupted animations must not duplicate scores, rewards or purchases.
- Use bounded work per command: board operations inspect at most 64 cells; chain effects keep a visited set/bitmask and a documented resolution limit.
- Preserve existing valid saves through explicit migrations. Add a rollback fixture before changing the schema.
- All shipping presets must remain Android. `tools/check_android_policy.py` runs before tests/builds and in the prepared CI workflow.

## 5. Phase 1: complete the Android interaction shell

Build this before adding large amounts of content.

1. Add screen routing for Home, Continue/New Expedition, Round, Pause, Settings and Run Result. Keep the board the main visual focus.
2. Replace abrupt New Round behavior with an abandon confirmation once an expedition is active. Keep one-tap continuation for a saved run.
3. Keep tap-select/tap-place as a complete input method. Add optional drag-to-place with a raised ghost above the finger, clear valid/invalid feedback, cancellation and release-to-commit. A gesture must commit at most one placement.
4. Track one active touch ID. Ignore secondary fingers during a gesture and cancel a drag on pause, focus loss, navigation or resize.
5. Make Back cancel a drag/selection first, close the top dialog next, return through navigation next, then show an exit choice at the root. Save before leaving gameplay. The current starter only implements selection cancellation and saved exit; the full route stack is future work.
6. Fit board, tray and bottom controls within the Android safe area for short screens, tall screens, camera cutouts, gesture navigation and three-button navigation. Test the actual drawable region rather than assuming 720x1280 is a phone's physical size.
7. Aim for at least 48 dp primary controls with adequate separation. Do not shrink controls below usable sizes just to fit decorative content. Measure dp using the device density; reference pixels are not physical dp.
8. Add settings for music, effects, haptics, reduced motion, text size and performance preference. Persist settings separately from the run so starting a new run does not reset them.
9. Provide plain, readable scoring explanations and color-independent symbols. Verify accessibility behavior on Android; the current custom-drawn tiles do not supply TalkBack semantics by themselves. Add a tested semantic layer for controls and the board before claiming screen-reader support.

Acceptance: complete a round with taps alone; drag cancellation never consumes a piece; Back follows the route hierarchy; dialogs cannot place pieces beneath them; resume after Home/lock/call without losing a completed move; controls remain reachable on the smallest supported test phone.

## 6. Phase 2: make the rule engine ready for the full design

1. Extract board, shapes, generation and scoring into small pure modules while preserving the current test fixtures.
2. Introduce a tile-state schema for element, upgrade, hazard, durability and temporary modifiers. Do not overload the current element integer with undocumented magic values.
3. Formalize a command/event sequence: validate placement; place cells; detect all lines; resolve tile effects; calculate Base; apply AddBase, AddMult and MultiplyMult phases; apply final Perfect Clear; award score/coins; resolve round end; notify presentation.
4. Specify exactly which destroyed cells count for Base, how intersections count once, whether a hazard survives its first clear, and when chained effects can trigger other effects.
5. Keep default no-gravity behavior. Gravity is a specific Guardian modifier, with deterministic cascade ordering and dedicated tests.
6. Represent talisman effects using data parameters plus a bounded registry of effect handlers. Never evaluate content strings as code.
7. Define score bounds and exact rounding for stacked fractional multipliers before implementing endless scaling. Prefer fixed-point/rational arithmetic for modifiers where practical; avoid JSON number precision loss and 64-bit overflow.
8. Resolve the design's talisman-order ambiguity explicitly. Current behavior is global additive phases before multiplicative phases, with slot order inside each phase. Keep the UI explanation and tests consistent with that decision.

Acceptance: all original scoring fixtures still pass; crossing lines never double-count cells; hazard/chain effects terminate deterministically; previews equal the committed result for an unchanged board; save/replay continues identically after later trays.

## 7. Phase 3: build the expedition and floor progression

1. Add `RunState`: run ID/seed, content version, climber, Altitude, floor, round type, current phase, currencies, equipped talismans, rune inventory, modified piece bag and RNG streams.
2. Add a state machine for Round Intro -> Playing -> Round Result -> Camp -> Next Round, and terminal Run Won/Run Lost states.
3. Load floor targets from data: 300, 525, 920, 1600, 2800, 4900, 8600 and 15000. Store the design's rounded Ridge targets explicitly rather than assuming one rounding formula produces every listed value.
4. Schedule Trail, Ridge and Guardian for each of eight floors. Baseline budgets are eight trays for Trail/Ridge and nine for Guardian; modifiers may change them.
5. Decide and document round-to-round board reset/carry rules before implementation; the source design does not specify this sufficiently. Proposed default: start each encounter with a fresh board plus encounter hazards, carrying the build and currencies across encounters. Keep this as an explicit decision rather than silently changing it later.
6. Award rewards once per won round and apply them through a transaction/state transition. A reload at the result screen cannot grant the same reward again.
7. Save at every completed command and durable phase transition, including before and after Camp rewards and round initialization.
8. Add run summaries with floor reached, outcome, best placement, build and XP earned. Do not show unwritten data as real results.

Acceptance: complete all 24 encounters in a test expedition; lose by target/budget and by blockage correctly; resume from every transition without skipped rounds, duplicate coins or changed future draws.

## 8. Phase 4: Camp, talismans and the in-run economy

1. Implement free choose-one-of-three talisman drafts, skip for coins and the higher-rarity Guardian draft rules from the design.
2. Implement equipped slots, descriptions, trigger explanations, selling and supported reordering. Show the current effect and why it triggered.
3. Add the Trader: three talismans, two runes and one Forge service. Charge the initial two-coin reroll and its per-Camp increasing cost atomically.
4. Add coin rewards, interest and spending rules as validated data. Keep permanent Shards separate from run Coins.
5. Start with approximately ten well-tested talismans spanning element, combo and economy play. Ember Heart and Twin Rope are currently score examples only; wire their actual equipped effects before exposing them as rewards.
6. Expand to roughly 30 talismans after the first complete playable floor, then to the design's 48 launch talismans after automated and human balance checks.
7. Implement Forge upgrade/remove/duplicate/attune against the persistent run piece bag. Validate the bag cannot become empty or generate invalid shapes.
8. Test insufficient funds, rapid repeated taps, full slots, empty inventories, reload during a purchase and deterministic offer generation. Currency can never become negative.

Acceptance: win a round, draft, buy/sell, modify the bag and continue; all purchases persist exactly once; taking a draft does not unexpectedly change the independent piece RNG stream.

## 9. Phase 5: runes, tiles, weather, Guardians and climbers

Build these in dependency order rather than adding all content at once.

1. Add two-slot consumable rune inventory. Implement targeting, confirm/cancel behavior and exactly-once consumption before complex effects. Then cover Dye, Shattering, Hands, Time, Wealth, Forging, Thaw, Seer, Echo, Shrinking, Stillness and Kinship rules.
2. Add special tiles: Gold, Glass, Bomb, Crystal, Iron and Seed. Persist per-shape upgrades and growing values. Test Bomb intersections, Crystal pure-line matching and Glass break probability with fixed seeds.
3. Add Stone, Frozen, Ember and Fog hazards with explicit durability/visibility/spread rules. Avoid selecting a random empty cell by an unbounded retry loop.
4. Implement the eight Ridge weather definitions and show a concise rule before the round. Test their interactions with runes and scoring modifiers.
5. Implement Guardians from simplest to most complex: Stone Yak, Moon Bear and Mist Weaver first; then the remaining modifier types, gravity, shuffled/disabled talismans and the Summit Warden's three phases.
6. Reach the design's 12 Guardians only after each has individual fixtures and at least one valid complete-run fixture. The Warden must reuse earlier encountered rules deterministically.
7. Add the six base climbers with their starting kits, exceptions and unlocks. Add seasonal climbers only with their content milestone; do not ship empty selection cards.
8. Keep encounter effects parameterized and composable. Add pairwise interaction tests for weather + Guardian + climber + rune + talisman combinations, then seeded full-run stress tests.

Acceptance: each displayed rule matches its actual effect; every supported encounter can be saved/resumed; no hazard chain hangs the game; all target content is reachable and has an explanation in the Codex.

## 10. Phase 6: progression, modes and onboarding

1. Add Expedition XP, profile unlocks, the Codex, achievements and Altitudes 0-10 as independent profile data. Validate migrations from older profiles.
2. Build a short interactive tutorial: first placement, first clear, pure-line/score explanation, reroll and the first Camp choice. Teach actions through play, with skip/replay controls.
3. Add Zen and local custom-seed modes using the same tested rules. Mark unranked practice clearly. Unlock Endless only after the required completed run.
4. Add local daily/weekly challenges if desired before any backend work. Do not label a locally generated score as server-verified or display fabricated ranks.
5. Localize strings from the start using stable translation keys. Complete English, Nepali and Hindi first, then the source design's Spanish (Latin America), Portuguese (Brazil), Indonesian, Turkish, German, French, Japanese and Korean as reviewed content becomes available.
6. Test long translations, Devanagari/CJK font coverage, number formatting and text scaling. Include only required font weights/glyph ranges after visual verification.
7. Implement reset-data and clear explanations of what will be lost. Keep the run/profile/settings stores separate.

Acceptance: a fresh install can learn and complete a floor without external help; returning players continue correctly; unlocks persist; long localized text does not hide actions or clip important numbers.

## 11. Phase 7: Android art, audio and feedback

1. Replace temporary visuals with a coherent Himalayan art direction. Keep the board readable at actual phone size and do not make symbols depend on color alone.
2. Build texture atlases for frequently co-visible tiles and icons. Use appropriate mobile imports, limit transparent overdraw and avoid full-screen shader effects for ordinary gameplay.
3. Add short placement/clear/score animations from a bounded object pool. Cap simultaneous particles and score popups. Reduced Motion must preserve information while removing unnecessary movement.
4. Cache finite style resources. Animate node transforms/modulate instead of generating a new cached style for every intermediate color/alpha value.
5. Use compressed streaming music and small, preloaded effects where appropriate. Cap simultaneous audio voices and pause/duck sound correctly on Android interruptions.
6. Add optional Android haptics after testing the actual API/permission path. Keep it user-controlled and avoid a long vibration for every placement.
7. Complete adaptive launcher icons, splash treatment, Guardian illustrations and release artwork. Preserve required engine and third-party notices in exported artifacts.

Acceptance: placement is immediately understandable, multi-line clears feel rewarding, overlapping effects remain legible, and disabled audio/haptics/reduced-motion settings behave consistently after restart.

## 12. Phase 8: performance and battery engineering

These are **acceptance targets**, not measurements already achieved:

- Active play: aim for stable 60 FPS on a representative budget Android phone with 2 GB RAM. Use 16.7 ms as the 60 FPS frame budget; investigate P95/P99 frame-time spikes instead of reporting only average FPS.
- Low-power/menu mode: at most 30 FPS when animated; static views should stop requesting redundant redraws. Keep input feedback responsive. A player-selectable 30 FPS mode is useful on devices that cannot sustain 60.
- Cold launch to an interactive board: under four seconds on the baseline phone, measured separately for cold and warm starts.
- Peak total PSS: target below 350 MB during representative play; no continuing growth through a 30-minute play/restart cycle. Record the actual device and workload.
- Base release AAB: target under 80 MB. Also record Play's per-device download/install estimates; debug universal APK size is not a substitute for those metrics.
- Input-to-visible feedback: aim for under 100 ms at the 95th percentile on the test device.
- Offline: the complete base expedition, tutorial, settings and save/resume work in airplane mode. Future optional online features fail gracefully.

Optimization order:

1. Capture baseline traces on an actual phone before optimizing new systems. Record build hash, device model, Android/API, refresh rate, memory, battery level, thermal state and test sequence.
2. Use Godot's profiler for script/render counts, Android Perfetto/system tracing for scheduling/frame pacing, and `adb shell dumpsys meminfo <package>` for memory. `gfxinfo` alone may miss engine surface rendering, so do not treat it as a complete GPU measurement.
3. Eliminate unneeded work first: no full-board redraw per idle frame, no repeated identical save writes, no network polling in offline play, no continuous background gameplay loop.
4. Reuse tile visuals, style resources, effects, popups and audio players. Track bounded pool/cache sizes and include a long-session memory check.
5. Keep deterministic model work small and synchronous for ordinary moves. Put heavy balance searches, image preparation or optional network parsing outside the input path, with snapshots and bounded/cancellable work.
6. Compress and downscale assets based on their visible size. Add atlases and compression only after checking visual quality on phones. Do not load all floors' high-resolution art at startup.
7. Keep GL Compatibility as the default for this flat 2D board. Do not add Vulkan-only rendering requirements without device evidence and an explicit supported-device decision.
8. Retain Android frame pacing and a 60 FPS upper cap. Verify behavior at 60/90/120 Hz and under thermal throttling. If later animation needs continuous redraw, reevaluate low-processor mode with traces rather than assuming its current static-board benefit remains unchanged.
9. Let the screen time out during idle thinking in the current non-timed mode. For any future timed challenge, decide wake behavior explicitly and release it on pause.
10. Run a 30-minute thermal/battery soak with the same brightness/workload when comparing builds. Report actual CPU/GPU/frame/battery differences; do not claim a percentage improvement from code inspection alone.

The GDD's zero-allocation aspiration should become measured hot-path work: avoid repeated per-frame node/resource allocation and unbounded growth. GDScript dictionaries, snapshots and JSON still allocate; do not claim that an entire placement/save is allocation-free.

Acceptance: attach device measurements against these budgets; fix the largest measured bottleneck; rerun the same scenario and retain before/after evidence. A PC screenshot or headless rule test cannot pass this phase.

## 13. Phase 9: automated tests and Android device qualification

Run quick checks after ordinary code changes; reserve large simulations and device soak tests for relevant changes/milestones.

1. Keep fast deterministic rule fixtures, save schema fixtures and scene interaction/lifecycle checks. Add tests for real failures and boundary rules rather than mirroring helper implementations.
2. Cover every new command's invalid-input behavior and ensure rejection is atomic. Compare preview/commit, repeated commands and save/restore continuation.
3. Run 1,000 seeded smoke rounds locally during ordinary rule work. After full expedition support exists, run at least 100,000 full seeded runs for significant balance/content changes, with per-floor loss causes, blocked rate, economy, pick rate and build outcomes. The current one-round first-fit bot cannot provide those conclusions.
4. Maintain a physical device set: one low-memory budget phone, one typical midrange phone and one modern/high-refresh phone. Include older supported Android and current target-API behavior. Use emulators for missing API/cutout/page-size cases, clearly labelled as emulator evidence.
5. Test fresh install, upgrade without data loss, app restart, process death while backgrounded, low storage, corrupted primary save, missing backup, repeated pause/resume and interrupted Camp transactions.
6. Test Home, lock/unlock, incoming call/audio interruption, notification shade, Back gesture/button, multi-touch and long idle. Resume without a duplicated placement, reward, purchase or active drag.
7. Test gesture and three-button navigation, display cutouts, short/tall screens, larger font/display scaling, low-power mode and 60/90/120 Hz screens.
8. Test airplane mode from first launch, optional service timeouts, no account state and denied optional permissions. Base play stays available.
9. Validate 16 KB page compatibility: native library ELF LOAD alignment, APK ZIP alignment and an actual 16 KB device/emulator run. Static alignment checks alone do not establish runtime compatibility.
10. Validate exported contents and signatures after every packaging/plugin change. Current default is zero Android permissions; add a permission only for an implemented Android feature with a documented purpose and a manifest regression check. Avoid broad photo/storage permissions for sharing images; use Android's sharing/provider path.

For a running debug app:

```powershell
. .\tools\Enter-Dev.ps1
adb shell dumpsys meminfo com.summitstudio.summitshards
adb shell getconf PAGE_SIZE
adb logcat -d -v threadtime > .\Logs\android-logcat.txt
```

Use a controlled test phone when collecting logs, and review logs before sharing them. Capture a Perfetto trace for a reproducible stutter; record start/end markers for the gesture that triggers it.

## 14. Phase 10: optional Android services

Core offline play comes first. Add only services actually selected for the product.

1. Define interfaces for achievements, score submission, cloud sync, rewarded ads and billing. The default offline implementation must not block game startup.
2. For online Daily Climb, version the rules/content and record a complete command replay. Select and validate an authoritative replay implementation compatible with GDScript before accepting competitive scores; the old C# model is not automatically compatible.
3. Add anonymous/account/cloud features only with clear conflict resolution and an account-free local path. Never overwrite a newer local run with an older remote save silently.
4. If rewarded ads are selected, reward only a confirmed, idempotent completion callback. Network failure, cancellation or app pause must not grant or charge twice.
5. If purchases are selected, validate purchases, restore entitlements and handle pending/cancelled transactions through the supported Android billing integration. Test through the platform's test track before real-money release.
6. Keep analytics events minimal and useful, with no secrets or unnecessary personal data. Update privacy/disclosure content for the actual installed SDK behavior.

Acceptance: disabling the network/services leaves the base game playable; rewards/purchases are idempotent; real service behavior is labelled separately from test/sandbox results.

## 15. Phase 11: Google Play release and updates

1. Finish the selected launch scope. Do not publish placeholder screens or list unimplemented modes as available.
2. Choose the permanent package/studio identity before the first public release. Set a release version and a strictly increasing version code.
3. Configure an Android release preset using the installed Godot Gradle source template. The existing debug preset remains available for testing; both presets target Android.
4. Install the exact extra SDK/Gradle dependencies required by the pinned template. Keep their versions reproducible. See `docs/ANDROID_RELEASE.md` for the prepared instructions.
5. Create/use the owner's release upload key outside the repository, back it up securely, and export with debug disabled. A debug APK/key is not a store release identity.
6. Validate the AAB with bundletool, verify signing, inspect manifest/ABIs/permissions, check 16 KB alignment, and test generated device APKs. Check current Play target-API, testing and account requirements directly when submitting.
7. Test the signed build through the appropriate Google Play testing track, including update installation over the prior version and persistence migrations. Complete store artwork, content rating, privacy and data-safety declarations based on actual features.
8. Prepare crash monitoring, a staged rollout and a tested hotfix/migration path before expanding distribution. Submit/publish only as the owner's explicit release action, after the build and review materials are ready.
9. For every update, repeat relevant regression, save migration, dependency/permission and device checks. Preserve a known-good artifact and its exact source/content version.

Acceptance: signed Android release artifact, store-side validation, physical-device results, owner-reviewed release metadata and an update path. Creating this plan or a debug APK does not pass this release phase.

## 16. Milestone gates and next implementation slice

- **Foundation:** current Android-only starter, reproducible APK, rules/scene checks and resource-caching changes verified. Phone performance remains pending.
- **First complete floor:** touch shell, one Trail/Ridge/Guardian sequence, Camp, a small useful talisman set and reliable full-run saves.
- **Playable expedition:** all eight floors, complete state transitions, core content interactions, tutorial and run summaries.
- **Content complete:** selected launch talismans, Guardians, climbers, runes, progression, modes, reviewed art/audio and languages.
- **Android beta:** performance budgets and lifecycle/device checks measured; release signing/AAB and upgrade path verified.
- **Release:** owner-approved store submission and tested rollout/update process.

**Phase 1 code is in place (0.2.0-dev); finish it on hardware:** check drag feel, safe areas, Back and lifecycle behavior on real phones, then add a text-size setting and a tested TalkBack layer. Do not start with ads, a backend, additional platforms or all 48 talismans. First make one complete floor feel good on a real budget Android phone.

## 17. Official implementation references

- [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot Android Gradle/AAB builds](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html)
- [Godot project settings: frame cap, low-processor mode, Back and screen timeout](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)
- [Godot guidance on rendering only when needed](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html#performance)
- [Android system tracing](https://developer.android.com/games/optimize)
- [Android frame pacing](https://developer.android.com/games/sdk/frame-pacing)
- [Android 16 KB page-size validation](https://developer.android.com/guide/practices/page-sizes)
- [Android app signing](https://developer.android.com/studio/publish/app-signing)

These links explain implementation requirements and tooling. Numeric performance budgets above are project goals to measure, not claimed results or guarantees.
