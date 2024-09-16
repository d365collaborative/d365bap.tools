
<#
    .SYNOPSIS
        Compare environment D365 Apps
        
    .DESCRIPTION
        Enables the user to compare 2 x environments, with one as a source and the other as a destination
        
        It will only look for installed D365 Apps on the source, and use this as a baseline against the destination
        
    .PARAMETER SourceEnvironmentId
        Environment Id of the source environment that you want to utilized as the baseline for the compare
        
    .PARAMETER DestinationEnvironmentId
        Environment Id of the destination environment that you want to validate against the baseline (source)
        
    .PARAMETER ShowDiffOnly
        Instruct the cmdlet to only output the differences that are not aligned between the source and destination
        
    .PARAMETER GeoRegion
        Instructs the cmdlet which Geo / Region the environment is located
        
        The default value is: "Emea"
        
        This is mandatory field from the API specification, we don't have the full list of values at the time of writing
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test*
        
        This will get all installed D365 Apps from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        
        Sample output:
        PpacD365AppName                      PpacPackageName                SourceVersion       DestinationVersion
        ---------------                      ---------------                -------------       ------------------
        Agent Productivity Tools             AgentProductivityToolsAnchor   9.2.24083.1006      9.2.24083.1006
        appprofilemanager                    msdyn_AppProfileManagerAnchor  10.1.24083.1006     10.1.24083.1006
        Business Copilot AI                  msdyn_BusinessCopilotAIAnchor  1.0.0.23            1.0.0.23
        Copilot for finance and operations … msdyn_FnOCopilotAnchor         1.0.2748.3          1.0.2748.3
        Copilot in Microsoft Dynamics 365 F… msdyn_FinanceAIAppAnchor       1.0.2755.2          1.0.2755.2
        Copilot in Microsoft Dynamics 365 S… msdyn_SCMAIAppAnchor           1.0.2731.2          1.0.2731.2
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -ShowDiffOnly
        
        This will get all installed D365 Apps from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will filter out results, to only include those where the DestinationVersions is different from the SourceVersion.
        
        Sample output:
        PpacD365AppName                      PpacPackageName                SourceVersion       DestinationVersion
        ---------------                      ---------------                -------------       ------------------
        Dataverse Accelerator                DataverseAccelerator_Anchor    1.0.5.6             1.0.4.36
        Dynamics 365 ChannelExperienceApps   msdyn_ChannelExperienceAppsAn… 1.0.24074.1004      1.0.24083.1004
        Invoice Capture for Dynamics 365 Fi… msdyn_FnoInvoiceCaptureAnchor  1.7.0.1             Missing
        OData v4 Data Provider               ODatav4DataProvider            9.1.0.203           9.1.0.226
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -AsExcelOutput
        
        This will get all installed D365 Apps from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Compare-BapEnvironmentD365App {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $SourceEnvironmentId,

        [parameter (mandatory = $true)]
        [string] $DestinationEnvironmentId,
    
        [switch] $ShowDiffOnly,

        [string] $GeoRegion = "Emea",

        [switch] $AsExcelOutput

    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envSourceObj = Get-BapEnvironment -EnvironmentId $SourceEnvironmentId | Select-Object -First 1

        if ($null -eq $envSourceObj) {
            $messageString = "The supplied SourceEnvironmentId: <c='em'>$SourceEnvironmentId</c> didn't return any matching environment details. Please verify that the SourceEnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envDestinationObj = Get-BapEnvironment -EnvironmentId $DestinationEnvironmentId | Select-Object -First 1

        if ($null -eq $envDestinationObj) {
            $messageString = "The supplied DestinationEnvironmentId: <c='em'>$DestinationEnvironmentId</c> didn't return any matching environment details. Please verify that the DestinationEnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $appsSourceEnvironment = Get-BapEnvironmentD365App -EnvironmentId $SourceEnvironmentId -Status Installed -GeoRegion $GeoRegion
        $appsDestinationEnvironment = Get-BapEnvironmentD365App -EnvironmentId $DestinationEnvironmentId -GeoRegion $GeoRegion
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resCol = @(foreach ($sourceApp in $($appsSourceEnvironment | Sort-Object -Property PpacD365AppName )) {
                $destinationApp = $appsDestinationEnvironment | Where-Object PpacD365AppId -eq $sourceApp.PpacD365AppId | Select-Object -First 1
        
                $sourceVersion = if ($sourceApp.InstalledVersion -eq "N/A") { [System.Version]"0.0.0.0" } else { [System.Version]$sourceApp.InstalledVersion }
                $tmp = [Ordered]@{
                    PpacD365AppId      = $sourceApp.PpacD365AppId
                    PpacPackageName    = $sourceApp.PpacPackageName
                    PpacD365AppName    = $sourceApp.PpacD365AppName
                    SourceVersion      = $sourceVersion
                    DestinationVersion = "Missing"
                }
        
                if (-not ($null -eq $destinationApp)) {
                    $tmp.DestinationVersion = if ($destinationApp.InstalledVersion -eq "N/A") { [System.Version]"0.0.0.0" }else { [System.Version]$destinationApp.InstalledVersion }
                }
        
                ([PSCustomObject]$tmp) | Select-PSFObject -TypeName "D365Bap.Tools.Compare.PpacD365App"
            }
        )

        if ($ShowDiffOnly) {
            $resCol = $resCol | Where-Object { $_.SourceVersion -ne $_.DestinationVersion }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -NoNumberConversion SourceVersion, DestinationVersion
            return
        }

        $resCol
    }
    
    end {
        
    }
}