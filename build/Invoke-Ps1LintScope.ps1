[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $BaseSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $HeadSha,
	[string] $RepositoryPath = (Join-Path $PSScriptRoot '..'),
	[string] $OutputPath,
	[switch] $RunAnalyzer
)

$ErrorActionPreference = 'Stop'

$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$scope = & (Join-Path $PSScriptRoot 'Get-Ps1LintScope.ps1') -BaseSha $BaseSha -HeadSha $HeadSha -RepositoryPath $repository -OutputPath $OutputPath

Write-Host "Changed PowerShell files: $(@($scope.Files | Where-Object { $_ -match '\.ps1$' }).Count)"
Write-Host "Dependency-affected files: $($scope.DependencyFiles.Count)"
Write-Host "Full custom-rule scan recommended: $($scope.FullScan)"

foreach ($itemReason in $scope.Reasons) {
	Write-Host "  $($itemReason.Kind): $($itemReason.Path) — $($itemReason.Reason)"
}

if ($scope.InvalidFormatFiles.Count -gt 0) {
	foreach ($itemError in $scope.InvalidFormatFiles) { Write-Host "  invalid format XML: $itemError" }
	throw "Malformed format XML changed in this pull request: $($scope.InvalidFormatFiles -join '; ')"
}

if ($scope.FullScan) {
	Write-Host 'A lint rule or its settings changed. Run the full custom-rule scan before review:'
	Write-Host '  prek run --all-files --stage manual --config prek.toml'
	exit 0
}

if (-not $RunAnalyzer -or $scope.DependencyFiles.Count -eq 0) { exit 0 }

$hook = Join-Path $PSScriptRoot 'ps1-lint/psscriptanalyzer/Run.ps1'
$colPaths = @($scope.DependencyFiles | ForEach-Object { Join-Path $repository $_ })
Write-Host "Reporting dependency-affected diagnostics for $($colPaths.Count) file(s). This report is non-blocking."

$output = @(& pwsh -NoProfile -NonInteractive -File $hook @colPaths 2>&1 | ForEach-Object { "$_" })
if ($output.Count -gt 0) { $output | Write-Host }

exit 0
