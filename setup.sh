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
OPENTOFU_RG="${OPENTOFU_RG:-azure-iac-benchmark-opentofu-rg}"
PULUMI_RG="${PULUMI_RG:-azure-iac-benchmark-pulumi-rg}"

# Check prerequisites
echo -e "\n${BLUE}[1/7] Checking prerequisites...${NC}"

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "  ${YELLOW}!${NC} $1 not found"
        return 1
    fi
}

install_opentofu() {
    echo -e "  ${BLUE}→${NC} Installing OpenTofu..."
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check for snap (works on most Linux distros)
        if command -v snap &> /dev/null; then
            sudo snap install --classic opentofu > /dev/null 2>&1
        # Debian/Ubuntu
        elif command -v apt-get &> /dev/null; then
            # Install dependencies
            sudo apt-get update -qq > /dev/null 2>&1
            sudo apt-get install -y -qq gnupg software-properties-common curl > /dev/null 2>&1
            
            # Add OpenTofu repository
            curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg > /dev/null
            curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg 2>/dev/null
            
            echo "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
                sudo tee /etc/apt/sources.list.d/opentofu.list > /dev/null
            echo "deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | \
                sudo tee -a /etc/apt/sources.list.d/opentofu.list > /dev/null
            
            sudo apt-get update -qq > /dev/null 2>&1
            sudo apt-get install -y -qq tofu > /dev/null 2>&1
        # RHEL/Fedora
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y -q 'dnf-command(config-manager)' > /dev/null 2>&1
            sudo dnf config-manager --add-repo https://packages.opentofu.org/opentofu/tofu/fedora/any/tofu.repo > /dev/null 2>&1
            sudo dnf install -y -q tofu > /dev/null 2>&1
        else
            echo -e "  ${RED}✗${NC} Could not auto-install OpenTofu. Please install manually:"
            echo -e "    https://opentofu.org/docs/intro/install/"
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install opentofu > /dev/null 2>&1
        else
            echo -e "  ${RED}✗${NC} Please install Homebrew first, then run: brew install opentofu"
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} Unsupported OS. Please install OpenTofu manually:"
        echo -e "    https://opentofu.org/docs/intro/install/"
        return 1
    fi
    
    if command -v tofu &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} OpenTofu installed successfully"
        return 0
    else
        echo -e "  ${RED}✗${NC} OpenTofu installation failed"
        return 1
    fi
}

MISSING=0
check_command "az" || MISSING=1
check_command "terraform" || MISSING=1
check_command "tofu" || { install_opentofu || MISSING=1; }
check_command "pulumi" || MISSING=1
check_command "python3" || MISSING=1

if [ $MISSING -eq 1 ]; then
    echo -e "\n${RED}Please install missing prerequisites before continuing.${NC}"
    echo -e "See README.md for installation instructions."
    exit 1
fi

# Check Azure login
echo -e "\n${BLUE}[2/7] Checking Azure login...${NC}"
if az account show &> /dev/null; then
    ACCOUNT=$(az account show --query name -o tsv)
    echo -e "  ${GREEN}✓${NC} Logged in to Azure: $ACCOUNT"
else
    echo -e "  ${YELLOW}!${NC} Not logged in to Azure. Running 'az login'..."
    az login
fi

# Create resource groups
echo -e "\n${BLUE}[3/7] Creating Azure resource groups...${NC}"

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
create_rg "$OPENTOFU_RG"
create_rg "$PULUMI_RG"

# Initialize Terraform
echo -e "\n${BLUE}[4/7] Initializing Terraform...${NC}"
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

# Initialize OpenTofu
echo -e "\n${BLUE}[5/7] Initializing OpenTofu...${NC}"
cd "$SCRIPT_DIR/opentofu"
if [ -d ".terraform" ]; then
    echo -e "  ${GREEN}✓${NC} OpenTofu already initialized"
else
    tofu init -input=false > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} OpenTofu initialized"
fi

# Create opentofu.tfvars if not exists
if [ ! -f "terraform.tfvars" ]; then
    cat > terraform.tfvars << TFVARS
resource_group_name = "$OPENTOFU_RG"
location            = "$LOCATION"
TFVARS
    echo -e "  ${GREEN}✓${NC} Created terraform.tfvars for OpenTofu"
fi

# Initialize Pulumi
echo -e "\n${BLUE}[6/7] Initializing Pulumi...${NC}"
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
pulumi config set resourceGroupName "$PULUMI_RG" 2>/dev/null || true
pulumi config set location "$LOCATION" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Configured Pulumi stack"

deactivate

# Verify Bicep
echo -e "\n${BLUE}[7/7] Verifying Bicep templates...${NC}"
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
echo -e "  • ${CYAN}$OPENTOFU_RG${NC}"
echo -e "  • ${CYAN}$PULUMI_RG${NC}"
echo -e "\nRun the benchmark with:"
echo -e "  ${YELLOW}./run-iterations.sh${NC}        # 3 iterations (default)"
echo -e "  ${YELLOW}./run-iterations.sh 5${NC}      # 5 iterations"
echo -e "\nOr run a single benchmark:"
echo -e "  ${YELLOW}./run-benchmark.sh -g azure-iac-benchmark -i 1${NC}"
