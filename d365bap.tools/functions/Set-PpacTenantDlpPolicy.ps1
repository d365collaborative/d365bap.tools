<#
    .SYNOPSIS
        Update a tenant classic DLP policy.

    .DESCRIPTION
        Updates a tenant-scoped classic data loss prevention definition through the
        Business App Platform API.

        The supplied body is passed through to the service.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .PARAMETER Policy
        Replacement policy body as a hashtable or PSCustomObject.

    .EXAMPLE
        PS C:\> Set-PpacTenantDlpPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -Policy @{ displayName = "Tenant baseline"; environmentType = "AllEnvironments" }

        Replaces the tenant DLP policy body.
        It uses -PolicyId to select the policy.
        It uses -Policy to pass the replacement body.

    .NOTES
        Author: d365bap.tools contributors
#>
function Set-PpacTenantDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object] $Policy
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

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
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = 'Update tenant DLP policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$secureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies/$($colCurrent[0].PolicyId)?api-version=2018-10-01"

		try {
			$null = Invoke-RestMethod -Method Put -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
			} -Body ($Policy | ConvertTo-Json -Depth 20) -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to update the tenant DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the tenant DLP update request failed." -Exception $_.Exception
			return
		}

		Get-PpacTenantDlpPolicy -PolicyId $colCurrent[0].PolicyId
	}
}
