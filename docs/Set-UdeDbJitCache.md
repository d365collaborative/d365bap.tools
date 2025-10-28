---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-UdeDbJitCache

## SYNOPSIS
Sets UDE database JIT access credentials in the local cache.

## SYNTAX

```
Set-UdeDbJitCache [-Id] <String> [-Server] <String> [-Database] <String> [-Username] <String>
 [-Password] <String> [[-Expiration] <DateTime>] [[-Role] <String>] [[-EnvironmentId] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function sets UDE database JIT access credentials in the local cache for later retrieval.

Handles storing the credentials securely using the TUN.CredentialManager module.
Made to have SSMS able to retrieve the password when connecting.

## EXAMPLES

### EXAMPLE 1
```
Set-UdeDbJitCache -Id "demo" -Server "myserver.database.windows.net" -Database "mydatabase" -Username "myuser" -Password "mypassword"
```

This will set the JIT database access credentials in the local cache for the specified ID.
It will store the server, database, username, and password securely using the TUN.CredentialManager module.

### EXAMPLE 2
```
Get-UdeDbJit -EnvironmentId "env-123" | Set-UdeDbJitCache -Id "demo" -EnvironmentId "env-123"
```

This will retrieve the JIT database access information for the specified environment ID using Get-UdeDbJit.
It will then set the JIT database access credentials in the local cache for the ID "demo".
It will store the server, database, username, and password securely using the TUN.CredentialManager module.
It will store the expiration and role as provided by Get-UdeDbJit.
It will also associate the environment details with the cached credentials.

## PARAMETERS

### -Id
The unique identifier for the JIT access credentials.

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

### -Server
The SQL Server instance name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Database
The database name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Username
The username for the JIT access credentials.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Password
The password for the JIT access credentials.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Expiration
The expiration date and time for the JIT access credentials.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: (Get-Date).AddHours(8)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The role assigned for JIT database access.
Can be either "Reader" or "Writer".

Defaults to "Reader".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: Reader
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
