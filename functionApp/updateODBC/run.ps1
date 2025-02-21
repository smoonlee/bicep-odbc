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
$vmNameArray = $env:vmNameArray -split ','

# Loop through the VM names and apply ODBC configurations
foreach ($vmName in $vmNameArray) {
    $vmName = $vmName.Trim("'"," ")
    
    try {
        $vm = Get-AzVM -ResourceName $vmName -ErrorAction Stop
        $vmResourceGroup = $vm.ResourceGroupName

        foreach ($odbcConfig in $odbcConfigs) {
            # Create the PowerShell script to be executed on the VM
            $script = @"
Add-OdbcDsn -Name '$($odbcConfig.dsnName)' -DriverName '$($odbcConfig.dsnDriverName)' -DsnType 'System' -SetPropertyValue @('Server=$($odbcConfig.dsnFqdn)')
"@

            # Execute the PowerShell script on the VM using Azure VM extension
            $runPowerShellCmd = Invoke-AzVMRunCommand -ResourceGroupName $vmResourceGroup -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
            
            Write-Host "Successfully configured ODBC on VM: $vmName (Status: $($runPowerShellCmd.Status))"
        }
    } catch {
        Write-Error "Failed to configure ODBC on VM: $vmName. Error: $_"
    }
}
