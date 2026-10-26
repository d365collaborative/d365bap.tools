Describe "Get-PpacFinOpsVersion Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}

	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Get-PpacFinOpsVersion).ParameterSets.Name | Should -Be 'Default', 'Lowest', 'Highest'
		}

		It 'Should have the expected parameter AppVersion' {
			$parameter = (Get-Command Get-PpacFinOpsVersion).Parameters['AppVersion']
			$parameter.Name | Should -Be 'AppVersion'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be -2147483648
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter EnvironmentId' {
			$parameter = (Get-Command Get-PpacFinOpsVersion).Parameters['EnvironmentId']
			$parameter.Name | Should -Be 'EnvironmentId'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be -2147483648
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Oldest' {
			$parameter = (Get-Command Get-PpacFinOpsVersion).Parameters['Oldest']
			$parameter.Name | Should -Be 'Oldest'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'Lowest'
			$parameter.ParameterSets.Keys | Should -Contain 'Lowest'
			$parameter.ParameterSets['Lowest'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['Lowest'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Lowest'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Lowest'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Lowest'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Latest' {
			$parameter = (Get-Command Get-PpacFinOpsVersion).Parameters['Latest']
			$parameter.Name | Should -Be 'Latest'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'Highest'
			$parameter.ParameterSets.Keys | Should -Contain 'Highest'
			$parameter.ParameterSets['Highest'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['Highest'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Highest'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Highest'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Highest'].ValueFromRemainingArguments | Should -Be $False
		}
	}

	Describe "Testing parameterset Default" {
		<#
		Default -
		Default -AppVersion -EnvironmentId
		#>
	}
 	Describe "Testing parameterset Lowest" {
		<#
		Lowest -
		Lowest -AppVersion -EnvironmentId -Oldest
		#>
	}
 	Describe "Testing parameterset Highest" {
		<#
		Highest -
		Highest -AppVersion -EnvironmentId -Latest
		#>
	}

}
