---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacSecurityRoleTable

## SYNOPSIS
Set the table privileges of a security role in a given environment.

## SYNTAX

```
Set-PpacSecurityRoleTable [-EnvironmentId] <String> [-Role] <String> [-Table] <String> [[-Create] <String>]
 [[-Read] <String>] [[-Write] <String>] [[-Delete] <String>] [[-Append] <String>] [[-AppendTo] <String>]
 [[-Assign] <String>] [[-Share] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet sets the privileges of a table (entity) on a security role in a given Power Platform environment.

It mimics editing the table permissions in the security role editor in the Power Platform admin center, where each privilege type (Create, Read, Write, Delete, Append, AppendTo, Assign and Share) can be configured with an access level.

The access levels use the Power Platform admin center naming and are translated automatically to the Dataverse privilege depths accepted by the Web API:
"User" - Basic
"BusinessUnit" - Local
"ParentChildBusinessUnit" - Deep
"Organization" - Global
"None" - None

Privilege types that are not supplied (or set to "None") are removed from the role for the table.
Access levels of already assigned privileges are updated to the supplied values.

It uses the AddPrivilegesRole and ReplacePrivilegesRole actions of the Dataverse Web API, against the root record of the security role - the inherited business unit copies of the role are managed by Dataverse.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "businessunit" -Read "Organization"
```

This command sets the privileges of the table "businessunit" on the security role "Monitoring Reader" in the environment "ContosoEnv".
The Read privilege is set to the "Organization" access level.
All other privileges of the table are removed from the role.

### EXAMPLE 2
```
Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "Sharepoint Document" -Create "User" -Read "Organization" -Write "User" -Append "User" -AppendTo "User"
```

This command sets the privileges of the table "Sharepoint Document" on the security role "Monitoring Reader" in the environment "ContosoEnv".
The Read privilege is set to the "Organization" access level.
The Create, Write, Append and AppendTo privileges are set to the "User" access level.
The Delete, Assign and Share privileges are removed from the role.

### EXAMPLE 3
```
Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "businessunit"
```

This command removes all privileges of the table "businessunit" from the security role "Monitoring Reader" in the environment "ContosoEnv".

## PARAMETERS

### -EnvironmentId
The ID of the environment to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The security role that you want to work against.

Can be either the role name or the role ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Table
The table (entity) that you want to set the privileges for.

Can be either the table display name, the logical name or the schema name.

```yaml
Type: String
Parameter Sets: (All)
Aliases: TableName

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Create
The access level for the Create privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Read
The access level for the Read privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Write
The access level for the Write privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Delete
The access level for the Delete privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Append
The access level for the Append privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppendTo
The access level for the AppendTo privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Assign
The access level for the Assign privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Share
The access level for the Share privilege of the table.

Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".

The default value is "None".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Trygve Bechsgaard

## RELATED LINKS
