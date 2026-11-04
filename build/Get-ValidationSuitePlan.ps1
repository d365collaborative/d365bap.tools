<#
.SYNOPSIS
	Selects validation suites for a pull request diff.

.DESCRIPTION
	Keeps the validation-runners workflow filters intact, then picks only the
	suites whose subjects changed so unrelated suites stay idle.

.PARAMETER BaseSha
	The pull request base commit. Empty selects every suite.

.PARAMETER HeadSha
	The pull request head commit. Empty selects every suite.

.PARAMETER RepositoryPath
	The repository to inspect.

	Default: .

.PARAMETER OutputPath
	Optional JSON path for the selected suite plan.

.PARAMETER ForceAll
	Select every suite regardless of the diff.

.PARAMETER Path
	Changed paths to plan against instead of a git diff.
#>
[CmdletBinding()]
param(
	[string] $BaseSha,

	[string] $HeadSha,

	[string] $RepositoryPath = '.',

	[string] $OutputPath,

	[switch] $ForceAll,

	[string[]] $Path
)

$ErrorActionPreference = 'Stop'

# Path patterns that force the full suite list: the runner or its plan changed.
$script:ForceAllPattern = @(
	'^\.github/workflows/test-validation-runners\.yml$'
	'^build/Test-ValidationSuites\.ps1$'
	'^build/Get-ValidationSuitePlan\.ps1$'
	'^build/Test-Ps1RuleSuites\.ps1$'
)

# Suite -> subject paths. Keys are the suite inventory (single source).
# Keep patterns aligned with test-validation-runners.yml paths.
$script:SuitePattern = [ordered]@{
	'Test-PreloadExitCode.ps1'               = @(
		'^d365bap\.tools/internal/sdk/token-preload\.ps1$'
		'^d365bap\.tools/internal/sdk/finopsversion-preload\.ps1$'
		'^build/Test-PreloadExitCode\.ps1$'
	)
	'Test-ModulePublication.ps1'             = @(
		'^build/Publish-ModuleWithRetry\.ps1$'
		'^build/vsts-build\.ps1$'
		'^build/Test-ModulePublication\.ps1$'
	)
	'Test-Ps1ExampleHelp.ps1'                = @(
		'^build/ps1-lint/'
		'^build/Test-Ps1ExampleHelp\.ps1$'
	)
	'Test-Ps1RuleSuites.ps1'                 = @(
		'^build/ps1-lint/'
		'^build/Test-Ps1.+Rule\.ps1$'
		'^build/Test-Ps1RuleSuites\.ps1$'
	)
	'Test-RequiredModules.ps1'               = @(
		'^build/Install-RequiredModules\.ps1$'
		'^build/Install-Prek\.ps1$'
		'^build/ModuleCacheRequirements\.json$'
		'^build/ToolCacheRequirements\.json$'
		'^build/Test-RequiredModules\.ps1$'
	)
	'Test-PSScriptAnalyzerConsolidation.ps1' = @(
		'^d365bap\.tools/tests/pester-PSScriptAnalyzer\.ps1$'
		'^d365bap\.tools/tests/general/PSScriptAnalyzer\.Tests\.ps1$'
		'^build/Test-PSScriptAnalyzerConsolidation\.ps1$'
	)
	'Test-PesterRunners.ps1'                 = @(
		'^d365bap\.tools/tests/pester\.ps1$'
		'^d365bap\.tools/tests/pester-PSScriptAnalyzer\.ps1$'
		'^build/Test-PesterRunners\.ps1$'
	)
}
$script:AllSuite = @($script:SuitePattern.Keys)

