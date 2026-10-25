
<#
    .SYNOPSIS
        Resolves the developer tools auth context.

    .DESCRIPTION
        Returns the environment, access token and base values for developer tools calls.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .EXAMPLE
        PS C:\> $ctx = Get-DevToolsAuthContext -EnvironmentId "env-123"

        Resolves the auth context for that environment.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-DevToolsAuthContext {
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[string] $EnvironmentId
	)

	process {
		$envObj = $null

		if (-not [string]::IsNullOrWhiteSpace($EnvironmentId)) {
			$envObj = Get-UnifiedEnvironment `
				-EnvironmentId $EnvironmentId `
				-SkipVersionDetails | `
				Select-Object -First 1

			if ($null -eq $envObj) {
				$messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

				Write-PSFMessage -Level Important -Message $messageString
				Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
				return $null
			}
		}
		else {
			$candidates = @(Get-UnifiedEnvironment -SkipVersionDetails | Sort-Object PpacEnvName)

			if ($candidates.Count -eq 0) {
				$messageString = "No FinOps environments found. Please verify access with <c='em'>Get-UnifiedEnvironment</c> and try again."

				Write-PSFMessage -Level Important -Message $messageString
				Stop-PSFFunction -Message "Stopping because no environment is available as auth context." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
				return $null
			}

			$envObj = $candidates | Select-Object -First 1

			Write-PSFMessage -Level Verbose -Message "No environment specified, using <c='em'>$($envObj.PpacEnvName)</c> as auth context. The requested version is independent of this environment."
		}

		$baseUri = $envObj.PpacEnvUri + "/"

		$secureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

		return @{
			Env   = $envObj
			Token = $tokenValue
		}
	}
}
