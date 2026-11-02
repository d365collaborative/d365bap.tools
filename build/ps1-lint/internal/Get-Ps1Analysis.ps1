# Rule applicability lives in one table so every rule asks the same question.
# Include keys are ORed; any Exclude key that is set makes the rule skip the
# file. The values are flags on the scope object built by
# Get-Ps1AnalysisScope, so a rule never normalizes a path on its own.
$script:Ps1RuleScope = @{
	ModuleSource         = @{ Include = @('IsModuleSource'); Exclude = @('IsTestsFile', 'IsTeppFolder') }
	ModuleSourceWithTepp = @{ Include = @('IsModuleSource'); Exclude = @('IsTestsFile') }
	ModuleOrBuild        = @{ Include = @('IsModuleSource', 'IsBuildFolder'); Exclude = @('IsTestsFile', 'IsTeppFolder') }
	ModuleOrLintTooling  = @{ Include = @('IsModuleSource', 'IsLintTooling'); Exclude = @('IsTestsFile', 'IsTeppFolder') }
	PublicFunction       = @{ Include = @('IsPublicFunctionFile'); Exclude = @() }
	FunctionFile         = @{ Include = @('IsFunctionFile'); Exclude = @('IsTestsFile') }
	OutputTypeFile       = @{ Include = @('IsPublicFunctionFile', 'IsInternalFunctionFile'); Exclude = @('IsTestsFile', 'IsTeppFolder') }
	RepositoryScript     = @{ Include = @('IsRepositoryScript'); Exclude = @('IsTestsFile', 'IsTestFolder', 'IsTeppFolder') }
	Documentation        = @{ Include = @(); Exclude = @('IsTestsFile', 'IsTestFolder', 'IsTeppFolder', 'IsTeppScript', 'IsBuildFolder') }
}

# Script block predicates are built once per node type. FindAll takes a
# script block, so rebuilding it per call would trade one cost for another.
$script:Ps1NodePredicate = @{}

function Get-Ps1AnalysisScope {
	param([string] $Path)

	$normalized = $Path -replace '\\', '/'
	$fileName = [IO.Path]::GetFileName($Path)

	$hashScope = @{
		NormalizedPath           = $normalized
		FileName                 = $fileName
		FileNameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($Path)
		IsTestsFile              = $fileName -like '*Tests.ps1'
		IsTeppScript             = $fileName -like '*.tepp.ps1'
		IsTeppFolder             = $normalized -match '/d365bap\.tools/internal/tepp/'
		IsTestFolder             = $normalized -match '/d365bap\.tools/tests/'
		IsBuildFolder            = $normalized -match '/build/'
		IsLintTooling            = $normalized -match '/build/ps1-lint/'
		IsModuleRepository       = $normalized -match '/d365bap\.tools/'
		IsModuleSource           = $normalized -match '/d365bap\.tools/(functions|internal)/'
		IsPublicFunctionFile     = $normalized -match '/d365bap\.tools/functions/[^/]+\.ps1$'
		IsInternalFunctionFile   = $normalized -match '/d365bap\.tools/internal/functions/[^/]+\.ps1$'
		IsFunctionFile           = $normalized -match '/d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$'
	}
	$hashScope.IsRepositoryScript = $hashScope.IsModuleRepository -or $hashScope.IsBuildFolder
	$hashScope
}

function Test-Ps1RuleScope {
	param(
		[hashtable] $Analysis,
		[string] $Scope
	)

	$hashRuleScope = $script:Ps1RuleScope[$Scope]
	if ($null -eq $hashRuleScope) {
		throw "Unknown ps1-lint rule scope '$Scope'."
	}

	$hashScope = $Analysis.Scope
	foreach ($itemKey in $hashRuleScope.Exclude) {
		if ($hashScope[$itemKey]) { $false; return }
	}

	$hasInclude = $hashRuleScope.Include.Count -eq 0
	foreach ($itemKey in $hashRuleScope.Include) {
		if (-not $hashScope[$itemKey]) { continue }
		$hasInclude = $true
		break
	}
	$hasInclude
}

