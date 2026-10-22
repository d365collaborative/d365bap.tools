<#
    Internal runtime for Power Platform provisioning discovery data.

    Location, template, language and currency catalogs change rarely and
    carry no tenant specific values, so a trimmed snapshot ships with the
    module (internal/sdk/provisioning-cache.json for locations and
    templates, internal/sdk/provisioning-catalog.json for languages and
    currencies) and is loaded into memory on import. A throttled
    background job refreshes the snapshot on disk for the next import, so
    tab completion and validation keep working without network access
    while staying current.

    Tenant defaults are different per tenant and account, so no default
    flag is ever stored in the cache. The background job resolves them
    live and writes them to a per-tenant store on disk
    (provisioning-tenant-defaults.json), keyed by tenant and account, for
    later use. The public Get-PpacTenantProvisioningDefault cmdlet stays
    live only: it looks up the default locations live per call and then
    resolves language and currency live through the bundled Power
    Platform SDK:

      GET /environmentmanagement/provisioning/locations
      GET /environmentmanagement/provisioning/locations/{location}/languages
      GET /environmentmanagement/provisioning/locations/{location}/currencies
#>

$script:ProvisioningCache = $null
$script:ProvisioningCatalogLoaded = $false

# Templates New-UnifiedEnvironmentV2 supports. The discovery cache keeps
# every template the API returns; this list filters what the V2 cmdlet
# validates and completes.
$script:ProvisioningV2TemplateFilter = @('D365_FinOps*', 'D365_DeveloperEdition')

function Get-ProvisioningUserCachePath {
    [CmdletBinding()]
    param ()

    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    Join-Path (Join-Path $base 'd365bap.tools') 'provisioning-cache.json'
}

function Get-ProvisioningTenantDefaultsPath {
    [CmdletBinding()]
    param ()

    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    Join-Path (Join-Path $base 'd365bap.tools') 'provisioning-tenant-defaults.json'
}

