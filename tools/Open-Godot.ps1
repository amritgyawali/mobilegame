. "$PSScriptRoot\Enter-Dev.ps1"
$editor = $GodotExe.Replace('_console.exe', '.exe')
if (!(Test-Path -LiteralPath $editor)) { throw 'Godot Editor is missing. See docs/SETUP_STATUS.md.' }
Start-Process -FilePath $editor -ArgumentList @('--editor', '--path', ('"' + $GodotProject + '"'))
