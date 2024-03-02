
<#
    .SYNOPSIS
        Short description
        
    .DESCRIPTION
        Long description
        
    .PARAMETER EnvironmentId
        Parameter description
        
    .PARAMETER AsExcelOutput
        Parameter description
        
    .EXAMPLE
        An example
        
    .NOTES
        General notes
#>
function Get-BapEnvironmentDetails {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [switch] $AsExcelOutput
    )
    
    begin {
        $curUserId = (Get-AzContext).account.id

        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri
        $tokenWebApi = Get-AzAccessToken -ResourceUrl $baseUri
        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApi.Token)"
        }

    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        # Invoke-RestMethod -Method Get -Uri "$baseUri/api/data/v9.2/RetrieveAvailableLanguages()" -Headers $headersWebApi
        # Invoke-RestMethod -Method Get -Uri "$baseUri/api/data/v9.2/RetrieveProvisionedLanguages()" -Headers $headersWebApi

        # $resOrg = @(Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/organizations?$select=organizationid,orgdborgsettings,languagecode,localeid,name') -Headers $headersWebApi)
        # $resOrg.value | ConvertTo-Json -Depth 10

        $resOrg = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/organizations?$select=organizationid,orgdborgsettings,languagecode,localeid,name') -Headers $headersWebApi | Select-Object -ExpandProperty value | Select-Object -First 1
        # $resOrg
        
        $languages = @(Get-EnvironmentLanguage -BaseUri $baseUri)

        $languages | ConvertTo-Json -Depth 10

        # $resUser = Invoke-RestMethod -Method Get -Uri $("$baseUri/api/data/v9.2/systemusers?" + '$select=internalemailaddress&$top=1&$filter=internalemailaddress eq' + " '$curUserId'" + '&$expand=user_settings($select=uilanguageid)') -Headers $headersWebApi
        $resUser = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/systemusers?$select=internalemailaddress&$top=1&$filter=internalemailaddress eq ''{0}''&$expand=user_settings($select=uilanguageid)' -f $curUserId) -Headers $headersWebApi

        # $resUser.value | ConvertTo-Json -Depth 10
    }
    
    end {
        
    }
}