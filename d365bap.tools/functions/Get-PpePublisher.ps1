
<#
    .SYNOPSIS
        Get publishers from Power Platform environment.
        
    .DESCRIPTION
        Enables the user to query against the publishers from the Power Platform environment.
        
        All raw properties returned from the API are kept on the output objects, with friendly aliases (Name, SystemName, Prefix, OptionValuePrefix, Description, EmailAddress, SupportingWebsiteUrl and the Address* details) wired on top - the same pattern used by Get-BapEnvironment.
        
        The default table and list views only show a curated subset of properties. Use -AsExcelOutput to export all details, or Format-List * to inspect every property.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Name
        The name of the publisher that you are looking for.
        
        The parameter supports wildcards, but will resolve them into a strategy that matches best practice from Microsoft documentation.
        
        It means that you can only have a single search phrase. E.g.
        * -Name "*Retail"
        * -Name "Retail*"
        * -Name "*Retail*"
        
        It will search in both friendly name, unique name and id of the publisher.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state.
        
    .EXAMPLE
        PS C:\> Get-PpePublisher -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all publishers from the environment.
        
    .EXAMPLE
        PS C:\> Get-PpePublisher -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*contoso*"
        
        This will fetch publishers with "contoso" in their name from the environment.
        
    .EXAMPLE
        PS C:\> Get-PpePublisher -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will fetch all publishers from the environment.
        It will then output the results directly into an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpePublisher {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }
        
        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
     
        $localUri = $baseUri + "/api/data/v9.2/publishers"

        $colPublishersRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colPublishers = $colPublishersRaw | Where-Object {
            ($_.friendlyname -like $Name -or $_.friendlyname -eq $Name) `
                -or ($_.uniquename -like $Name -or $_.uniquename -eq $Name) `
                -or ($_.publisherid -like $Name -or $_.publisherid -eq $Name) `
                -or ($_.customizationprefix -like $Name -or $_.customizationprefix -eq $Name)
        } | Sort-Object -Property friendlyname

        $resCol = @(
            $colPublishers | Select-PSFObject -TypeName "D365Bap.Tools.PpePublisher" `
                -ExcludeProperty publisherid, isreadonly, description, emailaddress, supportingwebsiteurl, address1_line1, address1_line2, address1_line3, address1_city, address1_stateorprovince, address1_postalcode, address1_country, address1_telephone1 `
                -Property "publisherid as PpePublisherId",
            "friendlyname as Name",
            "uniquename as SystemName",
            "customizationprefix as Prefix",
            "customizationoptionvalueprefix as OptionValuePrefix",
            "isreadonly as IsReadOnly",
            "description as Description",
            "emailaddress as EmailAddress",
            "supportingwebsiteurl as SupportingWebsiteUrl",
            "address1_line1 as AddressLine1",
            "address1_line2 as AddressLine2",
            "address1_line3 as AddressLine3",
            "address1_city as AddressCity",
            "address1_stateorprovince as AddressStateOrProvince",
            "address1_postalcode as AddressPostalCode",
            "address1_country as AddressCountry",
            "address1_telephone1 as AddressPhone",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpePublisher"
            return
        }

        $resCol
    }
    
    end {
        
    }
}
