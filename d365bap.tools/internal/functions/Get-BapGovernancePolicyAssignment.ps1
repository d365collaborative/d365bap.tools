<#
    .SYNOPSIS
        Retrieves governance policy assignments.

    .DESCRIPTION
        Reads the rule-based policy assignments for one environment or one
        environment group through the Power Platform API.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .EXAMPLE
        PS C:\> Get-BapGovernancePolicyAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Returns assignments for the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-BapGovernancePolicyAssignment -EnvironmentGroupId "11111111-1111-1111-1111-111111111111"

        Returns assignments for the environment group.
        It uses -EnvironmentGroupId to select the group.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-BapGovernancePolicyAssignment {
	[CmdletBinding(DefaultParameterSetName = 'Environment')]
	[OutputType([PSCustomObject], [object[]])]
	param (
		[Parameter(ParameterSetName = 'Environment', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(ParameterSetName = 'EnvironmentGroup', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId
	)

	$objSecureToken = Get-BapAccessToken -PowerPlatform
	$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $objSecureToken
	$hashHeaders = @{
		Authorization = "Bearer $tokenValue"
		Accept        = 'application/json'
	}

	$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }

	if ($PSCmdlet.ParameterSetName -eq 'EnvironmentGroup') {
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/environmentGroups/$EnvironmentGroupId/assignments?api-version=$apiVersion&includeRuleSetCounts=true"
	}
	else {
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/environments/$EnvironmentId/assignments?api-version=$apiVersion&includeRuleSetCounts=true"
	}

	$response = Invoke-RestMethod -Method Get -Uri $uri -Headers $hashHeaders -ErrorAction Stop
	[object[]]@($response.value)
}
