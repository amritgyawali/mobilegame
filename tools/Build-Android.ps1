param([ValidateSet('DebugApk')][string]$Mode = 'DebugApk')
. "$PSScriptRoot\Enter-Dev.ps1"
& python "$PSScriptRoot\check_android_policy.py"
if ($LASTEXITCODE -ne 0) { throw 'Android-only project policy failed.' }
New-Item -ItemType Directory -Force -Path "$ProjectRoot\Logs", "$ProjectRoot\Builds\Android" | Out-Null
$artifact = "$ProjectRoot\Builds\Android\SummitShards-debug.apk"
$stdout = "$ProjectRoot\Logs\godot-android-export.log"
$stderr = "$ProjectRoot\Logs\godot-android-export-errors.log"
$process = Start-Process -FilePath $GodotExe -ArgumentList @('--headless', '--path', ('"' + $GodotProject + '"'), '--export-debug', 'Android', ('"' + $artifact + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout -Tail 12
$errors = Get-Content -LiteralPath $stderr -Raw
if ($errors) { Write-Output $errors }
if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $artifact) -or $errors -match 'ERROR:') { throw "Android export failed. See $stdout and $stderr." }
& "$env:JAVA_HOME\bin\java.exe" -jar "$env:ANDROID_HOME\build-tools\36.0.0\lib\apksigner.jar" verify --verbose $artifact
if ($LASTEXITCODE -ne 0) { throw 'APK signature validation failed.' }
& python "$PSScriptRoot\verify_android.py" $artifact "$env:ANDROID_HOME\build-tools\36.0.0\aapt.exe"
if ($LASTEXITCODE -ne 0) { throw 'APK archive/manifest validation failed.' }
Get-Item -LiteralPath $artifact | Select-Object FullName, Length
