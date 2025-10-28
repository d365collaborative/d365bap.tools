<#
.SYNOPSIS
Clears the cached credentials used by Visual Studio for connecting to Dynamics 365 / Power Platform environments.

.DESCRIPTION
Clears the cached credentials used by Visual Studio for connecting to Dynamics 365 / Power Platform environments by removing the credential cache directory located at %APPDATA%\Microsoft\CRMDeveloperToolKit.

.PARAMETER Force
Instructs the function to proceed with clearing the credential cache.

Nothing happens unless this parameter is supplied.

.EXAMPLE
PS C:\> Clear-UdeCredentialCache

This will prompt the user to make sure that they understand what will be removed/cleared.
However, no action will be taken unless the -Force parameter is supplied.

.EXAMPLE
PS C:\> Clear-UdeCredentialCache -Force

This will remove all Visual Studio cached credentials for connecting to Dynamics 365 / Power Platform environments.
Force parameter is needed for the function to proceed.

.NOTES
Author: Mötz Jensen (@Splaxi)

#>
function Clear-UdeCredentialCache {
    [CmdletBinding()]
    param (
        [switch] $Force
    )

    $path = "$env:APPDATA\Microsoft\CRMDeveloperToolKit"

    if (-not $Force) {
        $messageString = "This will remove all Visual Studio cached credentials for connecting to Dynamics 365 / Power Platform environments. If you are sure, please re-run the command with the <c='em'>-Force</c> parameter."

        Write-PSFMessage -Level Host -Message $messageString -Target Host
        Stop-PSFFunction -Message "Stopping because Force parameter wasn't supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        return
    }

    Remove-Item -Path $path `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue `
        -Confirm:$false
}