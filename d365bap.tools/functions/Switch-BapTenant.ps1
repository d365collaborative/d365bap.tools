
<#
    .SYNOPSIS
        Switches the current context to a specified BAP tenant.
        
    .DESCRIPTION
        This function allows you to switch the current context to a specified BAP tenant based on the tenant details stored in the local PSFramework configuration.
        
        It uses the auth provider set with Set-BapToolsAuthProvider: Az PowerShell context (AzAccount) or Azure CLI (AzCli).
        
    .PARAMETER Id
        The ID of the BAP tenant to switch to.
        
    .PARAMETER Force
        Instruct the function to force an authentication prompt even if the current token is still valid. This can be useful if you want to ensure that you are using the most up-to-date credentials or if you want to switch to a different user within the same tenant.
        
    .EXAMPLE
        PS C:\> Switch-BapTenant -Id "Contoso"
        
        This will switch the current context to the BAP tenant with the id "Contoso".
        It will ensure that the authentication token is valid, prompting for re-authentication if necessary.
        
    .EXAMPLE
        PS C:\> Switch-BapTenant -Id "Contoso" -Force
        
        This will switch the current context to the BAP tenant with the id "Contoso".
        It will force an authentication prompt, even if the current token is still valid.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Switch-BapTenant {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [switch] $Force
    )

    begin {
        
    }
    
    process {
        $hashTenants = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.tenant.details")
        
        if ($null -eq $hashTenants."$Id") {
            $messageString = "No tenant details found for Id <c='em'>$Id</c>. Please add the tenant details using <c='em'>Set-BapTenantDetail</c> first."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because tenant was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        $obj = $hashTenants."$Id"
        $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

        $fake = ''

        if ($authProvider -eq 'AzCli') {
            $azMatch = $null
            try {
                $azRaw = az account list --query "[?tenantId=='$($obj.Tenant)' && user.name=='$($obj.User)']" -o json 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azRaw")) {
                    $azMatch = @("$azRaw" | ConvertFrom-Json -ErrorAction Stop) | Select-Object -First 1
                }
            }
            catch {
                Write-PSFMessage -Level Verbose -Message "az account list failed with: $($_.Exception.Message)"
            }

            if ($null -ne $azMatch) {
                if (-not [string]::IsNullOrWhiteSpace("$($azMatch.id)")) {
                    $null = az account set --subscription $azMatch.id 2>$null
                }

                try {
                    $azProbe = az account get-access-token --resource 'https://service.powerapps.com/' -o json 2>$null
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azProbe")) {
                        $fake = "$azProbe"
                    }
                }
                catch {
                    Write-PSFMessage -Level Verbose -Message "Azure CLI token probe failed with: $($_.Exception.Message)"
                }
            }
        }
        else {
            $contextObj = (Get-AzContext -ListAvailable | `
                    Where-Object { $_.tenant.id -eq $obj.Tenant } | `
                    Where-Object { $_.Account.Id -eq $obj.User } | `
                    Select-Object -First 1)

            if (-not $null -eq $contextObj) {
                Select-AzContext -InputObject $contextObj > $null

                $fake = (Get-AzAccessToken `
                        -ResourceUrl "https://service.powerapps.com/" `
                        -AsSecureString -ErrorAction SilentlyContinue).Token
            }
        }

        if ([string]::IsNullOrWhiteSpace($fake) -or $Force) {
            if ([string]::IsNullOrWhiteSpace($fake)) {
                Write-PSFMessage -Level Important -Message "It seems that your credentials/cache has <c='sub'>expired</c>. Will force an authentication prompt for the <c='em'>$($obj.User)</c>."
            }
            else {
                Write-PSFMessage -Level Verbose -Message "Force flag is set. Will force an authentication prompt for the <c='em'>$($obj.User)</c>."
            }
            
            Start-Sleep -Seconds 2

            if ($authProvider -eq 'AzCli') {
                # Subscription selection is irrelevant for BAP tenant auth (Power Platform tokens).
                # --allow-no-subscriptions skips subscription discovery for tenant-level
                # operations, matching the Az path's SkipContextPopulation behaviour
                # (no subscription context is populated).
                $null = az login --tenant $obj.Tenant --allow-no-subscriptions 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $messageString = "Azure CLI login failed for tenant <c='em'>$($obj.Tenant)</c>. Please run <c='em'>az login --tenant $($obj.Tenant) --allow-no-subscriptions</c> manually and try again."
                    Write-PSFMessage -Level Important -Message $messageString
                    Stop-PSFFunction -Message "Stopping because the Azure CLI login failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                    return
                }
            }
            else {
            # Subscription selection is irrelevant for BAP tenant auth (Power Platform tokens).
            # Do not pass -Subscription: a cached or current Az context may still hold SubA from
            # another tenant, and Connect-AzAccount then fails when that sub is not in the target tenant.
            # Process-scoped LoginExperienceV2 Off avoids the interactive tenant/subscription picker.
            # Process-scoped empty DefaultSubscriptionForLogin stops Az inheriting SubA from Get-AzConfig.
            # Warning (3) and Information (6) streams are discarded so Connect-AzAccount does not print:
            # "Please select the account...", "Retrieving subscriptions...", or DefaultSubscriptionForLogin guidance.
            $loginExperienceOverridden = $false
            $defaultSubscriptionOverridden = $false
            $previousWarningPreference = $WarningPreference
            $previousInformationPreference = $InformationPreference
            try {
                $currentLoginExperience = (Get-AzConfig -LoginExperienceV2 -ErrorAction SilentlyContinue).Value
                if ("$currentLoginExperience" -ne 'Off') {
                    $null = Update-AzConfig -LoginExperienceV2 Off -Scope Process -ErrorAction SilentlyContinue
                    $loginExperienceOverridden = $true
                }

                $currentDefaultSubscription = (Get-AzConfig -DefaultSubscriptionForLogin -ErrorAction SilentlyContinue).Value
                if (-not [string]::IsNullOrWhiteSpace("$currentDefaultSubscription")) {
                    $null = Update-AzConfig -DefaultSubscriptionForLogin '' -Scope Process -ErrorAction SilentlyContinue
                    $defaultSubscriptionOverridden = $true
                }

                $WarningPreference = 'SilentlyContinue'
                $InformationPreference = 'SilentlyContinue'

                $connectParams = @{
                    Tenant                = $obj.Tenant
                    AccountId             = $obj.User
                    SkipContextPopulation = $true
                    WarningAction         = 'SilentlyContinue'
                    InformationAction     = 'SilentlyContinue'
                }

                # 3 = Warning stream, 6 = Information stream (Az login status lines).
                $null = Connect-AzAccount @connectParams 3>$null 6>$null
            }
            finally {
                $WarningPreference = $previousWarningPreference
                $InformationPreference = $previousInformationPreference

                if ($loginExperienceOverridden) {
                    $null = Clear-AzConfig -LoginExperienceV2 -Scope Process -ErrorAction SilentlyContinue
                }

                if ($defaultSubscriptionOverridden) {
                    $null = Clear-AzConfig -DefaultSubscriptionForLogin -Scope Process -ErrorAction SilentlyContinue
                }
            }
            }
        }

        if (Get-Command Clear-BapTokenCache -ErrorAction SilentlyContinue) { Clear-BapTokenCache }
        else { $script:BapTokenCache = @{} }

        Register-PSFTaskEngineTask -Name EnvironmentRefresh -Interval (New-TimeSpan -Minutes 15) -ResetTask -ScriptBlock {
            Set-PSFTaskEngineCache -Module d365bap.tools -Name Environments -Value (Get-BapEnvironment -FscmEnabled:$FscmEnabled).EnvName
        }
    }
    
    end {
        
    }
}