
<#
    .SYNOPSIS
        Get D365 App from the environment
        
    .DESCRIPTION
        Enables the user to analyze and validate the current D365 Apps and their state, on a given environment
        
        It can show all available D365 Apps - including their InstallState
        
        It can show only installed D365 Apps
        
        It can show only installed D365 Apps, with available updates
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
        Wildcard is supported
        
    .PARAMETER Name
        Name of the D365 App that you are looking for
        
        It supports wildcard searching, which is validated against the following properties:
        * PpacD365AppName / AppName / ApplicationName
        * PpacPackageName / PackageName / UniqueName
        
    .PARAMETER Status
        Instruct the cmdlet which install states that you want to have included in the output
        
        The default value is: "All"
        
        Valid values:
        * "All"
        * "Installed"
        * "InstallFailed"
        * "None"
        
    .PARAMETER GeoRegion
        Instructs the cmdlet which Geo / Region the environment is located
        
        The default value is: "Emea"
        
        This is mandatory field from the API specification, we don't have the full list of values at the time of writing
        
    .PARAMETER IncludeAll
        Instruction to include all D365 Apps in the output, regardless of their install state
        
    .PARAMETER UpdatesOnly
        Instruct the cmdlet to only output D365 Apps that has an update available
        
        Makes it easier to fully automate the update process of a given environment
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will query the environment for ALL available D365 Apps.
        It will output the ones that are either installed or in a failed install state.
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        
        Sample output:
        
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
        appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
        Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
        Copilot for finance and ope... msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test*
        
        This will query the environment for ALL available D365 Apps.
        It will output the ones that are either installed or in a failed install state.
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        
        Sample output:
        
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
        appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
        Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
        Copilot for finance and ope... msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -Status Installed
        
        This will query the environment for installed only D365 Apps.
        It will output the ones that are either installed or in a failed install state.
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        
        Sample output:
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
        appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
        Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
        Copilot for finance and ope... msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -Status None
        
        This will query the environment for NON-installed only D365 Apps.
        It will output all details available for the D365 Apps.
        
        Sample output:
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        AI Builder for Project Cortex  SharePointFormProcessing       N/A                                 None
        Analytics Custom Entities      AnalyticsCustomEntities        N/A                                 None
        Analytics Custom Entities      AnalyticsCustomEntities_Anchor N/A                                 None
        Awards and Recognitions Tem... mpa_AwardsAndRecognition       N/A                                 None
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -Status InstallFailed
        
        This will query the environment for D365 Apps that are in a failed installation state.
        It will output all details available for the D365 Apps.
        
        Sample output:
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Azure Synapse Link for Datave… ExportToDataLakeCoreAnchor     N/A                                 InstallFailed
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -Name "*ToolsAnchor*"
        
        This will query the environment for ALL D365 Apps.
        It will filter the output to only those who match the search pattern "*ToolsAnchor*".
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        
        Sample output:
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -UpdatesOnly
        
        This will query the environment for ALL available D365 Apps.
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        It will filter the output to only containing those who have an update available.
        
        Sample output:
        PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
        ---------------                ---------------                ----------------    --------------- ------
        Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
        Dual-write core solution       DualWriteCoreAnchor            1.0.24062.2         True            Installed
        Dynamics 365 ChannelExperienc… msdyn_ChannelExperienceAppsAn… 1.0.24074.1004      True            Installed
        Dynamics 365 ContextualHelp    msdyn_ContextualHelpAnchor     1.0.0.22            True            Installed
        
    .EXAMPLE
        PS C:\> $appIds = @(Get-BapEnvironmentD365App -EnvironmentId *test* -UpdatesOnly | Select-Object -ExpandProperty PpacD365AppId)
        PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId *test* -D365AppId $appIds
        
        This will query the environment for installed only D365 Apps.
        It will filter the output to only containing those who have an update available.
        It will persist the PackageIds for each D365 App, into an array.
        It will invoke the installation process using the Invoke-BapEnvironmentInstallD365App cmdlet.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentD365App -EnvironmentId *test* -AsExcelOutput
        
        This will query the environment for ALL available D365 Apps.
        It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentD365App {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [ValidateSet("All", "Installed", "InstallFailed", "None")]
        [string] $Status = "All",

        [string] $GeoRegion = "Emea",

        [switch] $IncludeAll,

        [switch] $UpdatesOnly,

        [switch] $AsExcelOutput
    )
    
    begin {
        $tenantId = (Get-AzContext).Tenant.Id
        
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        # First we will fetch ALL available apps for the environment
        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }
        
        $appsAvailable = Invoke-RestMethod -Method Get -Uri "https://api.powerplatform.com/appmanagement/environments/$($envObj.PpacEnvId)/applicationPackages?api-version=2022-03-01-preview" -Headers $headersPowerApi | Select-Object -ExpandProperty Value

        # Next we will fetch current installed apps and their details, for the environment
        $uriSourceEncoded = [System.Web.HttpUtility]::UrlEncode($envObj.LinkedMetaPpacEnvUri)
        
        $secureTokenAdminApi = (Get-AzAccessToken -ResourceUrl "065d9450-1e87-434e-ac2f-69af271549ed" -AsSecureString).Token
        $tokenAdminApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenAdminApi

        $headersAdminApi = @{
            "Authorization" = "Bearer $($tokenAdminApiValue)"
        }

        $appsEnvironment = Invoke-RestMethod -Method Get -Uri "https://api.admin.powerplatform.microsoft.com/api/AppManagement/InstancePackages/instanceId/$tenantId`?instanceUrl=$uriSourceEncoded`&geoType=$GeoRegion" -Headers $headersAdminApi
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resCol = @(
            foreach ($appObj in $($appsAvailable | Sort-Object -Property ApplicationName)) {
                if ((-not ($appObj.ApplicationName -like $Name -or $appObj.ApplicationName -eq $Name)) -and (-not ($appObj.UniqueName -like $Name -or $appObj.UniqueName -eq $Name))) { continue }
                
                if ($Status -ne "All" -and $appObj.state -ne $Status) { continue }
            
                $appObj | Add-Member -MemberType NoteProperty -Name CurrentVersion -Value "N/A"

                $currentApp = $appsEnvironment | Where-Object ApplicationId -eq $appObj.ApplicationId | Select-Object -First 1
                if ($currentApp) {
                    $appObj.CurrentVersion = $currentApp.Version
                
                    $appObj | Add-Member -MemberType NoteProperty -Name IsLatest -Value $($appObj.CurrentVersion -eq $appObj.Version)
                    $appObj | Add-Member -MemberType NoteProperty -Name UpdateAvail -Value $(-not ($appObj.CurrentVersion -eq $appObj.Version))
                }
            
                $appObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacD365App" `
                    -Property "Id as PpacD365AppId",
                "ApplicationName as PpacD365AppName",
                "UniqueName as PpacPackageName",
                "Version as AvailableVersion",
                "CurrentVersion as InstalledVersion",
                "UpdateAvail as UpdateAvailable",
                "state as Status",
                @{Name = "StateIsInstalled"; Expression = { if (($_.state -ne 'none')) { $true }else { $false } } },
                *,
                @{Name = "SupportedCountriesList"; Expression = { $_.supportedCountries -join "," } }
            }
        )

        if (-not $IncludeAll -and $Status -ne 'None') {
            $resCol = @($resCol | Where-Object StateIsInstalled -eq $true )
        }

        if ($UpdatesOnly) {
            $resCol = @($resCol | Where-Object IsLatest -eq $false)
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapEnvironmentD365App" `
                -NoNumberConversion Version, AvailableVersion, InstalledVersion, crmMinversion, crmMaxVersion, Version
            return
        }

        $resCol
    }
    
    end {
        
    }
}