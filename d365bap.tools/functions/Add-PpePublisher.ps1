
<#
    .SYNOPSIS
        Add a publisher to a Power Platform environment.
        
    .DESCRIPTION
        Creates a new Dataverse publisher (publishers) with the bare minimum of required fields.
        
        The cmdlet is idempotent and works as an upsert keyed on UniqueName. If a publisher
        with the same unique name already exists, it is updated in place with the supplied
        values instead of failing. Only values explicitly supplied by the caller are updated -
        omitted optional values are left untouched on existing publishers.
        
        Requires the unique name, display name, customization prefix and option value prefix. The option value prefix defaults to a random value between 10000 and 99999 when omitted on create. It is left untouched on update when omitted.
        
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
        
    .PARAMETER EmailAddress
        An optional email address for the publisher.
        
    .PARAMETER SupportingWebsiteUrl
        An optional supporting website URL for the publisher.
        
    .PARAMETER AddressLine1
        An optional first street line for address 1.
        
    .PARAMETER AddressLine2
        An optional second street line for address 1.
        
    .PARAMETER AddressLine3
        An optional third street line for address 1.
        
    .PARAMETER AddressCity
        An optional city for address 1.
        
    .PARAMETER AddressStateOrProvince
        An optional state or province for address 1.
        
    .PARAMETER AddressPostalCode
        An optional ZIP / postal code for address 1.
        
    .PARAMETER AddressCountry
        An optional country / region for address 1.
        
    .PARAMETER AddressPhone
        An optional phone number for address 1.
        
    .EXAMPLE
        PS C:\> Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont"
        
        This will create the "Contoso" publisher with the prefix "cont" and a random option value prefix.
        
    .EXAMPLE
        PS C:\> Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont" -OptionValuePrefix 12345 -Description "Contoso publisher"
        
        This will create the "Contoso" publisher with full details.
        
    .EXAMPLE
        PS C:\> Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont" -AddressLine1 "One Microsoft Way" -AddressCity "Redmond" -AddressCountry "USA" -EmailAddress "publisher@contoso.com"
        
        This will update the existing "contoso" publisher with address details if it already exists, or create it with address details if it does not exist.
        
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

        [string] $Description,

        [string] $EmailAddress,

        [Alias('Website')]
        [string] $SupportingWebsiteUrl,

        [string] $AddressLine1,

        [string] $AddressLine2,

        [string] $AddressLine3,

        [string] $AddressCity,

        [string] $AddressStateOrProvince,

        [string] $AddressPostalCode,

        [string] $AddressCountry,

        [Alias('Phone', 'Telephone1')]
        [string] $AddressPhone
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
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $existingPublisher = Get-PpePublisher `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $UniqueName | `
            Where-Object { $_.SystemName -eq $UniqueName -or $_.PpePublisherId -eq $UniqueName } | `
            Select-Object -First 1

        if ($null -ne $existingPublisher) {
            # Idempotent upsert: update the existing publisher in place with explicitly supplied values.
            # Note: PSBoundParameters keys are checked with aliases included, as callers may use them.
            $updatePayload = [ordered]@{}

            if ($PSBoundParameters.ContainsKey('FriendlyName') -or $PSBoundParameters.ContainsKey('DisplayName')) { $updatePayload.friendlyname = $FriendlyName }
            # Prefix and option value prefix are only sent when they actually differ - they are
            # effectively immutable after create and re-sending them can trigger server-side
            # recalculation of the option value prefix.
            if ($PSBoundParameters.ContainsKey('Prefix') -or $PSBoundParameters.ContainsKey('CustomizationPrefix')) {
                if ("$($existingPublisher.customizationprefix)" -ne "$Prefix") { $updatePayload.customizationprefix = $Prefix }
            }
            if ($PSBoundParameters.ContainsKey('OptionValuePrefix') -or $PSBoundParameters.ContainsKey('CustomizationOptionValuePrefix')) {
                if ("$($existingPublisher.customizationoptionvalueprefix)" -ne "$OptionValuePrefix") { $updatePayload.customizationoptionvalueprefix = $OptionValuePrefix }
            }
            if ($PSBoundParameters.ContainsKey('Description')) { $updatePayload.description = $Description }
            if ($PSBoundParameters.ContainsKey('EmailAddress')) { $updatePayload.emailaddress = $EmailAddress }
            if ($PSBoundParameters.ContainsKey('SupportingWebsiteUrl') -or $PSBoundParameters.ContainsKey('Website')) { $updatePayload.supportingwebsiteurl = $SupportingWebsiteUrl }
            if ($PSBoundParameters.ContainsKey('AddressLine1')) { $updatePayload.address1_line1 = $AddressLine1 }
            if ($PSBoundParameters.ContainsKey('AddressLine2')) { $updatePayload.address1_line2 = $AddressLine2 }
            if ($PSBoundParameters.ContainsKey('AddressLine3')) { $updatePayload.address1_line3 = $AddressLine3 }
            if ($PSBoundParameters.ContainsKey('AddressCity')) { $updatePayload.address1_city = $AddressCity }
            if ($PSBoundParameters.ContainsKey('AddressStateOrProvince')) { $updatePayload.address1_stateorprovince = $AddressStateOrProvince }
            if ($PSBoundParameters.ContainsKey('AddressPostalCode')) { $updatePayload.address1_postalcode = $AddressPostalCode }
            if ($PSBoundParameters.ContainsKey('AddressCountry')) { $updatePayload.address1_country = $AddressCountry }
            if ($PSBoundParameters.ContainsKey('AddressPhone') -or $PSBoundParameters.ContainsKey('Phone') -or $PSBoundParameters.ContainsKey('Telephone1')) { $updatePayload.address1_telephone1 = $AddressPhone }

            if ($updatePayload.Count -eq 0) {
                Write-PSFMessage -Level Verbose -Message "The publisher: $UniqueName already exists and no updatable values were supplied. Returning the existing publisher."
                return $existingPublisher
            }

            $isDifferent = $false
            foreach ($key in @($updatePayload.Keys)) {
                $desiredValue = $updatePayload[$key]
                $currentValue = $existingPublisher.$key

                if ($null -eq $desiredValue -and $null -eq $currentValue) { continue }
                if ([string]::IsNullOrEmpty($desiredValue) -and [string]::IsNullOrEmpty($currentValue)) { continue }
                if ("$currentValue" -ne "$desiredValue") {
                    $isDifferent = $true
                    break
                }
            }

            if (-not $isDifferent) {
                Write-PSFMessage -Level Verbose -Message "The publisher: $UniqueName already exists with the supplied values. Returning the existing publisher."
                return $existingPublisher
            }

            Write-PSFMessage -Level Verbose -Message "The publisher: $UniqueName already exists. Updating it with the supplied values."

            Invoke-RestMethod -Method Patch `
                -Uri $($baseUri + "/api/data/v9.2/publishers($($existingPublisher.PpePublisherId))") `
                -Headers $headersWebApi `
                -ContentType "application/json" `
                -Body $($updatePayload | ConvertTo-Json -Depth 10) `
                -StatusCodeVariable statusUpdate > $null 4> $null

            if (-not ($statusUpdate -like "2*")) {
                $messageString = "Failed to update the publisher: <c='em'>$UniqueName</c> in the Power Platform environment. HTTP status: <c='em'>$statusUpdate</c>. Please try updating the publisher manually via the Power Platform maker portal - <c='em'>https://make.powerapps.com</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because updating the publisher failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            Get-PpePublisher `
                -EnvironmentId $envObj.PpacEnvId `
                -Name $existingPublisher.PpePublisherId

            return
        }

        if (-not ($PSBoundParameters.ContainsKey('OptionValuePrefix') -or $PSBoundParameters.ContainsKey('CustomizationOptionValuePrefix'))) {
            $OptionValuePrefix = Get-Random -Minimum 10000 -Maximum 99999
        }

        $payload = [ordered]@{
            uniquename                      = $UniqueName
            friendlyname                    = $FriendlyName
            customizationprefix             = $Prefix
            customizationoptionvalueprefix  = $OptionValuePrefix
        }

        if ($PSBoundParameters.ContainsKey('Description')) { $payload.description = $Description }
        if ($PSBoundParameters.ContainsKey('EmailAddress')) { $payload.emailaddress = $EmailAddress }
        if ($PSBoundParameters.ContainsKey('SupportingWebsiteUrl') -or $PSBoundParameters.ContainsKey('Website')) { $payload.supportingwebsiteurl = $SupportingWebsiteUrl }
        if ($PSBoundParameters.ContainsKey('AddressLine1')) { $payload.address1_line1 = $AddressLine1 }
        if ($PSBoundParameters.ContainsKey('AddressLine2')) { $payload.address1_line2 = $AddressLine2 }
        if ($PSBoundParameters.ContainsKey('AddressLine3')) { $payload.address1_line3 = $AddressLine3 }
        if ($PSBoundParameters.ContainsKey('AddressCity')) { $payload.address1_city = $AddressCity }
        if ($PSBoundParameters.ContainsKey('AddressStateOrProvince')) { $payload.address1_stateorprovince = $AddressStateOrProvince }
        if ($PSBoundParameters.ContainsKey('AddressPostalCode')) { $payload.address1_postalcode = $AddressPostalCode }
        if ($PSBoundParameters.ContainsKey('AddressCountry')) { $payload.address1_country = $AddressCountry }
        if ($PSBoundParameters.ContainsKey('AddressPhone') -or $PSBoundParameters.ContainsKey('Phone') -or $PSBoundParameters.ContainsKey('Telephone1')) { $payload.address1_telephone1 = $AddressPhone }

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
