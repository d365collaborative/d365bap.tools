
<#
    .SYNOPSIS
        Sets UDE configuration for a specific environment.
        
    .DESCRIPTION
        This function allows you to set the UDE configuration used in Visual Studio for a specific environment.
        
    .PARAMETER EnvironmentUri
        The URI of the environment to configure.
        
    .PARAMETER PackagesVersion
        The version of the packages to use.
        
    .PARAMETER Path
        The path to the custom source code to include in the UDE configuration.
        
    .PARAMETER FallbackPath
        The fallback path to use if the needed packages or XRef DB files are not referenced in any other UDE configuration.
        
    .EXAMPLE
        PS C:\> Set-UdeConfig -EnvironmentUri "https://env-123.cloud.dynamics.com" -PackagesVersion "10.0.2177.188" -Path "C:\CustomSourceCode"
        
        This will set the UDE configuration for the environment with the URI "https://env-123.cloud.dynamics.com".
        It will use the packages version "10.0.2177.188".
        It will include the custom source code from "C:\CustomSourceCode".
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironment -EnvironmentId "env-123" | Set-UdeConfig -Path "C:\CustomSourceCode"
        
        This will set the UDE configuration for the environment with the ID "env-123".
        It will use the packages version from the environment details.
        It will include the custom source code from "C:\CustomSourceCode".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-UdeConfig {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvUri")]
        [string] $EnvironmentUri,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacProvApp")]
        [string] $PackagesVersion,

        [Parameter(Mandatory = $true)]
        [Alias("SourceCode")]
        [string] $Path,

        [string] $FallbackPath = 'C:\Temp\d365bap.tools\UdeDeveloperFiles'
    )

    begin {

    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # The configuration name is derived from the environment URI
        $confName = ([uri]$EnvironmentUri).Host.Split(".")[0]

        if ($null -ne (Get-UdeConfig -Name $confName)) {
            $messageString = "The UDE configuration <c='em'>$confName</c> already exists. Please remove it first before creating a new UDE configuration."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because UDE configuration already exists." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Path to the packages that matches the version
        $pathPackages = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$PackagesVersion\PackagesLocalDirectory"
        
        if (-not [System.IO.Path]::Exists($pathPackages)) {
            $messageString = "It seems that the PackagesLocalDirectory for <c='em'>$PackagesVersion</c> does not exist. Please download the developer files first using <c='em'>Get-UdeDeveloperFile -Download</c>."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because PackagesLocalDirectory wasn't found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        # Some of the names need the version without dots
        $striped = $PackagesVersion.Replace(".", "")

        # Do we have the XRef DB for the version already?
        $dbVersion = Get-UdeXrefDb | `
            Where-Object name -like "*$striped" | `
            Select-Object -First 1 -ExpandProperty Name

        # The name of the XRef DB to create
        $dbXrefName = "XRef_$confName$striped"
        
        # Path to store the config files + XRef DB files
        $pathConfigs = "$env:LOCALAPPDATA\Microsoft\Dynamics365\XPPConfig"

        # Xpp configuration file + XRef DB directory
        $xppName = "$confName`___$PackagesVersion"
        $pathXRefDb = "$pathConfigs\$xppName"
        $pathXppConf = "$pathConfigs\$xppName.json"

        $pathSymlinks = "$env:LOCALAPPDATA\Microsoft\Dynamics365\RuntimeSymLinks\$confName"

        # Path to the custom source code to link in UDE
        if ($Path -like "*Metadata*") {
            $pathSource = "$Path"
        }
        else {
            $pathSource = "$Path\$confName\Metadata"
        }

        $pathXRefBackup = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$PackagesVersion\DYNAMICSXREFDB.bak"

        if ($null -eq $dbVersion) {
            # Let's look for the backup file instead - in the fallback location
            if (-not [System.IO.Path]::Exists("$FallbackPath\$PackagesVersion\DYNAMICSXREFDB.bak")) {
                $messageString = "It seems that the XRef DB backup file for <c='em'>$PackagesVersion</c> does not exist at `r`n<c='em'>$pathXRefBackup</c> `r`nor the fallback path `r`n<c='em'>$FallbackPath\$PackagesVersion\DYNAMICSXREFDB.bak</c>. Please download the developer files first using <c='em'>Get-UdeDeveloperFile -Download</c>."

                Write-PSFMessage -Level Host -Message $messageString -Target Host
                Stop-PSFFunction -Message "Stopping because XRef DB backup file wasn't found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            # We don't have a DB for the version, so we need to copy the backup file from the fallback location
            Copy-Item -Path "$FallbackPath\$PackagesVersion\DYNAMICSXREFDB.bak" `
                -Destination $pathXRefBackup `
                -Force
        }
        else {
            # We have a DB for the version, that we can use to create a copy-only backup
            $sqlCommand = Get-SqlCommand
            
            $sqlCommand.CommandText = @"
BACKUP DATABASE [$dbVersion]
TO DISK = N'$pathXRefBackup'
WITH
COPY_ONLY,
FORMAT,
INIT,
NAME = N'DYNAMICSXREFDB - $PackagesVersion - Copy-Only Database Backup',
STATS = 10;
"@
            try {
                $sqlCommand.Connection.Open()
    
                $sqlCommand.ExecuteNonQuery() > $null
            }
            catch {
                $messageString = "The backup for XRef DB <c='em'>failed</c>. Please make sure that you have enough free disk space."

                Write-PSFMessage -Level Host -Message $messageString -Target Host -Exception $PSItem.Exception
                Stop-PSFFunction -Message "Stopping because XRef DB backup failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
            finally {
                Dispose-SqlCommand -InputObject $sqlCommand
            }
        }

        if ($null -ne (Get-UdeXrefDb -Name $dbXrefName)) {
            $messageString = "The XRef DB <c='em'>$dbXrefName</c> already exists. Please consider running the <c='em'>Clear-UdeOrphanedConfig</c> cmdlet to make sure that your configuration is cleaned."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because XRef DB already exists." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        # Create the XRef DB directory
        New-Item -Path $pathXRefDb `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null
            
        # We have the original DB
        $sqlCommand = Get-SqlCommand

        $sqlCommand.CommandText = @"
RESTORE DATABASE [$dbXrefName]
FROM DISK = N'$pathXRefBackup'
WITH
     MOVE N'DYNAMICSXREFDB' TO N'$pathXRefDb\DYNAMICSXREFDB1.mdf',
     MOVE N'DYNAMICSXREFDB_log' TO N'$pathXRefDb\DYNAMICSXREFDB1_log.ldf',
     REPLACE,
     STATS = 10;
"@

        try {
            $sqlCommand.Connection.Open()
    
            $sqlCommand.ExecuteNonQuery() > $null
        }
        catch {
            $messageString = "The restore for XRef DB <c='em'>failed</c>. Please make sure that you have enough free disk space."

            Write-PSFMessage -Level Host -Message $messageString -Target Host -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because XRef DB restore failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        finally {
            Dispose-SqlCommand -InputObject $sqlCommand
            
            # Remove backup file, either the copied one or the created one
            Remove-Item -Path $pathXRefBackup `
                -Force `
                -ErrorAction SilentlyContinue
        }

        if ($null -eq (Get-UdeXrefDb -Name $dbXrefName)) {
            $messageString = "The XRef DB <c='em'>$dbXrefName</c> was not found after restore."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because XRef DB was not found after restore." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        # Create the source code directory
        New-Item -Path $pathSource `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null

        # Create the symlink directory
        New-Item -Path $pathSymlinks `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null

        # Create the symbolic/junction link to the source code for UDE
        New-Item -ItemType Junction `
            -Path "$pathSymlinks\ZZZZ__CustomXppMetadata" `
            -Target $pathSource `
            -Force `
            -WarningAction SilentlyContinue > $null

        # Create the symbolic/junction link to the packages for UDE
        New-Item -ItemType Junction `
            -Path "$pathSymlinks\PackagesLocalDirectory" `
            -Target $pathPackages `
            -Force `
            -WarningAction SilentlyContinue > $null

        # Create the symbolic/junction link to the bin directory under packages
        New-Item -ItemType Junction `
            -Path "$pathSymlinks\bin" `
            -Target $pathPackages\bin `
            -Force `
            -WarningAction SilentlyContinue > $null

        ([PsCustomObject][ordered]@{
            "CrossReferencesDatabaseName"     = "$dbXrefName"
            "CrossReferencesDbServerName"     = "(LocalDB)\MSSQLLocalDB"
            "ModelStoreFolder"                = $pathSource
            "ModuleExclusionList"             = $null
            "DefaultModelForNewProjects"      = "FleetManagement"
            "DebugSourceFolder"               = $pathSource
            "FrameworkDirectory"              = $pathPackages
            "AdminIdentityProvider"           = "https://sts.windows.net/"
            "AosWebsiteName"                  = "AOSService"
            "ApplicationHostConfigFile"       = "C:\AOSService\PackagesLocalDirectory\bin\applicationHost.config"
            "AudienceUri"                     = "spn:00000015-0000-0000-c000-000000000000"
            "BusinessDatabaseName"            = "AxDbRain"
            "BusinessDatabaseUserName"        = ""
            "BusinessDatabasePassword"        = ""
            "AzureAppID"                      = ""
            "AzureCR_Key"                     = $null
            "ContainerMemory"                 = $null
            "RunBatchWithinAOS"               = $null
            "CloudInstanceURL"                = "https://usnconeboxax1aos.cloud.onebox.dynamics.com/"
            "DatabaseServer"                  = "localhost"
            "DefaultCompany"                  = ""
            "EnableOfflineAuthentication"     = $true
            "OfflineAuthenticationAdminEmail" = ""
            "PartitionKey"                    = "initial"
            "RuntimeHostType"                 = 4
            "Description"                     = "Unified development environment $confName. `r`nFinOps application version $PackagesVersion. `r`nConfiguration generated on $((Get-Date).ToString('dd/MM/yyyy')). `r`nCross Reference DB Server (LocalDB)\MSSQLLocalDB. `r`nCross Reference DB Name $dbXrefName."
            "WebRoleDeploymentFolder"         = "C:\AOSService\webroot"
            "ReferencePackagesPaths"          = @($pathPackages)
            "RuntimePackagesDirectory"        = $pathSymlinks
        }) | ConvertTo-Json -Depth 5 | `
            Out-File -FilePath $pathXppConf -Encoding UTF8 -Force

        Get-UdeConfig -Name $confName
    }
}