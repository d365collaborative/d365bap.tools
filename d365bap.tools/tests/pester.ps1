param (
	$TestGeneral = $true,

	$TestFunctions = $true,

	[ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
	[Alias('Show')]
	$Output = "None",

	$Include = "*",

	$Exclude = ""
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
$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true

if ($TestGeneral) {
	Write-PSFMessage -Level Important -Message "Modules imported, proceeding with general tests"
	foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1")) {
		if ($file.Name -notlike $Include) { continue }
		if ($file.Name -like $Exclude) { continue }

		Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
		$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).xml"
		$config.Run.Path = $file.FullName
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
		$results = Invoke-Pester -Configuration $config
		foreach ($result in $results) {
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			if ($result.Result -eq 'Failed') { $failedRuns++ }
			foreach ($failure in @($result.FailedContainers) + @($result.FailedBlocks)) {
				$testresults += [pscustomobject]@{
					Block   = $failure.Path -join '.'
					Name    = "$($failure.Name)"
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
}

$global:__pester_data.ScriptAnalyzer | Out-Host

if ($TestFunctions) {
	Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
	$files = @(Get-ChildItem "$PSScriptRoot\functions" -Recurse -File |
		Where-Object { $_.Name -like "*Tests.ps1" -and $_.Name -like $Include -and $_.Name -notlike $Exclude } |
		Sort-Object FullName)
	$batchSize = 20
	for ($offset = 0; $offset -lt $files.Count; $offset += $batchSize) {
		$last = [Math]::Min($offset + $batchSize - 1, $files.Count - 1)
		$batch = @($files[$offset..$last])
		$batchNumber = [int]($offset / $batchSize) + 1
		Write-PSFMessage -Level Significant -Message "  Executing function test batch $batchNumber ($($batch.Count) files)"
		$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" ("TEST-Functions-{0:D3}.xml" -f $batchNumber)
		$config.Run.Path = @($batch.FullName)
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
		$results = Invoke-Pester -Configuration $config
		foreach ($result in $results) {
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			if ($result.Result -eq 'Failed') { $failedRuns++ }
			foreach ($failure in @($result.FailedContainers) + @($result.FailedBlocks)) {
				$testresults += [pscustomobject]@{
					Block   = $failure.Path -join '.'
					Name    = "$($failure.Name)"
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
}

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($failedRuns -eq 0) { Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed; $failedRuns Pester run(s) reported failure." }

if ($failedRuns -gt 0) {
	throw "$totalFailed / $totalRun tests failed; $failedRuns Pester run(s) reported failure (including any container or block errors)."
}
