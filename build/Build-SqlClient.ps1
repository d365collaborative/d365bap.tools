#Requires -Version 7.6
#Requires -PSEdition Core
<#
    .SYNOPSIS
        Bundles the current SQL client runtime dependencies.

    .DESCRIPTION
        Restores current stable packages in a temporary project and copies their runtime assets and notices. No module code is compiled.
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('bap-sqlclient-' + [guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $temporaryRoot > $null
try {
	$project = Join-Path $temporaryRoot 'SqlClient.Dependencies.csproj'
	@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <NuGetAuditMode>all</NuGetAuditMode>
    <WarningsAsErrors>NU1901;NU1902;NU1903;NU1904</WarningsAsErrors>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.SqlClient" Version="*" />
    <PackageReference Include="System.Security.Cryptography.Pkcs" Version="*" />
  </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath $project -Encoding utf8
	dotnet restore $project --source https://api.nuget.org/v3/index.json --nologo
	if ($LASTEXITCODE) { throw 'SQL client restore failed.' }

	$assets = Get-Content -LiteralPath (Join-Path $temporaryRoot 'obj/project.assets.json') -Raw | ConvertFrom-Json -AsHashtable
	$packageRoot = @($assets.packageFolders.Keys)[0]
	$destination = [IO.Path]::GetFullPath((Join-Path $root 'd365bap.tools/bin/SqlClient'))
	if (Test-Path -LiteralPath $destination) {
		$resolved = (Resolve-Path -LiteralPath $destination).ProviderPath
		if ($resolved -ne $destination -or (Get-Item -LiteralPath $destination).LinkType) {
			throw 'Refusing to replace a SQL client bundle outside the expected directory.'
		}
		Remove-Item -LiteralPath $destination -Recurse -Force
	}
	New-Item -ItemType Directory -Path $destination > $null
	foreach ($entry in $assets.targets['net10.0'].GetEnumerator()) {
		$package = Join-Path $packageRoot $assets.libraries[$entry.Key].path
		foreach ($assetGroup in @('runtime', 'runtimeTargets')) {
			foreach ($asset in $entry.Value[$assetGroup].Keys) {
				if (-not $asset.EndsWith('.dll')) { continue }
				$relativePath = if ($asset.StartsWith('runtimes/')) { $asset } else { [IO.Path]::GetFileName($asset) }
				if ($relativePath -eq 'Microsoft.Data.SqlClient.dll') { continue }
				$target = Join-Path $destination $relativePath
				New-Item -ItemType Directory -Path (Split-Path $target) -Force > $null
				Copy-Item -LiteralPath (Join-Path $package $asset) -Destination $target -Force
			}
		}
	}

	$notices = [Collections.Generic.List[string]]::new()
	$licenses = [Collections.Generic.HashSet[string]]::new()
	foreach ($entry in $assets.libraries.GetEnumerator() | Sort-Object Key) {
		if ($entry.Value.type -ne 'package') { continue }
		$package = Join-Path $packageRoot $entry.Value.path
		$nuspec = Get-ChildItem -LiteralPath $package -Filter '*.nuspec' -File
		$metadata = ([xml](Get-Content -LiteralPath $nuspec.FullName -Raw)).package.metadata
		if ($metadata.license.type -eq 'file') {
			$licenses.Add([IO.File]::ReadAllText((Join-Path $package $metadata.license.InnerText))) > $null
		}
		elseif ($metadata.license.type -ne 'expression' -or $metadata.license.InnerText -ne 'MIT') {
			throw "Review the license before bundling $($entry.Key)."
		}
		$notices.Add("$($entry.Key) | $($metadata.copyright) | $($metadata.license.InnerText) | https://www.nuget.org/packages/$($entry.Key)")
		foreach ($file in Get-ChildItem -LiteralPath $package -File | Where-Object Name -Match 'license|notice') {
			$licenses.Add([IO.File]::ReadAllText($file.FullName)) > $null
		}
	}
	$notices.Add([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SqlClient.MIT.txt')))
	foreach ($license in $licenses) { $notices.Add($license) }
	$noticeText = ($notices -join "`n`n") -replace '(?m)[ \t]+(?=\r?$)', ''
	[IO.File]::WriteAllText((Join-Path $destination 'THIRD-PARTY-NOTICES.txt'), ($noticeText.TrimEnd() + "`n"))
}
finally {
	$resolved = (Resolve-Path -LiteralPath $temporaryRoot).ProviderPath
	$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
	if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
		[IO.Path]::GetFileName($resolved) -notmatch '^bap-sqlclient-[0-9a-f]{32}$' -or
		(Get-Item -LiteralPath $resolved).LinkType) {
		throw 'Refusing to remove a path outside the expected temporary directory.'
	}
	Remove-Item -LiteralPath $resolved -Recurse -Force
}
