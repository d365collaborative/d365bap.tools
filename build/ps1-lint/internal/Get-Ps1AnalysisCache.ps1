# Local-only result cache for repeated lint runs.
#
# Built-in analysis dominates a batch, and a local developer runs the same
# batch again after editing a file or nothing at all. The cache stores the
# per-file analysis result on disk so a later run in a new process can reuse it
# instead of paying PSScriptAnalyzer and the repository rules again.
#
# Two kinds of entry are kept per file, because they depend on different
# inputs:
#   builtin - PSScriptAnalyzer diagnostics. Keyed on the analyzed text, the
#             analyzer settings, the pinned analyzer version, and the path.
#   custom  - repository rule diagnostics. Keyed like builtin plus the
#             repository metadata the rules read (parameters, aliases, output
#             types, command names), the ps1-lint.json allowlist that applies
#             to the file, and a fingerprint of the rule implementation itself.
#             Editing one function's body does not invalidate another file's
#             custom result; changing a parameter or an output type does, and so
#             does editing a rule under build/ps1-lint/internal.
#
# The cache never runs in CI and never changes a result. Every read validates
# the schema, the key, and the entry shape; any problem falls back to the
# uncached path for the rest of the process.
$script:Ps1AnalysisCacheSchema = 'ps1-lint-analysis-v1'
$script:Ps1AnalysisCacheWriteBudget = 20000
# Shared helpers the repository rules call. Together with every
# Get-Ps1*Diagnostic.ps1 file, these make up the rule implementation whose
# fingerprint invalidates custom entries.
$script:Ps1AnalysisRuleHelperFile = @(
	'Get-Ps1Analysis.ps1'
	'Get-Ps1CommentGroup.ps1'
	'Get-Ps1HelpSection.ps1'
	'Get-Ps1AliasConfiguration.ps1'
	'Resolve-Ps1AliasCommand.ps1'
	'Invoke-Ps1Analysis.ps1'
)

