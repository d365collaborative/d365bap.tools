<#
.SYNOPSIS
    Tests example help lint rules.

.DESCRIPTION
    Parses fixture scripts and checks example diagnostics without importing
    or running the documented commands.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1HelpDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('example-help-' + [guid]::NewGuid().ToString('N') + '.ps1')
$script:caseCount = 0

function Assert-Example {
	param([string] $Label, [string] $Source, [string[]] $Expected = @())
	[IO.File]::WriteAllText($fixturePath, $Source)
	$analysis = Get-Ps1Analysis -Path $fixturePath
	$diagnostics = @(Get-Ps1HelpDiagnostic -Analysis $analysis | Where-Object RuleName -eq 'PSHelpExample')
	$message = $diagnostics.Message -join ' '
	if ($Expected.Count -eq 0 -and $diagnostics.Count -gt 0) { throw "${Label}: unexpected diagnostics: $message" }
	foreach ($fragment in $Expected) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$fixture = @'
function New-Fixture {
<#
.SYNOPSIS
    Creates a fixture.
.PARAMETER Name
    Display name.
.PARAMETER Template
    Provisioning template.

    Default: Developer
.PARAMETER Language
    When omitted, the tenant default language is used.
.PARAMETER Currency
    Default: tenant currency
.PARAMETER Filter
    Search filter.

    Default: *
.EXAMPLE
    PS C:\> New-Fixture -Name demo

    Creates a fixture environment.
    It will use -Name demo.
    It will use the default -Template Developer.
    It uses the tenant default for -Language.
    It will use the tenant default for -Currency.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [Alias('DisplayName')]
        [string] $Name,
        [string] $Template = 'Developer',
        [string] $Language,
        [string] $Currency,
        [string] $Filter = '*'
    )
}
'@

