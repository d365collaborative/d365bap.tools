
<#
    .SYNOPSIS
        Centralized Azure access token minter for d365bap.tools.

    .DESCRIPTION
        Mints an Azure access token for the requested resource via the configured auth
        provider and returns the .Token equivalent (a SecureString), so existing call
        sites can keep their ConvertFrom-SecureString -AsPlainText pattern.

        A failed mint stops execution entirely with a terminating error: running
        any code without a token makes no sense, so there is no soft-fail path.

        Tokens are cached per resource + tenant + account in $script:BapTokenCache and
        reused while more than 15 minutes of lifetime remain. The current Azure context
        is re-read on every call: a manual context switch outside Switch-BapTenant
        changes the cache key / stored stamp, so the next call treats the entry as a
        miss and mints a fresh token.
#>

if ($null -eq $script:BapTokenCache) {
    $script:BapTokenCache = @{}
}

<#
    .SYNOPSIS
        Mints (or returns a cached) Azure access token as a SecureString.

    .DESCRIPTION
        Returns the .Token equivalent (a SecureString) for the requested resource. Uses
        Get-AzAccessToken when the auth provider is 'AzAccount' and the Azure CLI
        ('az account get-access-token') when the provider is 'AzCli'.

    .PARAMETER ResourceUrl
        The resource (audience) to mint the token for, e.g. "https://graph.microsoft.com/".

    .PARAMETER TenantId
        Optional tenant to mint the token for. Passed through to the active auth provider.

    .EXAMPLE
        PS C:\> $secureToken = Get-BapAccessToken -ResourceUrl 'https://graph.microsoft.com/'
        PS C:\> $tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        Mints (or reuses a cached) token for Microsoft Graph and converts it to plain text
        at the call site.

    .NOTES
        Author: Motz Jensen (@Splaxi)
