<#
    .SYNOPSIS
        Imports a managed solution ZIP into Dataverse and waits for completion.

    .DESCRIPTION
        Skips the import when the same or a newer managed version is installed.
        Waits for active solution imports before submitting a new one, then verifies
        the installed version. Managed components are published during import.

    .PARAMETER EnvironmentId
        The environment name or ID accepted by Get-BapEnvironment.

    .PARAMETER Path
        The literal path to the managed solution ZIP.

    .PARAMETER PollIntervalSeconds
        Seconds between status checks.
        Default: 15

    .PARAMETER TimeoutMinutes
        Maximum minutes to wait for import, version checks, and optional publishing.
        Default: 60

    .PARAMETER PublishAndWait
        Publishes all customizations and waits after a successful import.

    .PARAMETER Silent
        Suppresses status messages. The result and errors are still returned.

    .EXAMPLE
        PS C:\> Import-PpeSolution -EnvironmentId 'Contoso Demo' -Path '.\ContosoDemo_1_0_0_0_managed.zip' -PublishAndWait

        It targets Contoso Demo using -EnvironmentId.
        It reads the managed ZIP specified by -Path.
        It checks every 15 seconds by default when -PollIntervalSeconds is omitted.
        It waits up to 60 minutes by default when -TimeoutMinutes is omitted.
        It publishes all customizations and waits using -PublishAndWait.
        It displays status messages by default when -Silent is omitted.
