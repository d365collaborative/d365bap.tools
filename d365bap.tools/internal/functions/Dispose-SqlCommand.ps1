
<#
    .SYNOPSIS
        Disposes a SqlCommand object and closes its connection.
        
    .DESCRIPTION
        This function takes a SqlCommand object as input, closes its connection if it is open, and disposes of both the command and its connection to free up resources.
        
    .PARAMETER InputObject
        The SqlCommand object to dispose of.
        
    .EXAMPLE
        PS C:\> Dispose-SqlCommand -InputObject $sqlCommand
        
        This will close the connection of the provided SqlCommand object (if it is open) and dispose of both the command and its connection.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Dispose-SqlCommand {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
    [CmdletBinding()]
    param (
        [System.Data.SqlClient.SqlCommand] $InputObject
    )
    end {
        if ($InputObject.Connection.State -ne [System.Data.ConnectionState]::Closed) {
            $InputObject.Connection.Close()

            $InputObject.Dispose()
            $InputObject.Connection.Dispose()
        }
    }
}