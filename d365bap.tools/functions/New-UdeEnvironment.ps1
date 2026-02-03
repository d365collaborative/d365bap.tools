
<#
    .SYNOPSIS
        Deploy a new Unified Developer Environment (UDE) in Power Platform
        
    .DESCRIPTION
        Deploys a new Unified Developer Environment (UDE) in Power Platform using specified parameters such as name, location, template, and version.
        
    .PARAMETER Name
        Name of the new UDE environment as it will be displayed in Power Platform Admin Center.
        
    .PARAMETER CustomDomainName
        The custom domain name to be associated with the new environment.
        
        E.g. "demo-time" will create the environment URLs:
        - "https://demo-time.crmX.dynamics.com".
        - "https://demo-time.operations.eu.dynamics.com"
        
    .PARAMETER Location
        The deployment location for the new environment.
        
        This translates to the Power Platform location where the environment will be created.
        
        Data residency and compliance requirements should be considered when selecting the location.
        
        Get-BapDeployLocation can be used to find available locations.
        
    .PARAMETER Region
        The Azure region for the new environment.
        
        It specifies the physical location of the data center where the environment will be hosted.
        
        Get-BapDeployLocation | Format-List can be used to find possible regions.
        
    .PARAMETER FnoTemplate
        The deployment template to use for creating the UDE.
        
        Get-BapDeployTemplate can be used to find available templates.
        
    .PARAMETER NoDemoDb
        Instructs the cmdlet to create the environment without a demo database.
        
    .PARAMETER Version
        The version of the Finance and Operations application to be installed in the new environment.
        
    .PARAMETER SecurityGroupId
        Entra Groups security group ID to restrict access to the new environment.
        
    .EXAMPLE
        PS C:\> New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance
        
        This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
        It will include a demo database by default.
        It will get a default domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        
    .EXAMPLE
        PS C:\> New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -Region WestEurope -FnoTemplate D365_FinOps_Finance
        
        This will create a new UDE environment named "MyUdeEnv" in the "Europe" location and "WestEurope" region using the specified Finance and Operations template.
        It will include a demo database by default.
        It will get a default domain name assigned by Power Platform.
        It will take the latest available version of Finance and Operations.
        
    .EXAMPLE
        PS C:\> New-UdeEnvironment -Name "MyUdeEnv" -CustomDomainName "my-ude-env" -Location "Europe" -FnoTemplate D365_FinOps_Finance
        
        This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
        It will include a demo database by default.
        It will get the custom domain name "my-ude-env".
        It will take the latest available version of Finance and Operations.
        
    .EXAMPLE
        PS C:\> New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance -NoDemoDb -Version 10.0.45.7
        
        This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
        It will NOT include a demo database.
        It will get a default domain name assigned by Power Platform.
        It will install Finance and Operations application version 10.0.45.7.
        
    .EXAMPLE
        PS C:\> New-UdeEnvironment -Name "MyUdeEnv" -Location "Europe" -FnoTemplate D365_FinOps_Finance -SecurityGroupId "12345678-90ab-cdef-1234-567890abcdef"
        
        This will create a new UDE environment named "MyUdeEnv" in the "Europe" location using the specified Finance and Operations template.
        It will include a demo database by default.
        It will get a default domain name assigned by Power Platform.
        It will restrict access to the environment to members of the specified Entra Groups security group.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function New-UdeEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $CustomDomainName,

        [string] $Location,

        [string] $Region,
        
        [string] $FnoTemplate,

        [switch] $NoDemoDb,

        [version] $Version,

        [string] $SecurityGroupId
        
        # ,        [switch] $WaitForCompletion
    )
    
    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
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
                environmentSku            = "Sandbox" # UDE - Can only be Sandbox
                linkedEnvironmentMetadata = [PsCustomObject][ordered]@{
                    baseLanguage     = "" # Maybe it selects the TenantDefault
                    currency         = $null # Maybe it selects the TenantDefault
                    templateMetadata = [PsCustomObject][ordered]@{
                        PostProvisioningPackages = [PsCustomObject]@([PsCustomObject][ordered]@{
                                applicationUniqueName = "msdyn_FinanceAndOperationsProvisioningAppAnchor"
                                parameters            = "DevToolsEnabled=true|DemoDataEnabled=$(-not $NoDemoDb)"
                            })
                    }
                    templates        = @("$FnoTemplate")
                }
            }
        }
        
        if ($Region) {
            $config.properties | `
                Add-Member -MemberType NoteProperty `
                -Name azureRegion `
                -Value $Region
        }

        if ($Version) {
            $config.properties.linkedEnvironmentMetadata.templateMetadata.PostProvisioningPackages[0].parameters += "|ApplicationVersion=$Version"
        }

        if ($CustomDomainName) {
            $config.properties.linkedEnvironmentMetadata | `
                Add-Member -MemberType NoteProperty `
                -Name domainName `
                -Value $CustomDomainName
        }

        if ($SecurityGroupId) {
            $config.properties.linkedEnvironmentMetadata | `
                Add-Member -MemberType NoteProperty `
                -Name securityGroupId `
                -Value $SecurityGroupId
        }
        
        $payload = $config | ConvertTo-Json -Depth 10

        $resRequest = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersBapApi `
            -Body $payload `
            -ContentType "application/json" `
            -SkipHttpErrorCheck
            
        $resRequest
        
        # do {
        #     # Get environemnt operation history

        # } while ($WaitForCompletion -and $(1 -eq 1))

        # # if ($null -eq $resRequest) {
        # #     $messageString = "Failed to queue the update/install of FinOps Application version <c='em'>$Version</c> for environment <c='em'>$($envObj.PpacEnvName)</c>. Please verify that the version exists using <c='em'>Get-BapEnvironmentFnOAppUpdate</c> and try again."
        # #     Write-PSFMessage -Level Important -Message $messageString
        # #     Stop-PSFFunction -Message "Stopping because the update/install could not be queued." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        # #     return
        # # }

        # $resRequest | ConvertTo-Json -Depth 10
    }
    
    end {
        
    }
}