#>
function Import-PpeSolution {
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,

		[ValidateRange(5, 60)]
		[int] $PollIntervalSeconds = 15,

		[ValidateRange(1, 1440)]
		[int] $TimeoutMinutes = 60,

		[switch] $PublishAndWait,

		[switch] $Silent
	)

	$package = Get-Item -LiteralPath $Path `
		-ErrorAction Stop

	if (($package -isnot [System.IO.FileInfo]) `
			-or ($package.Extension -ne '.zip')) {
		throw "Expected a managed solution ZIP file at '$Path'."
	}

	$archive = [System.IO.Compression.ZipFile]::OpenRead($package.FullName)
	try {
		$entry = $archive.GetEntry('solution.xml')
		if ($null -eq $entry) { throw "The ZIP '$Path' is missing solution.xml." }

		$stream = $entry.Open()
		try {
			$manifest = [System.Xml.XmlDocument]::new()
			$manifest.Load($stream)
		}
		finally {
			$stream.Dispose()
		}
	}
	finally {
		$archive.Dispose()
	}

	$solution = $manifest.ImportExportXml.SolutionManifest
	$solutionName = [string] $solution.UniqueName
	$version = $null
	if (($solution.Managed -ne '1') `
			-or ($solutionName -notmatch '^[a-zA-Z0-9_]+$') `
			-or (-not [version]::TryParse($solution.Version, [ref] $version))) {
		throw "The ZIP '$Path' must contain a managed solution with a valid unique name and version."
	}

	$envObj = Get-Environment -EnvironmentId $EnvironmentId `
		-ErrorAction Stop

	if ((@($envObj).Count -ne 1) `
			-or (-not $envObj.PpacEnvUri)) {
		throw "Expected exactly one Dataverse environment for '$EnvironmentId'."
	}

	$orgUrl = $envObj.PpacEnvUri.TrimEnd('/')
	$apiUrl = "$orgUrl/api/data/v9.2"
	$solutionFilter = [uri]::EscapeDataString("uniquename eq '$solutionName'")
	$solutionUri = "$apiUrl/solutions?" + '$select=version,ismanaged&$filter=' + $solutionFilter
	$importSolutionAsyncOperationType = 203
	$activeFilter = [uri]::EscapeDataString("operationtype eq $importSolutionAsyncOperationType and statecode ne 3")
	$activeUri = "$apiUrl/asyncoperations?" + '$select=asyncoperationid&$top=1&$filter=' + $activeFilter
	$deadline = [datetime]::UtcNow.AddMinutes($TimeoutMinutes)
	$hashRestParams = @{ Authentication = 'Bearer'; ErrorAction = 'Stop' }

	$operationId = $null
	$importJobId = $null
	$approved = $false
	$status = 'Skipped'
	$publishDescription = $PublishAndWait ? ' and publish all customizations' : ''
	do {
		$hashRestParams.Token = Get-BapAccessToken -ResourceUrl $orgUrl

		$tmpInstalled = (Invoke-RestMethod -Uri $solutionUri @hashRestParams).value |
		Select-Object -First 1
		if ((-not ($null -eq $tmpInstalled)) `
				-and (-not $tmpInstalled.ismanaged)) {
			throw "An unmanaged solution named '$solutionName' already exists in '$($envObj.PpacEnvName)'."
		}

		if ((-not ($null -eq $tmpInstalled)) `
				-and ([version] $tmpInstalled.version -ge $version)) {
			break
		}

		if ([datetime]::UtcNow -ge $deadline) {
			throw "Timed out waiting for '$solutionName' $version in '$($envObj.PpacEnvName)' (operation '$operationId', import job '$importJobId')."
		}

		if (-not $operationId) {
			if (-not $approved) {
				$shouldAffected = $envObj.PpacEnvName
				$shouldLabel = "Import $solutionName $version$publishDescription"

				if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
				$approved = $true
			}

			$status = 'Installing'
			$active = (Invoke-RestMethod -Uri $activeUri @hashRestParams).value
			if (-not $active) {
				$importJobId = [guid]::NewGuid()
				$body = @{
					CustomizationFile                = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($package.FullName))
					ImportJobId                      = $importJobId
					OverwriteUnmanagedCustomizations = $false
					PublishWorkflows                 = $false
				} | ConvertTo-Json -Compress

				$response = Invoke-RestMethod @hashRestParams -Method Post `
					-Uri "$apiUrl/ImportSolutionAsync" `
					-ContentType 'application/json' `
					-Body $body

				$operationId = $response.AsyncOperationId
				if (-not $operationId) { throw "Dataverse did not return an operation ID for import job '$importJobId'." }

				Wait-PpeAsyncOperation -OperationId $operationId `
					-OrganizationUrl $orgUrl `
					-Activity "Import $solutionName $version" `
					-Deadline $deadline `
					-PollIntervalSeconds $PollIntervalSeconds `
					-Silent:$Silent

				continue
			}

			if (-not $Silent) {
				Write-PSFMessage -Level Important `
					-Message "Waiting for Dataverse import job $($active.asyncoperationid) before importing $solutionName."
			}
		}
		elseif (-not $Silent) {
			Write-PSFMessage -Level Important `
				-Message "Waiting for Dataverse to show $solutionName $version."
		}

		$tmpRemainingSeconds = ($deadline - [datetime]::UtcNow).TotalSeconds
		Start-Sleep -Seconds ([Math]::Max(0, [Math]::Min($PollIntervalSeconds, $tmpRemainingSeconds)))
	} while ($true)

	if (($PublishAndWait) `
			-and ($status -eq 'Installing')) {
		if ([datetime]::UtcNow -ge $deadline) {
			throw "Import completed, but the timeout expired before publishing. Run Invoke-PpePublishAllCustomizations to publish."
		}

		$publish = Invoke-RestMethod @hashRestParams -Method Post `
			-Uri "$apiUrl/PublishAllXmlAsync" `
			-ContentType 'application/json' `
			-Body '{}'

		if (-not $publish.AsyncOperationId) { throw "Dataverse did not return a publish job ID." }

		Wait-PpeAsyncOperation -OperationId $publish.AsyncOperationId `
			-OrganizationUrl $orgUrl `
			-Activity "Publish all customizations in $($envObj.PpacEnvName)" `
			-Deadline $deadline `
			-PollIntervalSeconds $PollIntervalSeconds `
			-Silent:$Silent
	}

	[PSCustomObject][ordered]@{
		EnvironmentId    = $envObj.PpacEnvId
		SolutionName     = $solutionName
		InstalledVersion = $tmpInstalled.version
		Status           = $status
		OperationId      = $operationId
	}
}
