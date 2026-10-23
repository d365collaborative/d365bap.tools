
<#
    .SYNOPSIS
        Gets the token minting provider used by d365bap.tools.

    .DESCRIPTION
        This function retrieves the currently configured token minting
        provider: AzAccount (default, via the Az.Accounts PowerShell
        module) or AzCli (via the Azure CLI, `az`).

    .EXAMPLE
        PS C:\> Get-BapToolsAuthProvider

        This will return the currently configured token minting provider.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapToolsAuthProvider {
    [CmdletBinding()]
    [OutputType([string])]
    param ( )

    process {
        Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'
    }
}
