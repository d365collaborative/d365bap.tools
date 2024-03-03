
<#
    .SYNOPSIS
        Get Virutal Entity
        
    .DESCRIPTION
        Enables the user to query against the Virtual Entities from the D365FO environment
        
        This will help determine which Virtual Entities are already enabled / visible and their state
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER VisibleOnly
        Instruct the cmdlet to only output those virtual entities that are enabled / visible
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all virtual entities from the environment.
        
        Sample output:
        EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
        ----------                     --------- --------------------- ----------
        AadWorkerIntegrationEntity     False     False                 00002893-0000-0000-560a-005001000000
        AbbreviationsEntity            False     False                 00002893-0000-0000-5002-005001000000
        AccountantEntity               False     False                 00002893-0000-0000-0003-005001000000
        AccountingDistributionBiEntity False     False                 00002893-0000-0000-d914-005001000000
        AccountingEventBiEntity        False     False                 00002893-0000-0000-d414-005001000000
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -VisibleOnly
        
        This will fetch visble only virtual entities from the environment.
        
        Sample output:
        EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
        ----------                     --------- --------------------- ----------
        CurrencyEntity                 True      False                 00002893-0000-0000-c30b-005001000000
        WMHEOutboundQueueEntity        True      False                 00002893-0000-0000-f30b-005001000000
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will fetch all virtual entities from the environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentVirtualEntity {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [switch] $VisibleOnly,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri
        $tokenWebApi = Get-AzAccessToken -ResourceUrl $baseUri
        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApi.Token)"
        }

        # Fetch all meta data - for all entities in the environment
        $entitiesMetaRaw = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/entities') -Headers $headersWebApi
        $templateMeta = $entitiesMetaRaw.value[0]

        # Filter down to only those who are connected to Virtual Entities
        $entitiesMeta = $entitiesMetaRaw.value | Where-Object { -not [System.String]::IsNullOrEmpty($_.externalname) }
    }
    
    process {
        $localUri = $($baseUri + '/api/data/v9.2/mserp_financeandoperationsentities')

        if ($VisibleOnly) {
            $localUri += '?$filter=mserp_hasbeengenerated eq true'
        }
        $resEntities = Invoke-RestMethod -Method Get -Uri $localUri -Headers $headersWebApi

        $resCol = @(
            foreach ($virEntity in $($resEntities.value | Sort-Object -Property mserp_physicalname)) {

                $tempMeta = $entitiesMeta | Where-Object externalname -eq $virEntity.mserp_physicalname | Select-Object -First 1

                if ($null -ne $tempMeta) {
                    # Work against the meta data found
                    foreach ($prop in $tempMeta.PsObject.Properties) {
                        $virEntity | Add-Member -MemberType NoteProperty -Name "meta_$($prop.Name)" -Value $prop.Value
                    }
                }
                else {
                    # Create empty properties for those who doesn't have meta data available
                    foreach ($prop in $templateMeta.PsObject.Properties) {
                        $virEntity | Add-Member -MemberType NoteProperty -Name "meta_$($prop.Name)" -Value $null
                    }
                }

                $virEntity | Select-PSFObject -TypeName "D365Bap.Tools.VirtualEntity" -Property "mserp_physicalname as EntityName",
                "mserp_hasbeengenerated as IsVisible",
                "mserp_changetrackingenabled as ChangeTrackingEnabled",
                "mserp_financeandoperationsentityid as EntityGuid",
                *
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
        
    }
}