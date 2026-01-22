using Pulumi;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.Network;
using Pulumi.AzureNative.Storage;
using Pulumi.AzureNative.Web;
using Pulumi.AzureNative.OperationalInsights;
using Pulumi.Random;
using System.Collections.Generic;

// Aliases to resolve ambiguous references
using NetworkInputs = Pulumi.AzureNative.Network.Inputs;
using StorageInputs = Pulumi.AzureNative.Storage.Inputs;
using WebInputs = Pulumi.AzureNative.Web.Inputs;
using OpsInputs = Pulumi.AzureNative.OperationalInsights.Inputs;

return await Pulumi.Deployment.RunAsync(() =>
{
    var config = new Config();
    var azureConfig = new Config("azure-native");

    // Get configuration values
    var resourceGroupName = config.Require("resourceGroupName");
    var location = config.Get("location") ?? "westeurope";
    var environmentName = config.Get("environmentName") ?? "test";
    var applicationName = config.Get("applicationName") ?? "drifttest";

    // Deployment flags
    var deployVnet = config.GetBoolean("deployVnet") ?? true;
    var deployNsg = config.GetBoolean("deployNsg") ?? true;
    var deployStorage = config.GetBoolean("deployStorage") ?? true;
    var deployAppServicePlan = config.GetBoolean("deployAppServicePlan") ?? true;
    var deployLogAnalytics = config.GetBoolean("deployLogAnalytics") ?? true;

    // Common tags
    var tags = new Dictionary<string, string>
    {
        ["Environment"] = environmentName,
        ["Application"] = applicationName,
        ["ResourceType"] = "Infrastructure",
        ["IaC"] = "Pulumi-DotNet"
    };

    // Generate unique suffix
    var uniqueSuffix = new RandomString("unique-suffix", new RandomStringArgs
    {
        Length = 8,
        Special = false,
        Upper = false
    });

    // Outputs dictionary
    var outputs = new Dictionary<string, object?>
    {
        ["resourceGroupName"] = resourceGroupName,
        ["uniqueSuffix"] = uniqueSuffix.Result
    };

    // Network Security Group
    NetworkSecurityGroup? nsg = null;
    if (deployNsg)
    {
        nsg = new NetworkSecurityGroup("drifttest-nsg", new NetworkSecurityGroupArgs
        {
            NetworkSecurityGroupName = "drifttest-nsg",
            ResourceGroupName = resourceGroupName,
            Location = location,
            Tags = tags,
            SecurityRules = new[]
            {
                new NetworkInputs.SecurityRuleArgs
                {
                    Name = "AllowHTTP",
                    Priority = 100,
                    Access = "Allow",
                    Direction = "Inbound",
                    Protocol = "Tcp",
                    SourcePortRange = "*",
                    DestinationPortRange = "80",
                    SourceAddressPrefix = "*",
                    DestinationAddressPrefix = "*"
                },
                new NetworkInputs.SecurityRuleArgs
                {
                    Name = "AllowHTTPS",
                    Priority = 110,
                    Access = "Allow",
                    Direction = "Inbound",
                    Protocol = "Tcp",
                    SourcePortRange = "*",
                    DestinationPortRange = "443",
                    SourceAddressPrefix = "*",
                    DestinationAddressPrefix = "*"
                },
                new NetworkInputs.SecurityRuleArgs
                {
                    Name = "DenyAllInbound",
                    Priority = 1000,
                    Access = "Deny",
                    Direction = "Inbound",
                    Protocol = "*",
                    SourcePortRange = "*",
                    DestinationPortRange = "*",
                    SourceAddressPrefix = "*",
                    DestinationAddressPrefix = "*"
                }
            }
        });
        outputs["nsgId"] = nsg.Id;
        outputs["nsgName"] = nsg.Name;
    }

    // Virtual Network
    VirtualNetwork? vnet = null;
    if (deployVnet)
    {
        vnet = new VirtualNetwork("drifttest-vnet", new VirtualNetworkArgs
        {
            VirtualNetworkName = "drifttest-vnet",
            ResourceGroupName = resourceGroupName,
            Location = location,
            Tags = tags,
            AddressSpace = new NetworkInputs.AddressSpaceArgs
            {
                AddressPrefixes = new[] { "10.0.0.0/16" }
            },
            Subnets = new[]
            {
                new NetworkInputs.SubnetArgs
                {
                    Name = "drifttest-subnet",
                    AddressPrefix = "10.0.0.0/24",
                    PrivateEndpointNetworkPolicies = "Disabled",
                    PrivateLinkServiceNetworkPolicies = "Enabled"
                },
                new NetworkInputs.SubnetArgs
                {
                    Name = "drifttest-private-subnet",
                    AddressPrefix = "10.0.1.0/24",
                    PrivateEndpointNetworkPolicies = "Disabled",
                    PrivateLinkServiceNetworkPolicies = "Enabled"
                },
                new NetworkInputs.SubnetArgs
                {
                    Name = "drifttest-private-subnet-2",
                    AddressPrefix = "10.0.2.0/24",
                    PrivateEndpointNetworkPolicies = "Disabled",
                    PrivateLinkServiceNetworkPolicies = "Enabled"
                }
            },
            EnableDdosProtection = false
        });
        outputs["vnetId"] = vnet.Id;
        outputs["vnetName"] = vnet.Name;
    }

    // Storage Account
    StorageAccount? storageAccount = null;
    if (deployStorage)
    {
        var storageAccountName = uniqueSuffix.Result.Apply(suffix => $"drifttestsa{suffix}");
        storageAccount = new StorageAccount("drifttest-storage", new StorageAccountArgs
        {
            AccountName = storageAccountName,
            ResourceGroupName = resourceGroupName,
            Location = location,
            Tags = tags,
            Sku = new StorageInputs.SkuArgs
            {
                Name = Pulumi.AzureNative.Storage.SkuName.Standard_LRS
            },
            Kind = Kind.StorageV2,
            AccessTier = AccessTier.Hot,
            AllowBlobPublicAccess = false,
            AllowSharedKeyAccess = true,
            MinimumTlsVersion = MinimumTlsVersion.TLS1_2,
            EnableHttpsTrafficOnly = true,
            IsHnsEnabled = false,
            LargeFileSharesState = LargeFileSharesState.Disabled,
            NetworkRuleSet = new StorageInputs.NetworkRuleSetArgs
            {
                DefaultAction = Pulumi.AzureNative.Storage.DefaultAction.Allow
            }
        });
        outputs["storageAccountId"] = storageAccount.Id;
        outputs["storageAccountName"] = storageAccount.Name;
    }

    // App Service Plan
    AppServicePlan? appServicePlan = null;
    if (deployAppServicePlan)
    {
        appServicePlan = new AppServicePlan("drifttest-asp", new AppServicePlanArgs
        {
            Name = "drifttest-asp",
            ResourceGroupName = resourceGroupName,
            Location = location,
            Tags = tags,
            Sku = new WebInputs.SkuDescriptionArgs
            {
                Name = "F1",
                Tier = "Free"
            },
            Reserved = false,
            ZoneRedundant = false
        });
        outputs["appServicePlanId"] = appServicePlan.Id;
        outputs["appServicePlanName"] = appServicePlan.Name;
    }

    // Log Analytics Workspace
    Workspace? logAnalytics = null;
    if (deployLogAnalytics)
    {
        var logAnalyticsName = uniqueSuffix.Result.Apply(suffix => $"drifttest-law-{suffix}");
        logAnalytics = new Workspace("drifttest-law", new WorkspaceArgs
        {
            WorkspaceName = logAnalyticsName,
            ResourceGroupName = resourceGroupName,
            Location = location,
            Tags = tags,
            Sku = new OpsInputs.WorkspaceSkuArgs
            {
                Name = WorkspaceSkuNameEnum.PerGB2018
            },
            RetentionInDays = 30,
            Features = new OpsInputs.WorkspaceFeaturesArgs
            {
                EnableLogAccessUsingOnlyResourcePermissions = true
            }
        });
        outputs["logAnalyticsWorkspaceId"] = logAnalytics.Id;
        outputs["logAnalyticsWorkspaceName"] = logAnalytics.Name;
    }

    return outputs;
});
