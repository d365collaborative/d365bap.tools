
<#
    .SYNOPSIS
        Compare environment Virtual Entities
        
    .DESCRIPTION
        Enables the user to compare 2 x environments, with one as a source and the other as a destination
        
        It will only look for enabled / visible Virtual Entities on the source, and use this as a baseline against the destination
        
    .PARAMETER SourceEnvironmentId
        Environment Id of the source environment that you want to utilized as the baseline for the compare
        
    .PARAMETER DestinationEnvironmentId
        Environment Id of the destination environment that you want to validate against the baseline (source)
        
    .PARAMETER ShowDiffOnly
        Instruct the cmdlet to only output the differences that are not aligned between the source and destination
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
        
        This will get all enabled / visible Virtual Entities from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        
        Sample output:
        EntityName                     SourceIsVisible SourceChangeTrackingEnabled Destination DestinationChange
        IsVisible   TrackingEnabled
        ----------                     --------------- --------------------------- ----------- -----------------
        AccountantEntity               True            False                       True        False
        CurrencyEntity                 True            False                       False       False
        WMHEOutboundQueueEntity        True            False                       False       False
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -ShowDiffOnly
        
        This will get all enabled / visible Virtual Entities from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will filter out results, to only include those where the Source is different from the Destination.
        
        Sample output:
        EntityName                     SourceIsVisible SourceChangeTrackingEnabled Destination DestinationChange
        IsVisible   TrackingEnabled
        ----------                     --------------- --------------------------- ----------- -----------------
        CurrencyEntity                 True            False                       False       False
        WMHEOutboundQueueEntity        True            False                       False       False
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
        
        This will get all enabled / visible Virtual Entities from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Compare-BapEnvironmentVirtualEntity {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $SourceEnvironmentId,

        [parameter (mandatory = $true)]
        [string] $DestinationEnvironmentId,

        [switch] $ShowDiffOnly,

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

        $entitiesSourceEnvironment = @(Get-BapEnvironmentVirtualEntity -EnvironmentId $SourceEnvironmentId -VisibleOnly)
        $entitiesDestinationEnvironment = @(
            foreach ($entName in $entitiesSourceEnvironment.EntityName) {
                Get-BapEnvironmentVirtualEntity -EnvironmentId $DestinationEnvironmentId -Name $entName
            }
        )
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $resCol = @(foreach ($sourceEntity in $($entitiesSourceEnvironment | Sort-Object -Property EntityName )) {
                $destinationEntity = $entitiesDestinationEnvironment | Where-Object EntityName -eq $sourceEntity.EntityName | Select-Object -First 1
        
                $tmp = [Ordered]@{
                    EntityName                       = $sourceEntity.EntityName
                    SourceIsVisible                  = $sourceEntity.IsVisible
                    SourceChangeTrackingEnabled      = $sourceEntity.ChangeTrackingEnabled
                    SourceEntityGuid                 = $sourceEntity.EntityGuid
                    DestinationIsVisible             = ""
                    DestinationChangeTrackingEnabled = ""
                    DestinationEntityGuid            = ""
                }
        
                if (-not ($null -eq $destinationEntity)) {
                    $tmp.DestinationIsVisible = $destinationEntity.IsVisible
                    $tmp.DestinationChangeTrackingEnabled = $destinationEntity.ChangeTrackingEnabled
                    $tmp.DestinationEntityGuid = $destinationEntity.EntityGuid
                }
        
                ([PSCustomObject]$tmp) | Select-PSFObject -TypeName "D365Bap.Tools.Compare.VirtualEntity"
            }
        )

        if ($ShowDiffOnly) {
            $resCol = $resCol | Where-Object { ($_.SourceIsVisible -ne $_.DestinationIsVisible) -or ($_.SourceChangeTrackingEnabled -ne $_.DestinationChangeTrackingEnabled) }
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