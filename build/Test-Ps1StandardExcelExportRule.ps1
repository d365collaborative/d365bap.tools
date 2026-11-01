<#
.SYNOPSIS
    Tests the standard Excel export lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks the canonical AsExcelOutput block: an
    Export-Excel call named after the function, then a bare return. Else
    branches, count guards, missing returns, and forwarding wrappers are
    checked too.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1StandardExcelExportDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('standard-excel-export-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Excel {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1StandardExcelExportDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

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

Assert-Excel 'Variable worksheet name is ignored' @'
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
'@

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
'@

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

Assert-Excel 'Named worksheet exemption' @'
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
'@ -FileName 'Get-UdeConnection.ps1'

Assert-Excel 'Exempted function still needs the right name' @'
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
'@ -FileName 'Get-UdeConnection.ps1' -Expected 1

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

Write-Output "Standard Excel export rule checks passed: $script:caseCount cases."
