<#
.SYNOPSIS
    Tests the looped note property lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a foreach loop which only adds note
    properties to the loop variable is reported.
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

$loop = @'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $envId -Force
        $item | Add-Member -NotePropertyName PpacEnvName -NotePropertyValue $envName -Force
    }
}
'@
Assert-AddMember 'Note properties added in a loop' $loop 1 @('PSAvoidAddMemberInLoop', 'Select-PSFObject')

Assert-AddMember 'Single note property' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $envId
    }
}
'@) -Expected 1

Assert-AddMember 'MemberType and Name form' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -MemberType NoteProperty -Name PpacEnvId -Value $envId -Force
    }
}
'@) -Expected 1

Assert-AddMember 'InputObject form' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        Add-Member -InputObject $item -NotePropertyName PpacEnvId -NotePropertyValue $envId
    }
}
'@) -Expected 1

Assert-AddMember 'Different target' (@'
function Get-Fixture {
    $resCol = @()
    $envObj = @{}

    foreach ($item in $resCol) {
        $envObj | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $envId
    }
}
'@)

Assert-AddMember 'Additional statement' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $envId
        $item.Marker = $true
    }
}
'@)

Assert-AddMember 'Conditional note property' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        if ($item.Id) {
            $item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $envId
        }
    }
}
'@)

Assert-AddMember 'Other member type' (@'
function Get-Fixture {
    $resCol = @()

    foreach ($item in $resCol) {
        $item | Add-Member -MemberType ScriptProperty -Name PpacEnvId -Value { $envId }
    }
}
'@)

Assert-AddMember 'Outside the module' $loop -Directory 'build'

Write-Output "Add-Member rule checks passed: $script:caseCount cases."
