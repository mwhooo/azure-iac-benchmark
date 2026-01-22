# Azure IaC Benchmark 🏁

A fair, reproducible benchmark comparing deployment speeds of **Bicep**, **Terraform**, and **Pulumi** on Azure.

![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Bicep](https://img.shields.io/badge/Bicep-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Pulumi](https://img.shields.io/badge/Pulumi-8A3391?style=flat&logo=pulumi&logoColor=white)

## 📊 Benchmark Results

Results from 3 iterations on identical Azure resources (January 2026):

### Deployment Times

| Tool | Min | Max | Average |
|------|-----|-----|---------|
| 🥉 Bicep | 35.03s | 65.70s | **45.48s** |
| 🥈 Terraform | 42.86s | 46.82s | **44.67s** |
| 🥇 Pulumi | 23.04s | 29.70s | **25.33s** |

### Destroy Times

| Tool | Min | Max | Average |
|------|-----|-----|---------|
| 🥈 Bicep | 17.57s | 28.67s | **21.39s** |
| 🥉 Terraform | 60.49s | 64.61s | **62.93s** |
| 🥇 Pulumi | 13.80s | 13.95s | **13.88s** |

### 🏆 Winners

- **Fastest Deploy**: Pulumi (25.33s avg) - 44% faster than Bicep/Terraform
- **Fastest Destroy**: Pulumi (13.88s avg) - 78% faster than Terraform, 35% faster than Bicep
- **Most Consistent**: Pulumi (smallest variance across iterations)

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
| Pulumi | [Install Guide](https://www.pulumi.com/docs/get-started/install/) (v3.0+) |
| Python | 3.8+ (for Pulumi) |

### One-Command Setup

```bash
# Clone the repo
git clone https://github.com/mwhooo/azure-iac-benchmark.git
cd azure-iac-benchmark

# Run setup (creates resource groups, initializes all tools)
./setup.sh
```

The setup script will:
1. ✅ Check all prerequisites are installed
2. ✅ Verify Azure CLI login
3. ✅ Create 3 resource groups (one per tool)
4. ✅ Initialize Terraform with providers
5. ✅ Create Pulumi virtual environment and stack
6. ✅ Verify Bicep templates compile

### Run Benchmark

```bash
# Run 3 iterations (default)
./run-iterations.sh

# Run 5 iterations for more statistical significance
./run-iterations.sh 5
```

Results are saved to `results/benchmark_TIMESTAMP.json`.

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
├── pulumi/                   # Pulumi Python project
│   ├── __main__.py
│   ├── Pulumi.yaml
│   └── requirements.txt
├── results/                  # Benchmark results (gitignored)
├── setup.sh                  # One-command setup
├── run-iterations.sh         # Multi-iteration benchmark
└── run-benchmark.sh          # Single benchmark with options
```

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

## 📈 Methodology

- All tools deploy to **separate resource groups** in the same region
- Timing measured with `date +%s.%N` (nanosecond precision)
- Each iteration: **full deploy → verify → full destroy**
- Output suppressed to eliminate I/O timing differences
- Same Azure subscription and network conditions
- Resources verified identical across all three tools

## 🧹 Cleanup

Remove all benchmark resources:

```bash
az group delete -n azure-iac-benchmark-bicep-rg --yes --no-wait
az group delete -n azure-iac-benchmark-terraform-rg --yes --no-wait
az group delete -n azure-iac-benchmark-pulumi-rg --yes --no-wait
```

## 🤝 Contributing

Contributions welcome! Ideas for improvement:

- [ ] Add OpenTofu to the comparison
- [ ] Add AWS CDK / CloudFormation comparison
- [ ] GitHub Actions workflow for automated benchmarks
- [ ] More complex infrastructure scenarios
- [ ] Cost comparison alongside speed
- [ ] Memory/CPU usage during deployments

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

*Benchmark conducted on Azure West Europe region. Your results may vary based on region, subscription type, and network conditions.*
