
<#
    .SYNOPSIS
        Removes tenant details for a specified BAP tenant from the local configuration.
        
    .DESCRIPTION
        This function allows you to remove tenant details for a specified BAP tenant from the local PSFramework configuration.
        If the -Force switch is not used, it will return the tenant details for the specified tenant id, allowing you to review them before deciding to remove them.
        
    .PARAMETER Id
        The ID of the BAP tenant whose details are to be removed.
        
    .PARAMETER Force
        Instructs the function to remove the tenant details without prompting for confirmation.
        
    .EXAMPLE
        PS C:\>  Remove-BapTenantDetail -Id "Contoso"
        
        This will show the tenant details for the BAP tenant with the id "Contoso".
        It will NOT remove the tenant details yet, allowing you to review them before deciding to remove them.
        
    .EXAMPLE
        PS C:\>  Remove-BapTenantDetail -Id "Contoso" -Force
        
        This will remove the tenant details for the BAP tenant with the id "Contoso" without prompting for confirmation.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-BapTenantDetail {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [switch] $Force
    )

    begin {
    }

    process {
        $hashTenants = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.tenant.details")

        if ($Force) {
            $hashTenants.Remove($Id) | Out-Null

            Set-PSFConfig -FullName "d365bap.tools.tenant.details" -Value $hashTenants
            Register-PSFConfig -FullName "d365bap.tools.tenant.details" -Scope UserDefault
        }
        else {
            $hashTenants."$Id" | Select-PSFObject -TypeName "D365Bap.Tools.TenantDetail" `
                -Property *
        }
    }
}