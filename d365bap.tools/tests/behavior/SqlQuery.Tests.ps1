BeforeDiscovery {
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name SqlQueryBehavior -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		Import-Module PSFramework -ErrorAction Stop
		$script:ModuleRoot = $Root
		. (Join-Path $Root 'internal/functions/Get-SqlClientFactory.ps1')
		. (Join-Path $Root 'internal/functions/Get-SqlCommand.ps1')
		. (Join-Path $Root 'internal/functions/Dispose-SqlCommand.ps1')
		. (Join-Path $Root 'functions/Invoke-UdeDbQuery.ps1')
		. (Join-Path $Root 'functions/Get-UdeDbJitCache.ps1')
		. (Join-Path $Root 'functions/Get-UdeDbJit.ps1')
		$script:actualFactory = Get-SqlClientFactory
		function Get-SqlClientFactory { $script:factory }
		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, $WorksheetName)
			process {
				$script:worksheet = $WorksheetName
				$script:exported.Add($InputObject)
			}
		}
		Export-ModuleMember -Function Invoke-UdeDbQuery
	}
	Import-Module $fixture -Force
}

Describe 'Bundled SQL query behavior' {
	InModuleScope SqlQueryBehavior {
		BeforeEach {
			Mock Test-PSFFunctionInterrupt { $false }
			Mock Get-UdeDbJitCache { $script:jit }
			Mock Get-UdeDbJit { $script:jit }
			Mock Write-PSFMessage {}
			Mock Stop-PSFFunction {
				param($Message, $Exception)
				if ($Exception) { throw $Exception }
				throw $Message
			}
			$script:jit = [pscustomobject]@{
				Server     = 'example.invalid'
				Database   = 'fixture'
				Username   = 'reader'
				Password   = 'password;with=special characters'
				Expiration = (Get-Date).AddHours(1)
			}
			$script:exported = [Collections.Generic.List[object]]::new()
			$script:reader = [pscustomobject]@{
				Names           = @('Value', 'Missing')
				Rows            = @(@(42, [DBNull]::Value), @(7, 'ok'))
				RowIndex        = -1
				RecordsAffected = -1
				Closed          = $false
				Disposed        = $false
			}
			$reader | Add-Member ScriptProperty FieldCount { $this.Names.Count }
			$reader | Add-Member ScriptMethod Read { $this.RowIndex++; $this.RowIndex -lt $this.Rows.Count }
			$reader | Add-Member ScriptMethod GetName { param($Index) $this.Names[$Index] }
			$reader | Add-Member ScriptMethod GetValue { param($Index) $this.Rows[$this.RowIndex][$Index] }
			$reader | Add-Member ScriptMethod NextResult { $false }
			$reader | Add-Member ScriptMethod Close { $this.Closed = $true }
			$reader | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
			$script:command = [pscustomobject]@{
				CommandText    = ''
				CommandTimeout = 0
				Reader         = $reader
				Fail           = $false
				Disposed       = $false
			}
			$command | Add-Member ScriptMethod ExecuteReader {
				if ($this.Fail) { throw 'fixture query failure' }
				$this.Reader
			}
			$command | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
			$script:connection = [pscustomobject]@{
				ConnectionString = ''
				Command          = $command
				State            = [Data.ConnectionState]::Closed
				Disposed         = $false
			}
			$connection | Add-Member ScriptMethod CreateCommand { $this.Command }
			$connection | Add-Member ScriptMethod Open { $this.State = [Data.ConnectionState]::Open }
			$connection | Add-Member ScriptMethod Close { $this.State = [Data.ConnectionState]::Closed }
			$connection | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
			$script:factory = [pscustomobject]@{ Connection = $connection; ActualFactory = $actualFactory }
			$factory | Add-Member ScriptMethod CreateConnection { $this.Connection }
			$factory | Add-Member ScriptMethod CreateConnectionStringBuilder { $this.ActualFactory.CreateConnectionStringBuilder() }
		}

		It 'uses cached SQL credentials, validates TLS, and returns typed rows with null values' {
			$result = @(Invoke-UdeDbQuery -Id 'fixture' -Query 'SELECT Value, Missing FROM fixture' -QueryTimeout 19)
			$result.Count | Should -Be 2
			$result[0].Value | Should -Be 42
			$result[0].Missing | Should -BeNullOrEmpty
			$result[1].Missing | Should -Be 'ok'
			$builder = $actualFactory.CreateConnectionStringBuilder()
			$builder.set_ConnectionString($connection.ConnectionString)
			$builder.DataSource | Should -Be $jit.Server
			$builder.InitialCatalog | Should -Be $jit.Database
			$builder.UserID | Should -Be $jit.Username
			$builder.Password | Should -Be $jit.Password
			$builder.get_Encrypt().ToString() | Should -Be 'True'
			$builder.TrustServerCertificate | Should -BeFalse
			$command.CommandText | Should -Be 'SELECT Value, Missing FROM fixture'
			$command.CommandTimeout | Should -Be 19
			$reader.Closed | Should -BeTrue
			$reader.Disposed | Should -BeTrue
			$command.Disposed | Should -BeTrue
			$connection.Disposed | Should -BeTrue
		}

		It 'returns the affected row count for a statement without result rows' {
			$reader.Rows = @()
			$reader.RecordsAffected = 3
			(Invoke-UdeDbQuery -Id 'fixture' -Query 'UPDATE fixture SET Value = 1').RowsAffected | Should -Be 3
		}

		It 'preserves positional cache ID, query and timeout arguments' {
			(Invoke-UdeDbQuery 'fixture' 'SELECT 1' 17).Count | Should -Be 2
			$command.CommandText | Should -Be 'SELECT 1'
			$command.CommandTimeout | Should -Be 17
			Should -Invoke Get-UdeDbJitCache -Times 1 -Exactly -ParameterFilter { $Id -eq 'fixture' }
		}

		It 'requests Reader JIT access by environment without using the credential cache' {
			(Invoke-UdeDbQuery -EnvironmentId 'fixture-env' -Query 'SELECT 1').Count | Should -Be 2
			Should -Invoke Get-UdeDbJit -Times 1 -Exactly -ParameterFilter { $EnvironmentId -eq 'fixture-env' -and $Role -eq 'Reader' }
			Should -Invoke Get-UdeDbJitCache -Times 0 -Exactly
		}

		It 'requires an explicit Writer role when requesting write access' {
			Invoke-UdeDbQuery -EnvironmentId 'fixture-env' -Role Writer -Query 'UPDATE fixture SET Value = 1' > $null
			Should -Invoke Get-UdeDbJit -Times 1 -Exactly -ParameterFilter { $Role -eq 'Writer' }
			Should -Invoke Get-UdeDbJitCache -Times 0 -Exactly
		}

		It 'reuses supplied credentials without requesting JIT or using CredentialManager' {
			(Invoke-UdeDbQuery -JitCredential $jit -Query 'SELECT 1').Count | Should -Be 2
			Should -Invoke Get-UdeDbJit -Times 0 -Exactly
			Should -Invoke Get-UdeDbJitCache -Times 0 -Exactly
		}

		It 'rejects incomplete supplied credentials before connecting' {
			$jit.Password = ''
			{ Invoke-UdeDbQuery -JitCredential $jit -Query 'SELECT 1' } | Should -Throw '*missing Password*'
			$connection.ConnectionString | Should -BeNullOrEmpty
		}

		It 'rejects expired ISO timestamps in supplied credentials' {
			$jit.Expiration = [DateTimeOffset]::UtcNow.AddHours(-1).ToString('o')
			{ Invoke-UdeDbQuery -JitCredential $jit -Query 'SELECT 1' } | Should -Throw '*expired*'
			$connection.ConnectionString | Should -BeNullOrEmpty
		}

		It 'rejects malformed credential expiry before connecting' {
			$jit.Expiration = 'invalid'
			{ Invoke-UdeDbQuery -JitCredential $jit -Query 'SELECT 1' } | Should -Throw '*invalid expiration*'
			$connection.ConnectionString | Should -BeNullOrEmpty
		}

		It 'accepts a piped cache ID and exports query rows to Excel' {
			$result = @([pscustomobject]@{ Id = 'fixture' } | Invoke-UdeDbQuery -Query 'SELECT * FROM fixture' -AsExcelOutput)
			$result.Count | Should -Be 0
			$exported.Count | Should -Be 2
			$exported[0].Value | Should -Be 42
			$worksheet | Should -Be 'Invoke-UdeDbQuery'
		}

		It 'disposes the connection and command when SQL execution fails' {
			$command.Fail = $true
			{ Invoke-UdeDbQuery -Id 'fixture' -Query 'invalid SQL' } | Should -Throw '*fixture query failure*'
			$connection.State | Should -Be ([Data.ConnectionState]::Closed)
			$connection.Disposed | Should -BeTrue
			$command.Disposed | Should -BeTrue
		}

		It 'rejects expired JIT credentials before opening the connection' {
			$jit.Expiration = (Get-Date).AddHours(-1)
			{ Invoke-UdeDbQuery -Id 'fixture' -Query 'SELECT 1' } | Should -Throw '*expired*'
			$connection.ConnectionString | Should -BeNullOrEmpty
		}

		It 'keeps LocalDB connection settings and disposes an unopened command' {
			$script:factory = $actualFactory
			$localCommand = Get-SqlCommand
			$localConnection = $localCommand.Connection
			$builder = $actualFactory.CreateConnectionStringBuilder()
			$builder.set_ConnectionString($localConnection.ConnectionString)
			$builder.DataSource | Should -Be '(LocalDB)\MSSQLLocalDB'
			$builder.IntegratedSecurity | Should -BeTrue
			$builder.get_Encrypt().ToString() | Should -Be 'False'
			Dispose-SqlCommand -InputObject $localCommand
			$localConnection.ConnectionString | Should -BeNullOrEmpty
		}
	}
}
