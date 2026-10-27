[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('selective-validation-' + [guid]::NewGuid().ToString('N'))
$pwsh = (Get-Process -Id $PID).Path
function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Run-Plan($Plan) {
	$planFile = Join-Path $fixture 'plan.json'
	$Plan | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $planFile -Encoding utf8
	$output = @(& $pwsh -NoProfile -NonInteractive -File (Join-Path $fixture 'build/Invoke-SelectiveValidation.ps1') -PlanPath $planFile 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
try {
	foreach ($dir in @('build', 'd365bap.tools/functions', 'd365bap.tools/tests/functions', 'd365bap.tools/tests/general', 'd365bap.tools/en-us')) {
		$null = New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force
	}
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-SelectiveValidation.ps1') -Destination (Join-Path $fixture 'build')
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-SelectedStrings.ps1') -Destination (Join-Path $fixture 'build')
	$project = Join-Path $fixture 'd365bap.tools'
	Set-Content -LiteralPath (Join-Path $project 'd365bap.tools.psm1') -Value ((1..21 | ForEach-Object { 'function Case{0:D2} {{ param([string] $NewParameter) "ok" }}' -f $_ }) + 'Export-ModuleMember -Function Case*') -Encoding utf8
	New-ModuleManifest -Path (Join-Path $project 'd365bap.tools.psd1') -RootModule 'd365bap.tools.psm1' -ModuleVersion '1.0.0' -FunctionsToExport 'Case*'
	$helpFixture = @(
		'param([string[]] $CommandPath)',
		'Describe "Selected help" {',
		'    It "receives only the selected source" -TestCases @{ Paths = $CommandPath } {',
		'        $Paths.Count | Should -Be 21',
		'        $Paths[0] | Should -BeLike "*Case01.ps1"',
		'    }',
		'}'
	)
	Set-Content -LiteralPath (Join-Path $project 'tests/general/Help.Tests.ps1') -Value $helpFixture -Encoding utf8
	Set-Content -LiteralPath (Join-Path $project 'tests/general/Help.Exceptions.ps1') -Value '$global:FunctionHelpTestExceptions = @()' -Encoding utf8
	Set-Content -LiteralPath (Join-Path $project 'tests/general/strings.Exceptions.ps1') -Value '@{ NoTextNeeded = @("External.Exception") }' -Encoding utf8
	Set-Content -LiteralPath (Join-Path $project 'en-us/strings.psd1') -Value '@{ Resolved = "text"; Orphan = "unused" }' -Encoding utf8
	foreach ($name in @('Manifest', 'strings', 'FileIntegrity')) {
		Set-Content -LiteralPath (Join-Path $project "tests/general/$name.Tests.ps1") -Value "param([string[]] `$CommandPath); Describe '$name' { It 'runs' { 1 | Should -Be 1 } }" -Encoding utf8
	}
	for ($i = 1; $i -le 21; $i++) {
		$name = 'Case{0:D2}' -f $i
		Set-Content -LiteralPath (Join-Path $project "functions/$name.ps1") -Value "function $name { param([string] `$NewParameter) }" -Encoding utf8
	}
	Set-Content -LiteralPath (Join-Path $project 'tests/functions/Case01.Tests.ps1') -Value 'Describe "stale signature" { It "expects the old parameter" { (Get-Command Case01).Parameters.Keys | Should -Contain "OldParameter" } }' -Encoding utf8
	Set-Content -LiteralPath (Join-Path $fixture 'check-snapshot.ps1') -Value @(
		'Import-Module Pester',
		'Import-Module (Join-Path $PSScriptRoot "d365bap.tools/d365bap.tools.psd1")',
		'$c = [PesterConfiguration]::Default',
		'$c.Run.Path = Join-Path $PSScriptRoot "d365bap.tools/tests/functions/Case01.Tests.ps1"',
		'$c.Run.PassThru = $true',
		'$c.Output.Verbosity = "None"',
		'$r = Invoke-Pester -Configuration $c',
		'if ($r.FailedCount -ne 1) { throw "Fixture must have exactly one failing snapshot test" }'
	) -Encoding utf8
	& $pwsh -NoProfile -NonInteractive -File (Join-Path $fixture 'check-snapshot.ps1')
	Assert-True ($LASTEXITCODE -eq 0) 'Stale snapshot fixture did not demonstrate a signature mismatch.'
	$plan = @{ Mode = 'selective'; PublicPaths = @(1..21 | ForEach-Object { 'd365bap.tools/functions/Case{0:D2}.ps1' -f $_ }) }
	$run = Run-Plan $plan
	Assert-True ($run.ExitCode -eq 0) "Valid plan failed: $($run.Output)"
	foreach ($name in @('ChangedHelp', 'Changed-Manifest', 'Changed-FileIntegrity')) {
		Assert-True (Test-Path -LiteralPath (Join-Path $fixture "TestResults/TEST-$name.xml")) "Missing $name result"
	}
	Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixture 'TestResults/TEST-ChangedFunctions-001.xml'))) 'Generated snapshot tests ran.'
	Write-Host 'PASS: targeted help and invariant checks run without stale generated snapshots'
	$plan.PublicPaths = @('d365bap.tools/functions/Absent.ps1')
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'Missing source was accepted.'
	$plan.PublicPaths = @('../d365bap.tools/functions/Case01.ps1')
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'Traversal path was accepted.'
	Set-Content -LiteralPath (Join-Path $project 'functions/Unexported.ps1') -Value 'function Unexported {}' -Encoding utf8
	$plan.PublicPaths = @('d365bap.tools/functions/Unexported.ps1')
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'Unexported selected command was accepted.'
	$plan.PublicPaths = @()
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'Empty plan was accepted.'
	Write-Host 'PASS: missing, unsafe and empty plans fail closed'
	$plan.PublicPaths = @('d365bap.tools/functions/Case01.ps1')
	Set-Content -LiteralPath (Join-Path $project 'tests/general/Help.Tests.ps1') -Value "throw 'fixture discovery error'" -Encoding utf8
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'Pester discovery error was accepted.'
	Set-Content -LiteralPath (Join-Path $project 'tests/general/Help.Tests.ps1') -Value '# no tests' -Encoding utf8
	Assert-True ((Run-Plan $plan).ExitCode -ne 0) 'A zero-test run was accepted.'
	Write-Host 'PASS: discovery error and empty help checks fail closed'
	Set-Content -LiteralPath (Join-Path $project 'tests/general/Help.Exceptions.ps1') -Value '$global:FunctionHelpTestExceptions = @("Case01")' -Encoding utf8
	$run = Run-Plan $plan
	Assert-True ($run.ExitCode -eq 0) "Explicitly excepted help should allow zero tests: $($run.Output)"
	Write-Host 'PASS: explicitly excepted help may contain zero tests'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../d365bap.tools/tests/general/FileIntegrity.Tests.ps1'), (Join-Path $PSScriptRoot '../d365bap.tools/tests/general/FileIntegrity.Exceptions.ps1') -Destination (Join-Path $project 'tests/general') -Force
	Set-Content -LiteralPath (Join-Path $project 'functions/Case01.ps1') -Value 'function Case01 { param([string] $NewParameter) }' -Encoding utf8BOM
	Set-Content -LiteralPath (Join-Path $project 'functions/Case02.ps1') -Value 'Write-Host "bad unselected file"' -Encoding utf8BOM
	$run = Run-Plan $plan
	Assert-True ($run.ExitCode -eq 0) "Unselected integrity violation should not fail: $($run.Output)"
	Set-Content -LiteralPath (Join-Path $project 'functions/Case01.ps1') -Value 'Write-Host "bad selected file"' -Encoding utf8BOM
	$run = Run-Plan $plan
	Assert-True ($run.ExitCode -ne 0 -and $run.Output -match 'Write-Host') "Selected integrity violation was not detected: $($run.Output)"
	Write-Host 'PASS: real file integrity rules apply to selected files only'
}
finally {
	if (Test-Path -LiteralPath $fixture) {
		$resolved = (Resolve-Path -LiteralPath $fixture).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Validation fixture escaped the temporary directory.' }
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
