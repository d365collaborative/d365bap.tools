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
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1LoopAppendDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'loop-append-rule'
$script:caseCount = 0

function Assert-LoopAppend {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1LoopAppendDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
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

Assert-LoopAppend 'Computed source is outside the bounded copy shape' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @(Get-Thing)) {
        $colTarget.Add($item)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Set copy loop stays clean' @'
function Get-Fixture {
    $hashSeen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($item in $colSource) {
        $hashSeen.Add($item)
    }
    $hashSeen
}
'@

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

Assert-LoopAppend 'Lowercase member name is recognized' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $colSource) {
        $colTarget.add($item)
    }
    $colTarget
}
'@ -Expected 1

Assert-LoopAppend 'Two arguments' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($item in $colSource) {
        $colTarget.Add($item.Name, $item)
    }
    $colTarget
}
'@

Assert-LoopAppend 'Nested loops without adjacent constructor stay clean' @'
function Get-Fixture {
    $colTarget = [System.Collections.Generic.List[object]]::new()
    foreach ($itemOuter in $colSource) {
        foreach ($itemInner in $itemOuter.Children) {
            $colTarget.Add($itemInner)
        }
    }
    $colTarget
}
'@

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

Assert-LoopAppend 'Transformed argument' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in $s) { $x.Add($i.ToString()) } }'
Assert-LoopAppend 'Custom Add' 'function f { $x = [CustomCollection]::new(); foreach ($i in $s) { $x.Add($i) } }'
Assert-LoopAppend 'Parentheses' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in $s) { ($x.Add(($i))) } }' -Expected 1
Assert-LoopAppend 'ArrayList output' 'function f { $x = [System.Collections.ArrayList]::new(); foreach ($i in $s) { $x.Add($i) } }'
Assert-LoopAppend 'Custom receiver' 'function f { foreach ($i in $s) { $x.Add($i) } }'
Assert-LoopAppend 'Reassigned receiver' 'function f { $x = [Collections.Generic.List[object]]::new(); $x = $other; foreach ($i in $s) { $x.Add($i) } }'
$target = [Collections.Generic.List[object]]::new()
$target.Add('existing')
$identity = $target
$output = @($target.AddRange([object[]]@('a', 'b')))
if (-not [object]::ReferenceEquals($identity, $target) -or ($target -join ',') -ne 'existing,a,b' -or $output.Count -ne 0) { throw 'AddRange behavior changed' }
$array = [Collections.ArrayList]::new()
$output = @(foreach ($item in 'a', 'b') { $array.Add($item) })
if (($output -join ',') -ne '0,1') { throw 'ArrayList Add output changed' }

Assert-LoopAppend 'Trap is extra work' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in $s) { trap { continue }; $x.Add($i) } }'
Assert-LoopAppend 'Redirect is not transparent' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in $s) { ($x.Add($i) > $null) } }'
Assert-LoopAppend 'Source assignment can replace receiver' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in ($x = $other)) { $x.Add($i) } }'
Assert-LoopAppend 'Loop variable cannot replace receiver' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($x in $s) { $x.Add($x) } }'
Assert-LoopAppend 'Self-copy can change exception behavior' 'function f { $x = [Collections.Generic.List[object]]::new(); foreach ($i in $x) { $x.Add($i) } }'
Assert-LoopAppend 'Parenthesized constructor remains exact' 'function f { $x = ([Collections.Generic.List[object]]::new()); foreach ($i in ($s)) { ($x.add(($i))) } }' -Expected 1
$original = [Collections.Generic.List[object]]::new()
$original.Add('existing')
$source = [object[]]@('a', 'b')
$originalOutput = @(foreach ($entry in $source) { $original.Add($entry) })
if ($originalOutput.Count -ne 0 -or ($original -join ',') -ne ($target -join ',')) { throw 'Supported copy loop and AddRange must agree on contents and success output.' }

Write-Output "Loop append rule checks passed: $script:caseCount cases."
