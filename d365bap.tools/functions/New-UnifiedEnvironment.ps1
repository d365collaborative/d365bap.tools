
<#
    .SYNOPSIS
        Deploy a new Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Deploys a new Unified Environment in Power Platform Admin Center (PPAC).
        
        Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).
        
    .PARAMETER Type
        Instructs the cmdlet to create either a Unified Sandbox Environment (USE) or a Unified Developer Environment (UDE).
        
        Valid values are:
        - "USE": Deploys a Unified Sandbox Environment (USE) which is a sandbox environment without developer tools.
        - "UDE": Deploys a Unified Developer Environment (UDE) which is a sandbox environment with developer tools.
        
    .PARAMETER Name
        Name of the new environment as it will be displayed in Power Platform Admin Center (PPAC).
        
    .PARAMETER CustomDomainName
        The custom domain name to be associated with the new environment.
        
        E.g. "demo-time" will create the environment URLs:
        - "https://demo-time.crmX.dynamics.com".
        - "https://demo-time.operations.eu.dynamics.com"
        
    .PARAMETER Location
        The deployment location for the new environment.
        
        This translates to the Power Platform location where the environment will be created.
        
        Data residency and compliance requirements should be considered when selecting the location.
        
        Get-PpacDeployLocation can be used to find available locations.
        
    .PARAMETER Region
        The Azure region for the new environment.
        
        It specifies the physical location of the data center where the environment will be hosted.
        
        Get-PpacDeployLocation | Format-List can be used to find possible regions.
        
    .PARAMETER NoDemoDb
        Instructs the cmdlet to create the environment without a demo database.
        
    .PARAMETER Version
        The version of the Finance and Operations application to be installed in the new environment.
        
    .PARAMETER SecurityGroup
        Entra Groups security group to restrict access to the new environment.
        
    .PARAMETER PostProvisionDelaySeconds
        Additional delay (in seconds) after the shell environment reports as ready.
        
        This pause helps ensure the platform application package endpoint is fully ready before install is attempted.
        
    .PARAMETER ReadyStateTimeoutMinutes
        Maximum number of minutes to wait for the environment to reach state 'Ready'.
        
        Prevents endless waiting when an environment is stuck in a non-ready state.
        
    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the final provisioning app installation is completed.
        
    .PARAMETER EarlyRelease
        Instructs the cmdlet to create the environment in the early release cycle.
        
        Note that not all locations/regions support early release environments.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe"
        
        This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
        It will include a demo database by default.
        It will get a default/unique domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        It will not restrict access to the environment.
        
        It will deploy into the North Europe region, as it's the default region for the Europe location.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -Region "West Europe"
        
        This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
        It will deploy into the "West Europe" region.
        It will include a demo database.
        It will get a default/unique domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        It will not restrict access to the environment.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe" -CustomDomainName "myudeenv"
        
        This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
        It will include a demo database by default.
        It will get the custom domain name "myudeenv".
        It will take the latest available version of Finance and Operations.
        It will not restrict access to the environment.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -NoDemoDb
        
        This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
        It will not include a demo database.
        It will get a default/unique domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        It will not restrict access to the environment.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe" -Version "10.0.44"
        
        This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
        It will include a demo database by default.
        It will get a default/unique domain name assigned by Power Platform.
        It will install version 10.0.44 of Finance and Operations.
        It will not restrict access to the environment.
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "USE" -Name "MyUseEnv" -Location "Europe" -SecurityGroup "MySecurityGroup"
        
        This will create a new Unified Sandbox Environment (USE) named "MyUseEnv" in the "Europe" location.
        It will include a demo database by default.
        It will get a default/unique domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        It will restrict access to the environment to members of the specified Entra Groups security group "MySecurityGroup".
        
    .EXAMPLE
        PS C:\> New-UnifiedEnvironment -Type "UDE" -Name "MyUdeEnv" -Location "Europe" -EarlyRelease
        
        This will create a new Unified Developer Environment (UDE) named "MyUdeEnv" in the "Europe" location.
        The environment will be in the early release cycle.
        It will include a demo database by default.
        It will get a default/unique domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        It will not restrict access to the environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        Author: Florian Hopfner (@FH-Inway)
        
