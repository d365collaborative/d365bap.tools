
<#
    .SYNOPSIS
        Get the tenant default provisioning language and currency per location.
        
    .DESCRIPTION
        Retrieves the tenant default language and currency for Power Platform
        environment provisioning, resolved live through the bundled Power
        Platform SDK.
        
        Tenant defaults are tenant specific and are never served from the
        provisioning cache. One row is returned per matched default location.
        
    .PARAMETER Location
        The deployment location to resolve tenant defaults for.
        
        Accepts a location name (e.g. "europe") or display name (e.g.
        "Europe"). Supports wildcard characters (*). Defaults to all
        locations. Only default locations are returned, looked up live
        for the current login.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacTenantProvisioningDefault
        
        This will return the tenant default language and currency for the default location.
        
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
        $secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
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

        # Default flags differ per tenant, so they are never cached. Look
        # the default locations up live for the current login.
        $base = 'https://api.powerplatform.com'
        $api = $script:BapSdkApiVersion

        $liveLocations = Invoke-BapSdkRequest `
            -Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.LocationsRequestBuilder' } `
            -Method 'GetAsync' `
            -Token $tokenPowerApiValue `
            -RequestUrl "$base/environmentmanagement/provisioning/locations?api-version=$api"

        $liveDefaultNames = @($liveLocations.collection | Where-Object { $_.isDefault } | ForEach-Object { $_.name })

        $defaultLocations = @($matchedLocations | Where-Object { $_.name -in $liveDefaultNames })

        if (-not $defaultLocations) {
            Write-PSFMessage -Level Warning -Message "None of the matched locations ($(($matchedLocations | ForEach-Object { $_.name }) -join ', ')) is a default provisioning location."
            return
        }

        $resCol = @(
            foreach ($locationEntry in $defaultLocations) {
                $tenantDefault = Get-ProvisioningLocationDefault -Location $locationEntry.name -Token $tokenPowerApiValue

                if (-not $tenantDefault) {
                    Write-PSFMessage -Level Warning -Message "No tenant default language or currency reported for location '$($locationEntry.name)'. Skipping."
                    continue
                }

                $tenantDefault | Add-Member -NotePropertyName "Name" -NotePropertyValue $locationEntry.displayName -Force
                $tenantDefault | Add-Member -NotePropertyName "IsDefault" -NotePropertyValue $true -Force

                $tenantDefault
            }
        )

        $resCol = @($resCol | Select-PSFObject -TypeName "D365Bap.Tools.PpacTenantProvisioningDefault" `
                -Property "Location as Location",
            "Name as Name",
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
