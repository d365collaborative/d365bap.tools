<#
    .SYNOPSIS
        Gets the token minting provider used by d365bap.tools.

    .DESCRIPTION
        Returns the configured token minting provider: AzAccount via Az.Accounts by default, or AzCli via the Azure CLI.

    .EXAMPLE
        PS C:\> Get-BapToolsAuthProvider

        Returns the currently configured token minting provider.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapToolsAuthProvider {
	[CmdletBinding()]
	[OutputType([string])]
	param ( )

	process {
		Get-PSFConfigValue `
			-FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'
	}
}
