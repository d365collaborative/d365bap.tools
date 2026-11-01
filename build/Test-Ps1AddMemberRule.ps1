<#
.SYNOPSIS
    Tests the looped note property lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that note properties added inside any
    iteration construct are read or written inside that loop.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1AddMemberDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('add-member-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-AddMember {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1AddMemberDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$unused = @'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
    }
}
'@
Assert-AddMember 'Foreach unused property' $unused 1 @('PSAvoidAddMemberInLoop', 'Marker', 'projection after the loop')

Assert-AddMember 'Foreach mixed with unused property' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $item.Other = 2
    }
}
'@) -Expected 1

Assert-AddMember 'Foreach used property' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $item.Marker
    }
}
'@)

Assert-AddMember 'Foreach property written later' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $item.Marker = 2
    }
}
'@)

Assert-AddMember 'Foreach property used through pipeline variable' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $resCol | Where-Object { $_.Marker -eq 1 }
    }
}
'@)

Assert-AddMember 'Foreach property used only after the loop' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1
    }

    $resCol | Select-Object -Property Marker
}
'@) -Expected 1

Assert-AddMember 'For loop unused property' (@'
function Get-Fixture {
    $item = [PSCustomObject]@{}

    for ($i = 0; $i -lt 2; $i++) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue $i -Force
    }
}
'@) -Expected 1

Assert-AddMember 'While loop unused property' (@'
function Get-Fixture {
    $item = [PSCustomObject]@{}

    while ($true) {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1 -Force
        break
    }
}
'@) -Expected 1

Assert-AddMember 'Do while unused property' (@'
function Get-Fixture {
    $item = [PSCustomObject]@{}

    do {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1 -Force
    } while ($false)
}
'@) -Expected 1

Assert-AddMember 'Do while property used in condition' (@'
function Get-Fixture {
    $item = [PSCustomObject]@{}

    do {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1 -Force
    } while ($item.Marker -eq 1)
}
'@)

Assert-AddMember 'Do until unused property' (@'
function Get-Fixture {
    $item = [PSCustomObject]@{}

    do {
        $item | Add-Member -NotePropertyName Marker -NotePropertyValue 1 -Force
    } until ($true)
}
'@) -Expected 1

Assert-AddMember 'ForEach-Object unused property' (@'
function Get-Fixture {
    $resCol = @()

    $resCol | ForEach-Object {
        $_ | Add-Member -NotePropertyName Marker -NotePropertyValue 1
    }
}
'@) -Expected 1

Assert-AddMember 'ForEach-Object used property' (@'
function Get-Fixture {
    $resCol = @()

    $resCol | ForEach-Object {
        $_ | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $_.Marker
    }
}
'@)

Assert-AddMember 'ForEach method unused property' (@'
function Get-Fixture {
    $resCol = @()

    $resCol.ForEach({
        $_ | Add-Member -NotePropertyName Marker -NotePropertyValue 1
    })
}
'@) -Expected 1

Assert-AddMember 'ForEach method used property' (@'
function Get-Fixture {
    $resCol = @()

    $resCol.ForEach({
        $_ | Add-Member -NotePropertyName Marker -NotePropertyValue 1
        $_.Marker
    })
}
'@)

Assert-AddMember 'Dynamic property name' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName $name -NotePropertyValue 1
    }
}
'@)

Assert-AddMember 'Non-variable target' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item.Sub | Add-Member -NotePropertyName Marker -NotePropertyValue 1
    }
}
'@)

Assert-AddMember 'Other member type' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -MemberType ScriptProperty -Name Marker -Value { 1 }
    }
}
'@)

Assert-AddMember 'Outside the module' $unused -Directory 'build'

Write-Output "Add-Member rule checks passed: $script:caseCount cases."
