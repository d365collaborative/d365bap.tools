<#
    .SYNOPSIS
        Validates generated artifacts are in sync.

    .DESCRIPTION
        Runs the generators and fails when generated files differ. Generated
        files are owned by the regen workflow. Line ending only changes are
        ignored.

    .PARAMETER RepoRoot
        The repository root to validate.

        Default: the parent of the build directory.
#>
[CmdletBinding()]
param(
	[string] $RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

Push-Location $RepoRoot
try {
	& (Join-Path $RepoRoot 'build/generate-parameterunittests.ps1')

	& (Join-Path $RepoRoot 'build/update-docs.ps1')

	& (Join-Path $RepoRoot 'build/Merge-FormatPs1Xml.ps1')

	$generated = @(
		'd365bap.tools/tests/functions'
		'docs'
		'd365bap.tools/xml/d365bap.tools.Table.Format.ps1xml'
		'd365bap.tools/xml/d365bap.tools.List.Format.ps1xml'
		'wiki/Namespaces.md'
	)

	$dirty = @(git diff --name-only -- $generated)
	$dirty += @(git ls-files --others --exclude-standard -- $generated)
	$dirty = @($dirty | Where-Object { $_ -and $_ -ne 'docs/AGENTS.md' -and $_ -ne 'd365bap.tools/tests/functions/AGENTS.md' } | Sort-Object -Unique)
	if ($dirty.Count -gt 0) {
		Write-Host 'Generated artifacts are out of sync. Do not edit them by hand.'
		Write-Host 'Push only sources; the regen workflow commits the rest to this PR automatically.'
		$dirty | ForEach-Object { Write-Host $_ }
		exit 1
	}

	Write-Host 'Generated artifacts are in sync.'
	exit 0
}
finally {
	Pop-Location
}
