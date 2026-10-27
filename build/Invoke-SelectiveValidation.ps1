[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string] $PlanPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path $repoRoot 'd365bap.tools/tests'
$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json -ErrorAction Stop
if ($plan.Mode -ne 'selective' -or $plan.PublicPaths -isnot [array]) {
	throw 'Expected a selective validation plan with a PublicPaths array.'
}

function Resolve-SelectedFiles([object[]] $Paths, [string] $Pattern) {
	$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	foreach ($path in $Paths) {
		if ($path -isnot [string] -or $path -notmatch $Pattern -or $path -match '(^|/)\.\.?(/|$)' -or $path.Contains('\')) {
			throw "Invalid selected path: $path"
		}
		$full = Join-Path $repoRoot $path
		if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Selected file is missing: $path" }
		if (-not $seen.Add($full)) { throw "Duplicate selected path: $path" }
		(Resolve-Path -LiteralPath $full).Path
	}
}
$publicPaths = @(Resolve-SelectedFiles @($plan.PublicPaths) '^d365bap\.tools/functions/(?:[^/]+/)*[^/]+\.ps1$')
if ($publicPaths.Count -eq 0) { throw 'Selective plan must select at least one public function.' }
$sourceNames = @($publicPaths | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } | Sort-Object)

$global:testroot = $testRoot
$global:__pester_data = @{}
Remove-Module d365bap.tools -ErrorAction Ignore
Import-Module (Join-Path $repoRoot 'd365bap.tools/d365bap.tools.psd1') -ErrorAction Stop
Import-Module (Join-Path $repoRoot 'd365bap.tools/d365bap.tools.psm1') -Force -ErrorAction Stop
$repoModulePath = (Resolve-Path (Join-Path $repoRoot 'd365bap.tools/d365bap.tools.psm1')).Path
Get-Module d365bap.tools | Where-Object Path -ne $repoModulePath | Remove-Module -Force -ErrorAction Ignore
if (@(Get-Module d365bap.tools).Count -ne 1) { throw 'Expected exactly one loaded checkout module. Aborting test run.' }
foreach ($name in $sourceNames) {
	if (-not (Get-Command -Name $name -Module d365bap.tools -CommandType Function -ErrorAction Ignore)) {
		throw "Selected public function was not exported by the checkout module: $name"
	}
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$resultDirectory = Join-Path $repoRoot 'TestResults'
$null = New-Item -Path $resultDirectory -ItemType Directory -Force
function Invoke-RequiredTests([string] $Name, [object] $Container, [switch] $AllowEmpty) {
	$config = [PesterConfiguration]::Default
	$config.Run.Container = @($Container)
	$config.Run.PassThru = $true
	$config.TestResult.Enabled = $true
	$config.TestResult.OutputPath = Join-Path $resultDirectory "TEST-$Name.xml"
	$config.Output.Verbosity = 'Normal'
	$result = Invoke-Pester -Configuration $config
	if ($null -eq $result -or $result.Result -ne 'Passed' -or (-not $AllowEmpty -and $result.PassedCount -eq 0) -or $result.FailedCount -gt 0 -or @($result.FailedContainers).Count -gt 0 -or @($result.FailedBlocks).Count -gt 0) {
		throw "Required test run '$Name' failed or discovered no tests."
	}
}

if ($publicPaths.Count -gt 0) {
	$helpTest = Join-Path $testRoot 'general/Help.Tests.ps1'
	. (Join-Path $testRoot 'general/Help.Exceptions.ps1')
	$helpRequired = @($sourceNames | Where-Object { $global:FunctionHelpTestExceptions -notcontains $_ })
	Invoke-RequiredTests 'ChangedHelp' (New-PesterContainer -Path $helpTest -Data @{ CommandPath = $publicPaths }) -AllowEmpty:($helpRequired.Count -eq 0)
}
Invoke-RequiredTests 'Changed-Manifest' (New-PesterContainer -Path (Join-Path $testRoot 'general/Manifest.Tests.ps1'))
& (Join-Path $PSScriptRoot 'Test-SelectedStrings.ps1') -ModuleRoot (Join-Path $repoRoot 'd365bap.tools') -CommandPath $publicPaths -ExceptionsFile (Join-Path $testRoot 'general/strings.Exceptions.ps1')
$integrityTest = Join-Path $testRoot 'general/FileIntegrity.Tests.ps1'
Invoke-RequiredTests 'Changed-FileIntegrity' (New-PesterContainer -Path $integrityTest -Data @{ CommandPath = $publicPaths })
