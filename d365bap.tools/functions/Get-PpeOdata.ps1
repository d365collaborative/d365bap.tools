
<#
    .SYNOPSIS
        Queries a Dataverse OData entity from Power Platform.

    .DESCRIPTION
        Sends a GET request to the Dataverse Web API OData endpoint and returns the
        matching records. Handles authentication, query filters, nextLink pagination,
        and automatic retries for throttled requests.

    .PARAMETER EnvironmentId
        Environment name or environment GUID (PPAC).

    .PARAMETER Entity
        The OData entity collection name to query, e.g. "accounts" or "systemusers".

    .PARAMETER ODataQuery
        Optional query string without the leading "?", e.g. '$filter=statecode eq 0'.

    .PARAMETER TraverseNextLink
        Follows "@odata.nextLink" pagination and accumulates every page in the result.

    .PARAMETER ThrottleSeed
        Random delay in seconds, between 1 and this value, after each page request.

    .PARAMETER AsExcelOutput
        Exports the retrieved records to an Excel file instead of the pipeline.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts"

        Retrieves every record from one OData entity.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "accounts" entity set.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "systemusers" -ODataQuery "`$filter=isdisabled eq false&`$select=fullname,systemuserid"

        Retrieves only enabled system users with two selected fields.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "systemusers" entity set.
        It uses -ODataQuery to send the filter and select expressions.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink

        Follows pagination links until every page is returned.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "accounts" entity set.
        It uses -TraverseNextLink to request all pages.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink -ThrottleSeed 3

        Pauses between pages to reduce the risk of throttling.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "accounts" entity set.
        It uses -TraverseNextLink to request all pages.
        It uses -ThrottleSeed 3 to wait up to three seconds between pages.

    .EXAMPLE
        PS C:\> Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -AsExcelOutput

        Exports every retrieved record to an Excel file.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "accounts" entity set.
        It uses -AsExcelOutput to write the records to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpeOdata {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "OData is the name of the protocol.")]
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType([PSCustomObject])]
	param (
		[Parameter (Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true, ParameterSetName = "Default")]
		[Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
		[ValidateNotNullOrEmpty()]
		[string] $Entity,

		[string] $ODataQuery,

		[Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
		[switch] $TraverseNextLink,

		[Parameter(ParameterSetName = "NextLink")]
		[int] $ThrottleSeed,

		[switch] $AsExcelOutput
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.PpacEnvUri.TrimEnd('/')

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenWebApiValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeadersWebApi = @{
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
					-Headers $hashHeadersWebApi

				$429Attempts = 0
				$resArray.AddRange($resGet.Value)

				if ($resGet.'@odata.nextLink') {
					$localUri = $resGet.'@odata.nextLink'
				}

				if ($ThrottleSeed) {
					$tmpThrottleDelay = Get-Random -Minimum 1 `
						-Maximum $ThrottleSeed

					Start-Sleep -Seconds $tmpThrottleDelay
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

					Write-PSFMessage -Level Host `
						-Message "Hit a 429 status code. Will wait for: <c='em'>$retryWaitSec</c> seconds before trying again. Attempt (<c='em'>$429Attempts</c> of <c='em'>$maxRetries</c>)"

					if ($429Attempts -ge $maxRetries) {
						Write-PSFMessage -Level Warning `
							-Message "Reached maximum of <c='em'>$maxRetries</c> retry attempts due to throttling. Returning <c='em'>$($resArray.Count)</c> collected records."

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
			$res |
			Export-Excel -WorksheetName "Get-PpeOdata"
			return
		}

		$res
	}

	end {

	}
}
