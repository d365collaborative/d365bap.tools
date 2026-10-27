$scbBapTenantTenantId = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$filterWord = "$wordToComplete".Trim("'", '"')
		$provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'
		if ($provider -eq 'AzCli') {
			$tenantIds = @()
			try {
				$raw = az account list --query '[].tenantId' -o tsv 2>$null
				if ($LASTEXITCODE -eq 0 -and $raw) {
					$tenantIds = @($raw | Where-Object { $_ } | Sort-Object -Unique)
				}
			}
			catch { }
			if ($tenantIds.Count -eq 0) {
				try {
					$rawTenants = az account tenant list --query '[].tenantId' -o tsv 2>$null
					if ($LASTEXITCODE -eq 0 -and $rawTenants) {
						$tenantIds = @($rawTenants | Where-Object { $_ } | Sort-Object -Unique)
					}
				}
				catch { }
			}
			foreach ($id in ($tenantIds | Where-Object { $_ -like "$filterWord*" })) {
				[System.Management.Automation.CompletionResult]::new($id, $id, 'ParameterValue', $id)
			}
			return
		}

		$contexts = Get-AzContext -ListAvailable -ErrorAction SilentlyContinue
		if (-not $contexts) { return }

		$tenantIds = $contexts |
		Where-Object { $null -ne $_.Tenant -and $null -ne $_.Tenant.Id -and $_.Tenant.Id } |
		Select-Object -ExpandProperty Tenant |
		Select-Object -ExpandProperty Id -Unique |
		Sort-Object |
		Where-Object { $_ -like "$filterWord*" }

		foreach ($id in $tenantIds) {
			[System.Management.Automation.CompletionResult]::new($id, $id, 'ParameterValue', $id)
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.tenant.tenantid" -ScriptBlock $scbBapTenantTenantId -Mode Full
