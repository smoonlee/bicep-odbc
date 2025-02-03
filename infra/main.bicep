targetScope = 'subscription' // Please Update this based on deploymentScope Variable

//
// Imported Parameters

@description('Azure Location')
param location string

@description('Azure Location Short Code')
param locationShortCode string

@description('Environment Type')
param environmentType string

@description('User Deployment Name')
param deployedBy string

@description('Azure Metadata Tags')
param tags object = {
  environmentType: environmentType
  deployedBy: deployedBy
  deployedDate: utcNow('yyyy-MM-dd')
}

//
// Virtual Machines
@description('The Network Security Group Name')
param networkSecurityGroupName string = 'nsg-learning-windows-${locationShortCode}'

@description('The Virtual Network Name')
param virtualNetworkName string = 'vnet-learning-windows-${locationShortCode}'

@description('The Subnet Name')
param subnetName string = 'snet-learning-windows-${locationShortCode}'

@description('The Public IP Address')
param publicIp string

@description('The names of the virtual machines')
param vmHostNames array = [
  'vm-windows-01'
  'vm-windows-02'
]

@description('The Local User Account Name')
param vmUserName string

@description('The Local User Account Password')
@secure()
param vmUserPassword string

//
// Function App
param projectName string = 'bwcodbc'
var userManagedIdentityName = 'id-${projectName}-${environmentType}-${locationShortCode}'
var keyvaultName = 'kv-${projectName}-${environmentType}'

param kvSoftDeleteRetentionInDays int = 7
param kvNetworkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}
param kvSecretArray array = [
]


// Storage Account Variables
param odbcStorageAccountName string = 'stodbc${environmentType}${locationShortCode}'
param funcStorageAccountName string = 'stfunc${projectName}${environmentType}${locationShortCode}'
param stSkuName string = 'Standard_GRS'
param stTlsVersion string = 'TLS1_2'
param stPublicNetworkAccess string = 'Enabled'
param stAllowedSharedKeyAccess bool = true
param stNetworkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}

// Log Analytics Variables
param logAnalyticsName string = 'log-${projectName}-${environmentType}-${locationShortCode}'

// Application Insights Variables
param appInsightsName string = 'appi-${projectName}-${environmentType}-${locationShortCode}'

// App Service Plan Variables
param appServicePlanName string = 'asp-${projectName}-${environmentType}-${locationShortCode}'
param aspCapacity int = 1
param aspSkuName string = 'Y1'
param aspKind string = 'linux'

// Azure Function Variables
param functionAppName string = 'func-${projectName}-${environmentType}-${locationShortCode}'

//
// Bicep Deployment Variables

param resourceGroupNames array = [
  'rg-compute-${environmentType}-${locationShortCode}'
  'rg-function-${environmentType}-${locationShortCode}'
]

//
// Azure Verified Modules - No Hard Coded Values below this line!

module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = [for (rg, i) in array(resourceGroupNames): {
  name: 'create-resource-group-${i}'
  scope: subscription()
  params: {
    name: rg
    location: location
    tags: tags
  }
}]

// Azure Bicep - Function App
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'create-userManaged-identity'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: userManagedIdentityName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM] - Key Vault
module createKeyVault 'br/public:avm/res/key-vault/vault:0.11.2' = {
  name: 'create-key-vault'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: keyvaultName
    sku: 'standard'
    location: location
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: false
    softDeleteRetentionInDays: kvSoftDeleteRetentionInDays
    networkAcls: kvNetworkAcls
    roleAssignments: [
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Administrator'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalType: 'ServicePrincipal'
      }
    ]
    secrets: kvSecretArray
  }
  dependsOn: [
    createUserManagedIdentity
  ]
}

// [AVM Module] - Storage Account ODBC
module createOdbcStorageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: 'create-storage-account-odbc'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: odbcStorageAccountName
    location: location
    skuName: stSkuName
    minimumTlsVersion: stTlsVersion
    publicNetworkAccess: stPublicNetworkAccess
    allowSharedKeyAccess: stAllowedSharedKeyAccess
    networkAcls: stNetworkAcls
    tags: tags
    tableServices: {
      enabled: true
    }
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Role Base Assignment - Storage Account
module createRoleAssignmentStorageAccount 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'create-role-assignment-storage-account'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
     principalType: 'ServicePrincipal'
     principalId: createUserManagedIdentity.outputs.principalId
     resourceId: createOdbcStorageAccount.outputs.resourceId
      roleDefinitionId: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
  }
  dependsOn: [
    createOdbcStorageAccount
  ]
}

