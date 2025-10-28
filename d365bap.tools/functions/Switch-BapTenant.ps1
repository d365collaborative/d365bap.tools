<#
.SYNOPSIS
Switches the current context to a specified BAP tenant.

.DESCRIPTION
This function allows you to switch the current context to a specified BAP tenant based on the tenant details stored in the local PSFramework configuration.

.PARAMETER Id
The ID of the BAP tenant to switch to.

.EXAMPLE
PS C:\> Switch-BapTenant -Id "Contoso"

This will switch the current context to the BAP tenant with the id "Contoso".
It will ensure that the authentication token is valid, prompting for re-authentication if necessary.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Switch-BapTenant {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id
    )

    begin {
        
    }
    
    process {
        $hashTenants = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.tenant.details")
        
        if ($null -eq $hashTenants."$Id") {
            $messageString = "No tenant details found for Id <c='em'>$Id</c>. Please add the tenant details using <c='em'>Set-BapTenantDetail</c> first."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because tenant was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        $obj = $hashTenants."$Id"
        $contextObj = (Get-AzContext -ListAvailable | Where-Object { $_.tenant.id -eq $obj.Tenant } | Where-Object { $_.Account.Id -eq $obj.User })

        Select-AzContext -InputObject $contextObj > $null

        $fake = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction SilentlyContinue).Token
        
        if ([string]::IsNullOrWhiteSpace($fake)) {
            Write-PSFMessage -Level Host -Message "It seems that your credentials/cache has <c='sub'>expired</c>. Will force an authentication prompt for the <c='em'>$($obj.User)</c>." -Target Host
            
            Start-Sleep -Seconds 2
            Connect-AzAccount -Tenant $obj.Tenant -AccountId $obj.User
        }
    }
    
    end {
        
    }
}