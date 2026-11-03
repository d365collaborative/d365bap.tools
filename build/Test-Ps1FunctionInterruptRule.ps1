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
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1FunctionInterruptDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'function-interrupt-rule'
$script:caseCount = 0

function Assert-Interrupt {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1FunctionInterruptDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
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

Assert-Interrupt 'Stop guard with return then check' @'
function Set-Fixture {
    process {
        $route = Get-Route
        if ($null -eq $route) {
            Write-PSFMessage -Message 'missing'
            Stop-PSFFunction -Message 'stop'
            return
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('preceding Stop-PSFFunction guard')

Assert-Interrupt 'Stop without return leaves the check valid' @'
function Set-Fixture {
    process {
        Stop-PSFFunction -Message 'stop'
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Direct StepsUpward targets the caller' @'
function Set-Fixture {
    process {
        Stop-PSFFunction -Message 'stop' -StepsUpward 1
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('preceding Stop-PSFFunction guard')

Assert-Interrupt 'StepsUpward zero leaves the check valid' @'
function Set-Fixture {
    process {
        Stop-PSFFunction -Message 'stop' -StepsUpward 0
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'EnableException stops the scope' @'
function Set-Fixture {
    process {
        Stop-PSFFunction -Message 'stop' -EnableException $true
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('preceding Stop-PSFFunction guard')

Assert-Interrupt 'EnableException false leaves the check valid' @'
function Set-Fixture {
    process {
        Stop-PSFFunction -Message 'stop' -EnableException $false
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Stop guard in a begin block is a different scope' @'
function Set-Fixture {
    begin {
        Stop-PSFFunction -Message 'stop'
        return
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Stop guard in a nested scriptblock is a different scope' @'
function Set-Fixture {
    process {
        $items | ForEach-Object {
            Stop-PSFFunction -Message 'stop'
            return
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@

Assert-Interrupt 'Stop guard in a try block returns before the check' @'
function Set-Fixture {
    process {
        try {
            Stop-PSFFunction -Message 'stop'
            return
        }
        catch {
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
}
'@ 1 @('preceding Stop-PSFFunction guard')

Assert-Interrupt 'Helper call in a guard is a potential interrupt source' @'
function Set-Fixture {
    process {
        if ($null -eq $route) {
            Invoke-StopHelper
            return
        }

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
