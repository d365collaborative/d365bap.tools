
<#
    .SYNOPSIS
        Set the link between Dataverse and the Enterprise Policy
        
    .DESCRIPTION
        To enable managed identity between Dataverse and Azure resources, you will need to work with the Enterprise Policy concept
        
        It needs to be linked, based on the SystemId of the Enterprise Policy (Azure) and the Dataverse environment (Id)
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER EnterprisePolicyResourceId
        The (system) id of the Enterprise Policy that you want to link to your Dataverse environment
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -EnterprisePolicyResourceId '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatform/enterprisePolicies/EnterprisePolicy-Dataverse'
        
        This will link the Dataverse Environment to the Enterprise Policy.
        The Environment is 'eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6'.
        The EnterprisePolicy is '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatform/enterprisePolicies/EnterprisePolicy-Dataverse'
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapEnvironmentLinkEnterprisePolicy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (mandatory = $true)]
        [Alias('SystemId')]
        [string] $EnterprisePolicyResourceId
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

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headers = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        $body = [PsCustomObject]@{
            "SystemId" = $EnterprisePolicyResourceId
        } | ConvertTo-Json

        # 2019-10-01
        $uriLinkEnterprisePolicy = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId/enterprisePolicies/Identity/link?api-version=2023-06-01"

        Invoke-RestMethod -Method Post -Uri $uriLinkEnterprisePolicy -Headers $headers -Body $body -ContentType "application/json" > $null
    }
    
    end {
        
    }
}