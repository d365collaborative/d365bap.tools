
<#
    .SYNOPSIS
        Compare the environment users
        
    .DESCRIPTION
        Enables the user to compare 2 x environments, with one as a source and the other as a destination
        
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
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test*
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will exclude those with ApplicationId filled.
        
        Sample output:
        Email                          Name                           PpacAppId            SourceId        DestinationId
        -----                          ----                           ---------            --------        -------------
        aba@temp.com                   Austin Baker                                        f85bcd69-ef7... 5aaac0ec-a...
        ade@temp.com                   Alex Denver                                         39309a5c-767... 1d521227-4...
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -IncludeAppIds
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will include those with ApplicationId filled.
        
        Sample output:
        Email                          Name                           AppId                SourceId        DestinationId
        -----                          ----                           -----                --------        -------------
        aba@temp.com                   Austin Baker                                        f85bcd69-ef7... 5aaac0ec-a...
        ade@temp.com                   Alex Denver                                         39309a5c-767... 1d521227-4...
        AIBuilder_StructuredML_Prod... # AIBuilder_StructuredML_Pr... be5f0473-6b57-40f... 4d86d7d3-cb5... 9a2a59ac-6...
        AIBuilderProd@onmicrosoft.c... # AIBuilderProd                ef32e2a3-262a-44e... 4386d7d3-cb5... 902a59ac-6...
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -IncludeAppIds -ShowDiffOnly
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will include those with ApplicationId filled.
        It will only output the users that is missing in the destionation environment.
        
        Sample output:
        Email                          Name                           AppId                SourceId        DestinationId
        -----                          ----                           -----                --------        -------------
        d365-scm-operationdataservi... d365-scm-operationdataservi... 986556ed-a409-433... 5e077e6a-a0c... Missing
        d365-scm-operationdataservi... d365-scm-operationdataservi... 14e80222-1878-455... 183ec023-9cc... Missing
        def@temp.com                   Dustin Effect                                       01e37132-0a4... Missing
        
    .EXAMPLE
        PS C:\> Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -AsExcelOutput
        
        This will get all system users from the Source Environment.
        It will iterate over all of them, and validate against the Destination Environment.
        It will exclude those with ApplicationId filled.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Compare-BapEnvironmentUser {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $SourceEnvironmentId,

        [Parameter (Mandatory = $true)]
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
                    Email                       = $sourceUser.Email
                    Name                        = $sourceUser.Name
                    PpacAppId                   = $sourceUser.PpacAppId
                    SourceId                    = $sourceUser.PpacSystemUserId
                    SourcePpacSystemUserId      = $sourceUser.PpacSystemUserId
                    DestinationId               = "Missing"
                    DestinationPpacSystemUserId = "Missing"
                }
        
                if (-not ($null -eq $destinationUser)) {
                    $tmp.DestinationId = $destinationUser.PpacSystemUserId
                    $tmp.DestinationPpacSystemUserId = $destinationUser.PpacSystemUserId
                }
        
                ([PSCustomObject]$tmp) | Select-PSFObject -TypeName "D365Bap.Tools.Compare.PpacUser"
            }
        )

        if ($ShowDiffOnly) {
            $resCol = $resCol | Where-Object { $_.DestinationId -eq "Missing" }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Compare-BapEnvironmentUser"
            return
        }

        $resCol
    }
    
    end {
        
    }
}