try {
	Assert-Example 'Separate lines and documented defaults' $fixture
	Assert-Example 'It and It will are accepted' ($fixture.Replace('It will ', 'It '))
	Assert-Example 'Summary is optional' ($fixture.Replace("    Creates a fixture environment.`n", ''))
	Assert-Example '124-character summary passes' ($fixture.Replace('Creates a fixture environment.', 'x' * 124))
	Assert-Example '125-character summary fails' ($fixture.Replace('Creates a fixture environment.', 'x' * 125)) @('summary must be fewer than 125')
	Assert-Example 'A missing explicit parameter is rejected' ($fixture.Replace("    It will use -Name demo.`n", '')) @('explain -Name')
	Assert-Example 'A missing signature default is rejected' ($fixture.Replace("    It will use the default -Template Developer.`n", '')) @('explain -Template')
	Assert-Example 'A missing documented default is rejected' ($fixture.Replace("    It will use the tenant default for -Currency.`n", '')) @('explain -Currency')
	Assert-Example 'When omitted also documents a default' ($fixture.Replace("    It uses the tenant default for -Language.`n", '')) @('explain -Language')
	Assert-Example 'Explicit values override defaults' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo -Template Standard').Replace('the default -Template Developer', '-Template Standard'))
	Assert-Example 'Explicit wildcard still needs a line' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo -Filter *')) @('explain -Filter')
	Assert-Example 'Explicit wildcard can be explained' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo -Filter *').Replace('    It will use -Name demo.', "    It will use -Name demo.`n    It will search all values with -Filter *."))
	foreach ($default in @("'demo*'", "'demo?'", "'[ab]*'")) {
		Assert-Example "Implicit search default $default is exempt" ($fixture.Replace("[string] `$Filter = '*'", "[string] `$Filter = $default"))
	}
	Assert-Example 'Documented wildcard default is exempt' ($fixture.Replace("[string] `$Filter = '*'", '[string] $Filter'))
	Assert-Example 'Documented wildcard behavior is exempt' ($fixture.Replace('Default: *', 'Default: wildcard search').Replace("[string] `$Filter = '*'", '[string] $Filter'))
	Assert-Example 'Documented like searches are exempt' ($fixture.Replace('Default: *', 'Default: -like search for all values').Replace("[string] `$Filter = '*'", '[string] $Filter'))
	Assert-Example 'Typed non-search defaults still need a line' ($fixture.Replace("[string] `$Filter = '*'", '[int] $Filter = [int]60')) @('explain -Filter')
	Assert-Example 'Common parameters need a line' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo -WhatIf')) @('explain -WhatIf')
	Assert-Example 'Common parameter explanation' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo -WhatIf').Replace('    It will use -Name demo.', "    It will use -Name demo.`n    It will preview changes with -WhatIf."))
	Assert-Example 'Aliases count as the same parameter' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -DisplayName demo').Replace('It will use -Name demo.', 'It uses -DisplayName demo.'))
	Assert-Example 'Case insensitive parameter coverage' ($fixture.Replace('It will use -Name demo.', 'It will use -NAME demo.'))
	Assert-Example 'Parameter name boundaries' ($fixture.Replace('It will use -Name demo.', 'It will use -Names demo.')) @('explain -Name')
	Assert-Example 'Positional parameters need a line' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture demo').Replace("    It will use -Name demo.`n", '')) @('explain -Name')
	Assert-Example 'Positional parameters can be explained' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture demo'))
	Assert-Example 'Named parameters support disabled positional binding' ($fixture.Replace('[CmdletBinding(SupportsShouldProcess)]', '[CmdletBinding(SupportsShouldProcess, PositionalBinding = $false)]'))
	Assert-Example 'Explicit positions support disabled positional binding' ($fixture.Replace('[CmdletBinding(SupportsShouldProcess)]', '[CmdletBinding(SupportsShouldProcess, PositionalBinding = $false)]').Replace('New-Fixture -Name demo', 'New-Fixture demo'))
	Assert-Example 'Unsupported positional arguments fail clearly' ($fixture.Replace('[CmdletBinding(SupportsShouldProcess)]', '[CmdletBinding(SupportsShouldProcess, PositionalBinding = $false)]').Replace('[Parameter(Position = 0)]', '[Parameter()]').Replace('New-Fixture -Name demo', 'New-Fixture demo')) @('positional arguments could not be matched')
	Assert-Example 'Splatting cannot silently skip coverage' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture @options')) @('spell out splatted parameters')
	Assert-Example 'Summary alone cannot cover parameters' ($fixture.Replace('Creates a fixture environment.', 'Creates a fixture with -Name demo.').Replace("    It will use -Name demo.`n", '')) @('explain -Name')
	Assert-Example 'Each parameter needs its own line' ($fixture.Replace("    It will use -Name demo.`n    It will use the default -Template Developer.", '    It will use -Name demo and -Template Developer.')) @('separate It line', 'explain -Name', 'explain -Template')
	foreach ($phrase in @('Same as above.', 'As in the previous example.', 'See example 1.', 'Similar to the first example.', 'It works as before.', 'Unlike the example above, this creates a fixture.', 'As shown in example 1.', 'Same command, but with a new domain.')) {
		Assert-Example "Dependent prose: $phrase" ($fixture.Replace('Creates a fixture environment.', $phrase)) @('stand alone')
	}
	$prefix = 'It uses -Name '
	$line80 = $prefix + ('x' * (79 - $prefix.Length)) + '.'
	if ($line80.Length -ne 80) { throw 'Incorrect boundary fixture' }
	Assert-Example 'Exactly 80 characters passes' ($fixture.Replace('It will use -Name demo.', $line80))
	Assert-Example '81 characters fails' ($fixture.Replace('It will use -Name demo.', $line80 + '.')) @('80 characters or fewer')
	Assert-Example 'Aggregate prose can exceed 124 characters' $fixture
	Assert-Example 'Wrapped details fail' ($fixture.Replace('    It will use -Name demo.', "    It will use -Name`n    demo.")) @('detail lines must each start')
	Assert-Example 'Blank prose lines fail' ($fixture.Replace('    It will use -Name demo.', "    It will use -Name demo.`n")) @('exactly one blank separator')
	Assert-Example 'Code separator is required' ($fixture.Replace("New-Fixture -Name demo`n`n", "New-Fixture -Name demo`n")) @('exactly one blank separator')
	Assert-Example 'Invalid code fails clearly' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name (')) @('valid PowerShell')
	Assert-Example 'Multiline command and pipeline' ($fixture.Replace('New-Fixture -Name demo', "New-Fixture ```n        -Name demo | Select-Object -Property Name").Replace('    It will use -Name demo.', "    It will use -Name demo.`n    It returns the -Property Name."))
	Assert-Example 'Like operator is not a parameter' ($fixture.Replace('New-Fixture -Name demo', 'New-Fixture -Name demo | Where-Object { $_.Name -like "*demo*" }'))
	$lineHelp = [regex]::Replace($fixture, '(?s)<#(.*?)#>', {
			param($match)
			(($match.Groups[1].Value.Trim() -split "`n" | ForEach-Object { '# ' + $_ }) -join "`n")
		})
	Assert-Example 'Line comment help also works' $lineHelp
	$other = $fixture.Replace('New-Fixture', 'New-OtherFixture').Replace('Default: tenant currency', 'Currency code.').Replace("    It will use the tenant default for -Currency.`n", '')
	Assert-Example 'Defaults do not leak between help groups' ($fixture + "`n" + $other)
	Write-Output "$script:caseCount example-help regression checks passed."
}
finally {
	if (Test-Path -LiteralPath $fixturePath) { Remove-Item -LiteralPath $fixturePath -Force }
}
