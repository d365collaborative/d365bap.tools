$script:Ps1BapAccessTokenEndpoints = [ordered]@{
	'https://service.powerapps.com'        = [pscustomobject]@{ Switch = 'Bap'; Name = 'Business Application Platform' }
	'https://api.powerplatform.com'        = [pscustomobject]@{ Switch = 'PowerPlatform'; Name = 'Power Platform API' }
	'065d9450-1e87-434e-ac2f-69af271549ed' = [pscustomobject]@{ Switch = 'PowerPlatformAdmin'; Name = 'Power Platform admin API' }
	'https://graph.microsoft.com'          = [pscustomobject]@{ Switch = 'Graph'; Name = 'Microsoft Graph' }
}

function ConvertTo-Ps1BapAccessTokenResourceKey {
	param([string] $Value)

	"$Value".Trim().TrimEnd('/').ToLowerInvariant(); return
}

function Get-Ps1BapAccessTokenEndpoint {
	param([string] $Value)

	$key = ConvertTo-Ps1BapAccessTokenResourceKey $Value
	if ($script:Ps1BapAccessTokenEndpoints.Contains($key)) {
		$script:Ps1BapAccessTokenEndpoints[$key]; return
	}
	$null; return
}

function Get-Ps1BapAccessTokenLiteral {
	param($Argument)

	if ($Argument -is [Management.Automation.Language.StringConstantExpressionAst]) { $Argument.Value; return }
	if ($Argument -is [Management.Automation.Language.ExpandableStringExpressionAst] -and $Argument.NestedExpressions.Count -eq 0) { $Argument.Value; return }
	$null; return
}

function Get-Ps1AccessTokenDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSourceWithTepp')) { return }

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName -or ($commandName -split '\\')[-1] -ine 'Get-BapAccessToken') { continue }

		$tmpElements = @($itemCommand.CommandElements)
		$argument = $null
		$extent = $null

		for ($index = 1; $index -lt $tmpElements.Count; $index++) {
			$element = $tmpElements[$index]
			if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if (-not 'ResourceUrl'.StartsWith($element.ParameterName, [StringComparison]::OrdinalIgnoreCase)) { continue }

			$argument = $element.Argument
			$extent = $element.Extent
			if ($null -eq $argument -and $index + 1 -lt $tmpElements.Count) {
				$next = $tmpElements[$index + 1]
				if ($next -isnot [Management.Automation.Language.CommandParameterAst]) {
					$argument = $next
					$extent = $next.Extent
				}
			}
			break
		}

		if ($null -eq $argument -and $tmpElements.Count -gt 1) {
			$first = $tmpElements[1]
			if ($first -isnot [Management.Automation.Language.CommandParameterAst] -and
				-not ($first -is [Management.Automation.Language.VariableExpressionAst] -and $first.Splatted)) {
				$argument = $first
				$extent = $first.Extent
			}
		}

		$value = Get-Ps1BapAccessTokenLiteral $argument
		if ([string]::IsNullOrWhiteSpace($value)) { continue }

		$endpoint = Get-Ps1BapAccessTokenEndpoint $value
		if ($null -eq $endpoint) { continue }

		New-Ps1Diagnostic $Path 'PSUseBapAccessTokenEndpointSwitch' "Replace -ResourceUrl '$value' with -$($endpoint.Switch) for the $($endpoint.Name) audience. The audience stays defined once in Get-BapAccessToken." $extent
	}
}
