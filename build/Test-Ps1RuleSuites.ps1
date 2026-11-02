<#
.SYNOPSIS
    Runs every PowerShell lint rule regression suite.

.DESCRIPTION
    Discovers the rule suites under build, checks them against the explicit
    registry, and runs each suite in a fresh pwsh process. A missing,
    unregistered, or failing suite fails the run, so nothing is skipped.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Keep this list in sync with build/Test-Ps1*Rule.ps1. A missing entry fails
# the run instead of dropping the suite from CI.
$expectedSuite = @(
	'Test-Ps1AccessTokenRule.ps1'
	'Test-Ps1AddMemberRule.ps1'
	'Test-Ps1CentralApiVersionRule.ps1'
	'Test-Ps1CommentRule.ps1'
	'Test-Ps1ComplexArrayElementRule.ps1'
	'Test-Ps1DirectParameterCheckRule.ps1'
	'Test-Ps1DirectStringCheckRule.ps1'
	'Test-Ps1EmptyAttributeRule.ps1'
	'Test-Ps1EmptyLineAfterContinuationRule.ps1'
	'Test-Ps1EnvironmentLookupRule.ps1'
	'Test-Ps1FormattedUrlRule.ps1'
	'Test-Ps1FunctionInterruptRule.ps1'
	'Test-Ps1HeadersVariableRule.ps1'
	'Test-Ps1LoopAppendRule.ps1'
	'Test-Ps1MandatoryRule.ps1'
	'Test-Ps1ModuleSplattingRule.ps1'
	'Test-Ps1MultilineIfConditionRule.ps1'
	'Test-Ps1MultilineIfExpressionRule.ps1'
	'Test-Ps1MultilineSelectObjectPropertyRule.ps1'
	'Test-Ps1NullComparisonRule.ps1'
	'Test-Ps1ObjectArrayCastRule.ps1'
	'Test-Ps1OneParameterPerLineRule.ps1'
	'Test-Ps1OrderedPSCustomObjectRule.ps1'
	'Test-Ps1OutNullRule.ps1'
	'Test-Ps1OutputTypeRule.ps1'
	'Test-Ps1ParameterArgumentRule.ps1'
	'Test-Ps1ParameterLayoutRule.ps1'
	'Test-Ps1ParameterPositionRule.ps1'
	'Test-Ps1PipelineContinuationRule.ps1'
	'Test-Ps1ReturnAfterStopRule.ps1'
	'Test-Ps1ReturnValueRule.ps1'
	'Test-Ps1SelectObjectPropertyRule.ps1'
	'Test-Ps1ShouldProcessRule.ps1'
	'Test-Ps1StandardExcelExportRule.ps1'
	'Test-Ps1StandardOutputRule.ps1'
	'Test-Ps1TernaryInObjectInitializationRule.ps1'
	'Test-Ps1ValidationAttributeOnMandatoryRule.ps1'
	'Test-Ps1VariableNamingRule.ps1'
	'Test-Ps1WildcardParameterAsFilterRule.ps1'
	'Test-Ps1WildcardRule.ps1'
)

$discovered = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-Ps1*Rule.ps1' -File |
	Sort-Object Name |
	ForEach-Object Name)

$missingSuite = @($expectedSuite | Where-Object { $_ -notin $discovered })
if ($missingSuite.Count -gt 0) {
	throw "Missing rule suite(s): $($missingSuite -join ', '). Restore the file or remove it from the registry."
}

$unregisteredSuite = @($discovered | Where-Object { $_ -notin $expectedSuite })
if ($unregisteredSuite.Count -gt 0) {
	throw "Unregistered rule suite(s): $($unregisteredSuite -join ', '). Add them to `$expectedSuite in $PSCommandPath."
}

$pwsh = (Get-Process -Id $PID).Path
$failedSuite = [System.Collections.Generic.List[string]]::new()

foreach ($itemSuite in $expectedSuite) {
	Write-Output "Running $itemSuite"
	& $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot $itemSuite)
	if ($LASTEXITCODE -ne 0) {
		$failedSuite.Add("$itemSuite (exit $LASTEXITCODE)")
	}
}

if ($failedSuite.Count -gt 0) {
	throw "Rule suite(s) failed: $($failedSuite -join ', ')."
}

Write-Output "Rule suite regression checks passed: $($expectedSuite.Count) suites."
