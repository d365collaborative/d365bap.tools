<#
    Internal runtime for Power Platform provisioning discovery data.

    New-UnifiedEnvironmentV2 validates -Location and -Template against the
    Power Platform provisioning discovery endpoints instead of sending raw
    user input to the API:

      GET /environmentmanagement/provisioning/locations
      GET /environmentmanagement/provisioning/locations/{location}/templates

    Tenant default language and currency are tenant specific, so they are
    never cached. They are resolved live through the bundled Power Platform
    SDK for the location being provisioned:

      GET /environmentmanagement/provisioning/locations/{location}/languages
      GET /environmentmanagement/provisioning/locations/{location}/currencies

    A trimmed snapshot ships with the module
    (internal/sdk/provisioning-cache.json) and is loaded into memory on
    import. A throttled background job refreshes the snapshot on disk for
    the next import, so tab completion and validation keep working without
    network access while staying current.
#>

$script:ProvisioningCache = $null

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

function Import-ProvisioningCache {
    [CmdletBinding()]
    param ()

    $script:ProvisioningCache = @{ locations = @(); templates = @{} }

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

function Publish-ProvisioningCompletionData {
    [CmdletBinding()]
    param ()

    $locations = @($script:ProvisioningCache.locations)
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.locations' -Value $locations -Description 'Power Platform provisioning locations for tab completion.'
    Set-PSFConfig -FullName 'd365bap.tools.provisioning.v2TemplateFilter' -Value $script:ProvisioningV2TemplateFilter -Description 'Template allow-list for New-UnifiedEnvironmentV2 tab completion.'
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

        if (Get-Job -Name 'd365bap.tools.provisioning.refresh' -State Running -ErrorAction SilentlyContinue) { return }
        Get-Job -Name 'd365bap.tools.provisioning.refresh' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

        $null = Start-Job -Name 'd365bap.tools.provisioning.refresh' -ScriptBlock {
            param ([string] $CachePath)

            try {
                Import-Module Az.Accounts -ErrorAction Stop
                if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }

                $secure = (Get-AzAccessToken -ResourceUrl 'https://api.powerplatform.com' -AsSecureString -ErrorAction Stop).Token
                $token = [Net.NetworkCredential]::new('', $secure).Password
                $headers = @{ Authorization = "Bearer $token" }
                $base = 'https://api.powerplatform.com'
                $api = '2024-10-01'

                $locations = (Invoke-RestMethod -Uri "$base/environmentmanagement/provisioning/locations?api-version=$api" -Headers $headers -ErrorAction Stop).collection
                $snapshot = [ordered]@{
                    refreshedUtc = [datetime]::UtcNow.ToString('o')
                    apiVersion   = $api
                    locations    = @($locations | ForEach-Object {
                            [ordered]@{
                                name                                          = $_.name
                                displayName                                   = $_.displayName
                                code                                          = $_.code
                                isDefault                                     = $_.isDefault
                                isDisabled                                    = $_.isDisabled
                                canProvisionDatabase                          = $_.canProvisionDatabase
                                hasFirstReleaseIslandAvailableForProvisioning = $_.hasFirstReleaseIslandAvailableForProvisioning
                            }
                        })
                    templates    = [ordered]@{}
                }

                foreach ($location in @($locations.name)) {
                    try {
                        $templates = (Invoke-RestMethod -Uri "$base/environmentmanagement/provisioning/locations/$location/templates?api-version=$api" -Headers $headers -ErrorAction Stop).collection
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
                    }
                    catch { $snapshot.templates[$location] = @() }
                }

                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $CachePath) -Force -ErrorAction Stop
                $snapshot | ConvertTo-Json -Depth 8 -ErrorAction Stop | Set-Content -LiteralPath $CachePath -Encoding utf8 -ErrorAction Stop
            }
            catch { Write-PSFMessage -Level Verbose -Message 'Provisioning refresh: background probe failed, keeping the previous cache.' }
        } -ArgumentList (Get-ProvisioningUserCachePath)
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
