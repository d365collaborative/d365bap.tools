<#
    .SYNOPSIS
        Deploy a Unified environment via the Power Platform SDK.

    .DESCRIPTION
        Deploys a Finance and Operations Unified environment (UDE or USE) through the bundled
        Power Platform SDK instead of the legacy Business App Platform endpoint.

        Input is validated against the provisioning cache before anything is sent.

    .PARAMETER Type
        UDE (sandbox with developer tools) or USE (sandbox without developer tools).

    .PARAMETER Name
        Name of the new environment as it will be displayed in Power Platform Admin Center (PPAC).

    .PARAMETER CustomDomainName
        Lowercase domain prefix, e.g. "demo-time". When omitted, Power Platform assigns one.

    .PARAMETER Location
        Deployment location, e.g. "europe". Tab completion lists the available locations.

    .PARAMETER Template
        UDE needs D365_DeveloperEdition, USE a D365_FinOps* template.
        Default: D365_DeveloperEdition

    .PARAMETER Language
        Base language as locale id (e.g. 1033) or name. When omitted, the tenant default is used.

    .PARAMETER Currency
        Currency code, e.g. "DKK". When omitted, the tenant default currency is used.

    .PARAMETER NoDemoDb
        Instructs the cmdlet to create the environment without a demo database.

    .PARAMETER Version
        The version of the Finance and Operations application to be installed in the new environment.

    .PARAMETER SecurityGroup
        Entra Groups security group to restrict access to the new environment.

    .PARAMETER EnvironmentGroup
        ID or display name of the environment group. Makes the environment a managed environment.

    .PARAMETER PostProvisionDelaySeconds
        Extra wait in seconds after the environment is ready, before package install.
        Default: 60

    .PARAMETER ReadyStateTimeoutMinutes
        Maximum minutes to wait for the environment to reach state Ready.
        Default: 60

    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the final provisioning app installation is completed.

    .PARAMETER EarlyRelease
        Creates the environment in the early release cycle. Not all locations support this.

    .EXAMPLE
        PS C:\> New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe"

        Creates UDE "MyUdeEnv" in "europe" with demo data, an assigned domain, the latest version and open access.

    .EXAMPLE
        PS C:\> New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -CustomDomainName "myudeenv"

        Same as above, but with the custom domain name "myudeenv".

    .EXAMPLE
        PS C:\> New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -Version "10.0.44" -WhatIf

        Shows the resolved provisioning payload without creating anything. Without -WhatIf it installs 10.0.44.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function New-UnifiedEnvironmentV2 {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	param (
		[Parameter (Mandatory = $true)]
		[ValidateSet("UDE", "USE")]
		[string] $Type,

		[Parameter (Mandatory = $true)]
		[string] $Name,

		[string] $CustomDomainName,

		[Parameter (Mandatory = $true)]
		[string] $Location,

		[string] $Template = 'D365_DeveloperEdition',

		[string] $Language,

		[string] $Currency,

		[switch] $NoDemoDb,

		[version] $Version,

		[Alias('EntraGroup')]
		[string] $SecurityGroup,

		[Alias('EnvironmentGroupId', 'EnvironmentGroupName')]
		[string] $EnvironmentGroup,

		[ValidateRange(0, 300)]
		[int] $PostProvisionDelaySeconds = 60,

		[ValidateRange(1, 720)]
		[int] $ReadyStateTimeoutMinutes = 60,

		[switch] $WaitForCompletion,

		[switch] $EarlyRelease
	)

	begin {
		if (Test-PSFFunctionInterrupt) { return }

		# Cache-only resolution first: no authentication, no network.
		$locationName = Resolve-ProvisioningLocation -Location $Location
		$templateName = Resolve-ProvisioningTemplate -Location $locationName -Template $Template -EnvironmentSku 'Sandbox' -AllowedPattern $script:ProvisioningV2TemplateFilter

		if ($Type -eq 'UDE' -and $templateName -ne 'D365_DeveloperEdition') {
			Stop-PSFFunction -Message "Type 'UDE' requires template 'D365_DeveloperEdition'. 'USE' environments use a Finance and Operations template instead." -EnableException $true
			return
		}
		if ($Type -eq 'USE' -and $templateName -eq 'D365_DeveloperEdition') {
			$finOpsTemplates = @($script:ProvisioningCache.templates[$locationName] | Where-Object { $_.name -like 'D365_FinOps*' } | ForEach-Object { $_.name } | Sort-Object -Unique)
			Stop-PSFFunction -Message "Type 'USE' cannot use template 'D365_DeveloperEdition'. Pick a Finance and Operations template instead. Supported values: $($finOpsTemplates -join ', '). Note that -Template defaults to 'D365_DeveloperEdition', so it must be specified explicitly for 'USE'." -EnableException $true
			return
		}
		$secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
		$tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

		# Language and currency catalogs resolve against the selected
		# location. Loaded once, then kept in memory for the session.
		Import-ProvisioningCatalog

		$catalogLanguages = @($script:ProvisioningCache['languages'][$locationName])
		$catalogCurrencies = @($script:ProvisioningCache['currencies'][$locationName])

		if ($PSBoundParameters.ContainsKey('Language')) {
			$languageMatch = @()
			if ("$Language" -match '^\d+$') {
				$languageMatch = @($catalogLanguages | Where-Object { $_.localeId -eq ([int]$Language) })
			}
			else {
				$languageMatch = @($catalogLanguages | Where-Object { $_.localizedName -eq $Language })
			}
			if ($languageMatch) {
				$baseLanguage = [int]$languageMatch[0].localeId
				$languageName = $languageMatch[0].localizedName
			}
			elseif ("$Language" -match '^\d+$' -and -not $catalogLanguages.Count) {
				$baseLanguage = [int]$Language
				$languageName = $null
			}
			else {
				$validLanguages = @($catalogLanguages | ForEach-Object { $_.localeId } | Sort-Object -Unique)
				throw "Unknown language '$Language' for location '$locationName'. Supported values: $($validLanguages -join ', ')."
			}
		}

		if ($PSBoundParameters.ContainsKey('Currency')) {
			$currencyMatch = @($catalogCurrencies | Where-Object { $_.code -eq $Currency })
			if ($catalogCurrencies.Count -and -not $currencyMatch) {
				$validCurrencies = @($catalogCurrencies | ForEach-Object { $_.code } | Sort-Object -Unique)
				throw "Unknown currency '$Currency' for location '$locationName'. Supported values: $($validCurrencies -join ', ')."
			}
			$currencyCode = if ($currencyMatch) { $currencyMatch[0].code } else { $Currency }
		}

		if (-not $PSBoundParameters.ContainsKey('Language') -or -not $PSBoundParameters.ContainsKey('Currency')) {
			$tenantDefault = $null
			$tenantDefaultCache = Get-ProvisioningTenantDefaultCache
			if ($tenantDefaultCache -and $tenantDefaultCache.defaults -and $tenantDefaultCache.defaults[$locationName]) {
				$cachedDefault = $tenantDefaultCache.defaults[$locationName]
				$tenantDefault = [pscustomobject]@{
					BaseLanguage = [int]$cachedDefault.language.localeId
					LanguageName = $cachedDefault.language.localizedName
					CurrencyCode = $cachedDefault.currency.code
				}
			}
			else {
				$tenantDefault = Get-ProvisioningTenantDefault -Location $locationName -Token $tokenPowerApiValue
			}

			if (-not $PSBoundParameters.ContainsKey('Language')) {
				$baseLanguage = $tenantDefault.BaseLanguage
				$languageName = $tenantDefault.LanguageName
			}
			if (-not $PSBoundParameters.ContainsKey('Currency')) {
				$currencyCode = $tenantDefault.CurrencyCode
			}
		}

		$SecurityGroupId = $null
		$EnvironmentGroupId = $null

		if ($SecurityGroup) {
			$SecurityGroupId = Get-GraphGroup `
				-Group $SecurityGroup | `
				Select-Object -ExpandProperty id
		}

		if ($EnvironmentGroup) {
			$environmentGroupGuid = [guid]::Empty

			if ([guid]::TryParse($EnvironmentGroup, [ref] $environmentGroupGuid)) {
				$EnvironmentGroupId = $environmentGroupGuid.ToString()
			}
			else {
				$matchingEnvironmentGroups = @(Get-PpacEnvironmentGroup -EnvironmentGroup $EnvironmentGroup | Where-Object {
						$_.DisplayName -eq $EnvironmentGroup
					})

				if ($matchingEnvironmentGroups.Count -eq 0) {
					Stop-PSFFunction -Message "Environment group '$EnvironmentGroup' was not found. Use Get-PpacEnvironmentGroup to list available environment groups."
					return
				}

				if ($matchingEnvironmentGroups.Count -gt 1) {
					Stop-PSFFunction -Message "Environment group name '$EnvironmentGroup' is ambiguous. Specify the environment group ID instead. Use Get-PpacEnvironmentGroup to list available environment groups."
					return
				}

				$EnvironmentGroupId = $matchingEnvironmentGroups[0].Id
			}
		}

		if (Test-PSFFunctionInterrupt) { return }

		$preview = [pscustomobject]@{
			Name               = $Name
			Type               = $Type
			Location           = $locationName
			Template           = $templateName
			EnvironmentSku     = 'Sandbox'
			BaseLanguage       = $baseLanguage
			LanguageName       = $languageName
			CurrencyCode       = $currencyCode
			CustomDomainName   = $CustomDomainName
			DevToolsEnabled    = ($Type -eq 'UDE')
			DemoDataEnabled    = (-not $NoDemoDb)
			Version            = if ($Version) { $Version.ToString() } else { $null }
			SecurityGroupId    = $SecurityGroupId
			EnvironmentGroupId = $EnvironmentGroupId
			EarlyRelease       = [bool]$EarlyRelease
		}

		$shouldProvision = $PSCmdlet.ShouldProcess($Name, "Create unified environment ($Type) in location '$locationName'")
		if (-not $shouldProvision) {
			$preview
			return
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }
		if (-not $tokenPowerApiValue) { return }
		if (-not $shouldProvision) { return }

		$shellEnvironmentParams = @{
			Name                      = $Name
			LocationName              = $locationName
			TemplateName              = $templateName
			BaseLanguage              = $baseLanguage
			CurrencyCode              = $currencyCode
			CustomDomainName          = $CustomDomainName
			SecurityGroupId           = $SecurityGroupId
			EnvironmentGroupId        = $EnvironmentGroupId
			TokenPowerApiValue        = $tokenPowerApiValue
			EarlyRelease              = $EarlyRelease
			ReadyStateTimeoutMinutes  = $ReadyStateTimeoutMinutes
			PostProvisionDelaySeconds = $PostProvisionDelaySeconds
		}

		$shellEnvironment = New-V2ShellEnvironment @shellEnvironmentParams

		if ($null -eq $shellEnvironment) { return }

		$environmentExists = $shellEnvironment.EnvironmentExists
		$environmentReady = $shellEnvironment.EnvironmentReady
		$envObj = $shellEnvironment.Environment

		if ($environmentExists -and $environmentReady) {

			$platformInstallParams = @{
				Name               = $Name
				Environment        = $envObj
				TokenPowerApiValue = $tokenPowerApiValue
			}

			$appObj = Install-V2PlatformApplicationPackage @platformInstallParams

			if ($null -eq $appObj) { return }

			$provisioningParams = @{
				Name              = $Name
				Type              = $Type
				NoDemoDb          = $NoDemoDb
				Version           = $Version
				WaitForCompletion = $WaitForCompletion
			}

			$appObj = Start-V2PlatformProvisioning @provisioningParams

			if ($null -eq $appObj) { return }

			# Output the app details, for the user to see
			$appObj
		}
	}

	end {

	}
}

