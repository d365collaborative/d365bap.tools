# PSScriptAnalyzer Invoke-Formatter settings.
# Mirrors Microsoft PowerShell extension (ms-vscode.powershell) document formatter
# defaults when the user has no powershell.codeFormatting.* overrides:
#   preset = Custom
#   openBraceOnSameLine = true
#   newLineAfterOpenBrace = true
#   newLineAfterCloseBrace = true
#   pipelineIndentationStyle = NoIndentation
#   whitespace* defaults as in extension package.json
#   alignPropertyValuePairs = true
#   useCorrectCasing = false
#   ignoreOneLineBlock = true
# Indentation Kind = tab matches observed VS Code Format Document output on this
# workspace (files use tabs; extension package default Kind is space, but the
# host effectively formats with tabs here).
@{
	IncludeRules = @(
		'PSPlaceOpenBrace'
		'PSPlaceCloseBrace'
		'PSUseConsistentWhitespace'
		'PSUseConsistentIndentation'
		'PSAlignAssignmentStatement'
		'PSUseCorrectCasing'
	)

	Rules = @{
		PSPlaceOpenBrace = @{
			Enable             = $true
			OnSameLine         = $true
			NewLineAfter       = $true
			IgnoreOneLineBlock = $true
		}

		PSPlaceCloseBrace = @{
			Enable             = $true
			NewLineAfter       = $true
			IgnoreOneLineBlock = $true
			NoEmptyLineBefore  = $false
		}

		PSUseConsistentIndentation = @{
			Enable              = $true
			Kind                = 'tab'
			PipelineIndentation = 'NoIndentation'
			IndentationSize     = 4
		}

		PSUseConsistentWhitespace = @{
			Enable                                  = $true
			CheckInnerBrace                         = $true
			CheckOpenBrace                          = $true
			CheckOpenParen                          = $true
			CheckOperator                           = $true
			CheckPipe                               = $true
			CheckPipeForRedundantWhitespace         = $false
			CheckSeparator                          = $true
			CheckParameter                          = $false
			IgnoreAssignmentOperatorInsideHashTable = $true
		}

		PSAlignAssignmentStatement = @{
			Enable         = $true
			CheckHashtable = $true
		}

		PSUseCorrectCasing = @{
			Enable = $false
		}
	}
}
