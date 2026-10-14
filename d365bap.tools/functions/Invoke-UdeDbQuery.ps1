
<#
    .SYNOPSIS
        Invokes a SQL query against a UDE database using cached JIT access credentials.
        
    .DESCRIPTION
        This function executes a SQL query against the database of a specified environment.
        
        It uses JIT access credentials from the local cache (see Get-UdeDbJitCache) and never
        obtains credentials itself.
                
    .PARAMETER Id
        The unique identifier of the cached JIT access credentials to use.
        
        Supports wildcard patterns. If multiple cached credentials match, the cmdlet stops and asks
        you to be specific.
        
    .PARAMETER Query
        The SQL query to execute against the environment database.
        
    .PARAMETER QueryTimeout
        The time in seconds to wait for the query to execute before timing out.
        
        Defaults to 60.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
        Will include all properties, including those not shown by default in the console output.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "es-ude-motz-01" -Role Reader | Set-UdeDbJitCache -Id "motz01-reader"
        PS C:\> Invoke-UdeDbQuery -Id "motz01-reader" -Query "SELECT TOP (10) name FROM sys.tables ORDER BY name"
        
        This will cache Reader JIT access credentials for the environment "es-ude-motz-01" (waiting 60 seconds
        for backend propagation) and then execute the query using the cached credentials.
        It will return one object per row.
        
    .EXAMPLE
        PS C:\> Invoke-UdeDbQuery -Id "motz01-writer" -Query "UPDATE dbo.MyTable SET MyColumn = 1 WHERE Id = 42"
        
        This will execute the data modifying statement using the cached Writer JIT access credentials
        for the ID "motz01-writer" and return the number of affected rows.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJitCache -Id "motz01-reader" | Invoke-UdeDbQuery -Query "SELECT * FROM dbo.MyTable" -AsExcelOutput
        
        This will execute the query using the cached JIT access credentials piped in from Get-UdeDbJitCache.
        It will output all details directly to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-UdeDbQuery {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true)]
        [string] $Query,

        [int] $QueryTimeout = 60,

        [switch] $AsExcelOutput
    )

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $cacheHits = @(Get-UdeDbJitCache -Id $Id -ShowPassword)

        if ($cacheHits.Count -eq 0) {
            $messageString = "No cached JIT database access credentials found for Id <c='em'>$Id</c>. Obtain them first using <c='em'>Get-UdeDbJit</c> and store them using <c='em'>Set-UdeDbJitCache -Id `"$Id`"</c>, then try again. List cached credentials using <c='em'>Get-UdeDbJitCache</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no cached JIT credentials were found." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ($cacheHits.Count -gt 1) {
            $messageString = "Multiple cached JIT database access credentials match Id <c='em'>$Id</c>. Please be specific and try again. List cached credentials using <c='em'>Get-UdeDbJitCache</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple cached JIT credentials matched." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $jit = $cacheHits[0]

        if ($jit.Expiration -is [datetime] -and $jit.Expiration -lt (Get-Date)) {
            $messageString = "The cached JIT database access credentials for Id <c='em'>$Id</c> expired at <c='em'>$($jit.ExpirationIso)</c>. Obtain fresh credentials using <c='em'>Get-UdeDbJit</c> and store them using <c='em'>Set-UdeDbJitCache -Id `"$Id`"</c>, then try again."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the cached JIT credentials expired." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ([string]::IsNullOrEmpty($jit.Password)) {
            $messageString = "The password for the cached JIT database access credentials for Id <c='em'>$Id</c> could not be resolved. Store the credentials again using <c='em'>Get-UdeDbJit</c> piped into <c='em'>Set-UdeDbJitCache -Id `"$Id`"</c>, then try again."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the cached password could not be resolved." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $connectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
        $connectionStringBuilder['Server'] = $jit.Server
        $connectionStringBuilder['Initial Catalog'] = $jit.Database
        $connectionStringBuilder['User ID'] = $jit.Username
        $connectionStringBuilder['Password'] = $jit.Password
        $connectionStringBuilder['Encrypt'] = $true
        $connectionStringBuilder['TrustServerCertificate'] = $false
        $connectionStringBuilder['Connect Timeout'] = 30
        $connectionStringBuilder['Application Name'] = 'd365bap.tools'

        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($connectionStringBuilder.ConnectionString)
        $sqlCommand = $sqlConnection.CreateCommand()
        $sqlCommand.CommandText = $Query
        $sqlCommand.CommandTimeout = $QueryTimeout

        $resCol = @()

        try {
            $sqlConnection.Open()

            $reader = $sqlCommand.ExecuteReader()

            try {
                $emitted = 0

                do {
                    while ($reader.Read() -eq $true) {
                        $properties = [ordered]@{}

                        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                            $columnName = $reader.GetName($i)

                            if ([string]::IsNullOrEmpty($columnName)) {
                                $columnName = "Column$($i + 1)"
                            }

                            $uniqueName = $columnName
                            $suffix = 1

                            while ($properties.Keys -contains $uniqueName) {
                                $suffix++
                                $uniqueName = "$($columnName)_$($suffix)"
                            }

                            $value = $reader.GetValue($i)

                            if ($value -is [System.DBNull]) {
                                $value = $null
                            }

                            $properties[$uniqueName] = $value
                        }

                        $emitted++
                        $resCol += [PSCustomObject]$properties
                    }
                } while ($reader.NextResult() -eq $true)

                if ($emitted -eq 0 -and $reader.RecordsAffected -ge 0) {
                    $resCol += [PSCustomObject]@{
                        RowsAffected = $reader.RecordsAffected
                    }
                }
            }
            finally {
                $reader.Close()
                $reader.Dispose()
            }
        }
        catch {
            Write-PSFMessage -Level Important -Message "Something went wrong while working against the database using the cached credentials for Id <c='em'>$Id</c>" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors" -Exception $PSItem.Exception
            return
        }
        finally {
            if ($sqlConnection.State -ne [System.Data.ConnectionState]::Closed) {
                $sqlConnection.Close()
            }

            $sqlCommand.Dispose()
            $sqlConnection.Dispose()
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Invoke-UdeDbQuery"
            return
        }

        $resCol
    }
}
