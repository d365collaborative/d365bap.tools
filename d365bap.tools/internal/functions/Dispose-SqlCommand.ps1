
<#
    .SYNOPSIS
        Disposes a SqlCommand object and closes its connection.

    .DESCRIPTION
        This function takes a SqlCommand object as input, closes its connection if it is open, and disposes of both the command and its connection to free up resources.

    .PARAMETER InputObject
        The SqlCommand object to dispose of.

    .EXAMPLE
        PS C:\> Dispose-SqlCommand -InputObject $sqlCommand

        Releases the command and its connection.
        It uses -InputObject to select the command to dispose.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Dispose-SqlCommand {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[System.Data.Common.DbCommand] $InputObject
	)
	end {
		if ($InputObject.Connection.State -ne [System.Data.ConnectionState]::Closed) {
			$InputObject.Connection.Close()
		}

		$connection = $InputObject.Connection
		$InputObject.Dispose()
		$connection.Dispose()
	}
}
