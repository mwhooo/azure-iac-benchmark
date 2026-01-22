# Azure IaC Benchmark 🏁

A fair, reproducible benchmark comparing deployment speeds of **Bicep**, **Terraform**, **OpenTofu**, and **Pulumi** on Azure.

![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Bicep](https://img.shields.io/badge/Bicep-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?style=flat&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iIzAwMCIgZD0iTTEyIDBMMS42MDggNnYxMkwxMiAyNGwxMC4zOTItNlY2TDEyIDB6bTAgMi40bDguNCA0Ljh2OS42bC04LjQgNC44LTguNC00LjhWNy4ybDguNC00Ljh6Ii8+PHBhdGggZmlsbD0iIzAwMCIgZD0iTTEyIDYuNTRMNi41NCAxMnY0LjkyTDEyIDE3LjQ2bDUuNDYtLjU0VjEyTDEyIDYuNTR6Ii8+PC9zdmc+&logoColor=black)
![Pulumi](https://img.shields.io/badge/Pulumi-8A3391?style=flat&logo=pulumi&logoColor=white)

## 📊 Benchmark Results

Results from 3 iterations on identical Azure resources (January 2026):

<p align="center">
  <img src="assets/benchmark-report.png" alt="Azure IaC Benchmark Report" width="900">
</p>

### Deployment Times

| Tool | Min | Max | Average |
|------|-----|-----|---------|
| 🥇 Pulumi | 23.13s | 24.23s | **23.64s** |
| 🥈 Bicep | 34.73s | 35.62s | **35.22s** |
| 🥉 Terraform | 42.15s | 46.81s | **44.15s** |
| 🔶 OpenTofu | 44.12s | 45.84s | **44.84s** |

### Destroy Times

| Tool | Min | Max | Average |
|------|-----|-----|---------|
| 🥇 Pulumi | 13.55s | 15.17s | **14.12s** |
| 🥈 Bicep | 16.82s | 29.54s | **21.39s** |
| 🥉 Terraform | 60.32s | 61.87s | **60.93s** |
| 🔶 OpenTofu | 59.42s | 63.23s | **61.15s** |

### 🏆 Winners

- **Fastest Deploy**: Pulumi (23.64s avg) - 49% faster than Bicep, 87% faster than Terraform/OpenTofu
- **Fastest Destroy**: Pulumi (14.12s avg) - 51% faster than Bicep, 332% faster than Terraform/OpenTofu
- **Most Consistent**: Pulumi (smallest variance across iterations)
- **Note**: OpenTofu and Terraform have nearly identical performance (expected as OpenTofu is a Terraform fork)

### � Methodology

> **How we measure**: Each tool deploys identical resources to the same Azure region (West Europe). Timing measures only the deployment/destroy phase—tool initialization and setup are excluded. All tools use their default parallelism settings. Results are averaged across multiple iterations to reduce variance from network latency and Azure API response times. The benchmark script and all infrastructure code are open source for full transparency.

### �🔍 Why Terraform/OpenTofu Are Slower

Terraform and OpenTofu consistently show longer deployment and especially destroy times compared to Bicep and Pulumi. This is due to fundamental architectural differences, not implementation quality:

| Factor | Terraform/OpenTofu | Bicep | Pulumi |
|--------|-------------------|-------|--------|
| **State Management** | Client-side state file that must be read, reconciled, and written | Stateless - Azure IS the state | Lightweight state with efficient diffing |
| **Plan Computation** | Always computes full execution plan before apply | No plan phase - direct ARM submission | Parallel resource graph analysis |
| **API Layer** | Provider abstraction → Azure API (extra hop) | Direct ARM API compilation | Native Azure SDK calls |
| **Parallelization** | Conservative default parallelism (`-parallelism=10`) | ARM handles orchestration | Aggressive automatic parallelization |
| **Destroy Behavior** | Sequential dependency-ordered deletion with confirmations | Single ARM deletion call | Parallel deletion with dependency awareness |

**Key Takeaways:**

1. **State overhead**: Terraform's state file is a feature (drift detection, import, collaboration), but adds I/O overhead. Bicep uses Azure Resource Manager as its source of truth.

2. **Plan phase**: Even with `--auto-approve`, Terraform must compute what changes to make. Bicep compiles directly to an ARM template that Azure evaluates.

3. **Provider architecture**: Terraform's provider model enables multi-cloud support but adds an abstraction layer. Bicep and Pulumi talk directly to Azure APIs.

4. **Destroy is the biggest gap**: Terraform's destroy is notably slower (4x) because it carefully sequences deletions and waits for confirmations. ARM deployments can delete resource groups atomically.

> **Note**: These tradeoffs may be worthwhile for your use case. Terraform/OpenTofu offer superior multi-cloud support, mature ecosystem, and excellent state management for team collaboration. Choose based on your requirements, not just speed.

## 🏗️ Resources Deployed

Each tool deploys identical infrastructure:

- **Virtual Network** with 3 subnets (10.0.0.0/16)
  - Default subnet (10.0.0.0/24)
  - Private subnet (10.0.1.0/24)
  - Private subnet 2 (10.0.2.0/24)
- **Network Security Group** with 3 rules (HTTP, HTTPS, SSH)
- **Storage Account** (Standard_LRS, StorageV2)
- **App Service Plan** (Linux, B1 SKU)
- **Log Analytics Workspace** (30-day retention)

## 🚀 Quick Start

### Prerequisites

| Tool | Installation |
|------|--------------|
| Azure CLI | [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Bicep CLI | Included with Azure CLI 2.20.0+ |
| Terraform | [Download](https://www.terraform.io/downloads) (v1.0+) |
| OpenTofu | [Install Guide](https://opentofu.org/docs/intro/install/) (v1.6+) |
| Pulumi | [Install Guide](https://www.pulumi.com/docs/get-started/install/) (v3.0+) |
| .NET SDK | [Download](https://dotnet.microsoft.com/download) (8.0+) |

> **Note on Pulumi language choice**: This benchmark uses Pulumi with C#/.NET rather than Python. While Python Pulumi performs equally well at applying infrastructure state, the CI/CD workflow initialization overhead (creating virtual environments, installing pip dependencies) significantly increases total pipeline runtime. .NET's `dotnet restore` is considerably faster, making it more suitable for CI/CD benchmarking scenarios.

### One-Command Setup

```bash
# Clone the repo
git clone https://github.com/mwhooo/azure-iac-benchmark.git
cd azure-iac-benchmark

# Login to Azure (required!)
az login

# Run setup (creates resource groups, initializes all tools)
./setup.sh
```

> ⚠️ **Important**: You must be logged in to Azure CLI (`az login`) before running any benchmark scripts. All tools (Bicep, Terraform, OpenTofu, Pulumi) rely on your Azure CLI credentials for authentication. The setup script will verify this, but deployments will fail if you're not authenticated.

The setup script will:
1. ✅ Check all prerequisites are installed
2. ✅ Verify Azure CLI login
3. ✅ Create 4 resource groups (one per tool)
4. ✅ Initialize Terraform with providers
5. ✅ Initialize OpenTofu with providers
6. ✅ Create Pulumi virtual environment and stack
7. ✅ Verify Bicep templates compile

### Run Benchmark

```bash
# Run 3 iterations (default)
./run-iterations.sh

# Run 5 iterations for more statistical significance
./run-iterations.sh 5
```

Results are saved to `results/` directory:
- **JSON**: `benchmark_TIMESTAMP.json` - Raw data for programmatic access
- **HTML**: `benchmark_TIMESTAMP.html` - Interactive report with charts (auto-opens in browser)

## 📁 Project Structure

```
azure-iac-benchmark/
├── bicep/                    # Bicep templates
│   ├── main-template.bicep
│   ├── main-template.bicepparam
│   └── bicep-modules/        # Reusable modules
├── terraform/                # Terraform configuration
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── opentofu/                 # OpenTofu configuration (Terraform-compatible)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── pulumi-dotnet/            # Pulumi C#/.NET project
│   ├── Program.cs
│   ├── Pulumi.yaml
│   ├── Pulumi.benchmark.yaml # Stack configuration
│   └── azure-iac-benchmark.csproj
├── results/                  # Benchmark results (gitignored)
│   ├── benchmark_*.json      # Raw timing data
│   └── benchmark_*.html      # Interactive HTML reports
├── setup.sh                  # One-command setup
├── run-iterations.sh         # Multi-iteration benchmark
└── run-benchmark.sh          # Single benchmark with options
```

## 📊 HTML Reports

After running the benchmark, an interactive HTML report is automatically generated and opened in your browser.

**Features:**
- 🏆 **Winner banner** with overall champion
- 📊 **Tool cards** with deploy/destroy times and ranges  
- 📈 **Bar charts** comparing average deploy and destroy times
- 📉 **Line chart** showing performance consistency per iteration
- ⚖️ **Comparison table** with percentage differences vs winner

Reports are saved to `results/benchmark_TIMESTAMP.html` and can be shared or archived.

## ⚙️ Configuration

### Custom Location

```bash
# Set location before running setup
export LOCATION=eastus
./setup.sh
```

### Custom Resource Groups

```bash
export BICEP_RG=my-bicep-rg
export TERRAFORM_RG=my-terraform-rg
export OPENTOFU_RG=my-opentofu-rg
export PULUMI_RG=my-pulumi-rg
./setup.sh
```

## 🔍 Why These Results?

### Pulumi's Speed Advantage

1. **Azure Native Provider** - Direct ARM API calls without translation layers
2. **Parallel Execution** - Deploys independent resources simultaneously
3. **Efficient State Management** - Optimized diffing algorithms
4. **Native Destroy** - Built-in resource deletion vs manual cleanup

### Terraform's Consistency

- Most consistent deploy times (lowest variance)
- Mature provider with predictable behavior
- Slower destroy due to strict dependency ordering

### Bicep's Variability

- Native Azure tool, no additional runtime
- Higher variance due to ARM deployment engine
- No native destroy command (requires manual resource deletion)

### OpenTofu Comparison

- Open-source fork of Terraform (MPL 2.0 license)
- Uses same HCL configuration language
- Compatible with Terraform providers
- Community-driven development
- Performance should be very similar to Terraform

## 📈 Methodology

- All tools deploy to **separate resource groups** in the same region
- Timing measured with `date +%s.%N` (nanosecond precision)
- Each iteration: **full deploy → verify → full destroy**
- Output suppressed to eliminate I/O timing differences
- Same Azure subscription and network conditions
- Resources verified identical across all four tools

## 🧹 Cleanup

Remove all benchmark resources:

```bash
az group delete -n azure-iac-benchmark-bicep-rg --yes --no-wait
az group delete -n azure-iac-benchmark-terraform-rg --yes --no-wait
az group delete -n azure-iac-benchmark-opentofu-rg --yes --no-wait
az group delete -n azure-iac-benchmark-pulumi-rg --yes --no-wait
```

## 🤖 GitHub Actions

Run benchmarks directly from GitHub without local setup:

### Required Azure Roles

The service principal needs these roles at the **subscription level**:

| Role | Purpose |
|------|---------|
| **Contributor** | Create/delete resource groups, deploy all resources (VNets, Storage, App Service, etc.) |

> **Note**: `Contributor` is sufficient for this benchmark. For production workloads, consider more restrictive custom roles.

### Setup Steps

1. **Create App Registration & Service Principal**:
   ```bash
   # Create the app registration and capture the appId
   APP_ID=$(az ad app create --display-name "iac-benchmark-github" --query appId -o tsv)
   echo "App ID: $APP_ID"
   
   # Create a service principal for the app
   az ad sp create --id $APP_ID
   
   # Get your subscription ID
   SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   
   # Assign Contributor role at subscription level
   az role assignment create \
     --assignee $APP_ID \
     --role Contributor \
     --scope /subscriptions/$SUBSCRIPTION_ID
   ```

2. **Configure Federated Credentials**: Set up OIDC trust between GitHub and Azure
   
   You need **two** federated credentials - one for the `main` branch and one for manual `workflow_dispatch` runs:
   
   ```bash
   # Federated credential for main branch pushes
   az ad app federated-credential create --id $APP_ID --parameters '{
     "name": "github-actions-main",
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "repo:<your-github-username>/azure-iac-benchmark:ref:refs/heads/main",
     "audiences": ["api://AzureADTokenExchange"],
     "description": "GitHub Actions - main branch"
   }'
   
   # Federated credential for manual workflow dispatch
   az ad app federated-credential create --id $APP_ID --parameters '{
     "name": "github-actions-dispatch",
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "repo:<your-github-username>/azure-iac-benchmark:environment:production",
     "audiences": ["api://AzureADTokenExchange"],
     "description": "GitHub Actions - workflow dispatch"
   }'
   ```
   
   > **Important**: Replace `<your-github-username>` with your actual GitHub username or organization name.

3. **Add GitHub Secrets**: Go to your repo → Settings → Secrets and variables → Actions, and add:
   
   | Secret Name | Value | How to get it |
   |-------------|-------|---------------|
   | `AZURE_CLIENT_ID` | The App Registration ID | `echo $APP_ID` or find in Azure Portal → App registrations |
   | `AZURE_TENANT_ID` | Your Azure AD tenant ID | `az account show --query tenantId -o tsv` |
   | `AZURE_SUBSCRIPTION_ID` | Your subscription ID | `az account show --query id -o tsv` |

4. **Run Benchmark**: Go to Actions → "Run IaC Benchmark" → "Run workflow"
   - Choose number of iterations (1, 3, or 5)
   - Results are uploaded as artifacts
   - Summary appears in the workflow run

### Why OIDC?

This approach uses **federated identity** (no stored secrets) which is more secure than storing service principal credentials:
- ✅ No client secrets to rotate
- ✅ Short-lived tokens (valid only for workflow run duration)
- ✅ Scoped to specific repos/branches
- ✅ Azure AD audit logs show exactly which workflow authenticated

## 🤝 Contributing

Contributions welcome! Ideas for improvement:

- [x] ~~Add OpenTofu to the comparison~~
- [x] ~~GitHub Actions workflow for automated benchmarks~~
- [ ] Add AWS CDK / CloudFormation comparison
- [ ] More complex infrastructure scenarios
- [ ] Cost comparison alongside speed
- [ ] Memory/CPU usage during deployments

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

*Benchmark conducted on Azure West Europe region. Your results may vary based on region, subscription type, and network conditions.*
