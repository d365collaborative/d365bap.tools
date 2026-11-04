<#
    .SYNOPSIS
        Sets the AzCopy executable location used by the module.

    .DESCRIPTION
        Stores the AzCopy executable location after verifying the file exists and is accessible.

    .PARAMETER Path
        Full filesystem location of the AzCopy executable.

    .EXAMPLE
        PS C:\> Set-BapAzCopyPath -Path "C:\temp\d365bap.tools\AzCopy\AzCopy.exe"

        Stores the AzCopy executable location for later module use.
        It uses -Path C:\temp\d365bap.tools\AzCopy\AzCopy.exe.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapAzCopyPath {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path
	)

	if ($null -eq (Get-Item -Path $Path)) {
		$messageString = "File path doesn't <c='em'>exist</c>. Please make sure that you have specified the correct path '<c='em'>$Path</c>'. You can use the '<c='em'>Invoke-BapInstallAzCopy</c>' function to download and install AzCopy."

		Write-PSFMessage `
			-Level Important `
			-Message $messageString

		Stop-PSFFunction `
			-Message "Stopping because file path doesn't exist." `
			-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

		return
	}

	Set-PSFConfig `
		-FullName "d365bap.tools.path.azcopy" `
		-Value $Path

	Register-PSFConfig `
		-FullName "d365bap.tools.path.azcopy"

	Update-ModuleVariables
}