#>
function Get-BapAccessToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification = "The Azure CLI returns the access token as plain text; it is converted to a SecureString immediately and never stored.")]
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ResourceUrl,

        [string] $TenantId
    )

    if ($null -eq $script:BapTokenCache) {
        $script:BapTokenCache = @{}
    }

    $provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'
    if ([string]::IsNullOrWhiteSpace("$provider")) {
        $provider = 'AzAccount'
    }

    #region Resolve current context stamp (account + tenant)
    $currentAccountId = ''
    $currentTenantId = ''

    if ("$provider" -eq 'AzAccount') {
        try {
            $azContext = Get-AzContext -ErrorAction Stop
            if ($null -ne $azContext) {
                $currentAccountId = "$($azContext.Account.Id)"
                $currentTenantId = "$($azContext.Tenant.Id)"
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Unable to read the current Az context. Continuing without a context stamp."
        }
    }
    elseif ("$provider" -eq 'AzCli') {
        try {
            $accountJson = az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$accountJson")) {
                $accountObj = "$accountJson" | ConvertFrom-Json -ErrorAction Stop
                $currentAccountId = "$($accountObj.user)"
                $currentTenantId = "$($accountObj.tenant)"
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Unable to read the current Azure CLI account. Continuing without a context stamp."
        }
    }
    else {
        $messageString = "Unknown auth provider '<c='em'>$provider</c>'. Expected 'AzAccount' or 'AzCli' in configuration 'd365bap.tools.auth.provider'."
        Write-PSFMessage -Level Critical -Message $messageString
        throw $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
    }
    #endregion Resolve current context stamp

    if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
        $effectiveTenantId = $TenantId
    }
    else {
        $effectiveTenantId = $currentTenantId
    }

    $cacheKey = "$($ResourceUrl.ToLowerInvariant())|$("$effectiveTenantId".ToLowerInvariant())|$("$currentAccountId".ToLowerInvariant())"

    #region Serve from cache
    $cached = $script:BapTokenCache[$cacheKey]
    if ($null -ne $cached -and $null -ne $cached.Token -and $null -ne $cached.ExpiresOn) {
        if ("$($cached.AccountId)" -eq "$currentAccountId" -and "$($cached.TenantId)" -eq "$effectiveTenantId") {
            $remainingMinutes = -1
            try {
                $remainingMinutes = (([datetime]$cached.ExpiresOn).ToUniversalTime() - [datetime]::UtcNow).TotalMinutes
            }
            catch {
                $remainingMinutes = -1
            }

            if ($remainingMinutes -gt 15) {
                Write-PSFMessage -Level Verbose -Message "Returning cached access token for resource <c='em'>$ResourceUrl</c>."
                return $cached.Token
            }

            Write-PSFMessage -Level Verbose -Message "Cached access token for resource <c='em'>$ResourceUrl</c> expires soon. Minting a new token."
        }
        else {
            Write-PSFMessage -Level Verbose -Message "Azure context changed since the token was cached. Minting a new token for resource <c='em'>$ResourceUrl</c>."
        }
    }
    #endregion Serve from cache

    #region Mint new token
    $secureToken = $null
    $expiresOn = [datetime]::MinValue

    if ("$provider" -eq 'AzAccount') {
        try {
            $tokenParams = @{
                ResourceUrl    = $ResourceUrl
                AsSecureString = $true
                ErrorAction    = 'Stop'
            }
            if (-not [string]::IsNullOrWhiteSpace($TenantId) -and "$TenantId" -ne "$currentTenantId") {
                $tokenParams['TenantId'] = $TenantId
            }

            $azToken = Get-AzAccessToken @tokenParams
            if ($null -eq $azToken -or $null -eq $azToken.Token) {
                throw "Get-AzAccessToken returned an empty result for resource '$ResourceUrl'."
            }

            $secureToken = $azToken.Token
            $rawExpiry = $azToken.ExpiresOn
            if ($rawExpiry -is [datetimeoffset]) {
                $expiresOn = $rawExpiry.UtcDateTime
            }
            elseif ($rawExpiry -is [datetime]) {
                $expiresOn = $rawExpiry
            }
            else {
                $expiresOn = ([datetime]"$rawExpiry")
            }
        }
        catch {
            $messageString = "Failed to mint an access token for resource <c='em'>$ResourceUrl</c> via Get-AzAccessToken. Stopping execution, a missing token must never be ignored."
            Write-PSFMessage -Level Critical -Message $messageString -Exception $_.Exception
            throw
        }
    }
    else {
        try {
            $cliArgs = @('account', 'get-access-token', '--resource', $ResourceUrl)
            if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
                $cliArgs += @('--tenant', $TenantId)
            }
            # Request both expiry shapes: expires_on (POSIX epoch, UTC) and expiresOn (datetime string).
            $cliArgs += @('--query', '{accessToken:accessToken, expires_on:expires_on, expiresOn:expiresOn}', '-o', 'json')

            $rawJson = & az @cliArgs 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$rawJson")) {
                throw "The Azure CLI command 'az account get-access-token' failed with exit code $LASTEXITCODE."
            }

            $tokenJson = "$rawJson" | ConvertFrom-Json -ErrorAction Stop
            $accessTokenPlain = "$($tokenJson.accessToken)"
            if ([string]::IsNullOrWhiteSpace($accessTokenPlain)) {
                throw "The Azure CLI returned an empty access token for resource '$ResourceUrl'."
            }

            $expiresRaw = "$($tokenJson.expires_on)"
            if ([string]::IsNullOrWhiteSpace($expiresRaw)) {
                $expiresRaw = "$($tokenJson.expiresOn)"
            }

            $epoch = 0
            if ([long]::TryParse($expiresRaw, [ref]$epoch)) {
                $expiresOn = [DateTimeOffset]::FromUnixTimeSeconds($epoch).UtcDateTime
            }
            else {
                $parsedExpiry = [datetime]::MinValue
                if ([datetime]::TryParse($expiresRaw, [ref]$parsedExpiry)) {
                    $expiresOn = $parsedExpiry
                }
                else {
                    throw "The Azure CLI returned an unparsable token expiry '$expiresRaw'."
                }
            }

            $secureToken = ConvertTo-SecureString -String $accessTokenPlain -AsPlainText -Force
        }
        catch {
            $messageString = "Failed to mint an access token for resource <c='em'>$ResourceUrl</c> via the Azure CLI. Stopping execution, a missing token must never be ignored."
            Write-PSFMessage -Level Critical -Message $messageString -Exception $_.Exception
            throw
        }
    }
    #endregion Mint new token

    $script:BapTokenCache[$cacheKey] = @{
        Token     = $secureToken
        ExpiresOn = $expiresOn
        AccountId = "$currentAccountId"
        TenantId  = "$effectiveTenantId"
    }

    return $secureToken
}

<#
    .SYNOPSIS
        Clears the cached Azure access tokens.

    .DESCRIPTION
        Empties $script:BapTokenCache. Called by Set-BapToolsAuthProvider and
        Switch-BapTenant so a provider swap or tenant switch never serves a
        stale token.

    .EXAMPLE
        PS C:\> Clear-BapTokenCache

        Clears all cached access tokens.

    .NOTES
        Author: Motz Jensen (@Splaxi)
#>
function Clear-BapTokenCache {
    [CmdletBinding()]
    param ()

    if ($null -eq $script:BapTokenCache) {
        $script:BapTokenCache = @{}
    }
    else {
        $script:BapTokenCache.Clear()
    }

    Write-PSFMessage -Level Verbose -Message "Cleared the BAP access token cache."
}
