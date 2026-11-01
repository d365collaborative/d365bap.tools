<#
    .SYNOPSIS
        Assign a governance policy to an environment.

    .DESCRIPTION
        Creates a governance rule-based policy assignment for an environment
        through the Power Platform API.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentRuleBasedPolicyAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Assigns the policy to the environment.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Add-PpacEnvironmentRuleBasedPolicyAssignment {
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

		$envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
		if ($null -ne $envObj) {
			$routeEnvironmentId = $envObj.PpacEnvId
		}
		else {
			$routeEnvironmentId = $null
			if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
				$routeEnvironmentId = $EnvironmentId
			}
			else {
				$environmentGuid = [guid]::Empty
				if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
					$tenantId = $null
					try { $tenantId = (Get-BapContext).TenantId } catch { $tenantId = $null }
					if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
						$routeEnvironmentId = "Default-$tenantId"
					}
					else {
						$routeEnvironmentId = "$environmentGuid"
					}
				}
			}
		}

		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			Stop-PSFFunction -Message "No environment matched '$EnvironmentId'."
			return
		}

		$environmentLabel = $EnvironmentId
		if ($null -ne $envObj -and -not [string]::IsNullOrWhiteSpace("$($envObj.PpacEnvName)")) {
			$environmentLabel = $envObj.PpacEnvName
		}

		$colPolicy = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($colPolicy.Count -eq 0) {
			Stop-PSFFunction -Message "No governance policy matched '$PolicyId'."
			return
		}
		if ($colPolicy.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple governance policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colPolicy[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colPolicy[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = "Assign policy to '$environmentLabel'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$secureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/$($colPolicy[0].PolicyId)/environments/$routeEnvironmentId/assignments?api-version=$apiVersion"

		try {
			$null = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} -Body '{}' -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to assign governance policy <c='em'>$PolicyId</c> to environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance assignment request failed." -Exception $_.Exception
			return
		}

		Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId $EnvironmentId -PolicyId $colPolicy[0].PolicyId
	}
}
