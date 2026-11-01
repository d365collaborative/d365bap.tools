
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
        It uses -EnvironmentId to select the environment.

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
		if (-not [string]::IsNullOrWhiteSpace($EnvironmentId)) {
			$envObj = Get-Environment `
				-EnvironmentId $EnvironmentId `
				-Unified | `
				Select-Object -First 1
		}
		else {
			$envObj = Get-Environment -Unified | Sort-Object PpacEnvName | Select-Object -First 1

			Write-PSFMessage -Level Verbose -Message "No environment specified, using <c='em'>$($envObj.PpacEnvName)</c> as auth context. The requested version is independent of this environment."
		}

		$baseUri = $envObj.PpacEnvUri + "/"

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $objSecureToken

		@{
			Env   = $envObj
			Token = $tokenValue
		}
	}
}
