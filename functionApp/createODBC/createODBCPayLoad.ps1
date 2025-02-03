$body = @{
    "PartitionTable" = "ODBC10"
    "RowKey"         = ""
    "dsnName"        = "dsn-connector-10"
    "dsnFQDN"        = "sql-server-prod-10.database.windows.net"
    "dsnDriverName"  = "ODBC Driver 18 for SQL Server"
} | ConvertTo-Json

$uri = 'https://func-bwcodbc-dev-weu.azurewebsites.net/api/createODBC?code=izH9AM5xqwR4g0PNyEU49fQt8eYBFSTzNbbM079uhCBqAzFuGrgBiQ%3D%3D'
$response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -ContentType "application/json"
Write-Output "Response: $($response.Content)"