$script:ProvisioningCache = $null
$script:ProvisioningCatalogLoaded = $false
$script:ProvisioningV2TemplateFilter = @('D365_FinOps*', 'D365_DeveloperEdition')

function Get-ProvisioningUserCachePath {
	<#
    .SYNOPSIS
        Returns the path of the user provisioning cache file.

    .DESCRIPTION
        The background refresh writes the cache there and the next import reads it.
    #>
	[CmdletBinding()]
	param ()

	$base = if ($env:APPDATA) {
		$env:APPDATA
	}
	else {
		Join-Path $HOME '.config'
	}
	Join-Path (Join-Path $base 'd365bap.tools') 'provisioning-cache.json'
}

function Get-ProvisioningTenantDefaultsPath {
	<#
    .SYNOPSIS
        Returns the path of the per-tenant provisioning defaults store.

    .DESCRIPTION
        The store is keyed by tenant and account and is written by the background refresh.
    #>
	[CmdletBinding()]
	param ()

	$base = if ($env:APPDATA) {
		$env:APPDATA
	}
	else {
		Join-Path $HOME '.config'
	}
	Join-Path (Join-Path $base 'd365bap.tools') 'provisioning-tenant-defaults.json'
}

function Import-ProvisioningCache {
	<#
    .SYNOPSIS
        Loads the tenant neutral provisioning discovery cache into memory.

    .DESCRIPTION
        Reads the shipped snapshot and overlays the user cache, which the throttled
        background refresh keeps current. Tenant defaults are never stored here.
    #>
	[CmdletBinding()]
	param ()

	$script:ProvisioningCache = @{ locations = @(); templates = @{} }
	$script:ProvisioningCatalogLoaded = $false

	$shipped = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-cache.json'
	if (Test-Path -LiteralPath $shipped) {
		$script:ProvisioningCache = Get-Content -LiteralPath $shipped `
			-Raw `
			-Encoding utf8 |
		ConvertFrom-Json -AsHashtable `
			-ErrorAction Stop
	}

	$userPath = Get-ProvisioningUserCachePath
	if (Test-Path -LiteralPath $userPath) {
		try {
			$overlay = Get-Content -LiteralPath $userPath `
				-Raw `
				-Encoding utf8 |
			ConvertFrom-Json -AsHashtable `
				-ErrorAction Stop

			foreach ($itemKey in @('locations', 'templates', 'refreshedUtc')) {
				if ($overlay.ContainsKey($itemKey)) { $script:ProvisioningCache[$itemKey] = $overlay[$itemKey] }
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Ignoring unreadable provisioning cache at $userPath : $($_.Exception.Message)"
		}
	}

	Publish-ProvisioningCompletionData
}

