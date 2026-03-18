<#
.SYNOPSIS
    Creates a new xppconfig.json from an existing downloaded D365 F&O platform version.

.DESCRIPTION
    Scans %LOCALAPPDATA%\Microsoft\Dynamics365\ for downloaded platform versions
    (folders matching the 10.*.*.* pattern), prompts you to pick one and provide
    a Cloud Instance URL, then auto-populates all other settings, creates the
    cross-reference database on LocalDB, and writes the config to the standard
    location (%LOCALAPPDATA%\Microsoft\Dynamics365\).

.PARAMETER CloudInstanceURL
    Optional. The cloud instance URL (e.g. https://yourtenant.operations.dynamics.com/).
    If omitted, the script will prompt for it.

.PARAMETER CustomMetadataFolder
    Optional. Path to the folder containing your custom X++ packages/models.
    Defaults to C:\Customizations if not specified.
    Added to ReferencePackagesPaths alongside the platform packages and used
    as the ModelStoreFolder and DebugSourceFolder.

.EXAMPLE
    .\New-D365DevConfig.ps1
    .\New-D365DevConfig.ps1 -CloudInstanceURL "https://myenv.operations.dynamics.com/"
    .\New-D365DevConfig.ps1 -CloudInstanceURL "https://myenv.operations.dynamics.com/" -CustomMetadataFolder "C:\MyModels"
	
.NOTES
	Author: Mike Caterino (@mikecaterino)
#>

param (
    [string]$CloudInstanceURL,
    [string]$CustomMetadataFolder = "C:\Customizations"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$baseDir      = "$env:LOCALAPPDATA\Microsoft\Dynamics365"
$localDbServer = "(LocalDB)\MSSQLLocalDB"
$dbServer      = "localhost"

# ---------------------------------------------------------------------------
# 1. Locate downloaded platform versions
# ---------------------------------------------------------------------------
if (-not (Test-Path $baseDir)) {
    Write-Error "Dynamics365 directory not found: $baseDir"
    exit 1
}

$platformVersions = @(Get-ChildItem -Path $baseDir -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.Name })

if ($platformVersions.Count -eq 0) {
    Write-Error "No platform versions found under $baseDir (expected folders matching 10.*.*.*). Please download a platform first."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Present selection menu
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Available platform versions:"
for ($i = 0; $i -lt $platformVersions.Count; $i++) {
    Write-Host "  [$($i + 1)] $($platformVersions[$i].Name)"
}

do {
    $raw = Read-Host "`nSelect a platform version (1-$($platformVersions.Count))"
    $idx = 0
    $valid = [int]::TryParse($raw, [ref]$idx) -and $idx -ge 1 -and $idx -le $platformVersions.Count
    if (-not $valid) { Write-Warning "Please enter a number between 1 and $($platformVersions.Count)." }
} while (-not $valid)

$selectedDir  = $platformVersions[$idx - 1].FullName
$selectedName = $platformVersions[$idx - 1].Name

Write-Host "  -> Selected: $selectedName"


# ---------------------------------------------------------------------------
# 4. Locate PackagesLocalDirectory inside the selected folder
# ---------------------------------------------------------------------------
$packagesLocal = Join-Path $selectedDir "PackagesLocalDirectory"
if (-not (Test-Path $packagesLocal)) {
    $packagesLocal = "C:\AOSService\PackagesLocalDirectory"
    Write-Warning "PackagesLocalDirectory not found under $selectedDir — defaulting to $packagesLocal"
}

# ---------------------------------------------------------------------------
# 5. Prompt for Cloud Instance URL
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($CloudInstanceURL)) {
    $CloudInstanceURL = Read-Host "`nEnter Cloud Instance URL (e.g. https://yourtenant.operations.dynamics.com/)"
}
if (-not $CloudInstanceURL.EndsWith("/")) { $CloudInstanceURL += "/" }

# ---------------------------------------------------------------------------
# 6. Derive names and output path
#    Registry shows VS stores configs in %LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\
#    with the filename pattern: <envname>___<version>.json (three underscores)
# ---------------------------------------------------------------------------
$envName        = ([System.Uri]$CloudInstanceURL).Host.Split('.')[0]
$versionNoDots  = $selectedName -replace '\.', ''
$businessDbName = "AXDBRAIN"
$crossRefDbName = "XRef_$envName$versionNoDots"
$xppConfigDir   = Join-Path $baseDir "XPPConfig"
$configName     = "${envName}___${selectedName}.json"
$outputPath     = Join-Path $xppConfigDir $configName

if (-not (Test-Path $xppConfigDir)) {
    New-Item -ItemType Directory -Path $xppConfigDir | Out-Null
}

# ---------------------------------------------------------------------------
# 7. Find an existing cross-reference database on the same platform version,
#    backup and restore it as the new database name.
#    Fails loudly if no matching source config or database is found.
# ---------------------------------------------------------------------------
Write-Host ""

# Find all config files for this platform version, excluding the file we are about to write
$matchingConfigs = @(
    Get-ChildItem -Path $xppConfigDir -Filter "*___${selectedName}.json" |
    Where-Object  { $_.Name -ne $configName } |
    Sort-Object   LastWriteTime -Descending
)

if ($matchingConfigs.Count -eq 0) {
    Write-Error "No existing configuration found for platform $selectedName under $xppConfigDir. A source configuration on the same platform version is required."
    exit 1
}

$sourceConfigFile = $matchingConfigs[0]
Write-Host "Source config  : $($sourceConfigFile.Name) (modified $($sourceConfigFile.LastWriteTime))"

$sourceConfig = Get-Content $sourceConfigFile.FullName -Raw | ConvertFrom-Json
$sourceDbName = $sourceConfig.CrossReferencesDatabaseName

if ([string]::IsNullOrWhiteSpace($sourceDbName)) {
    Write-Error "Source config '$($sourceConfigFile.Name)' does not specify a CrossReferencesDatabaseName."
    exit 1
}

Write-Host "Source XRef DB : $sourceDbName"

# Ensure LocalDB is running
Write-Host ""
Write-Host "Ensuring LocalDB instance is running..."

$sqlLocalDb = Get-Command SqlLocalDB -ErrorAction SilentlyContinue
if ($null -ne $sqlLocalDb) {
    $instanceInfo = & SqlLocalDB info MSSQLLocalDB 2>&1
    if ($instanceInfo -match "Stopped") {
        & SqlLocalDB start MSSQLLocalDB | Out-Null
        Write-Host "  LocalDB instance started."
    } else {
        Write-Host "  LocalDB instance is already running."
    }
} else {
    Write-Warning "SqlLocalDB.exe not found — assuming the instance is already running."
}

$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if ($null -eq $sqlcmd) {
    Write-Error "sqlcmd not found. Cannot restore cross-reference database."
    exit 1
}

# Verify the source database exists on LocalDB
$srcExists = (& sqlcmd -S $localDbServer -Q "SET NOCOUNT ON; SELECT COUNT(1) FROM sys.databases WHERE name = N'$sourceDbName'" -h -1 2>&1 |
    Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1).Trim()

if ($srcExists -ne "1") {
    Write-Error "Source database '$sourceDbName' was not found on $localDbServer. Ensure the source environment's cross-reference database is attached."
    exit 1
}

# Backup the source database to a temp file
$backupPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$sourceDbName.bak")
Write-Host "Backing up '$sourceDbName'..."
& sqlcmd -S $localDbServer -Q "BACKUP DATABASE [$sourceDbName] TO DISK = N'$backupPath' WITH FORMAT, INIT;" -b
if ($LASTEXITCODE -ne 0) {
    Write-Error "Backup of '$sourceDbName' failed (sqlcmd exit code $LASTEXITCODE)."
    exit 1
}

# Database files go in the XPPConfig subfolder for this config, matching where VS stores them
$dataPath = Join-Path $xppConfigDir ($configName -replace '\.json$', '')
if (-not (Test-Path $dataPath)) {
    New-Item -ItemType Directory -Path $dataPath | Out-Null
}

# Get logical file names from the backup
$fileListRaw = @(& sqlcmd -S $localDbServer -Q "RESTORE FILELISTONLY FROM DISK = N'$backupPath'" -s "|" -W -h -1 2>&1 |
    Where-Object { $_ -match '\|' })

$logicalData = ($fileListRaw | Where-Object { ($_ -split '\|')[2].Trim() -eq 'D' } | Select-Object -First 1).Split('|')[0].Trim()
$logicalLog  = ($fileListRaw | Where-Object { ($_ -split '\|')[2].Trim() -eq 'L' } | Select-Object -First 1).Split('|')[0].Trim()

if ([string]::IsNullOrEmpty($logicalData) -or [string]::IsNullOrEmpty($logicalLog)) {
    Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
    Write-Error "Could not determine logical file names from backup of '$sourceDbName'. Restore aborted."
    exit 1
}

# Restore as the new cross-reference database name
Write-Host "Restoring as '$crossRefDbName'..."

$restoreSql = @"
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'$crossRefDbName')
    DROP DATABASE [$crossRefDbName];
