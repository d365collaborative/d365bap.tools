
<#
    .SYNOPSIS
        Query an OData entity from a Power Platform / Dataverse environment.

    .DESCRIPTION
        Invokes a GET request against the Dataverse Web API OData endpoint for the specified entity, handling authentication, optional query filters, and automatic pagination via nextLink traversal.

        Includes built-in retry logic for 429 (Too Many Requests) responses.

    .PARAMETER EnvironmentId
        The ID of the environment to query.

        Can be either the environment name or the environment GUID (PPAC).

    .PARAMETER Entity
        The OData entity (plural name) to query, e.g. "accounts" or "systemusers".

    .PARAMETER ODataQuery
        An optional OData query string to append to the request, e.g. "`$filter=statecode eq 0&`$select=name,accountid".

        Do not include the leading "?".

    .PARAMETER TraverseNextLink
        Instructs the cmdlet to follow "@odata.nextLink" pagination and accumulate all pages into the result.

        Must be used together with the NextLink parameter set.

    .PARAMETER ThrottleSeed
        When specified, introduces a random delay between 1 and ThrottleSeed seconds after each page request to reduce throttling risk.

        Only valid when TraverseNextLink is also specified.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved records to an Excel file.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts"

        This command retrieves all records from the accounts entity in the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "systemusers" -ODataQuery "`$filter=isdisabled eq false&`$select=fullname,systemuserid"

        This command retrieves all enabled system users, returning only the fullname and systemuserid fields.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink

        This command retrieves all records from the accounts entity, following pagination links until all pages are returned.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink -ThrottleSeed 3

        This command retrieves all pages from the accounts entity, pausing between 1 and 3 seconds between each page request to reduce the risk of throttling.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -AsExcelOutput

        This command retrieves all records from the accounts entity in the environment "ContosoEnv" and exports the results to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpeOdata {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
        [string] $Entity,

        [string] $ODataQuery,

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

        $baseUri = $envObj.PpacEnvUri.TrimEnd('/')

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        [System.UriBuilder] $odataEndpoint = $baseUri
        $odataEndpoint.Path = "/api/data/v9.2/$Entity"

        if (-not ([string]::IsNullOrEmpty($ODataQuery))) {
            $odataEndpoint.Query = "$ODataQuery"
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
                    -Headers $headersWebApi

                $429Attempts = 0
                $resArray.AddRange($resGet.Value)

                if ($resGet.'@odata.nextLink') {
                    $localUri = $resGet.'@odata.nextLink'
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
            $res | Export-Excel -WorksheetName "Get-PpeOdata"
            return
        }

        $res
    }

    end {

    }
}
