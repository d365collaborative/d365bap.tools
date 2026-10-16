#Requires -Version 7.6
#Requires -PSEdition Core
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$project = Join-Path $root 'library/PowerPlatformSdk/PowerPlatformSdk.csproj'
$projectData = [xml](Get-Content -LiteralPath $project -Raw)
$sdkVersion = ($projectData.Project.ItemGroup.PackageReference | Where-Object Include -EQ 'Microsoft.PowerPlatform.Management').Version
dotnet restore $project --source https://api.nuget.org/v3/index.json --nologo
if ($LASTEXITCODE) { throw 'Power Platform SDK restore failed.' }
dotnet build $project -c Release --no-restore --nologo
if ($LASTEXITCODE) { throw 'Power Platform SDK build failed.' }

$destination = Join-Path $root 'd365bap.tools/bin/PowerPlatformSdk'
$null = New-Item -ItemType Directory -Path $destination -Force
Copy-Item -Path "$root/library/PowerPlatformSdk/bin/Release/net10.0/*.dll" -Destination $destination -Force
Copy-Item -LiteralPath "$HOME/.nuget/packages/microsoft.powerplatform.management/$sdkVersion/License.md" -Destination $destination -Force

$mapping = Import-PowerShellDataFile "$root/d365bap.tools/internal/sdk/commands.psd1"
$exports = @(foreach ($resource in $mapping.Resources) {
    foreach ($verb in ($resource.Methods.Keys | Sort-Object)) { "$verb-$($resource.Noun)" }
})
$manifestPath = Join-Path $root 'd365bap.tools/d365bap.tools.psd1'
$manifest = [IO.File]::ReadAllText($manifestPath)
$exportText = ($exports | ForEach-Object { "`t`t, '$_'" }) -join "`r`n"
$replacement = "`t`t# BEGIN SDK EXPORTS`r`n$exportText`r`n`t`t# END SDK EXPORTS"
if ($manifest -notmatch '(?s)\t\t# BEGIN SDK EXPORTS.*?# END SDK EXPORTS') {
    throw 'The manifest SDK export markers are missing.'
}
$manifest = [regex]::Replace($manifest, '(?s)\t\t# BEGIN SDK EXPORTS.*?# END SDK EXPORTS', $replacement)
[IO.File]::WriteAllText($manifestPath, $manifest, [Text.UTF8Encoding]::new($true))
