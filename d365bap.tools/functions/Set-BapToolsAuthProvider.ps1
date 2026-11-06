
<#
    .SYNOPSIS
        Sets the token minting provider used by d365bap.tools.

    .DESCRIPTION
        Sets which provider mints access tokens. Switching validates first and keeps the current provider on failure.

    .PARAMETER AzAccount
        Use the Az.Accounts module for minting tokens.

    .PARAMETER AzCli
        Use the Azure CLI for minting tokens.

    .EXAMPLE
        PS C:\> Set-BapToolsAuthProvider -AzAccount

        Selects Az.Accounts for token acquisition.
        It uses -AzAccount.

    .EXAMPLE
        PS C:\> Set-BapToolsAuthProvider -AzCli

        Validates the Azure CLI installation and account context, then selects Azure CLI.
        It uses -AzCli.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapToolsAuthProvider {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding(DefaultParameterSetName = 'AzAccount')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'AzCli')]
		[switch] $AzCli,

		[Parameter(Mandatory = $true, ParameterSetName = 'AzAccount')]
		[switch] $AzAccount
	)

	process {
		if ($AzCli) {
			if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
				$messageString = "Azure CLI (<c='em'>az</c>) was not found on the path. Please install it with '<c='em'>Invoke-BapInstallAzCli</c>' before switching the auth provider to AzCli."

				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the Azure CLI was not found." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			try {
				$tenantId = & az account show --query tenantId -o tsv 2>$null
				if ($LASTEXITCODE -ne 0) {
					throw "az account show exited with code $LASTEXITCODE."
				}
				if ([string]::IsNullOrWhiteSpace($tenantId)) {
					throw "az account show returned no tenant for the current account."
				}
			}
			catch {
				$messageString = "Azure CLI context probe failed: $($_.Exception.Message) Make sure you are logged in (e.g. '<c='em'>az login</c>') before switching the auth provider to AzCli."

				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the Azure CLI account context could not be read." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			Set-PSFConfig -FullName 'd365bap.tools.auth.provider' `
				-Value 'AzCli'
		}
		elseif ($AzAccount) {
			Set-PSFConfig -FullName 'd365bap.tools.auth.provider' `
				-Value 'AzAccount'
		}

		Register-PSFConfig -FullName 'd365bap.tools.auth.provider' `
			-Scope UserDefault

		if (Get-Command Clear-BapTokenCache -ErrorAction SilentlyContinue) { Clear-BapTokenCache }
		else { $script:BapTokenCache = @{} }

		if (Get-Command Clear-FinOpsVersionCache -ErrorAction SilentlyContinue) { Clear-FinOpsVersionCache }
		if (Get-Command Start-FinOpsVersionPreload -ErrorAction SilentlyContinue) { Start-FinOpsVersionPreload }

		Update-ModuleVariables
	}
}
