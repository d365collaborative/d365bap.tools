<#
    .SYNOPSIS
        Create a tenant classic DLP policy.

    .DESCRIPTION
        Creates a tenant-scoped classic data loss prevention definition through the
        Business App Platform API.

        The supplied body is passed through to the service.

    .PARAMETER Policy
        Policy body as a hashtable or PSCustomObject.

    .EXAMPLE
        PS C:\> New-PpacTenantDlpPolicy -Policy @{ displayName = "Tenant baseline"; environmentType = "AllEnvironments" }

        Creates a tenant DLP policy from the supplied body.
        It uses -Policy to pass the policy body.

    .NOTES
        Author: d365bap.tools contributors
#>
function New-PpacTenantDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacTenantDlpPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object] $Policy
	)

	process {
		$policyName = "$($Policy.displayName)"
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = "$($Policy.name)" }
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = 'DLP policy' }

		$shouldAffected = $policyName
		$shouldLabel = 'Create tenant DLP policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$objSecureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken
		$apiVersion = $script:BapApiVersions.ClassicBap
		$uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies?api-version={0}' `
			-f $apiVersion

		try {
			$created = Invoke-RestMethod -Method Post `
				-Uri $uri `
				-Headers @{
				Authorization = "Bearer $tokenValue"
			} `
				-Body ($Policy | ConvertTo-Json -Depth 20) `
				-ContentType 'application/json' `
				-ErrorAction Stop
		}
		catch {
			$messageString = "Failed to create the tenant DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the tenant DLP create request failed." `
				-Exception $_.Exception
			return
		}

		if (-not [string]::IsNullOrWhiteSpace("$($created.name)")) {
			Get-PpacTenantDlpPolicy -PolicyId $created.name
		}
		elseif (-not [string]::IsNullOrWhiteSpace("$($created.displayName)")) {
			Get-PpacTenantDlpPolicy -PolicyId $created.displayName
		}
	}
}
