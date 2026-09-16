
<#
    .SYNOPSIS
        Add a publisher to a Power Platform environment.
        
    .DESCRIPTION
        Creates a new Dataverse publisher (publishers) with the bare minimum of required fields.
        
        Requires the unique name, display name, customization prefix and option value prefix. The option value prefix defaults to a random value between 10000 and 99999 when omitted.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER UniqueName
        The unique name of the publisher. Must be unique across the environment.
        
    .PARAMETER FriendlyName
        The display / friendly name of the publisher.
        
    .PARAMETER Prefix
        The customization prefix used for new entities, attributes and relationships for solutions associated with this publisher.
        
    .PARAMETER OptionValuePrefix
        The default option value prefix used for newly created options for solutions associated with this publisher.
        
        Must be between 10000 and 99999. Defaults to a random value in that range when omitted.
        
    .PARAMETER Description
        An optional description of the publisher.
        
    .EXAMPLE
        PS C:\> Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont"
        
        This will create the "Contoso" publisher with the prefix "cont" and a random option value prefix.
        
    .EXAMPLE
        PS C:\> Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont" -OptionValuePrefix 12345 -Description "Contoso publisher"
        
        This will create the "Contoso" publisher with full details.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpePublisher {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $UniqueName,

        [Parameter (Mandatory = $true)]
        [Alias('DisplayName')]
        [string] $FriendlyName,

        [Parameter (Mandatory = $true)]
        [Alias('CustomizationPrefix')]
        [string] $Prefix,

        [Alias('CustomizationOptionValuePrefix')]
        [ValidateRange(10000, 99999)]
        [int] $OptionValuePrefix,

        [string] $Description
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }

        if (-not $PSBoundParameters.ContainsKey('OptionValuePrefix')) {
            $OptionValuePrefix = Get-Random -Minimum 10000 -Maximum 99999
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $existingPublisher = Get-PpePublisher `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $UniqueName | `
            Where-Object { $_.SystemName -eq $UniqueName -or $_.PpePublisherId -eq $UniqueName } | `
            Select-Object -First 1

        if ($null -ne $existingPublisher) {
            $messageString = "The supplied UniqueName: <c='em'>$UniqueName</c> is already a publisher in the Power Platform environment. Please verify that the name is correct - try running the <c='em'>Get-PpePublisher</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because a publisher with the same unique name already exists." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $payload = [ordered]@{
            uniquename                      = $UniqueName
            friendlyname                    = $FriendlyName
            customizationprefix             = $Prefix
            customizationoptionvalueprefix  = $OptionValuePrefix
        }

        if (-not [string]::IsNullOrEmpty($Description)) { $payload.description = $Description }

        Invoke-RestMethod -Method Post `
            -Uri $($baseUri + "/api/data/v9.2/publishers") `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $($payload | ConvertTo-Json -Depth 10) `
            -ResponseHeadersVariable responseHeaders `
            -StatusCodeVariable statusPublisher > $null 4> $null

        if (-not ($statusPublisher -like "2*")) {
            $messageString = "Failed to create the publisher: <c='em'>$UniqueName</c> in the Power Platform environment. Please try creating the publisher manually via the Power Platform maker portal - <c='em'>https://make.powerapps.com</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because creating the publisher failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $newPublisherId = [regex]::Match("$($responseHeaders.'OData-EntityId')", '\(([0-9a-fA-F-]{36})\)').Groups[1].Value

        Get-PpePublisher `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $newPublisherId
    }
    
    end {
        
    }
}
