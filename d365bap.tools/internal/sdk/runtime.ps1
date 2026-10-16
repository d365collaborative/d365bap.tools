function Import-BapSdk {
    [CmdletBinding()]
    param ()

    if ('D365Bap.Tools.PowerPlatformSdk.SdkClient' -as [type]) { return }
    $sdkRoot = Join-Path $script:ModuleRoot 'bin/PowerPlatformSdk'
    $bridge = Join-Path $sdkRoot 'D365Bap.Tools.PowerPlatformSdk.dll'
    if (-not (Test-Path -LiteralPath $bridge)) {
        throw 'The bundled Power Platform SDK is missing. Run build/Build-PowerPlatformSdk.ps1 before importing the source module.'
    }
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $sdkRoot 'Microsoft.Kiota.Abstractions.dll'))
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $sdkRoot 'Microsoft.Kiota.Serialization.Json.dll'))
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $sdkRoot 'Microsoft.Kiota.Http.HttpClientLibrary.dll'))
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $sdkRoot 'Microsoft.PowerPlatform.Management.dll'))
    $null = [Reflection.Assembly]::LoadFrom($bridge)
}

function Get-BapSdkParameter {
    [CmdletBinding()]
    param ($Resource, [string] $Method)

    $builder = $Resource.Builder -as [type]
    $bodyParameter = $builder.GetMethod($Method).GetParameters() |
        Where-Object { $_.Name -eq 'body' }
    if (-not $bodyParameter) { return }
    foreach ($property in $bodyParameter.ParameterType.GetProperties()) {
        if ($property.Name -eq 'AdditionalData') { continue }
        $type = $property.PropertyType
        $collection = $type.IsGenericType -and $type.GetGenericTypeDefinition() -eq [Collections.Generic.List``1]
        if ($collection) { $type = $type.GetGenericArguments()[0] }
        $underlying = [Nullable]::GetUnderlyingType($type)
        if ($underlying) { $type = $underlying }
        if (-not $type.IsEnum) {
            throw "The SDK generator does not yet support request property $($property.Name) of type $type."
        }
        $name = $property.Name
        if ($Resource.ParameterPrefix -and $name.StartsWith($Resource.ParameterPrefix)) {
            $name = $name.Substring($Resource.ParameterPrefix.Length)
        }
        [pscustomobject]@{
            Name = $name
            Property = $property
            Type = $type
            Collection = $collection
            Values = [Enum]::GetNames($type)
            ResponseProperty = $property.Name -replace '^Updated', ''
            BodyType = $bodyParameter.ParameterType
        }
    }
}

function Invoke-BapSdkRequest {
    [CmdletBinding()]
    param ($Resource, [string] $Method, [string] $EnvironmentId, $Body, [string] $Token, [string] $RequestUrl)

    $json = [D365Bap.Tools.PowerPlatformSdk.SdkClient]::Execute(
        $Resource.Builder, $Method, $EnvironmentId, $script:BapSdkApiVersion, $Body, $Token, $RequestUrl)
    if ($json) { $json | ConvertFrom-Json }
}

