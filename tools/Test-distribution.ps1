param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$oldPath=$env:PATH;$oldHome=$env:PYTHONHOME;$oldPythonPath=$env:PYTHONPATH
$count=0
function Assert-Pack($Condition,[string]$Label){if(-not $Condition){throw $Label};$script:count++}
try{
 $env:PATH="$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\WindowsPowerShell\v1.0"
 $env:PYTHONHOME=Join-Path $Root 'nonexistent-poison-home';$env:PYTHONPATH=Join-Path $Root 'nonexistent-poison-path'
 . (Join-Path $Root 'tools\Pack-Python.ps1')
 $python=Get-PackPython $Root
 Assert-Pack ($python -eq (Join-Path $Root 'runtime\python\python.exe')) 'Bundled interpreter not selected'
 $probe=(& $python -I -B -X utf8 (Join-Path $Root 'tools\runtime_probe.py')) | ConvertFrom-Json
 Assert-Pack ($probe.ok -and $probe.isolated -and $probe.ignore_environment -and $probe.bits -eq 32) 'Runtime isolation/dependencies failed'
 foreach($tool in @('install','update','collect_debug')){
  $output=& $python -I -B -X utf8 (Join-Path $Root 'tools\entrypoint.py') $tool --help
  Assert-Pack ($LASTEXITCODE -eq 0 -and ($output -join "`n") -match 'usage:') ('Entry point failed: '+$tool)
 }
 $pathFile=Join-Path $Root 'runtime\python\python314._pth';$original=[IO.File]::ReadAllBytes($pathFile)
 try{
  [IO.File]::AppendAllText($pathFile,"`n# synthetic mutation`n")
  $refused=$false;try{Get-PackPython $Root | Out-Null}catch{$refused=$_.Exception.Message -match 'integrity'}
  Assert-Pack $refused 'Modified runtime was not rejected'
 }finally{[IO.File]::WriteAllBytes($pathFile,$original)}
 $exeFile=Join-Path $Root 'runtime\python\python.exe';$held=$exeFile+'.qa-held'
 if(Test-Path -LiteralPath $held){throw 'Use a fresh extracted distribution'}
 try{
  Move-Item -LiteralPath $exeFile -Destination $held
  $refused=$false;try{Get-PackPython $Root | Out-Null}catch{$refused=$true}
  Assert-Pack $refused 'Missing runtime silently fell back to system Python'
 }finally{if(Test-Path -LiteralPath $held){Move-Item -LiteralPath $held -Destination $exeFile}}
 $again=Get-PackPython $Root
 Assert-Pack ($again -eq $python) 'Restored runtime failed'
 @{result='PASS';checks=$count;noPythonOnPath=$true;poisonedEnvironmentIgnored=$true;offline=$true;architecture=32} | ConvertTo-Json
}finally{$env:PATH=$oldPath;$env:PYTHONHOME=$oldHome;$env:PYTHONPATH=$oldPythonPath}
