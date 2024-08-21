
<#
    .SYNOPSIS
        Validates a given input string and checks string is a valid GUID
        
    .DESCRIPTION
        Validates a given input string and checks string is a valid GUID by using the .NET method Guid.TryParse
        
    .PARAMETER InputObject
        The input string that should be validated
        
    .EXAMPLE
        PS C:\> Test-Guid -InputObject "3363e9e1-00d8-45a1-9c0c-b93ee03f8c13"
        
    .NOTES
        Uses .NET method [guid]::TryParse()
        
        Based on: https://tech.nicolonsky.ch/validating-a-guid-with-powershell/
        
#>
function Test-Guid {
    
    [Cmdletbinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $InputObject
    )
    process {
        return [guid]::TryParse($InputObject, $([ref][guid]::Empty))
    }
}