function Get-Ps1NodePredicate {
	param([string[]] $Type)

	$key = $Type -join '+'
	if ($script:Ps1NodePredicate.ContainsKey($key)) {
		$script:Ps1NodePredicate[$key]; return
	}

	$condition = @(foreach ($itemType in $Type) { '$Node -is [Management.Automation.Language.' + $itemType + ']' }) -join ' -or '
	$predicate = [scriptblock]::Create('param($Node) ' + $condition)
	$script:Ps1NodePredicate[$key] = $predicate
	$predicate
}

function Get-Ps1AstNode {
	<#
	.SYNOPSIS
		Collects AST nodes once per analysis and search root.
	#>
	param(
		[hashtable] $Analysis,
		[string[]] $Type,
		$Root
	)

	if ($null -eq $Root) { $Root = $Analysis.Ast }
	if ($null -eq $Root) { @(); return }
	if ($null -eq $Analysis.Nodes) { $Analysis.Nodes = @{} }

	$key = $Type -join '+'
	$hashRoot = $Analysis.Nodes[$Root]
	if ($null -ne $hashRoot -and $hashRoot.ContainsKey($key)) {
		$hashRoot[$key]; return
	}

	$colNodes = @($Root.FindAll((Get-Ps1NodePredicate -Type $Type), $true))
	if ($null -eq $hashRoot) {
		$hashRoot = @{}
		$Analysis.Nodes[$Root] = $hashRoot
	}
	$hashRoot[$key] = $colNodes
	$colNodes
}

function Get-Ps1TokenNode {
	<#
	.SYNOPSIS
		Collects the tokens of one kind for the analysis.
	#>
	param(
		[hashtable] $Analysis,
		[string] $Kind
	)

	if ($null -eq $Analysis.TokenCache) { $Analysis.TokenCache = @{} }
	if ($Analysis.Tokens -isnot [array]) { $Analysis.Tokens = @($Analysis.Tokens) }
	if ($Analysis.TokenCache.ContainsKey($Kind)) {
		$Analysis.TokenCache[$Kind]; return
	}

	$kindValue = [System.Management.Automation.Language.TokenKind]::$Kind
	$colTokens = @($Analysis.Tokens | Where-Object { $_.Kind -eq $kindValue })
	$Analysis.TokenCache[$Kind] = $colTokens
	$colTokens
}

function New-Ps1Diagnostic {
	<#
	.SYNOPSIS
		Creates one repository rule diagnostic.
	#>
	param(
		[string] $Path,
		[string] $Rule,
		[string] $Message,
		$Extent,
		$Line,
		$Column
	)

	if ($null -ne $Extent) {
		$Line = $Extent.StartLineNumber
		$Column = $Extent.StartColumnNumber
	}

	[pscustomobject]@{
		RuleName   = $Rule
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Line
		Column     = $Column
		Message    = $Message
	}
}

function Get-Ps1Analysis {
	param([string] $Path)
	$tokens = $null
	$parseErrors = $null
	$ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
	$hashAnalysis = @{
		Path        = $Path
		Ast         = $ast
		Tokens      = @($tokens)
		ParseErrors = @($parseErrors)
		Scope       = Get-Ps1AnalysisScope -Path $Path
		Nodes       = @{}
		TokenCache  = @{}
	}
	$hashAnalysis.CommentGroups = @(Get-Ps1CommentGroup -Analysis $hashAnalysis)
	$hashAnalysis.HelpSections = @(Get-Ps1HelpSection -Analysis $hashAnalysis)
	$hashAnalysis
}

function Get-Ps1ParseDiagnostic {
	param([hashtable] $Analysis)

	foreach ($itemError in @($Analysis.ParseErrors)) {
		if ($null -eq $itemError) { continue }

		New-Ps1Diagnostic $Analysis.Path 'PSParseError' "$($itemError.ErrorId): $($itemError.Message)" $null $itemError.Extent.StartLineNumber $itemError.Extent.StartColumnNumber
	}
}

