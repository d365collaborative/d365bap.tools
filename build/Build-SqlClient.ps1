#Requires -Version 7.6
#Requires -PSEdition Core
<#
    .SYNOPSIS
        Builds and bundles the SQL client runtime.

    .DESCRIPTION
        Restores locked dependencies, builds the isolated loader, and packages runtime assets and license notices.
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$projectRoot = Join-Path $root 'library/SqlClient'
$project = Join-Path $projectRoot 'SqlClient.csproj'
dotnet restore $project --locked-mode --source https://api.nuget.org/v3/index.json --nologo
if ($LASTEXITCODE) { throw 'SQL client restore failed.' }
dotnet build $project -c Release --no-restore --nologo
if ($LASTEXITCODE) { throw 'SQL client build failed.' }

$output = Join-Path $projectRoot 'bin/Release/net10.0'
$destination = [IO.Path]::GetFullPath((Join-Path $root 'd365bap.tools/bin/SqlClient'))
if (Test-Path -LiteralPath $destination) {
	$resolved = (Resolve-Path -LiteralPath $destination).ProviderPath
	if ($resolved -ne $destination -or (Get-Item -LiteralPath $destination).LinkType) {
		throw 'Refusing to replace a SQL client bundle outside the expected directory.'
	}
	Remove-Item -LiteralPath $destination -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $destination -Force
foreach ($file in Get-ChildItem -LiteralPath $output -Recurse -File) {
	if ($file.Extension -notin @('.dll', '.json')) { continue }
	$target = Join-Path $destination ([IO.Path]::GetRelativePath($output, $file.FullName))
	$null = New-Item -ItemType Directory -Path (Split-Path $target) -Force
	Copy-Item -LiteralPath $file.FullName -Destination $target -Force
	if ($file.Extension -eq '.json') {
		[IO.File]::WriteAllText($target, ([IO.File]::ReadAllText($target).TrimEnd() + "`n"))
	}
}

$assets = Get-Content -LiteralPath (Join-Path $projectRoot 'obj/project.assets.json') -Raw | ConvertFrom-Json -AsHashtable
$packageRoot = @($assets.packageFolders.Keys)[0]
$notices = [Collections.Generic.List[string]]::new()
$licenses = [Collections.Generic.HashSet[string]]::new()
foreach ($entry in $assets.libraries.GetEnumerator() | Sort-Object Key) {
	if ($entry.Value.type -ne 'package') { continue }
	$package = Join-Path $packageRoot $entry.Value.path
	$nuspec = Get-ChildItem -LiteralPath $package -Filter '*.nuspec' -File
	$metadata = ([xml](Get-Content -LiteralPath $nuspec.FullName -Raw)).package.metadata
	if ($metadata.license.type -eq 'file') {
		$null = $licenses.Add([IO.File]::ReadAllText((Join-Path $package $metadata.license.InnerText)))
	}
	elseif ($metadata.license.type -ne 'expression' -or $metadata.license.InnerText -ne 'MIT') {
		throw "Review the license before bundling $($entry.Key)."
	}
	$notices.Add("$($entry.Key) | $($metadata.copyright) | $($metadata.license.InnerText) | https://www.nuget.org/packages/$($entry.Key)")
	foreach ($file in Get-ChildItem -LiteralPath $package -File | Where-Object Name -Match 'license|notice') {
		$null = $licenses.Add([IO.File]::ReadAllText($file.FullName))
	}
}
$notices.Add([IO.File]::ReadAllText((Join-Path $projectRoot 'MIT.txt')))
foreach ($license in $licenses) { $notices.Add($license) }
$noticeText = ($notices -join "`n`n") -replace '(?m)[ \t]+(?=\r?$)', ''
[IO.File]::WriteAllText((Join-Path $destination 'THIRD-PARTY-NOTICES.txt'), ($noticeText.TrimEnd() + "`n"))
