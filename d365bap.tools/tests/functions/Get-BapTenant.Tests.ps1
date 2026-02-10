Describe "Get-BapTenant Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Get-BapTenant).ParameterSets.Name | Should -Be 'Default', 'Excel', 'HashTable'
		}
		
		It 'Should have the expected parameter Upn' {
			$parameter = (Get-Command Get-BapTenant).Parameters['Upn']
			$parameter.Name | Should -Be 'Upn'
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
		It 'Should have the expected parameter TenantId' {
			$parameter = (Get-Command Get-BapTenant).Parameters['TenantId']
			$parameter.Name | Should -Be 'TenantId'
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
		It 'Should have the expected parameter AsExcelOutput' {
			$parameter = (Get-Command Get-BapTenant).Parameters['AsExcelOutput']
			$parameter.Name | Should -Be 'AsExcelOutput'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'Excel'
			$parameter.ParameterSets.Keys | Should -Contain 'Excel'
			$parameter.ParameterSets['Excel'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['Excel'].Position | Should -Be -2147483648
			$parameter.ParameterSets['Excel'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['Excel'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['Excel'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AsHashTable' {
			$parameter = (Get-Command Get-BapTenant).Parameters['AsHashTable']
			$parameter.Name | Should -Be 'AsHashTable'
			$parameter.ParameterType.ToString() | Should -Be System.Management.Automation.SwitchParameter
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be 'HashTable'
			$parameter.ParameterSets.Keys | Should -Contain 'HashTable'
			$parameter.ParameterSets['HashTable'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['HashTable'].Position | Should -Be -2147483648
			$parameter.ParameterSets['HashTable'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['HashTable'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['HashTable'].ValueFromRemainingArguments | Should -Be $False
		}
	}
	
	Describe "Testing parameterset Default" {
		<#
		Default -
		Default -Upn -TenantId
		#>
	}
 	Describe "Testing parameterset Excel" {
		<#
		Excel -
		Excel -Upn -TenantId -AsExcelOutput
		#>
	}
 	Describe "Testing parameterset HashTable" {
		<#
		HashTable -
		HashTable -Upn -TenantId -AsHashTable
		#>
	}

}