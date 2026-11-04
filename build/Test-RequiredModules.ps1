[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'Install-RequiredModules.ps1'
$requirements = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ModuleCacheRequirements.json') -Raw | ConvertFrom-Json

$state = @{}

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Add-Call([string] $Operation, [string] $Name = '') {
	$state.calls.Add("$Operation`:$Name")
	if ($state.failure -eq $Operation) { throw "Injected $Operation failure" }
}

function Get-Module {
	[CmdletBinding()]
	param([switch] $ListAvailable, [string] $Name)
	Assert-True $ListAvailable 'Module lookup must use -ListAvailable.'
	Add-Call 'GetModule' $Name
	[pscustomobject]@{ Version = [version]'0.0.0.0' }
	if ($state.present.ContainsKey($Name)) {
		[pscustomobject]@{ Version = [version]$state.present[$Name] }
	}
}

function Get-PSRepository {
	[CmdletBinding()]
	param([string] $Name)
	Assert-True ($Name -eq 'PSGallery' -and $PSBoundParameters.ErrorAction -eq 'SilentlyContinue') 'Repository lookup must quietly target PSGallery.'
	Add-Call 'GetRepository' $Name
	if ($state.galleryExists) { [pscustomobject]@{ Name = 'PSGallery' } }
}

function Register-PSRepository {
	[CmdletBinding()]
	param([switch] $Default)
	Assert-True $Default 'Repository registration must use -Default.'
	Add-Call 'RegisterRepository'
	$state.galleryExists = $true
}

function Set-PSRepository {
	[CmdletBinding()]
	param([string] $Name, [string] $InstallationPolicy)
	Assert-True ($Name -eq 'PSGallery' -and $InstallationPolicy -eq 'Trusted') 'Repository setup must trust PSGallery.'
	Add-Call 'SetRepository' $Name
	Assert-True $state.galleryExists 'The gallery must exist before it can be configured.'
	$state.galleryTrusted = $true
}

function Install-Module {
	[CmdletBinding()]
	param([string] $Name, [string] $RequiredVersion, [string] $Scope, [switch] $Force, [switch] $SkipPublisherCheck)
	Assert-True ($state.pins.ContainsKey($Name) -and $RequiredVersion -ceq $state.pins[$Name]) "Incorrect pinned version for $Name`: $RequiredVersion"
	Assert-True ($Scope -eq 'CurrentUser' -and $Force -and $SkipPublisherCheck) "Incorrect installation options for $Name."
	Assert-True $state.galleryTrusted 'Installation must not require a gallery trust prompt.'
	Add-Call 'Install' $Name
	$state.present[$Name] = $RequiredVersion
}

function Initialize-Scenario($Modules) {
	$state.calls = [System.Collections.Generic.List[string]]::new()
	$state.present = @{}
	$state.pins = @{}
	$state.galleryExists = $true
	$state.galleryTrusted = $false
	$state.failure = ''
	foreach ($itemEntry in $Modules) {
		$state.pins[$itemEntry.Name] = $itemEntry.Version
		$state.present[$itemEntry.Name] = $itemEntry.Version
	}
}

function Assert-Installed([string[]] $Expected) {
	$colActual = @($state.calls | Where-Object { $_ -like 'Install:*' } | Sort-Object)
	$colExpectedCalls = @($Expected | ForEach-Object { "Install:$_" } | Sort-Object)
	Assert-True (($colActual -join ',') -ceq ($colExpectedCalls -join ',')) "Expected installs: $colExpectedCalls. Actual: $colActual."
	foreach ($itemName in $state.pins.Keys) {
		Assert-True ($state.present[$itemName] -eq $state.pins[$itemName]) "Missing pinned version of $itemName."
	}
}

foreach ($set in @('base', 'generated')) {
	$modules = @($requirements.$set)
	Assert-True ($modules.Count -ge 3) "$set must contain at least three pins for these scenarios."

	Initialize-Scenario $modules
	& $installer -Set $set
	Assert-Installed @()
	Assert-True (@($state.calls | Where-Object { $_ -notlike 'GetModule:*' }).Count -eq 0) 'A complete cache must not access the gallery.'
	Write-Output "PASS: $set complete cache hit"

	foreach ($galleryExists in @($true, $false)) {
		Initialize-Scenario $modules
		$state.galleryExists = $galleryExists
		$first = $modules[1].Name
		$last = $modules[-1].Name
		$state.present.Remove($first)
		$state.present.Remove($last)
		& $installer -Set $set
		Assert-Installed @($first, $last)
		Assert-True (@($state.calls | Where-Object { $_ -eq 'RegisterRepository:' }).Count -eq [int](-not $galleryExists)) 'Register the gallery only when it is missing.'
		Assert-True (@($state.calls | Where-Object { $_ -eq 'SetRepository:PSGallery' }).Count -eq 1) 'Configure the gallery once per installation run.'
		Write-Output "PASS: $set partial miss (gallery exists: $galleryExists)"
	}
}

# The lint set restores and installs only what the PowerShell lint hooks import.
$lintModules = @($requirements.lint)
$analyzerSettings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1')
Assert-True ($lintModules.Count -eq 1) 'The lint module set must hold exactly the module a lint run imports.'
Assert-True ($lintModules[0].Name -eq 'PSScriptAnalyzer') 'The lint module set must only contain PSScriptAnalyzer.'
Assert-True ("$($lintModules[0].Version)" -eq "$($analyzerSettings.PSScriptAnalyzerVersion)") 'The lint cache pin must match the analyzer import pin.'

Initialize-Scenario $lintModules
& $installer -Set lint
Assert-Installed @()
Write-Output 'PASS: lint complete cache hit'

Initialize-Scenario $lintModules
$state.present.Remove('PSScriptAnalyzer')
& $installer -Set lint
Assert-Installed @('PSScriptAnalyzer')
Write-Output 'PASS: lint cache miss installs only PSScriptAnalyzer'

$modules = @($requirements.base)
foreach ($failure in @('GetModule', 'GetRepository', 'RegisterRepository', 'SetRepository', 'Install')) {
	Initialize-Scenario $modules
	$state.present.Remove($modules[0].Name)
	$state.galleryExists = $false
	$state.failure = $failure
	$caught = $null
	try { & $installer -Set base }
	catch { $caught = $_ }
	Assert-True ($null -ne $caught -and $caught.Exception.Message -eq "Injected $failure failure") "$failure failure did not propagate."
	Assert-True ($state.calls[-1] -like "$failure`:*") "$failure failure must stop further operations."
	Write-Output "PASS: $failure failure propagates"
}

# Az.Accounts stays in the published RequiredModules for users, but CI uses a
# stub instead of caching/installing the real Azure module.
foreach ($set in @('base', 'generated', 'lint')) {
	$azPins = @($requirements.$set | Where-Object Name -EQ 'Az.Accounts')
	Assert-True ($azPins.Count -eq 0) "Module cache set '$set' must not pin Az.Accounts; CI registers build/ci-stubs instead."
}

$stubManifest = Join-Path $PSScriptRoot 'ci-stubs/Az.Accounts/99.0.0/Az.Accounts.psd1'
Assert-True (Test-Path -LiteralPath $stubManifest) 'The CI Az.Accounts stub manifest must exist.'

# Child process: this file mocks Get-Module/Install-Module in-process for installer
# scenarios, so stub discovery must run outside those doubles.
$stubProbe = Join-Path ([IO.Path]::GetTempPath()) ('bap-az-stub-' + [guid]::NewGuid().ToString('N') + '.ps1')
@'
param([string] $Installer, [string] $StubRoot)
$ErrorActionPreference = 'Stop'
& $Installer -Set base
if (-not ($env:PSModulePath.StartsWith($StubRoot + [IO.Path]::PathSeparator) -or $env:PSModulePath -eq $StubRoot)) {
	throw 'Install-RequiredModules -Set base must prepend the CI stub root to PSModulePath.'
}
$loaded = Get-Module -ListAvailable -Name Az.Accounts | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $loaded -or $loaded.Version -lt [version]'99.0.0') {
	throw 'The CI Az.Accounts stub must be discoverable at version 99.0.0 or newer.'
}
if ($loaded.Path -notmatch [regex]::Escape((Join-Path 'ci-stubs' 'Az.Accounts'))) {
	throw "ListAvailable must resolve the CI stub under build/ci-stubs; got $($loaded.Path)"
}
Write-Output 'PASS: CI Az.Accounts stub registered for base set'
'@ | Set-Content -LiteralPath $stubProbe -Encoding utf8
try {
	& pwsh -NoProfile -NonInteractive -File $stubProbe -Installer $installer -StubRoot (Join-Path $PSScriptRoot 'ci-stubs')
	if ($LASTEXITCODE -ne 0) { throw 'CI Az.Accounts stub registration probe failed.' }
}
finally {
	Remove-Item -LiteralPath $stubProbe -Force -ErrorAction SilentlyContinue
}

Write-Output 'Required module regression checks passed.'
