<#
    .SYNOPSIS
        Selects the files the pull request lint job must check.

    .DESCRIPTION
        Reuses the shared Get-Ps1LintScope.ps1 change parser instead of a second
        git diff. The plan separates files for the cheap hooks, the PowerShell
        hooks, and actionlint so CI can skip irrelevant setup.

    .PARAMETER BaseSha
        The pull request base commit.

    .PARAMETER HeadSha
        The pull request head commit.

    .PARAMETER OutputPath
        Writes the plan as JSON for the workflow steps that consume it.

    .PARAMETER RepositoryPath
        The repository to inspect.

        Default: the parent of this script's directory.
#>
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

$colPowerShell = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$colCheap = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$colWorkflows = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($itemChange in @($changeSet.Changes)) {
	$path = $itemChange.Path -replace '\\', '/'
	if ($itemChange.Status -match '^D') { continue }
	if (-not (Test-Path -LiteralPath (Join-Path $repository $path) -PathType Leaf)) { continue }

	# Every existing changed path is offered to the cheap hooks. prek applies
	# each hook's own glob and type filters, so a documentation file only runs
	# the whitespace checks and a JSON file also runs check-json.
	$null = $colCheap.Add($path)

	if ($path -match '\.(ps1|psm1|psd1)$') {
		$null = $colPowerShell.Add($path)
	}

	if ($path -match '^\.github/workflows/[^/]+\.ya?ml$') {
		$null = $colWorkflows.Add($path)
	}
}

$plan = [pscustomobject]@{
	BaseSha         = $BaseSha
	HeadSha         = $HeadSha
	MergeBase       = $changeSet.MergeBase
	PowerShellFiles = @($colPowerShell | Sort-Object)
	CheapFiles      = @($colCheap | Sort-Object)
	WorkflowFiles   = @($colWorkflows | Sort-Object)
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
	$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}

Write-Host "Changed files: $($plan.CheapFiles.Count)"
Write-Host "PowerShell hook files: $($plan.PowerShellFiles.Count)"
Write-Host "Workflow files: $($plan.WorkflowFiles.Count)"
$plan
