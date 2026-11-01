<#
.SYNOPSIS
    Tests the orphan PSFramework interrupt lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a process-block
    Test-PSFFunctionInterrupt has a preceding command that can interrupt the
    function. Empty begin blocks, assignment-only begin blocks, and earlier
    process assignments do not count.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1FunctionInterruptDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('function-interrupt-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Interrupt {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Set-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1FunctionInterruptDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-Interrupt 'Process check without a begin block' @'
function Set-Fixture {
    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('PSAvoidOrphanPSFFunctionInterruptCheck', 'no preceding command')

Assert-Interrupt 'Process check with an empty begin block' @'
function Set-Fixture {
    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('no preceding command')

Assert-Interrupt 'Process check after an assignment-only begin' @'
function Set-Fixture {
    begin {
        $config = @{ Key = 'Value' }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('no preceding command')

Assert-Interrupt 'Process check after a begin command' @'
function Set-Fixture {
    begin {
        $envObj = Get-Environment -EnvironmentId 'env-01'
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Process check after a begin Stop-PSFFunction' @'
function Set-Fixture {
    begin {
        Stop-PSFFunction -Message 'Stop'
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Process check after an earlier process command' @'
function Set-Fixture {
    process {
        $envObj = Get-Environment -EnvironmentId 'env-01'
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Process check after an earlier process assignment' @'
function Set-Fixture {
    process {
        $value = 1
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('no preceding command')

Assert-Interrupt 'Process check inside an if with a prior command' @'
function Set-Fixture {
    process {
        if (Get-Environment -EnvironmentId 'env-01') {
            if (Test-PSFFunctionInterrupt) { return }
        }
    }
}
'@

Assert-Interrupt 'Check in the begin block' @'
function Set-Fixture {
    begin {
        if (Test-PSFFunctionInterrupt) { return }
    }

    process {
        Get-Thing
    }
}
'@

Assert-Interrupt 'Check in the end block' @'
function Set-Fixture {
    process {
        Get-Thing
    }

    end {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Dynamic parameter command allows the check' @'
function Set-Fixture {
    dynamicparam {
        Get-Thing
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Module qualified command' @'
function Set-Fixture {
    process {
        if (PSFramework\Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('PSAvoidOrphanPSFFunctionInterruptCheck')

Assert-Interrupt 'Nested function without a begin block' @'
function Set-Fixture {
    process {
        function Test-Inner {
            process {
                if (Test-PSFFunctionInterrupt) { return }
            }
        }
    }
}
'@ 1 @('PSAvoidOrphanPSFFunctionInterruptCheck')

Assert-Interrupt 'Test files are exempt' @'
function Set-Fixture {
    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ -FileName 'Get-Ps1FunctionInterruptRule.Tests.ps1'

Assert-Interrupt 'Tepp files are exempt' @'
function Set-Fixture {
    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-Interrupt 'Outside the module' @'
function Set-Fixture {
    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ -Directory 'build'

$script:caseCount++
Write-Output "Function interrupt rule checks passed: $script:caseCount cases."
