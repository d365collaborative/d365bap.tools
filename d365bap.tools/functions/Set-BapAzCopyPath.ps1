<#
.SYNOPSIS
Sets the path to the AzCopy executable.

.DESCRIPTION
This function sets the path to the AzCopy executable, ensuring that it exists and is accessible.

.PARAMETER Path
The full path to the AzCopy executable.

.EXAMPLE
PS C:\> Set-BapAzCopyPath -Path "C:\temp\d365bap.tools\AzCopy\AzCopy.exe"

This will set the path to the AzCopy executable.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Set-BapAzCopyPath {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if ($null -eq (Get-Item -Path $Path)) {
        $messageString = "File path doesn't <c='em'>exist</c>. Please make sure that you have specified the correct path '<c='em'>$Path</c>'. You can use the '<c='em'>Invoke-BapInstallAzCopy</c>' function to download and install AzCopy."

        Write-PSFMessage -Level Host -Message $messageString -Target Host
        Stop-PSFFunction -Message "Stopping because file path doesn't exist." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        return
    }

    Set-PSFConfig -FullName "d365bap.tools.path.azcopy" -Value $Path
    Register-PSFConfig -FullName "d365bap.tools.path.azcopy"

    Update-ModuleVariables
}