[CmdletBinding()]
param (
	[Parameter(Mandatory)]
	[string] $PlanPath
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$module = Join-Path $repo 'd365bap.tools'
$testRoot = Join-Path $module 'tests'
$functionRoot = [IO.Path]::GetFullPath((Join-Path $module 'functions'))
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
if ($null -eq $plan -or $null -eq $plan.PSObject.Properties['PublicPaths']) {
	throw 'Validation plan must contain PublicPaths.'
}
if ($plan.PublicPaths -isnot [array] -or $plan.PublicPaths.Count -eq 0) {
	throw 'PublicPaths must be a nonempty array for changed-file analysis.'
}

$paths = [System.Collections.Generic.List[string]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relative in $plan.PublicPaths) {
	if ($relative -isnot [string] -or [string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative)) {
		throw "Invalid relative source path: $relative"
	}
	$path = [IO.Path]::GetFullPath((Join-Path $repo $relative))
	$prefix = $functionRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
	if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($path) -ine '.ps1') {
		throw "Path is not a public PowerShell function: $relative"
	}
	$item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
	if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
		throw "Path must be a regular file: $relative"
	}
	if (-not $seen.Add($path)) { throw "Duplicate source path: $relative" }
	$paths.Add($path)
}

$global:testroot = $testRoot
$global:__pester_data = @{}
Remove-Module d365bap.tools -ErrorAction Ignore
Import-Module (Join-Path $module 'd365bap.tools.psd1') -ErrorAction Stop
Import-Module (Join-Path $module 'd365bap.tools.psm1') -Force -ErrorAction Stop
$repoModulePath = (Resolve-Path -LiteralPath (Join-Path $module 'd365bap.tools.psm1')).Path
Get-Module d365bap.tools | Where-Object Path -ne $repoModulePath | Remove-Module -Force -ErrorAction Ignore
if (@(Get-Module d365bap.tools).Count -ne 1) { throw 'Expected exactly one loaded d365bap.tools instance from this checkout.' }
Import-Module Pester -ErrorAction Stop
Import-Module PSScriptAnalyzer -ErrorAction Stop

$resultDir = Join-Path $repo 'TestResults'
$null = New-Item -ItemType Directory -Path $resultDir -Force
$config = [PesterConfiguration]::Default
$config.Run.Container = New-PesterContainer -Path (Join-Path $testRoot 'general/PSScriptAnalyzer.Tests.ps1') -Data @{ CommandPath = $paths.ToArray() }
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Normal'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $resultDir 'TEST-PSScriptAnalyzer.Changed.xml'
$result = Invoke-Pester -Configuration $config
$global:__pester_data.ScriptAnalyzer | Format-Table RuleName, Severity, ScriptName, Line, Column, Message -Wrap | Out-Host
if ($result.Result -ne 'Passed' -or $result.FailedCount -ne 0 -or $result.TotalCount -ne $paths.Count -or $result.PassedCount -ne $paths.Count) {
	throw "Changed-file analyzer failed or did not run every requested file: $($result.PassedCount) passed, $($result.TotalCount) discovered, $($paths.Count) requested; result $($result.Result)."
}
