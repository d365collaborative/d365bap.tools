<#
    Internal runtime for Power Platform provisioning discovery data.

    New-UnifiedEnvironmentV2 validates -Location and -Template against the
    Power Platform provisioning discovery endpoints instead of sending raw
    user input to the API:

      GET /environmentmanagement/provisioning/locations
      GET /environmentmanagement/provisioning/locations/{location}/templates
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

    $script:ProvisioningCache = @{ locations = @(); templates = @{}; languages = @{}; currencies = @{} }

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
            foreach ($key in @('locations', 'templates', 'languages', 'currencies', 'refreshedUtc')) {
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

        # Provider choice cannot be read inside the job: PSFConfig and
        # $script: module state are not shared with the job process, so
        # pass it explicitly and let the job mint a fresh token.
        $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

        $null = Start-Job -Name 'd365bap.tools.provisioning.refresh' -ScriptBlock {
            param ([string] $CachePath, [string] $AuthProvider, [string] $ModuleRoot)

            try {
                if ($AuthProvider -eq 'AzAccount') {
                    Import-Module Az.Accounts -ErrorAction Stop
                    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }
                }

                if (-not (Get-Command Get-BapAccessToken -ErrorAction SilentlyContinue)) {
                    $helperPath = Join-Path $ModuleRoot 'internal/functions/Get-BapAccessToken.ps1'
                    if (Test-Path -LiteralPath $helperPath) { . $helperPath }
                    else { return }
                }

                $secure = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com' -ErrorAction Stop
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
                    languages    = [ordered]@{}
                    currencies   = [ordered]@{}
                }

                $languageLocations = @('europe', 'unitedstates', 'unitedkingdom', 'germany')
                if (Test-Path -LiteralPath $CachePath) {
                    try {
                        $previous = Get-Content -LiteralPath $CachePath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                        foreach ($key in @($previous.languages.Keys)) {
                            if ($key -notin $languageLocations) { $languageLocations += $key }
                        }
                    }
                    catch { Write-PSFMessage -Level Verbose -Message "Provisioning refresh: keeping previous language list, could not read '$CachePath'." }
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

                foreach ($location in $languageLocations) {
                    try {
                        $snapshot.languages[$location] = @((Invoke-RestMethod -Uri "$base/environmentmanagement/provisioning/locations/$location/languages?api-version=$api" -Headers $headers -ErrorAction Stop).collection |
                            ForEach-Object { [ordered]@{ localeId = $_.localeId; localizedName = $_.localizedName; isTenantDefault = $_.isTenantDefault } })
                        $snapshot.currencies[$location] = @((Invoke-RestMethod -Uri "$base/environmentmanagement/provisioning/locations/$location/currencies?api-version=$api" -Headers $headers -ErrorAction Stop).collection |
                            ForEach-Object { [ordered]@{ code = $_.code; symbol = $_.symbol; isTenantDefault = $_.isTenantDefault } })
                    }
                    catch { Write-PSFMessage -Level Verbose -Message "Provisioning refresh: skipping languages/currencies for location '$location'." }
                }

                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $CachePath) -Force -ErrorAction Stop
                $snapshot | ConvertTo-Json -Depth 8 -ErrorAction Stop | Set-Content -LiteralPath $CachePath -Encoding utf8 -ErrorAction Stop
            }
            catch { Write-PSFMessage -Level Verbose -Message 'Provisioning refresh: background probe failed, keeping the previous cache.' }
        } -ArgumentList @((Get-ProvisioningUserCachePath), $authProvider, $script:ModuleRoot)
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

function Get-ProvisioningTenantDefault {
    [CmdletBinding()]
    param (
        [string] $Location = 'europe'
    )

    $languages = @($script:ProvisioningCache.languages[$Location])
    if (-not $languages) {
        foreach ($key in @($script:ProvisioningCache.languages.Keys)) {
            $languages = @($script:ProvisioningCache.languages[$key])
            if ($languages) { break }
        }
    }
    $language = @($languages | Where-Object { $_.isTenantDefault } | Select-Object -First 1)
    $baseLanguage = if ($language) { [int]$language[0].localeId } else { 1033 }

    $currencies = @($script:ProvisioningCache.currencies[$Location])
    if (-not $currencies) {
        foreach ($key in @($script:ProvisioningCache.currencies.Keys)) {
            $currencies = @($script:ProvisioningCache.currencies[$key])
            if ($currencies) { break }
        }
    }
    $currency = @($currencies | Where-Object { $_.isTenantDefault } | Select-Object -First 1)

    [pscustomobject]@{
        BaseLanguage   = $baseLanguage
        CurrencyCode   = if ($currency) { $currency[0].code } else { 'USD' }
        CurrencySymbol = if ($currency) { $currency[0].symbol } else { '$' }
    }
}

Import-ProvisioningCache
Start-ProvisioningCacheRefresh
