---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-FscmRestService

## SYNOPSIS
Invokes a REST service operation in Finance and Supply Chain Management (FSCM).

## SYNTAX

```
Invoke-FscmRestService [-EnvironmentId] <String> [-Endpoint] <String> [[-Method] <String>]
 [[-Payload] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Calls a custom service operation exposed via the FSCM REST services endpoint (/api/services).

The caller supplies the full service path (ServiceGroup/Service/Operation) as the Endpoint,
and an optional pre-structured JSON payload for POST operations.

## EXAMPLES

### EXAMPLE 1
```
Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetData"
```

This will call the GetData operation using the default Post method, without a payload.

### EXAMPLE 2
```
Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetData" -Method Get
```

This will call the GetData operation using the default Get method, without a payload.

### EXAMPLE 3
```
$payload = '{"_contract": {"CustomerAccount": "US-001"}}'
PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetCustomer" -Payload $payload
```

This will call the GetCustomer operation using POST and pass the structured JSON payload to the service.

## PARAMETERS

### -EnvironmentId
The id of the environment you want to target.

This can be obtained from the Get-BapEnvironment cmdlet.

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

### -Endpoint
The full path to the service operation, in the format: ServiceGroup/Service/Operation.

E.g.
MyServiceGroup/MyService/MyOperation

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Method
The HTTP method to use when calling the service operation.

Valid values are: Get, Post

Defaults to: Post

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Post
Accept pipeline input: False
Accept wildcard characters: False
```

### -Payload
The raw JSON payload to send with a POST request, fully structured as expected by the service operation.

Not required for GET requests.

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
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
