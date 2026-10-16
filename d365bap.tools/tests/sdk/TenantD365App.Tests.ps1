BeforeAll {
    Import-Module "$PSScriptRoot/../../d365bap.tools.psd1" -Force
}

Describe 'Module import scope' {
    It 'preserves caller variables while loading format views' {
        $Name = '*Sales*'
        $moduleRoot = 'caller-value'
        Import-Module "$PSScriptRoot/../../d365bap.tools.psd1" -Force
        $Name | Should -Be '*Sales*'
        $moduleRoot | Should -Be 'caller-value'
    }
}

Describe 'Get-PpacTenantD365App behavior' {
    BeforeEach {
        Mock Get-AzAccessToken -ModuleName d365bap.tools {
            [pscustomobject]@{ Token = [Security.SecureString]::new() }
        }
        Mock Get-BapEnvironment -ModuleName d365bap.tools { throw 'Tenant commands must not resolve an environment.' }
        Mock Invoke-BapSdkRequest -ModuleName d365bap.tools {
            param ($RequestUrl)
            if ($RequestUrl) {
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{ applicationId = '00000000-0000-0000-0000-000000000003'; applicationName = 'Beta'; uniqueName = 'sales_anchor'; publisherName = 'Publisher B' }
                    )
                }
            }
            else {
                [pscustomobject]@{
                    '@odata.nextLink' = 'https://api.powerplatform.com/appmanagement/applicationPackages?continuationToken=next'
                    value = @(
                        [pscustomobject]@{ applicationId = '00000000-0000-0000-0000-000000000002'; applicationName = 'Zebra'; uniqueName = 'zebra_anchor'; publisherName = 'Publisher Z' },
                        [pscustomobject]@{ applicationId = '00000000-0000-0000-0000-000000000001'; applicationName = 'Alpha Sales'; uniqueName = 'alpha_sales'; publisherName = 'Publisher A' }
                    )
                }
            }
        }
    }

    It 'lists and sorts every page without requiring an environment' {
        $command = Get-Command Get-PpacTenantD365App
        $command.Parameters.Keys | Should -Not -Contain 'EnvironmentId'
        $apps = @(Get-PpacTenantD365App)
        $apps.PpacD365AppName | Should -Be @('Alpha Sales', 'Beta', 'Zebra')
        $apps[0].PpacD365AppId | Should -Be '00000000-0000-0000-0000-000000000001'
        $apps[0].Publisher | Should -Be 'Publisher A'
        $apps[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacTenantD365App'
        Should -Invoke Invoke-BapSdkRequest -ModuleName d365bap.tools -Times 1 -Exactly -ParameterFilter {
            $RequestUrl -eq 'https://api.powerplatform.com/appmanagement/applicationPackages?continuationToken=next'
        }
        Should -Invoke Get-BapEnvironment -ModuleName d365bap.tools -Times 0 -Exactly
    }

    It 'filters application names and unique names without duplicating a match' {
        $apps = @(Get-PpacTenantD365App -Name '*sales*')
        $apps.PpacD365AppName | Should -Be @('Alpha Sales', 'Beta')
        @(Get-PpacTenantD365App -Name 'SALES_ANCHOR').PpacD365AppName | Should -Be 'Beta'
    }

    It 'returns no objects when the filter does not match' {
        @(Get-PpacTenantD365App -Name 'missing*').Count | Should -Be 0
    }

    It 'exports only filtered rows into a real Excel workbook' {
        Mock Export-Excel -ModuleName d365bap.tools {
            param ($InputObject, $WorksheetName)
            $InputObject | ImportExcel\Export-Excel -Path "$TestDrive/apps.xlsx" -WorksheetName $WorksheetName -Append
        }
        @(Get-PpacTenantD365App -Name '*sales*' -AsExcelOutput).Count | Should -Be 0
        $rows = @(Import-Excel -Path "$TestDrive/apps.xlsx" -WorksheetName 'Get-PpacTenantD365App')
        $rows.PpacD365AppName | Should -Be @('Alpha Sales', 'Beta')
        $rows.PpacPackageName | Should -Be @('alpha_sales', 'sales_anchor')
    }

    It 'does not export an empty result set' {
        Mock Export-Excel -ModuleName d365bap.tools { throw 'Empty results must not be exported.' }
        @(Get-PpacTenantD365App -Name 'missing*' -AsExcelOutput).Count | Should -Be 0
        Should -Invoke Export-Excel -ModuleName d365bap.tools -Times 0 -Exactly
    }

    It 'rejects a repeated continuation URL' {
        Mock Invoke-BapSdkRequest -ModuleName d365bap.tools {
            [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://api.powerplatform.com/repeated' }
        }
        { Get-PpacTenantD365App } | Should -Throw '*repeated continuation URL*'
    }

    It 'propagates a failed continuation request' {
        Mock Invoke-BapSdkRequest -ModuleName d365bap.tools {
            param ($RequestUrl)
            if ($RequestUrl) { throw 'The second page failed.' }
            [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://api.powerplatform.com/next' }
        }
        { Get-PpacTenantD365App } | Should -Throw '*second page failed*'
    }

    It 'rejects a continuation URL outside the API host before sending a request' {
        {
            [D365Bap.Tools.PowerPlatformSdk.SdkClient]::Execute(
                'Microsoft.PowerPlatform.Management.Appmanagement.ApplicationPackages.ApplicationPackagesRequestBuilder',
                'GetAsync', $null, '2024-10-01', $null, 'test-token', 'https://example.com/next')
        } | Should -Throw '*continuation URL must use the Power Platform API host*'
    }
}
