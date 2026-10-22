<#
    Location-aware language and currency completion for New-UnifiedEnvironmentV2.

    Registered as native argument completers (rather than through the
    PSFramework TEPP host) because the completion needs $fakeBoundParameters
    to filter languages and currencies by the -Location value on the command
    line.

    The list shows the friendly text but accepts both text and id: typing
    either the display text or the locale id / currency code narrows the
    list, while tab always completes the id / code. The tenant default for
    the location comes first, followed by the full list in ascending
    order, so the default value appears twice.
#>

$provisioningCultureCompleter = {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $word = "$wordToComplete".Trim("'", '"')

    $langs = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.languages' -Fallback $null
    $currs = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.currencies' -Fallback $null
    if (-not $langs -or -not $currs) {
        # The background preload worker has not merged the catalog yet:
        # parse it synchronously once and publish it for this session.
        try {
            $catalogPath = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.catalogPath' -Fallback $null
            $userPath = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.userCachePath' -Fallback $null
            $merged = @{ languages = @{}; currencies = @{} }
            foreach ($path in @($catalogPath, $userPath)) {
                if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }
                $data = Get-Content -LiteralPath $path -Raw -Encoding utf8 |
                    ConvertFrom-Json -AsHashtable -ErrorAction Stop
                foreach ($key in @('languages', 'currencies')) {
                    if ($data.ContainsKey($key)) {
                        foreach ($locationKey in @($data[$key].Keys)) {
                            $merged[$key][$locationKey] = @($data[$key][$locationKey])
                        }
                    }
                }
            }
            Set-PSFConfig -FullName 'd365bap.tools.provisioning.languages' -Value $merged['languages'] -Description 'Power Platform provisioning languages per location for tab completion.'
            Set-PSFConfig -FullName 'd365bap.tools.provisioning.currencies' -Value $merged['currencies'] -Description 'Power Platform provisioning currencies per location for tab completion.'
            $langs = $merged['languages']
            $currs = $merged['currencies']
        }
        catch { return }
    }
    if (-not $langs -or -not $currs) { return }

    $storeEntry = $null
    try {
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ($azContext -and $azContext.Tenant.Id) {
            $storeBase = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
            $storePath = Join-Path (Join-Path $storeBase 'd365bap.tools') 'provisioning-tenant-defaults.json'
            if (Test-Path -LiteralPath $storePath) {
                $store = Get-Content -LiteralPath $storePath -Raw -Encoding utf8 |
                    ConvertFrom-Json -AsHashtable -ErrorAction Stop
                $storeEntry = $store["$($azContext.Tenant.Id)/$($azContext.Account.Id)"]
            }
        }
    }
    catch { }

    $locationKey = $null
    if ($fakeBoundParameters -and $fakeBoundParameters.ContainsKey('Location') -and $fakeBoundParameters['Location']) {
        $wanted = "$($fakeBoundParameters['Location'])".Trim("'", '"')
        $locationKey = @($langs.Keys | Where-Object { $_ -like $wanted }) | Select-Object -First 1
        if (-not $locationKey) {
            $locations = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.locations' -Fallback @()
            $locationKey = @($locations | Where-Object { $_.displayName -like $wanted } | ForEach-Object { $_.name }) | Select-Object -First 1
        }
    }
    if (-not $locationKey) {
        if ($storeEntry -and @($storeEntry.defaultLocations).Count) {
            $locationKey = @($storeEntry.defaultLocations)[0]
        }
        else {
            $locationKey = 'europe'
        }
    }

    if ($parameterName -eq 'Language') {
        $entries = @($langs[$locationKey] | Sort-Object -Property localeId)
        $defaultId = $null
        if ($storeEntry -and $storeEntry.defaults -and $storeEntry.defaults[$locationKey] -and $storeEntry.defaults[$locationKey].language) {
            $defaultId = $storeEntry.defaults[$locationKey].language.localeId
        }
        $ordered = @()
        if ($null -ne $defaultId) { $ordered += @($entries | Where-Object { $_.localeId -eq $defaultId }) }
        $ordered += $entries
        foreach ($entry in $ordered) {
            $text = "$($entry.localeId) $($entry.localizedName)"
            if ("$($entry.localeId)" -like "$word*" -or "$($entry.localizedName)" -like "$word*") {
                [Management.Automation.CompletionResult]::new("$($entry.localeId)", $text, 'ParameterValue', $text)
            }
        }
    }
    elseif ($parameterName -eq 'Currency') {
        $entries = @($currs[$locationKey] | Sort-Object -Property code)
        $defaultCode = $null
        if ($storeEntry -and $storeEntry.defaults -and $storeEntry.defaults[$locationKey] -and $storeEntry.defaults[$locationKey].currency) {
            $defaultCode = $storeEntry.defaults[$locationKey].currency.code
        }
        $ordered = @()
        if ($null -ne $defaultCode) { $ordered += @($entries | Where-Object { $_.code -eq $defaultCode }) }
        $ordered += $entries
        foreach ($entry in $ordered) {
            $text = "$($entry.code) ($($entry.symbol))"
            if ("$($entry.code)" -like "$word*" -or "$($entry.symbol)" -like "$word*") {
                [Management.Automation.CompletionResult]::new("'$($entry.code)'", $text, 'ParameterValue', $text)
            }
        }
    }
}

Register-ArgumentCompleter -CommandName New-UnifiedEnvironmentV2 -ParameterName Language -ScriptBlock $provisioningCultureCompleter
Register-ArgumentCompleter -CommandName New-UnifiedEnvironmentV2 -ParameterName Currency -ScriptBlock $provisioningCultureCompleter
