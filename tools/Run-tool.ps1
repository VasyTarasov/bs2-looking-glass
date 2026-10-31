param([Parameter(Mandatory=$true)][ValidateSet('install','update','collect_debug')][string]$Tool,[Parameter(ValueFromRemainingArguments=$true)][string[]]$ToolArguments)
$ErrorActionPreference='Stop'
try{
 $root=Split-Path $PSScriptRoot -Parent
 . (Join-Path $PSScriptRoot 'Pack-Python.ps1')
 $python=Get-PackPython $root
 & $python -I -B -X utf8 (Join-Path $PSScriptRoot 'entrypoint.py') $Tool @ToolArguments
 exit $LASTEXITCODE
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