// [AVM Module] - Storage Account - Function App
module createFuncStorageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: 'create-storage-account-func'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: funcStorageAccountName
    location: location
    skuName: stSkuName
    minimumTlsVersion: stTlsVersion
    publicNetworkAccess: stPublicNetworkAccess
    allowSharedKeyAccess: stAllowedSharedKeyAccess
    secretsExportConfiguration: {
      accessKey1: 'accessKey1'
      accessKey2: 'accessKey2'
      connectionString1: 'connectionString1'
      connectionString2: 'connectionString2'
      keyVaultResourceId: createKeyVault.outputs.resourceId
    }
    networkAcls: stNetworkAcls
    tags: tags
  }
  dependsOn: [
    createKeyVault
  ]
}

// [AVM Module] - Log Analytics
module createLogAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: 'create-log-analytics'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Application Insights
module createApplicationInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: 'create-app-insights'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    name: appInsightsName
    workspaceResourceId: createLogAnalytics.outputs.resourceId
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - App Service Plan
module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  scope: resourceGroup(resourceGroupNames[1])
  name: 'create-app-service-plan'
  params: {
    name: appServicePlanName
    skuCapacity: aspCapacity
    skuName: aspSkuName
    kind: aspKind
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Function App
module createFunctionApp 'br/public:avm/res/web/site:0.13.1' = {
  name: 'create-function-app'
  scope: resourceGroup(resourceGroupNames[1])
  params: {
    kind: 'functionapp,linux'
    name: functionAppName
    location: location
    httpsOnly: true
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    appInsightResourceId: createApplicationInsights.outputs.resourceId
    keyVaultAccessIdentityResourceId: createUserManagedIdentity.outputs.resourceId
    storageAccountRequired: true
    storageAccountResourceId: createFuncStorageAccount.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [
        createUserManagedIdentity.outputs.resourceId
      ]
    }
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=connectionString1)'
      WEBSITE_CONTENTSHARE: functionAppName
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      managedIdentityId: createUserManagedIdentity.outputs.clientId
    }
    siteConfig: {
      alwaysOn: false
      linuxFxVersion: 'POWERSHELL|7.4'
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.3'
      use32BitWorkerProcess: false
      cors: {
        allowedOrigins: ['*']
      }
    }
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: true
        name: 'scm'
      }
    ]
    logsConfiguration: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    tags: tags
  }
  dependsOn: [
    createUserManagedIdentity
    createAppServicePlan
  ]
}

// Azure Bicep - Compute
module createNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.0' = {
  name: 'createNetworkSecurityGroup'
  scope: resourceGroup(resourceGroupNames[0])
  params: {
    name: networkSecurityGroupName
    location: location
    securityRules: [
      {
        name: 'ALLOW_RDP_INBOUND_TCP'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: publicIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'create-virtual-network'
  scope: resourceGroup(resourceGroupNames[0])
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      '10.0.0.0/24'
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: '10.0.0.0/24'
        networkSecurityGroupResourceId: createNetworkSecurityGroup.outputs.resourceId
      }
    ]
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createVirtualMachine 'br/public:avm/res/compute/virtual-machine:0.8.0' = [for vmName in vmHostNames: {
  name: 'create-virtual-machine-${vmName}'
  scope: resourceGroup(resourceGroupNames[0])
  params: {
    name: vmName
    adminUsername: vmUserName
    adminPassword: vmUserPassword
    location: location
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    zone: 0
    bootDiagnostics: true
    secureBootEnabled: true
    vTpmEnabled: true
    securityType: 'TrustedLaunch'
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition-hotpatch'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            pipConfiguration: {
              name: '${vmName}-pip-01'
            }
            subnetResourceId: createVirtualNetwork.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
  }
  dependsOn: [
    createVirtualNetwork
  ]
}]
