BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

	$msprovBody = '{"applicationversion":"10.0.2790.46","platformversion":"7.0.7120.42","finopsenvironmentstate":"Ready","applicationdeploymenttype":"Sandbox"}'
	$catalogBody = '[{"appVersion":"10.0.49","appBuild":"10.0.2790","platVersion":"7.0.7120","platBuild":"7.0.7120.42"}]'

	$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
	$probe.Start()
	$script:msprovPort = ($probe.LocalEndpoint -as [Net.IPEndPoint]).Port
	$probe.Stop()

	$script:msprovJob = Start-Job -Name 'UnifiedEnvMsprovFixture' -ScriptBlock {
		param($Port, $Msprov, $Catalog)
		$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
		$listener.Start()
		try {
			$served = 0
			while ($served -lt 24) {
				$accept = $listener.AcceptTcpClientAsync()
				if (-not $accept.Wait(10000)) { break }
				$client = $accept.Result
				try {
					$stream = $client.GetStream()
					$stream.ReadTimeout = 10000
					$reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
					$requestLine = $reader.ReadLine()
					do { $line = $reader.ReadLine() } while ($null -ne $line -and $line -ne '')
					$Body = if ($null -ne $requestLine -and $requestLine -like '*finopsversions*') { $Catalog } else { $Msprov }
					$bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)
					$header = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($bodyBytes.Length)`r`nConnection: close`r`n`r`n"
					$headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
					$stream.Write($headerBytes, 0, $headerBytes.Length)
					$stream.Write($bodyBytes, 0, $bodyBytes.Length)
					$stream.Flush()
					$served++
				}
				catch { $null = $_.Exception.Message }
				finally { $client.Close() }
			}
		}
		finally { $listener.Stop() }
	} -ArgumentList $script:msprovPort, $msprovBody, $catalogBody

	$deadline = (Get-Date).AddSeconds(20)
	while ($true) {
		$ready = $false
		try {
			$tcp = [Net.Sockets.TcpClient]::new()
			$iar = $tcp.BeginConnect('127.0.0.1', $script:msprovPort, $null, $null)
			if ($iar.AsyncWaitHandle.WaitOne(500)) {
				$tcp.EndConnect($iar)
				$ready = $true
			}
			$tcp.Close()
		}
		catch { $null = $_.Exception.Message }
		if ($ready) { break }
		if ((Get-Date) -gt $deadline) { throw 'Fixture msprov server did not start.' }
		Start-Sleep -Milliseconds 100
	}

	$script:msprovUri = "http://127.0.0.1:$script:msprovPort"

	$fixture = New-Module -Name UnifiedEnvBehaviorFixture -ArgumentList $sourceRoot, $script:msprovUri -ScriptBlock {
		param($Root, $BaseUri)
		. (Join-Path $Root 'internal/functions/FinOpsVersionCache.ps1')
		. (Join-Path $Root 'functions/Get-UnifiedEnvironment.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Test-Guid { param($InputObject) $false }
		function Get-BapEnvironment {
			param($EnvironmentId, [switch] $FscmEnabled)
			@(
				[pscustomobject]@{
					PpacEnvId             = '00000000-0000-0000-0000-000000000001'
					PpacEnvName           = 'finops-test-01'
					PpacEnvUri            = $script:fixtureUri
					FinOpsMetadataEnvType = 'Internal'
				}
				[pscustomobject]@{
					PpacEnvId             = '00000000-0000-0000-0000-000000000002'
					PpacEnvName           = 'finops-test-broken'
					PpacEnvUri            = ''
					FinOpsMetadataEnvType = 'Internal'
				}
			)
		}
		function Get-BapAccessToken {
			param($ResourceUrl)
			$secure = [Security.SecureString]::new()
			foreach ($char in @('fixture-token'.ToCharArray())) { $secure.AppendChar($char) }
			$secure.MakeReadOnly()
			$secure
		}
		$script:fixtureUri = $BaseUri
		$script:fixtureDevBase = $BaseUri
		$script:fixtureCatalog = $null
		$script:catalogCalls = 0
		$script:failCatalog = $false
		function Get-FinOpsVersionCache {
			param([int] $MaxAgeHours = 24)
			$script:fixtureCatalog
		}
		$script:writeCalls = @()
		function Write-FinOpsVersionCache {
			param($Versions, $Builds, $Platforms)
			$script:writeCalls += [pscustomobject]@{ Versions = @($Versions) }
			$script:fixtureCatalog = [pscustomobject]@{ versions = @($Versions) }
		}
		function Invoke-RestMethod {
			[CmdletBinding()]
			param($Method, $Uri, $Headers)
			if ("$Uri" -like '*finopsversions*') {
				$script:catalogCalls++
				if ($script:failCatalog) { throw 'fixture catalog failure' }
				$localUri = "$Uri" -replace 'https://developertools\.powerplatform\.microsoft\.com', $script:fixtureDevBase
				Microsoft.PowerShell.Utility\Invoke-RestMethod -Method $Method -Uri $localUri -Headers $Headers
			}
			else { throw "Unexpected main-runspace request: $Uri" }
		}
		$script:exportCalls = @()
		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, [string] $WorksheetName, [string[]] $NoNumberConversion)
			process {
				$script:exportCalls += [pscustomobject]@{ InputObject = $InputObject; WorksheetName = $WorksheetName; NoNumberConversion = $NoNumberConversion }
			}
		}
		Export-ModuleMember -Function Get-UnifiedEnvironment
	}
	Import-Module $fixture -Force
}

