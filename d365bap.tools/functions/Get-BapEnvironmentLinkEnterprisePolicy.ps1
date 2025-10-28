
<#
    .SYNOPSIS
        Get Enterprise Policy
        
    .DESCRIPTION
        Get all registered Enterprise Policies from a Dataverse environment and its linked status
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will get all Enterprise Policy informations from the Dataverse environment.
        
        Sample output:
        PpacEnvId   : eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        PpacEnvName : new-test
        Type        : identity
        policyId    : d3e06308-e287-42bb-ad6d-a588ef77d6e8
        location    : europe
        id          : /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatfor
        m/enterprisePolicies/EnterprisePolicy-Dataverse
        systemId    : /regions/europe/providers/Microsoft.PowerPlatform/enterprisePolicies/d3e06308-e287-42bb-ad6d-a588ef77d6e8
        linkStatus  : Linked
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will get all Enterprise Policy informations from the Dataverse environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentLinkEnterprisePolicy {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (mandatory = $true)]
        [string] $EnvironmentId,

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

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        $body = [PsCustomObject]@{
            "SystemId" = $EnterprisePolicyResourceId
        } | ConvertTo-Json

        # 2019-10-01
        $uriLinkEnterprisePolicy = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$EnvironmentId`?api-version=2024-05-01"

        $resObj = Invoke-RestMethod -Method Get -Uri $uriLinkEnterprisePolicy -Headers $headersBapApi -Body $body -ContentType "application/json"

        $resCol = @(
            if ($null -ne $resObj.properties.enterprisePolicies) {
                foreach ($prop in $resObj.properties.enterprisePolicies.psobject.Properties) {
                    $enterprisePolicyObj = [ordered]@{
                        PpacEnvId   = $envObj.PpacEnvId
                        PpacEnvName = $envObj.PpacEnvName
                        Type        = $prop.Name
                    }

                    foreach ($innerProp in $prop.Value.psobject.properties) {
                        $enterprisePolicyObj."$($innerProp.Name)" = $innerProp.Value
                    }
                
                    ([PSCustomObject]$enterprisePolicyObj) | Select-PSFObject -TypeName "D365Bap.Tools.Environment.EnterprisePolicy"
                }
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapEnvironmentLinkEnterprisePolicy"
            return
        }

        $resCol
    }
    
    end {
        
    }
}