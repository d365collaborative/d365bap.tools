
<#
    .SYNOPSIS
        Get Business Units from Environment
        
    .DESCRIPTION
        Fetches all Business Units from the environment
        
    .PARAMETER BaseUri
        Base Web API URI for the environment
        
        Used to construct the correct REST API Url, based on the WebApi / OData endpoint
        
    .EXAMPLE
        PS C:\> Get-EnvironmentBusinessUnit -BaseUri 'https://temp-test.crm4.dynamics.com'
        
        This will fetch all Business Units from the environment.
        Uses the WebAPI / OData endpoint.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-EnvironmentBusinessUnit {
    [CmdletBinding()]
    param (
        [Parameter (mandatory = $true)]
        [string] $BaseUri
    )

    begin {
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }

    process {
        $resBusinessUnits = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/businessunits?$expand=business_unit_parent_business_unit') -Headers $headersWebApi

        $resBusinessUnits.value | Select-PSFObject -TypeName "D365Bap.Tools.BusinessUnit" -Property "businessunitid as Id",
        Name,
        @{Name = "ParentId"; Expression = { $_.business_unit_parent_business_unit[0].businessunitid } },
        @{Name = "ParentName"; Expression = { $_.business_unit_parent_business_unit[0].name } },
        "_organizationid_value as OrganizationId"
    }
}