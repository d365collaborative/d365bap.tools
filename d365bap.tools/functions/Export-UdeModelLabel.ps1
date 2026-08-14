
<#
    .SYNOPSIS
        Exports UDE model label files from PackagesLocalDirectory
        
    .DESCRIPTION
        Copies label files from the local packages into a versioned folder structure under the output path
        
        Uses the active UDE configuration by default, or accepts PackagesLocalDirectory from Get-UdePackageLocalDirectory via the pipeline
        
    .PARAMETER Model
        Module name(s) to include. Supports wildcards. Defaults to '*'
        
    .PARAMETER Language
        Language code used to resolve the label descriptor files. Defaults to 'en-US'
        
    .PARAMETER LabelFileId
        Label file id(s) to include. Supports wildcards. Defaults to '*'
        
    .PARAMETER OutputPath
        Root folder for exported labels. Each packages version is exported to a subfolder
        
        Defaults to 'C:\temp\d365bap.tools\ModelLabels'
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
    .PARAMETER ShowLabelDetails
        Instructs the cmdlet to display the processed label details
        
    .PARAMETER PackagesLocalDirectory
        One or more PackagesLocalDirectory paths to export from. Supports pipeline input
        
    .EXAMPLE
        PS C:\> Export-UdeModelLabel
        
        Exports label files from the active UDE configuration.
        It will export all label files for all models.
        It will export the default language 'en-US'.
        
    .EXAMPLE
        PS C:\> Export-UdeModelLabel -Model 'Foundation'
        
        Exports matching labels from the active UDE configuration.
        It will export all label files for the 'Foundation' model.
        It will export the default language 'en-US'.
        
    .EXAMPLE
        PS C:\> Export-UdeModelLabel -Model 'Foundation' -LabelFileId 'AccountsPayable'
        
        Exports matching labels from the active UDE configuration.
        It will export only label files for the 'Foundation' model.
        It will export only the label file with the id 'AccountsPayable'.
        It will export the default language 'en-US'.
        
    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -Version '10.0.2345*' | Export-UdeModelLabel
        
        Exports label files for all matching local package versions.
        It will export all label files for all models.
        It will export the default language 'en-US'.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Export-UdeModelLabel {
    [CmdletBinding(DefaultParameterSetName = 'Active')]
    [OutputType('D365Bap.Tools.UdeModelLabel')]
    param (
        [string[]] $Model = @('*'),

        [string] $Language = "en-US",

        [string] $LabelFileId = '*',

        [string] $OutputPath = 'C:\temp\d365bap.tools\ModelLabels',

        [switch] $AsExcelOutput,

        [switch] $ShowLabelDetails,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Pipeline')]
        [string[]] $PackagesLocalDirectory
    )

    begin {
        $resCol = [System.Collections.Generic.List[object]]::new()
        $skipDirs = @('bin', 'Descriptor', 'Reports', 'Resources', 'WebContent', 'XppMetadata')

        if (-not (Test-Path -LiteralPath $OutputPath)) {
            $null = New-Item -Path $OutputPath -ItemType Directory -Force
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Active' {
                $udeConfig = Get-UdeConfig -Active | Select-Object -First 1

                if ($null -eq $udeConfig) {
                    Stop-PSFFunction -Message "Stopping because no active UDE configuration was found." `
                        -Exception $([System.Exception]::new("No active UDE configuration was found."))
                    return
                }

                $PackagesLocalDirectory = $udeConfig.PackagesLocalDirectory
            }
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($pathPackages in @($PackagesLocalDirectory)) {
            if ([string]::IsNullOrWhiteSpace($pathPackages)) { continue }

            $packagesVersion = Split-Path -Path (Split-Path -Path $pathPackages -Parent) -Leaf

            if (-not (Test-Path -LiteralPath $pathPackages)) {
                Stop-PSFFunction -Message "Stopping because PackagesLocalDirectory was not found." `
                    -Exception $([System.Exception]::new("PackagesLocalDirectory '$pathPackages' was not found."))
                return
            }

            $pathOutputRoot = Join-Path -Path $OutputPath -ChildPath $packagesVersion
            $versionExportCount = 0

            $colModules = @(
                foreach ($package in Get-ChildItem -LiteralPath $pathPackages -Directory | Where-Object Name -notin $skipDirs) {
                    foreach ($module in Get-ChildItem -LiteralPath $package.FullName -Directory | Where-Object Name -notin $skipDirs) {
                        $pathAxLabelFile = Join-Path -Path $module.FullName -ChildPath 'AxLabelFile'
                        if (-not (Test-Path -LiteralPath $pathAxLabelFile)) { continue }

                        $moduleMatches = $false
                        foreach ($modelPattern in $Model) {
                            if ($module.Name -like $modelPattern) {
                                $moduleMatches = $true
                                break
                            }
                        }
                        if (-not $moduleMatches) { continue }

                        [PSCustomObject]@{
                            Package         = $package.Name
                            Model           = $module.Name
                            AxLabelFilePath = $pathAxLabelFile
                        }
                    }
                }
            )

            foreach ($module in $colModules) {
                $descriptorPattern = "*_$Language.xml"
                $colDescriptors = Get-ChildItem -LiteralPath $module.AxLabelFilePath -File -Filter '*.xml' |
                    Where-Object Name -like $descriptorPattern

                foreach ($descriptor in $colDescriptors) {
                    try {
                        [xml] $descriptorXml = Get-Content -LiteralPath $descriptor.FullName -Raw -Encoding UTF8
                    }
                    catch {
                        continue
                    }

                    $labelId = $descriptorXml.AxLabelFile.LabelFileId
                    if ($labelId -notlike $LabelFileId) { continue }

                    $labelRelative = ($descriptorXml.AxLabelFile.RelativeUriInModelStore -replace '^.*?AxLabelFile\\', '')
                    $sourcePath = Join-Path -Path $module.AxLabelFilePath -ChildPath $labelRelative

                    if (-not (Test-Path -LiteralPath $sourcePath)) { continue }

                    $destinationDir = Join-Path -Path $pathOutputRoot -ChildPath (Join-Path -Path $module.Package -ChildPath $module.Model)
                    if (-not (Test-Path -LiteralPath $destinationDir)) {
                        $null = New-Item -Path $destinationDir -ItemType Directory -Force
                    }

                    $labelFileName = Split-Path -Path $sourcePath -Leaf
                    $destinationPath = Join-Path -Path $destinationDir -ChildPath $labelFileName
                    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force

                    $null = $resCol.Add([PSCustomObject]@{
                            PackagesVersion = $packagesVersion
                            Package         = $module.Package
                            Model           = $module.Model
                            LabelFileId     = $labelId
                            Language        = $Language
                            LabelFileName   = $labelFileName
                        })

                    $versionExportCount++
                }
            }

            if ($versionExportCount -gt 0) {
                Write-PSFMessage -Level Important -Message "Exported <c='em'>$versionExportCount</c> label file(s) to <c='em'>$pathOutputRoot</c>."
            }
        }
    }

    end {
        if (Test-PSFFunctionInterrupt) { return }

        if (-not ($ShowLabelDetails -or $AsExcelOutput)) { return }

        $output = $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.UdeModelLabel' -Property *

        if ($AsExcelOutput) {
            $output | Export-Excel -WorksheetName "Export-UdeModelLabel"
        }

        if ($ShowLabelDetails) {
            $output
        }
    }
}