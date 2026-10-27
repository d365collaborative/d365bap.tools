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
	foreach ($entry in $Modules) {
		$state.pins[$entry.Name] = $entry.Version
		$state.present[$entry.Name] = $entry.Version
	}
}

function Assert-Installed([string[]] $Expected) {
	$actual = @($state.calls | Where-Object { $_ -like 'Install:*' } | Sort-Object)
	$expectedCalls = @($Expected | ForEach-Object { "Install:$_" } | Sort-Object)
	Assert-True (($actual -join ',') -ceq ($expectedCalls -join ',')) "Expected installs: $expectedCalls. Actual: $actual."
	foreach ($name in $state.pins.Keys) {
		Assert-True ($state.present[$name] -eq $state.pins[$name]) "Missing pinned version of $name."
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

Write-Output 'Required module regression checks passed.'
