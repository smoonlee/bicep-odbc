# ODBC Connector - Azure Function App

## Project Scope
 - We need to be able to deploy FQDN Connections to the ODBC Data Source Name
 - Needs to be automated and scaleable
 - Having attempted to add FQDN Connections using group policy, this is not supported, As it expects hostname only `vm-sql-prod-01` but not `vm-sql-prod-01.contoso.com`

## The Problem
In the past, when everything was on-premises and domain-joined, deploying an ODBC connection via Group Policy was simple—you'd just add vm-sql-prod-01, and it worked seamlessly.
However, when using Azure SQL with an FQDN like mydatabase.database.windows.net, you encounter the following error:

<br>
<div align="center">
  <img src="https://github.com/user-attachments/assets/71a9ff10-3c13-47c2-b934-7ffdf328362d" width="600" height="auto">
</div>
<br>
<br>

Rather than setting up a [split DNS](https://learn.microsoft.com/en-us/windows-server/networking/dns/deploy/dns-sb-with-ad) zone — which isn't ideal — tI explored alternative solutions. A Function App seemed like a promising approach, offering a scalable and eventually zero-touch deployment method.

## ODBC Windows Connector Requirements

- [Visual Studio RunTime (64x)](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#latest-microsoft-visual-c-redistributable-version)
- [ODBC Driver for SQL](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

## Azure Resouces
 - For the PoC Lab I created for testing, The Bicep deploys the following resources.
 - Two Resource Groups: `rg-computer-${environmentType}-${locationShortCode}` `rg-compute-${environmentType}-${locationShortCode}`
 - Two Windows Virtual Machines
 - Two Storage Accounts (one for ODBC Connections) (One for Function App)
 - App Service Plan (Y1)
 - Application Insights
 - Log Analytics Workspace
 - Function App
 - Key Vault (required for Function App Secrets)
 - User Managed Identity 

## Azure Role Based Assignment
| Resource        | ResouceId        | Role Assignment                 | Role Assignment Guid                 | RBAC Scope                               |
|-----------------|------------------|---------------------------------|--------------------------------------|------------------------------------------|
| Storage Account | Managed Identity | Storage Table Data Contributor  | 0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3 | Used to Create/Update/Read odbcDSN table |
| Virtual Machine | Managed Identity | Virtual Machine Contributor     | 9980e02c-c2be-4d73-94e8-173b1dc7cf3c | Required for RunPowerShellCommand        |

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
.\Infra\Invoke-AzDeployment.ps1 -targetscope sub -subscriptionId <subscriptionId> -location <location> -environmentType <dev | acc | prod> -deploy
```

