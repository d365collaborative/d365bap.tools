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
	[OutputType('System.Object')]
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
		if (Test-PSFFunctionInterrupt) { return }

		$routeEnvironmentId = Get-PpacEnvironmentDlpRoute -EnvironmentId $EnvironmentId
		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			Stop-PSFFunction -Message "No environment matched '$EnvironmentId'."
			return
		}

		$current = @(Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId -PolicyId $PolicyId)
		if ($current.Count -eq 0) {
			Stop-PSFFunction -Message "No environment DLP policy matched '$PolicyId'."
			return
		}
		if ($current.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple environment DLP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		if (-not $PSCmdlet.ShouldProcess($EnvironmentId, "Delete environment DLP policy $($current[0].PolicyId)")) { return }

		$secureToken = Get-BapAccessToken -ResourceUrl 'https://service.powerapps.com/'
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$routeEnvironmentId/apiPolicies/$($current[0].PolicyId)?api-version=2018-10-01"

		try {
			$null = Invoke-RestMethod -Method Delete -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
			} -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to delete the environment DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the environment DLP delete request failed." -Exception $_.Exception
			return
		}
	}
}
