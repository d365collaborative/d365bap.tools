
<#
    .SYNOPSIS
        Get the tenant default provisioning language and currency per location.
        
    .DESCRIPTION
        Retrieves the tenant default language and currency for Power Platform
        environment provisioning, resolved live through the bundled Power
        Platform SDK.
        
        Tenant defaults are tenant specific and are never served from the
        provisioning cache. One row is returned per matched location.
        
    .PARAMETER Location
        The deployment location to resolve tenant defaults for.
        
        Accepts a location name (e.g. "europe") or display name (e.g.
        "Europe"). Supports wildcard characters (*). Defaults to all
        locations.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacTenantProvisioningDefault
        
        This will return the tenant default language and currency for all locations.
        
    .EXAMPLE
        PS C:\> Get-PpacTenantProvisioningDefault -Location "europe"
        
        This will return the tenant default language and currency for the "europe" location.
        
    .EXAMPLE
        PS C:\> Get-PpacTenantProvisioningDefault -Location "europe*" -AsExcelOutput
        
        This will return the tenant default language and currency for matching locations.
        It will output the results directly into an Excel file, that will automatically open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacTenantProvisioningDefault {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [SupportsWildcards()]
        [string] $Location = "*",

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $matchedLocations = @($script:ProvisioningCache.locations | Where-Object {
                ($_.name -like $Location -or $_.name -eq $Location) `
                    -or ($_.displayName -like $Location -or $_.displayName -eq $Location)
            } | Sort-Object -Property name -Unique)

        if (-not $matchedLocations) {
            $valid = @($script:ProvisioningCache.locations | ForEach-Object { $_.name } | Sort-Object -Unique)
            Stop-PSFFunction -Message "Unknown location '$Location'. Valid values: $($valid -join ', ')."
            return
        }

        $resCol = @(
            foreach ($locationEntry in $matchedLocations) {
                $tenantDefault = Get-ProvisioningLocationDefault -Location $locationEntry.name -Token $tokenPowerApiValue

                if (-not $tenantDefault) {
                    Write-PSFMessage -Level Warning -Message "No tenant default language or currency reported for location '$($locationEntry.name)'. Skipping."
                    continue
                }

                $tenantDefault | Add-Member -NotePropertyName "IsDefault" -NotePropertyValue ([bool]$locationEntry.isDefault) -Force

                $tenantDefault
            }
        )

        $resCol = @($resCol | Select-PSFObject -TypeName "D365Bap.Tools.PpacTenantProvisioningDefault" `
                -Property "Location as Location",
            "BaseLanguage as BaseLanguage",
            "LanguageName as LanguageName",
            "CurrencyCode as CurrencyCode",
            "CurrencySymbol as CurrencySymbol",
            "IsDefault as IsDefault")

        if ($AsExcelOutput) {
            if ($resCol) {
                $resCol | Export-Excel -WorksheetName "Get-PpacTenantProvisioningDefault" `
                    -WarningAction SilentlyContinue
            }
            return
        }

        $resCol
    }
    
    end {
        
    }
}
