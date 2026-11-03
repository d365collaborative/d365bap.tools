<#
    .SYNOPSIS
        Delete an environment classic DLP policy.

    .DESCRIPTION
        Deletes an environment-scoped classic data loss prevention policy
        through the Business App Platform API.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Remove-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Deletes the environment DLP policy.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Remove-PpacEnvironmentDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		$objRoute = Get-PpacEnvironmentDlpRoute -EnvironmentId $EnvironmentId
		$routeEnvironmentId = $objRoute.RouteId
		if ([string]::IsNullOrWhiteSpace($routeEnvironmentId)) {
			Stop-PSFFunction -Message "No environment matched '$EnvironmentId'."
			return
		}

		$colCurrent = @(Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId `
				-PolicyId $PolicyId)

		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No environment DLP policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple environment DLP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = "Delete DLP policy from '$($objRoute.Name)'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$objSecureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			Authorization = "Bearer $tokenValue"
		}

		$apiVersion = $script:BapApiVersions.ClassicBap
		$uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/{0}/apiPolicies/{1}?api-version={2}' `
			-f $routeEnvironmentId,
		$colCurrent[0].PolicyId,
		$apiVersion

		try {
			Invoke-RestMethod -Method Delete `
				-Uri $uri `
				-Headers $hashHeaders `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to delete the environment DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the environment DLP delete request failed." `
				-Exception $_.Exception

			return
		}
	}
}
