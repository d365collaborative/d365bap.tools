<#
    .SYNOPSIS
        Retrieves FinOps properties for multiple environments.

    .DESCRIPTION
        Requests the FinOps properties of every supplied environment at the same time and returns a lookup keyed by id.

        A failed request yields a null entry, so the caller can report the failure.

    .PARAMETER EnvironmentId
        PPAC environment ids to query.

    .PARAMETER Token
        Bearer token for the Power Platform API.

    .PARAMETER TimeoutSeconds
        Timeout for each request in seconds.

        Default: 30

    .EXAMPLE
        PS C:\> $hashProperties = Get-FinOpsEnvironmentProperty -EnvironmentId $envIds -Token $token

        It will retrieve the FinOps properties for all supplied environments.
        It applies -EnvironmentId to select who is queried.
        It applies -Token to authorize each request.
        It applies -TimeoutSeconds to bound each request; the default is 30 seconds.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FinOpsEnvironmentProperty {
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[string[]] $EnvironmentId,

		[string] $Token,

		[int] $TimeoutSeconds = 30
	)

	$hashResult = @{}

	if (@($EnvironmentId).Count -gt 0) {
		$apiVersion = $script:BapApiVersions.PowerPlatform

		$objHttpClient = [System.Net.Http.HttpClient]::new()
		$objHttpClient.Timeout = [timespan]::FromSeconds($TimeoutSeconds)
		$objHttpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)

		try {
			$hashRequests = @{}

			foreach ($itemId in $EnvironmentId) {
				$uri = 'https://api.powerplatform.com/dynamics/environments/{0}/finopsproperties?api-version={1}' `
					-f $itemId, `
					$apiVersion

				$hashRequests[$itemId] = $objHttpClient.GetStringAsync($uri)
			}

			foreach ($itemId in $hashRequests.Keys) {
				try {
					$tmpJson = $hashRequests[$itemId].GetAwaiter().GetResult()
					$hashResult[$itemId] = $tmpJson |
					ConvertFrom-Json -ErrorAction Stop
				}
				catch {
					$hashResult[$itemId] = $null
					Write-PSFMessage -Level Verbose `
						-Message "FinOps properties unavailable for environment <c='em'>$itemId</c>: $($_.Exception.Message)"
				}
			}
		}
		finally {
			$objHttpClient.Dispose()
		}
	}

	$hashResult
}
