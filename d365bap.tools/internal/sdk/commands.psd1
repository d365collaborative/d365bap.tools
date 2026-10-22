@{
    Resources = @(
        @{
            Noun = 'UnifiedEnvironmentMaintenance'
            Scope = 'Environment'
            Builder = 'Microsoft.PowerPlatform.Management.Dynamics.Environments.Item.Finopsadminsettings.FinopsadminsettingsRequestBuilder'
            ParameterPrefix = 'UpdatedMaintenanceWindow'
            Methods = @{ Get = 'GetAsync'; Set = 'PutAsync' }
            Synopsis = 'Finance and Operations maintenance settings through the bundled Power Platform SDK.'
        }
        @{
            Noun = 'PpacTenantD365App'
            Scope = 'Tenant'
            Builder = 'Microsoft.PowerPlatform.Management.Appmanagement.ApplicationPackages.ApplicationPackagesRequestBuilder'
            Methods = @{ Get = 'GetAsync' }
            Synopsis = 'Get Dynamics 365 applications available in the tenant.'
            CollectionProperty = 'value'
            NextLinkProperty = '@odata.nextLink'
            FilterProperties = @('ApplicationName', 'UniqueName')
            SortProperty = 'ApplicationName'
            TypeName = 'D365Bap.Tools.PpacTenantD365App'
            Properties = @(
                'ApplicationId as PpacD365AppId'
                'ApplicationName as PpacD365AppName'
                'UniqueName as PpacPackageName'
                'PublisherName as Publisher'
                '*'
            )
            WorksheetName = 'Get-PpacTenantD365App'
        }
    )
}
