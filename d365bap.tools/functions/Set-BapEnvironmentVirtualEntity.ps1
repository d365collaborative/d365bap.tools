
<#
    .SYNOPSIS
        Set Virtual Entity configuration in environment
        
    .DESCRIPTION
        Enables the user to update the configuration for any given Virtual Entity in the environment
        
        The configuration is done against the Dataverse environment, and allows the user to update the Visibility or TrackingChanges, for a given Virtual Entity
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER  Name
        The name of the virtual entity that you are looking for
        
    .PARAMETER VisibilityOn
        Instructs the cmdlet to turn "ON" the Virtual Entity
        
        Can be used in combination with TrackingOn / TrackingOff
        
    .PARAMETER VisibilityOff
        Instructs the cmdlet to turn "OFF" the Virtual Entity
        
        Can be used in combination with TrackingOn / TrackingOff
        
    .PARAMETER TrackingOn
        Instructs the cmdlet to enable ChangeTracking on the Virtual Entity
        
        Can be used in combination with VisibilityOn / VisibilityOff
        
    .PARAMETER TrackingOff
        Instructs the cmdlet to disable ChangeTracking on the Virtual Entity
        
        Can be used in combination with VisibilityOn / VisibilityOff
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -VisibilityOn -TrackingOff
        
        This will enable the Virtual Entity "AccountantEntity" on the environment.
        It will turn off the ChangeTracking at the same time.
        
        Sample output:
        EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
        ----------                     --------- --------------------- ----------
        AccountantEntity               True      False                 00002893-0000-0000-0003-005001000000
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -VisibilityOff
        
        This will disable the Virtual Entity "AccountantEntity" on the environment.
        
        Sample output:
        EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
        ----------                     --------- --------------------- ----------
        AccountantEntity               False     False                 00002893-0000-0000-0003-005001000000
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -TrackingOn
        
        This will update the Virtual Entity "AccountantEntity" on the environment.
        It will enable the ChangeTracking for the entity.
        
        Sample output:
        EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
        ----------                     --------- --------------------- ----------
        AccountantEntity               True      True                  00002893-0000-0000-0003-005001000000
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapEnvironmentVirtualEntity {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (mandatory = $true)]
        [string] $Name,

        [switch] $VisibilityOn,

        [switch] $VisibilityOff,

        [switch] $TrackingOn,

        [switch] $TrackingOff
    )
    
    begin {
        if (-not($VisibilityOn -or $VisibilityOff -or $TrackingOn -or $TrackingOff)) {
            $messageString = "You need to select atleast one of the ParameterSets: You have to use either <c='em'>-VisibilityOn</c> / <c='em'>-VisibilityOff</c> or <c='em'>-TrackingOn</c> / <c='em'>-TrackingOff</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because intent of the operation is NOT clear." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($VisibilityOn -and $VisibilityOff) {
            $messageString = "The supplied parameter combination is not valid. You have to use either <c='em'>-VisibilityOn</c> or <c='em'>-VisibilityOff</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because intent of the operation is NOT clear." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($TrackingOn -and $TrackingOff) {
            $messageString = "The supplied parameter combination is not valid. You have to use either <c='em'>-TrackingOn</c> or <c='em'>-TrackingOff</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because intent of the operation is NOT clear." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvApiUri
        $tokenWebApi = Get-AzAccessToken -ResourceUrl $baseUri
        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApi.Token)"
        }

        $entities = @(Get-BapEnvironmentVirtualEntity -EnvironmentId $EnvironmentId -Name $Name)

        if ($entities.Count -ne 1) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $entity = $entities[0]
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $($baseUri + '/XRMServices/2011/Organization.svc/web?SDKClientVersion=9.2.49.3165' -f $entity.EntityGuid)

        # Base payload for updating the virtual entity configuration
        $body = @'
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Header>
            <UserType xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">CrmUser</UserType>
            <SdkClientVersion xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">9.2.49.3165</SdkClientVersion>
            <x-ms-client-request-id xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">{0}</x-ms-client-request-id>
        </s:Header>
        <s:Body>
            <Execute xmlns="http://schemas.microsoft.com/xrm/2011/Contracts/Services">
                <request i:type="a:UpdateRequest" xmlns:a="http://schemas.microsoft.com/xrm/2011/Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
                    <a:Parameters xmlns:b="http://schemas.datacontract.org/2004/07/System.Collections.Generic">
                        <a:KeyValuePairOfstringanyType>
                            <b:key>Target</b:key>
                            <b:value i:type="a:Entity">
                                <a:Attributes>
##INPUT##
                                </a:Attributes>
                                <a:EntityState i:nil="true"/>
                                <a:FormattedValues/>
                                <a:Id>{1}</a:Id>
                                <a:KeyAttributes xmlns:c="http://schemas.microsoft.com/xrm/7.1/Contracts"/>
                                <a:LogicalName>mserp_financeandoperationsentity</a:LogicalName>
                                <a:RelatedEntities/>
                                <a:RowVersion i:nil="true"/>
                            </b:value>
                        </a:KeyValuePairOfstringanyType>
                    </a:Parameters>
                    <a:RequestId>{0}</a:RequestId>
                    <a:RequestName>Update</a:RequestName>
                </request>
            </Execute>
        </s:Body>
    </s:Envelope>
'@ -f $([System.Guid]::NewGuid().Guid), $entity.EntityGuid


        if ($VisibilityOn -or $VisibilityOff) {
            # We need to set the Visibility configuration for the virtual entity
            $visibility = @'
                                    <a:KeyValuePairOfstringanyType>
                                        <b:key>mserp_hasbeengenerated</b:key>
                                        <b:value i:type="c:boolean" xmlns:c="http://www.w3.org/2001/XMLSchema">{0}</b:value>
                                    </a:KeyValuePairOfstringanyType>
'@ -f $(if ($VisibilityOn) { "true" }else { "false" })
        }


        if ($TrackingOn -or $TrackingOff) {
            # We need to set the Tracking configuration for the virtual entity
            $tracking = @'
                                    <a:KeyValuePairOfstringanyType>
                                        <b:key>mserp_changetrackingenabled</b:key>
                                        <b:value i:type="c:boolean" xmlns:c="http://www.w3.org/2001/XMLSchema">{0}</b:value>
                                    </a:KeyValuePairOfstringanyType>
'@ -f $(if ($TrackingOn) { "true" }else { "false" })
        }
        
        $body = $body -replace $("##INPUT##", "$visibility`r`n$tracking")

        $headersWebApi."Content-Type" = "text/xml; charset=utf-8"
        $headersWebApi.SOAPAction = "http://schemas.microsoft.com/xrm/2011/Contracts/Services/IOrganizationService/Execute"
        Invoke-RestMethod -Method Post -Uri $localUri -Headers $headersWebApi -Body $body -ContentType "text/xml; charset=utf-8" > $null
        
        # We are asking to fast for the meta data to be updated
        Start-Sleep -Seconds 10

        Get-BapEnvironmentVirtualEntity -EnvironmentId $EnvironmentId -Name $Name
    }
    
    end {
        
    }
}