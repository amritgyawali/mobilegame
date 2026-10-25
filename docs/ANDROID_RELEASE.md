# Android release workflow

The local development APK build is verified. The following store-release workflow is prepared guidance; a signed Play Store AAB has not been built or uploaded.

Only Android presets are allowed. Follow the full [Android build plan](../ANDROID_GAME_BUILD_PLAN.md) for the development sequence and mobile quality gates. The pre-build platform check rejects desktop, iOS and web exports.

1. Open `Open-Godot.cmd`. Choose your permanent package ID, studio name and release version. Increase version code for each store upload.
2. Duplicate the Android export preset as a release preset. Enable **Gradle Build > Use Gradle Build** and select **Export AAB**. Install Godot's Android build template through **Project > Install Android Build Template**. The matching `android_source.zip` is already installed with Godot's export templates.
3. Use the dependency versions in the installed template's `config.gradle`. The pinned 4.7.2 source specifies Java 17, compile/target API 36, minimum API 24, build-tools 36.1.0 and NDK 29.0.14206865. The verified prebuilt APK export currently uses build-tools 36.0.0 and does not require compiling the engine. Install any extra Gradle dependencies using `sdkmanager` when enabling that path; older stable-documentation examples may list different versions.
4. Create and securely back up your own upload keystore outside the repository. Enter it in the release export's keystore settings. Use the same key/store password as required by Godot. Local `export_credentials.cfg`, keystores and environment files are ignored by Git. Keep passwords in your local credential workflow, not chat or source control.
5. Export with **Export With Debug** disabled. Godot's CLI can use `--export-release <preset> <output.aab>` after the preset and Gradle build are configured. A debug key is for development only.
6. Validate the bundle using Android's bundletool, verify release signing and merged permissions, then test on actual Android hardware. Check ARM64 ELF LOAD/RELRO layout, 16 KB ZIP alignment and runtime behavior on a 16 KB device/emulator. The debug APK verifier checks static layout/alignment, which does not replace that runtime test. Finish content, accessibility, lifecycle/resume, performance and offline checks before store submission.

The current starter requests no Android permissions. Adding plugins can alter the merged manifest, so recheck it after any such change. Store forms, artwork, privacy declarations and Play Console upload remain later release work.

Official documentation:

- [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot Android Gradle builds](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html)
- [Pinned engine Gradle versions](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle)
- [Android signing](https://developer.android.com/studio/publish/app-signing)
- [Android 16 KB validation](https://developer.android.com/guide/practices/page-sizes)
