
<#
    .SYNOPSIS
        Add a solution to a Power Platform environment.
        
    .DESCRIPTION
        Creates a new unmanaged Dataverse solution (solutions) with the bare minimum of required fields.
        
        The cmdlet is idempotent and works as an upsert keyed on SystemName. If a solution with
        the same unique name already exists, it is updated in place with the supplied values
        instead of failing. Only values explicitly supplied by the caller are updated -
        omitted optional values are left untouched on existing solutions.
        
        The publisher is resolved by unique name, friendly name, prefix or id using Get-PpePublisher.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Publisher
        The publisher that the solution belongs to.
        
        Can be either the publisher unique name, friendly name, prefix or id. Use Get-PpePublisher to list available publishers.
        
    .PARAMETER Name
        The display / friendly name of the solution.
        
    .PARAMETER SystemName
        The unique name of the solution. Must be unique across the environment.
        
    .PARAMETER Version
        The initial version of the solution. Defaults to "1.0.0.0".
        
    .PARAMETER Description
        An optional description of the solution.
        
    .EXAMPLE
        PS C:\> Add-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Publisher "contoso" -Name "Contoso Tools" -SystemName "contoso_tools"
        
        This will create the "Contoso Tools" solution with version 1.0.0.0 for the "contoso" publisher.
        
    .EXAMPLE
        PS C:\> Add-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Publisher "contoso" -Name "Contoso Tools" -SystemName "contoso_tools" -Version "1.0.0.0" -Description "Contoso tools solution"
        
        This will create the "Contoso Tools" solution with full details.
        
    .EXAMPLE
        PS C:\> Add-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Publisher "contoso" -Name "Contoso Tools Updated" -SystemName "contoso_tools"
        
        This will update the existing "contoso_tools" solution with the new display name if it already exists, or create it if it does not exist.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpeSolution {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $Publisher,

        [Parameter (Mandatory = $true)]
        [Alias('DisplayName', 'FriendlyName')]
        [string] $Name,

        [Parameter (Mandatory = $true)]
        [Alias('UniqueName')]
        [string] $SystemName,

        [string] $Version,

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

        $publisherObj = Get-PpePublisher `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Publisher | `
            Select-Object -First 1

        if ($null -eq $publisherObj) {
            $messageString = "The supplied Publisher: <c='em'>$Publisher</c> didn't return any matching publisher in the Power Platform environment. Please verify that the publisher is correct - try running the <c='em'>Get-PpePublisher</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because publisher was NOT found based on the name / id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $existingSolution = Get-PpeSolution `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $SystemName | `
            Where-Object { $_.SystemName -eq $SystemName } | `
            Select-Object -First 1

        if ($null -ne $existingSolution) {
            # Idempotent upsert: update the existing solution in place with explicitly supplied values.
            $updatePayload = [ordered]@{}

            if ($PSBoundParameters.ContainsKey('Name') -or $PSBoundParameters.ContainsKey('DisplayName') -or $PSBoundParameters.ContainsKey('FriendlyName')) {
                if ("$($existingSolution.Name)" -ne "$Name") { $updatePayload.friendlyname = $Name }
            }
            if ($PSBoundParameters.ContainsKey('Version')) {
                if ("$($existingSolution.Version)" -ne "$Version") { $updatePayload.version = $Version }
            }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $existingDesc = if ($existingSolution.PSObject.Properties['description']) { "$($existingSolution.description)" } else { "" }
                if ($existingDesc -ne "$Description") { $updatePayload.description = $Description }
            }
            if ($PSBoundParameters.ContainsKey('Publisher')) {
                $desiredPublisherId = $publisherObj.PpePublisherId
                $currentPublisherId = "$($existingSolution._publisherid_value)"
                if ($currentPublisherId -ne $desiredPublisherId) {
                    $updatePayload."publisherid@odata.bind" = "/publishers($desiredPublisherId)"
                }
            }

            if ($updatePayload.Count -eq 0) {
                Write-PSFMessage -Level Verbose -Message "The solution: $SystemName already exists with the supplied values. Returning the existing solution."
                return $existingSolution
            }

            Write-PSFMessage -Level Verbose -Message "The solution: $SystemName already exists. Updating it with the supplied values."

            Invoke-RestMethod -Method Patch `
                -Uri $($baseUri + "/api/data/v9.2/solutions($($existingSolution.PpeSolutionId))") `
                -Headers $headersWebApi `
                -ContentType "application/json" `
                -Body $($updatePayload | ConvertTo-Json -Depth 10) `
                -StatusCodeVariable statusUpdate > $null 4> $null

            if (-not ($statusUpdate -like "2*")) {
                $messageString = "Failed to update the solution: <c='em'>$SystemName</c> in the Power Platform environment. HTTP status: <c='em'>$statusUpdate</c>. Please try updating the solution manually via the Power Platform maker portal - <c='em'>https://make.powerapps.com</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because updating the solution failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            Get-PpeSolution `
                -EnvironmentId $envObj.PpacEnvId `
                -Name $existingSolution.PpeSolutionId

            return
        }

        $effectiveVersion = if ($PSBoundParameters.ContainsKey('Version')) { $Version } else { "1.0.0.0" }

        $payload = [ordered]@{
            uniquename                 = $SystemName
            friendlyname               = $Name
            version                    = $effectiveVersion
            "publisherid@odata.bind"   = "/publishers($($publisherObj.PpePublisherId))"
        }

        if ($PSBoundParameters.ContainsKey('Description')) { $payload.description = $Description }

        Invoke-RestMethod -Method Post `
            -Uri $($baseUri + "/api/data/v9.2/solutions") `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $($payload | ConvertTo-Json -Depth 10) `
            -ResponseHeadersVariable responseHeaders `
            -StatusCodeVariable statusSolution > $null 4> $null

        if (-not ($statusSolution -like "2*")) {
            $messageString = "Failed to create the solution: <c='em'>$SystemName</c> in the Power Platform environment. Please try creating the solution manually via the Power Platform maker portal - <c='em'>https://make.powerapps.com</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because creating the solution failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $newSolutionId = [regex]::Match("$($responseHeaders.'OData-EntityId')", '\(([0-9a-fA-F-]{36})\)').Groups[1].Value

        Get-PpeSolution `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $newSolutionId
    }
    
    end {
        
    }
}
