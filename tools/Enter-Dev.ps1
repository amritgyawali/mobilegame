$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$settingsFile = Join-Path $PSScriptRoot 'local.settings.json'
if (Test-Path -LiteralPath $settingsFile) {
    $script:ToolchainRoot = (Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json).toolchainRoot
} else {
    $script:ToolchainRoot = 'D:\SummitShardsToolchain'
}
$env:GRADLE_USER_HOME = Join-Path $ToolchainRoot 'gradle'
$env:ANDROID_USER_HOME = Join-Path $ToolchainRoot 'android-user'
$script:GodotExe = Join-Path $ToolchainRoot 'Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$script:GodotProject = Join-Path $ProjectRoot 'SummitShards'
$env:SUMMIT_GODOT_EDITOR = $GodotExe.Replace('_console.exe', '.exe')
$env:ANDROID_HOME = Join-Path $ToolchainRoot 'Android\SDK'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_HOME = Join-Path $ToolchainRoot 'Android\JDK'
$env:TEMP = Join-Path $ToolchainRoot 'temp'
$env:TMP = $env:TEMP
$env:PATH = "$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\16.0\bin;$env:JAVA_HOME\bin;$env:PATH"
foreach ($directory in @($env:GRADLE_USER_HOME, $env:ANDROID_USER_HOME, $env:TEMP)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