function Import-ProvisioningCatalog {
	<#
    .SYNOPSIS
        Loads the tenant neutral language and currency catalogs into memory.

    .DESCRIPTION
        Runs on demand only, so module import stays fast.
    #>
	[CmdletBinding()]
	param ()

	if ($script:ProvisioningCatalogLoaded) { return }

	$hashCatalog = @{ languages = @{}; currencies = @{} }

	$shipped = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json'
	if (Test-Path -LiteralPath $shipped) {
		try {
			$shippedCatalog = Get-Content -LiteralPath $shipped `
				-Raw `
				-Encoding utf8 |
			ConvertFrom-Json -AsHashtable `
				-ErrorAction Stop

			foreach ($itemKey in @('languages', 'currencies')) {
				if ($shippedCatalog.ContainsKey($itemKey)) { $hashCatalog[$itemKey] = $shippedCatalog[$itemKey] }
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Ignoring unreadable provisioning catalog at $shipped : $($_.Exception.Message)"
		}
	}

	$userPath = Get-ProvisioningUserCachePath
	if (Test-Path -LiteralPath $userPath) {
		try {
			$overlay = Get-Content -LiteralPath $userPath `
				-Raw `
				-Encoding utf8 |
			ConvertFrom-Json -AsHashtable `
				-ErrorAction Stop

			foreach ($itemKey in @('languages', 'currencies')) {
				if ($overlay.ContainsKey($itemKey)) { $hashCatalog[$itemKey] = $overlay[$itemKey] }
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Ignoring unreadable provisioning catalog at $userPath : $($_.Exception.Message)"
		}
	}

	$script:ProvisioningCache['languages'] = $hashCatalog['languages']
	$script:ProvisioningCache['currencies'] = $hashCatalog['currencies']
	$script:ProvisioningCatalogLoaded = $true
	Publish-ProvisioningCatalogData
}

function Get-ProvisioningCatalog {
	<#
    .SYNOPSIS
        Returns the in-memory language and currency catalogs.

    .DESCRIPTION
        Loads the catalogs on first use. Powers tab completion for non-default deployments.
    #>
	[CmdletBinding()]
	param ()

	Import-ProvisioningCatalog

	[pscustomobject][ordered]@{
		Languages  = $script:ProvisioningCache['languages']
		Currencies = $script:ProvisioningCache['currencies']
	}
}

function Get-ProvisioningTenantDefaultCache {
	<#
    .SYNOPSIS
        Reads the stored tenant default language and currency.

    .DESCRIPTION
        Looks up the current tenant and account in the store written by the background
        refresh. Emits $null when nothing was stored yet. Live callers stay authoritative.
    #>
	[CmdletBinding()]
	param ()

	$objAzContext = Get-BapContext -AllowEmpty
	if ($null -eq $objAzContext) {
		$null
		return
	}

	$storePath = Get-ProvisioningTenantDefaultsPath
	if (-not (Test-Path -LiteralPath $storePath)) {
		$null
		return
	}

	try {
		$store = Get-Content -LiteralPath $storePath `
			-Raw `
			-Encoding utf8 |
		ConvertFrom-Json -AsHashtable `
			-ErrorAction Stop

		$key = "$($objAzContext.TenantId)/$($objAzContext.Upn)"
		if ($store.ContainsKey($key)) {
			$store[$key]
			return
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "Ignoring unreadable tenant defaults at $storePath : $($_.Exception.Message)"
	}

	$null
}

function Publish-ProvisioningCatalogData {
	<#
    .SYNOPSIS
        Publishes the in-memory language and currency catalogs for tab completion.

    .DESCRIPTION
        Called after the catalog is loaded, whenever that happens.
    #>
	[CmdletBinding()]
	param ()

	Set-PSFConfig -FullName 'd365bap.tools.provisioning.languages' `
		-Value $script:ProvisioningCache['languages'] `
		-Description 'Power Platform provisioning languages per location for tab completion.'

	Set-PSFConfig -FullName 'd365bap.tools.provisioning.currencies' `
		-Value $script:ProvisioningCache['currencies'] `
		-Description 'Power Platform provisioning currencies per location for tab completion.'
}

function Start-ProvisioningCatalogPreload {
	<#
    .SYNOPSIS
        Parses the language and currency catalogs in a background worker.

    .DESCRIPTION
        Keeps import fast. A StateChanged action merges the result into module scope and
        removes the worker by name. The event name differs from the worker name, or that
        removal disposes the action's own job and pwsh crashes on exit.
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseUsingScopeModifierInNewRunspaces", "", Justification = "Start-Job binds values through ArgumentList, the using scope modifier is not supported there.")]
	[CmdletBinding()]
	param ()

	$sourceId = 'd365bap.tools.provisioning.catalog.preload.event'
	$jobName = 'd365bap.tools.provisioning.catalog.preload'

	if ($script:ProvisioningCatalogLoaded) { return }

	$objRunningJob = Get-Job -Name $jobName `
		-ErrorAction SilentlyContinue |
	Where-Object State -eq 'Running' |
	Select-Object -First 1
	$colSubscriber = @(
		Get-EventSubscriber -SourceIdentifier $sourceId `
			-ErrorAction SilentlyContinue
	)
	if ($colSubscriber) {
		if ($objRunningJob) { return }
		Unregister-Event -SourceIdentifier $sourceId `
			-ErrorAction SilentlyContinue
	}

	$module = $ExecutionContext.SessionState.Module
	if (-not $module) { return }

	if (-not $objRunningJob) {
		$shippedCatalogPath = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json'
		$userPath = Get-ProvisioningUserCachePath
		$objRunningJob = Start-Job -Name $jobName `
			-ScriptBlock {
			param ([string] $ShippedPath, [string] $UserPath)

			$hashCatalog = @{ languages = @{}; currencies = @{} }
			foreach ($itemPath in @($ShippedPath, $UserPath)) {
				if ((-not $itemPath) `
						-or (-not (Test-Path -LiteralPath $itemPath))) { continue }

				try {
					$data = Get-Content -LiteralPath $itemPath `
						-Raw `
						-Encoding utf8 |
					ConvertFrom-Json -AsHashtable `
						-ErrorAction Stop

					foreach ($itemKey in @('languages', 'currencies')) {
						if ($data.ContainsKey($itemKey)) {
							foreach ($itemLocationKey in @($data[$itemKey].Keys)) {
								$hashCatalog[$itemKey][$itemLocationKey] = @($data[$itemKey][$itemLocationKey])
							}
						}
					}
				}
				catch { $_.Exception.Message > $null }
			}
			$hashCatalog
		} `
			-ArgumentList $shippedCatalogPath, $userPath
	}

	Register-ObjectEvent -InputObject $objRunningJob `
		-EventName StateChanged `
		-SourceIdentifier $sourceId `
		-MessageData $module `
		-Action {
		try {
			if ($Event.Sender.State -eq 'Completed') {
				$catalog = Receive-Job -Job $Event.Sender `
					-ErrorAction Stop

				& $Event.MessageData {
					param ($loaded)
					if ($null -eq $loaded) { return }
					foreach ($itemKey in @('languages', 'currencies')) {
						if ($loaded.ContainsKey($itemKey)) { $script:ProvisioningCache[$itemKey] = $loaded[$itemKey] }
					}
					$script:ProvisioningCatalogLoaded = $true
					Publish-ProvisioningCatalogData
				} $catalog
			}
		}
		catch { $_.Exception.Message > $null }
		finally {
			Unregister-Event -SourceIdentifier 'd365bap.tools.provisioning.catalog.preload.event' `
				-ErrorAction SilentlyContinue

			Remove-Job -Name 'd365bap.tools.provisioning.catalog.preload' `
				-Force `
				-ErrorAction SilentlyContinue
		}
	} > $null
}

function Publish-ProvisioningCompletionData {
	<#
    .SYNOPSIS
        Publishes the provisioning discovery data for tab completion.

    .DESCRIPTION
        Includes the template allow-list that New-UnifiedEnvironmentV2 validates and
        completes. The discovery cache keeps every template the API returns.
    #>
	[CmdletBinding()]
	param ()

	$colLocations = @($script:ProvisioningCache.locations)
	Set-PSFConfig -FullName 'd365bap.tools.provisioning.locations' `
		-Value $colLocations `
		-Description 'Power Platform provisioning locations for tab completion.'

	Set-PSFConfig -FullName 'd365bap.tools.provisioning.v2TemplateFilter' `
		-Value $script:ProvisioningV2TemplateFilter `
		-Description 'Template allow-list for New-UnifiedEnvironmentV2 tab completion.'

	Set-PSFConfig -FullName 'd365bap.tools.provisioning.catalogPath' `
		-Value (Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json') `
		-Description 'Shipped language and currency catalog for tab completion.'

	Set-PSFConfig -FullName 'd365bap.tools.provisioning.userCachePath' `
		-Value (Get-ProvisioningUserCachePath) `
		-Description 'User language and currency cache for tab completion.'

	$hashTemplateIndex = @{}
	foreach ($itemLocationName in @($script:ProvisioningCache.templates.Keys)) {
		$hashTemplateIndex[$itemLocationName] = @(
			$script:ProvisioningCache.templates[$itemLocationName] |
			ForEach-Object {
				@{
					name        = $_.name
					displayName = $_.displayName
					skus        = @(
						$_.availability |
						Where-Object { -not $_.isDisabled } |
						ForEach-Object { $_.environmentSku }
					)
				}
			}
		)
	}
	Set-PSFConfig -FullName 'd365bap.tools.provisioning.templates' `
		-Value $hashTemplateIndex `
		-Description 'Provisioning templates per location for tab completion.'
}

function Start-ProvisioningCacheRefresh {
	<#
    .SYNOPSIS
        Refreshes the provisioning discovery cache in a throttled background job.

    .DESCRIPTION
        The job writes the tenant neutral snapshot for the next import and resolves
        tenant defaults live into the per-tenant store. The auth provider is passed
        in, because the job process shares no module state.

    .PARAMETER MaxAgeHours
        Skips the refresh while the user cache is younger than this many hours.

        Default: 24
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseUsingScopeModifierInNewRunspaces", "", Justification = "Start-Job binds values through ArgumentList, the using scope modifier is not supported there.")]
	[CmdletBinding()]
	param (
		[int] $MaxAgeHours = 24
	)

	try {
		$userPath = Get-ProvisioningUserCachePath
		if (Test-Path -LiteralPath $userPath) {
			$age = [datetime]::UtcNow - (Get-Item -LiteralPath $userPath).LastWriteTimeUtc
			if ($age.TotalHours -lt $MaxAgeHours) { return }
		}

		$runningRefresh = Get-Job -Name 'd365bap.tools.provisioning.refresh' `
			-ErrorAction SilentlyContinue |
		Where-Object State -eq 'Running'
		if ($runningRefresh) { return }
		Get-Job -Name 'd365bap.tools.provisioning.refresh' `
			-ErrorAction SilentlyContinue |
		Remove-Job -Force `
			-ErrorAction SilentlyContinue

		$sdkRoot = Join-Path $script:ModuleRoot 'bin/PowerPlatformSdk'
		$tenantDefaultsPath = Get-ProvisioningTenantDefaultsPath

		$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		Start-Job -Name 'd365bap.tools.provisioning.refresh' `
			-ScriptBlock {
			param ([string] $CachePath, [string] $SdkRoot, [string] $ApiVersion, [string] $TenantDefaultsPath, [string] $AuthProvider, [string] $ModuleRoot)

			try {
				if ($AuthProvider -eq 'AzCli') {
					$azShow = az account show --query '{tenant:tenantId, user:user.name}' -o json 2>$null
					if (($LASTEXITCODE -ne 0) `
							-or ([string]::IsNullOrWhiteSpace($azShow))) { return }

					$azIdentity = "$azShow" |
					ConvertFrom-Json -ErrorAction Stop
					$azTenantId = "$($azIdentity.tenant)"
					$azAccountId = "$($azIdentity.user)"
					if (([string]::IsNullOrWhiteSpace($azTenantId)) `
							-or ([string]::IsNullOrWhiteSpace($azAccountId))) { return }
				}
				else {
					Import-Module Az.Accounts -ErrorAction Stop
					$azContext = Get-AzContext -ErrorAction SilentlyContinue
					if ((-not $azContext) `
							-or ([string]::IsNullOrWhiteSpace($azContext.Tenant.Id)) `
							-or ([string]::IsNullOrWhiteSpace($azContext.Account.Id))) { return }

					$azTenantId = $azContext.Tenant.Id
					$azAccountId = $azContext.Account.Id
				}

				foreach ($itemDll in @('Microsoft.Kiota.Abstractions.dll', 'Microsoft.Kiota.Serialization.Json.dll', 'Microsoft.Kiota.Http.HttpClientLibrary.dll', 'Microsoft.PowerPlatform.Management.dll', 'D365Bap.Tools.PowerPlatformSdk.dll')) {
					$dllPath = Join-Path $SdkRoot $itemDll
					if (-not (Test-Path -LiteralPath $dllPath)) { return }
					[System.Reflection.Assembly]::LoadFrom($dllPath) > $null
				}
				$objSdkAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
				Where-Object { $_.FullName -like 'D365Bap.Tools.PowerPlatformSdk,*' } |
				Select-Object -First 1
				$clientType = $objSdkAssembly.GetType('D365Bap.Tools.PowerPlatformSdk.SdkClient')
				if (-not $clientType) { return }
				$execute = $clientType.GetMethod('Execute')

				if (-not (Get-Command Get-BapAccessToken -ErrorAction SilentlyContinue)) {
					$helperPath = Join-Path $ModuleRoot 'internal/functions/Get-BapAccessToken.ps1'
					if (Test-Path -LiteralPath $helperPath) { . $helperPath }
					else { return }
				}

				$objSecure = Get-BapAccessToken -PowerPlatform
				$token = [Net.NetworkCredential]::new('', $objSecure).Password
				$base = 'https://api.powerplatform.com'

				$invokeSdk = {
					param ([string] $Builder, [string] $RequestUrl)
					$json = $execute.Invoke($null, @($Builder, 'GetAsync', $null, $ApiVersion, $null, $token, $RequestUrl))
					if ($json) {
						$json |
						ConvertFrom-Json
					}
				}

				$locationsUrl = '{0}/environmentmanagement/provisioning/locations?api-version={1}' `
					-f $base,
				$ApiVersion

				$locations = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.LocationsRequestBuilder' $locationsUrl).collection
				$hashSnapshot = [ordered]@{
					refreshedUtc = [datetime]::UtcNow.ToString('o')
					apiVersion   = $ApiVersion
					locations    = @(
						$locations |
						ForEach-Object {
							[ordered]@{
								name                                          = $_.name
								displayName                                   = $_.displayName
								code                                          = $_.code
								isDisabled                                    = $_.isDisabled
								canProvisionDatabase                          = $_.canProvisionDatabase
								hasFirstReleaseIslandAvailableForProvisioning = $_.hasFirstReleaseIslandAvailableForProvisioning
							}
						}
					)
					templates    = [ordered]@{}
					languages    = [ordered]@{}
					currencies   = [ordered]@{}
				}

				$colDefaultLocations = @(
					$locations |
					Where-Object { $_.isDefault } |
					ForEach-Object { $_.name }
				)
				$hashTenantDefaults = [ordered]@{}

				foreach ($itemLocation in @($locations.name)) {
					try {
						$templatesUrl = '{0}/environmentmanagement/provisioning/locations/{1}/templates?api-version={2}' `
							-f $base,
						$itemLocation,
						$ApiVersion

						$templates = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Templates.TemplatesRequestBuilder' $templatesUrl).collection
						$hashSnapshot.templates[$itemLocation] = @(
							$templates |
							ForEach-Object {
								[ordered]@{
									name                         = $_.name
									displayName                  = $_.displayName
									isCustomerEngagement         = $_.isCustomerEngagement
									isSupportedForResetOperation = $_.isSupportedForResetOperation
									availability                 = @(
										$_.availability |
										ForEach-Object {
											$tmpSlot = [ordered]@{ environmentSku = $_.environmentSku; isDisabled = $_.isDisabled }
											if ($_.disabledReason) { $tmpSlot.disabledReason = [ordered]@{ code = $_.disabledReason.code } }
											$tmpSlot
										}
									)
								}
							}
						)

						$languagesUrl = '{0}/environmentmanagement/provisioning/locations/{1}/languages?api-version={2}' `
							-f $base,
						$itemLocation,
						$ApiVersion

						$languages = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Languages.LanguagesRequestBuilder' $languagesUrl).collection
						$hashSnapshot.languages[$itemLocation] = @(
							$languages |
							ForEach-Object {
								[ordered]@{ localeId = $_.localeId; localizedName = $_.localizedName }
							}
						)

						$currenciesUrl = '{0}/environmentmanagement/provisioning/locations/{1}/currencies?api-version={2}' `
							-f $base,
						$itemLocation,
						$ApiVersion

						$currencies = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Currencies.CurrenciesRequestBuilder' $currenciesUrl).collection
						$hashSnapshot.currencies[$itemLocation] = @(
							$currencies |
							ForEach-Object {
								[ordered]@{ code = $_.code; symbol = $_.symbol }
							}
						)

						if ($itemLocation -in $colDefaultLocations) {
							$tmpLanguage = @(
								$languages |
								Where-Object { $_.isTenantDefault } |
								Select-Object -First 1
							)
							$tmpCurrency = @(
								$currencies |
								Where-Object { $_.isTenantDefault } |
								Select-Object -First 1
							)
							if (($tmpLanguage) `
									-and ($tmpCurrency)) {
								$tmpLocationEntry = $locations |
								Where-Object { $_.name -eq $itemLocation } |
								Select-Object -First 1
								$hashTenantDefaults[$itemLocation] = [ordered]@{
									locationDisplayName = $tmpLocationEntry.displayName
									language            = [ordered]@{ localeId = $tmpLanguage[0].localeId; localizedName = $tmpLanguage[0].localizedName }
									currency            = [ordered]@{ code = $tmpCurrency[0].code; symbol = $tmpCurrency[0].symbol }
								}
							}
						}
					}
					catch {
						Write-PSFMessage -Level Verbose `
							-Message "Provisioning refresh: skipping location '$itemLocation'."
					}
				}

				New-Item -ItemType Directory `
					-Path (Split-Path -Parent $CachePath) `
					-Force `
					-ErrorAction Stop > $null

				$hashSnapshot |
				ConvertTo-Json -Depth 8 `
					-ErrorAction Stop |
				Set-Content -LiteralPath $CachePath `
					-Encoding utf8 `
					-ErrorAction Stop

				$hashStore = @{}
				if (Test-Path -LiteralPath $TenantDefaultsPath) {
					try {
						$hashStore = Get-Content -LiteralPath $TenantDefaultsPath `
							-Raw `
							-Encoding utf8 |
						ConvertFrom-Json -AsHashtable `
							-ErrorAction Stop
					}
					catch {
						Write-PSFMessage -Level Verbose `
							-Message 'Provisioning refresh: starting a new tenant defaults store.'
					}
				}
				$hashStore["$azTenantId/$azAccountId"] = [ordered]@{
					tenantId         = $azTenantId
					account          = $azAccountId
					savedUtc         = [datetime]::UtcNow.ToString('o')
					apiVersion       = $ApiVersion
					defaultLocations = @($colDefaultLocations)
					defaults         = $hashTenantDefaults
				}
				$hashStore |
				ConvertTo-Json -Depth 8 `
					-ErrorAction Stop |
				Set-Content -LiteralPath $TenantDefaultsPath `
					-Encoding utf8 `
					-ErrorAction Stop
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message 'Provisioning refresh: background probe failed, keeping the previous cache.'
			}
		} `
			-ArgumentList $userPath, $sdkRoot, $script:BapSdkApiVersion, $tenantDefaultsPath, $authProvider, $script:ModuleRoot > $null
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "Provisioning refresh was skipped: $($_.Exception.Message)"
	}
}

function Resolve-ProvisioningLocation {
	<#
    .SYNOPSIS
        Resolves a provisioning region by name, wildcard or display name.

    .DESCRIPTION
        Matches the cached regions and throws with the valid values when no single match exists.
    #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Location
	)

	$colLocations = @($script:ProvisioningCache.locations)
	$colMatch = @(
		$colLocations |
		Where-Object { $_.name -eq $Location }
	)
	if (-not $colMatch) {
		$colMatch = @(
			$colLocations |
			Where-Object { $_.name -like $Location }
		)
	}
	if ($colMatch.Count -eq 1) {
		$colMatch[0].name
		return
	}
	if (-not $colMatch) {
		$colMatch = @(
			$colLocations |
			Where-Object { $_.displayName -like $Location }
		)
	}
	if ($colMatch.Count -eq 1) {
		$colMatch[0].name
		return
	}

	$colValid = @(
		$colLocations |
		ForEach-Object { $_.name } |
		Sort-Object -Unique
	)
	throw "Unknown location '$Location'. Valid values: $($colValid -join ', ')."
}

function Resolve-ProvisioningTemplate {
	<#
    .SYNOPSIS
        Resolves a provisioning template name for a region and SKU.

    .DESCRIPTION
        Throws when no single match or SKU slot exists. A disabled slot only warns,
        because availability flags have been observed to disagree across calls.

    .PARAMETER Location
        Region name as stored in the discovery cache.

    .PARAMETER Template
        Template name or wildcard pattern.

    .PARAMETER EnvironmentSku
        Environment SKU slot the template must offer.

        Default: Sandbox

    .PARAMETER AllowedPattern
        Wildcard patterns that limit which templates may match.
    #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Location,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Template,

		[string] $EnvironmentSku = 'Sandbox',

		[string[]] $AllowedPattern
	)

	$colTemplates = @($script:ProvisioningCache.templates[$Location])
	if ($AllowedPattern) {
		$colTemplates = @(
			$colTemplates |
			Where-Object {
				$templateName = $_.name
				$colAllowed = @(
					$AllowedPattern |
					Where-Object { $templateName -like $_ }
				)
				$colAllowed.Count -gt 0
			}
		)
	}
	$colMatch = @(
		$colTemplates |
		Where-Object { $_.name -eq $Template }
	)
	if (-not $colMatch) {
		$colMatch = @(
			$colTemplates |
			Where-Object { $_.name -like $Template }
		)
	}

	if ($colMatch.Count -ne 1) {
		$colValid = @(
			$colTemplates |
			ForEach-Object { $_.name } |
			Sort-Object -Unique
		)
		throw "Unknown template '$Template' for location '$Location'. Supported values: $($colValid -join ', ')."
	}

	$colSlot = @(
		$colMatch[0].availability |
		Where-Object { $_.environmentSku -eq $EnvironmentSku }
	)
	if (-not $colSlot) {
		throw "Template '$Template' has no $EnvironmentSku slot in location '$Location'."
	}
	if ($colSlot[0].isDisabled) {
		$reason = $colSlot[0].disabledReason.code
		Write-PSFMessage -Level Warning `
			-Message "Template '$Template' is currently reported as disabled for $EnvironmentSku in location '$Location' (reason: $reason). Provisioning will be attempted anyway."
	}
	$colMatch[0].name
}

function Get-ProvisioningLocationDefault {
	<#
    .SYNOPSIS
        Shared worker for tenant default language and currency.

    .DESCRIPTION
        Resolves live through the bundled Power Platform SDK. Tenant defaults are
        tenant specific, so they are never read from the provisioning cache.
    #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Location,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Token
	)

	$base = 'https://api.powerplatform.com'
	$api = $script:BapSdkApiVersion

	$languagesUrl = '{0}/environmentmanagement/provisioning/locations/{1}/languages?api-version={2}' `
		-f $base,
	$Location,
	$api

	$languageResult = Invoke-BapSdkRequest `
		-Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Languages.LanguagesRequestBuilder' } `
		-Method 'GetAsync' `
		-Token $Token `
		-RequestUrl $languagesUrl

	$colLanguage = @(
		$languageResult.collection |
		Where-Object { $_.isTenantDefault } |
		Select-Object -First 1
	)

	$currenciesUrl = '{0}/environmentmanagement/provisioning/locations/{1}/currencies?api-version={2}' `
		-f $base,
	$Location,
	$api

	$currencyResult = Invoke-BapSdkRequest `
		-Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Currencies.CurrenciesRequestBuilder' } `
		-Method 'GetAsync' `
		-Token $Token `
		-RequestUrl $currenciesUrl

	$colCurrency = @(
		$currencyResult.collection |
		Where-Object { $_.isTenantDefault } |
		Select-Object -First 1
	)

	if ((-not $colLanguage) `
			-or (-not $colCurrency)) {
		Write-PSFMessage -Level Verbose `
			-Message "No tenant default language or currency reported for location '$Location'."

		$null
		return
	}

	[pscustomobject][ordered]@{
		Location       = $Location
		BaseLanguage   = [int]$colLanguage[0].localeId
		LanguageName   = $colLanguage[0].localizedName
		CurrencyCode   = $colCurrency[0].code
		CurrencySymbol = $colCurrency[0].symbol
	}
}

function Get-ProvisioningTenantDefault {
	<#
    .SYNOPSIS
        Internal tenant default for New-UnifiedEnvironmentV2.

    .DESCRIPTION
        Always resolves live through the bundled Power Platform SDK. The tenant default
        is tenant specific and is never served from the provisioning cache.

    .PARAMETER Location
        Region name, wildcard or display name.

        Default: europe

    .PARAMETER Token
        Power Platform access token. A new one is minted when empty.
    #>
	[CmdletBinding()]
	param (
		[string] $Location = 'europe',

		[string] $Token
	)

	if (-not $Token) {
		$objSecure = Get-BapAccessToken -PowerPlatform
		$Token = [Net.NetworkCredential]::new('', $objSecure).Password
	}

	$locationName = Resolve-ProvisioningLocation -Location $Location
	$tenantDefault = Get-ProvisioningLocationDefault -Location $locationName `
		-Token $Token

	if (-not $tenantDefault) {
		throw "No tenant default language or currency reported for location '$locationName'."
	}

	[pscustomobject][ordered]@{
		BaseLanguage   = $tenantDefault.BaseLanguage
		LanguageName   = $tenantDefault.LanguageName
		CurrencyCode   = $tenantDefault.CurrencyCode
		CurrencySymbol = $tenantDefault.CurrencySymbol
	}
}

Import-ProvisioningCache
Start-ProvisioningCacheRefresh
Start-ProvisioningCatalogPreload
