
<#
    .SYNOPSIS
        Get operation history for a given Unified environment from PPAC.
        
    .DESCRIPTION
        Retrieves the operation history for a specified Unified environment from the Power Platform Admin Center (PPAC). This includes details such as operation name, description, correlation ID, status, and more.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER LatestOnly
        Instructs the cmdlet to only return the latest operation from the history.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.
        
    .PARAMETER DownloadLog
        Instructs the cmdlet to attempt to download the operation logs for each operation in the history.
        
        Note that not all operations will have logs available, and for some operations (e.g. FnO DB Sql Jit) there are no logs at all.
        
    .PARAMETER DownloadPath
        Specifies the path where the downloaded logs will be saved.
        
        The default path is "C:\Temp\d365bap.tools\PpacD365OperationHistory".
        
        Logs will be organized in subfolders for each environment based on the environment name.
        
    .EXAMPLE
        PS C:\> Get-PpacD365OperationHistory -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will fetch the operation history for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -LatestOnly
        
        This will fetch only the latest operation from the operation history for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
        
        This will fetch the operation history for the specified environment.
        It will output the results directly into an Excel file, that will automatically open on your machine.
        
    .EXAMPLE
        PS C:\> Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -DownloadLog
        
        This will fetch the operation history for the specified environment.
        It will attempt to download the operation logs for each operation in the history, and save them to the default download path.
        
    .EXAMPLE
        PS C:\> Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -DownloadLog -DownloadPath "C:\Temp\MyLogs"
        
        This will fetch the operation history for the specified environment.
        It will attempt to download the operation logs for each operation in the history, and save them to "C:\Temp\MyLogs".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacD365OperationHistory {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $LatestOnly,

        [switch] $AsExcelOutput,

        [switch] $DownloadLog,

        [string] $DownloadPath = "C:\Temp\d365bap.tools\PpacD365OperationHistory"
    )
    
    begin {
        # Needs to be empty for support of pipe input
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UnifiedEnvironment `
            -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ($DownloadLog) {
            $downloadDir = "$DownloadPath\$($envObj.PpacEnvName)"
            New-Item -Path $downloadDir `
                -ItemType Directory `
                -Force `
                -WarningAction SilentlyContinue > $null
        }

        $baseUri = $envObj.PpacEnvUri + "/" #! Very important to have the trailing slash

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }

        $localUri = $baseUri + "api/data/v9.0/msprov_operationhistories"

        $colModules = Invoke-RestMethod -Uri $localUri `
            -Method Get `
            -Headers $headers | `
            Select-Object -ExpandProperty value | `
            Sort-Object -Property modifiedon -Descending
            
        if ($LatestOnly) {
            $colModules = $colModules | Select-Object -First 1
        }

        $resCol = @(
            $colModules | Select-PSFObject -TypeName 'D365Bap.Tools.PpacD365OperationHistory' `
                -ExcludeProperty '@odata.etag' `
                -Property "msprov_name As Name",
            "msprov_description As Description",
            "msprov_correlationid As CorrelationId",
            "msprov_operationhistoryid As Id",
            "'_createdby_value@OData.Community.Display.V1.FormattedValue' As CreatedBy",
            "'msprov_startedon@OData.Community.Display.V1.FormattedValue' As StartedOn",
            "'statuscode@OData.Community.Display.V1.FormattedValue' As Status",
            "'statecode@OData.Community.Display.V1.FormattedValue' As State",
            "createdon As Created",
            "modifiedon As Modified",
            "versionnumber As Version",
            @{ Name = "msprov_UserId"; Expression = {
                    if ($null -ne $_.msprov_operationproperties) {
                        if (Test-Json -Json $_.msprov_operationproperties -ErrorAction SilentlyContinue) {
                            ($_.msprov_operationproperties | ConvertFrom-Json -Depth 10).UserId
                        }
                    }
                }
            },
            @{ Name = "msprov_Payload"; Expression = {
                    if ($null -ne $_.msprov_operationproperties) {
                        if (Test-Json -Json $_.msprov_operationproperties -ErrorAction SilentlyContinue) {
                            ($_.msprov_operationproperties | ConvertFrom-Json -Depth 10).Payload
                        }
                    }
                }
            },
            @{ Name = "ProvVersion"; Expression = {
                    if ($null -ne $_.msprov_operationproperties) {
                        if (Test-Json -Json $_.msprov_operationproperties -ErrorAction SilentlyContinue) {
                            ($_.msprov_operationproperties | ConvertFrom-Json -Depth 10).Payload.Split("|")[0].Split("=")[1]
                        }
                    }
                }
            },
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel `
                -WorksheetName "Get-PpacD365OperationHistory" `
                -WarningAction SilentlyContinue
            
            return
        }

        if ($DownloadLog) {
            Write-PSFMessage `
                -Message "Please note that for '<c='em'>FnO DB Sql Jit request</c>' there exists no logs. Will attempt to download logs for other operations." `

            foreach ($histObj in $resCol) {
                $logFileName = "$($histObj.Id)_$($histObj.msprov_logs_name)"

                $logUri = $baseUri + "api/data/v9.0/msprov_operationhistories($($histObj.Id))/msprov_logs/`$value"

                $downloadFilePath = "$downloadDir\$logFileName"

                if ($histObj.Name -ne 'FnOSqlJit') {
                    Invoke-WebRequest -Uri $logUri `
                        -Method Get `
                        -Headers $headers `
                        -OutFile $downloadFilePath `
                        -SkipHttpErrorCheck 4> $null
                }
            }

            Write-PSFMessage -Level Important -Message "Operation logs downloaded to:"
            Write-PSFHostColor -String "- '<c='em'>$downloadDir</c>'"
        }

        $resCol
    }

    end {
    }
}