
<#
    .SYNOPSIS
        Queries a Finance and Operations OData entity.

    .DESCRIPTION
        Sends a GET request to the Finance and Operations OData endpoint and returns the
        matching records. Handles authentication, query filters, cross-company access,
        nextLink pagination, and automatic retries for throttled requests.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Entity
        The OData entity collection name to query, e.g. "SysAADClients".

    .PARAMETER ODataQuery
        Optional query string without the leading "?", e.g. '$filter=IsActive eq true'.

    .PARAMETER CrossCompany
        Adds "cross-company=true" so records from all legal entities are returned.

    .PARAMETER TraverseNextLink
        Follows "@odata.nextLink" pagination and accumulates every page in the result.

    .PARAMETER ThrottleSeed
        Random delay in seconds, between 1 and this value, after each page request.

    .PARAMETER AsExcelOutput
        Exports the retrieved records to an Excel file instead of the pipeline.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients"

        Retrieves every record from one OData entity.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SysAADClients" entity set.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -ODataQuery "`$filter=IsActive eq true"

        Retrieves only active system users through a query filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SystemUsers" entity set.
        It uses -ODataQuery to send the filter expression.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -CrossCompany

        Retrieves system users across all legal entities.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SystemUsers" entity set.
        It uses -CrossCompany to include every legal entity.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink

        Follows pagination links until every page is returned.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SysAADClients" entity set.
        It uses -TraverseNextLink to request all pages.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink -ThrottleSeed 3

        Pauses between pages to reduce the risk of throttling.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SysAADClients" entity set.
        It uses -TraverseNextLink to request all pages.
        It uses -ThrottleSeed 3 to wait up to three seconds between pages.

    .EXAMPLE
        PS C:\> Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -AsExcelOutput

        Exports every retrieved record to an Excel file.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity to select the "SysAADClients" entity set.
        It uses -AsExcelOutput to write the records to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdata {
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

		[switch] $CrossCompany,

		[Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
		[switch] $TraverseNextLink,

		[Parameter(ParameterSetName = "NextLink")]
		[int] $ThrottleSeed,

		[switch] $AsExcelOutput
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeadersFnO = @{
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
					-Headers $hashHeadersFnO

				$429Attempts = 0
				$resArray.AddRange($resGet.Value)

				if ($($resGet.'@odata.nextLink') -match ".*(/data/.*)") {
					$localUri = "$baseUri$($Matches[1])"
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
			Export-Excel -WorksheetName "Get-FscmOdata"
			return
		}

		$res
	}

	end {

	}
}
