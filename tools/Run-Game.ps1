. "$PSScriptRoot\Enter-Dev.ps1"
New-Item -ItemType Directory -Force -Path "$ProjectRoot\Logs" | Out-Null
$editor = $GodotExe.Replace('_console.exe', '.exe')
Start-Process -FilePath $editor -ArgumentList @('--path', ('"' + $GodotProject + '"'), '--log-file', ('"' + "$ProjectRoot\Logs\godot-play.log" + '"'))
