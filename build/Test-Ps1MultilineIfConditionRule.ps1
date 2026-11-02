<#
.SYNOPSIS
    Tests the multiline if condition lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a compound if or elseif condition,
    or a compound Where-Object predicate, puts every test in parentheses on
    its own line. A single test stays clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1MultilineIfConditionDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('multiline-if-condition-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-MultilineIfCondition {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1MultilineIfConditionDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-MultilineIfCondition 'Compound condition on one line' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (-Not ($null -eq $objGroup) -and -not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)")) {
        $objGroup.DisplayName
    }
}
'@ -Expected 1 @('PSUseMultilineIfCondition', 'operator')

Assert-MultilineIfCondition 'Split condition without parentheses' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (-Not ($null -eq $objGroup) -and
        -not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)")) {
        $objGroup.DisplayName
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Parenthesized condition on one line' @'
function Get-Fixture {
    $objGroup = Get-Group
    if ((-Not ($null -eq $objGroup)) -and (-not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)"))) {
        $objGroup.DisplayName
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Operator at the end of the line' @'
function Get-Fixture {
    $colValue = @()
    if (($colValue.Count -gt 0) -and
        (($colValue[0] -eq 'a') -or
            ($colValue[0] -eq 'b'))) {
        $colValue[0]
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Split and parenthesized condition' @'
function Get-Fixture {
    $objGroup = Get-Group
    if ((-Not ($null -eq $objGroup)) `
    -and (-not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)"))) {
        $objGroup.DisplayName
    }
}
'@

Assert-MultilineIfCondition 'Condition inside the if parentheses' @'
function Get-Fixture {
    $colValue = @()
    if (
        ($colValue.Count -gt 0) `
    -and ($colValue[0])
    ) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Three tests on one line' @'
function Get-Fixture {
    $colValue = @()
    if (($null -eq $colValue) -and ($colValue.Count -gt 0) -and ($colValue[0])) {
        $colValue[0]
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Three split tests' @'
function Get-Fixture {
    $colValue = @()
    if (($null -eq $colValue) `
    -and ($colValue.Count -gt 0) `
    -and ($colValue[0])) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Or condition on one line' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) -or ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Split or condition' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) `
    -or ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@

Assert-MultilineIfCondition 'Nested or not split' @'
function Get-Fixture {
    $colValue = @()
    if (($colValue.Count -gt 0) -and
        ($colValue[0] -eq 'a' -or $colValue[0] -eq 'b')) {
        $colValue[0]
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Nested or split' @'
function Get-Fixture {
    $colValue = @()
    if (($colValue.Count -gt 0) `
    -and (($colValue[0] -eq 'a') `
    -or ($colValue[0] -eq 'b'))) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Elseif condition on one line' @'
function Get-Fixture {
    $Kind = 'A'
    if ($Kind -eq 'A') {
        'a'
    }
    elseif (($Kind -eq 'B') -and ($Kind -eq 'C')) {
        'b'
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Elseif condition split' @'
function Get-Fixture {
    $Kind = 'A'
    if ($Kind -eq 'A') {
        'a'
    }
    elseif (($Kind -eq 'B') `
    -and ($Kind -eq 'C')) {
        'b'
    }
}
'@

Assert-MultilineIfCondition 'Simple operands on one line' @'
function Get-Fixture {
    param(
        [switch] $Force,
        [switch] $Enabled
    )

    if ($Force -and $Enabled) {
        'forced'
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Simple operands split and parenthesized' @'
function Get-Fixture {
    param(
        [switch] $Force,
        [switch] $Enabled
    )

    if (($Force) `
    -and ($Enabled)) {
        'forced'
    }
}
'@

Assert-MultilineIfCondition 'Single test' @'
function Get-Fixture {
    param(
        [switch] $Force
    )

    if (-not $Force) { return }
    if ($Force) { 'forced' }
}
'@

Assert-MultilineIfCondition 'If expression condition' @'
function Get-Fixture {
    $objRoute = Get-Route
    $value = if (($null -eq $objRoute) -and ($objRoute.IsDefault)) { 'default' } else { 'custom' }
    $value
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object predicate on one line' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object { $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1 @('PSUseMultilineIfCondition', 'operator')

Assert-MultilineIfCondition 'Where-Object predicate split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        ($_.Count -gt 0) `
        -and ($_.Count -lt 10)
    }
}
'@

Assert-MultilineIfCondition 'Where-Object alias question mark' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | ? { $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object where alias' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | where { $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object qualified name' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Microsoft.PowerShell.Core\Where-Object { $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object FilterScript parameter' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object -FilterScript { $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object FilterScript split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object -FilterScript {
        ($_.Count -gt 0) `
        -and ($_.Count -lt 10)
    }
}
'@

Assert-MultilineIfCondition 'Where-Object FilterScript variable' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $sb = { $_.Count -gt 0 -and $_.Count -lt 10 }
    $colValue | Where-Object -FilterScript $sb
}
'@

Assert-MultilineIfCondition 'Where-Object FilterScript colon argument' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object -FilterScript:{ $_.Count -gt 0 -and $_.Count -lt 10 }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object simplified syntax' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object Name -eq 'abc'
}
'@

Assert-MultilineIfCondition 'Where-Object single test' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object { $_.Count -gt 0 }
}
'@

Assert-MultilineIfCondition 'Where-Object negated compound split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        -not (($_.Count -gt 0) `
            -and ($_.Count -lt 10))
    }
}
'@

Assert-MultilineIfCondition 'Where-Object negated compound on one line' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object { -not (($_.Count -gt 0) -and ($_.Count -lt 10)) }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object mixed operators split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        (($_.Count -gt 0) `
            -and ($_.Count -lt 10)) `
        -or ($_.Name)
    }
}
'@

Assert-MultilineIfCondition 'Where-Object nested operator not split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        (($_.Count -gt 0) -and ($_.Count -lt 10)) `
        -or ($_.Name)
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object operator at the end of the line' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        ($_.Count -gt 0) -and
        ($_.Count -lt 10)
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Where-Object three tests split' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        ($_.Count -gt 0) `
        -and ($_.Count -lt 10) `
        -and ($_.Name)
    }
}
'@

Assert-MultilineIfCondition 'Where-Object multi-statement predicate' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $colValue | Where-Object {
        $tmp = $_
        ($tmp.Count -gt 0) `
        -and ($tmp.Name)
    }
}
'@

Assert-MultilineIfCondition 'Where-Object inside an array subexpression' @'
function Get-Fixture {
    $colValue = @(1, 2, 3)
    $tmp = @($colValue | Where-Object { $_.Count -gt 0 -and $_.Count -lt 10 })
    $tmp
}
'@ -Expected 1

Assert-MultilineIfCondition 'Negated compound condition on one line' @'
function Get-Fixture {
    $colValue = @()
    if (-not (($colValue.Count -gt 0) -and ($colValue[0]))) {
        $colValue[0]
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Negated compound condition split' @'
function Get-Fixture {
    $colValue = @()
    if (-not (($colValue.Count -gt 0) `
        -and ($colValue[0]))) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Double negation split' @'
function Get-Fixture {
    $colValue = @()
    if (-not (-not (($colValue.Count -gt 0) `
        -and ($colValue[0])))) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Mixed operators preserve precedence split' @'
function Get-Fixture {
    $colValue = @()
    if ((($colValue.Count -gt 0) `
            -and ($colValue[0])) `
        -or ($colValue.Name)) {
        $colValue[0]
    }
}
'@

Assert-MultilineIfCondition 'Mixed operators need operand parentheses' @'
function Get-Fixture {
    $colValue = @()
    if (($colValue.Count -gt 0) `
        -and ($colValue[0]) `
        -or ($colValue.Name)) {
        $colValue[0]
    }
}
'@ -Expected 1

Assert-MultilineIfCondition 'Condition in a string' @'
function Get-Fixture {
    $text = 'if ($a -and $b) { }'
    $text
}
'@

Assert-MultilineIfCondition 'Internal module code is checked' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) -and ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-MultilineIfCondition 'Build scripts are exempt' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) -and ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@ -Directory 'build/scripts'

Assert-MultilineIfCondition 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) -and ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-MultilineIfCondition 'Test files are exempt' @'
function Get-Fixture {
    $objGroup = Get-Group
    if (($null -eq $objGroup) -and ($null -eq $objGroup.DisplayName)) {
        $objGroup
    }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Multiline if condition rule checks passed: $script:caseCount cases."
