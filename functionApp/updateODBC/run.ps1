using namespace System.Net

param($Request)

# Variables
Update-AzConfig -DisplayBreakingChangeWarning $false
$storageAccountName = 'stbwcodbcdevweu'
$storageTableName = 'odbcDSN'

# Authenticate to Azure and fetch ODBC configurations from Table Storage
$token = (Get-AzAccessToken -ResourceUrl "https://storage.azure.com").Token
$headers = @{
    Authorization  = "Bearer $token"
    "x-ms-version" = "2020-12-06"
    Accept         = "application/json"
}
$uri = "https://$storageAccountName.table.core.windows.net/$storageTableName()"
$data = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ContentType "application/json"

# Assuming the response from Table Storage contains entities in the `value` array
$odbcConfigs = $data.value

# Array of VM names
$vmNameArray = @('vm-windows-01', 'vm-windows-02')

# Loop through the VM names and send ODBC configuration for installation
foreach ($vmName in $vmNameArray) {
    foreach ($odbcConfig in $odbcConfigs) {
        # Create the PowerShell script to be executed on the VM
        $script = @"
Add-OdbcDsn -Name '$($odbcConfig.dsnName)' -DriverName '$($odbcConfig.dsnDriverName)' -DsnType 'System' -SetPropertyValue @('Server=$($odbcConfig.dsnFqdn)')
"@

        # Send the PowerShell script to the VM using Azure VM extension
        $runPowerShellCmd = Invoke-AzVMRunCommand -ResourceGroupName 'rg-compute-dev-weu' -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString $script

        Write-Output "Running ODBC configuration on $vmName using Azure VM RunPowerShellCommand: $runPowerShellCmd.Status"
    }
}