AfterAll {
	Get-Job -Name 'UnifiedEnvMsprovFixture' -ErrorAction SilentlyContinue | Stop-Job -ErrorAction SilentlyContinue
	Get-Job -Name 'UnifiedEnvMsprovFixture' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
}

Describe 'Get-UnifiedEnvironment version details' {
	BeforeEach {
		$catalog = [pscustomobject]@{
			versions = @(
				[pscustomobject]@{ appVersion = '10.0.49'; appBuild = '10.0.2790'; platVersion = '7.0.7120'; platBuild = '7.0.7120.42' }
			)
		}
		& (Get-Module UnifiedEnvBehaviorFixture) {
			param($c)
			$script:fixtureCatalog = $c
			$script:catalogCalls = 0
			$script:failCatalog = $false
			$script:writeCalls = @()
		} $catalog
	}

	It 'resolves the installed build from the cache without a live catalog call' {
		$env = UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment | Where-Object PpacEnvName -eq 'finops-test-01' | Select-Object -First 1
		$env.PpacProvApp | Should -Be '10.0.2790.46'
		$env.EnvType | Should -Be 'USE'
		$env.AppVersion | Should -Be '10.0.49'
		$env.AppBuild | Should -Be '10.0.2790'
		$env.Track | Should -Be '10.0.2790'
		$env.Build | Should -Be '10.0.2790.46'
		$env.PlatVersion | Should -Be '7.0.7120'
		$env.PlatBuild | Should -Be '7.0.7120.42'
		$env.PlatformVersion | Should -Be '7.0.7120.42'
		& (Get-Module UnifiedEnvBehaviorFixture) { $script:catalogCalls } | Should -Be 0
	}

	It 'refreshes a cold cache from the live catalog and resolves the miss' {
		& (Get-Module UnifiedEnvBehaviorFixture) { $script:fixtureCatalog = $null }
		$env = UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment | Where-Object PpacEnvName -eq 'finops-test-01' | Select-Object -First 1
		$env.AppVersion | Should -Be '10.0.49'
		$env.AppBuild | Should -Be '10.0.2790'
		$env.Track | Should -Be '10.0.2790'
		$env.Build | Should -Be '10.0.2790.46'
		$env.PlatVersion | Should -Be '7.0.7120'
		$env.PlatBuild | Should -Be '7.0.7120.42'
		$env.PlatformVersion | Should -Be '7.0.7120.42'
		& (Get-Module UnifiedEnvBehaviorFixture) { $script:catalogCalls } | Should -Be 1
		$writes = @(& (Get-Module UnifiedEnvBehaviorFixture) { $script:writeCalls })
		$writes.Count | Should -Be 1
		$writes[0].Versions[0].appVersion | Should -Be '10.0.49'
	}

	It 'falls back to empty version details when the live catalog is unreachable' {
		& (Get-Module UnifiedEnvBehaviorFixture) {
			$script:fixtureCatalog = $null
			$script:failCatalog = $true
		}
		$env = UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment | Where-Object PpacEnvName -eq 'finops-test-01' | Select-Object -First 1
		$env.PpacProvApp | Should -Be '10.0.2790.46'
		$env.Build | Should -Be '10.0.2790.46'
		$env.PlatformVersion | Should -Be '7.0.7120.42'
		$env.AppVersion | Should -Be ''
		$env.AppBuild | Should -Be ''
		$env.Track | Should -Be ''
		$env.PlatVersion | Should -Be ''
		$env.PlatBuild | Should -Be ''
		$writes = @(& (Get-Module UnifiedEnvBehaviorFixture) { $script:writeCalls })
		$writes.Count | Should -Be 0
	}

	It 'returns empty version details for environments without provisioning data' {
		$broken = @(UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment | Where-Object PpacEnvName -eq 'finops-test-broken')
		$broken.Count | Should -Be 1
		$broken[0].EnvType | Should -Be 'N/A'
		$broken[0].Build | Should -Be ''
		$broken[0].AppVersion | Should -Be ''
		$broken[0].PlatformVersion | Should -Be ''
	}

	It 'keeps UdeOnly and UseOnly filtering on the enriched output' {
		$all = @(UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment)
		$all.Count | Should -Be 2
		$use = @(UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment -UseOnly)
		$use.Count | Should -Be 1
		$ude = @(UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment -UdeOnly)
		$ude.Count | Should -Be 0
	}

	It 'exports version fields without converting them into numbers' {
		$output = @(UnifiedEnvBehaviorFixture\Get-UnifiedEnvironment -EnvironmentId 'finops-test-01' -AsExcelOutput)
		$output.Count | Should -Be 0
		$exports = @(& (Get-Module UnifiedEnvBehaviorFixture) { $script:exportCalls })
		$exports.Count | Should -Be 1
		$exports[0].WorksheetName | Should -Be 'Get-UnifiedEnvironment'
		foreach ($field in @('AppVersion', 'AppBuild', 'Track', 'Build', 'PlatVersion', 'PlatBuild', 'PlatformVersion')) {
			$exports[0].NoNumberConversion | Should -Contain $field
		}
	}
}
