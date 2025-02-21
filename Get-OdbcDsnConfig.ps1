# Get all ODBC DSN entries
$odbcDsnEntries = Get-OdbcDsn

# Extract relevant information
$dsnDetails = $odbcDsnEntries | ForEach-Object {
    [PSCustomObject]@{
        Name       = $_.Name
        DriverName = $_.DriverName
        ServerName = $_.Attribute['Server']   # Server name from attributes
        Database   = $_.Attribute['Database'] # Database name from attributes
    }
}

# Define export path
$csvPath = "$env:USERPROFILE\Desktop\ODBC_DSNs.csv"

# Export to CSV
$dsnDetails | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Output confirmation
Write-Host "CSV file has been exported to: $csvPath" -ForegroundColor Green
