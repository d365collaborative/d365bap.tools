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

Write-Host "Touched PowerShell files: $($scope.Files.Count)"
Write-Host "Dependency-affected files (report only): $($scope.DependencyFiles.Count)"
Write-Host "Full custom-rule scan recommended: $($scope.FullScan)"

foreach ($itemReason in $scope.Reasons) {
	Write-Host "  $($itemReason.Kind): $($itemReason.Path) — $($itemReason.Reason)"
}

foreach ($itemDiagnostic in $scope.Diagnostics) {
	Write-Host "  $($itemDiagnostic.Kind): $($itemDiagnostic.Path) — $($itemDiagnostic.Message)"
}
if ($scope.Diagnostics.Count -gt 0) {
	$colDetail = @($scope.Diagnostics | ForEach-Object { "$($_.Path): $($_.Message)" })
	throw "Touched files changed in this pull request have blocking diagnostics: $($colDetail -join '; ')"
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
