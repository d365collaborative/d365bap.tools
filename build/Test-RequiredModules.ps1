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
}

function Set-PSRepository {
	[CmdletBinding()]
	param([string] $Name, [string] $InstallationPolicy)
	Assert-True ($Name -eq 'PSGallery' -and $InstallationPolicy -eq 'Trusted') 'Repository setup must trust PSGallery.'
	Add-Call 'SetRepository' $Name
}

function Install-Module {
	[CmdletBinding()]
	param([string] $Name, [string] $RequiredVersion, [string] $Scope, [switch] $Force, [switch] $SkipPublisherCheck)
	Assert-True ($state.pins.ContainsKey($Name) -and $RequiredVersion -ceq $state.pins[$Name]) "Incorrect pinned version for $Name`: $RequiredVersion"
	Assert-True ($Scope -eq 'CurrentUser' -and $Force -and $SkipPublisherCheck) "Incorrect installation options for $Name."
	Add-Call 'Install' $Name
}

function Initialize-Scenario($Modules) {
	$state.calls = [System.Collections.Generic.List[string]]::new()
	$state.present = @{}
	$state.pins = @{}
	$state.galleryExists = $true
	$state.failure = ''
	foreach ($entry in $Modules) {
		$state.pins[$entry.Name] = $entry.Version
		$state.present[$entry.Name] = $entry.Version
	}
}

function Assert-Call([string[]] $Expected, [string] $Context) {
	$actual = $state.calls -join ', '
	$expectedText = $Expected -join ', '
	Assert-True ($actual -ceq $expectedText) "$Context calls differ. Expected: $expectedText. Actual: $actual."
}

foreach ($set in @('base', 'generated')) {
	$modules = @($requirements.$set)
	Assert-True ($modules.Count -ge 3) "$set must contain at least three pins for these scenarios."

	Initialize-Scenario $modules
	& $installer -Set $set
	Assert-Call @($modules | ForEach-Object { "GetModule`:$($_.Name)" }) "$set complete cache hit"
	Write-Output "PASS: $set complete cache hit"

	foreach ($galleryExists in @($true, $false)) {
		Initialize-Scenario $modules
		$state.galleryExists = $galleryExists
		$first = $modules[1].Name
		$last = $modules[-1].Name
		$state.present.Remove($first)
		$state.present.Remove($last)
		& $installer -Set $set
		$expected = foreach ($entry in $modules) {
			"GetModule`:$($entry.Name)"
			if ($entry.Name -eq $first) {
				'GetRepository:PSGallery'
				if (-not $galleryExists) { 'RegisterRepository:' }
				'SetRepository:PSGallery'
			}
			if ($entry.Name -in @($first, $last)) { "Install`:$($entry.Name)" }
		}
		Assert-Call $expected "$set partial miss (gallery exists: $galleryExists)"
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
	$expected = @("GetModule`:$($modules[0].Name)", 'GetRepository:PSGallery', 'RegisterRepository:', 'SetRepository:PSGallery', "Install`:$($modules[0].Name)")
	$stop = @('GetModule', 'GetRepository', 'RegisterRepository', 'SetRepository', 'Install').IndexOf($failure)
	Assert-Call $expected[0..$stop] "$failure failure"
	Write-Output "PASS: $failure failure propagates"
}

Write-Output 'Required module regression checks passed.'
