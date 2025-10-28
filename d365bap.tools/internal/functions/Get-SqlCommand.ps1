
<#
    .SYNOPSIS
        Gets a configured SqlCommand object for local SQL Server LocalDB access.
        
    .DESCRIPTION
        This function creates and configures a SqlCommand object for use with a local SQL Server LocalDB instance.
        
    .EXAMPLE
        PS C:\> $sqlCommand = Get-SqlCommand
        
        This will create and return a SqlCommand object configured to connect to the local SQL Server LocalDB instance.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-SqlCommand {
    [CmdletBinding()]
    param (
        
    )
    end {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand

        try {
            $sqlConnection.ConnectionString = "Server='(LocalDB)\MSSQLLocalDB';Database='master';Integrated Security='SSPI';Application Name='d365bap.tools'"

            $sqlCommand.Connection = $sqlConnection
            $sqlCommand.CommandTimeout = 0
        }
        catch {
            Write-PSFMessage -Level Host -Message "Something went wrong while working with the sql server connection objects" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors" -StepsUpward 1
            return
        }

        $sqlCommand
    }
}