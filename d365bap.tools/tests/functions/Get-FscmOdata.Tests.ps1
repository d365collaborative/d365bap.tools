Describe "Get-FscmOdata Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Get-FscmOdata).ParameterSets.Name | Should -Be 'NextLink', 'Default'
		}
		
		It 'Should have the expected parameter EnvironmentId' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['EnvironmentId']
			$parameter.Name | Should -Be 'EnvironmentId'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be -2147483648
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Entity' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['Entity']
			$parameter.Name | Should -Be 'Entity'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'NextLink', 'Default'
			$parameter.ParameterSets.Keys | Should -Contain 'NextLink'
			$parameter.ParameterSets['NextLink'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['NextLink'].Position | Should -Be -2147483648
			$parameter.ParameterSets['NextLink'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromRemainingArguments | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Contain 'Default'
			$parameter.ParameterSets['Default'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['Default'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Default'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Default'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Default'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter ODataQuery' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['ODataQuery']
			$parameter.Name | Should -Be 'ODataQuery'
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
		It 'Should have the expected parameter CrossCompany' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['CrossCompany']
			$parameter.Name | Should -Be 'CrossCompany'
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
		It 'Should have the expected parameter TraverseNextLink' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['TraverseNextLink']
			$parameter.Name | Should -Be 'TraverseNextLink'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'NextLink'
			$parameter.ParameterSets.Keys | Should -Contain 'NextLink'
			$parameter.ParameterSets['NextLink'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['NextLink'].Position | Should -Be -2147483648
			$parameter.ParameterSets['NextLink'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter ThrottleSeed' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['ThrottleSeed']
			$parameter.Name | Should -Be 'ThrottleSeed'
			$parameter.ParameterType.ToString() | Should -Be System.Int32
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'NextLink'
			$parameter.ParameterSets.Keys | Should -Contain 'NextLink'
			$parameter.ParameterSets['NextLink'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['NextLink'].Position | Should -Be -2147483648
			$parameter.ParameterSets['NextLink'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['NextLink'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AsExcelOutput' {
			$parameter = (Get-Command Get-FscmOdata).Parameters['AsExcelOutput']
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
	
	Describe "Testing parameterset NextLink" {
		<#
		NextLink -EnvironmentId -TraverseNextLink
		NextLink -EnvironmentId -Entity -ODataQuery -CrossCompany -TraverseNextLink -ThrottleSeed -AsExcelOutput
		#>
	}
 	Describe "Testing parameterset Default" {
		<#
		Default -EnvironmentId -Entity
		Default -EnvironmentId -Entity -ODataQuery -CrossCompany -AsExcelOutput
		#>
	}

}