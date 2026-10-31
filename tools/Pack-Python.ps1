function Get-PackPython([string]$Root,[string]$Language='en'){
 $runtime=Join-Path $Root 'runtime\python';$exe=Join-Path $runtime 'python.exe'
 if(Test-Path -LiteralPath $runtime){
  $manifestPath=Join-Path $runtime 'manifest.json'
  if(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Bundled Python is incomplete. Extract the entire release ZIP again.'}
  $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $lock=Get-Content -LiteralPath (Join-Path $Root 'tools\python-runtime.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if($manifest.archive_sha256 -ne $lock.sha256 -or $manifest.version -ne $lock.version){throw 'Bundled Python does not match this release.'}
  foreach($entry in $manifest.files.PSObject.Properties){
   if($entry.Name -notmatch '^[A-Za-z0-9_.-]+$' -or $entry.Name -eq '..'){throw 'Invalid bundled Python manifest.'}
   $file=Join-Path $runtime $entry.Name
   if(-not (Test-Path -LiteralPath $file -PathType Leaf) -or ((Get-Item -LiteralPath $file).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Bundled Python is incomplete. Extract the entire release ZIP again.'}
   $algorithm=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($file)
   try{$actualHash=([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}
   finally{$stream.Dispose();$algorithm.Dispose()}
   if($actualHash -ne $entry.Value){throw 'Bundled Python integrity check failed. Extract the release ZIP again.'}
  }
  if(-not $manifest.files.'python.exe' -or -not $manifest.files.($lock.stdlib_zip) -or -not $manifest.files.($lock.path_file) -or -not $manifest.files.'vcruntime140.dll'){throw 'Bundled Python manifest is incomplete.'}
 }else{
  $commands=@(Get-Command python.exe -CommandType Application -All -ErrorAction SilentlyContinue | Where-Object {$_.Source -notmatch '\\WindowsApps\\'})
  if(-not $commands.Count){
   if($Language -eq 'ru'){throw 'Скачайте полный ZIP из Releases и распакуйте его целиком. В нём Python уже включён. ZIP исходников требует Python 3.12 или новее.'}
   throw 'Download and fully extract the ZIP from Releases; Python is included. Source-only archives require Python 3.12 or newer.'
  }
  $exe=$commands[0].Source
 }
 $probe=& $exe -I -B -X utf8 (Join-Path $Root 'tools\runtime_probe.py') 2>$null
 if($LASTEXITCODE -ne 0 -or -not (($probe -join "`n") | ConvertFrom-Json).ok){throw 'Python could not start or lacks required standard-library components. Extract the full release ZIP again.'}
 return $exe
}