function Import-ProvisioningCache {
    [CmdletBinding()]
    param ()

    $script:ProvisioningCache = @{ locations = @(); templates = @{} }
    $script:ProvisioningCatalogLoaded = $false

    $shipped = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-cache.json'
    if (Test-Path -LiteralPath $shipped) {
        $script:ProvisioningCache = Get-Content -LiteralPath $shipped -Raw -Encoding utf8 |
            ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }

    $userPath = Get-ProvisioningUserCachePath
    if (Test-Path -LiteralPath $userPath) {
        try {
            $overlay = Get-Content -LiteralPath $userPath -Raw -Encoding utf8 |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop
            foreach ($key in @('locations', 'templates', 'refreshedUtc')) {
                if ($overlay.ContainsKey($key)) { $script:ProvisioningCache[$key] = $overlay[$key] }
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Ignoring unreadable provisioning cache at $userPath : $($_.Exception.Message)"
        }
    }

    Publish-ProvisioningCompletionData
}

function Import-ProvisioningCatalog {
    <#
        Loads the tenant neutral language and currency catalogs into
        memory. Runs on demand only, so module import stays fast.
    #>
    [CmdletBinding()]
    param ()

    if ($script:ProvisioningCatalogLoaded) { return }

    $catalog = @{ languages = @{}; currencies = @{} }

    $shipped = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json'
    if (Test-Path -LiteralPath $shipped) {
        try {
            $shippedCatalog = Get-Content -LiteralPath $shipped -Raw -Encoding utf8 |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop
            foreach ($key in @('languages', 'currencies')) {
                if ($shippedCatalog.ContainsKey($key)) { $catalog[$key] = $shippedCatalog[$key] }
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Ignoring unreadable provisioning catalog at $shipped : $($_.Exception.Message)"
        }
    }

    $userPath = Get-ProvisioningUserCachePath
    if (Test-Path -LiteralPath $userPath) {
        try {
            $overlay = Get-Content -LiteralPath $userPath -Raw -Encoding utf8 |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop
            foreach ($key in @('languages', 'currencies')) {
                if ($overlay.ContainsKey($key)) { $catalog[$key] = $overlay[$key] }
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Ignoring unreadable provisioning catalog at $userPath : $($_.Exception.Message)"
        }
    }

    $script:ProvisioningCache['languages'] = $catalog['languages']
    $script:ProvisioningCache['currencies'] = $catalog['currencies']
    $script:ProvisioningCatalogLoaded = $true
    Publish-ProvisioningCatalogData
}

function Get-ProvisioningCatalog {
    <#
        Returns the in-memory language and currency catalogs, loading them
        on first use. Powers future tab completion for non-default
        deployments.
    #>
    [CmdletBinding()]
    param ()

    Import-ProvisioningCatalog

    [pscustomobject]@{
        Languages  = $script:ProvisioningCache['languages']
        Currencies = $script:ProvisioningCache['currencies']
    }
}

function Get-ProvisioningTenantDefaultCache {
    <#
        Reads the stored tenant default language and currency for the
        current tenant and account. Returns $null when nothing was stored
        yet. Written by the background refresh; consumed live callers
        stay authoritative.
    #>
    [CmdletBinding()]
    param ()

    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $azContext -or [string]::IsNullOrWhiteSpace($azContext.Tenant.Id)) { return $null }

    $storePath = Get-ProvisioningTenantDefaultsPath
    if (-not (Test-Path -LiteralPath $storePath)) { return $null }

    try {
        $store = Get-Content -LiteralPath $storePath -Raw -Encoding utf8 |
            ConvertFrom-Json -AsHashtable -ErrorAction Stop
        $key = "$($azContext.Tenant.Id)/$($azContext.Account.Id)"
        if ($store.ContainsKey($key)) { return $store[$key] }
    }
    catch {
        Write-PSFMessage -Level Verbose -Message "Ignoring unreadable tenant defaults at $storePath : $($_.Exception.Message)"
    }

    return $null
}

function Publish-ProvisioningCatalogData {
    <#
        Publishes the in-memory language and currency catalogs for tab
        completion. Called after the catalog is loaded, whenever that
        happens.
    #>
    [CmdletBinding()]
    param ()

    Set-PSFConfig -FullName 'd365bap.tools.provisioning.languages' -Value $script:ProvisioningCache['languages'] -Description 'Power Platform provisioning languages per location for tab completion.'
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.currencies' -Value $script:ProvisioningCache['currencies'] -Description 'Power Platform provisioning currencies per location for tab completion.'
}

function Start-ProvisioningCatalogPreload {
    <#
        Parses the language and currency catalogs in a background worker
        so module import stays fast. A StateChanged action merges the
        result into module scope when the job completes. Anything that
        needs the catalog calls Import-ProvisioningCatalog, which covers
        the gap if the worker has not finished yet.
    #>
    [CmdletBinding()]
    param ()

    $sourceId = 'd365bap.tools.provisioning.catalog.preload'
    $jobName = 'd365bap.tools.provisioning.catalog.preload'

    if ($script:ProvisioningCatalogLoaded) { return }

    $runningJob = Get-Job -Name $jobName -ErrorAction SilentlyContinue | Where-Object State -eq 'Running' | Select-Object -First 1
    if (Get-EventSubscriber -SourceIdentifier $sourceId -ErrorAction SilentlyContinue) {
        if ($runningJob) { return }
        Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue
    }

    # The module is still importing when this runs, so it is not in
    # Get-Module yet. The session state reference is always available.
    $module = $ExecutionContext.SessionState.Module
    if (-not $module) { return }

    if (-not $runningJob) {
        $shippedCatalogPath = Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json'
        $userPath = Get-ProvisioningUserCachePath
        $runningJob = Start-Job -Name $jobName -ScriptBlock {
            param ([string] $ShippedPath, [string] $UserPath)

            $catalog = @{ languages = @{}; currencies = @{} }
            foreach ($path in @($ShippedPath, $UserPath)) {
                if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }
                try {
                    $data = Get-Content -LiteralPath $path -Raw -Encoding utf8 |
                        ConvertFrom-Json -AsHashtable -ErrorAction Stop
                    foreach ($key in @('languages', 'currencies')) {
                        if ($data.ContainsKey($key)) {
                            foreach ($locationKey in @($data[$key].Keys)) {
                                $catalog[$key][$locationKey] = @($data[$key][$locationKey])
                            }
                        }
                    }
                }
                catch { }
            }
            $catalog
        } -ArgumentList $shippedCatalogPath, $userPath
    }

    $null = Register-ObjectEvent -InputObject $runningJob -EventName StateChanged -SourceIdentifier $sourceId -MessageData $module -Action {
        try {
            if ($Event.Sender.State -eq 'Completed') {
                $catalog = Receive-Job -Job $Event.Sender -ErrorAction Stop
                & $Event.MessageData {
                    param ($loaded)
                    if ($null -eq $loaded) { return }
                    foreach ($key in @('languages', 'currencies')) {
                        if ($loaded.ContainsKey($key)) { $script:ProvisioningCache[$key] = $loaded[$key] }
                    }
                    $script:ProvisioningCatalogLoaded = $true
                    Publish-ProvisioningCatalogData
                } $catalog
            }
        }
        catch { }
        finally {
                    # NOTE: remove by name. Removing by job object or id from
                    # inside an event action reports success but leaves the
                    # job behind.
                    Unregister-Event -SourceIdentifier 'd365bap.tools.provisioning.catalog.preload' -ErrorAction SilentlyContinue
                    Remove-Job -Name 'd365bap.tools.provisioning.catalog.preload' -Force -ErrorAction SilentlyContinue
                }
    }
}
function Publish-ProvisioningCompletionData {
    [CmdletBinding()]
    param ()

    $locations = @($script:ProvisioningCache.locations)
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.locations' -Value $locations -Description 'Power Platform provisioning locations for tab completion.'
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.v2TemplateFilter' -Value $script:ProvisioningV2TemplateFilter -Description 'Template allow-list for New-UnifiedEnvironmentV2 tab completion.'
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.catalogPath' -Value (Join-Path $script:ModuleRoot 'internal/sdk/provisioning-catalog.json') -Description 'Shipped language and currency catalog for tab completion.'
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.userCachePath' -Value (Get-ProvisioningUserCachePath) -Description 'User language and currency cache for tab completion.'
    $templateIndex = @{}
    foreach ($locationName in @($script:ProvisioningCache.templates.Keys)) {
        $templateIndex[$locationName] = @(
            $script:ProvisioningCache.templates[$locationName] | ForEach-Object {
                @{
                    name        = $_.name
                    displayName = $_.displayName
                    skus        = @($_.availability | Where-Object { -not $_.isDisabled } | ForEach-Object { $_.environmentSku })
                }
            }
        )
    }
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.templates' -Value $templateIndex -Description 'Provisioning templates per location for tab completion.'
}

function Start-ProvisioningCacheRefresh {
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

        if (Get-Job -Name 'd365bap.tools.provisioning.refresh' -ErrorAction SilentlyContinue | Where-Object State -eq 'Running') { return }
        Get-Job -Name 'd365bap.tools.provisioning.refresh' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

        $sdkRoot = Join-Path $script:ModuleRoot 'bin/PowerPlatformSdk'
        $tenantDefaultsPath = Get-ProvisioningTenantDefaultsPath

        $null = Start-Job -Name 'd365bap.tools.provisioning.refresh' -ScriptBlock {
            param ([string] $CachePath, [string] $SdkRoot, [string] $ApiVersion, [string] $TenantDefaultsPath)

            try {
                Import-Module Az.Accounts -ErrorAction Stop
                $azContext = Get-AzContext -ErrorAction SilentlyContinue
                if (-not $azContext -or [string]::IsNullOrWhiteSpace($azContext.Tenant.Id)) { return }

                foreach ($dll in @('Microsoft.Kiota.Abstractions.dll', 'Microsoft.Kiota.Serialization.Json.dll', 'Microsoft.Kiota.Http.HttpClientLibrary.dll', 'Microsoft.PowerPlatform.Management.dll', 'D365Bap.Tools.PowerPlatformSdk.dll')) {
                    $dllPath = Join-Path $SdkRoot $dll
                    if (-not (Test-Path -LiteralPath $dllPath)) { return }
                    [void][System.Reflection.Assembly]::LoadFrom($dllPath)
                }
                $clientType = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like 'D365Bap.Tools.PowerPlatformSdk,*' } | Select-Object -First 1).GetType('D365Bap.Tools.PowerPlatformSdk.SdkClient')
                if (-not $clientType) { return }
                $execute = $clientType.GetMethod('Execute')

                $secure = (Get-AzAccessToken -ResourceUrl 'https://api.powerplatform.com' -AsSecureString -ErrorAction Stop).Token
                $token = [Net.NetworkCredential]::new('', $secure).Password
                $base = 'https://api.powerplatform.com'

                $invokeSdk = {
                    param ([string] $Builder, [string] $RequestUrl)
                    $json = $execute.Invoke($null, @($Builder, 'GetAsync', $null, $ApiVersion, $null, $token, $RequestUrl))
                    if ($json) { $json | ConvertFrom-Json }
                }

                $locations = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.LocationsRequestBuilder' "$base/environmentmanagement/provisioning/locations?api-version=$ApiVersion").collection
                $snapshot = [ordered]@{
                    refreshedUtc = [datetime]::UtcNow.ToString('o')
                    apiVersion   = $ApiVersion
                    locations    = @($locations | ForEach-Object {
                            [ordered]@{
                                name                                          = $_.name
                                displayName                                   = $_.displayName
                                code                                          = $_.code
                                isDisabled                                    = $_.isDisabled
                                canProvisionDatabase                          = $_.canProvisionDatabase
                                hasFirstReleaseIslandAvailableForProvisioning = $_.hasFirstReleaseIslandAvailableForProvisioning
                            }
                        })
                    templates    = [ordered]@{}
                    languages    = [ordered]@{}
                    currencies   = [ordered]@{}
                }

                $defaultLocations = @($locations | Where-Object { $_.isDefault } | ForEach-Object { $_.name })
                $tenantDefaults = [ordered]@{}

                foreach ($location in @($locations.name)) {
                    try {
                        $templates = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Templates.TemplatesRequestBuilder' "$base/environmentmanagement/provisioning/locations/$location/templates?api-version=$ApiVersion").collection
                        $snapshot.templates[$location] = @($templates | ForEach-Object {
                                [ordered]@{
                                    name                           = $_.name
                                    displayName                    = $_.displayName
                                    isCustomerEngagement           = $_.isCustomerEngagement
                                    isSupportedForResetOperation   = $_.isSupportedForResetOperation
                                    availability                   = @($_.availability | ForEach-Object {
                                            $slot = [ordered]@{ environmentSku = $_.environmentSku; isDisabled = $_.isDisabled }
                                            if ($_.disabledReason) { $slot.disabledReason = [ordered]@{ code = $_.disabledReason.code } }
                                            $slot
                                        })
                                }
                            })

                        $languages = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Languages.LanguagesRequestBuilder' "$base/environmentmanagement/provisioning/locations/$location/languages?api-version=$ApiVersion").collection
                        $snapshot.languages[$location] = @($languages | ForEach-Object {
                                [ordered]@{ localeId = $_.localeId; localizedName = $_.localizedName }
                            })

                        $currencies = (& $invokeSdk 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Currencies.CurrenciesRequestBuilder' "$base/environmentmanagement/provisioning/locations/$location/currencies?api-version=$ApiVersion").collection
                        $snapshot.currencies[$location] = @($currencies | ForEach-Object {
                                [ordered]@{ code = $_.code; symbol = $_.symbol }
                            })

                        if ($location -in $defaultLocations) {
                            $language = @($languages | Where-Object { $_.isTenantDefault } | Select-Object -First 1)
                            $currency = @($currencies | Where-Object { $_.isTenantDefault } | Select-Object -First 1)
                            if ($language -and $currency) {
                                $tenantDefaults[$location] = [ordered]@{
                                    locationDisplayName = ($locations | Where-Object { $_.name -eq $location } | Select-Object -First 1).displayName
                                    language            = [ordered]@{ localeId = $language[0].localeId; localizedName = $language[0].localizedName }
                                    currency            = [ordered]@{ code = $currency[0].code; symbol = $currency[0].symbol }
                                }
                            }
                        }
                    }
                    catch { Write-PSFMessage -Level Verbose -Message "Provisioning refresh: skipping location '$location'." }
                }

                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $CachePath) -Force -ErrorAction Stop
                $snapshot | ConvertTo-Json -Depth 8 -ErrorAction Stop | Set-Content -LiteralPath $CachePath -Encoding utf8 -ErrorAction Stop

                $store = @{}
                if (Test-Path -LiteralPath $TenantDefaultsPath) {
                    try {
                        $store = Get-Content -LiteralPath $TenantDefaultsPath -Raw -Encoding utf8 |
                            ConvertFrom-Json -AsHashtable -ErrorAction Stop
                    }
                    catch { Write-PSFMessage -Level Verbose -Message "Provisioning refresh: starting a new tenant defaults store." }
                }
                $store["$($azContext.Tenant.Id)/$($azContext.Account.Id)"] = [ordered]@{
                    tenantId         = $azContext.Tenant.Id
                    account          = $azContext.Account.Id
                    savedUtc         = [datetime]::UtcNow.ToString('o')
                    apiVersion       = $ApiVersion
                    defaultLocations = @($defaultLocations)
                    defaults         = $tenantDefaults
                }
                $store | ConvertTo-Json -Depth 8 -ErrorAction Stop | Set-Content -LiteralPath $TenantDefaultsPath -Encoding utf8 -ErrorAction Stop
            }
            catch { Write-PSFMessage -Level Verbose -Message 'Provisioning refresh: background probe failed, keeping the previous cache.' }
        } -ArgumentList $userPath, $sdkRoot, $script:BapSdkApiVersion, $tenantDefaultsPath
    }
    catch { Write-PSFMessage -Level Verbose -Message "Provisioning refresh was skipped: $($_.Exception.Message)" }
}

