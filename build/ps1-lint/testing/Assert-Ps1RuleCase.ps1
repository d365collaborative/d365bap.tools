<#
.SYNOPSIS
	Shared fixture helper for ps1-lint rule regression suites.

.DESCRIPTION
	Writes a temporary script, runs Get-Ps1Analysis plus one diagnostic,
	and checks diagnostic count and message fragments. Callers must
	dot-source analysis scripts at script scope via
	Get-Ps1RuleAnalysisScriptPath.
#>

function Initialize-Ps1RuleFixtureRoot {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $NamePrefix
	)

	$root = Join-Path `
		-Path ([IO.Path]::GetTempPath()) `
		-ChildPath ($NamePrefix + '-' + [guid]::NewGuid().ToString('N'))
	New-Item `
		-ItemType Directory `
		-Path $root `
		-Force > $null
	$root
}

function Get-Ps1RuleAnalysisScriptPath {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $BuildRoot,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $ScriptName
	)

	foreach ($itemName in $ScriptName) {
		Join-Path `
			-Path $BuildRoot `
			-ChildPath "ps1-lint/internal/$itemName.ps1"
	}
}

function Assert-Ps1RuleCase {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $FixtureRoot,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $DiagnosticCommand,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Label,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Source,

		[int] $Expected = 0,

		[string[]] $ExpectedText = @(),

		[string] $Directory = 'd365bap.tools/functions',

		[string] $FileName = 'Get-Fixture.ps1',

		[string] $RuleName,

		[string] $MessageLike
	)

	$folder = Join-Path `
		-Path $FixtureRoot `
		-ChildPath $Directory
	New-Item `
		-ItemType Directory `
		-Path $folder `
		-Force > $null
	$path = Join-Path `
		-Path $folder `
		-ChildPath $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(
		& $DiagnosticCommand -Analysis $analysis
	)
	if ($PSBoundParameters.ContainsKey('RuleName') -and $RuleName) {
		$colDiagnostics = @($colDiagnostics | Where-Object RuleName -eq $RuleName)
	}
	if ($PSBoundParameters.ContainsKey('MessageLike') -and $MessageLike) {
		$colDiagnostics = @($colDiagnostics | Where-Object { $_.Message -like $MessageLike })
	}
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) {
			throw "${Label}: missing '$itemFragment' in '$message'"
		}
	}
	# Dot-sourced callers share this script scope for the case counter.
	$script:caseCount++
}
