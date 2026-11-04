
<#
    .SYNOPSIS
        Invokes a SQL query against a UDE database using JIT access credentials.

    .DESCRIPTION
        Executes SQL with the bundled client using fresh, supplied, or cached JIT credentials.
        Fresh and supplied credentials stay in memory and need no CredentialManager or SSMS.

    .PARAMETER Id
        Cached JIT credential ID. Wildcards must match exactly one entry.

    .PARAMETER EnvironmentId
        Environment name or GUID for fresh JIT access, without caching credentials. Supports wildcards.

    .PARAMETER Role
        JIT access role for fresh credentials. Writer permits data changes.

        Default: Reader.

    .PARAMETER JitCredential
        Credential object from Get-UdeDbJit. Used in memory without CredentialManager.

    .PARAMETER Query
        The SQL query to execute against the environment database.

    .PARAMETER QueryTimeout
        The time in seconds to wait for the query to execute before timing out.

        Defaults to 60.

    .PARAMETER AsExcelOutput
        Exports all result properties to an Excel file instead of returning rows.

    .EXAMPLE
        PS C:\> Invoke-UdeDbQuery -EnvironmentId "dev-environment" -Query "SELECT DB_NAME() AS DatabaseName"

        Requests temporary Reader access and queries the environment.
        It uses -EnvironmentId to request fresh JIT credentials without caching them.
        It uses the default -Role Reader.
        It executes the SQL in -Query after the JIT propagation wait.
        It uses the default -QueryTimeout of 60 seconds.
        It leaves -AsExcelOutput disabled by default and returns rows.

    .EXAMPLE
        PS C:\> $jit = Get-UdeDbJit -EnvironmentId "dev-environment"
        PS C:\> Invoke-UdeDbQuery -JitCredential $jit -Query "SELECT DB_NAME() AS DatabaseName"

        Reuses temporary credentials without storing them in the SSMS cache.
        It uses -EnvironmentId to request the credentials.
        It passes -JitCredential directly from Get-UdeDbJit.
        It uses the default -Role Reader when requesting the credentials.
        It executes the SQL in -Query.
        It uses the default -QueryTimeout of 60 seconds.
        It leaves -AsExcelOutput disabled by default and returns rows.

    .EXAMPLE
        PS C:\> Invoke-UdeDbQuery -Id "dev-reader" -Query "SELECT TOP (10) name FROM sys.tables ORDER BY name"

        Runs a query with cached Reader credentials.
        It uses -Id to select the cached credentials.
        It uses the cached role; -Role defaults to Reader for fresh access.
        It executes the SQL in -Query and returns one object per row.
        It uses the default -QueryTimeout of 60 seconds.
        It leaves -AsExcelOutput disabled by default and returns rows.

    .EXAMPLE
        PS C:\> Invoke-UdeDbQuery -Id "dev-writer" -Query "UPDATE dbo.MyTable SET MyColumn = 1 WHERE Id = 42"

        Updates rows with cached Writer credentials.
        It uses -Id to select the cached credentials.
        It uses the cached role; -Role defaults to Reader for fresh access.
        It executes -Query and returns RowsAffected when no rows are returned.
        It uses the default -QueryTimeout of 60 seconds.
        It leaves -AsExcelOutput disabled by default and returns the result.

    .EXAMPLE
        PS C:\> Get-UdeDbJitCache -Id "dev-reader" | Invoke-UdeDbQuery -Query "SELECT * FROM dbo.MyTable" -AsExcelOutput

        Exports query results to Excel.
        It uses -Id from the piped cache entry to select credentials.
        It uses the cached role; -Role defaults to Reader for fresh access.
        It executes the SQL in -Query.
        It uses the default -QueryTimeout of 60 seconds.
        It enables -AsExcelOutput to write all result properties to Excel.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-UdeDbQuery {
	[CmdletBinding(DefaultParameterSetName = 'Cached', PositionalBinding = $false)]
	[OutputType([PSCustomObject[]])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Cached', Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string] $Id,

		[Parameter(Mandatory = $true, ParameterSetName = 'Environment')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(ParameterSetName = 'Environment')]
		[ValidateSet('Reader', 'Writer')]
		[string] $Role = 'Reader',

		[Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
		[ValidateNotNull()]
		[psobject] $JitCredential,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string] $Query,

		[Parameter(Position = 2)]
		[int] $QueryTimeout = 60,

		[switch] $AsExcelOutput
	)

	process {
		if ($PSCmdlet.ParameterSetName -eq 'Environment') {
			$colJitCredentials = @(Get-UdeDbJit -EnvironmentId $EnvironmentId `
					-Role $Role)

			if (Test-PSFFunctionInterrupt) { return }

			if ($colJitCredentials.Count -ne 1) {
				throw "Expected one JIT credential for '$EnvironmentId'; found $($colJitCredentials.Count)."
			}

			$jit = $colJitCredentials[0]
			$credentialLabel = "environment '$EnvironmentId'"
		}
		elseif ($PSCmdlet.ParameterSetName -eq 'Credential') {
			$jit = $JitCredential
			$credentialLabel = 'supplied JIT credentials'
		}
		else {
			$colCacheHits = @(Get-UdeDbJitCache -Id $Id `
					-ShowPassword)

			if (Test-PSFFunctionInterrupt) { return }

			if ($colCacheHits.Count -eq 0) {
				$messageString = "No cached JIT database access credentials found for Id <c='em'>$Id</c>. Obtain them first using <c='em'>Get-UdeDbJit</c> and store them using <c='em'>Set-UdeDbJitCache -Id `"$Id`"</c>, then try again. List cached credentials using <c='em'>Get-UdeDbJitCache</c>."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because no cached JIT credentials were found." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			if ($colCacheHits.Count -gt 1) {
				$messageString = "Multiple cached JIT database access credentials match Id <c='em'>$Id</c>. Please be specific and try again. List cached credentials using <c='em'>Get-UdeDbJitCache</c>."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because multiple cached JIT credentials matched." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$jit = $colCacheHits[0]
			$credentialLabel = "cached ID '$Id'"
		}

		foreach ($itemField in @('Server', 'Database', 'Username', 'Password', 'Expiration')) {
			if ([string]::IsNullOrWhiteSpace([string]$jit.$itemField)) {
				throw "The JIT credentials for $credentialLabel are missing $itemField. Obtain fresh credentials using Get-UdeDbJit."
			}
		}

		try { $expiration = [DateTimeOffset]$jit.Expiration }
		catch { throw "The JIT credentials for $credentialLabel have an invalid expiration. Obtain fresh credentials using Get-UdeDbJit." }

		if ($expiration -lt [DateTimeOffset]::UtcNow) {
			$messageString = "The JIT database access credentials for $credentialLabel expired at $($expiration.ToString('o')). Obtain fresh credentials using Get-UdeDbJit and try again."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the JIT credentials expired." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$objSqlClientFactory = Get-SqlClientFactory
		$connectionStringBuilder = $objSqlClientFactory.CreateConnectionStringBuilder()
		$connectionStringBuilder['Server'] = $jit.Server
		$connectionStringBuilder['Initial Catalog'] = $jit.Database
		$connectionStringBuilder['User ID'] = $jit.Username
		$connectionStringBuilder['Password'] = $jit.Password
		$connectionStringBuilder['Encrypt'] = $true
		$connectionStringBuilder['TrustServerCertificate'] = $false
		$connectionStringBuilder['Connect Timeout'] = 30
		$connectionStringBuilder['Application Name'] = 'd365bap.tools'

		$sqlConnection = $objSqlClientFactory.CreateConnection()
		$sqlConnection.ConnectionString = $connectionStringBuilder.ConnectionString
		$sqlCommand = $sqlConnection.CreateCommand()
		$sqlCommand.CommandText = $Query
		$sqlCommand.CommandTimeout = $QueryTimeout

		$colResults = [Collections.Generic.List[object]]::new()

		try {
			$sqlConnection.Open()

			$reader = $sqlCommand.ExecuteReader()

			try {
				$emitted = 0

				do {
					while ($reader.Read() -eq $true) {
						$tmpProperties = [ordered]@{}

						for ($i = 0; $i -lt $reader.FieldCount; $i++) {
							$columnName = $reader.GetName($i)

							if ([string]::IsNullOrEmpty($columnName)) {
								$columnName = "Column$($i + 1)"
							}

							$uniqueName = $columnName
							$suffix = 1

							while ($tmpProperties.Keys -contains $uniqueName) {
								$suffix++
								$uniqueName = "$($columnName)_$($suffix)"
							}

							$value = $reader.GetValue($i)

							if ($value -is [System.DBNull]) {
								$value = $null
							}

							$tmpProperties[$uniqueName] = $value
						}

						$emitted++
						$colResults.Add([PSCustomObject]$tmpProperties)
					}
				} while ($reader.NextResult() -eq $true)

				if (($emitted -eq 0) `
						-and ($reader.RecordsAffected -ge 0)) {
					$colResults.Add([PSCustomObject][ordered]@{
							RowsAffected = $reader.RecordsAffected
						})
				}
			}
			finally {
				$reader.Close()
				$reader.Dispose()
			}
		}
		catch {
			Write-PSFMessage -Level Important `
				-Message "Something went wrong while working against the database using JIT access for $credentialLabel" `
				-Exception $PSItem.Exception

			Stop-PSFFunction -Message "Stopping because of errors" `
				-Exception $PSItem.Exception

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
			$colResults |
			Export-Excel -WorksheetName "Invoke-UdeDbQuery"
			return
		}

		$colResults
	}
}
