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
try {
	$destination = New-Item -ItemType Directory -Path (Join-Path $staging 'd365bap.tools') -Force
	Copy-Item -Path (Join-Path $root 'd365bap.tools\*') -Destination $destination.FullName -Recurse -Force
	& (Join-Path $root 'build/Merge-FormatPs1Xml.ps1') -XmlRoot (Join-Path $destination.FullName 'xml')
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
	$compiledManifest = Join-Path $destination.FullName 'd365bap.tools.psd1'
	$smokeScript = Join-Path $staging 'smoke.ps1'
	@'
param([string] $Manifest)
$ErrorActionPreference = 'Stop'
$expectedPath = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $Manifest) 'd365bap.tools.psm1')).ProviderPath
$imported = @(Import-Module -Name $Manifest -Force -PassThru -ErrorAction Stop)
$PSModuleAutoLoadingPreference = 'None'
$loaded = @($imported | Where-Object { $_.Path -eq $expectedPath })
if ($loaded.Count -ne 1) { throw "Expected staged compiled module at $expectedPath; imported: $($imported.Path -join ', ')" }
foreach ($name in @('Get-UdeNuget', 'Get-BapEnvironment', 'Get-FscmEnvironmentVersion')) {
    $command = Get-Command -Name $name -ErrorAction Stop
    if ($null -eq $command.Module -or $command.Module.Path -ne $expectedPath) {
        throw "Command $name did not resolve to the staged compiled module: $($command.Source)"
    }
}
Write-Host 'Compiled module and formats import.'
'@ | Set-Content -LiteralPath $smokeScript -Encoding utf8
	& pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $smokeScript -Manifest $compiledManifest
	$importExit = $LASTEXITCODE
	if ($importExit -ne 0) { throw 'Compiled module import failed.' }
}
finally {
	if (Test-Path -LiteralPath $staging) {
		$resolved = (Resolve-Path -LiteralPath $staging).Path
		$tempRoot = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
			-not ([IO.Path]::GetFileName($resolved) -match '^bap-compile-[0-9a-f]{32}$')) {
			throw 'Refusing to remove a staging path outside the expected temporary directory.'
		}
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