function Resolve-ProvisioningLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location
    )

    $locations = @($script:ProvisioningCache.locations)
    $match = @($locations | Where-Object { $_.name -eq $Location })
    if (-not $match) { $match = @($locations | Where-Object { $_.name -like $Location }) }
    if ($match.Count -eq 1) { return $match[0].name }
    if (-not $match) { $match = @($locations | Where-Object { $_.displayName -like $Location }) }
    if ($match.Count -eq 1) { return $match[0].name }

    $valid = @($locations | ForEach-Object { $_.name } | Sort-Object -Unique)
    throw "Unknown location '$Location'. Valid values: $($valid -join ', ')."
}

function Resolve-ProvisioningTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [string] $Template,

        [string] $EnvironmentSku = 'Sandbox',

        [string[]] $AllowedPattern
    )

    $templates = @($script:ProvisioningCache.templates[$Location])
    if ($AllowedPattern) {
        $templates = @($templates | Where-Object {
                $templateName = $_.name
                @($AllowedPattern | Where-Object { $templateName -like $_ }).Count -gt 0
            })
    }
    $match = @($templates | Where-Object { $_.name -eq $Template })
    if (-not $match) { $match = @($templates | Where-Object { $_.name -like $Template }) }

    if ($match.Count -ne 1) {
        $valid = @($templates | ForEach-Object { $_.name } | Sort-Object -Unique)
        throw "Unknown template '$Template' for location '$Location'. Supported values: $($valid -join ', ')."
    }

    $slot = @($match[0].availability | Where-Object { $_.environmentSku -eq $EnvironmentSku })
    if (-not $slot) {
        throw "Template '$Template' has no $EnvironmentSku slot in location '$Location'."
    }
    if ($slot[0].isDisabled) {
        # Advisory only: availability flags have been observed to disagree
        # across calls, so a disabled flag warns instead of blocking.
        $reason = $slot[0].disabledReason.code
        Write-PSFMessage -Level Warning -Message "Template '$Template' is currently reported as disabled for $EnvironmentSku in location '$Location' (reason: $reason). Provisioning will be attempted anyway."
    }
    return $match[0].name
}

