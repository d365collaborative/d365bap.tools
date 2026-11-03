<#
    .SYNOPSIS
        Retrieves governance rule-based policies.

    .DESCRIPTION
        Reads every governance rule-based policy visible to the current
        sign-in through the Power Platform API.

    .EXAMPLE
        PS C:\> Get-BapGovernancePolicy

        Returns every governance rule-based policy definition.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-BapGovernancePolicy {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param ()

	$objSecureToken = Get-BapAccessToken -PowerPlatform
	$tokenValue = ConvertFrom-SecureString -AsPlainText `
		-SecureString $objSecureToken

	$hashHeaders = @{
		Authorization = "Bearer $tokenValue"
		Accept        = 'application/json'
	}

	$apiVersion = $script:BapApiVersions.PowerPlatform
	$uri = 'https://api.powerplatform.com/governance/ruleBasedPolicies?api-version={0}' `
		-f $apiVersion

	$colPolicies = [Collections.Generic.List[object]]::new()
	$colVisited = [Collections.Generic.HashSet[string]]::new()

	do {
		$response = Invoke-RestMethod -Method Get `
			-Uri $uri `
			-Headers $hashHeaders `
			-ErrorAction Stop

		$colPolicies.AddRange(@($response.value))

		$nextLink = "$($response.'@odata.nextLink')"
		if ([string]::IsNullOrWhiteSpace($nextLink)) { $nextLink = "$($response.nextLink)" }

		if ((-not [string]::IsNullOrWhiteSpace($nextLink)) `
				-and (-not $colVisited.Add($nextLink))) {
			throw 'The governance policy API returned a repeated continuation URL.'
		}

		$uri = $nextLink
	} while (-not [string]::IsNullOrWhiteSpace($uri))

	$colPolicies.ToArray()
}