function Get-Ps1TextHash {
	param([AllowEmptyString()] [string] $Text)

	$bytes = [Text.Encoding]::UTF8.GetBytes($Text)
	$hash = [Security.Cryptography.SHA256]::HashData($bytes)
	[Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-Ps1AnalysisCacheRoot {
	# The default folder sits at the repository root, three folders above this
	# file: build/ps1-lint/internal -> build/ps1-lint -> build -> repository.
	param([string] $RepositoryRoot)

	# A [string] parameter binds an omitted argument as an empty string, so
	# both an empty and a $null root mean "use the checkout that owns this
	# file".
	if ([string]::IsNullOrEmpty($RepositoryRoot)) {
		$tmpLintFolder = Split-Path $PSScriptRoot -Parent
		$tmpBuildFolder = Split-Path $tmpLintFolder -Parent
		$RepositoryRoot = Split-Path $tmpBuildFolder -Parent
	}

	$setting = "$env:PS1_LINT_CACHE"
	if ($setting -match '^(off|none|0|false|no)$') { return }
	if (-not [string]::IsNullOrWhiteSpace($setting)) {
		$setting
		return
	}

	# The cache is a local-run optimization. CI keeps the uncached path so a
	# job never reads or writes a cache folder.
	if ($env:CI -match '^(1|true|yes)$' -or $env:TF_BUILD -match '^(1|true|yes)$') { return }

	Join-Path $RepositoryRoot '.ps1-lint-cache'
}

function Get-Ps1AnalysisCacheSettingsHash {
	param([string] $SettingsPath)

	if ([string]::IsNullOrWhiteSpace($SettingsPath) -or
		-not (Test-Path -LiteralPath $SettingsPath `
				-PathType Leaf)) { return }

	Get-Ps1TextHash -Text ([IO.File]::ReadAllText($SettingsPath))
}

function Get-Ps1AnalysisCacheState {
	# The counter bounds the cache folder; a missing or unreadable state file
	# only means the budget starts over.
	param([string] $Root)

	$path = Join-Path $Root 'state.json'
	if (-not (Test-Path -LiteralPath $path `
				-PathType Leaf)) { @{ Writes = 0 } ; return }

	try {
		$state = Get-Content -LiteralPath $path `
			-Raw `
			-ErrorAction Stop |
		ConvertFrom-Json -ErrorAction Stop
		@{ Writes = [int] $state.Writes }
	}
	catch {
		@{ Writes = 0 }
	}
}

function Get-Ps1AnalysisCacheRuleCodeFingerprint {
	# Hashes the rule implementation, not the analyzed file. A local edit to a
	# rule or to a helper the rules call changes the diagnostics it produces
	# for unchanged files, so the custom key has to see it. Built-in entries do
	# not include this fingerprint; PSScriptAnalyzer is pinned and versioned
	# separately.
	#
	# The set is every repository rule file plus the shared helpers they read.
	# The fingerprint records file names and content, not paths, so moving the
	# checkout or a copy of the folder keeps the same entries.
	param([string] $RuleRoot)

	if ([string]::IsNullOrWhiteSpace($RuleRoot)) { $RuleRoot = $PSScriptRoot }

	$colFile = @(Get-ChildItem -LiteralPath $RuleRoot `
			-File `
			-Filter '*.ps1' |
		Where-Object {
			$_.Name -like 'Get-Ps1*Diagnostic.ps1' -or
			$_.Name -in $script:Ps1AnalysisRuleHelperFile
		} |
		Sort-Object Name)

	# A missing or empty rule set cannot be fingerprinted, so the session must
	# not cache at all rather than cache with a partial key.
	if ($colFile.Count -eq 0) { return }

	$colLine = @(foreach ($itemFile in $colFile) {
			"$($itemFile.Name)|$(Get-Ps1TextHash -Text ([IO.File]::ReadAllText($itemFile.FullName)))"
		})

	Get-Ps1TextHash -Text ($colLine -join "`n")
}

function New-Ps1AnalysisCacheSession {
	# Returns $null when the cache is off: CI, PS1_LINT_CACHE=off, or no
	# analyzer settings file or version. The session carries the key inputs
	# that cannot change during one process and the hit counters.
	param(
		[Parameter(Mandatory = $true)]
		$Analyzer,
		[string] $RepositoryRoot,
		# The folder that holds the rule implementation. Regression tests point
		# this at a modified copy to prove the custom key follows rule edits.
		[string] $RuleRoot,
		[int] $WriteBudget = $script:Ps1AnalysisCacheWriteBudget
	)

	try {
		if ($null -eq $Analyzer -or $null -eq $Analyzer.Version) { return }

		$root = Get-Ps1AnalysisCacheRoot -RepositoryRoot $RepositoryRoot
		if ([string]::IsNullOrWhiteSpace($root)) { return }

		$settingsHash = Get-Ps1AnalysisCacheSettingsHash -SettingsPath $Analyzer.SettingsPath
		if ($null -eq $settingsHash) { return }

		$ruleCodeFingerprint = Get-Ps1AnalysisCacheRuleCodeFingerprint -RuleRoot $RuleRoot
		if ($null -eq $ruleCodeFingerprint) { return }

		$objSession = [pscustomobject]@{
			Enabled             = $true
			Root                = $root
			EntryRoot           = Join-Path $root $script:Ps1AnalysisCacheSchema
			StatePath           = Join-Path $root 'state.json'
			SettingsHash        = $settingsHash
			AnalyzerVersion     = "$($Analyzer.Version)"
			RuleCodeFingerprint = $ruleCodeFingerprint
			WriteBudget         = $WriteBudget
			Writes              = 0
			Hits                = 0
			Misses              = 0
			ResetCount          = $false
			Fingerprints        = @{}
			RuleFingerprint     = @{}
		}

		$hashState = Get-Ps1AnalysisCacheState -Root $root
		if ([int] $hashState.Writes -gt $WriteBudget) {
			# A reset is safe: every entry is validated on read, so the next
			# run pays the uncached cost once instead of the folder growing
			# without bound.
			if (Test-Path -LiteralPath $objSession.EntryRoot `
					-PathType Container) {
				Remove-Item -LiteralPath $objSession.EntryRoot `
					-Recurse `
					-Force `
					-ErrorAction Ignore
			}
			$objSession.ResetCount = $true
		}

		$objSession
	}
	catch {
		$null
	}
}

function Get-Ps1AnalysisCacheKey {
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateSet('builtin', 'custom')]
		[ValidateNotNullOrEmpty()]
		[string] $Kind,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $TextHash,
		[string] $Fingerprint = '-'
	)

	$normalized = $Path -replace '\\', '/'
	$keyText = @(
		$script:Ps1AnalysisCacheSchema
		$Kind
		$Session.AnalyzerVersion
		$Session.SettingsHash
		$normalized
		$TextHash
		$Fingerprint
	) -join "`n"

	Get-Ps1TextHash -Text $keyText
}

