
<#
    .SYNOPSIS
        Creates a new xppconfig.json from an existing downloaded D365 F&O platform version.

    .DESCRIPTION
        Scans %LOCALAPPDATA%\Microsoft\Dynamics365\ for downloaded platform versions
        (folders matching the 10.*.*.* pattern), prompts you to pick one and provide
        a Environment URL, then auto-populates all other settings, creates the
        cross-reference database on LocalDB, and writes the config to the standard
        location (%LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\).

    .PARAMETER PlatformVersion
        Optional. The platform version to target (e.g. 10.0.44.12345).
        Must match the 10.*.*.* pattern and correspond to a downloaded folder under %LOCALAPPDATA%\Microsoft\Dynamics365\.
        If omitted, the cmdlet will present a menu of available versions to choose from.

    .PARAMETER EnvironmentURL
        Optional. The environment URL (e.g. https://myenv.operations.dynamics.com/).
        If omitted, the cmdlet will prompt for it.

    .PARAMETER CustomMetadataFolder
        Optional. Path to the folder containing your custom X++ packages/models.
        Defaults to C:\Customizations if not specified.
        Used as the ModelStoreFolder and DebugSourceFolder.

    .EXAMPLE
        PS C:\> New-D365DevConfig

        Prompts for platform version selection and environment URL, then creates the config.

    .EXAMPLE
        PS C:\> New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/"

        Prompts for platform version selection only; uses the supplied Environment URL.

    .EXAMPLE
        PS C:\> New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/" -PlatformVersion "10.0.44.12345"

        Skips the selection menu entirely; uses the supplied platform version and Environment URL.

    .EXAMPLE
        PS C:\> New-D365DevConfig -EnvironmentURL "https://myenv.operations.dynamics.com/" -CustomMetadataFolder "C:\MyModels"

        Uses the supplied environment URL and custom metadata folder path.

    .NOTES
        Author: Mike Caterino (@mikecaterino)
#>
function New-D365DevConfig {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [string] $EnvironmentURL,

        [ValidatePattern('^10\.\d+\.\d+\.\d+$')]
        [string] $PlatformVersion,

        [string] $CustomMetadataFolder = "C:\Customizations"
    )

    begin {
        $baseDir       = "$env:LOCALAPPDATA\Microsoft\Dynamics365"
        $localDbServer = "(LocalDB)\MSSQLLocalDB"
        $dbServer      = "localhost"

        # ---------------------------------------------------------------------------
        # 1. Locate downloaded platform versions
        # ---------------------------------------------------------------------------
        if (-not (Test-Path $baseDir)) {
            $messageString = "Dynamics365 directory not found: $baseDir"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the Dynamics365 base directory was not found." -Exception $([System.Exception]::new($messageString))
            return
        }

        # ---------------------------------------------------------------------------
        # 2. Resolve the selected platform version
        # ---------------------------------------------------------------------------
        if ($PlatformVersion) {
            $selectedDir = Join-Path $baseDir $PlatformVersion

            if (-not (Test-Path $selectedDir)) {
                $messageString = "Platform version folder not found: $selectedDir. Ensure version $PlatformVersion has been downloaded."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because the specified platform version folder was not found." -Exception $([System.Exception]::new($messageString))
                return
            }

            $selectedName = $PlatformVersion
            Write-PSFMessage -Level Host -Message "  -> Selected: $selectedName"
        }
        else {
            $platformVersions = @(
                Get-ChildItem -Path $baseDir -Directory |
                Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
                Sort-Object { [version]$_.Name }
            )

            if ($platformVersions.Count -eq 0) {
                $messageString = "No platform versions found under $baseDir (expected folders matching 10.*.*.*). Please download a platform first."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because no platform versions were found." -Exception $([System.Exception]::new($messageString))
                return
            }

            Write-PSFMessage -Level Host -Message "Available platform versions:"
            for ($i = 0; $i -lt $platformVersions.Count; $i++) {
                Write-PSFMessage -Level Host -Message "  [$($i + 1)] $($platformVersions[$i].Name)"
            }

            do {
                $raw = Read-Host "`nSelect a platform version (1-$($platformVersions.Count))"
                $idx = 0
                $valid = [int]::TryParse($raw, [ref]$idx) -and $idx -ge 1 -and $idx -le $platformVersions.Count
                if (-not $valid) { Write-PSFMessage -Level Warning -Message "Please enter a number between 1 and $($platformVersions.Count)." }
            } while (-not $valid)

            $selectedDir  = $platformVersions[$idx - 1].FullName
            $selectedName = $platformVersions[$idx - 1].Name

            Write-PSFMessage -Level Host -Message "  -> Selected: $selectedName"
        }

        # ---------------------------------------------------------------------------
        # 3. Locate PackagesLocalDirectory inside the selected folder
        # ---------------------------------------------------------------------------
        $packagesLocal = Join-Path $selectedDir "PackagesLocalDirectory"
        if (-not (Test-Path $packagesLocal)) {
            $packagesLocal = "C:\AOSService\PackagesLocalDirectory"
            Write-PSFMessage -Level Warning -Message "PackagesLocalDirectory not found under $selectedDir — defaulting to $packagesLocal"
        }

        # ---------------------------------------------------------------------------
        # 4. Prompt for Environment URL
        # ---------------------------------------------------------------------------
        if ([string]::IsNullOrWhiteSpace($EnvironmentURL)) {
            $EnvironmentURL = Read-Host "`nEnter the environment's URL (e.g. https://myenv.operations.dynamics.com/)"
        }
        if (-not $EnvironmentURL.EndsWith("/")) { $EnvironmentURL += "/" }

        # ---------------------------------------------------------------------------
        # 5. Derive names and output path
        #    VS stores configs in %LOCALAPPDATA%\Microsoft\Dynamics365\XPPConfig\
        #    with the filename pattern: <envname>___<version>.json (three underscores)
        # ---------------------------------------------------------------------------
        $envName        = ([System.Uri]$EnvironmentURL).Host.Split('.')[0]
        $versionNoDots  = $selectedName -replace '\.', ''
        $businessDbName = "AXDBRAIN"
        $crossRefDbName = "XRef_$envName$versionNoDots"
        $xppConfigDir   = Join-Path $baseDir "XPPConfig"
        $configName     = "${envName}___${selectedName}.json"
        $outputPath     = Join-Path $xppConfigDir $configName

        if (-not (Test-Path $xppConfigDir)) {
            New-Item -ItemType Directory -Path $xppConfigDir | Out-Null
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # ---------------------------------------------------------------------------
        # 6. Find an existing cross-reference database on the same platform version,
        #    backup and restore it as the new database name.
        #    Fails loudly if no matching source config or database is found.
        # ---------------------------------------------------------------------------
        $matchingConfigs = @(
            Get-ChildItem -Path $xppConfigDir -Filter "*___${selectedName}.json" |
            Where-Object  { $_.Name -ne $configName } |
            Sort-Object   LastWriteTime -Descending
        )

        if ($matchingConfigs.Count -eq 0) {
            $messageString = "No existing configuration found for platform $selectedName under $xppConfigDir. A source configuration on the same platform version is required."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no source configuration was found for platform $selectedName." -Exception $([System.Exception]::new($messageString))
            return
        }

        $sourceConfigFile = $matchingConfigs[0]
        Write-PSFMessage -Level Host -Message "Source config  : $($sourceConfigFile.Name) (modified $($sourceConfigFile.LastWriteTime))"

        $sourceConfig = Get-Content $sourceConfigFile.FullName -Raw | ConvertFrom-Json
        $sourceDbName = $sourceConfig.CrossReferencesDatabaseName

        if ([string]::IsNullOrWhiteSpace($sourceDbName)) {
            $messageString = "Source config '$($sourceConfigFile.Name)' does not specify a CrossReferencesDatabaseName."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the source config does not specify a CrossReferencesDatabaseName." -Exception $([System.Exception]::new($messageString))
            return
        }

        Write-PSFMessage -Level Host -Message "Source XRef DB : $sourceDbName"

        # Ensure LocalDB is running
        Write-PSFMessage -Level Host -Message "Ensuring LocalDB instance is running..."

        $sqlLocalDb = Get-Command SqlLocalDB -ErrorAction SilentlyContinue
        if ($null -ne $sqlLocalDb) {
            $instanceInfo = & SqlLocalDB info MSSQLLocalDB 2>&1
            if ($instanceInfo -match "Stopped") {
                & SqlLocalDB start MSSQLLocalDB | Out-Null
                Write-PSFMessage -Level Host -Message "  LocalDB instance started."
            }
            else {
                Write-PSFMessage -Level Host -Message "  LocalDB instance is already running."
            }
        }
        else {
            Write-PSFMessage -Level Warning -Message "SqlLocalDB.exe not found — assuming the instance is already running."
        }

        $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
        if ($null -eq $sqlcmd) {
            $messageString = "sqlcmd not found. Cannot restore cross-reference database."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because sqlcmd was not found." -Exception $([System.Exception]::new($messageString))
            return
        }

        # Verify the source database exists on LocalDB
        $srcExists = (& sqlcmd -S $localDbServer -Q "SET NOCOUNT ON; SELECT COUNT(1) FROM sys.databases WHERE name = N'$sourceDbName'" -h -1 2>&1 |
            Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1).Trim()

        if ($srcExists -ne "1") {
            $messageString = "Source database '$sourceDbName' was not found on $localDbServer. Ensure the source environment's cross-reference database is attached."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because source database '$sourceDbName' was not found on $localDbServer." -Exception $([System.Exception]::new($messageString))
            return
        }

        # Backup the source database to a temp file
        $backupPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$sourceDbName.bak")
        Write-PSFMessage -Level Host -Message "Backing up '$sourceDbName'..."
        & sqlcmd -S $localDbServer -Q "BACKUP DATABASE [$sourceDbName] TO DISK = N'$backupPath' WITH FORMAT, INIT;" -b
        if ($LASTEXITCODE -ne 0) {
            $messageString = "Backup of '$sourceDbName' failed (sqlcmd exit code $LASTEXITCODE)."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because backup of '$sourceDbName' failed." -Exception $([System.Exception]::new($messageString))
            return
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
            $messageString = "Could not determine logical file names from backup of '$sourceDbName'. Restore aborted."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because logical file names could not be determined from backup." -Exception $([System.Exception]::new($messageString))
            return
        }

        # Restore as the new cross-reference database name
        Write-PSFMessage -Level Host -Message "Restoring as '$crossRefDbName'..."

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
            $messageString = "Restore of '$crossRefDbName' failed (sqlcmd exit code $restoreExit)."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because restore of '$crossRefDbName' failed." -Exception $([System.Exception]::new($messageString))
            return
        }

        Write-PSFMessage -Level Host -Message "  Cross-reference database '$crossRefDbName' restored from '$sourceDbName'."

        # ---------------------------------------------------------------------------
        # 7. Build the config object
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
            EnvironmentURL                  = $EnvironmentURL
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
        # 8. Write the JSON file
        # ---------------------------------------------------------------------------
        $json = $config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($outputPath, $json, [System.Text.UTF8Encoding]::new($false))

        Write-PSFMessage -Level Host -Message "Configuration written to: $outputPath"

        # ---------------------------------------------------------------------------
        # 9. Register the configuration in the VS registry so it appears in
        #    Dynamics 365 > Configure Metadata
        # ---------------------------------------------------------------------------
        $regKey = 'HKCU:\Software\Microsoft\Dynamics\AX7\Development\Configurations'
        Set-ItemProperty -Path $regKey -Name 'CurrentMetadataConfig' -Value $outputPath   -Type String
        Set-ItemProperty -Path $regKey -Name 'FrameworkDirectory'    -Value $packagesLocal -Type String
        Write-PSFMessage -Level Host -Message "Registry updated (CurrentMetadataConfig, FrameworkDirectory)"
        Write-PSFMessage -Level Host -Message "Key settings:"
        Write-PSFMessage -Level Host -Message "  RuntimePackagesDirectory    : $selectedDir"
        Write-PSFMessage -Level Host -Message "  FrameworkDirectory          : $packagesLocal"
        Write-PSFMessage -Level Host -Message "  CustomMetadataFolder        : $CustomMetadataFolder"
        Write-PSFMessage -Level Host -Message "  BusinessDatabaseName        : $businessDbName @ $dbServer"
        Write-PSFMessage -Level Host -Message "  CrossReferencesDatabaseName : $crossRefDbName @ $localDbServer"
        Write-PSFMessage -Level Host -Message "  EnvironmentURL              : $EnvironmentURL"
        Write-PSFMessage -Level Host -Message "Done. Open this config in Visual Studio: Dynamics 365 > Configure Metadata."
    }

    end {
    }
}
