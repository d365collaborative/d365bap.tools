
<#
    .SYNOPSIS
        Query an OData entity from a Finance and Operations environment.
        
    .DESCRIPTION
        Invokes a GET request against the Finance and Operations OData endpoint for the specified entity, handling authentication, optional query filters, cross-company access, and automatic pagination via nextLink traversal.
        
        Includes built-in retry logic for 429 (Too Many Requests) responses.
        
    .PARAMETER EnvironmentId
        The ID of the environment to query.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Entity
        The OData entity name to query, e.g. "SysAADClients" or "SystemUsers".
        
    .PARAMETER ODataQuery
        An optional OData query string to append to the request, e.g. "`$filter=IsActive eq true&`$select=UserId,Name".
        
        Do not include the leading "?".
        
    .PARAMETER CrossCompany
        Instructs the cmdlet to append "cross-company=true" to the request, returning records across all legal entities.
        
    .PARAMETER TraverseNextLink
        Instructs the cmdlet to follow "@odata.nextLink" pagination and accumulate all pages into the result.
        
        Must be used together with the NextLink parameter set.
        
    .PARAMETER ThrottleSeed
        When specified, introduces a random delay between 1 and ThrottleSeed seconds after each page request to reduce throttling risk.
        
        Only valid when TraverseNextLink is also specified.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved records to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients"
        
        This command retrieves all records from the SysAADClients OData entity in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -ODataQuery "`$filter=IsActive eq true"
        
        This command retrieves all active system users from the environment "ContosoEnv" using an OData filter.
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -CrossCompany
        
        This command retrieves system users across all legal entities in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink
        
        This command retrieves all records from the SysAADClients entity, following pagination links until all pages are returned.
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink -ThrottleSeed 3
        
        This command retrieves all pages from the SysAADClients entity, pausing between 1 and 3 seconds between each page request to reduce the risk of throttling.
        
    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -AsExcelOutput
        
        This command retrieves all records from the SysAADClients entity in the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdata {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Parameter(ParameterSetName = "NextLink")]
        [string] $Entity,

        [string] $ODataQuery,

        [switch] $CrossCompany,

        [Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
        [switch] $TraverseNextLink,

        [Parameter(ParameterSetName = "NextLink")]
        [int] $ThrottleSeed,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        [System.UriBuilder] $odataEndpoint = $baseUri
        $odataEndpoint.Path = "/data/$Entity"

        if (-not ([string]::IsNullOrEmpty($ODataQuery))) {
            $odataEndpoint.Query = "$ODataQuery"
        }
        
        if ($CrossCompany) {
            $odataEndpoint.Query = $($odataEndpoint.Query + "&cross-company=true").Replace("?", "")
        }

        [System.Collections.Generic.List[System.Object]] $resArray = @()

        $localUri = $odataEndpoint.Uri.AbsoluteUri

        $429Attempts = 0
        $maxRetries = 3

        do {
            $429Retry = $false

            try {
                $resGet = Invoke-RestMethod -Method Get `
                    -Uri $localUri `
                    -Headers $headersFnO

                $429Attempts = 0
                $resArray.AddRange($resGet.Value)

                if ($($resGet.'@odata.nextLink') -match ".*(/data/.*)") {
                    $localUri = "$baseUri$($Matches[1])"
                }

                if ($ThrottleSeed) {
                    Start-Sleep -Seconds $(Get-Random -Minimum 1 -Maximum $ThrottleSeed)
                }
            }
            catch [System.Net.WebException] {
                if ($_.exception.response.statuscode -eq 429) {
                    $429Retry = $true
                    $429Attempts++

                    $retryWaitSec = $_.exception.response.Headers["Retry-After"]

                    if (-not ($retryWaitSec -gt 0)) {
                        $retryWaitSec = 10
                    }

                    Write-PSFMessage -Level Host -Message "Hit a 429 status code. Will wait for: <c='em'>$retryWaitSec</c> seconds before trying again. Attempt (<c='em'>$429Attempts</c> of <c='em'>$maxRetries</c>)"

                    if ($429Attempts -ge $maxRetries) {
                        Write-PSFMessage -Level Warning -Message "Reached maximum of <c='em'>$maxRetries</c> retry attempts due to throttling. Returning <c='em'>$($resArray.Count)</c> collected records."
                        break
                    }

                    Start-Sleep -Seconds $retryWaitSec
                }
                else {
                    Throw
                }
            }

        } while ($429Retry -or ($TraverseNextLink -and $resGet.'@odata.nextLink'))

        if ($resArray.Count -gt 0) {
            $res = $resArray.ToArray()
        }

        if ($AsExcelOutput) {
            $res | Export-Excel -WorksheetName "Get-FscmOdata"
            return
        }

        $res
        
    }
    
    end {
        
    }
}