function Test-FinOpsClientLogin {
	<#
        .SYNOPSIS
            Checks for an Azure login without network calls.

        .DESCRIPTION
            Returns whether the selected login provider is available. Used to skip background work when nobody is logged in.

        .PARAMETER AuthProvider
            Login provider to check. Either AzAccount or AzCli.

            Default: AzAccount

        .EXAMPLE
            PS C:\> Test-FinOpsClientLogin -AuthProvider AzCli

            Checks for an Azure CLI login.
            It uses -AuthProvider AzCli to select the provider.
    #>
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[string] $AuthProvider = 'AzAccount'
	)

	if ($AuthProvider -eq 'AzCli') {
		$azCommand = Get-Command az -ErrorAction SilentlyContinue

		if ($null -eq $azCommand) { $false; return }

		& az account show -o json 2>$null > $null

		($LASTEXITCODE -eq 0)
		return
	}

	$azContext = Get-AzContext -ErrorAction SilentlyContinue

	-not ($null -eq $azContext)
}

function Get-FinOpsClientAuthContext {
	<#
        .SYNOPSIS
            Mints developer tools headers for a FinOps environment.

        .DESCRIPTION
            Signs in with the selected provider, picks the first FinOps environment and returns the headers, tenant, account, and environment URI for developer tools calls.

        .PARAMETER AuthProvider
            Login provider to use. Either AzAccount or AzCli.

            Default: AzAccount

        .PARAMETER ApiVersion
            API version for the environment lookup.

            Default: 2023-06-01

        .EXAMPLE
            PS C:\> Get-FinOpsClientAuthContext -AuthProvider AzAccount -ApiVersion '2023-06-01'

            Mints headers for the first FinOps environment.
            It uses -AuthProvider AzAccount to select the provider.
            It uses -ApiVersion '2023-06-01' for the environment lookup.
    #>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[string] $AuthProvider = 'AzAccount',

		[string] $ApiVersion = '2023-06-01'
	)

	$bapToken = $null
	$tenantId = ''
	$accountId = ''

	if ($AuthProvider -eq 'AzCli') {
		$tokenRaw = & az account get-access-token --resource 'https://service.powerapps.com/' --query accessToken -o tsv 2>$null

		if (($LASTEXITCODE -ne 0) `
				-or ([string]::IsNullOrWhiteSpace($tokenRaw))) {
			throw 'FinOps client login failed.'
		}

		$bapToken = "$tokenRaw".Trim()
		$accountRaw = & az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null

		if (($LASTEXITCODE -ne 0) `
				-or ([string]::IsNullOrWhiteSpace($accountRaw))) {
			throw 'FinOps client login failed.'
		}

		$accountObj = "$accountRaw" |
		ConvertFrom-Json -ErrorAction Stop

		$accountId = "$($accountObj.user)"
		$tenantId = "$($accountObj.tenant)"
	}
	else {
		$bapTokenResult = Get-AzAccessToken -ResourceUrl 'https://service.powerapps.com/' `
			-ErrorAction Stop

		if ($bapTokenResult.Token -is [System.Security.SecureString]) {
			$bapToken = ConvertFrom-SecureString -AsPlainText `
				-SecureString $bapTokenResult.Token
		}
		else {
			$bapToken = "$($bapTokenResult.Token)"
		}

		$jobContext = Get-AzContext -ErrorAction SilentlyContinue

		if (-not ($null -eq $jobContext)) {
			$accountId = "$($jobContext.Account.Id)"
			$tenantId = "$($jobContext.Tenant.Id)"
		}
	}

	if ([string]::IsNullOrWhiteSpace($bapToken)) {
		throw 'FinOps client login failed.'
	}

	$hashBapHeaders = @{ Authorization = "Bearer $bapToken" }

	$colEnvs = Invoke-RestMethod -Method Get `
		-Uri ('https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version={0}' `
			-f $ApiVersion) `
		-Headers $hashBapHeaders `
		-ConnectionTimeoutSeconds 60 |
	Select-Object -ExpandProperty value

	$colFinopsEnvs = @(
		$colEnvs |
		Where-Object { -not ($null -eq $_.properties.linkedAppMetadata.type) } |
		Sort-Object { $_.properties.displayName }
	)

	if ($colFinopsEnvs.Count -eq 0) {
		throw 'FinOps client found no FinOps environment.'
	}

	$tmpAuthEnvUri = ("$($colFinopsEnvs[0].properties.linkedEnvironmentMetadata.instanceUrl)" -replace 'com/', 'com').TrimEnd('/') + '/'
	$dataverseToken = $null

	if ($AuthProvider -eq 'AzCli') {
		$dvRaw = & az account get-access-token --resource $tmpAuthEnvUri --query accessToken -o tsv 2>$null

		if (($LASTEXITCODE -ne 0) `
				-or ([string]::IsNullOrWhiteSpace($dvRaw))) {
			throw 'FinOps client login failed.'
		}

		$dataverseToken = "$dvRaw".Trim()
	}
	else {
		$dvResult = Get-AzAccessToken -ResourceUrl $tmpAuthEnvUri `
			-ErrorAction Stop

		if ($dvResult.Token -is [System.Security.SecureString]) {
			$dataverseToken = ConvertFrom-SecureString -AsPlainText `
				-SecureString $dvResult.Token
		}
		else {
			$dataverseToken = "$($dvResult.Token)"
		}
	}

	if ([string]::IsNullOrWhiteSpace($dataverseToken)) {
		throw 'FinOps client login failed.'
	}

	[ordered]@{
		Headers   = @{
			Correlationid           = [guid]::NewGuid().ToString()
			Dataverseenvironmenturi = $tmpAuthEnvUri.TrimEnd('/')
			Authorization           = "Bearer $dataverseToken"
			'Odata-Maxversion'      = '4.0'
			'Odata-Version'         = '4.0'
			Accept                  = 'application/json'
		}
		TenantId  = "$tenantId"
		AccountId = "$accountId"
		EnvUri    = "$tmpAuthEnvUri"
	}
}

function Get-FinOpsClientCatalog {
	<#
        .SYNOPSIS
            Lists every published FinOps application track.

        .DESCRIPTION
            Queries the developer tools service for the version catalog.

        .PARAMETER Headers
            Headers for the developer tools service call.

        .EXAMPLE
            PS C:\> Get-FinOpsClientCatalog -Headers $hashDevHeaders

            Lists every published application track.
            It uses -Headers $hashDevHeaders for the service call.
    #>
	[CmdletBinding()]
	[OutputType([object[]])]
	param (
		[hashtable] $Headers
	)

	if ($null -eq $Headers) {
		throw 'FinOps client call needs headers.'
	}

	$tmpVersions = Invoke-RestMethod -Method Get `
		-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
		-Headers $Headers `
		-ConnectionTimeoutSeconds 60 `
		-ErrorAction Stop

	if ($null -eq $tmpVersions) {
		, @()
	}
	else {
		, @($tmpVersions)
	}
}

function Get-FinOpsClientBuildList {
	<#
        .SYNOPSIS
            Lists quality updates for a FinOps track.

        .DESCRIPTION
            Queries the developer tools service for every published quality update of one application release.

        .PARAMETER Track
            Application track to list, such as 10.0.2790.

        .PARAMETER Headers
            Headers for the developer tools service call.

        .EXAMPLE
            PS C:\> Get-FinOpsClientBuildList -Track '10.0.2790' -Headers $hashDevHeaders

            Lists all builds of the 10.0.2790 track.
            It uses -Track '10.0.2790' to select the track.
            It uses -Headers $hashDevHeaders for the service call.
    #>
	[CmdletBinding()]
	[OutputType([object[]])]
	param (
		[string] $Track,

		[hashtable] $Headers
	)

	if ([string]::IsNullOrWhiteSpace($Track)) {
		throw 'FinOps client call needs a track.'
	}

	if ($null -eq $Headers) {
		throw 'FinOps client call needs headers.'
	}

	$tmpBuilds = Invoke-RestMethod -Method Get `
		-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
			-f $Track.Replace('.', '-')) `
		-Headers $Headers `
		-ConnectionTimeoutSeconds 60 `
		-ErrorAction Stop

	if ($null -eq $tmpBuilds) {
		, @()
	}
	else {
		, @($tmpBuilds)
	}
}

function Get-FinOpsClientPlatform {
	<#
        .SYNOPSIS
            Resolves the platform version of a build.

        .DESCRIPTION
            Queries the developer tools service for the platform version of one application release. Returns nothing when the platform cannot be resolved.

        .PARAMETER Build
            Full application build to resolve, such as 10.0.2790.87.

        .PARAMETER Headers
            Headers for the developer tools service call.

        .EXAMPLE
            PS C:\> Get-FinOpsClientPlatform -Build '10.0.2790.87' -Headers $hashDevHeaders

            Resolves the platform of that build.
            It uses -Build '10.0.2790.87' to select the build.
            It uses -Headers $hashDevHeaders for the service call.
    #>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[string] $Build,

		[hashtable] $Headers
	)

	if ([string]::IsNullOrWhiteSpace($Build)) {
		throw 'FinOps client call needs a build.'
	}

	if ($null -eq $Headers) {
		throw 'FinOps client call needs headers.'
	}

	$tmpPlat = Invoke-RestMethod -Method Get `
		-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
			-f $Build.Replace('.', '-')) `
		-Headers $Headers `
		-ConnectionTimeoutSeconds 60 `
		-ErrorAction Stop

	"$tmpPlat"
}

function Select-FinOpsTopTrack {
	<#
        .SYNOPSIS
            Selects the newest FinOps application tracks.

        .DESCRIPTION
            Sorts version catalog entries by application version and returns the newest track names. Accepts raw and cached catalog shapes.

        .PARAMETER Versions
            Version catalog entries to sort.

        .PARAMETER Count
            How many tracks to select.

            Default: 3

        .EXAMPLE
            PS C:\> Select-FinOpsTopTrack -Versions $catalog -Count 3

            Selects the three newest tracks.
            It uses -Versions $catalog as the catalog to sort.
            It uses -Count 3 to keep three tracks.
    #>
	[CmdletBinding()]
	[OutputType([string[]])]
	param (
		$Versions,

		[int] $Count = 3
	)

	if ($null -eq $Versions) {
		, @()
		return
	}

	$colVersionRows = [System.Collections.Generic.List[object]]::new()

	foreach ($itemVersion in @($Versions)) {
		if (-not ($null -eq $itemVersion.AppVersion)) {
			$tmpAppName = "$($itemVersion.AppVersion)"
			$tmpTrackName = "$($itemVersion.AppBuild)"
		}
		else {
			$tmpAppName = "$($itemVersion.appVersion)"
			$tmpTrackName = "$($itemVersion.appBuild)"
		}

		$tmpRow = [PsCustomObject][Ordered]@{
			Track = $tmpTrackName
			App   = $tmpAppName
		}

		$colVersionRows.Add($tmpRow)
	}

	, @(
		$colVersionRows |
		Sort-Object -Property { [version]$_.App } `
			-Descending |
		Select-Object -ExpandProperty Track |
		Select-Object -First $Count
	)
}

function Read-FinOpsClientCache {
	<#
        .SYNOPSIS
            Reads the cached FinOps version catalog.

        .DESCRIPTION
            Returns the catalog as stored on disk without validating the active login. Returns nothing when the file is missing or unreadable.

        .PARAMETER Path
            Path to the cache file.

        .EXAMPLE
            PS C:\> Read-FinOpsClientCache -Path $CachePath

            Returns the cached catalog without checking the active login.
            It uses -Path $CachePath to locate the cache file.
    #>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[string] $Path
	)

	if ([string]::IsNullOrWhiteSpace($Path)) {
		$null
		return
	}

	try {
		$tmpState = Get-Content -LiteralPath $Path `
			-Raw `
			-Encoding utf8 `
			-ErrorAction Stop |
		ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		$null
		return
	}

	$tmpState
}

function Write-FinOpsClientCache {
	<#
        .SYNOPSIS
            Merges data into the FinOps version cache file.

        .DESCRIPTION
            Merges the given catalog sections into the cache file on disk and stamps it with the given tenant and account. Sections left out keep their stored values. Stored entries from another tenant are dropped.

        .PARAMETER Path
            Path to the cache file.

        .PARAMETER Versions
            Catalog rows to store, replacing the stored rows.

        .PARAMETER Builds
            Build lists per track to merge into the stored lists.

        .PARAMETER Platforms
            Platform versions per build to merge into the stored map.

        .PARAMETER TenantId
            Tenant to stamp the cache file with.

        .PARAMETER AccountId
            Account to stamp the cache file with.

        .EXAMPLE
            PS C:\> Write-FinOpsClientCache -Path $CachePath -Platforms $hashPlatforms -TenantId $TenantId -AccountId $AccountId

            Merges platform versions into the cache file.
            It uses -Path $CachePath to locate the cache file.
            It uses -Platforms $hashPlatforms to merge the platform map.
            It uses -TenantId $TenantId to stamp the cache file.
            It uses -AccountId $AccountId to stamp the cache file.
    #>
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[string] $Path,

		[object[]] $Versions,

		[hashtable] $Builds,

		[hashtable] $Platforms,

		[string] $TenantId,

		[string] $AccountId
	)

	$objCurrent = $null

	if ((-not ([string]::IsNullOrWhiteSpace($Path))) `
			-and (Test-Path -LiteralPath $Path)) {
		try {
			$objCurrent = Get-Content -LiteralPath $Path `
				-Raw `
				-Encoding utf8 `
				-ErrorAction Stop |
			ConvertFrom-Json -ErrorAction Stop
		}
		catch {
			$objCurrent = $null
		}
	}

	$colFinalVersions = @()

	if (-not ($null -eq $Versions)) {
		$colFinalVersions = @($Versions)
	}
	elseif ((-not ($null -eq $objCurrent)) `
			-and (-not ($null -eq $objCurrent.versions))) {
		$colFinalVersions = @($objCurrent.versions)
	}

	if ($colFinalVersions.Count -eq 0) { return }

	$hashMergedBuilds = @{}

	if (-not ($null -eq $objCurrent)) {
		if (-not ($null -eq $objCurrent.builds)) {
			foreach ($itemProperty in $objCurrent.builds.PSObject.Properties) {
				$hashMergedBuilds["$($itemProperty.Name)"] = @($itemProperty.Value)
			}
		}
	}

	if (-not ($null -eq $Builds)) {
		foreach ($itemKey in $Builds.Keys) {
			$hashMergedBuilds["$itemKey"] = @($Builds[$itemKey])
		}
	}

	$hashMergedPlatforms = @{}
	$keepPrior = $false

	if (-not ($null -eq $objCurrent)) {
		if (-not ($null -eq $objCurrent.platforms)) {
			$fileTenant = "$($objCurrent.tenantId)"

			if ([string]::IsNullOrWhiteSpace($fileTenant)) {
				$keepPrior = $true
			}
			elseif ($fileTenant -eq $TenantId) {
				$keepPrior = $true
			}
		}
	}

	if ($keepPrior) {
		foreach ($itemProperty in $objCurrent.platforms.PSObject.Properties) {
			$hashMergedPlatforms["$($itemProperty.Name)"] = "$($itemProperty.Value)"
		}
	}

	if (-not ($null -eq $Platforms)) {
		foreach ($itemKey in $Platforms.Keys) {
			$hashMergedPlatforms["$itemKey"] = "$($Platforms[$itemKey])"
		}
	}

	$hashPayload = [ordered]@{
		refreshedUtc = [datetime]::UtcNow.ToString('o')
		tenantId     = "$TenantId"
		accountId    = "$AccountId"
		versions     = $colFinalVersions
		builds       = $hashMergedBuilds
		platforms    = $hashMergedPlatforms
	}

	New-Item -ItemType Directory `
		-Path (Split-Path -Parent $Path) `
		-Force `
		-ErrorAction Stop > $null

	$hashPayload |
	ConvertTo-Json -Depth 6 `
		-ErrorAction Stop |
	Set-Content -LiteralPath $Path `
		-Encoding utf8 `
		-ErrorAction Stop
}
