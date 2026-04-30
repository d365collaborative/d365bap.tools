param (
	$TestPublic = $true,

	$TestInternal = $true,

	[ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
	$Output = "None"
)

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

Remove-Module d365bap.tools -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\d365bap.tools.psd1"
Import-Module "$PSScriptRoot\..\d365bap.tools.psm1" -Force

Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\..\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()
$file = Get-Item "$PSScriptRoot\general\PSScriptAnalyzer.Tests.ps1"
$config = [PesterConfiguration]::Default
$config.Run.PassThru = $true
$config.TestResult.Enabled = $true
$config.Output.Verbosity = $Output

#region Run Public PSScriptAnalyzer Tests
if ($TestPublic) {
	Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c> (public functions)"
	$config.Run.Container = New-PesterContainer -Path $file.FullName -Data @{ CommandPath = "$PSScriptRoot\..\functions" }
	$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).Public.xml"
	$results = Invoke-Pester -Configuration $config
	foreach ($result in $results) {
		$totalRun += $result.TotalCount
		$totalFailed += $result.FailedCount
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
#endregion Run Public PSScriptAnalyzer Tests

#region Run Internal PSScriptAnalyzer Tests
if ($TestInternal) {
	Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c> (internal functions)"
	$config.Run.Container = New-PesterContainer -Path $file.FullName -Data @{ CommandPath = "$PSScriptRoot\..\internal\functions" }
	$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\TestResults" "TEST-$($file.BaseName).Internal.xml"
	$results = Invoke-Pester -Configuration $config
	foreach ($result in $results) {
		$totalRun += $result.TotalCount
		$totalFailed += $result.FailedCount
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
#endregion Run Internal PSScriptAnalyzer Tests

$testresults | Sort-Object Block, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed!" }

if ($totalFailed -gt 0) {
	throw "$totalFailed / $totalRun tests failed!"
}