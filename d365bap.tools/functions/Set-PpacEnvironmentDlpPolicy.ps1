<#
    .SYNOPSIS
        Update an environment classic DLP policy.

    .DESCRIPTION
        Updates an environment-scoped classic data loss prevention definition
        through the Business App Platform API.

        The supplied body is passed through to the service.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .PARAMETER Policy
        Replacement policy body as a hashtable or PSCustomObject.

    .EXAMPLE
        PS C:\> Set-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111" -Policy @{ displayName = "Environment baseline"; environmentType = "SingleEnvironment" }

        Replaces the environment DLP policy body.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.
        It uses -Policy to pass the replacement body.

    .NOTES
        Author: d365bap.tools contributors
#>
function Set-PpacEnvironmentDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object] $Policy
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$objRoute = Get-PpacEnvironmentDlpRoute -EnvironmentId $EnvironmentId
		$routeEnvironmentId = $objRoute.RouteId
		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			Stop-PSFFunction -Message "No environment matched '$EnvironmentId'."
			return
		}

		$colCurrent = @(Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No environment DLP policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple environment DLP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = "Update DLP policy in '$($objRoute.Name)'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$secureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$routeEnvironmentId/apiPolicies/$($colCurrent[0].PolicyId)?api-version=2018-10-01"

		try {
			$null = Invoke-RestMethod -Method Patch -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
			} -Body ($Policy | ConvertTo-Json -Depth 20) -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to update the environment DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the environment DLP update request failed." -Exception $_.Exception
			return
		}

		Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId -PolicyId $colCurrent[0].PolicyId
	}
}
