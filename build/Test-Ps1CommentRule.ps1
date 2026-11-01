<#
.SYNOPSIS
    Tests the comment-based help only lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that only comment-based help and region
    markers are accepted. The rule covers module fragments and other scripts.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1CommentDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('comment-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Comment {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Get-Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1CommentDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$inline = @'
function Get-Fixture {
    $cache = 1 # fill the cache
}
'@
Assert-Comment 'Inline comment in a function' $inline 1 @('PSOnlyCommentBasedHelp', 'Remove this comment')

Assert-Comment 'Inline comment in an internal script' $inline -Directory 'd365bap.tools/internal' -Expected 1
Assert-Comment 'Inline comment outside the module' $inline -Directory 'build' -Expected 1
Assert-Comment 'Comment in a string is not a comment' @'
function Get-Fixture {
    $text = "# fill the cache"
}
'@

Assert-Comment 'Standalone line comment' @'
function Get-Fixture {
    # fill the cache
    $cache = 1
}
'@ 1

Assert-Comment 'Consecutive line comments are one group' @'
function Get-Fixture {
    # fill the cache
    # and keep it warm
    $cache = 1
}
'@ 1

Assert-Comment 'Plain block comment' @'
function Get-Fixture {
    <#
        fill the cache
    #>
    $cache = 1
}
'@ 1

Assert-Comment 'Function comment-based help' @'
function Get-Fixture {
    <#
        .SYNOPSIS
            Fills the cache.

        .EXAMPLE
            PS C:\> Get-Fixture

            Fills the cache.
    #>
    param ()

    $cache = 1
}
'@

Assert-Comment 'Script comment-based help' @'
<#
    .SYNOPSIS
        Fills the cache.

    .EXAMPLE
        PS C:\> ./Fill-Cache.ps1

        Fills the cache.
#>
$cache = 1
'@ -FileName 'Fill-Cache.ps1'

Assert-Comment 'Region markers' @'
function Get-Fixture {
    #region Fill
    $cache = 1
    #endregion Fill
}
'@

Assert-Comment 'Requires statement' @'
#requires -Version 7.6
function Get-Fixture {
    $cache = 1
}
'@

Assert-Comment 'Help and a stray comment' @'
<#
    .SYNOPSIS
        Fills the cache.

    .EXAMPLE
        PS C:\> Get-Fixture

        Fills the cache.
#>
function Get-Fixture {
    # fill the cache
    $cache = 1
}
'@ 1 @('PSOnlyCommentBasedHelp')

Assert-Comment 'Test files are exempt' $inline -FileName 'Get-Fixture.Tests.ps1'
Assert-Comment 'Test support files are exempt' $inline -FileName 'Help.Exceptions.ps1' -Directory 'd365bap.tools/tests/general'
Assert-Comment 'Tepp files are exempt' $inline -FileName 'example.tepp.ps1' -Directory 'd365bap.tools/internal/tepp'
Assert-Comment 'Tepp support files are exempt' $inline -FileName 'assignment.ps1' -Directory 'd365bap.tools/internal/tepp'

$script:caseCount++
Write-Output "Comment rule checks passed: $script:caseCount cases."
