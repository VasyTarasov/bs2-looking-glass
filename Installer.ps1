param([switch]$ValidateOnly,[switch]$PreviewOnly,[string]$PreviewOutput,[ValidateSet('en','ru')][string]$UILanguage='en',[string]$PreviewModule='hd_display',[int]$PreviewHeight=0)
$ErrorActionPreference='Stop'
$script:lang='en';if($UILanguage){$script:lang=$UILanguage}
$script:strings=@{
 en=@{title='BLACK SOULS II — QoL Pack 1.02';folder='BLACK SOULS II folder';browse='Browse…';choose='Select the folder containing Game.exe';note='Choose the mod language. This does not translate the game. Close the game before installing. Saves and settings are retained.';ready='Choose features. Point to a choice or select it with Tab to read its description.';install='Install / change selection';check='Check';remove='Remove modpack';empty='Select a feature or use Remove modpack.';compatible='Compatible build. Installed: {0}. Game running: {1}.';removed='Modpack disabled. Saves, settings, loadouts and journals are retained.';done='Selected features installed. Individual settings are available in the game.';failed='No change completed: ';caption='BLACK SOULS II — QoL Pack';yes='yes';no='no';version='Mod language';requires='Also selects: '}
 ru=@{title='BLACK SOULS II — QoL Pack 1.02';folder='Папка BLACK SOULS II';browse='Обзор…';choose='Выберите папку с Game.exe';note='Выберите язык мода. Игра не переводится. Перед установкой закройте игру. Сохранения и настройки сохраняются.';ready='Выберите возможности. Наведите указатель или выберите пункт клавишей Tab, чтобы прочитать описание.';install='Установить / изменить состав';check='Проверить';remove='Удалить модпак';empty='Выберите возможность или используйте «Удалить модпак».';compatible='Сборка совместима. Установлено: {0}. Игра запущена: {1}.';removed='Модпак отключён. Сохранения, настройки, комплекты и журналы сохранены.';done='Выбранные возможности установлены. Отдельные настройки доступны в игре.';failed='Изменение не выполнено: ';caption='BLACK SOULS II — QoL Pack';yes='да';no='нет';version='Язык мода';requires='Также включается: '}
}
function T([string]$key){return $script:strings[$script:lang][$key]}
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'modules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:modulesById=@{};foreach($m in $manifest){$script:modulesById[$m.id]=$m}
function Module-Text($m,[string]$kind){return [string]$m.($kind+'_'+$script:lang)}
function Module-Description($m){$text=Module-Text $m 'description';if($m.requires.Count){$names=@($m.requires | ForEach-Object {Module-Text $script:modulesById[$_] 'name'});$text+="`n"+(T 'requires')+($names -join ', ')};return $text}
function Tooltip-Text([string]$text){
 $lines=New-Object 'System.Collections.Generic.List[string]'
 foreach($paragraph in ($text -split "`n")){
  $line=''
  foreach($word in ($paragraph -split '\s+')){
   $candidate=if($line){$line+' '+$word}else{$word}
   if($line -and $candidate.Length -gt 68){$lines.Add($line);$line=$word}else{$line=$candidate}
  }
  if($line){$lines.Add($line)}
 }
 return $lines -join "`n"
}
if($ValidateOnly){
 if((($script:strings.en.Keys | Sort-Object)-join ',') -ne (($script:strings.ru.Keys | Sort-Object)-join ',')){throw 'Translation keys differ'}
 foreach($m in $manifest){foreach($key in @('name_en','name_ru','description_en','description_ru','group_en','group_ru')){if(-not $m.$key){throw "Missing module field: $key"}};foreach($d in $m.requires){if(-not $script:modulesById.ContainsKey($d)){throw 'Unknown dependency'}}}
 $off=@($manifest | Where-Object {-not $_.default} | ForEach-Object {$_.id} | Sort-Object);if(($off -join ',') -ne 'battle_support,debug,legacy_shortcuts'){throw 'Unexpected defaults'}
 @{result='PASS';version='1.02';defaultLanguage=$script:lang;languages=@('en','ru');modules=$manifest.Count;defaultOff=$off;uiShown=$false} | ConvertTo-Json;return
}
Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object System.Windows.Forms.Form;$form.ClientSize=New-Object System.Drawing.Size(920,580)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.AutoScaleMode='Dpi';$form.Font=New-Object System.Drawing.Font('Segoe UI',9.5)
$label=New-Object System.Windows.Forms.Label;$label.SetBounds(16,11,700,20);$form.Controls.Add($label)
$language=New-Object System.Windows.Forms.Button;$language.SetBounds(804,8,100,26);$form.Controls.Add($language)
$folder=New-Object System.Windows.Forms.TextBox;$folder.Text='C:\SteamLibrary\steamapps\common\BLACK SOULS II';$folder.SetBounds(16,40,786,25);$form.Controls.Add($folder)
$browse=New-Object System.Windows.Forms.Button;$browse.SetBounds(814,38,90,27);$form.Controls.Add($browse)
$browse.Add_Click({$dialog=New-Object System.Windows.Forms.FolderBrowserDialog;$dialog.Description=T 'choose';if($dialog.ShowDialog() -eq 'OK'){$folder.Text=$dialog.SelectedPath};$dialog.Dispose()})
$gameLabel=New-Object System.Windows.Forms.Label;$gameLabel.SetBounds(16,79,120,20);$form.Controls.Add($gameLabel)
$gameVersion=New-Object System.Windows.Forms.ComboBox;$gameVersion.DropDownStyle='DropDownList';$gameVersion.SetBounds(140,75,240,26);$form.Controls.Add($gameVersion)
$note=New-Object System.Windows.Forms.Label;$note.SetBounds(400,73,504,32);$note.Font=New-Object System.Drawing.Font('Segoe UI',9);$form.Controls.Add($note)
$panel=New-Object System.Windows.Forms.Panel;$panel.SetBounds(16,108,888,278);$panel.AutoScroll=$false;$form.Controls.Add($panel)
$script:boxes=@{};$headers=@{}
# Whole sections occupy three columns; no checkbox or section scrolls.
$layout=@{display=@(0,0);combat=@(0,88);support=@(1,0);information=@(1,88);equipment=@(1,176);exploration=@(2,0);additional=@(2,160)}
foreach($groupId in @('display','combat','support','information','equipment','exploration','additional')){
 $members=@($manifest | Where-Object {$_.group -eq $groupId})
 $position=$layout[$groupId];$group=New-Object System.Windows.Forms.GroupBox
 $group.SetBounds(($position[0]*300),$position[1],288,(30+$members.Count*24))
 $group.Font=New-Object System.Drawing.Font('Segoe UI',9.5,[System.Drawing.FontStyle]::Bold)
 $headers[$groupId]=$group;$panel.Controls.Add($group);$row=0
 foreach($m in $members){
  $box=New-Object System.Windows.Forms.CheckBox;$box.Checked=$m.default;$box.SetBounds(10,(22+$row*24),268,24)
  $box.Font=New-Object System.Drawing.Font('Segoe UI',9.5);$box.Tag=$m.id;$box.AccessibleRole='CheckButton'
  $script:boxes[$m.id]=$box;$group.Controls.Add($box);$row++
 }
}
$helpTitle=New-Object System.Windows.Forms.Label;$helpTitle.SetBounds(16,398,888,20);$helpTitle.Font=New-Object System.Drawing.Font('Segoe UI',9.5,[System.Drawing.FontStyle]::Bold);$form.Controls.Add($helpTitle)
$moduleHelp=New-Object System.Windows.Forms.Label;$moduleHelp.SetBounds(16,422,888,56);$form.Controls.Add($moduleHelp)
$install=New-Object System.Windows.Forms.Button;$install.SetBounds(16,486,338,32);$form.Controls.Add($install)
$check=New-Object System.Windows.Forms.Button;$check.SetBounds(366,486,200,32);$form.Controls.Add($check)
$remove=New-Object System.Windows.Forms.Button;$remove.SetBounds(578,486,326,32);$form.Controls.Add($remove)
$status=New-Object System.Windows.Forms.Label;$status.SetBounds(16,532,888,32);$status.ForeColor=[System.Drawing.Color]::DimGray;$form.Controls.Add($status)
$tooltip=New-Object System.Windows.Forms.ToolTip;$tooltip.InitialDelay=450;$tooltip.ReshowDelay=100;$tooltip.AutoPopDelay=20000;$tooltip.ShowAlways=$true
$script:helpId='hd_display';$script:syncing=$false
function Show-ModuleHelp($box,[bool]$popup=$false){$script:helpId=[string]$box.Tag;$m=$script:modulesById[$script:helpId];$helpTitle.Text=Module-Text $m 'name';$moduleHelp.Text=Module-Description $m;if($popup -and $form.Visible){$popupText=Tooltip-Text $moduleHelp.Text;$tooltip.Show($popupText,$box,25,$box.Height,16000)}}
function Sync-Dependencies($box){
 if($script:syncing){return};$script:syncing=$true
 try{if($box.Checked){foreach($d in $script:modulesById[[string]$box.Tag].requires){$script:boxes[$d].Checked=$true}}
 do{$changed=$false;foreach($m in $manifest){if($script:boxes[$m.id].Checked){foreach($d in $m.requires){if(-not $script:boxes[$d].Checked){$script:boxes[$m.id].Checked=$false;$changed=$true}}}}}while($changed)
 }finally{$script:syncing=$false};Show-ModuleHelp $box
}
foreach($box in $script:boxes.Values){$box.Add_MouseEnter({Show-ModuleHelp $this});$box.Add_Enter({Show-ModuleHelp $this $true});$box.Add_Leave({$tooltip.Hide($this)});$box.Add_CheckedChanged({Sync-Dependencies $this})}
function Apply-Language{
 $form.Text=T 'title';$label.Text=T 'folder';$browse.Text=T 'browse';$note.Text=T 'note';$install.Text=T 'install';$check.Text=T 'check';$remove.Text=T 'remove';$status.Text=T 'ready'
 $language.Text=if($script:lang -eq 'en'){'Русский'}else{'English'};$gameLabel.Text=T 'version'
 $selection=$gameVersion.SelectedIndex;if($selection -lt 0){$selection=0};$gameVersion.Items.Clear()
 if($script:lang -eq 'en'){$gameVersion.Items.AddRange(@('Auto-detect','English','Russian'))}else{$gameVersion.Items.AddRange(@('Определить автоматически','Английский','Русский'))};$gameVersion.SelectedIndex=$selection
 foreach($m in $manifest){$box=$script:boxes[$m.id];$box.Text=Module-Text $m 'name';$box.AccessibleName=$box.Text;$box.AccessibleDescription=Module-Description $m;$tooltip.SetToolTip($box,(Tooltip-Text $box.AccessibleDescription));$headers[$m.group].Text=Module-Text $m 'group'}
 Show-ModuleHelp $script:boxes[$script:helpId]
}
$language.Add_Click({$script:lang=if($script:lang -eq 'en'){'ru'}else{'en'};Apply-Language})
function Invoke-ModuleInstaller([string]$Mode){
 $install.Enabled=$false;$check.Enabled=$false;$remove.Enabled=$false
 try{. (Join-Path $PSScriptRoot 'tools\Pack-Python.ps1');$python=Get-PackPython $PSScriptRoot $script:lang;$selectedLanguage=@('auto','en','ru')[$gameVersion.SelectedIndex];$arguments=@('-I','-B','-X','utf8',(Join-Path $PSScriptRoot 'tools\entrypoint.py'),'install','--game',$folder.Text,'--language',$selectedLanguage)
 if($Mode -eq 'install'){$selected=@($manifest | Where-Object {$script:boxes[$_.id].Checked} | ForEach-Object {$_.id});if($selected.Count -eq 0){throw (T 'empty')};$arguments+=@('--install','--modules',($selected -join ','))}elseif($Mode -eq 'uninstall'){$arguments+='--uninstall'}
 $output=& $python @arguments;$code=$LASTEXITCODE;$result=($output -join "`n") | ConvertFrom-Json;if($code -ne 0){throw $result.error}
 if($Mode -eq 'check'){$gameVersion.SelectedIndex=if($result.language -eq 'en'){1}else{2};if($null -ne $result.module_ids){$script:syncing=$true;try{foreach($m in $manifest){$script:boxes[$m.id].Checked=$result.module_ids -contains $m.id}}finally{$script:syncing=$false}};$installed=if($result.installed){T 'yes'}else{T 'no'};$running=if($result.target_running){T 'yes'}else{T 'no'};$status.Text=(T 'compatible') -f $installed,$running
 }elseif($Mode -eq 'uninstall'){$status.Text=T 'removed'}else{$status.Text=T 'done'}
 }catch{$status.Text=(T 'failed')+$_.Exception.Message;[System.Windows.Forms.MessageBox]::Show($_.Exception.Message,(T 'caption'),'OK','Information') | Out-Null}finally{$install.Enabled=$true;$check.Enabled=$true;$remove.Enabled=$true}
}
$install.Add_Click({Invoke-ModuleInstaller 'install'});$check.Add_Click({Invoke-ModuleInstaller 'check'});$remove.Add_Click({Invoke-ModuleInstaller 'uninstall'})
Apply-Language
if($PreviewOnly){
 if(-not $PreviewOutput){throw 'Preview output path is required'};$form.ShowInTaskbar=$false;$form.Opacity=0;$form.Show();[System.Windows.Forms.Application]::DoEvents()
 if(-not $script:boxes.ContainsKey($PreviewModule)){throw 'Unknown preview module'};$target=$script:boxes[$PreviewModule];Show-ModuleHelp $target
 $script:boxes['semantic_groups'].Checked=$false;if($script:boxes['macros'].Checked){throw 'Dependent macro was not disabled'};$script:boxes['macros'].Checked=$true;if(-not $script:boxes['semantic_groups'].Checked){throw 'Macro prerequisite was not enabled'}
 foreach($m in $manifest){if($tooltip.GetToolTip($script:boxes[$m.id]) -ne (Tooltip-Text (Module-Description $m))){throw 'Tooltip content mismatch'}}
 $target.Focus() | Out-Null;[System.Windows.Forms.Application]::DoEvents()
 if($script:helpId -ne $PreviewModule){throw 'Keyboard focus did not update the description'}
 $language.PerformClick();$language.PerformClick()
 foreach($m in $manifest){if($tooltip.GetToolTip($script:boxes[$m.id]) -ne (Tooltip-Text (Module-Description $m))){throw 'Tooltip language switch mismatch'}}
 foreach($g in $headers.Values){
  if($g.Left -lt 0 -or $g.Top -lt 0 -or $g.Right -gt $panel.ClientSize.Width -or $g.Bottom -gt $panel.ClientSize.Height){throw 'Section extends outside the module area'}
 }
 foreach($box in $script:boxes.Values){
  if(-not $box.Visible -or $box.Right -gt $box.Parent.ClientSize.Width -or $box.Bottom -gt $box.Parent.ClientSize.Height){throw 'Module choice is clipped'}
  $size=[System.Windows.Forms.TextRenderer]::MeasureText($box.Text,$box.Font)
  if($size.Width+22 -gt $box.Width){throw ('Module name is too wide: '+$box.Tag)}
 }
 if($panel.AutoScroll -or $panel.VerticalScroll.Visible -or $panel.HorizontalScroll.Visible){throw 'Module area must not scroll'}
 foreach($control in @($install,$check,$remove,$status,$moduleHelp)){if($control.Bottom -gt $form.ClientSize.Height -or $control.Right -gt $form.ClientSize.Width){throw 'Footer extends outside the dialog'}}
 Show-ModuleHelp $target;$tooltip.Hide($target);$form.Refresh();[System.Windows.Forms.Application]::DoEvents()
 $bitmap=New-Object System.Drawing.Bitmap($form.Width,$form.Height)
 try{$form.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save([IO.Path]::GetFullPath($PreviewOutput),[System.Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
 @{result='PASS';language=$script:lang;modules=$script:boxes.Count;descriptions=20;groups=$headers.Count;gameVersions=$gameVersion.Items.Count;previewWritten=$true;dependencyEventsVerified=$true;columns=3;allChoicesVisible=$true;scrollbars=$false;clientWidth=$form.ClientSize.Width;clientHeight=$form.ClientSize.Height} | ConvertTo-Json
 $tooltip.Dispose();$form.Dispose();return
}
[void]$form.ShowDialog();$tooltip.Dispose();$form.Dispose()