function Get-ProvisioningLocationDefault {
    <#
        Shared worker for tenant default language and currency.

        Resolves live through the bundled Power Platform SDK. Tenant
        defaults are tenant specific, so they are never read from the
        provisioning cache.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [Parameter(Mandatory = $true)]
        [string] $Token
    )

    $base = 'https://api.powerplatform.com'
    $api = $script:BapSdkApiVersion

    $languageResult = Invoke-BapSdkRequest `
        -Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Languages.LanguagesRequestBuilder' } `
        -Method 'GetAsync' `
        -Token $Token `
        -RequestUrl "$base/environmentmanagement/provisioning/locations/$Location/languages?api-version=$api"

    $language = @($languageResult.collection | Where-Object { $_.isTenantDefault } | Select-Object -First 1)

    $currencyResult = Invoke-BapSdkRequest `
        -Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Locations.Item.Currencies.CurrenciesRequestBuilder' } `
        -Method 'GetAsync' `
        -Token $Token `
        -RequestUrl "$base/environmentmanagement/provisioning/locations/$Location/currencies?api-version=$api"

    $currency = @($currencyResult.collection | Where-Object { $_.isTenantDefault } | Select-Object -First 1)

    if (-not $language -or -not $currency) {
        Write-PSFMessage -Level Verbose -Message "No tenant default language or currency reported for location '$Location'."
        return $null
    }

    [pscustomobject]@{
        Location       = $Location
        BaseLanguage   = [int]$language[0].localeId
        LanguageName   = $language[0].localizedName
        CurrencyCode   = $currency[0].code
        CurrencySymbol = $currency[0].symbol
    }
}

