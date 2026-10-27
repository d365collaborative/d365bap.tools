[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Import-Module PSScriptAnalyzer -ErrorAction Stop
$root = Join-Path ([IO.Path]::GetTempPath()) ('changed-analyzer-' + [guid]::NewGuid().ToString('N'))
$module = Join-Path $root 'd365bap.tools'
$functions = Join-Path $module 'functions'
$plan = Join-Path $root 'plan.json'
$pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}
function Invoke-Fixture([object[]] $Paths) {
	@{ PublicPaths = $Paths } | ConvertTo-Json | Set-Content -LiteralPath $plan -Encoding utf8
	$output = @(& $pwsh -NoProfile -NonInteractive -File (Join-Path $root 'build/Invoke-ChangedScriptAnalyzer.ps1') -PlanPath $plan 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
	$null = New-Item -ItemType Directory -Path (Join-Path $root 'build'), $functions, (Join-Path $module 'tests/general') -Force
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-ChangedScriptAnalyzer.ps1') -Destination (Join-Path $root 'build')
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../d365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1') -Destination (Join-Path $module 'tests/general')
	Set-Content -LiteralPath (Join-Path $module 'd365bap.tools.psm1') -Value 'function Get-Fixture { }; Export-ModuleMember -Function Get-Fixture' -Encoding utf8
	New-ModuleManifest -Path (Join-Path $module 'd365bap.tools.psd1') -RootModule 'd365bap.tools.psm1' -ModuleVersion '1.0.0' -FunctionsToExport 'Get-Fixture'
	Set-Content -LiteralPath (Join-Path $functions 'Clean.ps1') -Value "Write-Output 'clean'" -Encoding utf8
	Set-Content -LiteralPath (Join-Path $functions 'Bad[1].ps1') -Value "Write-Host 'bad'" -Encoding utf8
	$clean = 'd365bap.tools/functions/Clean.ps1'
	$bad = 'd365bap.tools/functions/Bad[1].ps1'
	$run = Invoke-Fixture @($clean)
	Assert-True ($run.ExitCode -eq 0) "Clean selected source failed: $($run.Output)"
	$run = Invoke-Fixture @($clean, $bad)
	Assert-True ($run.ExitCode -ne 0 -and $run.Output -match 'PSAvoidUsingWriteHost') "Analyzer missed a selected source with wildcard characters: $($run.Output)"
	foreach ($paths in @(@(), @('d365bap.tools/functions/Missing.ps1'), @('../outside.ps1'), @($clean, $clean))) {
		$run = Invoke-Fixture $paths
		Assert-True ($run.ExitCode -ne 0) "Invalid source list unexpectedly succeeded: $($run.Output)"
	}
	Set-Content -LiteralPath (Join-Path $module 'tests/general/PSScriptAnalyzer.Tests.ps1') -Value "throw 'fixture discovery failure'" -Encoding utf8
	$run = Invoke-Fixture @($clean)
	Assert-True ($run.ExitCode -ne 0 -and $run.Output -match 'fixture discovery failure') "Discovery failure was not blocking: $($run.Output)"
	Write-Host 'Changed-file PSScriptAnalyzer regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
