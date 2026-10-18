param([switch]$ValidateOnly)
$ErrorActionPreference='Stop'
$script:lang='en'
$script:strings=@{
 en=@{title='Looking Glass 0.91-dev — BLACK SOULS II';folder='BLACK SOULS II folder';browse='Browse...';choose='Select the folder containing Game.exe';note='Close the game before changing modules. Settings are retained. Diagnostics are opt-in; review local reports before sharing.';ready='Select modules, then choose Install / change.';install='Install / change';check='Check';remove='Remove modules';empty='Select a module or use Remove modules.';compatible='Compatible build. Installed: {0}. Game running: {1}.';removed='Modules disabled. Saves, settings, loadouts and logs remain local.';done='Selected modules installed. Open mod settings in the game.';failed='No change completed: ';caption='Looking Glass';yes='yes';no='no'}
 ru=@{title='Looking Glass 0.91-dev — BLACK SOULS II';folder='Папка BLACK SOULS II';browse='Обзор…';choose='Выберите папку с Game.exe';note='Закройте игру перед изменением модулей. Настройки сохраняются. Диагностика включается отдельно; проверьте отчёт перед отправкой.';ready='Выберите модули и нажмите «Установить / изменить».';install='Установить / изменить';check='Проверить';remove='Удалить модули';empty='Выберите модуль или используйте «Удалить модули».';compatible='Сборка совместима. Установлено: {0}. Игра запущена: {1}.';removed='Модули отключены. Сейвы, настройки, комплекты и журналы сохранены.';done='Выбранные модули установлены. Настройки доступны в игре.';failed='Изменение не выполнено: ';caption='Looking Glass';yes='да';no='нет'}
}
function T([string]$key) { return $script:strings[$script:lang][$key] }
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'modules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($ValidateOnly) {
 $enKeys=($script:strings.en.Keys | Sort-Object) -join ',';$ruKeys=($script:strings.ru.Keys | Sort-Object) -join ','
 if ($enKeys -ne $ruKeys) { throw 'Translation keys differ' }
 foreach ($m in $manifest) { if (-not $m.name_en -or -not $m.name_ru) { throw 'Missing module translation' } }
 @{result='PASS';version='0.91-dev';defaultLanguage=$script:lang;languages=@('en','ru');modules=$manifest.Count;uiShown=$false} | ConvertTo-Json
 return
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object System.Windows.Forms.Form
$form.ClientSize=New-Object System.Drawing.Size(700,920)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$form.Font=New-Object System.Drawing.Font('Segoe UI',10)
$label=New-Object System.Windows.Forms.Label;$label.SetBounds(20,15,490,25);$form.Controls.Add($label)
$language=New-Object System.Windows.Forms.Button;$language.SetBounds(550,10,130,30);$form.Controls.Add($language)
$folder=New-Object System.Windows.Forms.TextBox;$folder.Text='C:\SteamLibrary\steamapps\common\BLACK SOULS II';$folder.SetBounds(20,48,550,28);$form.Controls.Add($folder)
$browse=New-Object System.Windows.Forms.Button;$browse.SetBounds(580,46,100,30);$form.Controls.Add($browse)
$browse.Add_Click({$dialog=New-Object System.Windows.Forms.FolderBrowserDialog;$dialog.Description=(T 'choose');if ($dialog.ShowDialog() -eq 'OK') {$folder.Text=$dialog.SelectedPath};$dialog.Dispose()})
$boxes=@{};$moduleY=87
foreach ($module in $manifest) {$box=New-Object System.Windows.Forms.CheckBox;$box.Checked=$module.default;$box.SetBounds(20,$moduleY,660,25);$boxes[$module.id]=$box;$form.Controls.Add($box);$moduleY+=27}
$boxes['retry'].Add_CheckedChanged({if($boxes['retry'].Checked){$boxes['defeat'].Checked=$true}})
$boxes['defeat'].Add_CheckedChanged({if(-not $boxes['defeat'].Checked){$boxes['retry'].Checked=$false}})
$note=New-Object System.Windows.Forms.Label;$note.SetBounds(20,($moduleY+10),660,65);$form.Controls.Add($note)
$install=New-Object System.Windows.Forms.Button;$install.SetBounds(20,($moduleY+80),240,35);$form.Controls.Add($install)
$check=New-Object System.Windows.Forms.Button;$check.SetBounds(270,($moduleY+80),180,35);$form.Controls.Add($check)
$remove=New-Object System.Windows.Forms.Button;$remove.SetBounds(460,($moduleY+80),220,35);$form.Controls.Add($remove)
$status=New-Object System.Windows.Forms.Label;$status.SetBounds(20,($moduleY+130),660,65);$form.Controls.Add($status)
function Apply-Language {
 $form.Text=T 'title';$label.Text=T 'folder';$browse.Text=T 'browse';$note.Text=T 'note'
 $install.Text=T 'install';$check.Text=T 'check';$remove.Text=T 'remove';$status.Text=T 'ready'
 $language.Text=if($script:lang -eq 'en'){'Русский'}else{'English'}
 foreach($module in $manifest){$boxes[$module.id].Text=if($script:lang -eq 'en'){$module.name_en}else{$module.name_ru}}
}
$language.Add_Click({$script:lang=if($script:lang -eq 'en'){'ru'}else{'en'};Apply-Language})
function Invoke-ModuleInstaller([string]$Mode) {
 $install.Enabled=$false;$check.Enabled=$false;$remove.Enabled=$false
 try {
  $python=Get-Command python -ErrorAction Stop
  $arguments=@('-X','utf8',(Join-Path $PSScriptRoot 'tools\install.py'),'--game',$folder.Text)
  if($Mode -eq 'install'){
   $selected=@();foreach($module in $manifest){if($boxes[$module.id].Checked){$selected+=$module.id}}
   if($selected.Count -eq 0){throw (T 'empty')}
   $arguments+=@('--install','--modules',($selected -join ','))
  }elseif($Mode -eq 'uninstall'){$arguments+='--uninstall'}
  $output=& $python.Source @arguments;$code=$LASTEXITCODE;$result=($output -join "`n") | ConvertFrom-Json
  if($code -ne 0){throw $result.error}
  if($Mode -eq 'check'){
   $selection=Join-Path $folder.Text 'BS2Suite\modules.ini'
   if(Test-Path -LiteralPath $selection){$active=@{};foreach($line in (Get-Content -LiteralPath $selection -Encoding UTF8)){if($line -match '^([a-z_]+)=([01])$'){$active[$Matches[1]]=($Matches[2] -eq '1')}};foreach($module in $manifest){if($active.ContainsKey($module.id)){$boxes[$module.id].Checked=$active[$module.id]}}}
   $installed=if($result.installed){T 'yes'}else{T 'no'};$running=if($result.target_running){T 'yes'}else{T 'no'}
   $status.Text=(T 'compatible') -f $installed,$running
  }elseif($Mode -eq 'uninstall'){$status.Text=T 'removed'}else{$status.Text=T 'done'}
 }catch{$status.Text=(T 'failed')+$_.Exception.Message;[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,(T 'caption'),'OK','Information') | Out-Null}
 finally{$install.Enabled=$true;$check.Enabled=$true;$remove.Enabled=$true}
}
$install.Add_Click({Invoke-ModuleInstaller 'install'});$check.Add_Click({Invoke-ModuleInstaller 'check'});$remove.Add_Click({Invoke-ModuleInstaller 'uninstall'})
Apply-Language
[void]$form.ShowDialog();$form.Dispose()