function Invoke-BapSdkCommand {
    [CmdletBinding()]
    param ([string] $CommandName, [Collections.IDictionary] $BoundParameters)

    $operation = $script:BapSdkCommands[$CommandName]
    $environmentId = $null
    $environmentName = $null
    if ($operation.Resource.Scope -eq 'Environment') {
        $inputEnvironment = $BoundParameters['EnvironmentId']
        if ([guid]::TryParse($inputEnvironment, [ref]([guid]::Empty))) {
            $environmentId = $inputEnvironment
            $environmentName = $inputEnvironment
        }
        else {
            if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($inputEnvironment)) {
                throw 'EnvironmentId must be an exact environment name or GUID.'
            }
            $environments = @(Get-BapEnvironment -EnvironmentId $inputEnvironment -ErrorAction Stop)
            if ($environments.Count -ne 1) {
                throw "Expected one environment named '$inputEnvironment'; found $($environments.Count)."
            }
            $environmentId = $environments[0].PpacEnvId
            $environmentName = $environments[0].EnvName
        }
    }

    $secureToken = (Get-AzAccessToken -ResourceUrl 'https://api.powerplatform.com' -AsSecureString -ErrorAction Stop).Token
    $token = [Net.NetworkCredential]::new('', $secureToken).Password
    $body = $null
    if ($operation.Parameters.Count) {
        $current = Invoke-BapSdkRequest -Resource $operation.Resource -Method $operation.Resource.Methods.Get -EnvironmentId $environmentId -Token $token
        $body = [Activator]::CreateInstance($operation.Parameters[0].BodyType)
        foreach ($parameter in $operation.Parameters) {
            $value = if ($BoundParameters.ContainsKey($parameter.Name)) {
                $BoundParameters[$parameter.Name]
            }
            else {
                $current.($parameter.ResponseProperty)
            }
            if ($null -eq $value) {
                throw "The current value for $($parameter.Name) was absent. Specify it explicitly."
            }
            if ($parameter.Collection) {
                $converted = [Activator]::CreateInstance($parameter.Property.PropertyType)
                foreach ($item in $value) { $converted.Add([Enum]::Parse($parameter.Type, $item, $true)) }
            }
            else {
                $converted = [Enum]::Parse($parameter.Type, $value, $true)
            }
            $parameter.Property.SetValue($body, $converted)
        }
    }
    $request = @{
        Resource = $operation.Resource
        Method = $operation.Method
        EnvironmentId = $environmentId
        Body = $body
        Token = $token
        ErrorAction = 'Stop'
    }
    $result = Invoke-BapSdkRequest @request
    if ($operation.Resource.CollectionProperty) {
        $items = [Collections.Generic.List[object]]::new()
        $visited = [Collections.Generic.HashSet[string]]::new()
        do {
            foreach ($item in $result.($operation.Resource.CollectionProperty)) {
                $items.Add($item)
            }
            $nextLink = $result.($operation.Resource.NextLinkProperty)
            if ($nextLink) {
                if (-not $visited.Add($nextLink)) { throw 'The API returned a repeated continuation URL.' }
                $result = Invoke-BapSdkRequest @request -RequestUrl $nextLink
            }
        } while ($nextLink)

        $name = if ($BoundParameters.ContainsKey('Name')) { $BoundParameters['Name'] } else { '*' }
        $filtered = foreach ($item in $items) {
            foreach ($property in $operation.Resource.FilterProperties) {
                if ($item.$property -like $name -or $item.$property -eq $name) {
                    $item
                    break
                }
            }
        }
        $output = @($filtered | Sort-Object -Property $operation.Resource.SortProperty |
            Select-PSFObject -TypeName $operation.Resource.TypeName -Property $operation.Resource.Properties)
        if ($BoundParameters['AsExcelOutput']) {
            if ($output.Count) {
                $output | Export-Excel -WorksheetName $operation.Resource.WorksheetName
            }
            return
        }
        return $output
    }
    if ($null -ne $result) {
        $result.PSObject.TypeNames.Insert(0, ('D365Bap.Tools.' + $operation.Resource.Noun))
        foreach ($parameter in @(Get-BapSdkParameter -Resource $operation.Resource -Method $operation.Resource.Methods.Set)) {
            $result | Add-Member -NotePropertyName $parameter.Name -NotePropertyValue $result.($parameter.ResponseProperty)
        }
        $result | Add-Member -NotePropertyName EnvironmentId -NotePropertyValue $environmentId
        $result | Add-Member -NotePropertyName EnvironmentName -NotePropertyValue $environmentName
        $result | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $environmentId
        $result | Add-Member -NotePropertyName PpacEnvName -NotePropertyValue $environmentName
        $result
    }
}
