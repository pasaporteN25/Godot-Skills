# Corre TODOS los tests headless (tests/headless/all.gd: run.gd y los demás, cada uno en su proceso).
# Falla (código 1) si algún test falla o si aparece un SCRIPT ERROR.
# Uso: .\tools\test.ps1                      -> todos
#      .\tools\test.ps1 -Solo wiki,controls  -> solo los que contengan esos nombres
param([string]$Solo = "")
$godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$root = Split-Path -Parent $PSScriptRoot
& $godot --headless --path $root --import | Out-Null
$out = "$env:TEMP\fw_test_out.txt"
$err = "$env:TEMP\fw_test_err.txt"
$arguments = @('--headless', '--path', $root, '-s', 'tests/headless/all.gd')
if ($Solo -ne "") { $arguments += @('--', "solo=$Solo") }
$p = Start-Process -FilePath $godot -ArgumentList $arguments `
	-NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Get-Content $out -Encoding UTF8
$errors = Get-Content $err -ErrorAction SilentlyContinue | Select-String "SCRIPT ERROR|Parse Error"
if ($errors) {
	Write-Host "`nSCRIPT ERRORS:" -ForegroundColor Red
	$errors | ForEach-Object { Write-Host $_ }
	exit 1
}
exit $p.ExitCode
