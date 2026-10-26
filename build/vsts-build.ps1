<#
.SYNOPSIS
        Publishes the module to the gallery.

.DESCRIPTION
        Compiles the module from sources and uploads the package.

        Compilation steps can be inserted before publishing.

.PARAMETER Repository
        Target gallery repository.

        Default: PSGallery.
#>
param (
	$ApiKey,

	$WorkingDirectory,

	$Repository = 'PSGallery',

	[switch]
	$LocalRepo,

	[switch]
	$SkipPublish,

	[switch]
	$AutoVersion,

	[switch]
	$Build
)

if (-not $WorkingDirectory) {
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS) {
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }

if ($Build) {
	dotnet build "$WorkingDirectory\library\d365bap.tools.sln"
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to build d365bap.tools.dll!"
	}
}

& "$PSScriptRoot\Build-PowerPlatformSdk.ps1"
Write-PSFMessage -Level Important -Message "Creating and populating publishing directory"
$publishDir = New-Item -Path $WorkingDirectory -Name publish -ItemType Directory -Force
Copy-Item -Path "$($WorkingDirectory)\d365bap.tools" -Destination $publishDir.FullName -Recurse -Force

$text = @()
$processed = @()

foreach ($filePath in (& "$($PSScriptRoot)\..\d365bap.tools\internal\scripts\preimport.ps1")) {
	if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

	$item = Get-Item $filePath
	if ($item.PSIsContainer) { continue }
	if ($item.FullName -in $processed) { continue }
	$text += [System.IO.File]::ReadAllText($item.FullName)
	$processed += $item.FullName
}

Get-ChildItem -Path "$($publishDir.FullName)\d365bap.tools\internal\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}
Get-ChildItem -Path "$($publishDir.FullName)\d365bap.tools\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}

foreach ($filePath in (& "$($PSScriptRoot)\..\d365bap.tools\internal\scripts\postimport.ps1")) {
	if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

	$item = Get-Item $filePath
	if ($item.PSIsContainer) { continue }
	if ($item.FullName -in $processed) { continue }
	$text += [System.IO.File]::ReadAllText($item.FullName)
	$processed += $item.FullName
}

$fileData = Get-Content -Path "$($publishDir.FullName)\d365bap.tools\d365bap.tools.psm1" -Raw
$fileData = $fileData.Replace('"<was not compiled>"', '"<was compiled>"')
$fileData = $fileData.Replace('"<compile code into here>"', ($text -join "`n`n"))
[System.IO.File]::WriteAllText("$($publishDir.FullName)\d365bap.tools\d365bap.tools.psm1", $fileData, [System.Text.Encoding]::UTF8)

if ($AutoVersion) {
	Write-PSFMessage -Level Important -Message "Updating module version numbers."
	try { [version]$remoteVersion = (Find-Module 'd365bap.tools' -Repository $Repository -ErrorAction Stop).Version }
	catch {
		Stop-PSFFunction -Message "Failed to access $($Repository)" -EnableException $true -ErrorRecord $_
	}
	if (-not $remoteVersion) {
		Stop-PSFFunction -Message "Couldn't find d365bap.tools on repository $($Repository)" -EnableException $true
	}
	[version]$localVersion = (Import-PowerShellDataFile -Path "$($publishDir.FullName)\d365bap.tools\d365bap.tools.psd1").ModuleVersion
	if (($localVersion.Major -ne $remoteVersion.Major) -or ($localVersion.Minor -ne $remoteVersion.Minor)) {
		$localBuild = $localVersion.Build
		if ($localBuild -lt 0) { $localBuild = 0 }
		$newVersion = "$($localVersion.Major).$($localVersion.Minor).$localBuild"
		Write-PSFMessage -Level Important -Message "Major/Minor changed ($remoteVersion -> $newVersion), publishing repo version as-is."
	}
	else {
		$newBuildNumber = $remoteVersion.Build + 1
		$newVersion = "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
		Write-PSFMessage -Level Important -Message "Publishing auto-incremented version $newVersion."
	}
	Update-ModuleManifest -Path "$($publishDir.FullName)\d365bap.tools\d365bap.tools.psd1" -ModuleVersion $newVersion
}

if ($SkipPublish) { return }
if ($LocalRepo) {
	Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: PSFramework"
	New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath .
	Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: d365bap.tools"
	New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)\d365bap.tools" -PackagePath .
}
else {
	Write-PSFMessage -Level Important -Message "Publishing the d365bap.tools module to $($Repository)"
	Publish-Module -Path "$($publishDir.FullName)\d365bap.tools" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
