param([string]$ToolchainRoot = 'D:\SummitShardsToolchain')
$ErrorActionPreference = 'Stop'
$ToolchainRoot = [IO.Path]::GetFullPath($ToolchainRoot)
$downloads = "$ToolchainRoot\downloads"
New-Item -ItemType Directory -Force -Path $downloads, "$ToolchainRoot\temp" | Out-Null
function Download([string]$Url, [string]$Path) {
    if (!(Test-Path -LiteralPath $Path)) {
        & curl.exe --fail --location --retry 3 --output $Path $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    }
}
$lock = Get-Content -LiteralPath "$PSScriptRoot\godot-release-lock.json" -Raw | ConvertFrom-Json
$editor = "$ToolchainRoot\Godot\4.7.2"
$templates = "$ToolchainRoot\Godot\templates\4.7.2.stable"
if (!(Test-Path "$editor\Godot_v4.7.2-stable_win64.exe") -or !(Test-Path "$templates\android_release.apk") -or !(Test-Path "$templates\android_source.zip")) {
    foreach ($asset in $lock.assets) {
        $name = if ($asset.name.EndsWith('.tpz')) { 'Godot-4.7.2-templates.tpz' } else { 'Godot-4.7.2.zip' }
        Download $asset.browser_download_url "$downloads\$name"
    }
    & python "$PSScriptRoot\install_godot.py" $ToolchainRoot
    if ($LASTEXITCODE -ne 0) { throw 'Godot installation failed.' }
}
# Godot portable mode keeps editor settings, templates and debug keys off C:.
New-Item -ItemType File -Force -Path "$editor\_sc_" | Out-Null
$link = "$editor\editor_data\export_templates\4.7.2.stable"
New-Item -ItemType Directory -Force -Path (Split-Path $link) | Out-Null
if (!(Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $templates | Out-Null }

# Pinned SDK/JDK ZIPs install independently of the game editor.
if (!(Test-Path "$ToolchainRoot\Android\SDK\build-tools\36.0.0\aapt.exe") -or !(Test-Path "$ToolchainRoot\Android\JDK\bin\java.exe") -or !(Test-Path "$ToolchainRoot\Android\SDK\platform-tools\adb.exe")) {
    $android = Get-Content -LiteralPath "$PSScriptRoot\android-release-lock.json" -Raw | ConvertFrom-Json
    foreach ($component in $android.components) { Download $component.url "$downloads\$($component.id).zip" }
    & python "$PSScriptRoot\install_android_archives.py" $ToolchainRoot
    if ($LASTEXITCODE -ne 0) { throw 'Standalone Android SDK installation failed.' }
}
@{toolchainRoot = $ToolchainRoot} | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot\local.settings.json" -Encoding UTF8
. "$PSScriptRoot\Enter-Dev.ps1"
$settings = "$editor\editor_data\editor_settings-4.7.tres"
$javaPath = $env:JAVA_HOME.Replace('\', '/')
$sdkPath = $env:ANDROID_HOME.Replace('\', '/')
if (Test-Path -LiteralPath $settings) {
    $text = Get-Content -LiteralPath $settings -Raw
    foreach ($item in @(@('java_sdk_path', $javaPath), @('android_sdk_path', $sdkPath))) {
        $pattern = '(?m)^export/android/' + $item[0] + ' = .*'
        $line = 'export/android/' + $item[0] + ' = "' + $item[1] + '"'
        if ($text -match $pattern) { $text = [regex]::Replace($text, $pattern, $line) } else { $text += "`n$line`n" }
    }
} else {
    $text = "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`nexport/android/java_sdk_path = `"$javaPath`"`nexport/android/android_sdk_path = `"$sdkPath`"`n"
}
[IO.File]::WriteAllText($settings, $text, (New-Object Text.UTF8Encoding($false)))
$cache = "$ToolchainRoot\project-cache\Builds"
New-Item -ItemType Directory -Force -Path $cache | Out-Null
if (!(Test-Path "$ProjectRoot\Builds")) { New-Item -ItemType Junction -Path "$ProjectRoot\Builds" -Target $cache | Out-Null }
Write-Output 'Godot and the standalone Android SDK/JDK are installed. Run tools\Doctor.ps1, tools\Test-Game.ps1 and tools\Build-Android.ps1.'
