<#
    .SYNOPSIS
        Fails when a human touches generated artifacts.

    .DESCRIPTION
        Reports generated files changed by human commits. Commits authored
        by the regen bot are ignored. Generated files are owned by the
        regen workflow.

    .PARAMETER BaseRef
        The base ref of the commit range.

        Default: origin/main.

    .PARAMETER HeadRef
        The head ref of the commit range.

        Default: HEAD.

    .PARAMETER BotAuthor
        Authors treated as regeneration.

        Default: github-actions[bot], d365bap-regen[bot].
#>
[CmdletBinding()]
param(
	[string] $BaseRef = 'origin/main',
	[string] $HeadRef = 'HEAD',
	[string[]] $BotAuthor = @('github-actions[bot]', 'd365bap-regen[bot]')
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

$offenses = @(
	foreach ($line in @(git log --format='%H%x01%an%x01%s' --no-merges "$BaseRef..$HeadRef" -- d365bap.tools/tests/functions docs d365bap.tools/xml/d365bap.tools.Table.Format.ps1xml d365bap.tools/xml/d365bap.tools.List.Format.ps1xml wiki/Namespaces.md)) {
		$parts = $line -split [char]1
		if ($parts.Count -lt 3) { continue }
		if ($parts[1] -in $BotAuthor) { continue }
		$touched = @(git diff-tree --no-commit-id --name-only -r $parts[0] | Where-Object { Test-GeneratedFile $_ })
		if ($touched.Count -eq 0) { continue }
		[pscustomobject]@{
			Commit  = $parts[0].Substring(0, 7)
			Author  = $parts[1]
			Message = $parts[2]
			Files   = @($touched)
		}
	}
)

if ($offenses.Count -gt 0) {
	Write-Host 'Human commits must not touch generated files. Revert them and push only sources:'
	foreach ($offense in $offenses) {
		Write-Host ("  {0} {1} {2}" -f $offense.Commit, $offense.Author, $offense.Message)
		$offense.Files | ForEach-Object { Write-Host ("    $_") }
	}
	Write-Host 'The regen workflow commits the regeneration to this PR automatically.'
	exit 1
}

Write-Host 'No generated files touched by hand.'
exit 0
