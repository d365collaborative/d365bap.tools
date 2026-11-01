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
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object] $Policy
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$policyLabel = "$($Policy.displayName)"
		if ([string]::IsNullOrWhiteSpace("$policyLabel")) { $policyLabel = "$($Policy.name)" }
		if ([string]::IsNullOrWhiteSpace("$policyLabel")) { $policyLabel = 'DLP policy' }

		if (-not $PSCmdlet.ShouldProcess($policyLabel, 'Create tenant DLP policy')) { return }

		$secureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies?api-version=2018-10-01'

		try {
			$created = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
			} -Body ($Policy | ConvertTo-Json -Depth 20) -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to create the tenant DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the tenant DLP create request failed." -Exception $_.Exception
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
