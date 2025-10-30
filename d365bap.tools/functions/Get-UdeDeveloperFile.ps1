
<#
    .SYNOPSIS
        Gets UDE developer files for a specified environment.
        
    .DESCRIPTION
        This function retrieves UDE developer files for a specified environment.
        
    .PARAMETER EnvironmentId
        The ID of the environment that you want to work against.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .PARAMETER Path
        The path to the directory where the developer files will be saved.
        
        Defaults to "C:\Temp\d365bap.tools\UdeDeveloperFiles".
        
    .PARAMETER Files
        The types of developer files to retrieve.
        
        Can be one or more of the following values: "All", "SystemMetadata", "FinOpsVsix22", "TraceParser", "CrossReference".
        
        Defaults to "All".
        
    .PARAMETER Download
        Instructs the function to download the developer files to the specified path.
        
    .EXAMPLE
        PS C:\> Get-UdeDeveloperFile -EnvironmentId "env-123"
        
        This will retrieve the UDE developer files for the specified environment ID without downloading them.
        
    .EXAMPLE
        PS C:\> Get-UdeDeveloperFile -EnvironmentId "env-123" -Download
        
        This will download the UDE developer files for the specified environment ID to the default path.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeDeveloperFile {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Path = "C:\Temp\d365bap.tools\UdeDeveloperFiles",

        [ValidateSet('All', 'SystemMetadata', 'FinOpsVsix22', 'TraceParser', 'CrossReference')]
        [string[]] $Files = 'All',

        [switch] $Download
    )
    
    begin {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $envObj = Get-UdeEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UdeEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        $build = $envObj.PpacProvApp

        if ($Download) {
            $downloadDir = "$Path\$($envObj.PpacProvApp)"
            New-Item -Path $downloadDir `
                -ItemType Directory `
                -Force `
                -WarningAction SilentlyContinue > $null
        }

        $executable = Get-PSFConfigValue -FullName "d365bap.tools.path.azcopy"

        $endpoints = @("SystemMetadata", "FinOpsVsix22", "TraceParser", "CrossReference")
        $colFileTypes = @()
        
        if ($Files -eq 'All') {
            $colFileTypes = $endpoints
        }
        else {
            $colFileTypes = $Files
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.PpacEnvUri + "/" #! Very important to have the trailing slash

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Correlationid"           = [guid]::NewGuid().ToString()
            "Dataverseenvironmenturi" = $envObj.PpacEnvUri
            "Authorization"           = "Bearer $($tokenWebApiValue)"
            "Odata-Maxversion"        = "4.0"
            "Odata-Version"           = "4.0"
            "Accept"                  = "application/json"
        }

        $colFiles = @(
            foreach ($endpoint in $endpoints) {

                # Skip if not in requested file types
                if ($endpoint -notin $colFileTypes) { continue }

                $localUri = "https://developertools.powerplatform.microsoft.com/api/clientmetadata/$($endpoint.ToLower())?version=$($envObj.PpacProvApp.Replace(".", "-"))"

                [PsCustomObject][Ordered]@{
                    "Type"  = $endpoint
                    "Build" = $envObj.PpacProvApp
                    "Uri"   = $(Invoke-RestMethod -Method Get `
                            -Uri $localUri `
                            -Headers $headers)
                } | Select-PSFObject -TypeName "D365Bap.Tools.UdeDeveloperFile" `
                    -Property *
            }
        )

        if (-not $Download) {
            $colFiles
            return
        }

        Write-PSFMessage -Level Host -Message "Will start the download of the files. It will open a separate PowerShell window for each:"

        $processes = @()

        # Start a new PowerShell window for each download to allow parallel downloads
        # Each window will remain open after download to allow user to validate the download
        foreach ($fileObj in $colFiles) {
            $uriQuery = Split-Path $fileObj.Uri -Leaf
            $fileName = $uriQuery.Split("?")[0]
            $outputPath = Join-Path $downloadDir $fileName

            $fileObj | Add-Member -NotePropertyName "Path" -NotePropertyValue $outputPath

            if ([System.IO.Path]::Exists($outputPath)) {
                Write-PSFMessage -Level Host -Message " - Skipping <c='em'>$fileName</c> as it already <c='em'>exists</c>"
                continue
            }

            Write-PSFMessage -Level Host -Message " - <c='em'>$fileName</c>"

            # Command to run in new window: azcopy copy, then pause for validation
            $command = @"
$executable copy '$($fileObj.Uri)' '$outputPath';
if(-not [System.IO.Path]::Exists('$outputPath')){
    Write-Host 'Download failed. Review the logs for more information.' -ForegroundColor Red
};
"@
            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command", $command -WindowStyle Normal -PassThru

            $processes += $process
        }

        Write-PSFMessage -Level Host -Message "Will await the completion of <c='em'>all</c> file downloads."

        if ($processes.Count -gt 0 ) {
            Wait-Process -Id $processes.Id > $null
        }
        
        foreach ($fileObj in $colFiles) {
            Unblock-File -Path $fileObj.Path
        }
        
        # Output the details to the user
        $colFiles
            
        # If we downloaded the SystemMetadata, we extract it - otherwise it is useless
        $zipPackages = $colFiles | Where-Object type -eq 'SystemMetadata' | Select-Object -First 1 -ExpandProperty Path
        $pathPackages = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$build"

        if (-not [System.IO.Path]::Exists("$pathPackages\PackagesLocalDirectory")) {
            New-Item -Path "$pathPackages" `
                -ItemType Directory `
                -Force `
                -WarningAction SilentlyContinue > $null

            Write-PSFMessage -Level Host -Message "Will extract the <c='em'>PackagesLocalDirectory.zip</c> file. It will take some minutes..."
            [IO.Compression.ZipFile]::ExtractToDirectory($zipPackages, "$pathPackages\PackagesLocalDirectory")
            Write-PSFMessage -Level Host -Message "Extraction completed..."

            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
        }
    }

    end {
    }
}