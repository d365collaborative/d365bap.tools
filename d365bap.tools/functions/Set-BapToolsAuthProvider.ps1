
<#
    .SYNOPSIS
        Sets the token minting provider used by d365bap.tools.

    .DESCRIPTION
        This function sets which provider is used to mint access tokens:
        AzAccount (default, via the Az.Accounts PowerShell module) or
        AzCli (via the Azure CLI, `az`).

        Switching to AzCli validates the Azure CLI before changing any
        configuration. If the validation fails, the current provider is
        left unchanged.

    .PARAMETER AzAccount
        Use the Az.Accounts PowerShell module for minting tokens.

        This is the default provider and requires no validation, as
        Az.Accounts is a required module of d365bap.tools.

    .PARAMETER AzCli
        Use the Azure CLI (`az`) for minting tokens.

        Before switching, the function verifies that the `az` executable
        is available and that it can mint a token for the Power Apps
        resource. If either check fails, the provider is not changed.

    .EXAMPLE
        PS C:\> Set-BapToolsAuthProvider -AzAccount

        This will set the token minting provider to AzAccount.

    .EXAMPLE
        PS C:\> Set-BapToolsAuthProvider -AzCli

        This will validate the Azure CLI installation and its login
        state, then set the token minting provider to AzCli.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapToolsAuthProvider {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding(DefaultParameterSetName = 'AzAccount')]
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'AzCli')]
        [switch] $AzCli,

        [Parameter(Mandatory = $true, ParameterSetName = 'AzAccount')]
        [switch] $AzAccount
    )

    process {
        if (Test-PSFFunctionInterrupt) { return }

        if ($AzCli) {
            if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
                $messageString = "Azure CLI (<c='em'>az</c>) was not found on the path. Please install it with '<c='em'>Invoke-BapInstallAzCli</c>' before switching the auth provider to AzCli."

                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because the Azure CLI was not found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            try {
                $null = & az account get-access-token --resource 'https://service.powerapps.com/' -o json 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "az account get-access-token exited with code $LASTEXITCODE."
                }
            }
            catch {
                $messageString = "Azure CLI token probe failed: $($_.Exception.Message) Make sure you are logged in (e.g. '<c='em'>az login</c>') before switching the auth provider to AzCli."

                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because the Azure CLI could not mint a token." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            Set-PSFConfig -FullName 'd365bap.tools.auth.provider' -Value 'AzCli'
        }
        elseif ($AzAccount) {
            Set-PSFConfig -FullName 'd365bap.tools.auth.provider' -Value 'AzAccount'
        }

        Register-PSFConfig -FullName 'd365bap.tools.auth.provider' -Scope UserDefault

        if (Get-Command Clear-BapTokenCache -ErrorAction SilentlyContinue) { Clear-BapTokenCache }
        else { $script:BapTokenCache = @{} }

        Update-ModuleVariables
    }
}
