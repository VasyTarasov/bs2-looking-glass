$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
try{
 $folder=New-Object System.Windows.Forms.FolderBrowserDialog
 $folder.Description='BLACK SOULS II folder / Папка BLACK SOULS II'
 if($folder.ShowDialog() -ne 'OK'){exit}
 . (Join-Path $PSScriptRoot 'tools\Pack-Python.ps1')
 $python=Get-PackPython $PSScriptRoot
 $output=& $python -I -B -X utf8 (Join-Path $PSScriptRoot 'tools\entrypoint.py') update --game $folder.SelectedPath --apply
 $code=$LASTEXITCODE;$result=($output -join "`n") | ConvertFrom-Json
 if($code -ne 0){throw $result.error}
 [System.Windows.Forms.MessageBox]::Show('Update complete. Saves and settings retained. / Обновление завершено. Сохранения и настройки сохранены.','BLACK SOULS II — QoL Pack') | Out-Null
}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'BLACK SOULS II — QoL Pack','OK','Error') | Out-Null;exit 1}
