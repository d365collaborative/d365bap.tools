
<#
    .SYNOPSIS
        Get Business Units from Environment.
        
    .DESCRIPTION
        Fetches all Business Units from the CRM / Dataverse environment.
        
    .PARAMETER BaseUri
        Base Web API URI for the environment.
        
        Used to construct the correct REST API Url, based on the WebApi / OData endpoint
        
    .EXAMPLE
        PS C:\> Get-CrmBusinessUnit -BaseUri 'https://temp-test.crm4.dynamics.com'
        
        This will fetch all Business Units from the CRM / Dataverse environment.
        Uses the WebAPI / OData endpoint.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-CrmBusinessUnit {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
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
        $colBuRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/businessunits?$expand=business_unit_parent_business_unit') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colBu = $colBuRaw

        $colBu | Select-PSFObject -TypeName "D365Bap.Tools.BusinessUnit" -Property "businessunitid as Id",
        Name,
        @{Name = "IsRoot"; Expression = { $null -eq $_._parentbusinessunitid_value } },
        @{Name = "ParentId"; Expression = { $_._parentbusinessunitid_value } },
        @{Name = "ParentName"; Expression = {
                $tmpId = $_._parentbusinessunitid_value;
                ($colBuRaw | `
                    Where-Object { $_.businessunitid -eq $tmpId }
                    ).name
            }
        },
        "_organizationid_value as OrganizationId"
    }
}