@{
    EnvironmentId = @{
        Default  = 'The id (guid) of the environment that the cmdlet will execute against.
It is the unique identifier of the environment, or the display name in the Power Platform Admin Center (PPAC).'

        Variants = @(
            @{
                Match       = '*Ppac*'
                Description = 'The id (guid) of the Power Platform environment that the cmdlet will execute against.

It is the unique identifier of the environment, or the display name in the Power Platform Admin Center (PPAC).'
            }
            @{
                Match       = '*Fscm*'
                Description = 'The id (guid) of the Finance & Supply Chain Management environment that the cmdlet will execute against.

It can be the unique identifier of the environment, or the display name in the Power Platform Admin Center (PPAC).
It can also be the LCS environment id, as shown in the Lifecycle Services project.'
            }
        )
    }

    AsExcelOutput = @{
        Default = 'Instruct the cmdlet to output all details directly to an Excel file.

The excel file will open automatically once generated. You need to save the file from inside Excel if you want to keep it.'
    }
}