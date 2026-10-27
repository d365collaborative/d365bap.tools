[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Import-Module PSScriptAnalyzer -ErrorAction Stop

$testFile = Join-Path $PSScriptRoot '../d365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("analyzer-consolidation-" + [guid]::NewGuid())

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Invoke-AnalyzerFixture([string] $Directory) {
	$global:__pester_data = @{}
	$config = [PesterConfiguration]::Default
	$config.Run.Container = New-PesterContainer -Path $testFile -Data @{ CommandPath = $Directory }
	$config.Run.PassThru = $true
	$config.Output.Verbosity = 'None'
	$result = Invoke-Pester -Configuration $config
	Assert-True ($result.FailedBlocksCount -eq 0) "Pester discovery or setup failed for $Directory"
	return $result
}

try {
	$cleanDir = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'clean') -Force
	$badDir = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'bad') -Force
	$excludedDir = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'excluded') -Force
	Set-Content -LiteralPath (Join-Path $cleanDir 'Clean.ps1') -Value "Write-Output 'clean'" -Encoding utf8
	Set-Content -LiteralPath (Join-Path $badDir 'Bad.ps1') -Value @'
Write-Host 'hello'
$password = ConvertTo-SecureString 'secret' -AsPlainText -Force
'@ -Encoding utf8
	$excludedSource = @'
function Get-Thing {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Output 'clean'
}
'@
	$excludedSource = $excludedSource.Replace("Write-Output 'clean'", "Write-Output 'clean'  ")
	Set-Content -LiteralPath (Join-Path $excludedDir 'Excluded.ps1') -Value $excludedSource -Encoding utf8

	$clean = Invoke-AnalyzerFixture $cleanDir.FullName
	Assert-True ($clean.TotalCount -eq 1 -and $clean.FailedCount -eq 0) 'A clean file must have one passing consolidated test.'
	Assert-True ($global:__pester_data.ScriptAnalyzer.Count -eq 0) 'A clean file must not collect diagnostics.'

	$badPath = Join-Path $badDir 'Bad.ps1'
	$ruleNames = @(Get-ScriptAnalyzerRule | ForEach-Object RuleName)
	$expected = @(Invoke-ScriptAnalyzer -Path $badPath -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess | Where-Object RuleName -In $ruleNames)
	Assert-True (@($expected | Where-Object Severity -eq 'Error').Count -gt 0) 'Fixture must contain an error.'
	Assert-True (@($expected | Where-Object Severity -eq 'Warning').Count -gt 0) 'Fixture must contain a warning.'
	$bad = Invoke-AnalyzerFixture $badDir.FullName
	Assert-True ($bad.TotalCount -eq 1 -and $bad.FailedCount -eq 1) 'A file with diagnostics must fail its consolidated test.'
	$actual = @($global:__pester_data.ScriptAnalyzer)
	Assert-True ($actual.Count -eq $expected.Count) 'Every reported diagnostic must be collected in global data.'
	$failureText = ($bad.Failed[0].ErrorRecord | ForEach-Object { $_.ToString() }) -join "`n"
	foreach ($diagnostic in $expected) {
		$match = @($actual | Where-Object { $_.RuleName -eq $diagnostic.RuleName -and $_.Line -eq $diagnostic.Line -and $_.Column -eq $diagnostic.Column })
		Assert-True ($match.Count -eq 1) "Missing diagnostic $($diagnostic.RuleName) at $($diagnostic.Line):$($diagnostic.Column)."
		Assert-True ($failureText.Contains($diagnostic.RuleName)) "Failure output must include $($diagnostic.RuleName)."
	}

	$excludedPath = Join-Path $excludedDir 'Excluded.ps1'
	$trailing = @(Invoke-ScriptAnalyzer -Path $excludedPath -IncludeRule PSAvoidTrailingWhitespace)
	Assert-True ($trailing.Count -gt 0) 'Excluded-rule fixture must contain trailing whitespace.'
	$shouldProcess = @(Invoke-ScriptAnalyzer -Path $excludedPath -IncludeRule PSShouldProcess)
	Assert-True ($shouldProcess.Count -gt 0) 'Excluded-rule fixture must contain a PSShouldProcess diagnostic.'
	$excluded = Invoke-AnalyzerFixture $excludedDir.FullName
	Assert-True ($excluded.FailedCount -eq 0) 'Excluded rules must not fail the consolidated test.'
	Assert-True ($global:__pester_data.ScriptAnalyzer.Count -eq 0) 'Excluded diagnostics must not be collected.'

	function global:Get-ScriptAnalyzerRule { }
	try {
		$config = [PesterConfiguration]::Default
		$config.Run.Container = New-PesterContainer -Path $testFile -Data @{ CommandPath = $badDir.FullName }
		$config.Run.PassThru = $true
		$config.Output.Verbosity = 'None'
		$result = Invoke-Pester -Configuration $config
		Assert-True ($result.Result -eq 'Failed') 'An empty analyzer rule list must fail discovery.'
		Assert-True (($result.FailedContainers.ErrorRecord | Out-String) -match 'returned no rules') 'Empty rule discovery must report its cause.'
	}
	finally {
		Remove-Item Function:global:Get-ScriptAnalyzerRule
	}

	Write-Host 'PSScriptAnalyzer consolidation regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
