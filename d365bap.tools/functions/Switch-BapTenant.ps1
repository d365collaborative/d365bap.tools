
<#
    .SYNOPSIS
        Switches the current context to a specified BAP tenant.

    .DESCRIPTION
        Switches the current context to a saved BAP tenant, logging in again when needed.

    .PARAMETER Id
        The ID of the BAP tenant to switch to.

    .PARAMETER Force
        Forces an authentication prompt, even with a valid token.

    .EXAMPLE
        PS C:\> Switch-BapTenant -Id "Contoso"

        Switches to the Contoso tenant, prompting for login when needed.

    .EXAMPLE
        PS C:\> Switch-BapTenant -Id "Contoso" -Force

        Switches to Contoso and always prompts for login.

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
				$null = az login --tenant $obj.Tenant --allow-no-subscriptions 2>$null
				if ($LASTEXITCODE -ne 0) {
					$messageString = "Azure CLI login failed for tenant <c='em'>$($obj.Tenant)</c>. Please run <c='em'>az login --tenant $($obj.Tenant) --allow-no-subscriptions</c> manually and try again."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the Azure CLI login failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}
			}
			else {
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

		if (Get-Command Clear-FinOpsVersionCache -ErrorAction SilentlyContinue) { Clear-FinOpsVersionCache }
		if (Get-Command Start-FinOpsVersionPreload -ErrorAction SilentlyContinue) { Start-FinOpsVersionPreload }

		Register-PSFTaskEngineTask -Name EnvironmentRefresh -Interval (New-TimeSpan -Minutes 15) -ResetTask -ScriptBlock {
			Set-PSFTaskEngineCache -Module d365bap.tools -Name Environments -Value (Get-BapEnvironment -FscmEnabled:$FscmEnabled).EnvName
		}
	}

	end {

	}
}
