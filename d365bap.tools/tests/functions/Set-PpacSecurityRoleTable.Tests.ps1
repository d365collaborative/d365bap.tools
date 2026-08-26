Describe "Set-PpacSecurityRoleTable Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}

	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Set-PpacSecurityRoleTable).ParameterSets.Name | Should -Be '__AllParameterSets'
		}

		It 'Should have the expected parameter EnvironmentId' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['EnvironmentId']
			$parameter.Name | Should -Be 'EnvironmentId'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 0
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Role' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Role']
			$parameter.Name | Should -Be 'Role'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 1
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Table' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Table']
			$parameter.Name | Should -Be 'Table'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $True
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 2
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Create' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Create']
			$parameter.Name | Should -Be 'Create'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 3
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Read' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Read']
			$parameter.Name | Should -Be 'Read'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 4
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Write' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Write']
			$parameter.Name | Should -Be 'Write'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 5
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Delete' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Delete']
			$parameter.Name | Should -Be 'Delete'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 6
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Append' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Append']
			$parameter.Name | Should -Be 'Append'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 7
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter AppendTo' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['AppendTo']
			$parameter.Name | Should -Be 'AppendTo'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 8
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Assign' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Assign']
			$parameter.Name | Should -Be 'Assign'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 9
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
		It 'Should have the expected parameter Share' {
			$parameter = (Get-Command Set-PpacSecurityRoleTable).Parameters['Share']
			$parameter.Name | Should -Be 'Share'
			$parameter.ParameterType.ToString() | Should -Be System.String
			$parameter.IsDynamic | Should -Be $False
			$parameter.ParameterSets.Keys | Should -Be '__AllParameterSets'
			$parameter.ParameterSets.Keys | Should -Contain '__AllParameterSets'
			$parameter.ParameterSets['__AllParameterSets'].IsMandatory | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].Position | Should -Be 10
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipeline | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromPipelineByPropertyName | Should -Be $False
			$parameter.ParameterSets['__AllParameterSets'].ValueFromRemainingArguments | Should -Be $False
		}
	}

	Describe "Testing parameterset __AllParameterSets" {
		<#
		__AllParameterSets -EnvironmentId -Role -Table
		__AllParameterSets -EnvironmentId -Role -Table -Create -Read -Write -Delete -Append -AppendTo -Assign -Share
		#>
	}

	Describe "Regression - access level translation must not write back into validated parameters" {
		It 'Should not assign to any ValidateSet bound access level parameter variable' {
			# A validation attribute stays bound to the parameter variable for the entire function
			# scope, so assigning a translated depth value (e.g. "Global") back into e.g. $Read is
			# re-validated against the ValidateSet and throws a MetadataError at runtime.
			$validatedParameters = @('Create', 'Read', 'Write', 'Delete', 'Append', 'AppendTo', 'Assign', 'Share')

			$offendingAssignments = (Get-Command Set-PpacSecurityRoleTable).ScriptBlock.Ast.FindAll({
					param ($node)
					$node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
					$node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
					$node.Left.VariablePath.UserPath -in $validatedParameters
				}, $true)

			$offendingAssignments | Should -BeNullOrEmpty
		}

		# The function body requires PowerShell 7 (ConvertFrom-SecureString -AsPlainText,
		# Invoke-RestMethod -StatusCodeVariable), so the invocation test is skipped on Windows PowerShell.
		It 'Should translate the access level to the depth naming in the request payload' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
			InModuleScope d365bap.tools {
				Mock -CommandName Get-BapEnvironment -MockWith {
					[PsCustomObject][ordered]@{
						PpacEnvUri = "https://contoso.crm.dynamics.com"
						PpacEnvId  = "00000000-0000-0000-0000-000000000001"
					}
				}

				Mock -CommandName Get-AzAccessToken -MockWith {
					[PsCustomObject][ordered]@{
						Token = $(ConvertTo-SecureString -String "DummyToken" -AsPlainText -Force)
					}
				}

				Mock -CommandName Get-PpacSecurityRole -MockWith {
					[PsCustomObject][ordered]@{
						PpacRoleId          = "00000000-0000-0000-0000-000000000002"
						Name                = "Monitoring Reader"
						_parentroleid_value = $null
					}
				}

				Mock -CommandName Get-PpacSecurityRoleTable -MockWith { }

				Mock -CommandName Invoke-RestMethod -MockWith {
					if ($Method -eq 'Get' -and $Uri -like "*EntityDefinitions*") {
						[PsCustomObject][ordered]@{
							value = @(
								[PsCustomObject][ordered]@{
									LogicalName = "contosotable"
									SchemaName  = "ContosoTable"
									DisplayName = [PsCustomObject]@{ UserLocalizedLabel = [PsCustomObject]@{ Label = "Contoso Table" } }
									Privileges  = @(
										[PsCustomObject][ordered]@{
											PrivilegeId   = "00000000-0000-0000-0000-00000000000a"
											PrivilegeType = "Read"
										}
									)
								}
							)
						}
					}
					elseif ($Method -eq 'Get' -and $Uri -like "*RetrieveRolePrivilegesRole*") {
						[PsCustomObject][ordered]@{
							RolePrivileges = @()
						}
					}
				}

				# The mocked Invoke-RestMethod cannot populate the -StatusCodeVariable of the POST call,
				# so the function logs its "Failed to set the privileges" warning after the POST - expected noise.
				{
					Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "contosotable" -Read "Organization"
				} | Should -Not -Throw

				# The POSTed payload must carry the depth naming ("Global") - the untranslated
				# access level naming ("Organization") is rejected by the Dataverse Web API.
				Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
					$Method -eq 'Post' -and $Uri -like "*AddPrivilegesRole*" -and $Body -match '"Depth":\s*"Global"'
				}
			}
		}
	}

}