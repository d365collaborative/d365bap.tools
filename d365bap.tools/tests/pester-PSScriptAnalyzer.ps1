param (
	$TestPublic = $true,

	$TestInternal = $true,

	[ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
	$Output = "None"
)

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module d365bap.tools -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\d365bap.tools.psd1"
Import-Module "$PSScriptRoot\..\d365bap.tools.psm1" -Force

$repoModulePath = (Resolve-Path "$PSScriptRoot\..\d365bap.tools.psm1").Path
Get-Module d365bap.tools | Where-Object Path -ne $repoModulePath | Remove-Module -Force -ErrorAction Ignore
if (@(Get-Module d365bap.tools).Count -ne 1) { throw "Expected exactly one loaded d365bap.tools instance (the checkout under test). Aborting test run." }

Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\..\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0
$failedRuns = 0

$testresults = @()
$file = Get-Item "$PSScriptRoot\general\PSScriptAnalyzer.Tests.ps1"
$config = [PesterConfiguration]::Default
$config.Run.PassThru = $true
$config.TestResult.Enabled = $true
$config.Output.Verbosity = $Output

if ($TestPublic) {
	Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c> (public functions)"
	$config.Run.Container = New-PesterContainer -Path $file.FullName -Data @{ CommandPath = "$PSScriptRoot\..\functions" }
	$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).Public.xml"
	$results = Invoke-Pester -Configuration $config
	$global:__pester_data.ScriptAnalyzer | Format-Table RuleName, Severity, ScriptName, Line, Column, Message -Wrap | Out-Host
	foreach ($result in $results) {
		$totalRun += $result.TotalCount
		$totalFailed += $result.FailedCount
		if ($result.Result -eq 'Failed') { $failedRuns++ }
		foreach ($failure in @($result.FailedContainers) + @($result.FailedBlocks)) {
			$testresults += [pscustomobject]@{
				Block   = $failure.Path -join '.'
				Name    = "$($failure.Item)"
				Result  = 'Failed'
				Message = $failure.ErrorRecord.DisplayErrorMessage
			}
		}
		$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
			$testresults += [pscustomobject]@{
				Block   = $_.Block
				Name    = "It $($_.Name)"
				Result  = $_.Result
				Message = $_.ErrorRecord.DisplayErrorMessage
			}
		}
	}
}

if ($TestInternal) {
	Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c> (internal functions)"
	$config.Run.Container = New-PesterContainer -Path $file.FullName -Data @{ CommandPath = "$PSScriptRoot\..\internal\functions" }
	$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).Internal.xml"
	$results = Invoke-Pester -Configuration $config
	$global:__pester_data.ScriptAnalyzer | Format-Table RuleName, Severity, ScriptName, Line, Column, Message -Wrap | Out-Host
	foreach ($result in $results) {
		$totalRun += $result.TotalCount
		$totalFailed += $result.FailedCount
		if ($result.Result -eq 'Failed') { $failedRuns++ }
		foreach ($failure in @($result.FailedContainers) + @($result.FailedBlocks)) {
			$testresults += [pscustomobject]@{
				Block   = $failure.Path -join '.'
				Name    = "$($failure.Item)"
				Result  = 'Failed'
				Message = $failure.ErrorRecord.DisplayErrorMessage
			}
		}
		$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
			$testresults += [pscustomobject]@{
				Block   = $_.Block
				Name    = "It $($_.Name)"
				Result  = $_.Result
				Message = $_.ErrorRecord.DisplayErrorMessage
			}
		}
	}
}

$testresults | Sort-Object Block, Name, Result, Message | Format-List

if ($failedRuns -eq 0) { Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed; $failedRuns Pester run(s) reported failure." }

if ($failedRuns -gt 0) {
	throw "$totalFailed / $totalRun tests failed; $failedRuns Pester run(s) reported failure (including any container or block errors)."
}
