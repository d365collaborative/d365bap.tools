
<#
    .SYNOPSIS
        Get a User from Azure AD / Entra ID.
        
    .DESCRIPTION
        Retrieves a User from Azure AD / Entra ID based on the supplied ObjectId, display name, UPN or mail.
        
    .PARAMETER User
        The ObjectId, display name, UPN or mail of the User in Azure AD / Entra ID.
        
    .EXAMPLE
        PS C:\> Get-GraphUser -User "john@contoso.com"
        
        This will retrieve the User with the specified ObjectId, display name, UPN or mail from Azure AD / Entra ID.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphUser {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [Alias('EntraUser')]
        [string] $User
    )
    
    end {
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        if (Test-Guid -InputObject $User) {
            # Validate that the user exists in Azure AD / Entra ID
            $uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=id eq '$User'"
        }
        else {
            $uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=startswith(displayName, '$User') or startswith(userPrincipalName, '$User') or startswith(mail, '$User')"
        }

        $colUsers = @(Invoke-RestMethod -Method Get `
                -Uri $uriGraph `
                -Headers $headersGraphApi 4> $null | `
                Select-Object -ExpandProperty Value)

        if ($colUsers.Count -eq 0) {
            $messageString = "The supplied ObjectId / Entra User: <c='em'>$User</c> didn't return any matching User in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because User was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        if ($colUsers.Count -gt 1) {
            $messageString = "The supplied ObjectId / Entra User: <c='em'>$User</c> returned multiple matching Users in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Users were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colUsers[0]
    }
}