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

- **Fastest Deploy**: Pulumi (25.33s avg) - 44% faster than Terraform, 44% faster than Bicep
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

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (logged in)
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [Terraform](https://www.terraform.io/downloads) (v1.0+)
- [Pulumi](https://www.pulumi.com/docs/get-started/install/) (v3.0+)
- Python 3.8+ (for Pulumi)

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/yourusername/azure-iac-benchmark.git
   cd azure-iac-benchmark
   ```

2. **Create resource groups**
   ```bash
   az group create -n driftguard-benchmark-bicep-rg -l westeurope
   az group create -n driftguard-benchmark-terraform-rg -l westeurope
   az group create -n driftguard-benchmark-pulumi-rg -l westeurope
   ```

3. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   cd ..
   ```

4. **Initialize Pulumi**
   ```bash
   cd pulumi
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   export PULUMI_CONFIG_PASSPHRASE=""
   pulumi stack init benchmark
   pulumi config set azure-native:location westeurope
   pulumi config set resource_group_name driftguard-benchmark-pulumi-rg
   deactivate
   cd ..
   ```

### Run Benchmark

```bash
# Run 3 iterations (default)
./run-iterations.sh

# Run 5 iterations
./run-iterations.sh 5
```

Results are saved to `results/benchmark_TIMESTAMP.json`.

## 📁 Project Structure

```
azure-iac-benchmark/
├── bicep/                    # Bicep templates
│   ├── main-template.bicep
│   └── main-template.bicepparam
├── terraform/                # Terraform configuration
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── pulumi/                   # Pulumi Python project
│   ├── __main__.py
│   ├── Pulumi.yaml
│   └── requirements.txt
├── results/                  # Benchmark results
├── run-iterations.sh         # Benchmark runner script
└── README.md
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

## ⚙️ Methodology

- All tools deploy to separate resource groups in the same region (West Europe)
- Timing measured with `date +%s.%N` (nanosecond precision)
- Each iteration: full deploy → verify resources → full destroy
- Output suppressed to eliminate I/O timing differences
- Same Azure subscription and network conditions

## 🤝 Contributing

Contributions welcome! Ideas for improvement:

- [ ] Add OpenTofu to the comparison
- [ ] Add AWS CDK / CloudFormation comparison
- [ ] GitHub Actions workflow for automated benchmarks
- [ ] More complex infrastructure scenarios
- [ ] Cost comparison alongside speed

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

*Benchmark conducted on Azure West Europe region. Your results may vary based on region, subscription type, and network conditions.*
