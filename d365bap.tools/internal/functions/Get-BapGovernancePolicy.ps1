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
	[OutputType('System.Object[]')]
	param ()

	$secureToken = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com/'
	$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
	$headers = @{
		Authorization = "Bearer $tokenValue"
		Accept        = 'application/json'
	}

	$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
	$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies?api-version=$apiVersion"
	$policies = [Collections.Generic.List[object]]::new()
	$visited = [Collections.Generic.HashSet[string]]::new()

	do {
		$response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
		foreach ($policy in @($response.value)) { $policies.Add($policy) }

		$nextLink = "$($response.'@odata.nextLink')"
		if ([string]::IsNullOrWhiteSpace($nextLink)) { $nextLink = "$($response.nextLink)" }

		if (-not [string]::IsNullOrWhiteSpace($nextLink) -and -not $visited.Add($nextLink)) {
			throw 'The governance policy API returned a repeated continuation URL.'
		}

		$uri = $nextLink
	} while (-not [string]::IsNullOrWhiteSpace($uri))

	$policies
}