function Get-ProvisioningTenantDefault {
    <#
        Internal tenant default for New-UnifiedEnvironmentV2.

        Always resolves live through the bundled Power Platform SDK. The
        tenant default is tenant specific and is never served from the
        provisioning cache.
    #>
    [CmdletBinding()]
    param (
        [string] $Location = 'europe',

        [string] $Token
    )

    if (-not $Token) {
        $secure = (Get-AzAccessToken -ResourceUrl 'https://api.powerplatform.com' -AsSecureString -ErrorAction Stop).Token
        $Token = [Net.NetworkCredential]::new('', $secure).Password
    }

    $locationName = Resolve-ProvisioningLocation -Location $Location
    $tenantDefault = Get-ProvisioningLocationDefault -Location $locationName -Token $Token

    if (-not $tenantDefault) {
        throw "No tenant default language or currency reported for location '$locationName'."
    }

    [pscustomobject]@{
        BaseLanguage   = $tenantDefault.BaseLanguage
        LanguageName   = $tenantDefault.LanguageName
        CurrencyCode   = $tenantDefault.CurrencyCode
        CurrencySymbol = $tenantDefault.CurrencySymbol
    }
}

Import-ProvisioningCache
Start-ProvisioningCacheRefresh
Start-ProvisioningCatalogPreload
