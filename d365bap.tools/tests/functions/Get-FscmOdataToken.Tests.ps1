Describe "Get-FscmOdataToken Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Get-FscmOdataToken).ParameterSets.Name | Should -Be 'Default', 'Object', 'BearerToken'
		}
		
		It 'Should have the expected parameter EnvironmentId' {
			$parameter = (Get-Command Get-FscmOdataToken).Parameters['EnvironmentId']
			$parameter.Name | Should -Be 'EnvironmentId'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'Object', 'BearerToken', 'Default'
			$parameter.ParameterSets.Keys | Should -Contain 'Object'
			$parameter.ParameterSets['Object'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['Object'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Object'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Object'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Object'].ValueFromRemainingArguments | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Contain 'BearerToken'
			$parameter.ParameterSets['BearerToken'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['BearerToken'].Position | Should -Be -2147483648
			$parameter.ParameterSets['BearerToken'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['BearerToken'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['BearerToken'].ValueFromRemainingArguments | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Contain 'Default'
			$parameter.ParameterSets['Default'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['Default'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Default'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Default'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Default'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AsBearerToken' {
			$parameter = (Get-Command Get-FscmOdataToken).Parameters['AsBearerToken']
			$parameter.Name | Should -Be 'AsBearerToken'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'BearerToken'
			$parameter.ParameterSets.Keys | Should -Contain 'BearerToken'
			$parameter.ParameterSets['BearerToken'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['BearerToken'].Position | Should -Be -2147483648
			$parameter.ParameterSets['BearerToken'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['BearerToken'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['BearerToken'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AsObject' {
			$parameter = (Get-Command Get-FscmOdataToken).Parameters['AsObject']
			$parameter.Name | Should -Be 'AsObject'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'Object'
			$parameter.ParameterSets.Keys | Should -Contain 'Object'
			$parameter.ParameterSets['Object'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['Object'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Object'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Object'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Object'].ValueFromRemainingArguments | Should -Be $False
		}
	}
	
	Describe "Testing parameterset Default" {
		<#
		Default -EnvironmentId
		Default -EnvironmentId
		#>
	}
 	Describe "Testing parameterset Object" {
		<#
		Object -EnvironmentId -AsObject
		Object -EnvironmentId -AsObject
		#>
	}
 	Describe "Testing parameterset BearerToken" {
		<#
		BearerToken -EnvironmentId -AsBearerToken
		BearerToken -EnvironmentId -AsBearerToken
		#>
	}

}