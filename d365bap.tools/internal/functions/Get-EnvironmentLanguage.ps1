
<#
    .SYNOPSIS
        Get language from Environment
        
    .DESCRIPTION
        Fetches all languages from the environment
        
    .PARAMETER BaseUri
        Base Web API URI for the environment
        
        Used to construct the correct REST API Url, based on the WebApi / OData endpoint
        
    .EXAMPLE
        PS C:\> Get-EnvironmentLanguage -BaseUri 'https://temp-test.crm4.dynamics.com'
        
        This will fetch all languages from the environment.
        Uses the WebAPI / OData endpoint.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-EnvironmentLanguage {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $BaseUri
    )

    begin {
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }

        $resOrg = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/organizations?$select=organizationid,orgdborgsettings,languagecode,localeid,name') -Headers $headersWebApi | Select-Object -ExpandProperty value | Select-Object -First 1
        $resLangs = Invoke-RestMethod -Method Get -Uri "$BaseUri/api/data/v9.2/languagelocale" -Headers $headersWebApi | Select-Object -ExpandProperty value
    }

    process {
        foreach ($lanObj in $resLangs) {
            if ($lanObj.localeid -eq $resOrg.localeid) {
                # Could also be "languagecode" - maybe we'll get more info later on
                $lanObj | Add-Member -MemberType NoteProperty -Name "BaseLocaleId" -Value 0
            }
        }

        $resLangs
    }
}