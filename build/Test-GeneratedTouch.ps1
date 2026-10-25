<#
    .SYNOPSIS
        Fails when the change touches generated artifacts.

    .DESCRIPTION
        Compares HEAD against a base ref and reports generated files. Those
        files are owned by the regen workflow.

    .PARAMETER BaseRef
        The base ref of the three-dot diff.

        Default: origin/main.

    .PARAMETER HeadRef
        The head ref of the three-dot diff.

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

$changed = @(git diff --name-only "$BaseRef...$HeadRef" --)
$touched = @(
	foreach ($file in $changed) {
		$isGenerated = $false
		foreach ($pattern in $patterns) {
			if ($file -match $pattern) { $isGenerated = $true; break }
		}
		if (-not $isGenerated) { continue }
		$isAllowed = $false
		foreach ($pattern in $allowedGenerated) {
			if ($file -match $pattern) { $isAllowed = $true; break }
		}
		if (-not $isAllowed) { $file }
	}
)

if ($touched.Count -gt 0) {
	Write-Host 'This PR touches generated files. Revert them and push only sources:'
	$touched | ForEach-Object { Write-Host "  $_" }
	Write-Host 'After review, label `accept-signature-change` and the regen workflow commits the regeneration.'
	exit 1
}

Write-Host 'No generated files touched.'
exit 0
