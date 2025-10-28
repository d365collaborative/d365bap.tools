function Dispose-SqlCommand {
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