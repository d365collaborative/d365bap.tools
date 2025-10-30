
<#
    .SYNOPSIS
        Update the meta data for an Virtual Entity in an environment
        
    .DESCRIPTION
        Enables the user to update the metadata for any given Virtual Entity in the environment
        
        This is useful when there has been schema changes on the Virtual Entity inside the D365FO environment, after it was made visible / enabled
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER  Name
        The name of the virtual entity that you are looking for
        
    .EXAMPLE
        PS C:\> Update-BapEnvironmentVirtualEntityMetadata -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity
        
        This will execute the internal mechanism inside the Dataverse environment.
        It will halt/stall as long as the operation is running.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Update-BapEnvironmentVirtualEntityMetadata {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $Name
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
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
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
                                        <a:KeyValuePairOfstringanyType>
                                            <b:key>mserp_refresh</b:key>
                                            <b:value i:type="c:boolean" xmlns:c="http://www.w3.org/2001/XMLSchema">true</b:value>
                                        </a:KeyValuePairOfstringanyType>
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

        $headersWebApi."Content-Type" = "text/xml; charset=utf-8"
        $headersWebApi.SOAPAction = "http://schemas.microsoft.com/xrm/2011/Contracts/Services/IOrganizationService/Execute"
        Invoke-RestMethod -Method Post -Uri $localUri -Headers $headersWebApi -Body $body -ContentType "text/xml; charset=utf-8" > $null
    }
    
    end {
        
    }
}