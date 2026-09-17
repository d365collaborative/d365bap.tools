
<#
    .SYNOPSIS
        Remove models from a unified environment.
        
    .DESCRIPTION
        Removes one or more models from a unified environment (UDE, USE and others).
        
        Implements Way 2 from Plan-UdeModelDelete-Way2: downloads the last
        uploaded deploy zip for each model as a seed, rebuilds it as a Delete
        package and deploys it with BuildType=Delete.
        
        -Model accepts an array of names. Each name is validated against
        Get-UdeEnvironmentModel. Unknown names stop the cmdlet.
        
        Dependency linked models are supported: descriptor files
        (Descriptor/<model>.xml) from all installed models are read from
        their seed packages. If a model outside the removal list references
        a model inside it, the cmdlet stops. If a model inside the removal
        list references another installed model, the referenced model is
        added to the removal list, so the environment stays in a working
        state.
        
        Without -Force the cmdlet never calls DELETE msprov_fnomodules.
        That record-only fallback requires -Force.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER Model
        The names of the models that you want to remove.
        
        Each name is validated against Get-UdeEnvironmentModel.
        If the module table is empty, names fall back to the package
        names from Get-UnifiedEnvironmentPackage.
        
    .PARAMETER WorkFolder
        The folder where seed and delete packages are stored.
        
        Defaults to "C:\Temp\d365bap.tools\RemoveUdeModel".
        
        Files are organized in subfolders for each environment and model.
        
    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the delete deployment has completed.
        
    .PARAMETER DownloadLog
        Instructs the cmdlet to download the operation logs for the delete deployment.
        
    .PARAMETER Force
        Instructs the cmdlet to allow the record-only fallback.
        
        Without Force the cmdlet never calls DELETE msprov_fnomodules.
        
    .EXAMPLE
        PS C:\> Remove-UdeEnvironmentModel -EnvironmentId "env-123" -Model "B"
        
        This will remove the model B from the specified environment id.
        It will wait for the delete deployment to complete.
        
    .EXAMPLE
        PS C:\> Remove-UdeEnvironmentModel -EnvironmentId "env-123" -Model "A" -DownloadLog
        
        This will remove the model A and all models that depend on it from the specified environment id.
        It will download the operation logs to the work folder.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-UdeEnvironmentModel {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias("Name")]
        [string[]] $Model,

        [string] $WorkFolder = "C:\Temp\d365bap.tools\RemoveUdeModel",

        [switch] $WaitForCompletion,

        [switch] $DownloadLog,

        [switch] $Force
    )

    begin {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
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

        $colInstalledModels = @(Get-UdeEnvironmentModel -EnvironmentId $EnvironmentId)
        $colInstalledPackages = @(Get-UnifiedEnvironmentPackage -EnvironmentId $EnvironmentId)

        if ($colInstalledModels.Count -eq 0 -and $colInstalledPackages.Count -eq 0) {
            $messageString = "No models were found on the environment <c='em'>$($envObj.PpacEnvName)</c>. Nothing to remove."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no models were found on the environment." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $colInstalledNames = @($colInstalledModels | Select-Object -ExpandProperty Name)

        if ($colInstalledNames.Count -eq 0) {
            $colInstalledNames = @($colInstalledPackages | ForEach-Object { "$($_.Name)".Replace("_1_0_0_1_managed.zip", "") } | Where-Object { $_ -notlike "*_Delete_*" } | Select-Object -Unique)

            Write-PSFMessage -Level Important -Message "The msprov_fnomodules table is empty on <c='em'>$($envObj.PpacEnvName)</c>. Falling back to $($colInstalledNames.Count) model name(s) from the package table: $($colInstalledNames -join ', ')."
        }

        foreach ($modelName in $Model) {
            if ($modelName -notin $colInstalledNames) {
                $messageString = "The model <c='em'>$modelName</c> was not found on the environment <c='em'>$($envObj.PpacEnvName)</c>. Installed models are: $($colInstalledNames -join ', ')."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because a requested model was NOT found on the environment." `
                    -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        $colRemoveNames = @($Model | Select-Object -Unique)

        $hashSeedZipByModel = @{}
        $hashReferencesByModel = @{}

        foreach ($installedName in $colInstalledNames) {
            $seedInfo = Get-ModelSeedPackage -BaseUri $baseUri `
                -Headers $headers `
                -ModelName $installedName

            if ($null -eq $seedInfo) {
                $messageString = "No prior Full upload (seed package) was found for model <c='em'>$installedName</c>. Way 2 needs a seed for every installed model to resolve dependencies. Run a Full deploy of <c='em'>$installedName</c> first, then try again."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because a seed package was NOT found." `
                    -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $seedZipPath = Save-ModelSeedPackage -BaseUri $baseUri `
                -Headers $headers `
                -Seed $seedInfo `
                -ModelName $installedName `
                -WorkFolder $WorkFolder `
                -EnvironmentName $envObj.PpacEnvName

            if ($null -eq $seedZipPath) { return }

            $hashSeedZipByModel[$installedName] = $seedZipPath
            $hashReferencesByModel[$installedName] = @(Get-ModelModuleReference -SeedZipPath $seedZipPath -ModelName $installedName)
        }

        $colExpandedNames = Expand-ModelRemovalList -RequestedNames $colRemoveNames `
            -InstalledNames $colInstalledNames `
            -ReferencesByModel $hashReferencesByModel

        if ($null -eq $colExpandedNames) { return }

        $colOutsideNames = @($colInstalledNames | Where-Object { $_ -notin $colExpandedNames })

        foreach ($outsideName in $colOutsideNames) {
            $outsideRefs = @($hashReferencesByModel[$outsideName] | Where-Object { $_ -in $colExpandedNames })

            if ($outsideRefs.Count -gt 0) {
                $messageString = "Cannot remove model(s) $($colExpandedNames -join ', ') because installed model <c='em'>$outsideName</c> depends on $($outsideRefs -join ', '). Add <c='em'>$outsideName</c> to -Model, or remove the dependency first."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because an installed model outside the removal list depends on a model to remove." `
                    -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        $resCol = @(
            foreach ($removeName in $colExpandedNames) {
                $deleteResult = Invoke-ModelDeletePackage -BaseUri $baseUri `
                    -Headers $headers `
                    -Environment $envObj `
                    -ModelName $removeName `
                    -SeedZipPath $hashSeedZipByModel[$removeName] `
                    -WorkFolder $WorkFolder `
                    -WaitForCompletion:$WaitForCompletion `
                    -DownloadLog:$DownloadLog `
                    -Force:$Force

                if ($null -eq $deleteResult) {
                    Stop-PSFFunction -Message "Stopping because the delete deployment failed." `
                        -Exception $([System.Exception]::new("The delete deployment failed. See previous messages for details."))
                    return
                }

                $deleteResult
            }
        )

        $resCol
    }

    end {
    }
}

function Get-ModelSeedPackage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [string] $ModelName
    )

    $filterValue = [System.Uri]::EscapeDataString("'$ModelName'")
    $filterValue = $filterValue.Replace('%2527', '%27')
    $localUri = $BaseUri + "api/data/v9.0/msprov_fnopackages?`$filter=contains(msprov_name,$filterValue)&`$orderby=modifiedon desc&`$top=10"

    $colPackages = Invoke-RestMethod -Uri $localUri `
        -Method Get `
        -Headers $Headers | `
        Select-Object -ExpandProperty value

    foreach ($packageObj in $colPackages) {
        $seedZipPath = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid().ToString()).zip"

        try {
            Invoke-WebRequest -Uri ($BaseUri + "api/data/v9.0/msprov_fnopackages($($packageObj.msprov_fnopackageid))/msprov_packagepayload/`$value") `
                -Method Get `
                -Headers $Headers `
                -OutFile $seedZipPath `
                -SkipHttpErrorCheck 4> $null
        }
        catch {
            if ([System.IO.File]::Exists($seedZipPath)) {
                Remove-Item -Path $seedZipPath -Force -ErrorAction SilentlyContinue
            }
            continue
        }

        if (-not [System.IO.File]::Exists($seedZipPath)) { continue }

        try {
            $zipObj = [IO.Compression.ZipFile]::OpenRead($seedZipPath)
            $definitionEntry = $zipObj.Entries | Where-Object FullName -eq 'fnomoduledefinition.json' | Select-Object -First 1

            if ($null -eq $definitionEntry) {
                $zipObj.Dispose()
                [GC]::Collect()
                [GC]::WaitForPendingFinalizers()
                Remove-Item -Path $seedZipPath -Force -ErrorAction SilentlyContinue
                continue
            }

            $reader = New-Object System.IO.StreamReader($definitionEntry.Open())
            $definitionText = $reader.ReadToEnd()
            $reader.Close()
            $zipObj.Dispose()
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()

            $definitionJson = $definitionText | ConvertFrom-Json -ErrorAction SilentlyContinue

            $definitionModuleName = $null

            if ($null -ne $definitionJson.Module -and $null -ne $definitionJson.Module.Name) {
                $definitionModuleName = "$($definitionJson.Module.Name)"
            }
            elseif ($null -ne $definitionJson.Modules) {
                $definitionModuleName = "$($definitionJson.Modules[0].Name)"
            }
            elseif ($null -ne $definitionJson.Name) {
                $definitionModuleName = "$($definitionJson.Name)"
            }

            if ($definitionModuleName -eq $ModelName) {
                Remove-Item -Path $seedZipPath -Force -ErrorAction SilentlyContinue

                [PsCustomObject]@{
                    PackageId   = "$($packageObj.msprov_fnopackageid)"
                    PackageName = "$($packageObj.msprov_name)"
                }
                return
            }
        }
        catch {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
        }

        Remove-Item -Path $seedZipPath -Force -ErrorAction SilentlyContinue
    }

    $null
}

function Save-ModelSeedPackage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [psobject] $Seed,

        [Parameter(Mandatory = $true)]
        [string] $ModelName,

        [Parameter(Mandatory = $true)]
        [string] $WorkFolder,

        [Parameter(Mandatory = $true)]
        [string] $EnvironmentName
    )

    $modelDir = Join-Path $WorkFolder "$EnvironmentName\$ModelName"
    $seedDir = Join-Path $modelDir "seed"
    $outDir = Join-Path $modelDir "out"

    foreach ($dirPath in @($seedDir, $outDir)) {
        New-Item -Path $dirPath `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null
    }

    $seedZipPath = Join-Path $seedDir "$($ModelName)_seed.zip"

    try {
        Invoke-WebRequest -Uri ($BaseUri + "api/data/v9.0/msprov_fnopackages($($Seed.PackageId))/msprov_packagepayload/`$value") `
            -Method Get `
            -Headers $Headers `
            -OutFile $seedZipPath `
            -SkipHttpErrorCheck 4> $null
    }
    catch {
        $messageString = "Could not download the seed package for model <c='em'>$ModelName</c>. Please verify network access and try again."
        Write-PSFMessage -Level Important -Message $messageString -Exception $PSItem.Exception
        Stop-PSFFunction -Message "Stopping because the seed package could NOT be downloaded." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    if (-not [System.IO.File]::Exists($seedZipPath)) {
        $messageString = "Could not download the seed package for model <c='em'>$ModelName</c>. The payload was empty."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the seed package could NOT be downloaded." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    $seedZipPath
}

function Get-ModelModuleReference {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $SeedZipPath,

        [Parameter(Mandatory = $true)]
        [string] $ModelName
    )

    $descriptorPath = "Descriptor/$ModelName.xml"

    try {
        $zipObj = [IO.Compression.ZipFile]::OpenRead($SeedZipPath)
        $descriptorEntry = $zipObj.Entries | Where-Object FullName -eq $descriptorPath | Select-Object -First 1

        if ($null -eq $descriptorEntry) {
            $zipObj.Dispose()
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            return [string[]]@()
        }

        $reader = New-Object System.IO.StreamReader($descriptorEntry.Open())
        $descriptorText = $reader.ReadToEnd()
        $reader.Close()
        $zipObj.Dispose()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()

        $descriptorXml = [xml]$descriptorText

        return [string[]]@($descriptorXml.AxModelInfo.ModuleReferences.string | Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) })
    }
    catch {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        return [string[]]@()
    }
}

function Expand-ModelRemovalList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $RequestedNames,

        [Parameter(Mandatory = $true)]
        [string[]] $InstalledNames,

        [Parameter(Mandatory = $true)]
        [hashtable] $ReferencesByModel
    )

    $colExpanded = [System.Collections.Generic.List[string]]::new($RequestedNames)

    $changed = $true

    while ($changed) {
        $changed = $false

        foreach ($installedName in $InstalledNames) {
            if ($installedName -in $colExpanded) { continue }

            $dependsOnRemove = @($ReferencesByModel[$installedName] | Where-Object { $_ -in $colExpanded })

            if ($dependsOnRemove.Count -gt 0) {
                Write-PSFMessage -Level Important -Message "Model <c='em'>$installedName</c> depends on $($dependsOnRemove -join ', '). It will also be removed, so the environment stays in a working state."

                $colExpanded.Add($installedName)
                $changed = $true
            }
        }
    }

    return [string[]]@($colExpanded)
}

function Invoke-ModelDeletePackage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [psobject] $Environment,

        [Parameter(Mandatory = $true)]
        [string] $ModelName,

        [Parameter(Mandatory = $true)]
        [string] $SeedZipPath,

        [Parameter(Mandatory = $true)]
        [string] $WorkFolder,

        [switch] $WaitForCompletion,

        [switch] $DownloadLog,

        [switch] $Force
    )

    $modelDir = Join-Path $WorkFolder "$($Environment.PpacEnvName)\$ModelName"
    $seedDir = Join-Path $modelDir "seed"
    $outDir = Join-Path $modelDir "out"

    foreach ($dirPath in @($seedDir, $outDir)) {
        New-Item -Path $dirPath `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null
    }

    if ([System.IO.Directory]::Exists($seedDir)) {
        Get-ChildItem -Path $seedDir -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    [IO.Compression.ZipFile]::ExtractToDirectory($SeedZipPath, $seedDir, $true)

    $definitionPath = Join-Path $seedDir "fnomoduledefinition.json"

    if (-not [System.IO.File]::Exists($definitionPath)) {
        $messageString = "The seed package for model <c='em'>$ModelName</c> does not contain fnomoduledefinition.json at the top level. Way 2 needs the seed definition to build the delete package."

        if ($Force) {
            Write-PSFMessage -Level Important -Message $messageString
            Write-PSFMessage -Level Important -Message "Record-only fallback with -Force is not implemented yet. Stopping instead of calling DELETE msprov_fnomodules."
        }
        else {
            Write-PSFMessage -Level Important -Message $messageString
        }

        Stop-PSFFunction -Message "Stopping because the seed package is missing fnomoduledefinition.json." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    $correlationId = [guid]::NewGuid().ToString()

    $definitionJson = Get-Content -Path $definitionPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue

    if ($null -eq $definitionJson) {
        $messageString = "Could not read fnomoduledefinition.json for model <c='em'>$ModelName</c>. Way 2 needs the seed definition to build the delete package."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because fnomoduledefinition.json could NOT be read." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    Set-ModelDeleteDefinition -Definition $definitionJson -CorrelationId $correlationId

    $definitionJson | ConvertTo-Json -Depth 10 | Set-Content -Path $definitionPath -Encoding utf8

    $deleteZipName = "$($ModelName)_1_0_0_1_managed.zip"
    $deleteZipPath = Join-Path $outDir $deleteZipName

    if ([System.IO.File]::Exists($deleteZipPath)) {
        Remove-Item -Path $deleteZipPath -Force -ErrorAction SilentlyContinue
    }

    Compress-Archive -Path (Join-Path $seedDir "*") -DestinationPath $deleteZipPath -Force

    $packageName = "$($ModelName)_Delete_$(Get-Date -Format 'yyyyMMddHHmmss')_$($correlationId.Substring(0, 8))"

    $packageBody = @{
        "msprov_name"          = $packageName
        "msprov_buildtype"     = 2
        "msprov_packagetype"   = 0
        "msprov_dbsyncoptions" = 0
    } | ConvertTo-Json -Depth 3

    $packageHeaders = $Headers.Clone()
    $packageHeaders["Prefer"] = "return=representation"

    $packageResponse = Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.0/msprov_fnopackages") `
        -Method Post `
        -Headers $packageHeaders `
        -Body $packageBody `
        -ContentType "application/json" `
        -ResponseHeadersVariable packageRespHeaders

    $packageId = "$($packageResponse.msprov_fnopackageid)"

    if ([System.String]::IsNullOrWhiteSpace($packageId) -and $null -ne $packageRespHeaders) {
        $entityId = @($packageRespHeaders["OData-EntityId"] | Select-Object -First 1)

        if ($entityId -match 'msprov_fnopackages\(([^)]+)\)') {
            $packageId = $Matches[1]
        }
    }

    if ([System.String]::IsNullOrWhiteSpace($packageId)) {
        $messageString = "Could not create the delete package row for model <c='em'>$ModelName</c>. The server did not return a package id."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the delete package row could NOT be created." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    $uploadOk = Send-ModelPackagePayload -BaseUri $BaseUri `
        -Headers $Headers `
        -PackageId $packageId `
        -ZipPath $deleteZipPath `
        -ZipName $deleteZipName

    if (-not $uploadOk) { return }

    $moduleUri = $BaseUri + "api/data/v9.0/msprov_fnomodules"

    $moduleResponse = Invoke-RestMethod -Uri ($moduleUri + "?`$filter=msprov_name eq '$ModelName'&`$select=msprov_fnomoduleid,msprov_name") `
        -Method Get `
        -Headers $Headers | `
        Select-Object -ExpandProperty value

    $moduleRow = @($moduleResponse) | Select-Object -First 1

    if ($null -ne $moduleRow) {
        $moduleBody = @{
            "msprov_name" = $ModelName
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.0/msprov_fnomodules($($moduleRow.msprov_fnomoduleid))") `
            -Method Patch `
            -Headers $Headers `
            -Body $moduleBody `
            -ContentType "application/json" > $null
    }
    else {
        $moduleBody = @{
            "msprov_name" = $ModelName
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Uri $moduleUri `
            -Method Post `
            -Headers $Headers `
            -Body $moduleBody `
            -ContentType "application/json" > $null
    }

    $deployBody = @{
        "finopspackages" = @(
            @{
                "@odata.type"         = "Microsoft.Dynamics.CRM.msprov_fnopackage"
                "msprov_fnopackageid" = $packageId
            }
        )
        "packagetype"    = 0
        "buildtype"      = 2
    } | ConvertTo-Json -Depth 5

    $deployResponse = Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.2/msprov_deploypackagetofinopsasync") `
        -Method Post `
        -Headers $Headers `
        -Body $deployBody `
        -ContentType "application/json"

    $asyncOperationId = "$($deployResponse.asyncoperationid)"

    if ([System.String]::IsNullOrWhiteSpace($asyncOperationId)) {
        $asyncOperationId = "$($deployResponse.AsyncOperationId)"
    }

    $operationResult = [PsCustomObject][ordered]@{
        Environment     = "$($Environment.PpacEnvName)"
        Model           = $ModelName
        PackageId       = $packageId
        PackageName     = $packageName
        CorrelationId   = $correlationId
        AsyncOperation  = $asyncOperationId
        ZipPath         = $deleteZipPath
        Status          = "Started"
        PSTypeName      = "D365Bap.Tools.UdeEnvironmentModelDelete"
    }

    if (-not $WaitForCompletion) {
        $operationResult
        return
    }

    $terminalState = Wait-ModelAsyncOperation -BaseUri $BaseUri `
        -Headers $Headers `
        -AsyncOperationId $asyncOperationId

    if ($null -eq $terminalState) { return }

    $operationResult | Add-Member -NotePropertyName "OperationState" -NotePropertyValue "$($terminalState.statecode)" -Force
    $operationResult | Add-Member -NotePropertyName "OperationStatus" -NotePropertyValue "$($terminalState.statuscode)" -Force
    $operationResult | Add-Member -NotePropertyName "OperationMessage" -NotePropertyValue "$($terminalState.message)" -Force
    $operationResult.Status = "Completed"

    if ($DownloadLog) {
        $logDir = Join-Path $modelDir "logs"

        New-Item -Path $logDir `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null

        Save-ModelOperationLog -BaseUri $BaseUri `
            -Headers $Headers `
            -CorrelationId $correlationId `
            -LogDir $logDir

        $operationResult | Add-Member -NotePropertyName "LogDir" -NotePropertyValue $logDir -Force
    }

    $verifyModels = @(Get-UdeEnvironmentModel -EnvironmentId $Environment.PpacEnvId | Select-Object -ExpandProperty Name)

    if ($ModelName -in $verifyModels) {
        Write-PSFMessage -Level Important -Message "Model <c='em'>$ModelName</c> is still reported on the environment. It may take a while before the delete is visible."
        $operationResult.Status = "VerifyPending"
    }
    else {
        Write-PSFMessage -Level Important -Message "Model <c='em'>$ModelName</c> is gone from the environment. Remaining models: $($verifyModels -join ', ')."
    }

    $operationResult | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironmentModelDelete" -Property *
}

function Set-ModelDeleteDefinition {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject] $Definition,

        [Parameter(Mandatory = $true)]
        [string] $CorrelationId
    )

    if ($null -ne $Definition.Module) {
        $Definition.Module | Add-Member -NotePropertyName "BuildType" -NotePropertyValue "Delete" -Force
    }
    else {
        $Definition | Add-Member -NotePropertyName "BuildType" -NotePropertyValue "Delete" -Force
    }

    $Definition | Add-Member -NotePropertyName "BuildType" -NotePropertyValue "Delete" -Force
    $Definition | Add-Member -NotePropertyName "PackageType" -NotePropertyValue "Dev" -Force
    $Definition | Add-Member -NotePropertyName "PackageVersion" -NotePropertyValue "1.0.0.1" -Force
    $Definition | Add-Member -NotePropertyName "CorrelationID" -NotePropertyValue $CorrelationId -Force
    $Definition | Add-Member -NotePropertyName "TimestampUtc" -NotePropertyValue ([datetime]::UtcNow.ToString("o")) -Force

    if ($null -ne $Definition.DBSync) {
        $Definition.DBSync | Add-Member -NotePropertyName "SyncKind" -NotePropertyValue "None" -Force
        $Definition.DBSync | Add-Member -NotePropertyName "Arguments" -NotePropertyValue "" -Force
    }
    else {
        $Definition | Add-Member -NotePropertyName "DBSync" -NotePropertyValue ([PsCustomObject]@{
            "SyncKind"  = "None"
            "Arguments" = ""
        }) -Force
    }
}

function Send-ModelPackagePayload {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [string] $PackageId,

        [Parameter(Mandatory = $true)]
        [string] $ZipPath,

        [Parameter(Mandatory = $true)]
        [string] $ZipName
    )

    $initBody = @{
        "Target"            = "msprov_fnopackages($PackageId)"
        "FileAttributeName" = "msprov_packagepayload"
        "FileName"          = $ZipName
    } | ConvertTo-Json -Depth 3

    $initResponse = Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.2/InitializeFileBlocksUpload") `
        -Method Post `
        -Headers $Headers `
        -Body $initBody `
        -ContentType "application/json"

    $continuationToken = "$($initResponse.FileContinuationToken)"

    if ([System.String]::IsNullOrWhiteSpace($continuationToken)) {
        $messageString = "Could not initialize the file upload for package <c='em'>$PackageId</c>. The server did not return a continuation token."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the file upload could NOT be initialized." `
            -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return $false
    }

    $blockSize = 4MB
    $zipBytes = [System.IO.File]::ReadAllBytes($ZipPath)
    $blockCount = [Math]::Ceiling($zipBytes.Length / $blockSize)
    $blockIds = @()

    for ($blockIndex = 0; $blockIndex -lt $blockCount; $blockIndex++) {
        $offset = $blockIndex * $blockSize
        $length = [Math]::Min($blockSize, $zipBytes.Length - $offset)
        $blockBytes = New-Object byte[] $length
        [System.Array]::Copy($zipBytes, $offset, $blockBytes, 0, $length)

        $blockId = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("block-{0:D7}" -f $blockIndex))
        $blockIds += $blockId

        $blockBody = @{
            "BlockId"               = $blockId
            "BlockData"             = [Convert]::ToBase64String($blockBytes)
            "FileContinuationToken" = $continuationToken
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.2/UploadBlock") `
            -Method Post `
            -Headers $Headers `
            -Body $blockBody `
            -ContentType "application/json" > $null
    }

    $commitBody = @{
        "FileName"              = $ZipName
        "MimeType"              = "application/zip"
        "BlockList"             = $blockIds
        "FileContinuationToken" = $continuationToken
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.2/CommitFileBlocksUpload") `
        -Method Post `
        -Headers $Headers `
        -Body $commitBody `
        -ContentType "application/json" > $null

    $true
}

function Wait-ModelAsyncOperation {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [string] $AsyncOperationId
    )

    if ([System.String]::IsNullOrWhiteSpace($AsyncOperationId)) {
        $messageString = "The server did not return an async operation id. Cannot poll for completion."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the async operation id is missing." `
            -Exception $([System.Exception]::new($messageString)) -StepsUpward 1
        return
    }

    do {
        Start-Sleep -Seconds 20

        $asyncState = Invoke-RestMethod -Uri ($BaseUri + "api/data/v9.0/asyncoperations($AsyncOperationId)?`$select=statuscode,statecode,message,friendlymessage,errorcode") `
            -Method Get `
            -Headers $Headers

        $stateValue = "$($asyncState.statecode)"

        Write-PSFMessage -Level Verbose -Message "Delete deployment state: $stateValue. Status: $($asyncState.statuscode). Message: $($asyncState.message)"
    } while ($stateValue -notin @("Completed", "Failed", "Canceled", "3", "30", "31", "32"))

    $asyncState
}

function Save-ModelOperationLog {
    [CmdletBinding()]
    [OutputType()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $BaseUri,

        [Parameter(Mandatory = $true)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $true)]
        [string] $CorrelationId,

        [Parameter(Mandatory = $true)]
        [string] $LogDir
    )

    $historyUri = $BaseUri + "api/data/v9.0/msprov_operationhistories?`$filter=msprov_correlationid eq '$CorrelationId'&`$orderby=modifiedon desc"

    $colHistory = Invoke-RestMethod -Uri $historyUri `
        -Method Get `
        -Headers $Headers | `
        Select-Object -ExpandProperty value

    foreach ($historyObj in @($colHistory)) {
        $logFilePath = Join-Path $LogDir "$($historyObj.msprov_operationhistoryid).log"

        try {
            Invoke-WebRequest -Uri ($BaseUri + "api/data/v9.0/msprov_operationhistories($($historyObj.msprov_operationhistoryid))/msprov_logs/`$value") `
                -Method Get `
                -Headers $Headers `
                -OutFile $logFilePath `
                -SkipHttpErrorCheck 4> $null
        }
        catch {
            Write-PSFMessage -Level Important -Message "Could not download the log for operation <c='em'>$($historyObj.msprov_operationhistoryid)</c>." -Exception $PSItem.Exception
        }
    }
}