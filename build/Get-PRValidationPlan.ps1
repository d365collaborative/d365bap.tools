[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $BaseSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $HeadSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $OutputPath,
	[string] $RepositoryPath = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$changeSet = & (Join-Path $PSScriptRoot 'Get-Ps1LintScope.ps1') -BaseSha $BaseSha -HeadSha $HeadSha -RepositoryPath $repository -ChangesOnly
$mergeBase = $changeSet.MergeBase
$entries = @($changeSet.Changes)

# The change-aware regression suites in build/ (run by
# build/Invoke-InfrastructureValidation.ps1) exercise this tooling. A path that
# can change their behavior must start the infrastructure job. Keep the set
# explicit: Test-PRValidationPlan.ps1 pins each pattern in both directions, so a
# new suite input is added here deliberately instead of by accident.
$infrastructurePattern = @(
	'^build/ps1-lint(/|$)'
	'^build/Get-[^/]+\.ps1$'
	'^build/Invoke-[^/]+\.ps1$'
	'^build/Test-[^/]+\.ps1$'
	'^build/Install-RequiredModules\.ps1$'
	'^build/ModuleCacheRequirements\.json$'
	'^prek\.toml$'
	'^\.github/workflows/validate\.yml$'
)

function Test-Documentation([string] $Path) {
	if ([string]::IsNullOrEmpty($Path)) { $false; return }
	if ([IO.Path]::GetFileName($Path) -ieq 'AGENTS.md') { $false; return }
	$Path -ieq 'README.md' -or
	$Path -ieq 'd365bap.tools/readme.md' -or
	$Path -ieq 'd365bap.tools/changelog.md' -or
	$Path -match '^(docs|learning)/.+\.md$' -or
	$Path -match '^wiki/[^/]+\.md$'
}

$mode = 'docs'
$reasons = [System.Collections.Generic.List[string]]::new()
$publicPaths = [System.Collections.Generic.List[string]]::new()
$infrastructurePaths = [System.Collections.Generic.List[string]]::new()
if ($entries.Count -eq 0) { $mode = 'full'; $reasons.Add('No changed files were detected.') }
foreach ($entry in $entries) {
	# Both sides of a rename count: moving tooling out of build/ still changes it.
	foreach ($path in @($entry.Path) + @($entry.OldPath)) {
		if ([string]::IsNullOrEmpty($path)) { continue }
		foreach ($pattern in $infrastructurePattern) {
			if ($path -match $pattern) { $infrastructurePaths.Add($path); break }
		}
	}
	if ((Test-Documentation $entry.Path) -and ($null -eq $entry.OldPath -or (Test-Documentation $entry.OldPath))) { continue }
	if ($entry.Status -notin @('A', 'M') -or $entry.Path -cnotmatch '^d365bap\.tools/functions/[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*\.ps1$') {
		$mode = 'full'
		$reasons.Add("Shared, unknown, deleted, or renamed path: $($entry.Status) $($entry.Path)")
		continue
	}
	if (-not (Test-Path -LiteralPath (Join-Path $repository $entry.Path) -PathType Leaf)) {
		$mode = 'full'
		$reasons.Add("Missing changed source at checkout: $($entry.Path)")
		continue
	}
	if ($mode -eq 'docs') { $mode = 'selective' }
	$publicPaths.Add($entry.Path)
}
# No detected change means the diff could not be read, so run the suites rather
# than claim the tooling is untouched.
$infrastructureChange = $entries.Count -eq 0 -or $infrastructurePaths.Count -gt 0
$plan = [ordered]@{
	Mode                 = $mode
	InfrastructureChange = $infrastructureChange
	InfrastructurePaths  = @($infrastructurePaths | Sort-Object -Unique)
	PublicPaths          = @($publicPaths | Sort-Object -Unique)
	Reasons              = @($reasons)
	MergeBase            = $mergeBase
	HeadSha              = $HeadSha
}
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Validation mode: $mode ($($entries.Count) changed file(s))."
Write-Host "Infrastructure change: $infrastructureChange ($($infrastructurePaths.Count) matched path(s))."
foreach ($reason in $reasons) { Write-Host "  $reason" }
