#Requires -Version 7.6
#Requires -PSEdition Core
<#
.SYNOPSIS
    Tests formats loaded by the compiled module.

.DESCRIPTION
    Uses a disposable checkout to verify that stale consolidated formats are
    replaced and invalid per-view definitions fail during manifest import.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('bap-format-test-' + [guid]::NewGuid().ToString('N'))

function Invoke-CompiledImport {
	$scriptPath = Join-Path $fixture 'build/Test-CompiledImport.ps1'
	$output = & pwsh -NoProfile -NonInteractive -File $scriptPath 2>&1 | Out-String
	return @{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
	New-Item -ItemType Directory -Path (Join-Path $fixture 'build') -Force | Out-Null
	Copy-Item -LiteralPath (Join-Path $root 'd365bap.tools') -Destination $fixture -Recurse
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-CompiledImport.ps1'), (Join-Path $PSScriptRoot 'Merge-FormatPs1Xml.ps1') -Destination (Join-Path $fixture 'build')
	$xmlRoot = Join-Path $fixture 'd365bap.tools/xml'
	$poison = '<broken'
	$consolidated = @('Table', 'List') | ForEach-Object { Join-Path $xmlRoot "d365bap.tools.$_.Format.ps1xml" }
	foreach ($path in $consolidated) { [IO.File]::WriteAllText($path, $poison) }

	$result = Invoke-CompiledImport
	if ($result.ExitCode -ne 0 -or $result.Output -notmatch 'Compiled module and formats import\.') {
		throw "Compiled import did not regenerate and load the formats: $($result.Output)"
	}
	foreach ($path in $consolidated) {
		if ([IO.File]::ReadAllText($path) -ne $poison) { throw "Compiled import modified the source file $path" }
	}

	$invalidView = @'
<Configuration><ViewDefinitions><View><Name>InvalidFormatTest</Name><ViewSelectedBy><TypeName>InvalidFormatTest</TypeName></ViewSelectedBy><NotAFormatControl /></View></ViewDefinitions></Configuration>
'@
	foreach ($kind in @('table', 'list')) {
		$invalidPath = Join-Path $xmlRoot "formats/$kind/InvalidFormatTest.Format.ps1xml"
		[IO.File]::WriteAllText($invalidPath, $invalidView)
		$result = Invoke-CompiledImport
		Remove-Item -LiteralPath $invalidPath -Force
		if ($result.ExitCode -eq 0) { throw "Compiled import accepted invalid $kind format data: $($result.Output)" }
		if ($result.Output -notmatch 'InvalidFormatTest|NotAFormatControl') { throw "The $kind negative case failed for an unrelated reason: $($result.Output)" }
	}
	Write-Host 'Compiled import regenerates both formats in staging and rejects invalid format data.'
}
finally {
	if (Test-Path -LiteralPath $fixture) {
		$resolved = (Resolve-Path -LiteralPath $fixture).Path
		$tempRoot = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
			-not ([IO.Path]::GetFileName($resolved) -match '^bap-format-test-[0-9a-f]{32}$')) {
			throw 'Refusing to remove a fixture path outside the expected temporary directory.'
		}
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