RESTORE DATABASE [$crossRefDbName]
FROM DISK = N'$backupPath'
WITH REPLACE,
     MOVE N'$logicalData' TO N'$dataPath\$crossRefDbName.mdf',
     MOVE N'$logicalLog'  TO N'$dataPath\${crossRefDbName}_log.ldf';
"@

$tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
[System.IO.File]::WriteAllText($tmpSql, $restoreSql, [System.Text.Encoding]::UTF8)

& sqlcmd -S $localDbServer -i $tmpSql -b
$restoreExit = $LASTEXITCODE

Remove-Item $tmpSql     -Force -ErrorAction SilentlyContinue
Remove-Item $backupPath -Force -ErrorAction SilentlyContinue

if ($restoreExit -ne 0) {
    Write-Error "Restore of '$crossRefDbName' failed (sqlcmd exit code $restoreExit)."
    exit 1
}

Write-Host "  Cross-reference database '$crossRefDbName' restored from '$sourceDbName'."

# ---------------------------------------------------------------------------
# 8. Build the config object
# ---------------------------------------------------------------------------
$config = [ordered]@{
    AdminIdentityProvider           = "https://sts.windows.net/"
    AosWebsiteName                  = "AOSService"
    ApplicationHostConfigFile       = "$packagesLocal\bin\applicationHost.config"
    AudienceUri                     = "spn:00000015-0000-0000-c000-000000000000"
    AzureAppID                      = ""
    AzureCR_Key                     = $null
    BusinessDatabaseName            = $businessDbName
    BusinessDatabasePassword        = ""
    BusinessDatabaseUserName        = ""
    CloudInstanceURL                = $CloudInstanceURL
    ContainerMemory                 = $null
    CrossReferencesDatabaseName     = $crossRefDbName
    CrossReferencesDbServerName     = $localDbServer
    DatabaseServer                  = $dbServer
    DebugSourceFolder               = $CustomMetadataFolder
    DefaultCompany                  = ""
    DefaultModelForNewProjects      = "FleetManagement"
    Description                     = "Unified development environment $envName. `r`nFinOps application version $selectedName. `r`nConfiguration generated on $(Get-Date -Format 'M/d/yyyy'). `r`nCross Reference DB Server $localDbServer. `r`nCross Reference DB Name $crossRefDbName."
    EnableOfflineAuthentication     = $true
    FrameworkDirectory              = $packagesLocal
    ModelStoreFolder                = $CustomMetadataFolder
    ModuleExclusionList             = $null
    OfflineAuthenticationAdminEmail = ""
    PartitionKey                    = "initial"
    ReferencePackagesPaths          = @($packagesLocal)
    RunBatchWithinAOS               = $null
    RuntimeHostType                 = 4
    RuntimePackagesDirectory        = $selectedDir
    WebRoleDeploymentFolder         = "C:\AOSService\webroot"
}

