
<#
    .SYNOPSIS
        Sets the details for a specific tenant.
        
    .DESCRIPTION
        This function allows you to set the details for a specific tenant, including the user principal name (UPN), tenant ID, and tenant name.
        
        It enables you to switch between different tenants easily.
        
    .PARAMETER Id
        The id of the registered tenant.
        
        Used to have user defined name for tenants.
        
    .PARAMETER Upn
        The user principal name (UPN) of the tenant.
        
    .PARAMETER TenantId
        The unique identifier for the tenant.
        
    .PARAMETER TenantName
        The friendly name of the tenant.
        
    .EXAMPLE
        PS C:\> Set-BapTenantDetail -Id "Contoso" -Upn "user@contoso.com" -TenantId "12345678-1234-1234-1234-123456789012" -TenantName "ContosoUnlimited"
        
        This will set the details for the tenant with the id "Contoso".
        It will associate the UPN "user@contoso.com" with the tenant.
        It will also set the tenant ID to "12345678-1234-1234-1234-123456789012" and the friendly name to "ContosoUnlimited".
        
    .EXAMPLE
        PS C:\> Get-BapTenant -TenantId "12345678-1234-1234-1234-123456789012" | Set-BapTenantDetail -Id "Contoso"
        
        This will retrieve the tenant with the specified tenant ID.
        It will then set the details for the tenant with the id "Contoso" using the retrieved UPN and tenant ID.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapTenantDetail {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Login")]
        [Alias("User")]
        [Alias("Username")]
        [string] $Upn,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $TenantId,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("FriendlyName")]
        [string] $TenantName
    )

    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $details = [PSCustomObject][ordered]@{
            Id           = $Id
            User         = $($Upn)
            Tenant       = $($TenantId)
            FriendlyName = $($TenantName)
        }
        
        $hashTenants = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.tenant.details")
        $hashTenants."$Id" = $details

        Set-PSFConfig -FullName "d365bap.tools.tenant.details" -Value $hashTenants
        Register-PSFConfig -FullName "d365bap.tools.tenant.details" -Scope UserDefault
    }
}