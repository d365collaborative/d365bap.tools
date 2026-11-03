<#
.SYNOPSIS
    Tests the public output lint rule.

.DESCRIPTION
    Parses fixture functions and checks table views, the AsExcelOutput switch,
    and the export block through the complete public-output diagnostic set.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1StandardPublicOutputDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('standard-public-output-rule-' + [guid]::NewGuid().ToString('N'))
$tableDirectory = Join-Path $fixtureRoot 'd365bap.tools/xml/formats/table'
$null = New-Item -ItemType Directory -Path $tableDirectory -Force
$script:caseCount = 0

function Write-TableFormat {
	param([string[]] $TypeName)
	Remove-Item -Path (Join-Path $tableDirectory '*.ps1xml') -Force -ErrorAction Ignore
	$index = 0
	foreach ($itemName in $TypeName) {
		$index++
		$document = @"
<?xml version="1.0" encoding="utf-8"?>
<Configuration><ViewDefinitions><View><Name>$itemName</Name><ViewSelectedBy><TypeName>$itemName</TypeName></ViewSelectedBy><TableControl><TableRowEntries><TableRowEntry><TableColumnItems><TableColumnItem><PropertyName>Name</PropertyName></TableColumnItem></TableColumnItems></TableRowEntry></TableRowEntries></TableControl></View></ViewDefinitions></Configuration>
"@
		[IO.File]::WriteAllText((Join-Path $tableDirectory "Type$index.Table.Format.ps1xml"), $document)
	}
	$script:Ps1TableFormatTypes = $null
}

function Assert-Output {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	if ($analysis.ParseErrors.Count -gt 0) { throw "Invalid fixture ${Label}: $($analysis.ParseErrors.Message -join '; ')" }
	$colDiagnostics = @(Get-Ps1StandardPublicOutputDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

$standard = @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('D365Bap.Tools.Known[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Table view, Excel switch, and export block' $standard

Write-TableFormat @()
Assert-Output 'Missing table view' $standard -Expected 1 @('PSUseStandardPublicOutput', "Add a table format view for 'D365Bap.Tools.Known'")

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Missing Excel switch explains the complete convention' ($standard.Replace('[switch] $AsExcelOutput', '')) -Expected 1 @('PSUseStandardPublicOutput', 'Add [switch] $AsExcelOutput', 'Export-Excel', "WorksheetName 'Get-Fixture'", 'bare return')

Write-TableFormat @()
Assert-Output 'Missing view and switch reports both requirements' ($standard.Replace('[switch] $AsExcelOutput', '')) -Expected 2 @('Add a table format view', 'Add [switch] $AsExcelOutput')

Write-TableFormat @()
Assert-Output 'Single object declaration still checks the emitted custom type' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", "[OutputType('System.Object')]")) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Empty declaration still checks the emitted custom type' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", '[OutputType()]')) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'String array declaration does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", '[OutputType([string[]])]')) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Qualified scalar array does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", "[OutputType('System.String[]')]")) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Integer array declaration does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", '[OutputType([int[]])]')) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Boolean array declaration does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", '[OutputType([bool[]])]')) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Guid array declaration does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", '[OutputType([guid[]])]')) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Decimal array declaration does not hide a custom projection' ($standard.Replace("[OutputType('D365Bap.Tools.Known[]')]", "[OutputType('System.Decimal[]')]")) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Outside the functions folder' $standard -Directory 'build'

Write-TableFormat @()
Assert-Output 'Internal functions stay outside public output scope' $standard -Directory 'd365bap.tools/internal/functions'

Write-TableFormat @()
Assert-Output 'PSTypeName property needs a view' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    [PSCustomObject]@{ PSTypeName = 'D365Bap.Tools.Unknown'; Name = 'demo' }
}
'@ -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'One missing type of two' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
    $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}
'@ -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat @()
Assert-Output 'No custom type to check' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $resCol
}
'@

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'AsExcelOutput must be a switch' ($standard.Replace('[switch] $AsExcelOutput', '[string] $AsExcelOutput')) -Expected 1 @('Add [switch] $AsExcelOutput', 'Export-Excel')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'All top-level functions are checked' @'
function Get-Helper {
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}

