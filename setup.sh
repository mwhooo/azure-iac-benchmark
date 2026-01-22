#!/bin/bash
# =============================================================================
# Azure IaC Benchmark - Setup Script
# Initializes all tools and creates required Azure resource groups
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Azure IaC Benchmark - Setup                         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

# Configuration
LOCATION="${LOCATION:-westeurope}"
BICEP_RG="${BICEP_RG:-azure-iac-benchmark-bicep-rg}"
TERRAFORM_RG="${TERRAFORM_RG:-azure-iac-benchmark-terraform-rg}"
PULUMI_RG="${PULUMI_RG:-azure-iac-benchmark-pulumi-rg}"

# Check prerequisites
echo -e "\n${BLUE}[1/6] Checking prerequisites...${NC}"

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 not found"
        return 1
    fi
}

MISSING=0
check_command "az" || MISSING=1
check_command "terraform" || MISSING=1
check_command "pulumi" || MISSING=1
check_command "python3" || MISSING=1

if [ $MISSING -eq 1 ]; then
    echo -e "\n${RED}Please install missing prerequisites before continuing.${NC}"
    echo -e "See README.md for installation instructions."
    exit 1
fi

# Check Azure login
echo -e "\n${BLUE}[2/6] Checking Azure login...${NC}"
if az account show &> /dev/null; then
    ACCOUNT=$(az account show --query name -o tsv)
    echo -e "  ${GREEN}✓${NC} Logged in to Azure: $ACCOUNT"
else
    echo -e "  ${YELLOW}!${NC} Not logged in to Azure. Running 'az login'..."
    az login
fi

# Create resource groups
echo -e "\n${BLUE}[3/6] Creating Azure resource groups...${NC}"

create_rg() {
    local rg=$1
    if az group show -n "$rg" &> /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $rg already exists"
    else
        az group create -n "$rg" -l "$LOCATION" -o none
        echo -e "  ${GREEN}✓${NC} Created $rg"
    fi
}

create_rg "$BICEP_RG"
create_rg "$TERRAFORM_RG"
create_rg "$PULUMI_RG"

# Initialize Terraform
echo -e "\n${BLUE}[4/6] Initializing Terraform...${NC}"
cd "$SCRIPT_DIR/terraform"
if [ -d ".terraform" ]; then
    echo -e "  ${GREEN}✓${NC} Terraform already initialized"
else
    terraform init -input=false > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Terraform initialized"
fi

# Create terraform.tfvars if not exists
if [ ! -f "terraform.tfvars" ]; then
    cat > terraform.tfvars << TFVARS
resource_group_name = "$TERRAFORM_RG"
location            = "$LOCATION"
TFVARS
    echo -e "  ${GREEN}✓${NC} Created terraform.tfvars"
fi

# Initialize Pulumi
echo -e "\n${BLUE}[5/6] Initializing Pulumi...${NC}"
cd "$SCRIPT_DIR/pulumi"

# Create virtual environment
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "  ${GREEN}✓${NC} Created Python virtual environment"
else
    echo -e "  ${GREEN}✓${NC} Virtual environment exists"
fi

# Install dependencies
source venv/bin/activate
pip install -q -r requirements.txt
echo -e "  ${GREEN}✓${NC} Installed Python dependencies"

# Initialize Pulumi stack
export PULUMI_CONFIG_PASSPHRASE=""
if pulumi stack ls 2>/dev/null | grep -q "benchmark"; then
    echo -e "  ${GREEN}✓${NC} Pulumi stack 'benchmark' exists"
else
    pulumi stack init benchmark --non-interactive 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Created Pulumi stack 'benchmark'"
fi

# Configure Pulumi
pulumi config set azure-native:location "$LOCATION" 2>/dev/null || true
pulumi config set resource_group_name "$PULUMI_RG" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Configured Pulumi stack"

deactivate

# Verify Bicep
echo -e "\n${BLUE}[6/6] Verifying Bicep templates...${NC}"
cd "$SCRIPT_DIR/bicep"
if az bicep build --file main-template.bicep --stdout > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Bicep templates compile successfully"
else
    echo -e "  ${RED}✗${NC} Bicep templates have errors"
    exit 1
fi

# Done
echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Setup Complete!                             ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "\nResource groups created:"
echo -e "  • ${CYAN}$BICEP_RG${NC}"
echo -e "  • ${CYAN}$TERRAFORM_RG${NC}"
echo -e "  • ${CYAN}$PULUMI_RG${NC}"
echo -e "\nRun the benchmark with:"
echo -e "  ${YELLOW}./run-iterations.sh${NC}        # 3 iterations (default)"
echo -e "  ${YELLOW}./run-iterations.sh 5${NC}      # 5 iterations"
echo -e "\nOr run a single benchmark:"
echo -e "  ${YELLOW}./run-benchmark.sh -g azure-iac-benchmark -i 1${NC}"
