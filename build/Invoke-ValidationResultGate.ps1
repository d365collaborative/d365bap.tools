<#
.SYNOPSIS
    Checks validation job results against the plan.

.DESCRIPTION
    Fails when a required job is skipped, missing, or failed, and when a job
    runs that the plan did not ask for. Test-PRValidationPlan.ps1 covers every
    accepted and rejected combination.
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
	[string] $Scope,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $PlanHash,
	# The selective and compiled jobs report these only when they run. Their
	# values are required and compared only when the matching plan flag is true.
	[string] $SelectiveHash,
	[string] $CompiledHash,
	[string] $SelectiveScope,
	[string] $CompiledScope,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $ModuleTests,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $AnalyzerScans,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $SelectiveTests,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $CompiledImport,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $InfrastructureChange,
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
if ($ChangeResult -ne 'success') { throw 'Change detection failed.' }
if ($PlanHash -notmatch '^[0-9A-F]{64}$') { throw 'Missing or invalid central validation plan hash.' }

$hashFlag = [ordered]@{
	ModuleTests          = $ModuleTests
	AnalyzerScans        = $AnalyzerScans
	SelectiveTests       = $SelectiveTests
	CompiledImport       = $CompiledImport
	InfrastructureChange = $InfrastructureChange
}
foreach ($itemName in $hashFlag.Keys) {
	if ($hashFlag[$itemName] -cnotin @('true', 'false')) { throw "Missing or invalid plan flag $itemName`: '$($hashFlag[$itemName])'." }
}
$runModuleTests = $ModuleTests -ceq 'true'
$runAnalyzerScans = $AnalyzerScans -ceq 'true'
$runSelectiveTests = $SelectiveTests -ceq 'true'
$runCompiledImport = $CompiledImport -ceq 'true'
$runInfrastructure = $InfrastructureChange -ceq 'true'

# The planner never emits a documentation scope with a partial job set: any
# change that is not documentation-only loads the module. An impossible
# combination fails closed instead of silently skipping a check.
if (-not $runCompiledImport -and ($runModuleTests -or $runAnalyzerScans -or $runSelectiveTests -or $runInfrastructure)) {
	throw "Impossible validation scope '$Scope': no compiled-import job with module, analyzer, selective, or infrastructure work."
}

# The jobs that recompute the plan must agree with the change-detection job.
# Their results are cross-checked above, so a skipped job cannot fake agreement.
if ($runSelectiveTests) {
	if ($SelectiveHash -cne $PlanHash) { throw 'Validation jobs produced different change plans (selective).' }
	if ($SelectiveScope -cne $Scope) { throw "Validation jobs disagreed on the scope: expected $Scope, got '$SelectiveScope' (selective)." }
}
if ($runCompiledImport) {
	if ($CompiledHash -cne $PlanHash) { throw 'Validation jobs produced different change plans (compiled).' }
	if ($CompiledScope -cne $Scope) { throw "Validation jobs disagreed on the scope: expected $Scope, got '$CompiledScope' (compiled)." }
}

$jobCheck = @(
	@{ Name = 'general-unit-tests'; Required = $runModuleTests; Actual = $General }
	@{ Name = 'public-functions-unit-tests'; Required = $runAnalyzerScans; Actual = $Public }
	@{ Name = 'internal-functions-unit-tests'; Required = $runAnalyzerScans; Actual = $Internal }
	@{ Name = 'selective-tests'; Required = $runSelectiveTests; Actual = $Selective }
	@{ Name = 'compiled-import'; Required = $runCompiledImport; Actual = $Compiled }
	@{ Name = 'infrastructure-tests'; Required = $runInfrastructure; Actual = $InfrastructureResult }
)
foreach ($job in $jobCheck) {
	$expected = if ($job.Required) { 'success' } else { 'skipped' }
	if ($job.Actual -cne $expected) {
		throw "Unexpected result for $($job.Name): expected $expected, got '$($job.Actual)' (scope $Scope)."
	}
}
Write-Host "Validation passed ($Scope)."
