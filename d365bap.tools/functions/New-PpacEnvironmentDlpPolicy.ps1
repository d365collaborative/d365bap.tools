<#
    .SYNOPSIS
        Create an environment classic DLP policy.

    .DESCRIPTION
        Creates an environment-scoped classic data loss prevention definition
        through the Business App Platform API.

        The supplied body is passed through to the service.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER Policy
        Policy body as a hashtable or PSCustomObject.

    .EXAMPLE
        PS C:\> New-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -Policy @{ displayName = "Environment baseline"; environmentType = "SingleEnvironment" }

        Creates an environment DLP policy from the supplied body.
        It uses -EnvironmentId to select the environment.
        It uses -Policy to pass the policy body.

    .NOTES
        Author: d365bap.tools contributors
#>
function New-PpacEnvironmentDlpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacEnvironmentDlpPolicy')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[object] $Policy
	)

	process {
		$objRoute = Get-PpacEnvironmentDlpRoute -EnvironmentId $EnvironmentId
		$routeEnvironmentId = $objRoute.RouteId
		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			Stop-PSFFunction -Message "No environment matched '$EnvironmentId'."
			return
		}

		$policyName = "$($Policy.displayName)"
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = "$($Policy.name)" }
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = 'DLP policy' }

		$shouldAffected = $policyName
		$shouldLabel = "Create DLP policy in '$($objRoute.Name)'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$objSecureToken = Get-BapAccessToken -Bap
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $objSecureToken
		$uri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$routeEnvironmentId/apiPolicies?api-version=2018-10-01"

		try {
			$created = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
			} -Body ($Policy | ConvertTo-Json -Depth 20) -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to create the environment DLP policy. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the environment DLP create request failed." -Exception $_.Exception
			return
		}

		if (-not [string]::IsNullOrWhiteSpace("$($created.name)")) {
			Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId -PolicyId $created.name
		}
		elseif (-not [string]::IsNullOrWhiteSpace("$($created.displayName)")) {
			Get-PpacEnvironmentDlpPolicy -EnvironmentId $EnvironmentId -PolicyId $created.displayName
		}
	}
}
