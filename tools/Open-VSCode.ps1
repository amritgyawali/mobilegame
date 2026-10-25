. "$PSScriptRoot\Enter-Dev.ps1"
$code = Get-Command code.cmd -ErrorAction Stop
& $code.Source "$ProjectRoot\SummitShards.code-workspace" --new-window
if ($LASTEXITCODE -ne 0) { throw 'VS Code did not open successfully.' }
