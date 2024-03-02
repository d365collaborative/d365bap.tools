
<#
    .SYNOPSIS
        Compare environment D365 Apps
        
    .DESCRIPTION
        This enables the user to compare 2 x environments, with one as a source and the other as a destination
        
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
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
        
        This will get all installed D365 Apps from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        
        Sample output:
        PackageId                            PackageName                    SourceVersion       DestinationVersion  AppName
        ---------                            -----------                    -------------       ------------------  -------
        ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24012.1005      Agent Prod…
        1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24012.1013     appprofile…
        6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             0.0.0.0             Azure Syna…
        42cc1442-194f-462b-a325-ce5b5f18c02d msdyn_EmailAddressValidation   1.0.0.4             1.0.0.4             Data Valid…
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -ShowDiffOnly
        
        This will get all installed D365 Apps from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will filter out results, to only include those where the DestinationVersions is different from the SourceVersion.
        
        Sample output:
        PackageId                            PackageName                    SourceVersion       DestinationVersion  AppName
        ---------                            -----------                    -------------       ------------------  -------
        ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24012.1005      Agent Prod…
        1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24012.1013     appprofile…
        6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             0.0.0.0             Azure Syna…
        7523d261-f1be-46e7-8e68-f3de16eeabbb DualWriteCoreAnchor            1.0.24022.4         1.0.24011.1         Dual-write…
        
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

        $appsSourceEnvironment = Get-BapEnvironmentD365App -EnvironmentId $SourceEnvironmentId -InstallState Installed
        $appsDestinationEnvironment = Get-BapEnvironmentD365App -EnvironmentId $DestinationEnvironmentId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resCol = @(foreach ($sourceApp in $($appsSourceEnvironment | Sort-Object -Property ApplicationName )) {
                $destinationApp = $appsDestinationEnvironment | Where-Object PackageId -eq $sourceApp.PackageId | Select-Object -First 1
        
                $tmp = [Ordered]@{
                    PackageId          = $sourceApp.PackageId
                    PackageName        = $sourceApp.PackageName
                    AppName            = $sourceApp.AppName
                    SourceVersion      = [System.Version]$sourceApp.InstalledVersion
                    DestinationVersion = "Missing"
                }
        
                if (-not ($null -eq $destinationApp)) {
                    $tmp.DestinationVersion = if ($destinationApp.InstalledVersion -eq "N/A") { [System.Version]"0.0.0.0" }else { [System.Version]$destinationApp.InstalledVersion }
                }
        
                ([PSCustomObject]$tmp) | Select-PSFObject -TypeName "D365Bap.Tools.Compare.Package"
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