function Get-Ps1AnalysisCacheEntryPath {
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Key
	)

	Join-Path (Join-Path $Session.EntryRoot $Key.Substring(0, 2)) "$Key.json"
}

function ConvertTo-Ps1CachedDiagnostic {
	param($Diagnostic)

	[pscustomobject]@{
		RuleName   = "$($Diagnostic.RuleName)"
		Severity   = "$($Diagnostic.Severity)"
		ScriptName = "$($Diagnostic.ScriptName)"
		Line       = $Diagnostic.Line
		Column     = $Diagnostic.Column
		Message    = "$($Diagnostic.Message)"
	}
}

function Read-Ps1AnalysisCacheEntry {
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Key,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EntryPath
	)

	try {
		if (-not (Test-Path -LiteralPath $EntryPath `
					-PathType Leaf)) { return }

		$entry = Get-Content -LiteralPath $EntryPath `
			-Raw `
			-ErrorAction Stop |
		ConvertFrom-Json -ErrorAction Stop

		# A stale file, a schema change, or a hash collision must never pass as
		# a hit, so the key is checked again from the stored copy.
		if ($entry.Schema -ne $script:Ps1AnalysisCacheSchema -or $entry.Key -ne $Key) { return }

		[pscustomobject]@{
			Diagnostics = @(foreach ($itemDiagnostic in @($entry.Diagnostics)) {
					ConvertTo-Ps1CachedDiagnostic -Diagnostic $itemDiagnostic
				})
			ParseFailed = [bool] $entry.ParseFailed
		}
	}
	catch {
		$Session.Enabled = $false
	}
}

function Write-Ps1AnalysisCacheEntry {
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Key,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EntryPath,
		[object[]] $Diagnostics = @(),
		[bool] $ParseFailed = $false
	)

	if (-not $Session.Enabled) { return }

	$tempPath = "$EntryPath.$PID.tmp"
	try {
		$directory = Split-Path $EntryPath -Parent
		if (-not (Test-Path -LiteralPath $directory `
					-PathType Container)) {
			New-Item -ItemType Directory `
				-Path $directory `
				-Force > $null
		}

		$hashPayload = [ordered]@{
			Schema      = $script:Ps1AnalysisCacheSchema
			Key         = $Key
			ParseFailed = $ParseFailed
			Diagnostics = @(foreach ($itemDiagnostic in @($Diagnostics)) {
					[ordered]@{
						RuleName   = "$($itemDiagnostic.RuleName)"
						Severity   = "$($itemDiagnostic.Severity)"
						ScriptName = "$($itemDiagnostic.ScriptName)"
						Line       = $itemDiagnostic.Line
						Column     = $itemDiagnostic.Column
						Message    = "$($itemDiagnostic.Message)"
					}
				})
		}

		# A whole entry is written to a temporary name first, so a reader never
		# sees a partial file from a concurrent local run.
		$hashPayload |
		ConvertTo-Json -Depth 4 `
			-Compress |
		Set-Content -LiteralPath $tempPath `
			-Encoding utf8 `
			-NoNewline
		Move-Item -LiteralPath $tempPath `
			-Destination $EntryPath `
			-Force
		$Session.Writes = $Session.Writes + 1
	}
	catch {
		Remove-Item -LiteralPath $tempPath `
			-Force `
			-ErrorAction Ignore
		$Session.Enabled = $false
	}
}

function Get-Ps1AnalysisCacheRepositoryFingerprint {
	# Hashes the repository metadata the repository rules read: function
	# parameter names and aliases, declared output types, and command names. A
	# body-only edit leaves the fingerprint alone; a parameter or output type
	# change does not. The shared index is built on demand, once per process,
	# exactly as the rules build it, and memoized per module root.
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		$Analyzer,
		[string] $ModuleRoot
	)

	if ([string]::IsNullOrEmpty($ModuleRoot)) { '-' ; return }

	$memoKey = ($ModuleRoot -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
	if ($Session.Fingerprints.ContainsKey($memoKey)) {
		$Session.Fingerprints[$memoKey]
		return
	}

	$index = Get-Ps1RepositoryIndex -ModuleRoot $ModuleRoot `
		-Worker $Analyzer.Worker
	$colLine = @(
		foreach ($itemName in @($index.Functions.Keys | Sort-Object)) {
			$metadata = $index.Functions[$itemName]
			$tmpParameter = @(foreach ($itemParameter in @($metadata.Names.Keys | Sort-Object)) {
					"$itemParameter=$($metadata.Names[$itemParameter])"
				})
			$tmpAlias = @(foreach ($itemAlias in @($metadata.Aliases.Keys | Sort-Object)) {
					"$itemAlias>$($metadata.Aliases[$itemAlias])"
				})
			"f|$itemName|$($tmpParameter -join ',')|$($tmpAlias -join ',')"
		}
		foreach ($itemName in @($index.OutputTypes.Keys | Sort-Object)) {
			"t|$itemName|$($index.OutputTypes[$itemName])"
		}
		foreach ($itemName in @($index.Commands.Keys | Sort-Object)) {
			"c|$itemName|$($index.Commands[$itemName])"
		}
	)

	$fingerprint = Get-Ps1TextHash -Text ($colLine -join "`n")
	$Session.Fingerprints[$memoKey] = $fingerprint
	$fingerprint
}

