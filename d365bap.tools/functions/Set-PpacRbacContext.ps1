
<#
    .SYNOPSIS
        Authenticate for PPAC RBAC operations by obtaining an access token using user credentials.
        
    .DESCRIPTION
        Authenticates for PPAC RBAC operations by obtaining an access token using user credentials. This command is used to set the authentication context for subsequent PPAC RBAC operations in Power Platform.
        
        The command uses the OAuth 2.0 Resource Owner Password Credentials (ROPC) flow to obtain an access token for the Microsoft Graph API, which is then used for authentication in PPAC RBAC operations.
        
    .PARAMETER Username
        The username of the user to authenticate with.
        
    .PARAMETER Password
        The password of the user to authenticate with.
        
    .PARAMETER ImpersonateAppId
        The application (client) id of the app to impersonate when authenticating.
        
        The app needs to be registered in Azure AD and have the necessary API permissions to perform PPAC RBAC operations.
        
        Consent to the permissions for the app needs to be granted by a tenant administrator before running this command.
        
    .EXAMPLE
        PS C:\> Set-PpacRbacContext -Username "alice@contoso.com" -Password "P@ssw0rd!" -ImpersonateAppId "00000000-0000-0000-0000-000000000000"
        
        This command authenticates the user "alice@contoso.com" and sets the authentication context for subsequent PPAC RBAC operations using the specified app for impersonation.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
        Based on:
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Set-PpacRbacContext {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
        [string] $Username,

        [string] $Password,
        
        [string] $ImpersonateAppId
    )
    
    begin {
        $tenantId = (Get-AzContext).Tenant.Id
    }
    
    process {
        $body = @{
            client_id  = $ImpersonateAppId
            scope      = "https://api.powerplatform.com/.default"
            username   = $Username
            password   = $Password
            grant_type = "password"
        }

        $headersToken = @{
            'Content-Type' = "application/x-www-form-urlencoded"
            'Accept'       = "application/json"
        }

        $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

        $resToken = Invoke-RestMethod -Method Post `
            -Uri $uri `
            -Headers $headersToken `
            -Body $body `
            -ContentType $headersToken.'Content-Type' 4> $null

        Set-PSFConfig -FullName "d365bap.tools.internal.ppac.rbac.token" -Value "Bearer $($resToken.access_token)"
    }

    end {
        
    }
    
}