#>
function New-UnifiedEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [ValidateSet("UDE", "USE")]
        [string] $Type,

        [Parameter (Mandatory = $true)]
        [string] $Name,

        [string] $CustomDomainName,

        [Parameter (Mandatory = $true)]
        [string] $Location,

        [string] $Region,

        [switch] $NoDemoDb,

        [version] $Version,

        [Alias('EntraGroup')]
        [string] $SecurityGroup,

        [ValidateRange(0, 300)]
        [int] $PostProvisionDelaySeconds = 60,

        [ValidateRange(1, 720)]
        [int] $ReadyStateTimeoutMinutes = 60,

        [switch] $WaitForCompletion,

        [switch] $EarlyRelease
    )
    
    begin {
        $SecurityGroupId = $null

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }

        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
    
        if ($SecurityGroup) {
            $SecurityGroupId = Get-GraphGroup `
                -Group $SecurityGroup | `
                Select-Object -ExpandProperty id
        }
        
        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $shellEnvironmentParams = @{
            Name                     = $Name
            HeadersBapApi            = $headersBapApi
            Location                 = $Location
            Region                   = $Region
            CustomDomainName         = $CustomDomainName
            SecurityGroupId          = $SecurityGroupId
            PostProvisionDelaySeconds = $PostProvisionDelaySeconds
            ReadyStateTimeoutMinutes  = $ReadyStateTimeoutMinutes
            EarlyRelease              = $EarlyRelease
        }

        $shellEnvironment = New-ShellEnvironment @shellEnvironmentParams

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

            $appObj = Install-PlatformApplicationPackage @platformInstallParams

            if ($null -eq $appObj) { return }

            $provisioningParams = @{
                Name              = $Name
                Type              = $Type
                NoDemoDb          = $NoDemoDb
                Version           = $Version
                WaitForCompletion = $WaitForCompletion
            }

            $appObj = Start-PlatformProvisioning @provisioningParams

            if ($null -eq $appObj) { return }

            # Output the app details, for the user to see
            $appObj
        }
    }
    
    end {
        
    }
}