function Get-Fixture {
    [OutputType('D365Bap.Tools.Known[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@ -Expected 2 @('D365Bap.Tools.Unknown', 'Get-Helper')

Write-TableFormat 'D365Bap.Tools.Known'
$singular = @'
function Get-Fixture {
    [OutputType('D365Bap.Tools.Known')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@
Assert-Output 'Singular typed output with a view needs no Excel switch' $singular
Assert-Output 'Qualified attached type parameter' ($singular.Replace("Select-PSFObject -TypeName 'D365Bap.Tools.Known'", "PSFramework\Select-PSFObject -TypeName:'D365Bap.Tools.Known'"))

Write-TableFormat @()
Assert-Output 'Attached type parameter still requires a view' ($singular.Replace("-TypeName 'D365Bap.Tools.Known'", "-TypeName:'D365Bap.Tools.Known'")) -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Declared custom type with a view' 'function Get-Fixture { [OutputType("D365Bap.Tools.Known")] param(); Get-Row }'

Write-TableFormat @()
Assert-Output 'Declared custom type without an inline projection' 'function Get-Fixture { [OutputType("D365Bap.Tools.Known")] param(); Get-Row }' -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'Scalar array with no custom projection remains exempt' 'function Get-Fixture { [OutputType([string[]])] param(); "one"; "two" }'

Write-TableFormat @()
Assert-Output 'System.Collections declaration needs the Excel switch' 'function Get-Fixture { [OutputType("System.Collections.Generic.List[string]")] param(); Get-Row }' -Expected 1 @('Add [switch] $AsExcelOutput')

Write-TableFormat @()
Assert-Output 'Type expression collection declaration needs the Excel switch' 'function Get-Fixture { [OutputType([System.Object[]])] param(); Get-Row }' -Expected 1 @('Add [switch] $AsExcelOutput')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Scalar array with a view still needs no Excel switch' 'function Get-Fixture { [OutputType([string[]])] param(); $res | Select-PSFObject -TypeName "D365Bap.Tools.Known" -Property * }'

Write-TableFormat @()
Assert-Output 'Nested helper types do not require outer views' 'function Get-Fixture { [OutputType([void])] param(); function Helper { param(); $x | Select-PSFObject -TypeName "Other.Type" } }'

Write-TableFormat @()
Assert-Output 'Custom object with no parameter block still needs a view' 'function Get-Fixture { [pscustomobject]@{ PSTypeName = "Other.Type"; Name = "x" } }' -Expected 1 @('Other.Type')

Write-TableFormat 'D365Bap.Tools.Known'
$tablePath = Join-Path $tableDirectory 'Type1.Table.Format.ps1xml'
[IO.File]::WriteAllText($tablePath, '<Configuration><ViewDefinitions><View><ViewSelectedBy><TypeName>D365Bap.Tools.Known</TypeName></ViewSelectedBy><ListControl /></View></ViewDefinitions></Configuration>')
$script:Ps1TableFormatTypes = $null
Assert-Output 'List view cannot satisfy the table requirement' $singular -Expected 1 @('D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Output 'A nested helper cannot supply the parent switch' @'
function Get-Fixture {
    [OutputType('System.Object[]')]
    param ()

    function Helper {
        param ([switch] $AsExcelOutput)
        if ($AsExcelOutput) {
            $rows | Export-Excel -WorksheetName 'Get-Fixture'
            return
        }
    }
}
'@ -Expected 1 @('Add [switch] $AsExcelOutput', 'Get-Fixture')

Assert-Output 'Class method output does not require public views' 'class LocalFixture { [object] GetValue() { return [pscustomobject]@{ PSTypeName = "D365Bap.Tools.Hidden" } } }; function Get-Fixture { [OutputType([string])] param(); "sample" }'

Write-TableFormat 'D365Bap.Tools.Known'
$combinedPath = Join-Path $fixtureRoot 'd365bap.tools/functions/Get-Fixture.ps1'
[IO.File]::WriteAllText($combinedPath, $standard)
$combinedAnalysis = Get-Ps1Analysis -Path $combinedPath
. "$PSScriptRoot/ps1-lint/internal/Get-Ps1OutputTypeDiagnostic.ps1"
$combinedDiagnostics = @(Get-Ps1OutputTypeDiagnostic $combinedAnalysis) + @(Get-Ps1StandardPublicOutputDiagnostic $combinedAnalysis)
if ($combinedDiagnostics.Count -gt 0) { throw "Canonical output must pass declaration and public convention together: $($combinedDiagnostics.Message -join '; ')" }

Write-Output "Public output rule checks passed: $script:caseCount cases."
