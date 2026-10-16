@{
    Resources = @(
        @{
            Noun = 'UnifiedEnvironmentMaintenanceV2'
            Builder = 'Microsoft.PowerPlatform.Management.Dynamics.Environments.Item.Finopsadminsettings.FinopsadminsettingsRequestBuilder'
            ParameterPrefix = 'UpdatedMaintenanceWindow'
            Methods = @{ Get = 'GetAsync'; Set = 'PutAsync' }
            Synopsis = 'Finance and Operations maintenance settings through the bundled Power Platform SDK.'
        }
    )
}
