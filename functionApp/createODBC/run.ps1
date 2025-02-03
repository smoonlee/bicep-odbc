using namespace System.Net

# Function parameters
param($Request, $TriggerMetadata)

# Parse the incoming JSON body
$body = $Request.RawBody | ConvertFrom-Json

# Extract parameters
$PartitionTable = $body.PartitionTable
$RowKey = $body.RowKey
$dsnName = $body.dsnName
$dsnFQDN = $body.dsnFQDN
$dsnDriverName = $body.dsnDriverName

# Azure Table Storage parameters
$storageAccountName = $env:odbcStorageAccountName
$storageTableName = $env:odbcStorageTableName

# Function to handle error responses
function Send-ErrorResponse {
    param (
        [HttpStatusCode]$statusCode,
        [string]$message
    )

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $statusCode
            Body       = $message
        })
}

# Function to authenticate and get an access token for Azure Storage
function Get-StorageAccessToken {
    try {
        return (Get-AzAccessToken -ResourceUrl "https://storage.azure.com").Token
    }
    catch {
        Write-Error "Failed to authenticate to Azure: $_"
        Send-ErrorResponse -statusCode [HttpStatusCode]::Unauthorized -message "Authentication failed: $_"
        return $null
    }
}

# Function to send a POST request to insert a new entity into Table Storage
function Send-TableStorageRequest {
    param (
        [string]$uri,
        [Hashtable]$headers,
        [string]$entityJson
    )

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $entityJson -ContentType "application/json"
        return @{ statusCode = 200; Response = $response }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Error: $errorMessage"

        if ($errorMessage -match "EntityAlreadyExists") {
            return @{ statusCode = 409; Message = "The specified entity already exists. Please check the PartitionKey and RowKey combination." }
        }
        else {
            return @{ statusCode = 500; Message = "Failed to send request to Table Storage: $errorMessage" }
        }
    }
}


# Get the access token
$token = Get-StorageAccessToken
if (-not $token) { return }

# Set authorization headers
$headers = @{
    Authorization  = "Bearer $token"
    "x-ms-version" = "2020-12-06"
    Accept         = "application/json"
}

# Construct the URL for the Table Storage API
$uri = "https://$storageAccountName.table.core.windows.net/$storageTableName()"

# Prepare the table entity
$entity = @{
    PartitionKey  = $PartitionTable
    RowKey        = $RowKey
    dsnName       = $dsnName
    dsnFQDN       = $dsnFQDN
    dsnDriverName = $dsnDriverName
}

# Convert the entity to JSON
$entityJson = $entity | ConvertTo-Json -Depth 3

# Send the request and capture the response

$response = Send-TableStorageRequest -uri $uri -headers $headers -entityJson $entityJson
Write-Output $response

if ($response.statusCode -eq '200') {
    Write-Output "ODBC Created, Responding 200!"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $response.statusCode
            Body       = 'ODBC Connector Created!'
        })
}

if ($response.statusCode -eq '500') {
    Write-Output "Failed to create ODBC: $errorMessage"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $response.statusCode
            Body       = $response.Message
        })
}