function Get-Ps1AnalysisWorker {
	$hashWorker = @{
		RuntimeAliases        = @{}
		CommonParameters      = @{}
		Cache                 = @{}
		Configuration         = @{}
		RepositoryIndexes     = @{}
		RepositoryIndexBuilds = @{}
	}
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

	$root = $normalized.Substring(0, $index) + '/d365bap.tools'

	# A repository path above the module can also contain d365bap.tools, so a
	# build script would otherwise resolve to the enclosing checkout. Only a
	# folder that holds the module manifest or code folders is a module root.
	if (-not (Test-Path -LiteralPath (Join-Path $root 'd365bap.tools.psd1')) -and
		-not (Test-Path -LiteralPath (Join-Path $root 'functions')) -and
		-not (Test-Path -LiteralPath (Join-Path $root 'internal'))) { return }

	$root
}

function Get-Ps1RepositoryIndex {
	<#
	.SYNOPSIS
		Builds the repository metadata index once per worker.

	.DESCRIPTION
		Rules share the index. Commands holds every module function name for
		the splatting rule; Functions and OutputTypes hold parameter and output
		metadata for the alias and variable naming rules.
	#>
	param(
		[string] $ModuleRoot,
		[hashtable] $Worker
	)

	$cacheKey = ($ModuleRoot -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
	if (-not $Worker.RepositoryIndexes.ContainsKey($cacheKey)) {
		$Worker.RepositoryIndexes[$cacheKey] = @{
			Functions           = @{}
			FunctionsComplete   = $false
			OutputTypes         = @{}
			OutputTypesComplete = $false
			Commands            = @{}
			CommandsComplete    = $false
		}
	}
	$index = $Worker.RepositoryIndexes[$cacheKey]

	if ($index.FunctionsComplete -and $index.OutputTypesComplete -and $index.CommandsComplete) { $index; return }

	$hasAliasMetadata = $null -ne (Get-Command Get-Ps1AliasCommandMetadata -ErrorAction Ignore)
	$hasOutputMetadata = ($null -ne (Get-Command Get-Ps1FunctionOutputType -ErrorAction Ignore)) -and
	($null -ne (Get-Command Get-Ps1OutputTypeKind -ErrorAction Ignore))

	if (-not $hasAliasMetadata) { $index.FunctionsComplete = $true }
	if (-not $hasOutputMetadata) { $index.OutputTypesComplete = $true }

	$normalizedRoot = ($ModuleRoot -replace '\\', '/').TrimEnd('/') + '/'
	$colMetadataFolder = @('functions/', 'internal/functions/', 'internal/scripts/')
	if ($null -eq $Worker.RepositoryIndexBuilds) { $Worker.RepositoryIndexBuilds = @{} }
	$Worker.RepositoryIndexBuilds[$cacheKey] = 1 + [int] $Worker.RepositoryIndexBuilds[$cacheKey]

	# Module code lives under the module root; tests and tepp fixtures are
	# skipped below, matching the coverage the splatting rule had before the
	# index was shared.
	$colFile = @(Get-ChildItem -LiteralPath $ModuleRoot `
			-Recurse `
			-File |
		Sort-Object FullName)

	foreach ($itemFile in $colFile) {
		if ($itemFile.Extension -notin @('.ps1', '.psm1')) { continue }
		$normalized = $itemFile.FullName -replace '\\', '/'
		if ($normalized -match '/tests/') { continue }
		if ($normalized -match '/internal/tepp/') { continue }

		$tokens = $null
		$parseErrors = $null
		$ast = [Management.Automation.Language.Parser]::ParseFile($itemFile.FullName, [ref]$tokens, [ref]$parseErrors)
		if (@($parseErrors).Count -gt 0) { continue }

		$relative = $normalized.Substring($normalizedRoot.Length)
		$isMetadataFile = $itemFile.Extension -eq '.ps1' -and
		@($colMetadataFolder | Where-Object { $relative.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0

		foreach ($itemFunction in $ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
			$index.Commands[$itemFunction.Name.ToLowerInvariant()] = $itemFunction.Name

			if (-not $isMetadataFile) { continue }

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

	$index.FunctionsComplete = $true
	$index.OutputTypesComplete = $true
	$index.CommandsComplete = $true
	$index
}
