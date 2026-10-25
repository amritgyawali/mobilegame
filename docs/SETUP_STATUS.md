# Setup verification

Updated: 2026-10-25 (Asia/Katmandu). Sources: `C:\game`. Active project: `C:\game\SummitShards`. Tools: `D:\SummitShardsToolchain`.

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
