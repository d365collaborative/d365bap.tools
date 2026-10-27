<#
    .SYNOPSIS
        Fails when a human touches generated artifacts.

    .DESCRIPTION
        Rejects generated-file changes in the final pull request diff.
        CI produces current artifacts after merge and runtime formats
        for package validation. Commit author names do not grant a bypass.

    .PARAMETER BaseRef
        The base ref of the commit range.

        Default: origin/main.

    .PARAMETER HeadRef
        The head ref of the commit range.

        Default: HEAD.

#>
[CmdletBinding()]
param(
	[string] $BaseRef = 'origin/main',
	[string] $HeadRef = 'HEAD'
)

$ErrorActionPreference = 'Stop'

$patterns = @(
	'^d365bap\.tools/tests/functions/.*\.Tests\.ps1$',
	'^docs/.*\.md$',
	'^d365bap\.tools/xml/d365bap\.tools\.(Table|List)\.Format\.ps1xml$',
	'^wiki/Namespaces\.md$'
)

$allowedGenerated = @(
	'^docs/AGENTS\.md$'
)

function Test-GeneratedFile {
	param([string] $File)
	foreach ($pattern in $patterns) {
		if ($File -notmatch $pattern) { continue }
		foreach ($allowed in $allowedGenerated) {
			if ($File -match $allowed) { return $false }
		}
		return $true
	}
	return $false
}

$changed = @(git diff --name-only --no-renames "$BaseRef...$HeadRef" -- d365bap.tools/tests/functions docs d365bap.tools/xml/d365bap.tools.Table.Format.ps1xml d365bap.tools/xml/d365bap.tools.List.Format.ps1xml wiki/Namespaces.md)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect generated files in the pull request diff.' }
if (@($changed | Where-Object { $_.StartsWith('"') }).Count -gt 0) { throw 'Unsupported quoted generated-file path.' }
$offenses = @($changed | Where-Object { Test-GeneratedFile $_ })

if ($offenses.Count -gt 0) {
	Write-Host 'Pull requests must not change generated files. Revert them and push only sources:'
	$offenses | ForEach-Object { Write-Host ("  $_") }
	Write-Host 'CI generates documentation and test snapshots after merge; runtime formats are generated for validation and release.'
	exit 1
}

Write-Host 'No generated files changed in the pull request diff.'
exit 0
