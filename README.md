# Summit Shards Android development

**The working starter uses Godot 4.7.2 + GDScript.** Open `SummitShards/project.godot`, or double-click **Open-Godot.cmd**. Press **F6** with `main.tscn` open, or **F5** to play the project. **Play-Game.cmd** runs it directly; **Open-VSCode.cmd** opens the configured code workspace.

**Android is the only shipping platform.** APK/AAB builds are the product outputs. PC editor previews are development tools. The Windows export preset and desktop build script have been removed; web, iOS and desktop products are outside scope.

Read the full step-by-step [Android game build plan](ANDROID_GAME_BUILD_PLAN.md) for implementation phases, developer instructions, phone performance budgets, acceptance checks and release steps.

GDScript is the selected language for this 2D Android game: it integrates directly with Godot's scenes, touch input and Android exporter. The repository contains one Godot implementation and its Android development tools.

The active project imports, renders, passes its native checks and exports a verified Android APK. See [current verification](docs/SETUP_STATUS.md).

## Playable starter

Tap a tray piece, then tap the board cell for the **top-left of its bounding box**. Fill rows or columns to score. Reach 300 altitude within eight trays. Reroll unused pieces once per round; **NEW ROUND** starts a fresh seed.

Implemented: portrait 8x8 board, 19 shapes, three-piece tray, seeded weighted bag, simultaneous line clears, pure lines, streaks, perfect clears, score target, win/loss, hover/score preview with a mouse, and local save/backup recovery. Elements have both colors and symbols. This is one Trail round for development; the full expedition, Camp drafts, Guardians, weather, progression, art and audio are future game work.

Android tuning includes a 60 FPS upper cap, low-processor mode for the static board, normal screen timeout, reused drawing styles and redraws only when the hovered cell changes. Pause/focus callbacks avoid rewriting unchanged saves. Back cancels a selection before saved exit in the current single-screen starter. These are verified configuration/code improvements; battery life and sustained phone FPS still need device measurements.

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

- `SummitShards/scripts/round_model.gd`: pure round rules and versioned state, independent of scenes, clocks and filesystem.
- `SummitShards/scripts/main.gd`: drawing, touch/mouse input, safe-area layout and save adapter.
- `SummitShards/tests`: native Godot rule checks, scene interaction/save checks and viewport capture utility. Excluded from exported games.
- `SummitShards/export_presets.cfg`: Android-only export settings.
- `tools/check_android_policy.py`: platform and mobile-default checks, run before tests/builds.
- `tools`: pinned manifests, isolated environment, installers, checks and build commands.
- `docs`: original design, architecture, verification and release guidance.
- `CONTRIBUTING.md`: branch workflow and validation expectations.

## Release preparation

Package ID `com.summitstudio.summitshards`, version `0.1.1-dev` and the studio name are development placeholders. Choose your permanent identity before publishing. The debug key is not an upload key. No Play Store AAB, release signing key or store submission was created.

Godot's matching `android_source.zip` and Android release export template are installed for later Gradle/AAB configuration. See [Android release steps](docs/ANDROID_RELEASE.md). The installer now selects only Android export templates. Ads, IAP, analytics, cloud services and leaderboards are not connected. API 36 is this project's configured target, not a promise about a future Play policy deadline.

## Branch workflow

`main` holds stable source; `develop` integrates the next Android milestone. Create `feature/*` and `fix/*` branches for concrete changes, open pull requests into `develop`, then promote validated milestones to `main`. Release and hotfix branches are created when needed. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Official references

- [Godot Android export requirements and C# caveat](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Pinned Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
- [Godot Android Gradle build](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html)
- [Android app signing](https://developer.android.com/studio/publish/app-signing)

Godot engine and third-party notices are included in `SummitShards/assets` and in the game exports.
