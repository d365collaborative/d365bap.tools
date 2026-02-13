
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
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
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
        [string] $SecurityGroup
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
    
        $SecurityGroupId = Get-GraphGroup `
            -Group $SecurityGroup | `
            Select-Object -ExpandProperty id

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
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

        <#
            Region is about the physical location of the data center where the environment will be hosted,
            while Location is more about data residency and compliance requirements.
            Depending on the Location selected, there might be a subset of Regions available.
        #>
        if ($Region) {
            $config.properties | `
                Add-Member -MemberType NoteProperty `
                -Name azureRegion `
                -Value $Region
        }

        <#
            Custom domain is about the URL of the environment,
            and it needs to be unique across the Power Platform environment landscape,
            so it might require some trial and error to find an available one.
        #>
        if ($CustomDomainName) {
            $config.properties.linkedEnvironmentMetadata | `
                Add-Member -MemberType NoteProperty `
                -Name domainName `
                -Value $CustomDomainName
        }

        <#
            Security group is about restricting access to the environment to only members of a specific Entra Groups security group.
            This is important for controlling who can access the environment, especially in a production scenario.
        #>
        if ($null -ne $SecurityGroupId) {
            $config.properties.linkedEnvironmentMetadata | `
                Add-Member -MemberType NoteProperty `
                -Name securityGroupId `
                -Value $SecurityGroupId
        }
        
        $payload = $config | ConvertTo-Json -Depth 10
        
        # Deploys the shell environment
        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersBapApi `
            -Body $payload `
            -ContentType "application/json" `
            -SkipHttpErrorCheck `
            -StatusCodeVariable 'statusEnv' `
            -Verbose:$false > $null 4>$null

        if ($statusEnv -like "2**") {
            $envProvisioned = $false
            
            do {
                Write-PSFMessage -Level Verbose -Message "Waiting for environment '$Name' to be provisioned..."
                Start-Sleep -Seconds 20
                $envObj = Get-BapEnvironment -EnvironmentId $Name | `
                    Select-Object -First 1

                $envProvisioned = $envObj.State -eq "Ready"
            } until ($envProvisioned -eq $true)

            $appPlatform = Get-PpacD365App `
                -EnvironmentId $Name `
                -Name 'Dynamics 365 Finance and Operations Platform Tools' `
            | Select-Object -First 1

            $headersLocal = @{
                "Authorization" = "Bearer $($tokenPowerApiValue)"
                "Content-Type"  = "application/json"
            }

            # Installing the platform application package
            $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages/{1}/install?api-version=2022-03-01-preview" `
                -f $envObj.PpacEnvId `
                , $appPlatform.PpacPackageName

            Invoke-RestMethod `
                -Method Post `
                -Uri $localUri `
                -Headers $headersLocal `
                -Body "{}" `
                -SkipHttpErrorCheck `
                -StatusCodeVariable 'statusPlat' `
                -Verbose:$false > $null

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

                $appObj = Get-PpacD365App `
                    -EnvironmentId $Name `
                    -Name 'Dynamics 365 Finance and Operations Platform Tools' `
                | Select-Object -First 1

                $appPlatformInstalled = $appObj.Status -eq "Installed"
            } until ($appPlatformInstalled -eq $true)

            <#
                Platform version is 10.0.X for humans, but the application package version is 10.0.X.Y,
                so we need to get the latest available version and find the matching one.
            #>
            $tmpVersion = $Version.ToString().Substring(0, 7)
            $colVersions = Get-PpacD365PlatformUpdate -EnvironmentId $Name
            $deployVersion = $colVersions | Where-Object Platform -eq $tmpVersion

            if ($null -eq $deployVersion) {
                $messageString = "The specified version <c='em'>$Version</c> was not valid for the environment. Please verify the available versions using the <c='em'>Get-PpacD365PlatformUpdate</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "The specified version was not valid for the environment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
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

            <#
                Installing the specified version of the D365 platform
            #>
            Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $headersWebApi `
                -Body $payload `
                -ContentType $headersWebApi."Content-Type" `
                -SkipHttpErrorCheck `
                -StatusCodeVariable 'statusProvision' `
                -Verbose:$false > $null

            if (-not ($statusProvision -like "2**")) {
                $messageString = "Failed to provision the environment with the specified version: <c='em'>$($deployVersion.Version)</c>. Please check the environment and try provisioning manually."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because provisioning the environment with the specified version failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
            
            <#
                First we wait to make sure that the provisioning installation is queued
            #>
            do {
                Write-PSFMessage -Level Verbose -Message "Waiting for provisioning installation to be queued ..."
                Start-Sleep -Seconds 20
                
                $appObj = Get-PpacD365App `
                    -EnvironmentId $Name `
                    -Name 'Dynamics 365 Finance and Operations Provisioning App'
            }while (-not $appObj.StateIsInstalled)
            
            <#
                Then we wait for the provisioning installation to be completed.
                ... If requested by the user ... using the WaitForCompletion
            #>
            while ($WaitForCompletion -and $appObj.Status -ne "Installed") {
                Write-PSFMessage -Level Verbose -Message "Waiting for provisioning installation to be completed ..."
                Start-Sleep -Seconds 20
                
                $appObj = Get-PpacD365App `
                    -EnvironmentId $Name `
                    -Name 'Dynamics 365 Finance and Operations Provisioning App'
            }

            # Output the app details, for the user to see
            $appObj
        }
    }
    
    end {
        
    }
}