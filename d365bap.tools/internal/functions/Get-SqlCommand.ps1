
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
	[OutputType([System.Data.Common.DbCommand])]
	param (

	)
	end {
		$objSqlClientFactory = Get-SqlClientFactory
		$sqlConnection = $objSqlClientFactory.CreateConnection()
		$sqlCommand = $sqlConnection.CreateCommand()

		try {
			$sqlConnection.ConnectionString = "Server='(LocalDB)\MSSQLLocalDB';Database='master';Integrated Security='SSPI';Application Name='d365bap.tools';Encrypt=False"

			$sqlCommand.Connection = $sqlConnection
			$sqlCommand.CommandTimeout = 0
		}
		catch {
			Write-PSFMessage -Level Important `
				-Message "Something went wrong while working with the sql server connection objects" `
				-Exception $PSItem.Exception

			Stop-PSFFunction -Message "Stopping because of errors" `
				-StepsUpward 1

			return
		}

		$sqlCommand
	}
}
