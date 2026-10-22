Describe "Set-BapToolsAuthProvider Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Set-BapToolsAuthProvider).ParameterSets.Name | Should -Be 'AzAccount', 'AzCli'
		}
		
		It 'Should have the expected parameter AzCli' {
			$parameter = (Get-Command Set-BapToolsAuthProvider).Parameters['AzCli']
			$parameter.Name | Should -Be 'AzCli'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'AzCli'
			$parameter.ParameterSets.Keys | Should -Contain 'AzCli'
			$parameter.ParameterSets['AzCli'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['AzCli'].Position | Should -Be -2147483648
			$parameter.ParameterSets['AzCli'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['AzCli'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['AzCli'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AzAccount' {
			$parameter = (Get-Command Set-BapToolsAuthProvider).Parameters['AzAccount']
			$parameter.Name | Should -Be 'AzAccount'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'AzAccount'
			$parameter.ParameterSets.Keys | Should -Contain 'AzAccount'
			$parameter.ParameterSets['AzAccount'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['AzAccount'].Position | Should -Be -2147483648
			$parameter.ParameterSets['AzAccount'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['AzAccount'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['AzAccount'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter ProgressAction' {
			$parameter = (Get-Command Set-BapToolsAuthProvider).Parameters['ProgressAction']
			$parameter.Name | Should -Be 'ProgressAction'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.ActionPreference
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be -2147483648
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
	}
	
	Describe "Testing parameterset AzAccount" {
		<#
		AzAccount -AzAccount
		AzAccount -AzAccount -ProgressAction
		#>
	}
 	Describe "Testing parameterset AzCli" {
		<#
		AzCli -AzCli
		AzCli -AzCli -ProgressAction
		#>
	}

}