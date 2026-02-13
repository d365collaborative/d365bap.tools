
<#
    .SYNOPSIS
        Get user details from Microsoft Graph based on UPN or ObjectId.
        
    .DESCRIPTION
        Enables the user to get user details from Microsoft Graph based on UPN or ObjectId. This is used in multiple places across the functions to get details about users in Azure AD / Entra ID.
        
    .PARAMETER Upn
        The User Principal Name (UPN) or ObjectId of the user to retrieve from Microsoft Graph.
        
    .EXAMPLE
        PS C:\> Get-GraphUser -Upn "alice@contoso.com"
        
        This will retrieve the user details for the user with the UPN "alice@contoso.com".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphUser {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $Upn
    )
    
    end {
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
        }

        if (Test-Guid -InputObject $Upn) {
            # Validate that the Service Principal exists in Azure AD / Entra ID
            $uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=id eq '$Upn'"
        }
        else {
            $uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=startswith(userPrincipalName, '$Upn') or startswith(mail, '$Upn')"
        }

        $colUsers = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi 4> $null | `
            Select-Object -ExpandProperty Value

        if ($colUsers.Count -eq 0) {
            $messageString = "The supplied ObjectId / Service Principal: <c='em'>$Upn</c> didn't return any matching Service Principal in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Service Principal was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        if ($colUsers.Count -gt 1) {
            $messageString = "The supplied ObjectId / Service Principal: <c='em'>$Upn</c> returned multiple matching Service Principals in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Service Principals were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colUsers[0]
    }
}