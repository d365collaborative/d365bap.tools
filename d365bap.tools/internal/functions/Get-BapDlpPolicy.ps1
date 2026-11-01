<#
    .SYNOPSIS
        Retrieves classic DLP policies from the platform API.

    .DESCRIPTION
        Reads every classic data loss prevention policy visible to the current
        sign-in. Adds PolicyScope and EnvironmentIds to each policy for scope
        filtering.

    .EXAMPLE
        PS C:\> Get-BapDlpPolicy

        Returns every classic DLP policy with its scope annotation.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-BapDlpPolicy {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param ()

	$secureToken = Get-BapAccessToken -Bap
	$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
	$hashHeaders = @{
		Authorization = "Bearer $tokenValue"
	}

	$uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies?api-version=2018-10-01'
	$colPolicies = [Collections.Generic.List[object]]::new()
	$colVisited = [Collections.Generic.HashSet[string]]::new()

	do {
		$response = Invoke-RestMethod -Method Get -Uri $uri -Headers $hashHeaders -ErrorAction Stop

		foreach ($itemPolicy in @($response.value)) {
			$colPolicies.Add($itemPolicy)
		}

		$nextLink = "$($response.nextLink)"
		if ([string]::IsNullOrWhiteSpace($nextLink)) {
			$nextLink = "$($response.'@odata.nextLink')"
		}

		if (-not [string]::IsNullOrWhiteSpace($nextLink) -and -not $colVisited.Add($nextLink)) {
			throw 'The DLP policy API returned a repeated continuation URL.'
		}

		$uri = $nextLink
	} while (-not [string]::IsNullOrWhiteSpace($uri))

	$colPolicies.ToArray()
}
