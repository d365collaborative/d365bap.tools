
<#
    .SYNOPSIS
        Get Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Retrieves information about Unified Environments in Power Platform Admin Center (PPAC).
        
        Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve.
        
        Supports wildcard patterns.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER SkipVersionDetails
        Instructs the function to skip retrieving version details.
        
        Will result in faster execution, but will not include version information and tell you if the environment is UDE or USE.
        
    .PARAMETER UdeOnly
        Instructs the function to only return UDE environments.
        
    .PARAMETER UseOnly
        Instructs the function to only return USE environments.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment
        
        This will retrieve all available UDE/USE/UPE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -EnvironmentId "env-123"
        
        This will retrieve the UDE/USE/UPE environment with the specified environment ID.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -SkipVersionDetails
        
        This will retrieve all available UDE/USE/UPE environments without version details.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UdeOnly
        
        This will retrieve only UDE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UseOnly
        
        This will retrieve only USE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -AsExcelOutput
        
        This will export the retrieved UDE/USE/UPE environments to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironment {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType('System.Object[]')]
    param (
        [Parameter()]
        [string] $EnvironmentId = "*",

        [Parameter(ParameterSetName = "SkipVersion")]
        [switch] $SkipVersionDetails,

        [Parameter(ParameterSetName = "UdeOnly")]
        [switch] $UdeOnly,
        
        [Parameter(ParameterSetName = "UseOnly")]
        [switch] $UseOnly,

        [Parameter()]
        [switch] $AsExcelOutput
    )

    begin {
        $colEnv = Get-BapEnvironment -EnvironmentId $EnvironmentId `
            -FscmEnabled

        $searchById = Test-Guid -InputObject $EnvironmentId

        $currentProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    
    process {
        $filteredEnvs = $colEnv | Where-Object FinOpsMetadataEnvType -eq "Internal"

        # ForEach-Object -Parallel runs in isolated runspaces that do not
        # inherit module functions (Get-BapAccessToken and
        # Get-BapEnvironmentD365App are unavailable there). Mint all tokens
        # up-front and pass plain-text values via $using:.
        $dataverseTokenMap = @{}
        $tokenPowerApiValue = $null
        $tokenAdminApiValue = $null
        $tenantId = $null

        if (-not $SkipVersionDetails -and @($filteredEnvs).Count -gt 0) {
            $tenantId = (Get-BapContext).TenantId

            $secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
            $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

            $secureTokenAdminApi = Get-BapAccessToken -ResourceUrl "065d9450-1e87-434e-ac2f-69af271549ed"
            $tokenAdminApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenAdminApi

            $distinctUris = @($filteredEnvs |
                Select-Object -ExpandProperty PpacEnvUri -Unique |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

            foreach ($uri in $distinctUris) {
                $secure = Get-BapAccessToken -ResourceUrl $uri
                $dataverseTokenMap[$uri] = ConvertFrom-SecureString -AsPlainText -SecureString $secure
            }
        }

        $resCol = $filteredEnvs | ForEach-Object -Parallel {
            $envObj = $_
            $localTokenMap = $using:dataverseTokenMap
            $localPowerToken = $using:tokenPowerApiValue
            $localAdminToken = $using:tokenAdminApiValue
            $localTenantId = $using:tenantId

            if ($using:searchById) {
                if (-not ($envObj.PpacEnvId -like $using:EnvironmentId)) { continue }
            }
            else {
                if (-not ($envObj.PpacEnvName -like $using:EnvironmentId)) { continue }
            }

            if ($using:SkipVersionDetails) {
                $envObj

                continue
            }

            Import-Module PSFramework -ErrorAction SilentlyContinue

            # Version details come from the Web API function msprov_getfinopsapplicationdetails
            $baseUri = $envObj.PpacEnvUri
            $tokenWebApiValue = $localTokenMap[$baseUri]

            $headersApi = @{
                Authorization      = "Bearer $($tokenWebApiValue)"
                Accept             = "application/json"
                "OData-MaxVersion" = "4.0"
                "OData-Version"    = "4.0"
            }

            $Response = $null

            try {
                $Response = Invoke-RestMethod `
                    -Uri "$($baseUri.TrimEnd('/'))/api/data/v9.2/msprov_getfinopsapplicationdetails()" `
                    -Method Get `
                    -Headers $headersApi
            }
            catch {
                $Response = $null
            }

            if ($null -eq $Response) {
                $messageString = "Could not obtain the <c='em'>Ppac Provision</c> details for <c='em'>$($envObj.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center (PPAC)."
                Write-PSFMessage -Level Important -Message $messageString
                Write-PSFHostColor -String "- <c='em'>https://admin.powerplatform.microsoft.com/environments/environment/$($envObj.PpacEnvId)/hub</c>"
            }
            else {
                $envObj | Add-Member -NotePropertyName "ProvisioningAppVersion" -NotePropertyValue $Response.applicationversion
                $envObj | Add-Member -NotePropertyName "ProvisioningPlatVersion" -NotePropertyValue $Response.platformversion
                $envObj | Add-Member -NotePropertyName "ProvisioningState" -NotePropertyValue $Response.finopsenvironmentstate
                $envObj | Add-Member -NotePropertyName "ProvisioningType" -NotePropertyValue $Response.applicationdeploymenttype
            }

            # User friendly version from the installed provisioning anchor app.
            # Inlined here (instead of Get-BapEnvironmentD365App) because
            # module functions are unavailable in -Parallel runspaces.
            $finOpsAppVersion = $null

            try {
                $headersPowerApi = @{
                    "Authorization" = "Bearer $($localPowerToken)"
                }

                $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages?appInstallState=All&api-version=2024-10-01" `
                    -f $envObj.PpacEnvId

                $appsAvailable = @()

                do {
                    $responsePage = Invoke-RestMethod `
                        -Method Get `
                        -Uri $localUri `
                        -Headers $headersPowerApi

                    $appsAvailable += $responsePage.value
                    $localUri = $responsePage.'@odata.nextLink'
                } while (-not [string]::IsNullOrEmpty($localUri))

                $anchorAvailable = @($appsAvailable |
                    Where-Object UniqueName -eq 'msdyn_FinanceAndOperationsProvisioningAppAnchor') |
                    Select-Object -First 1

                if ($null -ne $anchorAvailable) {
                    $uriSourceEncoded = [System.Web.HttpUtility]::UrlEncode($envObj.LinkedMetaPpacEnvUri)

                    $headersAdminApi = @{
                        "Authorization" = "Bearer $($localAdminToken)"
                    }

                    $appsEnvironment = Invoke-RestMethod `
                        -Method Get `
                        -Uri "https://api.admin.powerplatform.microsoft.com/api/AppManagement/InstancePackages/instanceId/$($localTenantId)?instanceUrl=$uriSourceEncoded&geoType=Emea" `
                        -Headers $headersAdminApi

                    $currentApp = @($appsEnvironment |
                        Where-Object ApplicationId -eq $anchorAvailable.ApplicationId) |
                        Select-Object -First 1

                    if ($null -ne $currentApp) {
                        $finOpsAppVersion = $currentApp.Version
                    }
                }
            }
            catch {
                $finOpsAppVersion = $null
            }

            $envObj | Add-Member -NotePropertyName "FinOpsApp" -NotePropertyValue $finOpsAppVersion

            $envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
                -ExcludeProperty EnvType `
                -Property "ProvisioningAppVersion as PpacProvApp",
            "ProvisioningPlatVersion as PpacProvPlatform",
            "ProvisioningState as PpacProvState",
            "ProvisioningType as PpacProvType",
            @{Name = "EnvType"; Expression = {
                    switch ($_.ProvisioningType) {
                        "OnlineDev" { "UDE" }
                        "Sandbox" { "USE" }
                        Default { "N/A" }
                    }
                }
            },
            *
        }

        if ($UdeOnly) {
            $resCol = $resCol | Where-Object EnvType -eq "UDE"
        }
        elseif ($UseOnly) {
            $resCol = $resCol | Where-Object EnvType -eq "USE"
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel `
                -WorksheetName "Get-UnifiedEnvironment" `
                -NoNumberConversion FinOpsApp,PpacProvApp,PpacProvPlatform,ProvisioningAppVersion,ProvisioningPlatVersion
            return
        }

        $resCol
    }
    
    end {
        $ProgressPreference = $currentProgress
    }
}