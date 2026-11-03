<#
    .SYNOPSIS
        Retrieves the available Azure tenants.

    .DESCRIPTION
        Reads the tenant and account pairs from the local Azure context cache. The auth provider set with Set-BapToolsAuthProvider selects Azure CLI or Az.Accounts data, and cached profile files are used when the provider call fails.

    .PARAMETER Upn
        Specifies the User Principal Name (UPN) to match. Supports wildcards.

        Default: * (all UPNs)

    .PARAMETER TenantId
        Specifies the tenant ID to match. Supports wildcards.

        Default: * (all tenants)

    .PARAMETER AsExcelOutput
        Exports the results to an Excel file instead of the console.

    .PARAMETER AsHashTable
        Returns the results as a hashtable instead of objects.

    .EXAMPLE
        PS C:\> Get-BapTenant

        Lists the cached Azure tenants.
        It uses the default -Upn * for all accounts.
        It uses the default -TenantId * for all tenants.

    .EXAMPLE
        PS C:\> Get-BapTenant -Upn "alex@contoso.com"

        Filters the cached tenants for one account.
        It filters on -Upn alex@contoso.com.
        It uses the default -TenantId * for all tenants.

    .EXAMPLE
        PS C:\> Get-BapTenant -TenantId "12345678-90ab-cdef-1234-567890abcdef"

        Filters the cached tenants for one tenant ID.
        It filters on -TenantId 12345678-90ab-cdef-1234-567890abcdef.
        It uses the default -Upn * for all accounts.

    .EXAMPLE
        PS C:\> Get-BapTenant -AsExcelOutput

        Exports the cached tenants to an Excel file.
        It uses -AsExcelOutput to write the Get-BapTenant worksheet.
        It uses the default -Upn * for all accounts.

    .EXAMPLE
        PS C:\> Get-BapTenant -AsHashTable

        Returns the cached tenants as a hashtable.
        It uses -AsHashTable to convert the results to a hashtable.
        It uses the default -TenantId * for all tenants.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapTenant {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('D365Bap.Tools.TenantCredential[]')]
	param (
		[SupportsWildcards()]
		[Alias("Login")]
		[Alias("User")]
		[Alias("Username")]
		[string] $Upn = "*",

		[SupportsWildcards()]
		[string] $TenantId = "*",

		[Parameter(ParameterSetName = 'Excel')]
		[switch] $AsExcelOutput,

		[Parameter(ParameterSetName = 'HashTable')]
		[switch] $AsHashTable
	)

	begin {
		$authProvider = Get-PSFConfigValue `
			-FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		try {
			if ($authProvider -eq 'AzCli') {
				$colTenantDomains = @()
				try {
					$rawNames = az account tenant list --query '[].[tenantId, displayName]' -o tsv 2>$null
					if (($LASTEXITCODE -eq 0) `
							-and ($rawNames)) {
						$colTenantDomains = @($rawNames |
							ForEach-Object {
								$parts = "$_".Split("`t")
								if (($parts.Count -ge 2) `
										-and (-not [string]::IsNullOrWhiteSpace($parts[0]))) {
									[pscustomobject][ordered]@{
										id   = $parts[0].Trim()
										name = $parts[1].Trim()
									}
								}
							} | Where-Object { -Not ($null -eq $_) })
					}
				}
				catch {
					Write-PSFMessage `
						-Level Verbose `
						-Message "az account tenant list failed with: $($_.Exception.Message). Tenant names will be empty."
				}
			}
			else {
				$colTenantDomains = @(Get-AzTenant -ErrorAction Stop)
			}
		}
		catch {
			Write-PSFMessage `
				-Level Verbose `
				-Message "Get-AzTenant failed with: $($_.Exception.Message). Tenant names will be empty."

			$colTenantDomains = @()
		}
	}

	process {
		$colAzContexts = $null
		if ($authProvider -eq 'AzCli') {
			$colAzContexts = @()
			try {
				$azRaw = az account list --query '[].{account:user.name, tenant:tenantId}' -o json 2>$null
				if (($LASTEXITCODE -eq 0) `
						-and (-not [string]::IsNullOrWhiteSpace($azRaw))) {
					foreach ($itemEntry in ("$azRaw" |
							ConvertFrom-Json -ErrorAction Stop)) {
						if (($null -eq $itemEntry) `
								-or ([string]::IsNullOrWhiteSpace($itemEntry.tenant))) { continue }

						if ([string]::IsNullOrWhiteSpace($itemEntry.account)) { continue }

						$tmpContext = [pscustomobject][ordered]@{
							Account = [pscustomobject][ordered]@{ Id = "$($itemEntry.account)" }
							Tenant  = [pscustomobject][ordered]@{ Id = "$($itemEntry.tenant)" }
						}
						$colAzContexts += $tmpContext
					}
				}
			}
			catch {
				Write-PSFMessage `
					-Level Verbose `
					-Message "az account list failed with: $($_.Exception.Message). Falling back to cached Azure CLI profile."
			}

			if ($colAzContexts.Count -eq 0) {
				$colProfileFiles = @()
				if (-not [string]::IsNullOrWhiteSpace($env:AZURE_CONFIG_DIR)) {
					$colProfileFiles += Join-Path $env:AZURE_CONFIG_DIR "azureProfile.json"
				}
				if ($HOME) {
					$colProfileFiles += Join-Path (Join-Path $HOME ".azure") "azureProfile.json"
				}
				if ($env:USERPROFILE) {
					$colProfileFiles += Join-Path (Join-Path $env:USERPROFILE ".azure") "azureProfile.json"
				}
				$objProfileFile = $colProfileFiles |
				Where-Object {
					(-not [string]::IsNullOrWhiteSpace($_)) `
						-and (Test-Path $_)
				} | Select-Object -First 1

				if ($objProfileFile) {
					try {
						$cachedProfile = Get-Content -Raw `
							-Path $objProfileFile `
							-ErrorAction Stop |
						ConvertFrom-Json -ErrorAction Stop

						foreach ($itemSub in @($cachedProfile.subscriptions)) {
							if (($null -eq $itemSub) `
									-or ([string]::IsNullOrWhiteSpace($itemSub.tenantId))) { continue }

							if (($null -eq $itemSub.user) `
									-or ([string]::IsNullOrWhiteSpace($itemSub.user.name))) { continue }

							$tmpContext = [pscustomobject][ordered]@{
								Account = [pscustomobject][ordered]@{ Id = "$($itemSub.user.name)" }
								Tenant  = [pscustomobject][ordered]@{ Id = "$($itemSub.tenantId)" }
							}
							$colAzContexts += $tmpContext
						}
					}
					catch {
						Write-PSFMessage `
							-Level Verbose `
							-Message "Failed to read cached Azure CLI profile from '$objProfileFile': $($_.Exception.Message)"
					}
				}
			}

			if ($colAzContexts.Count -eq 0) {
				try {
					$azShow = az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null
					if (($LASTEXITCODE -eq 0) `
							-and (-not [string]::IsNullOrWhiteSpace($azShow))) {
						$current = "$azShow" |
						ConvertFrom-Json -ErrorAction Stop

						if ((-Not ($null -eq $current)) `
								-and (-not [string]::IsNullOrWhiteSpace($current.tenant))) {
							$colAzContexts = @([pscustomobject][ordered]@{
									Account = [pscustomobject][ordered]@{ Id = "$($current.user)" }
									Tenant  = [pscustomobject][ordered]@{ Id = "$($current.tenant)" }
								})
						}
					}
				}
				catch {
					Write-PSFMessage `
						-Level Verbose `
						-Message "az account show also failed with: $($_.Exception.Message)"
				}
			}
		}
		else {
			try {
				$colAzContexts = @(Get-AzContext `
						-ListAvailable `
						-ErrorAction Stop)
			}
			catch {
				Write-PSFMessage `
					-Level Verbose `
					-Message "Get-AzContext -ListAvailable failed with: $($_.Exception.Message). Falling back to cached Azure profile."

				$colAzContexts = @()

				$colContextFiles = @()
				if (-not [string]::IsNullOrWhiteSpace($env:AZURE_CONFIG_DIR)) {
					$colContextFiles += Join-Path $env:AZURE_CONFIG_DIR "AzureRmContext.json"
				}
				if ($HOME) {
					$colContextFiles += Join-Path (Join-Path $HOME ".Azure") "AzureRmContext.json"
				}
				if ($env:USERPROFILE) {
					$colContextFiles += Join-Path (Join-Path $env:USERPROFILE ".Azure") "AzureRmContext.json"
				}
				$objContextFile = $colContextFiles |
				Where-Object {
					(-not [string]::IsNullOrWhiteSpace($_)) `
						-and (Test-Path $_)
				} | Select-Object -First 1

				if ($objContextFile) {
					try {
						$cachedProfile = Get-Content -Raw `
							-Path $objContextFile `
							-ErrorAction Stop |
						ConvertFrom-Json -ErrorAction Stop

						foreach ($itemProp in $cachedProfile.Contexts.PSObject.Properties) {
							$entry = $itemProp.Value
							if (($null -eq $entry) `
									-or (($null -eq $entry.Tenant)) `
									-or ([string]::IsNullOrWhiteSpace($entry.Tenant.Id))) { continue }

							if (($null -eq $entry.Account) `
									-or ([string]::IsNullOrWhiteSpace($entry.Account.Id))) { continue }

							$tmpContext = [pscustomobject][ordered]@{
								Account = [pscustomobject][ordered]@{ Id = $entry.Account.Id }
								Tenant  = [pscustomobject][ordered]@{ Id = $entry.Tenant.Id }
							}
							$colAzContexts += $tmpContext
						}
					}
					catch {
						Write-PSFMessage `
							-Level Verbose `
							-Message "Failed to read cached Azure contexts from '$objContextFile': $($_.Exception.Message)"
					}
				}

				if ($colAzContexts.Count -eq 0) {
					try {
						$current = Get-AzContext -ErrorAction Stop
						if ((-Not ($null -eq $current)) `
								-and (-Not ($null -eq $current.Tenant)) `
								-and ($current.Tenant.Id)) {
							$colAzContexts = @($current)
						}
					}
					catch {
						Write-PSFMessage `
							-Level Verbose `
							-Message "Get-AzContext (current) also failed with: $($_.Exception.Message)"
					}
				}
			}
		}

		$colCachedCreds = @(
			($colAzContexts |
			Where-Object { -Not ($null -eq $_.Tenant.Id) } |
			Group-Object { $_.Tenant.Id }, `
			{ $_.Account.Id }) |
			ForEach-Object { $_.Group[0] }
		)

		$colRes = @(
			foreach ($itemCredObj in $colCachedCreds) {
				if (-not ($itemCredObj.Account.Id -like $Upn)) { continue }
				if (-not ($itemCredObj.Tenant.Id -like $TenantId)) { continue }

				$itemCredObj |
				Select-PSFObject -TypeName "D365Bap.Tools.TenantCredential" `
					-Property @{ Name = "Upn"; Expression = { $_.Account.Id } },
				@{ Name = "TenantId"; Expression = { $_.Tenant.Id } },
				@{ Name = "TenantName"; Expression = {
						$colTenantDomains |
						Where-Object id -eq $_.Tenant.Id |
						Select-Object `
							-ExpandProperty name `
							-First 1
					}
				}
			}
		)

		if ($AsHashTable) {
			$colRes |
			ConvertTo-PSFHashtable
			return
		}

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName "Get-BapTenant"
			return
		}

		$colRes
	}

	end {
	}
}
