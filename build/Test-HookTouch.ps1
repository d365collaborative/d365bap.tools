<#
.SYNOPSIS
    Fails when a human touches lint hook internals.

.DESCRIPTION
    Reports hook scripts changed by human commits. Hook scripts implement
    the repository lint rules and must stay trustworthy.

    Coordinate changes with maintainers before modifying these files.

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
	'^build/ps1-lint/internal/.*$'
)

function Test-HookFile {
	param([string] $File)
	foreach ($pattern in $patterns) {
		if ($File -notmatch $pattern) { continue }
		return $true
	}
	return $false
}

$offenses = @(
	foreach ($line in @(git log --format='%H%x01%an%x01%s' --no-merges "$BaseRef..$HeadRef" -- build/ps1-lint/internal)) {
		$parts = $line -split [char]1
		if ($parts.Count -lt 3) { continue }
		$touched = @(git diff-tree --no-commit-id --name-only -r $parts[0] | Where-Object { Test-HookFile $_ })
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
	Write-Host 'Human commits must not touch lint hook internals. Coordinate changes with maintainers:'
	foreach ($offense in $offenses) {
		Write-Host ("  {0} {1} {2}" -f $offense.Commit, $offense.Author, $offense.Message)
		$offense.Files | ForEach-Object { Write-Host ("    $_") }
	}
	exit 1
}

Write-Host 'No lint hook internals touched by hand.'
exit 0
