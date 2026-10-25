. "$PSScriptRoot\Enter-Dev.ps1"
& python "$PSScriptRoot\check_android_policy.py"
if ($LASTEXITCODE -ne 0) { throw 'Android-only project policy failed.' }
$checks = [ordered]@{
    'Godot 4.7.2' = $GodotExe
    'Android debug template' = "$ToolchainRoot\Godot\4.7.2\editor_data\export_templates\4.7.2.stable\android_debug.apk"
    'JDK 17' = "$env:JAVA_HOME\bin\java.exe"
    'Android adb' = "$env:ANDROID_HOME\platform-tools\adb.exe"
    'Android API 36' = "$env:ANDROID_HOME\platforms\android-36\android.jar"
    'Android build-tools 36' = "$env:ANDROID_HOME\build-tools\36.0.0\aapt.exe"
    'APK signature tool' = "$env:ANDROID_HOME\build-tools\36.0.0\lib\apksigner.jar"
    'SDK manager' = "$env:ANDROID_HOME\cmdline-tools\16.0\bin\sdkmanager.bat"
    'Active project' = "$GodotProject\project.godot"
    'Playable scene' = "$GodotProject\main.tscn"
}
$missing = 0
foreach ($entry in $checks.GetEnumerator()) {
    $ok = Test-Path -LiteralPath $entry.Value
    if (!$ok) { $missing++ }
    Write-Output ('{0,-7} {1}: {2}' -f $(if ($ok) { 'OK' } else { 'MISSING' }), $entry.Key, $entry.Value)
}
if (Test-Path -LiteralPath $GodotExe) { & $GodotExe --version }
if (Test-Path -LiteralPath "$env:JAVA_HOME\bin\java.exe") {
    $process = Start-Process -FilePath "$env:JAVA_HOME\bin\java.exe" -ArgumentList '-version' -WindowStyle Hidden -Wait -PassThru -RedirectStandardError "$env:TEMP\summit-java-version.txt"
    Get-Content -LiteralPath "$env:TEMP\summit-java-version.txt"
    if ($process.ExitCode -ne 0) { $missing++ }
}
if (Test-Path -LiteralPath "$env:ANDROID_HOME\platform-tools\adb.exe") { & "$env:ANDROID_HOME\platform-tools\adb.exe" devices -l }
Write-Output "Missing checks: $missing. Android gameplay and performance still need a connected device."
if ($missing -gt 0) { exit 1 }
