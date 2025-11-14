<#
.SYNOPSIS
Get UDE environment operation history.

.DESCRIPTION
Gets the UDE environment operation history for a specified environment.

.PARAMETER EnvironmentId
The id of the environment that you want to work against

.PARAMETER LatestOnly
Instructs the cmdlet to return only the latest operation history.

Is based on the modified date.

.PARAMETER AsExcelOutput
Instructs the function to export the results to an Excel file.

.PARAMETER DownloadLog
Instructs the function to download the operation log.

.PARAMETER DownloadPath
Specifies the path where the operation log will be downloaded.

.EXAMPLE
PS C:\> Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123"

This will retrieve all UDE environment operation history for the specified environment id.

.EXAMPLE
PS C:\> Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -LatestOnly

This will retrieve only the latest UDE environment operation history for the specified environment id.
It is based on the modified date.

.EXAMPLE
PS C:\> Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -AsExcelOutput

This will retrieve all UDE environment operation history for the specified environment id.
Will output all details into an Excel file, that will auto open on your machine.

.EXAMPLE
PS C:\> Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -DownloadLog -DownloadPath "C:\Logs"

This will retrieve all UDE environment operation history for the specified environment id.
Will download the operation logs into the specified path.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeEnvironmentOperationHistory {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $LatestOnly,

        [switch] $AsExcelOutput,

        [switch] $DownloadLog,

        [string] $DownloadPath = "C:\Temp\d365bap.tools\UdeEnvironmentOperation"
    )
    
    begin {
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UdeEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UdeEnvironment</c>. Consider using wildcards if needed."

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

        foreach ($opsObj in $colModules) {
            foreach ($prop in ($opsObj.msprov_operationproperties | `
                        ConvertFrom-Json -Depth 10).PsObject.Properties) {
                $opsObj | Add-Member -NotePropertyName "prop_$($prop.Name)" -NotePropertyValue $prop.Value -Force
            }
        }

        $resCol = @(
            $colModules | Select-PSFObject -TypeName 'D365Bap.Tools.UdeEnvironmentOperation' `
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
            * `
                -ExcludeProperty '@odata.etag'
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel `
                -WorksheetName "Get-UdeEnvironmentOperationHistory" `
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
                        -OutFile $downloadFilePath
                }
            }
        }


        $resCol
    }

    end {
    }
}