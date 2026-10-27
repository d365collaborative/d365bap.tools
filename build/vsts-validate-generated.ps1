<#
    .SYNOPSIS
        Generates release documentation and test snapshots.

    .DESCRIPTION
        Intended for a disposable post-merge checkout. The tracked generated
        snapshots are not a freshness gate; outputs are published as artifacts.

    .PARAMETER RepoRoot
        Repository checkout to generate artifacts in.

        Default: the parent directory of this script.
#>
[CmdletBinding()]
param(
	[string] $RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

Push-Location $RepoRoot
try {
	& (Join-Path $RepoRoot 'build/Merge-FormatPs1Xml.ps1') -XmlRoot (Join-Path $RepoRoot 'd365bap.tools/xml')
	& (Join-Path $RepoRoot 'build/generate-parameterunittests.ps1')
	& (Join-Path $RepoRoot 'build/update-docs.ps1')
	Write-Host 'Generated formats, parameter tests, command docs and wiki namespaces.'
}
finally {
	Pop-Location
}
