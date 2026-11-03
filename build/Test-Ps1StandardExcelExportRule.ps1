<#
.SYNOPSIS
    Tests the standard Excel export output rule.

.DESCRIPTION
    Parses fixture cmdlets and checks the canonical AsExcelOutput block,
    worksheet forms, guards, and returns through the complete public-output
    diagnostic set.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1StandardPublicOutputDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('standard-public-excel-rule-' + [guid]::NewGuid().ToString('N'))
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

function Assert-Excel {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
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

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Excel 'Full accepted fixture' @'
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

Assert-Excel 'Canonical export block' @'
function Get-Fixture {
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

Assert-Excel 'Missing return' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
    }

    $resCol
}
'@ -Expected 1 @('bare return')

Assert-Excel 'Else branch' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }
    else {
        $resCol | ConvertTo-PSFHashtable
        return
    }

    $resCol
}
'@ -Expected 1 @('elseif/else')

Assert-Excel 'Elseif branch' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }
    elseif ($AsHashTable) {
        $resCol | ConvertTo-PSFHashtable
        return
    }

    $resCol
}
'@ -Expected 1 @('elseif/else')

Assert-Excel 'Result count guard' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        if ($resCol) {
            $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        }
        return
    }

    $resCol
}
'@ -Expected 1 @('result-count guard')

Assert-Excel 'Original issue count guard' @'
function Get-PpacTenantProvisioningDefault {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        if ($resCol) {
            $resCol | Export-Excel -WorksheetName "Get-PpacTenantProvisioningDefault" -WarningAction SilentlyContinue
        }
        return
    }

    $resCol
}
'@ -Expected 1 @('result-count guard', 'Get-PpacTenantProvisioningDefault')

Assert-Excel 'Count guard removed' @'
function Get-PpacTenantProvisioningDefault {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName "Get-PpacTenantProvisioningDefault" -WarningAction SilentlyContinue
        return
    }

    $resCol
}
'@

Assert-Excel 'Wrong worksheet name' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Something'
        return
    }

    $resCol
}
'@ -Expected 1 @("Use -WorksheetName 'Get-Fixture'")

Assert-Excel 'Missing worksheet name' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel
        return
    }

    $resCol
}
'@ -Expected 1 @("Pass -WorksheetName 'Get-Fixture'")

Assert-Excel 'Variable worksheet name is rejected' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()
    $name = 'Get-Fixture'

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName $name
        return
    }

    $resCol
}
'@ -Expected 1 @("Use -WorksheetName 'Get-Fixture'")

Assert-Excel 'Extra Export-Excel parameters' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture' -NoNumberConversion Id -WarningAction SilentlyContinue
        return
    }

    $resCol
}
'@

Assert-Excel 'Two export blocks' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $colOne = @()
    $colTwo = @()

    if ($Download) {
        if ($AsExcelOutput) {
            $colOne | Export-Excel -WorksheetName 'Get-Fixture'
            return
        }

        $colOne
        return
    }

    if ($AsExcelOutput) {
        $colTwo | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $colTwo
}
'@

Assert-Excel 'Forwarding wrapper' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    Get-Other -AsExcelOutput:$AsExcelOutput
}
'@ -Expected 1 @('Add the export block')

Assert-Excel 'Missing export block' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()
    $resCol
}
'@ -Expected 1 @('Add the export block')

Assert-Excel 'Return with a value' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return $null
    }

    $resCol
}
'@ -Expected 1 @('bare return')

Assert-Excel 'Worksheet name is case-sensitive' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'get-fixture'
        return
    }

    $resCol
}
'@ -Expected 1

Assert-Excel 'Legacy short worksheet name is rejected' @'
function Get-UdeConnection {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'UdeConnection'
        return
    }

    $resCol
}
'@ -FileName 'Get-UdeConnection.ps1' -Expected 1

Assert-Excel 'Connection command uses the function name as worksheet' @'
function Get-UdeConnection {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-UdeConnection'
        return
    }

    $resCol
}
'@ -FileName 'Get-UdeConnection.ps1'

