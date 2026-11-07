<#
    .SYNOPSIS
        Get an OData access token for a Finance and Operations environment.

    .DESCRIPTION
        Reads cached credentials and returns a token for the environment resource. Handle the output as plain text.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER AsBearerToken
        Returns the token with a bearer prefix for header use.

    .PARAMETER AsObject
        Returns a typed object with token details.

    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv"

        Returns the raw token for the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsBearerToken

        Returns the bearer token for header use.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsBearerToken to add the bearer prefix.

    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsObject

        Returns the token as a typed object.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsObject to request the typed object.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataToken {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType([System.String], ParameterSetName = 'Default')]
	[OutputType([System.String], ParameterSetName = 'BearerToken')]
	[OutputType('D365Bap.Tools.FscmOdataToken', ParameterSetName = 'Object')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Default')]
		[Parameter(Mandatory = $true, ParameterSetName = 'BearerToken')]
		[Parameter(Mandatory = $true, ParameterSetName = 'Object')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true, ParameterSetName = 'BearerToken')]
		[switch] $AsBearerToken,

		[Parameter(Mandatory = $true, ParameterSetName = 'Object')]
		[switch] $AsObject
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if ($AsObject) {
			[PSCustomObject][ordered]@{ Token = $tokenValue } |
			Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataToken" `
				-Property `
				"Token",
			@{ Name = "BearerToken"; Expression = { "Bearer $($_.Token)" } }
		}
		elseif ($AsBearerToken) {
			"Bearer $tokenValue"
		}
		else {
			$tokenValue
		}
	}

	end {

	}
}
