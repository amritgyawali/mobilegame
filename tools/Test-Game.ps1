. "$PSScriptRoot\Enter-Dev.ps1"
& python "$PSScriptRoot\check_android_policy.py"
if ($LASTEXITCODE -ne 0) { throw 'Android-only project policy failed.' }
New-Item -ItemType Directory -Force -Path "$ProjectRoot\Logs" | Out-Null
foreach ($test in @('rules', 'scene')) {
    $stdout = "$ProjectRoot\Logs\godot-$test.log"
    $stderr = "$ProjectRoot\Logs\godot-$test-errors.log"
    $process = Start-Process -FilePath $GodotExe -ArgumentList @('--headless', '--path', ('"' + $GodotProject + '"'), '--script', "res://tests/${test}_test.gd") -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Get-Content -LiteralPath $stdout
    $errors = Get-Content -LiteralPath $stderr -Raw
    if ($errors) { Write-Output $errors }
    if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR:|ERROR:') { throw "Godot $test checks failed. See $stdout and $stderr." }
}
