#Requires -Version 7.6
#Requires -PSEdition Core
<#
    .SYNOPSIS
        Compiles and imports the module.

    .DESCRIPTION
        Concatenates sources like the release build, then smoke-imports in a child process. Staging copies the import surface only. Smoke softens RequiredModules to skip Az.Accounts while asserting the source manifest still requires it for users.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$moduleRoot = Join-Path $root 'd365bap.tools'
$staging = Join-Path ([IO.Path]::GetTempPath()) ('bap-compile-' + [guid]::NewGuid().ToString('N'))
try {
	$destination = New-Item -ItemType Directory -Path (Join-Path $staging 'd365bap.tools') -Force
	foreach ($name in @('bin', 'en-us', 'internal', 'xml', 'd365bap.tools.psd1', 'd365bap.tools.psm1')) {
		Copy-Item -LiteralPath (Join-Path $moduleRoot $name) -Destination $destination.FullName -Recurse -Force
	}
	& (Join-Path $root 'build/Merge-FormatPs1Xml.ps1') -XmlRoot (Join-Path $destination.FullName 'xml')
	$text = @()
	$processed = @()
	foreach ($filePath in (& (Join-Path $moduleRoot 'internal\scripts\preimport.ps1'))) {
		if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
		$item = Get-Item -LiteralPath $filePath
		if ($item.PSIsContainer) { continue }
		if ($item.FullName -in $processed) { continue }
		$text += [IO.File]::ReadAllText($item.FullName)
		$processed += $item.FullName
	}
	Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'internal\functions') -Recurse -File -Filter '*.ps1' | ForEach-Object {
		$text += [IO.File]::ReadAllText($_.FullName)
	}
	Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'functions') -Recurse -File -Filter '*.ps1' | ForEach-Object {
		$text += [IO.File]::ReadAllText($_.FullName)
	}
	foreach ($filePath in (& (Join-Path $moduleRoot 'internal\scripts\postimport.ps1'))) {
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

	# Users still require Az.Accounts via the source manifest. Smoke drops it from
	# the staged RequiredModules so Import-Module does not pay Az.Accounts load
	# cost; postimport Get-AzContext must not auto-load it either.
	$sourcePsd1 = Get-Content -LiteralPath (Join-Path $moduleRoot 'd365bap.tools.psd1') -Raw
	foreach ($needed in @('PSFramework', 'ImportExcel', 'Az.Accounts')) {
		if ($sourcePsd1 -notmatch [regex]::Escape($needed)) {
			throw "Source manifest must list $needed in RequiredModules for users."
		}
	}
	$azAvailable = Get-Module -ListAvailable -Name Az.Accounts |
	Where-Object { $_.Version -ge [version]'2.17.0' } |
	Select-Object -First 1
	if (-not $azAvailable) {
		throw 'Az.Accounts 2.17.0 or newer must be installed for users (RequiredModules); CI cache/install did not provide it.'
	}

	$psd1Text = Get-Content -LiteralPath $compiledManifest -Raw
	$softText = [regex]::Replace(
		$psd1Text,
		'(?s)RequiredModules\s*=\s*@\((?:[^()]|\([^)]*\))*\)',
		"RequiredModules   = (@{ ModuleName = 'PSFramework'; ModuleVersion = '1.9.310' }, @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.8.6' })"
	)
	if ($softText -eq $psd1Text) {
		throw 'Failed to soften staged RequiredModules for compiled-import smoke.'
	}
	$softManifest = Join-Path $destination.FullName 'd365bap.tools.smoke.psd1'
	[IO.File]::WriteAllText($softManifest, $softText, [Text.Encoding]::UTF8)

	$smokeScript = Join-Path $staging 'smoke.ps1'
	@'
param([string] $Manifest)
$ErrorActionPreference = 'Stop'
# -NoProfile children do not preload Utility/Management; load them before ModuleQualified.
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security -ErrorAction Stop
$expectedPath = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $Manifest) 'd365bap.tools.psm1')).ProviderPath
# Block unqualified Get-AzContext from auto-loading Az.Accounts during import.
$PSModuleAutoLoadingPreference = 'ModuleQualified'
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
if (Get-Module -Name Az.Accounts -ErrorAction SilentlyContinue) {
    throw 'Smoke import loaded Az.Accounts; soft RequiredModules path failed.'
}
Write-Host 'Compiled module and formats import.'
'@ | Set-Content -LiteralPath $smokeScript -Encoding utf8
	& pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $smokeScript -Manifest $softManifest
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
