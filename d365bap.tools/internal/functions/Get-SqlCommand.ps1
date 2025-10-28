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