function New-ShellEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [hashtable] $HeadersBapApi,

        [Parameter(Mandatory = $true)]
        [string] $Location,

        [string] $Region,

        [string] $CustomDomainName,

        [string] $SecurityGroupId,

        [Parameter(Mandatory = $true)]
        [int] $PostProvisionDelaySeconds,

        [Parameter(Mandatory = $true)]
        [int] $ReadyStateTimeoutMinutes,

        [switch] $EarlyRelease
    )

    $localUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2024-05-01'

    $config = [PsCustomObject][ordered]@{
        location   = $Location
        properties = [PsCustomObject][ordered]@{
            databaseType              = "CommonDataService"
            description               = ""
            displayName               = $Name
            environmentSku            = "Sandbox" # UDE & USE - Can only be Sandbox
            linkedEnvironmentMetadata = [PsCustomObject][ordered]@{
                baseLanguage = "" # Maybe it selects the TenantDefault
                currency     = $null # Maybe it selects the TenantDefault
                templates    = @("D365_DeveloperEdition")
            }
        }
    }

    if ($Region) {
        $config.properties | `
            Add-Member -MemberType NoteProperty `
            -Name azureRegion `
            -Value $Region
    }

    if ($CustomDomainName) {
        $config.properties.linkedEnvironmentMetadata | `
            Add-Member -MemberType NoteProperty `
            -Name domainName `
            -Value $CustomDomainName
    }

    if ($null -ne $SecurityGroupId) {
        $config.properties.linkedEnvironmentMetadata | `
            Add-Member -MemberType NoteProperty `
            -Name securityGroupId `
            -Value $SecurityGroupId
    }

    if ($EarlyRelease) {
        $config.properties | `
            Add-Member -MemberType NoteProperty `
                -Name cluster `
                -Value ([PsCustomObject][ordered]@{
                    category = "FirstRelease"
                })
    }

    $payload = $config | ConvertTo-Json -Depth 10

    $environmentExists = $false
    $environmentReady = $false
    $statusEnv = $null
    $envObj = $null

    # Phase 1: Ensure environment exists
    $envObj = Get-BapEnvironment -EnvironmentId $Name | `
        Select-Object -First 1

    if ($null -ne $envObj) {
        $environmentExists = $true
        Write-PSFMessage -Level Verbose -Message "Environment '$Name' already exists. Skipping shell provisioning and moving to readiness checks."
    }
    else {
        $createEnvironmentParams = @{
            Method            = 'Post'
            Uri               = $localUri
            Headers           = $HeadersBapApi
            Body              = $payload
            ContentType       = 'application/json'
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusEnv'
        }

        Invoke-RestMethod @createEnvironmentParams > $null 4>$null

        if ($statusEnv -like "2**") {
            $environmentExists = $true
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

        if ($statusEnv -like "2**" -and $PostProvisionDelaySeconds -gt 0) {
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
        StatusCode        = $statusEnv
    }
}

function Install-PlatformApplicationPackage {
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

    $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages/{1}/install?api-version=2022-03-01-preview" `
        -f $Environment.PpacEnvId `
        , $appPlatform.PpacPackageName

    $statusPlat = $null
    $platformInstallMaxAttempts = 3

    for ($platformInstallAttempt = 1; $platformInstallAttempt -le $platformInstallMaxAttempts; $platformInstallAttempt++) {
        Write-PSFMessage -Level Verbose -Message "Installing platform package '$($appPlatform.PpacPackageName)' (attempt $platformInstallAttempt of $platformInstallMaxAttempts)..."

        $platformInstallParams = @{
            Method            = 'Post'
            Uri               = $localUri
            Headers           = $headersLocal
            Body              = '{}'
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusPlat'
        }

        Invoke-RestMethod @platformInstallParams > $null 4>$null

        if ($statusPlat -like "2**") {
            break
        }

        if ($platformInstallAttempt -lt $platformInstallMaxAttempts) {
            Write-PSFMessage -Level Verbose -Message "Platform package install attempt failed with status '$statusPlat'. Retrying in 10 seconds..."
            Start-Sleep -Seconds 10
        }
    }

    if (-not ($statusPlat -like "2**")) {
        $messageString = "Failed to install the platform application package: <c='em'>$($appPlatform.PpacPackageName)</c>. Please check the environment and try installing the package manually."
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

function Start-PlatformProvisioning {
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

    $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
    $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

    $headersWebApi = @{
        "Authorization" = "Bearer $($tokenWebApiValue)"
        "Content-Type"  = "application/json"
    }

    $localUri = $baseUri + '/api/data/v9.2/msprov_queuefnoinstallorupdate'

    $payload = [PsCustomObject][ordered]@{
        "payload" = "ApplicationVersion=$($deployVersion.Version)|DevToolsEnabled=$($Type -eq 'UDE')|DemoDataEnabled=$(-not $NoDemoDb)"
    } | ConvertTo-Json -Depth 3

    $provisioningRequestParams = @{
        Method             = 'Post'
        Uri                = $localUri
        Headers            = $headersWebApi
        Body               = $payload
        ContentType        = $headersWebApi.'Content-Type'
        SkipHttpErrorCheck = $true
        StatusCodeVariable = 'statusProvision'
    }

    Invoke-RestMethod @provisioningRequestParams > $null 4>$null

    if (-not ($statusProvision -like "2**")) {
        $messageString = "Failed to provision the environment with the specified version: <c='em'>$($deployVersion.Version)</c>. Please check the environment and try provisioning manually."
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