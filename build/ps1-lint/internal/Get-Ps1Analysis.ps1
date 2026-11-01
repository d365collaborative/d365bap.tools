function Get-Ps1Analysis {
	param([string] $Path)
	$tokens = $null
	$parseErrors = $null
	$ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
	$hashAnalysis = @{ Path = $Path; Ast = $ast; Tokens = $tokens; ParseErrors = @($parseErrors) }
	$hashAnalysis.CommentGroups = @(Get-Ps1CommentGroup -Analysis $hashAnalysis)
	$hashAnalysis.HelpSections = @(Get-Ps1HelpSection -Analysis $hashAnalysis)
	$hashAnalysis
}

function Get-Ps1ParseDiagnostic {
	param([hashtable] $Analysis)

	foreach ($itemError in @($Analysis.ParseErrors)) {
		if ($null -eq $itemError) { continue }

		[pscustomobject]@{
			RuleName   = 'PSParseError'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Analysis.Path)
			Line       = $itemError.Extent.StartLineNumber
			Column     = $itemError.Extent.StartColumnNumber
			Message    = "$($itemError.ErrorId): $($itemError.Message)"
		}
	}
}

function Get-Ps1AnalysisWorker {
	$hashWorker = @{ RuntimeAliases = @{}; CommonParameters = @{}; Cache = @{}; Configuration = @{}; RepositoryIndexes = @{} }
	foreach ($itemAlias in Get-Alias) { $hashWorker.RuntimeAliases[$itemAlias.Name] = $itemAlias.Definition }
	foreach ($itemParameter in (Get-Command Microsoft.PowerShell.Management\Remove-Item).Parameters.Values) {
		if ([Management.Automation.Cmdlet]::CommonParameters.Contains($itemParameter.Name) -or
			[Management.Automation.Cmdlet]::OptionalCommonParameters.Contains($itemParameter.Name)) {
			$hashWorker.CommonParameters[$itemParameter.Name] = $itemParameter
		}
	}
	$hashWorker
}

function Get-Ps1ModuleRoot {
	param([string] $Path)

	$normalized = $Path -replace '\\', '/'
	$marker = '/d365bap.tools/'
	$index = $normalized.LastIndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
	if ($index -lt 0) { return }

	$normalized.Substring(0, $index) + '/d365bap.tools'
}

function Get-Ps1RepositoryIndex {
	param(
		[string] $ModuleRoot,
		[hashtable] $Worker
	)

	$cacheKey = $ModuleRoot.ToLowerInvariant()
	if (-not $Worker.RepositoryIndexes.ContainsKey($cacheKey)) {
		$Worker.RepositoryIndexes[$cacheKey] = @{
			Functions           = @{}
			OutputTypes         = @{}
			FunctionsComplete   = $false
			OutputTypesComplete = $false
		}
	}
	$index = $Worker.RepositoryIndexes[$cacheKey]

	if ($index.FunctionsComplete -and $index.OutputTypesComplete) { $index; return }

	$hasAliasMetadata = $null -ne (Get-Command Get-Ps1AliasCommandMetadata -ErrorAction Ignore)
	$hasOutputMetadata = ($null -ne (Get-Command Get-Ps1FunctionOutputType -ErrorAction Ignore)) -and
	($null -ne (Get-Command Get-Ps1OutputTypeKind -ErrorAction Ignore))

	if (-not $hasAliasMetadata) { $index.FunctionsComplete = $true }
	if (-not $hasOutputMetadata) { $index.OutputTypesComplete = $true }
	if ($index.FunctionsComplete -and $index.OutputTypesComplete) { $index; return }

	foreach ($itemRelativeRoot in @('functions', 'internal/functions', 'internal/scripts')) {
		$folder = Join-Path $ModuleRoot $itemRelativeRoot
		if (-not (Test-Path -LiteralPath $folder)) { continue }

		foreach ($itemFile in @(Get-ChildItem -LiteralPath $folder -Recurse -File -Filter '*.ps1')) {
			$tokens = $null
			$parseErrors = $null
			$ast = [Management.Automation.Language.Parser]::ParseFile($itemFile.FullName, [ref]$tokens, [ref]$parseErrors)
			if (@($parseErrors).Count -gt 0) { continue }

			foreach ($itemFunction in $ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
				if (-not $index.FunctionsComplete) {
					$metadata = Get-Ps1AliasCommandMetadata $itemFunction $Worker.CommonParameters
					$index.Functions[$metadata.Name] = $metadata
				}

				if (-not $index.OutputTypesComplete) {
					$tmpTypes = @(Get-Ps1FunctionOutputType -Function $itemFunction)
					if ($tmpTypes.Count -eq 0) { continue }

					$outputKind = Get-Ps1OutputTypeKind -Types $tmpTypes
					if ($null -ne $outputKind) { $index.OutputTypes[$itemFunction.Name] = $outputKind }
				}
			}
		}
	}

	$index.FunctionsComplete = $true
	$index.OutputTypesComplete = $true
	$index
}
