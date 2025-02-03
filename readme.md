# ODBC Connector - Azure Function App.

## Project Scope
 - We need to be able to deploy ODBC Connections to Virtual Machines
 - Needs to be automated and scaleable
 - Having attempted to add FQDN Connections using group policy, this is not supported, As it expects hostname only 'vm-sql-prod-01' but not 'vm-sql-prod-01.contoso.com'

## Azure Resouces
 - For the PoC Lab I created for testing, The Bicep deploys the following resources.
 - Two Resource Groups (rg-computer-${environmentType}-${locationShortCode} rg-compute-${environmentType}-${locationShortCode}
 - Two Windows Virtual Machines
 - Two Storage Accounts (one for ODBC Connections) (One for Function App)
 - App Service Plan (Y1)
 - Application Insights
 - Log Analytics Workspace
 - Function App
 - Key Vault (required for Function App Secrets)
 - User Managed Identity 

## Azure Role Based Assignment
| Resource        | ResouceId        | Role Assignment                 | Role Assignment Guid                 | Scope                              |
|-----------------|------------------|---------------------------------|--------------------------------------|------------------------------------|
| Storage Account | Managed Identity | Storage Table Data Contributor  | 0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3 | Used to Create/Update/Read odbcDSN |
| Virtual Machine | Managed Identity | Virtual Machine Contributor     | 9980e02c-c2be-4d73-94e8-173b1dc7cf3c | Required for RunPowerShellCommand  |

## ODBC Windows Connector Requirements

- [Visual Studio RunTime (64x)](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#latest-microsoft-visual-c-redistributable-version)
- [ODBC Driver for SQL](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

## Azure Table Storage Overview

| PartitionTable | RowKey | dsnName          | dsnFQDN                           | dsnDriverName                       |
|----------------|--------|------------------|-----------------------------------|-------------------------------------|
| ODBC01         |        | dsn-connector-01 | sql-server.database.windows.net  | ODBC Driver 18 for SQL Server        |

## Function App (WIP - Futrure Plans)
### createODBC

> JSON Body Example
``` powershell
$body = @{
    "PartitionTable" = "ODBC01"
    "dsnName"        = "dsn-connector-01"
    "dsnFQDN"        = "sql-server-prod-01.database.windows.net"
    "dsnDriverName"  = "ODBC Driver 18 for SQL Server"
} | ConvertTo-Json

$uri = '<azure-function-http-url>'
$response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -ContentType "application/json"
Write-Output "Response: $($response.Content)"
```

### updateODBCConnection
```
timer Trigger to update ODBC Connection on VM
```

## Infrastucture Deployment

> Clone Repository
``` bash
git clone https://github.com/smoonlee/bicep-odbc.git
```

> Execute Bicep
``` bash
.\Infra\.\Invoke-AzDeployment.ps1 -targetscope sub -subscriptionId <subscriptionId> -location <location> -environmentType <dev | acc | prod> -deploy
```