function New-V2ShellEnvironment {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[string] $LocationName,

		[Parameter(Mandatory = $true)]
		[string] $TemplateName,

		[Parameter(Mandatory = $true)]
		[int] $BaseLanguage,

		[Parameter(Mandatory = $true)]
		[string] $CurrencyCode,

		[string] $CustomDomainName,

		[string] $SecurityGroupId,

		[string] $EnvironmentGroupId,

		[Parameter(Mandatory = $true)]
		[string] $TokenPowerApiValue,

		[switch] $EarlyRelease,

		[Parameter(Mandatory = $true)]
		[int] $ReadyStateTimeoutMinutes,

		[Parameter(Mandatory = $true)]
		[int] $PostProvisionDelaySeconds
	)

	$sdkTypes = @(
		'Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequest'
		'Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestLinkedMetadata'
		'Microsoft.PowerPlatform.Management.Models.EnvironmentRequestCurrency'
		'Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestCluster'
		'Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestParentGroup'
	)
	foreach ($sdkType in $sdkTypes) {
		if (-not ($sdkType -as [type])) {
			Stop-PSFFunction -Message "The bundled SDK type '$sdkType' is not loaded. Reimport the module to initialize the SDK."
			return
		}
	}

	$body = [Activator]::CreateInstance([Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequest])
	$body.DisplayName = $Name
	$body.Description = ''
	$body.EnvironmentSku = [Microsoft.PowerPlatform.Management.Models.EnvironmentSku]::Sandbox
	$body.Location = $LocationName
	$body.DatabaseType = 'CommonDataService'

	$linked = [Activator]::CreateInstance([Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestLinkedMetadata])
	$linked.BaseLanguageCode = $BaseLanguage
	$currency = [Activator]::CreateInstance([Microsoft.PowerPlatform.Management.Models.EnvironmentRequestCurrency])
	$currency.Code = $CurrencyCode
	$linked.Currency = $currency
	$linked.Templates = [Collections.Generic.List[string]]@($TemplateName)
	if ($CustomDomainName) { $linked.DomainName = $CustomDomainName }
	if ($SecurityGroupId) { $linked.SecurityGroupId = $SecurityGroupId }
	$body.LinkedEnvironmentMetadata = $linked

	if ($EarlyRelease) {
		$cluster = [Activator]::CreateInstance([Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestCluster])
		$cluster.Category = 'FirstRelease'
		$body.Cluster = $cluster
	}

	if ($EnvironmentGroupId) {
		$parentGroup = [Activator]::CreateInstance([Microsoft.PowerPlatform.Management.Models.CreateEnvironmentRequestParentGroup])
		$parentGroup.Id = $EnvironmentGroupId
		$body.ParentEnvironmentGroup = $parentGroup
	}

	$environmentExists = $false
	$environmentReady = $false
	$provisionedNew = $false
	$envObj = $null

	# Phase 1: Ensure environment exists
	$envObj = Get-BapEnvironment -EnvironmentId $Name | `
		Select-Object -First 1

	if ($null -ne $envObj) {
		$environmentExists = $true
		Write-PSFMessage -Level Verbose -Message "Environment '$Name' already exists. Skipping shell provisioning and moving to readiness checks."
	}
	else {
		$operation = @{
			Resource = @{ Builder = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Provisioning.Environments.EnvironmentsRequestBuilder' }
			Method   = 'PostAsync'
		}
		try {
			$null = Invoke-BapSdkRequest -Resource $operation.Resource -Method $operation.Method -Body $body -Token $TokenPowerApiValue
			$provisionedNew = $true
			$environmentExists = $true
		}
		catch {
			$messageString = "Failed to provision the shell environment '$Name' in location '$LocationName' with template '$TemplateName'. The API reported: $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because the shell environment could not be provisioned." -Exception $([System.Exception]::new($messageString))
			return
		}
	}

	# Phase 2: Ensure environment is ready
	if ($environmentExists) {
		$readyStateDeadline = (Get-Date).AddMinutes($ReadyStateTimeoutMinutes)

		do {
			$envObj = Get-BapEnvironment -EnvironmentId $Name | `
				Select-Object -First 1

			if ($null -eq $envObj) {
				Stop-PSFFunction -Message "Environment '$Name' could not be found while waiting for it to become ready."
				return
			}

			$environmentReady = $envObj.State -eq "Ready"

			if (-not $environmentReady) {
				if ((Get-Date) -ge $readyStateDeadline) {
					$messageString = "Environment '$Name' did not reach state 'Ready' within $ReadyStateTimeoutMinutes minutes. Last known state was '$($envObj.State)'."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because environment readiness timed out." -Exception $([System.Exception]::new($messageString))
					return
				}

				Write-PSFMessage -Level Verbose -Message "Waiting for environment '$Name' to be provisioned and reach state 'Ready'..."
				Start-Sleep -Seconds 20
			}
		} until ($environmentReady)

		if ($provisionedNew -and $PostProvisionDelaySeconds -gt 0) {
			$progressActivity = "Waiting for Microsoft to finish provisioning the environment '$Name' and for the platform package endpoint to be ready..."
			for ($secondsElapsed = 0; $secondsElapsed -lt $PostProvisionDelaySeconds; $secondsElapsed++) {
				$secondsRemaining = $PostProvisionDelaySeconds - $secondsElapsed
				$percentComplete = [Math]::Floor(($secondsElapsed / $PostProvisionDelaySeconds) * 100)

				Write-Progress `
					-Activity $progressActivity `
					-Status "Give it a minute... $secondsRemaining sec remaining" `
					-PercentComplete $percentComplete

				Start-Sleep -Seconds 1
			}

			Write-Progress `
				-Activity $progressActivity `
				-Status "Installing platform package next." `
				-PercentComplete 100 `
				-Completed
		}

		Write-PSFMessage -Level Verbose -Message "Environment '$Name' is ready for provisioning and platform package installation."
	}

	[PsCustomObject]@{
		EnvironmentExists = $environmentExists
		EnvironmentReady  = $environmentReady
		Environment       = $envObj
		ProvisionedNew    = $provisionedNew
	}
}

function Install-V2PlatformApplicationPackage {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[psobject] $Environment,

		[Parameter(Mandatory = $true)]
		[string] $TokenPowerApiValue
	)

	$platformAppParams = @{
		EnvironmentId = $Name
		Name          = 'Dynamics 365 Finance and Operations Platform Tools'
	}

	$appPlatform = Get-PpacD365App @platformAppParams | Select-Object -First 1

	$headersLocal = @{
		"Authorization" = "Bearer $($TokenPowerApiValue)"
		"Content-Type"  = "application/json"
	}

	$localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages/{1}/install?api-version=2024-10-01" `
		-f $Environment.PpacEnvId `
		, $appPlatform.PpacPackageName

	$lastError = $null
	$platformInstallMaxAttempts = 3

	for ($platformInstallAttempt = 1; $platformInstallAttempt -le $platformInstallMaxAttempts; $platformInstallAttempt++) {
		Write-PSFMessage -Level Verbose -Message "Installing platform package '$($appPlatform.PpacPackageName)' (attempt $platformInstallAttempt of $platformInstallMaxAttempts)..."

		try {
			$null = Invoke-RestMethod -Method 'Post' -Uri $localUri -Headers $headersLocal -Body '{}' -ErrorAction Stop
			$lastError = $null
			break
		}
		catch {
			$lastError = $_.ErrorDetails.Message
			if (-not $lastError) { $lastError = $_.Exception.Message }
			if ($platformInstallAttempt -lt $platformInstallMaxAttempts) {
				Write-PSFMessage -Level Verbose -Message "Platform package install attempt failed with '$lastError'. Retrying in 10 seconds..."
				Start-Sleep -Seconds 10
			}
		}
	}

	if ($lastError) {
		$messageString = "Failed to install the platform application package: <c='em'>$($appPlatform.PpacPackageName)</c>. The API reported: $lastError"
		Write-PSFMessage -Level Important -Message $messageString
		Stop-PSFFunction -Message "Stopping because installing the platform application package failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		return
	}

	$appPlatformInstalled = $false

	do {
		Write-PSFMessage -Level Verbose -Message "Waiting for platform app to be installed ..."
		Start-Sleep -Seconds 20

		$appObj = Get-PpacD365App @platformAppParams | Select-Object -First 1

		$appPlatformInstalled = $appObj.Status -eq "Installed"
	} until ($appPlatformInstalled -eq $true)

	$appObj
}

function Start-V2PlatformProvisioning {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[ValidateSet("UDE", "USE")]
		[string] $Type,

		[Parameter(Mandatory = $true)]
		[switch] $NoDemoDb,

		[version] $Version,

		[switch] $WaitForCompletion
	)

	<#
        Platform version is 10.0.X for humans, but the application package version is 10.0.X.Y,
        so we need to get the latest available version and find the matching one.
    #>
	if (-not [System.String]::IsNullOrWhiteSpace($Version)) {
		$tmpVersion = $Version.ToString().Substring(0, 7)
		$colVersions = Get-PpacD365PlatformUpdate `
			-EnvironmentId $Name

		$deployVersion = $colVersions | `
			Where-Object Platform -eq $tmpVersion | `
			Select-Object -First 1
	}
	else {
		$deployVersion = Get-PpacD365PlatformUpdate `
			-EnvironmentId $Name `
			-Latest | `
			Select-Object -First 1
	}

	if ($null -eq $deployVersion) {
		$messageString = "The specified version <c='em'>$Version</c> was not valid for the environment. Please verify the available versions using the <c='em'>Get-PpacD365PlatformUpdate</c> cmdlet."
		Write-PSFMessage -Level Important -Message $messageString
		Stop-PSFFunction -Message "The specified version was not valid for the environment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
		return
	}

	$envObj = Get-BapEnvironment -EnvironmentId $Name | Select-Object -First 1
	$baseUri = $envObj.PpacEnvUri

	$secureToken = Get-BapAccessToken -ResourceUrl $baseUri
	$tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

	$headersWebApi = @{
		"Authorization" = "Bearer $($tokenWebApiValue)"
		"Content-Type"  = "application/json"
	}

	$localUri = $baseUri + '/api/data/v9.2/msprov_queuefnoinstallorupdate'

	$payload = [PsCustomObject][ordered]@{
		"payload" = "ApplicationVersion=$($deployVersion.Version)|DevToolsEnabled=$($Type -eq 'UDE')|DemoDataEnabled=$(-not $NoDemoDb)"
	} | ConvertTo-Json -Depth 3

	try {
		$null = Invoke-RestMethod -Method 'Post' -Uri $localUri -Headers $headersWebApi -Body $payload -ContentType $headersWebApi.'Content-Type' -ErrorAction Stop
	}
	catch {
		$details = $_.ErrorDetails.Message
		if (-not $details) { $details = $_.Exception.Message }
		$messageString = "Failed to provision the environment with the specified version: <c='em'>$($deployVersion.Version)</c>. The API reported: $details"
		Write-PSFMessage -Level Important -Message $messageString
		Stop-PSFFunction -Message "Stopping because provisioning the environment with the specified version failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
		return
	}

	$provisioningAppParams = @{
		EnvironmentId = $Name
		Name          = 'Dynamics 365 Finance and Operations Provisioning App'
	}

	do {
		Write-PSFMessage -Level Verbose -Message "Waiting for provisioning installation to be queued ..."
		Start-Sleep -Seconds 20

		$appObj = Get-PpacD365App @provisioningAppParams
	} while (-not $appObj.StateIsInstalled)

	while ($WaitForCompletion -and $appObj.Status -ne "Installed") {
		Write-PSFMessage -Level Verbose -Message "Waiting for provisioning installation to be completed ..."
		Start-Sleep -Seconds 20

		$appObj = Get-PpacD365App @provisioningAppParams
	}

	$appObj
}
