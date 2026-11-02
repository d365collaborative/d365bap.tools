<#
    .SYNOPSIS
        Delete a tenant classic DLP policy.

    .DESCRIPTION
        Deletes a tenant-scoped classic data loss prevention policy through the
        Business App Platform API.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Remove-PpacTenantDlpPolicy -PolicyId "11111111-1111-1111-1111-111111111111"

        Deletes the tenant DLP policy.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Remove-PpacTenantDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		$colCurrent = @(Get-PpacTenantDlpPolicy -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No tenant DLP policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple tenant DLP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = 'Delete tenant DLP policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$objSecureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			Authorization = "Bearer $tokenValue"
		}

		$apiVersion = $script:BapApiVersions.ClassicBap
		$uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies/{0}?api-version={1}' `
			-f $colCurrent[0].PolicyId,
		$apiVersion

		try {
			Invoke-RestMethod -Method Delete `
				-Uri $uri `
				-Headers $hashHeaders `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to delete the tenant DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the tenant DLP delete request failed." `
				-Exception $_.Exception

			return
		}
	}
}
