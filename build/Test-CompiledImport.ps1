#Requires -Version 7.6
#Requires -PSEdition Core
<#
    .SYNOPSIS
        Compiles and imports the module.

    .DESCRIPTION
        Concatenates the module sources exactly like the release build, then imports the result in a child process. Fails on parser or import errors.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$staging = Join-Path ([IO.Path]::GetTempPath()) ('bap-compile-' + [guid]::NewGuid().ToString('N'))
$destination = New-Item -ItemType Directory -Path (Join-Path $staging 'd365bap.tools') -Force
Copy-Item -Path (Join-Path $root 'd365bap.tools\*') -Destination $destination.FullName -Recurse -Force
$text = @()
$processed = @()
foreach ($filePath in (& (Join-Path $root 'd365bap.tools\internal\scripts\preimport.ps1'))) {
	if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
	$item = Get-Item -LiteralPath $filePath
	if ($item.PSIsContainer) { continue }
	if ($item.FullName -in $processed) { continue }
	$text += [IO.File]::ReadAllText($item.FullName)
	$processed += $item.FullName
}
Get-ChildItem -LiteralPath (Join-Path $destination.FullName 'internal\functions') -Recurse -File -Filter '*.ps1' | ForEach-Object {
	$text += [IO.File]::ReadAllText($_.FullName)
}
Get-ChildItem -LiteralPath (Join-Path $destination.FullName 'functions') -Recurse -File -Filter '*.ps1' | ForEach-Object {
	$text += [IO.File]::ReadAllText($_.FullName)
}
foreach ($filePath in (& (Join-Path $root 'd365bap.tools\internal\scripts\postimport.ps1'))) {
	if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
	$item = Get-Item -LiteralPath $filePath
	if ($item.PSIsContainer) { continue }
	if ($item.FullName -in $processed) { continue }
	$text += [IO.File]::ReadAllText($item.FullName)
	$processed += $item.FullName
}
$fileData = Get-Content -LiteralPath (Join-Path $destination.FullName 'd365bap.tools.psm1') -Raw
$fileData = $fileData.Replace('"<was not compiled>"', '"<was compiled>"')
$fileData = $fileData.Replace('"<compile code into here>"', ($text -join "`n`n"))
[IO.File]::WriteAllText((Join-Path $destination.FullName 'd365bap.tools.psm1'), $fileData, [Text.Encoding]::UTF8)
$compiledPsm1 = Join-Path $destination.FullName 'd365bap.tools.psm1'
& pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Import-Module '$compiledPsm1' -Force -ErrorAction Stop; Get-Command Get-UdeNuget -ErrorAction Stop | Out-Null; Write-Host 'Compiled module imports.'"
$importExit = $LASTEXITCODE
Remove-Item -LiteralPath $staging -Recurse -Force
if ($importExit -ne 0) { exit 1 }
exit 0
