
<#
    .SYNOPSIS
        Retrieves information about the available azure tenant.
        
    .DESCRIPTION
        This function retrieves information about the available azure tenants based on cached credentials in the local Azure PowerShell context.
        
    .PARAMETER Upn
        Specifies the User Principal Name (UPN) of the user account to filter the results.
        
        Supports wildcard patterns.
        
        Defaults to "*" which means all UPNs.
        
    .PARAMETER TenantId
        Specifies the Tenant ID to filter the results.
        
        Supports wildcard patterns.
        
        Defaults to "*" which means all Tenant IDs.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-BapTenant
        
        This will retrieve all available tenants based on cached Azure PowerShell credentials.
        
    .EXAMPLE
        PS C:\> Get-BapTenant -Upn "alex@contoso.com"
        
        This will retrieve the tenant information for the specified UPN.
        It will only return results where the UPN matches "alex@contoso.com".
        
    .EXAMPLE
        PS C:\> Get-BapTenant -TenantId "12345678-90ab-cdef-1234-567890abcdef"
        
        This will retrieve the tenant information for the specified Tenant ID.
        It will only return results where the Tenant ID matches "12345678-90ab-cdef-1234-567890abcdef".
        
    .EXAMPLE
        PS C:\> Get-BapTenant -AsExcelOutput
        
        This will export the retrieved tenant information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
#>
function Get-BapTenant {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Alias("Login")]
        [Alias("User")]
        [Alias("Username")]
        [string] $Upn = "*",

        [string] $TenantId = "*",

        [switch] $AsExcelOutput
    )

    begin {
        $tenantDomains = @(Get-AzDomain)
    }
    
    process {
        $cachedCreds = @(
            (Get-AzContext -ListAvailable | `
                Group-Object Tenant, account) | `
                ForEach-Object { $_.Group[0] }
        )

        $resCol = @(
            foreach ($credObj in $cachedCreds) {
                if (-not ($credObj.Account.Id -like $Upn)) { continue }
                if (-not ($credObj.Tenant.Id -like $TenantId)) { continue }

                $credObj | Select-PSFObject -TypeName "D365Bap.Tools.TenantCredential" `
                    -Property "Account as Upn",
                @{ Name = "TenantId"; Expression = { $_.Tenant.Id } },
                @{ Name = "TenantName"; Expression = { $tenantDomains | Where-Object id -eq $_.Tenant.Id | Select-Object -ExpandProperty name } }
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