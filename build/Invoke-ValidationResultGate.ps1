<#
.SYNOPSIS
    Checks validation job results against the plan.

.DESCRIPTION
    Accepts only the job-result combinations the change plan can produce, so a
    skipped or missing infrastructure job fails while the infrastructure flag is
    true. Test-PRValidationPlan.ps1 covers each accepted and rejected combination.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Lint,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $ChangeResult,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Mode,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $InfrastructureChange,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $PlanHash,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $SelectiveHash,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $CompiledHash,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $SelectiveMode,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $CompiledMode,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $General,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Public,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Internal,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Selective,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $Compiled,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $InfrastructureResult
)

$ErrorActionPreference = 'Stop'

if ($Lint -ne 'success') { throw 'Lint or source-ownership checks failed.' }
if ($ChangeResult -ne 'success' -or $Mode -cnotin @('docs', 'selective', 'full')) { throw 'Change detection failed or returned an invalid mode.' }
if ($PlanHash -notmatch '^[0-9A-F]{64}$') { throw 'Missing or invalid central validation plan hash.' }
foreach ($reportedHash in @($SelectiveHash, $CompiledHash)) {
	if ($reportedHash -cne $PlanHash) { throw 'Validation jobs produced different change plans.' }
}
foreach ($reportedMode in @($SelectiveMode, $CompiledMode)) {
	if ($reportedMode -cne $Mode) { throw "Validation jobs disagreed on change scope: expected $Mode, got $reportedMode." }
}
if ($InfrastructureChange -cnotin @('true', 'false')) { throw "Missing or invalid infrastructure-change flag: '$InfrastructureChange'." }

$expected = switch ("$Mode|$InfrastructureChange") {
	'docs|false' { @('skipped', 'skipped', 'skipped', 'success', 'success', 'skipped') }
	'selective|false' { @('skipped', 'skipped', 'skipped', 'success', 'success', 'skipped') }
	'full|false' { @('success', 'success', 'success', 'success', 'success', 'skipped') }
	'full|true' { @('success', 'success', 'success', 'success', 'success', 'success') }
	default { throw "Unsupported validation combination: mode '$Mode', infrastructure change '$InfrastructureChange'." }
}

$jobName = @('general-unit-tests', 'public-functions-unit-tests', 'internal-functions-unit-tests', 'selective-tests', 'compiled-import', 'infrastructure-tests')
$actual = @($General, $Public, $Internal, $Selective, $Compiled, $InfrastructureResult)
for ($i = 0; $i -lt $expected.Count; $i++) {
	if ($actual[$i] -ne $expected[$i]) {
		throw "Unexpected result for $($jobName[$i]): expected $($expected[$i]), got $($actual[$i]) (mode $Mode, infrastructure change $InfrastructureChange)."
	}
}
Write-Host "Validation passed ($Mode, infrastructure change: $InfrastructureChange)."
