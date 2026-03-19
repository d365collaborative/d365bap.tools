<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Username
Parameter description

.PARAMETER Password
Parameter description

.PARAMETER ImpersonateAppId
Parameter description

.EXAMPLE
An example

.NOTES
General notes
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