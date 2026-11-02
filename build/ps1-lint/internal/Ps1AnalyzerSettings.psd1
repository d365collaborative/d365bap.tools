@{
	# The formatter and the analyzer both import this exact version. The setup
	# hook installs it. No lint path may import whatever version is newest.
	PSScriptAnalyzerVersion = '1.25.0'
	# These rules are owned by another hook or by a repository rule:
	#   PSAvoidUsingCmdletAliases  -> PSAvoidCommandAliases / PSAvoidParameterAliases
	#   PSAvoidTrailingWhitespace  -> ps1-lint format phase
	# PSShouldProcess is filtered only for module function files, where
	# PSUseShouldProcessConvention replaces it. Other paths keep the built-in
	# declaration/call check. PSUseShouldProcessForStateChangingFunctions stays
	# enabled everywhere and covers state-changing functions that never declare
	# support.
	ExcludeRule           = @(
		'PSAvoidUsingCmdletAliases'
		'PSAvoidTrailingWhitespace'
	)
	# PSScriptAnalyzer severities to collect. Parser errors are added by
	# Get-Ps1ParseDiagnostic because PSScriptAnalyzer reports them as
	# ParseError, which is not part of this list.
	Severity              = @('Error', 'Warning')
	# Build scripts and other tooling keep the historical error-only gate.
	DefaultFatalSeverity   = @('Error')
	# Module functions match the full Pester scan, which has always failed on
	# warnings. Parse errors are emitted with Error severity.
	ModuleFatalSeverity    = @('Error', 'Warning')
	ModulePathPattern      = '/d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$'
	# These built-in warnings are always fatal for module and build code, even
	# when the path keeps the historical error-only gate. They catch defects
	# that the older code would have reported but not failed.
	HighSignalRule         = @(
		'PSAvoidAssignmentToAutomaticVariable'
		'PSAvoidUsingEmptyCatchBlock'
		'PSPossibleIncorrectComparisonWithNull'
		'PSAvoidUsingInvokeExpression'
		'PSUseProcessBlockForPipelineCommand'
	)
	HighSignalPathPattern  = '/d365bap\.tools/(?!internal/tepp/|tests/)|/build/'
}
