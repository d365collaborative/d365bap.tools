Describe "Get-UnifiedEnvironment Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Get-UnifiedEnvironment).ParameterSets.Name | Should -Be 'Default', 'SkipVersion', 'UdeOnly', 'UseOnly'
		}
		
		It 'Should have the expected parameter EnvironmentId' {
			$parameter = (Get-Command Get-UnifiedEnvironment).Parameters['EnvironmentId']
			$parameter.Name | Should -Be 'EnvironmentId'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be -2147483648
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter SkipVersionDetails' {
			$parameter = (Get-Command Get-UnifiedEnvironment).Parameters['SkipVersionDetails']
			$parameter.Name | Should -Be 'SkipVersionDetails'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'SkipVersion'
			$parameter.ParameterSets.Keys | Should -Contain 'SkipVersion'
			$parameter.ParameterSets['SkipVersion'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['SkipVersion'].Position | Should -Be -2147483648
			$parameter.ParameterSets['SkipVersion'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['SkipVersion'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['SkipVersion'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter UdeOnly' {
			$parameter = (Get-Command Get-UnifiedEnvironment).Parameters['UdeOnly']
			$parameter.Name | Should -Be 'UdeOnly'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'UdeOnly'
			$parameter.ParameterSets.Keys | Should -Contain 'UdeOnly'
			$parameter.ParameterSets['UdeOnly'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['UdeOnly'].Position | Should -Be -2147483648
			$parameter.ParameterSets['UdeOnly'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['UdeOnly'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['UdeOnly'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter UseOnly' {
			$parameter = (Get-Command Get-UnifiedEnvironment).Parameters['UseOnly']
			$parameter.Name | Should -Be 'UseOnly'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'UseOnly'
			$parameter.ParameterSets.Keys | Should -Contain 'UseOnly'
			$parameter.ParameterSets['UseOnly'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['UseOnly'].Position | Should -Be -2147483648
			$parameter.ParameterSets['UseOnly'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['UseOnly'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['UseOnly'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AsExcelOutput' {
			$parameter = (Get-Command Get-UnifiedEnvironment).Parameters['AsExcelOutput']
			$parameter.Name | Should -Be 'AsExcelOutput'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
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
	
	Describe "Testing parameterset Default" {
		<#
		Default -
		Default -EnvironmentId -AsExcelOutput
		#>
	}
 	Describe "Testing parameterset SkipVersion" {
		<#
		SkipVersion -
		SkipVersion -EnvironmentId -SkipVersionDetails -AsExcelOutput
		#>
	}
 	Describe "Testing parameterset UdeOnly" {
		<#
		UdeOnly -
		UdeOnly -EnvironmentId -UdeOnly -AsExcelOutput
		#>
	}
 	Describe "Testing parameterset UseOnly" {
		<#
		UseOnly -
		UseOnly -EnvironmentId -UseOnly -AsExcelOutput
		#>
	}

}