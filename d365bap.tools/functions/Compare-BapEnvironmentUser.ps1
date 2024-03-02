
<#
    .SYNOPSIS
        Compare the environment users
        
    .DESCRIPTION
        This enables the user to compare 2 x environments, with one as a source and the other as a destination
        
        It will only look for users on the source, and use this as a baseline against the destination
        
    .PARAMETER SourceEnvironmentId
        Environment Id of the source environment that you want to utilized as the baseline for the compare
        
    .PARAMETER DestinationEnvironmentId
        Environment Id of the destination environment that you want to validate against the baseline (source)
        
    .PARAMETER ShowDiffOnly
        Instruct the cmdlet to only output the differences that are not aligned between the source and destination
        
    .PARAMETER IncludeAppIds
        Instruct the cmdlet to also include the users with the ApplicationId property filled
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will exclude those with ApplicationId filled.
        
        Sample output:
        Email                          Name                           AppId                SourceId        DestinationId
        -----                          ----                           -----                --------        -------------
        aba@temp.com                   Austin Baker                                        f85bcd69-ef72-… 5aaac0ec-a91…
        ade@temp.com                   Alex Denver                                         39309a5c-7676-… 1d521227-43b…
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -IncludeAppIds
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will include those with ApplicationId filled.
        
        Sample output:
        Email                          Name                           AppId                SourceId        DestinationId
        -----                          ----                           -----                --------        -------------
        aba@temp.com                   Austin Baker                                        f85bcd69-ef72-… 5aaac0ec-a91…
        ade@temp.com                   Alex Denver                                         39309a5c-7676-… 1d521227-43b…
        AIBuilder_StructuredML_Prod_C… AIBuilder_StructuredML_Prod_C… ff8a1ad8-a415-45c1-… 95dc9ca2-8185-… 328db0cc-14c…
        AIBuilderProd@onmicrosoft.com  AIBuilderProd, #               0a143f2d-2320-4141-… c96f82b8-320f-… 1831f4dc-4c5…
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -IncludeAppIds -ShowDiffOnly
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will include those with ApplicationId filled.
        It will only output the users that is missing in the destionation environment.
        
        Sample output:
        Email                          Name                           AppId                SourceId        DestinationId
        -----                          ----                           -----                --------        -------------
        d365-scm-operationdataservice… d365-scm-operationdataservice… 986556ed-a409-4339-… 5e077e6a-a0c9-… Missing
        d365-scm-operationdataservice… d365-scm-operationdataservice… 14e80222-1878-455d-… 183ec023-9ccb-… Missing
        def@temp.com                   Dustin Effect                                       01e37132-0a44-… Missing
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Compare-BapEnvironmentUser {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $SourceEnvironmentId,

        [parameter (mandatory = $true)]
        [string] $DestinationEnvironmentId,
    
        [switch] $ShowDiffOnly,

        [switch] $IncludeAppIds,

        [switch] $AsExcelOutput

    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envSourceObj = Get-BapEnvironment -EnvironmentId $SourceEnvironmentId | Select-Object -First 1

        if ($null -eq $envSourceObj) {
            $messageString = "The supplied SourceEnvironmentId: <c='em'>$SourceEnvironmentId</c> didn't return any matching environment details. Please verify that the SourceEnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envDestinationObj = Get-BapEnvironment -EnvironmentId $DestinationEnvironmentId | Select-Object -First 1

        if ($null -eq $envDestinationObj) {
            $messageString = "The supplied DestinationEnvironmentId: <c='em'>$DestinationEnvironmentId</c> didn't return any matching environment details. Please verify that the DestinationEnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $usersSourceEnvironment = Get-BapEnvironmentUser -EnvironmentId $SourceEnvironmentId -IncludeAppIds:$IncludeAppIds
        $usersDestinationEnvironment = Get-BapEnvironmentUser -EnvironmentId $DestinationEnvironmentId -IncludeAppIds:$IncludeAppIds
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resCol = @(foreach ($sourceUser in $($usersSourceEnvironment | Sort-Object -Property Email )) {
                if ([System.String]::IsNullOrEmpty($sourceUser.Email)) { continue }

                $destinationUser = $usersDestinationEnvironment | Where-Object Email -eq $sourceUser.Email | Select-Object -First 1
        
                $tmp = [Ordered]@{
                    Email         = $sourceUser.Email
                    Name          = $sourceUser.Name
                    AppId         = $sourceUser.AppId
                    SourceId      = $sourceUser.systemuserid
                    DestinationId = "Missing"
                }
        
                if (-not ($null -eq $destinationUser)) {
                    $tmp.DestinationId = $destinationUser.systemuserid
                }
        
                ([PSCustomObject]$tmp) | Select-PSFObject -TypeName "D365Bap.Tools.Compare.User"
            }
        )

        if ($ShowDiffOnly) {
            $resCol = $resCol | Where-Object { $_.DestinationId -eq "Missing" }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -NoNumberConversion SourceVersion, DestinationVersion
            return
        }

        $resCol
    }
    
    end {
        
    }
}