function Get-ValidationSuiteChangedPath {
	param(
		[string] $Repository,
		[string] $Base,
		[string] $Head
	)

	foreach ($itemSha in @($Base, $Head)) {
		if ($itemSha -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') {
			throw "Invalid commit object ID: $itemSha"
		}
	}

	$mergeBase = (
		& git -C $Repository merge-base $Base $Head 2>$null |
		Select-Object -First 1
	)
	$diffFrom = $Base
	if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($mergeBase)) {
		$mergeBase = $mergeBase.Trim()
		$diffFrom = $mergeBase
	}
	else {
		$mergeBase = $null
		Write-Output "Validation suite plan: merge-base unavailable; diffing $Base...$Head."
	}

	$colPath = [System.Collections.Generic.List[string]]::new()
	# PowerShell captures git stdout as text. Avoid -z here: a NUL-separated
	# blob is not a Byte[] after & git, and GetString then fails.
	$colDiff = @(& git -C $Repository -c core.quotepath=false diff --name-only --find-renames $diffFrom $Head --)
	if ($LASTEXITCODE -ne 0) {
		throw 'Git diff failed while building the validation suite plan.'
	}
	foreach ($itemPath in $colDiff) {
		if ([string]::IsNullOrWhiteSpace($itemPath)) { continue }
		$colPath.Add(($itemPath -replace '\\', '/'))
	}

	[pscustomobject]@{
		MergeBase = $mergeBase
		Paths     = @($colPath.ToArray())
	}
}

function Test-ValidationSuitePathMatch {
	param(
		[string] $Path,
		[string[]] $Pattern
	)

	foreach ($itemPattern in $Pattern) {
		if ($Path -match $itemPattern) {
			$true
			return
		}
	}
	$false
}

$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$reason = [System.Collections.Generic.List[string]]::new()
$selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$mergeBase = $null

if ($ForceAll) {
	foreach ($itemSuite in $script:AllSuite) { $null = $selected.Add($itemSuite) }
	$reason.Add('Full suite list: ForceAll.')
	$colPath = @($Path | ForEach-Object { ($_ -replace '\\', '/') })
}
elseif ($null -ne $Path) {
	$colPath = @($Path | ForEach-Object { ($_ -replace '\\', '/') })
	$reason.Add('Suite list from explicit -Path input.')
}
elseif ([string]::IsNullOrWhiteSpace($BaseSha) -or [string]::IsNullOrWhiteSpace($HeadSha)) {
	foreach ($itemSuite in $script:AllSuite) { $null = $selected.Add($itemSuite) }
	$reason.Add('Full suite list: missing BaseSha/HeadSha.')
	$colPath = @()
}
else {
	$changeSet = Get-ValidationSuiteChangedPath -Repository $repository -Base $BaseSha -Head $HeadSha
	$colPath = @($changeSet.Paths)
	$mergeBase = $changeSet.MergeBase
}

if ($selected.Count -eq 0) {
	$forceAll = $false
	foreach ($itemPath in $colPath) {
		if (Test-ValidationSuitePathMatch -Path $itemPath -Pattern $script:ForceAllPattern) {
			$forceAll = $true
			$reason.Add("Full suite list: $itemPath changed.")
			break
		}
	}

	if ($forceAll) {
		foreach ($itemSuite in $script:AllSuite) { $null = $selected.Add($itemSuite) }
	}
	else {
		foreach ($itemSuite in $script:SuitePattern.Keys) {
			foreach ($itemPath in $colPath) {
				if (Test-ValidationSuitePathMatch -Path $itemPath -Pattern $script:SuitePattern[$itemSuite]) {
					$null = $selected.Add($itemSuite)
					$reason.Add("${itemSuite}: matched $itemPath")
					break
				}
			}
		}

		# A registered expected suite script edit selects itself even when the
		# subject-path map above did not list a broader pattern for it.
		foreach ($itemPath in $colPath) {
			if ($itemPath -notmatch '^build/(Test-.+\.ps1)$') { continue }
			$name = $Matches[1]
			if ($script:AllSuite -contains $name) {
				$null = $selected.Add($name)
				$reason.Add("${name}: suite script changed.")
			}
		}
	}
}

$ordered = @($script:AllSuite | Where-Object { $selected.Contains($_) })
$plan = [pscustomobject]@{
	BaseSha   = $BaseSha
	HeadSha   = $HeadSha
	MergeBase = $mergeBase
	Paths     = @($colPath)
	Suites    = $ordered
	AllSuites = @($script:AllSuite)
	Reasons   = @($reason)
}

if ($OutputPath) {
	$plan | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}

Write-Output ("Validation suite plan: {0} suite(s) for {1} changed path(s)." -f $ordered.Count, @($colPath).Count)
foreach ($itemSuite in $ordered) {
	Write-Output "  - $itemSuite"
}
if ($ordered.Count -eq 0) {
	Write-Output '  (no PowerShell validation suites selected for this diff)'
}

$plan