# ---------------------------------------------------------------------------
# 9. Write the JSON file
# ---------------------------------------------------------------------------
$json = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outputPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Configuration written to:"
Write-Host "  $outputPath"

# ---------------------------------------------------------------------------
# 10. Register the configuration in the VS registry so it appears in
#     Dynamics 365 > Options > Configure
# ---------------------------------------------------------------------------
$regKey = 'HKCU:\Software\Microsoft\Dynamics\AX7\Development\Configurations'
Set-ItemProperty -Path $regKey -Name 'CurrentMetadataConfig' -Value $outputPath   -Type String
Set-ItemProperty -Path $regKey -Name 'FrameworkDirectory'    -Value $packagesLocal -Type String
Write-Host "  Registry updated (CurrentMetadataConfig, FrameworkDirectory)"
Write-Host ""
Write-Host "Key settings:"
Write-Host "  RuntimePackagesDirectory    : $selectedDir"
Write-Host "  FrameworkDirectory          : $packagesLocal"
Write-Host "  CustomMetadataFolder        : $CustomMetadataFolder"
Write-Host "  BusinessDatabaseName        : $businessDbName @ $dbServer"
Write-Host "  CrossReferencesDatabaseName : $crossRefDbName @ $localDbServer"
Write-Host "  CloudInstanceURL            : $CloudInstanceURL"
Write-Host ""
Write-Host "Done. Open this config in Visual Studio: Dynamics 365 > Options > Configure."
