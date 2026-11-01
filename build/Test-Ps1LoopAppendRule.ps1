<#
.SYNOPSIS
    Tests the loop append lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a foreach whose only statement adds
    the loop variable is reported. Property appends, multi-statement bodies,
    other argument names, and other member calls stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1LoopAppendDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('loop-append-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-LoopAppend {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1LoopAppendDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-LoopAppend 'Copy loop' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@ -Expected 1 @('PSAvoidLoopAppend', 'AddRange')

Assert-LoopAppend 'Copy loop with a pipeline source' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @(Get-Thing)) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@ -Expected 1

Assert-LoopAppend 'Set copy loop still reports' @'
function Get-Fixture {
    $hashSeen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in $colSource) {
        $hashSeen.Add($item)
    }
    $hashSeen
}
'@ -Expected 1 @('UnionWith')

Assert-LoopAppend 'Property argument' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item.Name)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Different argument variable' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($other)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Second statement in the body' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item)
        $item.Seen = $true
    }
    $colTarget
}
'@

Assert-LoopAppend 'If in the body' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        if ($item.Enabled) {
            $colTarget.Add($item)
        }
    }
    $colTarget
}
'@

Assert-LoopAppend 'AddRange call' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    $colTarget.AddRange($colSource)
    $colTarget
}
'@

Assert-LoopAppend 'Lowercase member name is not the canonical Add' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.add($item)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Two arguments' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item.Name, $item)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Nested loops report the inner copy' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($itemOuter in $colSource) {
        foreach ($itemInner in $itemOuter.Children) {
            $colTarget.Add($itemInner)
        }
    }
    $colTarget
}
'@ -Expected 1

Assert-LoopAppend 'One-line copy loop' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) { $colTarget.Add($item) }
    $colTarget
}
'@ -Expected 1

Assert-LoopAppend 'Blank lines and comments in the body' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {

        # copy the item
        $colTarget.Add(
            $item
        )

    }
    $colTarget
}
'@ -Expected 1

Assert-LoopAppend 'Internal module code is checked' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-LoopAppend 'Build scripts are exempt' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@ -Directory 'build'

Assert-LoopAppend 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@ -Directory 'd365bap.tools/internal/tepp'

Write-Output "Loop append rule checks passed: $script:caseCount cases."
