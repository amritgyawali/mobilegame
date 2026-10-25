# Development workflow

This repository builds **Summit Shards for Android**, using Godot 4.7.2 and GDScript. Start with [README.md](README.md) and [ANDROID_GAME_BUILD_PLAN.md](ANDROID_GAME_BUILD_PLAN.md).

## Branches

- `main`: stable source; use this branch for release candidates after validation.
- `develop`: integration branch for the next Android milestone.
- `feature/<short-name>`: create from `develop` for a concrete feature; merge back through a pull request.
- `fix/<short-name>`: create from `develop` for ordinary fixes.
- `hotfix/<short-name>`: create from `main` for an urgent released-build fix; merge into both `main` and `develop`.
- `release/<version>`: create from `develop` when preparing an actual release candidate; merge into `main` and back into `develop` after acceptance.

Only `main` and `develop` are permanent. Create feature, fix, hotfix and release branches when that work starts, then delete them after merging. Keep the default branch as `main` and do day-to-day work on a feature branch.

```powershell
git switch develop
git pull --ff-only
git switch -c feature/android-interaction-shell
```

## Before opening or merging a pull request

1. Implement one focused change; preserve the pure model/UI/storage boundaries.
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Game.ps1`.
3. For runtime, packaging or asset changes, run `tools\Build-Android.ps1` and verify the newly generated APK.
4. Describe what changed and the actual checks performed. State the Android device/build tested, or explicitly leave handset testing pending.
5. Keep saves compatible, or include an explicit migration and its fixtures.
6. Update the plan/status when completing a milestone. Do not label planned features or unmeasured phone performance as delivered.

Open feature/fix pull requests into `develop`. Promote validated milestones from `develop` to `main`. The `Godot game rules` workflow checks Android-only exports, project import, pure rules and scene behavior on pull requests and pushes to the permanent branches.

The workflow uses read-only repository permissions. Branch protection is an independent GitHub repository setting; the branch layout and CI configuration do not themselves enable protection rules.

## Repository contents

Commit the Godot game, deterministic tests, Android tools, manifests, design documents and contributor documentation. Keep APKs, SDKs, caches, logs, local paths, keys and credentials outside Git. Preserve Godot `.uid` and asset import configuration files; they are source metadata.

Do not add another engine implementation, web/iOS/desktop export, a credential, or a new Android permission as incidental cleanup. Implement a concrete Android requirement and update the relevant checks when changing the platform contract.
