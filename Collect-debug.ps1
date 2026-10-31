$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$folder=New-Object System.Windows.Forms.FolderBrowserDialog
$folder.Description='Папка BLACK SOULS II с журналами BS2Suite'
$folder.SelectedPath='C:\SteamLibrary\steamapps\common\BLACK SOULS II'
if ($folder.ShowDialog() -ne 'OK') { exit }
$target=$folder.SelectedPath
$save=New-Object System.Windows.Forms.SaveFileDialog
$save.Title='Куда сохранить локальный диагностический отчёт'
$save.Filter='ZIP (*.zip)|*.zip'
$save.FileName='BS2_debug_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.zip'
if ($save.ShowDialog() -ne 'OK') { exit }
. (Join-Path $PSScriptRoot 'tools\Pack-Python.ps1')
$python=Get-PackPython $PSScriptRoot 'ru'
$result=& $python -I -B -X utf8 (Join-Path $PSScriptRoot 'tools\entrypoint.py') collect_debug --game $target --output $save.FileName
$parsed=($result -join "`n") | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw $parsed.error }
[System.Windows.Forms.MessageBox]::Show('Отчёт сохранён. Ничего не отправлено в интернет. Личные сейвы не включены.','Диагностика BLACK SOULS II') | Out-Null
