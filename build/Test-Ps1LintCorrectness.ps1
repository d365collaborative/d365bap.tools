[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-lint-correctness-' + [guid]::NewGuid().ToString('N'))
$hook = Join-Path $PSScriptRoot 'ps1-lint/psscriptanalyzer/Run.ps1'
$formatHook = Join-Path $PSScriptRoot 'ps1-lint/ps1-format/Run.ps1'
$readme = Join-Path $PSScriptRoot 'ps1-lint/README.md'
$pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Invoke-Hook([string] $Script, [string] $Path) {
	$output = @(& $pwsh -NoProfile -NonInteractive -File $Script $Path 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
	$null = New-Item -ItemType Directory -Path $root -Force

	# A syntax error must fail even though PSScriptAnalyzer's Error filter does not see it.
	$syntax = Join-Path $root 'Broken.ps1'
	Set-Content -LiteralPath $syntax -Value 'function Broken {'
	$run = Invoke-Hook $hook $syntax
	Assert-True ($run.ExitCode -ne 0) 'A parse error must fail the analyzer hook.'
	Assert-True ($run.Output -match 'PSParseError') 'A parse error must be reported as PSParseError.'

	# A valid standalone script must still pass.
	$clean = Join-Path $root 'Clean.ps1'
	Set-Content -LiteralPath $clean -Value "Write-Output 'clean'"
	$run = Invoke-Hook $hook $clean
	Assert-True ($run.ExitCode -eq 0) "A clean script must pass the analyzer hook: $($run.Output)"

	# Module and manifest syntax is covered without applying function conventions.
	foreach ($itemExtension in @('psm1', 'psd1')) {
		$broken = Join-Path $root "Broken.$itemExtension"
		Set-Content -LiteralPath $broken -Value 'function Broken {'
		$run = Invoke-Hook $hook $broken
		Assert-True ($run.ExitCode -ne 0) "A broken .$itemExtension file must fail the analyzer hook."
		Assert-True ($run.Output -match 'PSParseError') "A broken .$itemExtension file must report PSParseError."
	}

	$manifest = Join-Path $root 'Valid.psd1'
	Set-Content -LiteralPath $manifest -Value "@{ ModuleVersion = '1.0.0' }"
	$run = Invoke-Hook $hook $manifest
	Assert-True ($run.ExitCode -eq 0) "A valid manifest must pass the analyzer hook: $($run.Output)"

	# A formatter failure with unchanged content must fail the format hook.
	$readOnly = Join-Path $root 'ReadOnly.ps1'
	[System.IO.File]::WriteAllText($readOnly, "Write-Output 'clean'`n", [System.Text.UTF8Encoding]::new($false))
	$before = (Get-FileHash -LiteralPath $readOnly -Algorithm SHA256).Hash
	(Get-Item -LiteralPath $readOnly).IsReadOnly = $true
	$run = Invoke-Hook $formatHook $readOnly
	(Get-Item -LiteralPath $readOnly).IsReadOnly = $false
	$after = (Get-FileHash -LiteralPath $readOnly -Algorithm SHA256).Hash
	Assert-True ($run.ExitCode -ne 0) 'A formatter failure must fail the format hook.'
	Assert-True ($run.Output -match 'formatting failed') 'A formatter failure must be reported.'
	Assert-True ($before -eq $after) 'The formatter failure proof must leave the file unchanged.'

	# Missing formatter settings are a failure, not a silent warning.
	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1Format.ps1')
	$threw = $false
	try {
		Invoke-Ps1Format -Path $clean -SettingsPath (Join-Path $root 'missing.psd1')
	}
	catch {
		$threw = $true
		Assert-True ($_.Exception.Message -match 'Formatter settings not found') 'Missing formatter settings must report their cause.'
	}
	Assert-True $threw 'Missing formatter settings must throw.'

	# The hook dependency is pinned, not whatever happens to be installed.
	$hashSettings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1')
	Assert-True ($hashSettings.PSScriptAnalyzerVersion -eq '1.25.0') 'The analyzer settings must pin PSScriptAnalyzer 1.25.0.'
	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Ensure-PsScriptAnalyzer.ps1')
	Assert-True (Ensure-PsScriptAnalyzer) 'The setup hook default must make the pinned analyzer available.'
	$colInstalled = @(Get-Module -Name PSScriptAnalyzer -ListAvailable | Where-Object Version -EQ ([version] '1.25.0'))
	Assert-True ($colInstalled.Count -gt 0) 'The pinned PSScriptAnalyzer version must be installed.'

	# The documented semantics must match the rule messages.
	$readmeText = Get-Content -LiteralPath $readme -Raw
	Assert-True ($readmeText -match 'already rejects null and empty values') 'README must describe mandatory string binding accurately.'
	Assert-True ($readmeText -match 'emits one null item into the pipeline') 'README must describe the return $null difference accurately.'
	$contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Get-Ps1ParameterContractDiagnostic.ps1') -Raw
	Assert-True ($contract -match 'state the non-empty contract explicitly') 'The parameter contract message must describe the convention.'
	$returnRule = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Get-Ps1ReturnValueDiagnostic.ps1') -Raw
	Assert-True ($returnRule -match 'emit \$null explicitly') 'The return-value message must preserve the pipeline distinction.'

	Write-Host 'Lint correctness regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