Assert-Excel 'Function without the switch' @'
function Get-Fixture {
    param (
        [switch] $AsExcel
    )

    $resCol = @()
    $resCol
}
'@

Assert-Excel 'Internal helpers are exempt' @'
function Get-Fixture {
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()
    $resCol
}
'@ -Directory 'd365bap.tools/internal/functions'

Assert-Excel 'Colon' @'
function Get-Fixture {
    param([switch] $AsExcelOutput)
    if ($AsExcelOutput) { $result | Export-Excel -WorksheetName:'Get-Fixture'; return }
}
'@

Assert-Excel 'Duplicate' @'
function Get-Fixture {
    param([switch] $AsExcelOutput)
    if ($AsExcelOutput) { $result | Export-Excel -WorksheetName 'Get-Fixture' -WorksheetName 'Get-Fixture'; return }
}
'@ -Expected 1

Assert-Excel 'Computed' @'
function Get-Fixture {
    param([switch] $AsExcelOutput)
    if ($AsExcelOutput) { $result | Export-Excel -WorksheetName ('Get-' + 'Fixture'); return }
}
'@ -Expected 1

Assert-Excel 'Splat' @'
function Get-Fixture {
    param([switch] $AsExcelOutput)
    if ($AsExcelOutput) { $result | Export-Excel -WorksheetName 'Get-Fixture' @options; return }
}
'@ -Expected 1

Assert-Excel 'Nested ownership' @'
function Get-Fixture {
 param([switch] $AsExcelOutput)
 function Get-Helper { Get-Other -AsExcelOutput:$AsExcelOutput }
}
'@ -Expected 1 @('Add the export block')

Assert-Excel 'Literal forwarding' @'
function Get-Fixture {
 param([switch] $AsExcelOutput)
 Get-Other -AsExcelOutput:$true
}
'@ -Expected 1 @('Add the export block')

Assert-Excel 'Interpolated worksheet cannot be verified' 'function Get-Fixture { param([switch] $AsExcelOutput); if ($AsExcelOutput) { $rows | Export-Excel -WorksheetName "Get-$suffix"; return } }' -Expected 1
Assert-Excel 'Abbreviated worksheet parameter is rejected' "function Get-Fixture { param([switch] `$AsExcelOutput); if (`$AsExcelOutput) { `$rows | Export-Excel -Work 'Get-Fixture'; return } }" -Expected 1
Assert-Excel 'Variable worksheet cannot be verified' 'function Get-Fixture { param([switch] $AsExcelOutput); if ($AsExcelOutput) { $rows | Export-Excel -WorksheetName $sheet; return } }' -Expected 1
Assert-Excel 'Nested helper export cannot satisfy the parent' "function Get-Fixture { param([switch] `$AsExcelOutput); function Helper { param([switch] `$AsExcelOutput); if (`$AsExcelOutput) { `$rows | Export-Excel -WorksheetName 'Helper'; return } } }" -Expected 1 @('Add the export block')
Assert-Excel 'Qualified literal export is accepted' "function Get-Fixture { param([switch] `$AsExcelOutput); if (`$AsExcelOutput) { `$rows | ImportExcel\Export-Excel -WorksheetName:'Get-Fixture'; return } }"

Assert-Excel 'Trap blocks are extra work' 'function Get-Fixture { param([switch] $AsExcelOutput); if ($AsExcelOutput) { trap { continue }; $rows | Export-Excel -WorksheetName "Get-Fixture"; return } }' -Expected 1 @('trap blocks')
Assert-Excel 'Background export does not complete before return' 'function Get-Fixture { param([switch] $AsExcelOutput); if ($AsExcelOutput) { $rows | Export-Excel -WorksheetName "Get-Fixture" & return } }' -Expected 1 @('synchronously')

Write-Output "Standard Excel export rule checks passed: $script:caseCount cases."
