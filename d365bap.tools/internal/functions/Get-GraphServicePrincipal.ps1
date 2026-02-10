
<#
    .SYNOPSIS
        Get a Service Principal from Azure AD / Entra ID.
        
    .DESCRIPTION
        Retrieves a Service Principal from Azure AD / Entra ID based on the supplied ObjectId or appId.
        
    .PARAMETER SpId
        The ObjectId or appId of the Service Principal in Azure AD / Entra ID.
        
    .EXAMPLE
        PS C:\> Get-GraphServicePrincipal -SpId "00000000-0000-0000-0000-000000000000"
        
        This will retrieve the Service Principal with the specified ObjectId or appId from Azure AD / Entra ID.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphServicePrincipal {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [Alias('ServicePrincipal')]
        [string] $SpId
    )
    
    end {
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        if (Test-Guid -InputObject $SpId) {
            # Validate that the Service Principal exists in Azure AD / Entra ID
            $uriGraph = "$uriGraphBase`$filter=id eq '$SpId' or appId eq '$SpId'"
        }
        else {
            $uriGraph = "$uriGraphBase`$filter=startswith(displayName, '$SpId')"
        }

        $colSpns = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi | `
            Select-Object -ExpandProperty Value

        if ($colSpns.Count -eq 0) {
            $messageString = "The supplied ObjectId / Service Principal: <c='em'>$SpId</c> didn't return any matching Service Principal in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Service Principal was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        if ($colSpns.Count -gt 1) {
            $messageString = "The supplied ObjectId / Service Principal: <c='em'>$SpId</c> returned multiple matching Service Principals in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Service Principals were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colSpns[0]
    }
}