
<#
    .SYNOPSIS
        Short description
        
    .DESCRIPTION
        Long description
        
    .PARAMETER Name
        Parameter description
        
    .PARAMETER Location
        Parameter description
        
    .PARAMETER Region
        Parameter description
        
    .PARAMETER FnoTemplate
        Parameter description
        
    .PARAMETER NoDemoDb
        Parameter description
        
    .PARAMETER PlatformVersion
        Parameter description
        
    .PARAMETER WaitForCompletion
        Parameter description
        
    .EXAMPLE
        An example
        
    .NOTES
        General notes
#>
function New-UdeEnvironment {
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $CustomDomainName,

        [string] $Location,

        [string] $Region,
        
        [string] $FnoTemplate,

        [switch] $NoDemoDb,

        [version] $Version,

        [string] $SecurityGroupId,

        [switch] $WaitForCompletion
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
            
        do {
            # Get environemnt operation history

        } while ($WaitForCompletion -and $(1 -eq 1))

        # if ($null -eq $resRequest) {
        #     $messageString = "Failed to queue the update/install of FinOps Application version <c='em'>$Version</c> for environment <c='em'>$($envObj.PpacEnvName)</c>. Please verify that the version exists using <c='em'>Get-BapEnvironmentFnOAppUpdate</c> and try again."
        #     Write-PSFMessage -Level Important -Message $messageString
        #     Stop-PSFFunction -Message "Stopping because the update/install could not be queued." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        #     return
        # }

        $resRequest | ConvertTo-Json -Depth 10
    }
    
    end {
        
    }
}