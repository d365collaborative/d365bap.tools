<#
.SYNOPSIS
Gets detailed information about a BAP tenant.

.DESCRIPTION
This function retrieves detailed information about a BAP tenant stored in the local PSFramework configuration.

.PARAMETER Id
The id of the registered tenant.

Used to have user defined name for tenants.

.PARAMETER Upn
The User Principal Name (UPN) of the user.

.PARAMETER TenantId
The unique identifier of the tenant.

.PARAMETER FriendlyName
The friendly name of the tenant.

.PARAMETER AsExcelOutput
Instructs the function to export the results to an Excel file.

.EXAMPLE
PS C:\> Get-BapTenantDetail

This will retrieve all available BAP tenant details stored in the local PSFramework configuration.

.EXAMPLE
PS C:\> Get-BapTenantDetail -Id "Contoso"
This will retrieve the BAP tenant detail for the specified tenant id.
It will only return results where the tenant id matches "Contoso".

.EXAMPLE
PS C:\> Get-BapTenantDetail -Upn "user@contoso.com"
This will retrieve the BAP tenant detail for the specified user principal name (UPN).
It will only return results where the UPN matches "user@contoso.com".

.EXAMPLE
PS C:\> Get-BapTenantDetail -TenantId "12345678-90ab-cdef-1234-567890abcdef"
This will retrieve the BAP tenant detail for the specified tenant id.
It will only return results where the tenant id matches "12345678-90ab-cdef-1234-567890abcdef".

.EXAMPLE
PS C:\> Get-BapTenantDetail -FriendlyName "Contoso"
This will retrieve the BAP tenant detail for the specified friendly name.
It will only return results where the friendly name matches "Contoso".

.EXAMPLE
PS C:\> Get-BapTenantDetail -AsExcelOutput

This will export the retrieved BAP tenant details to an Excel file.

.NOTES
Author: Mötz Jensen (@Splaxi)

#>
function Get-BapTenantDetail {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $Id = "*",
        
        [Alias("Login")]
        [Alias("User")]
        [Alias("Username")]
        [string] $Upn = "*",

        [string] $TenantId = "*",

        [string] $FriendlyName = "*",

        [switch] $AsExcelOutput
    )

    begin {
        
    }
    
    process {
        $hashTenants = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.tenant.details")
        
        $resCol = @(
            foreach ($key in $hashTenants.Keys) {
                $obj = $hashTenants."$key"
                
                if (-not ($obj.Id -like $Id)) { continue }
                if (-not ($obj.User -like $Upn)) { continue }
                if (-not ($obj.Tenant -like $TenantId)) { continue }
                if (-not ($obj.FriendlyName -like $FriendlyName)) { continue }
                
                $obj | Select-PSFObject -TypeName "D365Bap.Tools.TenantDetail" `
                    -Property *
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