function Get-Ps1AnalysisCacheRuleFingerprint {
	# Hashes the ps1-lint.json allowlist that applies to one file. A file whose
	# configuration is invalid returns nothing and keeps the uncached path, so
	# its configuration diagnostic is always recomputed.
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,
		[Parameter(Mandatory = $true)]
		$Analyzer
	)

	$directory = Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent
	if ($Session.RuleFingerprint.ContainsKey($directory)) {
		$Session.RuleFingerprint[$directory]
		return
	}

	try {
		$rules = Get-Ps1AliasConfiguration -Path $Path `
			-Cache $Analyzer.Worker.Configuration
	}
	catch {
		return
	}

	$fingerprint = Get-Ps1TextHash -Text (
		@(
			@($rules.AllowedCommandAliases | Sort-Object) -join ','
			@($rules.AllowedParameterAliases | Sort-Object) -join ','
		) -join "`n"
	)
	$Session.RuleFingerprint[$directory] = $fingerprint
	$fingerprint
}

function Get-Ps1AnalysisCacheCustomFingerprint {
	param(
		[Parameter(Mandatory = $true)]
		$Session,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,
		[Parameter(Mandatory = $true)]
		$Analyzer
	)

	$ruleFingerprint = Get-Ps1AnalysisCacheRuleFingerprint -Session $Session `
		-Path $Path `
		-Analyzer $Analyzer
	if ($null -eq $ruleFingerprint) { return }

	$repositoryFingerprint = Get-Ps1AnalysisCacheRepositoryFingerprint -Session $Session `
		-Analyzer $Analyzer `
		-ModuleRoot (Get-Ps1ModuleRoot -Path $Path)

	"$($Session.RuleCodeFingerprint)|$repositoryFingerprint|$ruleFingerprint"
}

function Complete-Ps1AnalysisCacheSession {
	# Stores the write counter and reports the hit rate. A local run prints one
	# line so a developer can see whether the cache helped. The counters cover
	# cache entries, not files: a file uses one built-in entry and, unless the
	# run is built-in only, one custom entry.
	param($Session)

	if ($null -eq $Session -or -not $Session.Enabled) { return }

	$total = $Session.Hits + $Session.Misses
	$rate = if ($total -gt 0) { [math]::Round(100 * $Session.Hits / $total) } else { 0 }
	Write-Host "  analysis cache: reused $($Session.Hits) of $total result(s) ($rate%), wrote $($Session.Writes) entry(ies)."

	if ($Session.Writes -eq 0) { return }

	try {
		$hashState = Get-Ps1AnalysisCacheState -Root $Session.Root
		if ($Session.ResetCount) {
			# The folder was emptied this run, so the counter starts over.
			$hashState.Writes = [int] $Session.Writes
		}
		else {
			$hashState.Writes = [int] $hashState.Writes + [int] $Session.Writes
		}
		$hashState |
		ConvertTo-Json -Depth 2 |
		Set-Content -LiteralPath $Session.StatePath `
			-Encoding utf8
	}
	catch {
		# The counter only bounds the cache folder, so losing it costs disk, not
		# correctness, and must never surface as a lint failure.
		Write-Host "  analysis cache: could not record its entry count."
	}
}
