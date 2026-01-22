#!/bin/bash
# =============================================================================
# IaC Benchmark Runner - Multiple Iterations with Full Metrics
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ITERATIONS=${1:-3}
TOOLS_FILTER=${2:-all}
BICEP_RG="azure-iac-benchmark-bicep-rg"
TERRAFORM_RG="azure-iac-benchmark-terraform-rg"
OPENTOFU_RG="azure-iac-benchmark-opentofu-rg"
PULUMI_RG="azure-iac-benchmark-pulumi-rg"

# Tool filtering
RUN_BICEP=false
RUN_TERRAFORM=false
RUN_OPENTOFU=false
RUN_PULUMI=false

case "$TOOLS_FILTER" in
    all)
        RUN_BICEP=true; RUN_TERRAFORM=true; RUN_OPENTOFU=true; RUN_PULUMI=true ;;
    bicep-only)
        RUN_BICEP=true ;;
    terraform-only)
        RUN_TERRAFORM=true ;;
    opentofu-only)
        RUN_OPENTOFU=true ;;
    pulumi-only)
        RUN_PULUMI=true ;;
    *)
        echo "Unknown tools filter: $TOOLS_FILTER"; exit 1 ;;
esac

# Results arrays
declare -a BICEP_DEPLOY_TIMES
declare -a BICEP_DESTROY_TIMES
declare -a TERRAFORM_DEPLOY_TIMES
declare -a TERRAFORM_DESTROY_TIMES
declare -a OPENTOFU_DEPLOY_TIMES
declare -a OPENTOFU_DESTROY_TIMES
declare -a PULUMI_DEPLOY_TIMES
declare -a PULUMI_DESTROY_TIMES

# Resource usage arrays (memory in MB, CPU in seconds)
declare -a BICEP_DEPLOY_MEM
declare -a BICEP_DESTROY_MEM
declare -a BICEP_DEPLOY_CPU
declare -a BICEP_DESTROY_CPU
declare -a TERRAFORM_DEPLOY_MEM
declare -a TERRAFORM_DESTROY_MEM
declare -a TERRAFORM_DEPLOY_CPU
declare -a TERRAFORM_DESTROY_CPU
declare -a OPENTOFU_DEPLOY_MEM
declare -a OPENTOFU_DESTROY_MEM
declare -a OPENTOFU_DEPLOY_CPU
declare -a OPENTOFU_DESTROY_CPU
declare -a PULUMI_DEPLOY_MEM
declare -a PULUMI_DESTROY_MEM
declare -a PULUMI_DEPLOY_CPU
declare -a PULUMI_DESTROY_CPU

mkdir -p "$RESULTS_DIR"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       IaC Benchmark - $ITERATIONS Iterations per Tool              ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

# Helper: Clean resource group
clean_rg() {
    local rg=$1
    az resource list --resource-group "$rg" --query "[].id" -o tsv 2>/dev/null | xargs -r -I {} az resource delete --ids {} 2>/dev/null || true
    sleep 5
}

# Helper: Run command with resource monitoring
# Usage: run_with_metrics "command" time_var mem_var cpu_var
# Sets variables: METRICS_TIME, METRICS_MEM_MB, METRICS_CPU_SEC
run_with_metrics() {
    local cmd="$1"
    local time_output
    local start end
    
    # Create temp file for time output
    local time_file=$(mktemp)
    
    start=$(date +%s.%N)
    # Run command with GNU time, capture metrics to file
    /usr/bin/time -v bash -c "$cmd" 2> "$time_file" || true
    end=$(date +%s.%N)
    
    # Parse metrics from time output
    METRICS_TIME=$(echo "$end - $start" | bc)
    METRICS_MEM_KB=$(grep "Maximum resident set size" "$time_file" | awk '{print $NF}')
    METRICS_MEM_MB=$(echo "scale=2; ${METRICS_MEM_KB:-0} / 1024" | bc)
    local user_time=$(grep "User time" "$time_file" | awk '{print $NF}')
    local sys_time=$(grep "System time" "$time_file" | awk '{print $NF}')
    METRICS_CPU_SEC=$(echo "${user_time:-0} + ${sys_time:-0}" | bc)
    
    rm -f "$time_file"
}

# Benchmark Bicep
benchmark_bicep() {
    local iteration=$1
    echo -e "\n${BLUE}[Bicep] Iteration $iteration - Deploying...${NC}"
    
    run_with_metrics "az deployment group create \
        --resource-group '$BICEP_RG' \
        --template-file '$SCRIPT_DIR/bicep/main-template.bicep' \
        --parameters '$SCRIPT_DIR/bicep/main-template.bicepparam' \
        --output none 2>&1"
    
    BICEP_DEPLOY_TIMES+=("$METRICS_TIME")
    BICEP_DEPLOY_MEM+=("$METRICS_MEM_MB")
    BICEP_DEPLOY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Deploy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    echo -e "${BLUE}[Bicep] Iteration $iteration - Destroying...${NC}"
    run_with_metrics "az resource list --resource-group '$BICEP_RG' --query '[].id' -o tsv 2>/dev/null | xargs -r -I {} az resource delete --ids {} 2>/dev/null || true"
    
    BICEP_DESTROY_TIMES+=("$METRICS_TIME")
    BICEP_DESTROY_MEM+=("$METRICS_MEM_MB")
    BICEP_DESTROY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Destroy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    sleep 5
}

# Benchmark Terraform
benchmark_terraform() {
    local iteration=$1
    echo -e "\n${BLUE}[Terraform] Iteration $iteration - Deploying...${NC}"
    
    cd "$SCRIPT_DIR/terraform"
    
    run_with_metrics "terraform apply -auto-approve -var=\"resource_group_name=$TERRAFORM_RG\" > /dev/null 2>&1"
    
    TERRAFORM_DEPLOY_TIMES+=("$METRICS_TIME")
    TERRAFORM_DEPLOY_MEM+=("$METRICS_MEM_MB")
    TERRAFORM_DEPLOY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Deploy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    echo -e "${BLUE}[Terraform] Iteration $iteration - Destroying...${NC}"
    run_with_metrics "terraform destroy -auto-approve -var=\"resource_group_name=$TERRAFORM_RG\" > /dev/null 2>&1"
    
    TERRAFORM_DESTROY_TIMES+=("$METRICS_TIME")
    TERRAFORM_DESTROY_MEM+=("$METRICS_MEM_MB")
    TERRAFORM_DESTROY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Destroy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    cd "$SCRIPT_DIR"
}

# Benchmark OpenTofu
benchmark_opentofu() {
    local iteration=$1
    echo -e "\n${BLUE}[OpenTofu] Iteration $iteration - Deploying...${NC}"
    
    cd "$SCRIPT_DIR/opentofu"
    
    run_with_metrics "tofu apply -auto-approve -var=\"resource_group_name=$OPENTOFU_RG\" > /dev/null 2>&1"
    
    OPENTOFU_DEPLOY_TIMES+=("$METRICS_TIME")
    OPENTOFU_DEPLOY_MEM+=("$METRICS_MEM_MB")
    OPENTOFU_DEPLOY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Deploy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    echo -e "${BLUE}[OpenTofu] Iteration $iteration - Destroying...${NC}"
    run_with_metrics "tofu destroy -auto-approve -var=\"resource_group_name=$OPENTOFU_RG\" > /dev/null 2>&1"
    
    OPENTOFU_DESTROY_TIMES+=("$METRICS_TIME")
    OPENTOFU_DESTROY_MEM+=("$METRICS_MEM_MB")
    OPENTOFU_DESTROY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Destroy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    cd "$SCRIPT_DIR"
}

benchmark_pulumi() {
    local iteration=$1
    echo -e "\n${BLUE}[Pulumi] Iteration $iteration - Deploying...${NC}"
    
    cd "$SCRIPT_DIR/pulumi-dotnet"
    export PULUMI_CONFIG_PASSPHRASE=""
    
    # Ensure we're logged in and on the right stack
    pulumi login --local 2>/dev/null || true
    pulumi stack select benchmark 2>/dev/null || pulumi stack init benchmark 2>/dev/null || true
    
    run_with_metrics "pulumi up --yes --skip-preview 2>&1 | tail -10"
    
    if [ "$METRICS_TIME" == "0" ] || [ -z "$METRICS_TIME" ]; then
        echo -e "${RED}  ✗ Pulumi deploy failed${NC}"
        PULUMI_DEPLOY_TIMES+=("0"); PULUMI_DEPLOY_MEM+=("0"); PULUMI_DEPLOY_CPU+=("0")
        cd "$SCRIPT_DIR"; return
    fi
    
    PULUMI_DEPLOY_TIMES+=("$METRICS_TIME")
    PULUMI_DEPLOY_MEM+=("$METRICS_MEM_MB")
    PULUMI_DEPLOY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Deploy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    echo -e "${BLUE}[Pulumi] Iteration $iteration - Destroying...${NC}"
    run_with_metrics "pulumi destroy --yes --skip-preview 2>&1 | tail -5"
    
    PULUMI_DESTROY_TIMES+=("$METRICS_TIME")
    PULUMI_DESTROY_MEM+=("$METRICS_MEM_MB")
    PULUMI_DESTROY_CPU+=("$METRICS_CPU_SEC")
    echo -e "${GREEN}  ✓ Destroy: ${METRICS_TIME}s | Mem: ${METRICS_MEM_MB}MB | CPU: ${METRICS_CPU_SEC}s${NC}"
    
    cd "$SCRIPT_DIR"
}

# Calculate stats
calc_stats() {
    local -n arr=$1
    
    # Return zeros if array is empty
    if [ ${#arr[@]} -eq 0 ]; then
        echo "0 0 0"
        return
    fi
    
    local sum=0
    local min=999999
    local max=0
    
    for val in "${arr[@]}"; do
        sum=$(echo "$sum + $val" | bc)
        if (( $(echo "$val < $min" | bc -l) )); then min=$val; fi
        if (( $(echo "$val > $max" | bc -l) )); then max=$val; fi
    done
    
    local avg=$(echo "scale=2; $sum / ${#arr[@]}" | bc)
    echo "$min $max $avg"
}

# Run benchmarks
for ((i=1; i<=ITERATIONS; i++)); do
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    ITERATION $i of $ITERATIONS                     ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    [ "$RUN_BICEP" = true ] && benchmark_bicep "$i"
    [ "$RUN_TERRAFORM" = true ] && benchmark_terraform "$i"
    [ "$RUN_OPENTOFU" = true ] && benchmark_opentofu "$i"
    [ "$RUN_PULUMI" = true ] && benchmark_pulumi "$i"
done

# Calculate statistics
read bicep_deploy_min bicep_deploy_max bicep_deploy_avg <<< $(calc_stats BICEP_DEPLOY_TIMES)
read bicep_destroy_min bicep_destroy_max bicep_destroy_avg <<< $(calc_stats BICEP_DESTROY_TIMES)
read tf_deploy_min tf_deploy_max tf_deploy_avg <<< $(calc_stats TERRAFORM_DEPLOY_TIMES)
read tf_destroy_min tf_destroy_max tf_destroy_avg <<< $(calc_stats TERRAFORM_DESTROY_TIMES)
read ot_deploy_min ot_deploy_max ot_deploy_avg <<< $(calc_stats OPENTOFU_DEPLOY_TIMES)
read ot_destroy_min ot_destroy_max ot_destroy_avg <<< $(calc_stats OPENTOFU_DESTROY_TIMES)
read pulumi_deploy_min pulumi_deploy_max pulumi_deploy_avg <<< $(calc_stats PULUMI_DEPLOY_TIMES)
read pulumi_destroy_min pulumi_destroy_max pulumi_destroy_avg <<< $(calc_stats PULUMI_DESTROY_TIMES)

# Calculate memory stats
read bicep_deploy_mem_min bicep_deploy_mem_max bicep_deploy_mem_avg <<< $(calc_stats BICEP_DEPLOY_MEM)
read bicep_destroy_mem_min bicep_destroy_mem_max bicep_destroy_mem_avg <<< $(calc_stats BICEP_DESTROY_MEM)
read tf_deploy_mem_min tf_deploy_mem_max tf_deploy_mem_avg <<< $(calc_stats TERRAFORM_DEPLOY_MEM)
read tf_destroy_mem_min tf_destroy_mem_max tf_destroy_mem_avg <<< $(calc_stats TERRAFORM_DESTROY_MEM)
read ot_deploy_mem_min ot_deploy_mem_max ot_deploy_mem_avg <<< $(calc_stats OPENTOFU_DEPLOY_MEM)
read ot_destroy_mem_min ot_destroy_mem_max ot_destroy_mem_avg <<< $(calc_stats OPENTOFU_DESTROY_MEM)
read pulumi_deploy_mem_min pulumi_deploy_mem_max pulumi_deploy_mem_avg <<< $(calc_stats PULUMI_DEPLOY_MEM)
read pulumi_destroy_mem_min pulumi_destroy_mem_max pulumi_destroy_mem_avg <<< $(calc_stats PULUMI_DESTROY_MEM)

# Calculate CPU stats
read bicep_deploy_cpu_min bicep_deploy_cpu_max bicep_deploy_cpu_avg <<< $(calc_stats BICEP_DEPLOY_CPU)
read bicep_destroy_cpu_min bicep_destroy_cpu_max bicep_destroy_cpu_avg <<< $(calc_stats BICEP_DESTROY_CPU)
read tf_deploy_cpu_min tf_deploy_cpu_max tf_deploy_cpu_avg <<< $(calc_stats TERRAFORM_DEPLOY_CPU)
read tf_destroy_cpu_min tf_destroy_cpu_max tf_destroy_cpu_avg <<< $(calc_stats TERRAFORM_DESTROY_CPU)
read ot_deploy_cpu_min ot_deploy_cpu_max ot_deploy_cpu_avg <<< $(calc_stats OPENTOFU_DEPLOY_CPU)
read ot_destroy_cpu_min ot_destroy_cpu_max ot_destroy_cpu_avg <<< $(calc_stats OPENTOFU_DESTROY_CPU)
read pulumi_deploy_cpu_min pulumi_deploy_cpu_max pulumi_deploy_cpu_avg <<< $(calc_stats PULUMI_DEPLOY_CPU)
read pulumi_destroy_cpu_min pulumi_destroy_cpu_max pulumi_destroy_cpu_avg <<< $(calc_stats PULUMI_DESTROY_CPU)

# Print summary
echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    BENCHMARK RESULTS                           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

echo -e "\n${GREEN}DEPLOYMENT TIMES (seconds):${NC}"
printf "%-12s %10s %10s %10s\n" "Tool" "Min" "Max" "Avg"
printf "%-12s %10s %10s %10s\n" "--------" "------" "------" "------"
printf "%-12s %10.2f %10.2f %10.2f\n" "Bicep" "$bicep_deploy_min" "$bicep_deploy_max" "$bicep_deploy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Terraform" "$tf_deploy_min" "$tf_deploy_max" "$tf_deploy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "OpenTofu" "$ot_deploy_min" "$ot_deploy_max" "$ot_deploy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Pulumi" "$pulumi_deploy_min" "$pulumi_deploy_max" "$pulumi_deploy_avg"

echo -e "\n${GREEN}DESTROY TIMES (seconds):${NC}"
printf "%-12s %10s %10s %10s\n" "Tool" "Min" "Max" "Avg"
printf "%-12s %10s %10s %10s\n" "--------" "------" "------" "------"
printf "%-12s %10.2f %10.2f %10.2f\n" "Bicep" "$bicep_destroy_min" "$bicep_destroy_max" "$bicep_destroy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Terraform" "$tf_destroy_min" "$tf_destroy_max" "$tf_destroy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "OpenTofu" "$ot_destroy_min" "$ot_destroy_max" "$ot_destroy_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Pulumi" "$pulumi_destroy_min" "$pulumi_destroy_max" "$pulumi_destroy_avg"

echo -e "\n${GREEN}PEAK MEMORY USAGE - DEPLOY (MB):${NC}"
printf "%-12s %10s %10s %10s\n" "Tool" "Min" "Max" "Avg"
printf "%-12s %10s %10s %10s\n" "--------" "------" "------" "------"
printf "%-12s %10.2f %10.2f %10.2f\n" "Bicep" "$bicep_deploy_mem_min" "$bicep_deploy_mem_max" "$bicep_deploy_mem_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Terraform" "$tf_deploy_mem_min" "$tf_deploy_mem_max" "$tf_deploy_mem_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "OpenTofu" "$ot_deploy_mem_min" "$ot_deploy_mem_max" "$ot_deploy_mem_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Pulumi" "$pulumi_deploy_mem_min" "$pulumi_deploy_mem_max" "$pulumi_deploy_mem_avg"

echo -e "\n${GREEN}CPU TIME - DEPLOY (seconds):${NC}"
printf "%-12s %10s %10s %10s\n" "Tool" "Min" "Max" "Avg"
printf "%-12s %10s %10s %10s\n" "--------" "------" "------" "------"
printf "%-12s %10.2f %10.2f %10.2f\n" "Bicep" "$bicep_deploy_cpu_min" "$bicep_deploy_cpu_max" "$bicep_deploy_cpu_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Terraform" "$tf_deploy_cpu_min" "$tf_deploy_cpu_max" "$tf_deploy_cpu_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "OpenTofu" "$ot_deploy_cpu_min" "$ot_deploy_cpu_max" "$ot_deploy_cpu_avg"
printf "%-12s %10.2f %10.2f %10.2f\n" "Pulumi" "$pulumi_deploy_cpu_min" "$pulumi_deploy_cpu_max" "$pulumi_deploy_cpu_avg"

# Determine winners (only consider tools that were actually run - non-zero averages)
deploy_winner="None"
deploy_best=999999

# Only consider tools with non-zero deploy averages
if [ "$RUN_BICEP" = true ] && (( $(echo "$bicep_deploy_avg > 0 && $bicep_deploy_avg < $deploy_best" | bc -l) )); then deploy_winner="Bicep"; deploy_best=$bicep_deploy_avg; fi
if [ "$RUN_TERRAFORM" = true ] && (( $(echo "$tf_deploy_avg > 0 && $tf_deploy_avg < $deploy_best" | bc -l) )); then deploy_winner="Terraform"; deploy_best=$tf_deploy_avg; fi
if [ "$RUN_OPENTOFU" = true ] && (( $(echo "$ot_deploy_avg > 0 && $ot_deploy_avg < $deploy_best" | bc -l) )); then deploy_winner="OpenTofu"; deploy_best=$ot_deploy_avg; fi
if [ "$RUN_PULUMI" = true ] && (( $(echo "$pulumi_deploy_avg > 0 && $pulumi_deploy_avg < $deploy_best" | bc -l) )); then deploy_winner="Pulumi"; deploy_best=$pulumi_deploy_avg; fi

# Handle case where no tools ran successfully
if [ "$deploy_best" = "999999" ]; then deploy_best=0; fi

destroy_winner="None"
destroy_best=999999

# Only consider tools with non-zero destroy averages
if [ "$RUN_BICEP" = true ] && (( $(echo "$bicep_destroy_avg > 0 && $bicep_destroy_avg < $destroy_best" | bc -l) )); then destroy_winner="Bicep"; destroy_best=$bicep_destroy_avg; fi
if [ "$RUN_TERRAFORM" = true ] && (( $(echo "$tf_destroy_avg > 0 && $tf_destroy_avg < $destroy_best" | bc -l) )); then destroy_winner="Terraform"; destroy_best=$tf_destroy_avg; fi
if [ "$RUN_OPENTOFU" = true ] && (( $(echo "$ot_destroy_avg > 0 && $ot_destroy_avg < $destroy_best" | bc -l) )); then destroy_winner="OpenTofu"; destroy_best=$ot_destroy_avg; fi
if [ "$RUN_PULUMI" = true ] && (( $(echo "$pulumi_destroy_avg > 0 && $pulumi_destroy_avg < $destroy_best" | bc -l) )); then destroy_winner="Pulumi"; destroy_best=$pulumi_destroy_avg; fi

# Handle case where no tools ran successfully
if [ "$destroy_best" = "999999" ]; then destroy_best=0; fi

echo -e "\n${YELLOW}🏆 WINNERS:${NC}"
echo -e "  Fastest Deploy:  ${GREEN}$deploy_winner${NC} (${deploy_best}s avg)"
echo -e "  Fastest Destroy: ${GREEN}$destroy_winner${NC} (${destroy_best}s avg)"

# Save JSON results
cat > "$RESULTS_DIR/benchmark_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "iterations": $ITERATIONS,
  "results": {
    "bicep": {
      "deploy": { "times": [$(IFS=,; echo "${BICEP_DEPLOY_TIMES[*]}")], "min": $bicep_deploy_min, "max": $bicep_deploy_max, "avg": $bicep_deploy_avg },
      "destroy": { "times": [$(IFS=,; echo "${BICEP_DESTROY_TIMES[*]}")], "min": $bicep_destroy_min, "max": $bicep_destroy_max, "avg": $bicep_destroy_avg },
      "memory_mb": { "deploy_avg": $bicep_deploy_mem_avg, "destroy_avg": $bicep_destroy_mem_avg },
      "cpu_sec": { "deploy_avg": $bicep_deploy_cpu_avg, "destroy_avg": $bicep_destroy_cpu_avg }
    },
    "terraform": {
      "deploy": { "times": [$(IFS=,; echo "${TERRAFORM_DEPLOY_TIMES[*]}")], "min": $tf_deploy_min, "max": $tf_deploy_max, "avg": $tf_deploy_avg },
      "destroy": { "times": [$(IFS=,; echo "${TERRAFORM_DESTROY_TIMES[*]}")], "min": $tf_destroy_min, "max": $tf_destroy_max, "avg": $tf_destroy_avg },
      "memory_mb": { "deploy_avg": $tf_deploy_mem_avg, "destroy_avg": $tf_destroy_mem_avg },
      "cpu_sec": { "deploy_avg": $tf_deploy_cpu_avg, "destroy_avg": $tf_destroy_cpu_avg }
    },
    "opentofu": {
      "deploy": { "times": [$(IFS=,; echo "${OPENTOFU_DEPLOY_TIMES[*]}")], "min": $ot_deploy_min, "max": $ot_deploy_max, "avg": $ot_deploy_avg },
      "destroy": { "times": [$(IFS=,; echo "${OPENTOFU_DESTROY_TIMES[*]}")], "min": $ot_destroy_min, "max": $ot_destroy_max, "avg": $ot_destroy_avg },
      "memory_mb": { "deploy_avg": $ot_deploy_mem_avg, "destroy_avg": $ot_destroy_mem_avg },
      "cpu_sec": { "deploy_avg": $ot_deploy_cpu_avg, "destroy_avg": $ot_destroy_cpu_avg }
    },
    "pulumi": {
      "deploy": { "times": [$(IFS=,; echo "${PULUMI_DEPLOY_TIMES[*]}")], "min": $pulumi_deploy_min, "max": $pulumi_deploy_max, "avg": $pulumi_deploy_avg },
      "destroy": { "times": [$(IFS=,; echo "${PULUMI_DESTROY_TIMES[*]}")], "min": $pulumi_destroy_min, "max": $pulumi_destroy_max, "avg": $pulumi_destroy_avg },
      "memory_mb": { "deploy_avg": $pulumi_deploy_mem_avg, "destroy_avg": $pulumi_destroy_mem_avg },
      "cpu_sec": { "deploy_avg": $pulumi_deploy_cpu_avg, "destroy_avg": $pulumi_destroy_cpu_avg }
    }
  },
  "winners": {
    "deploy": "$deploy_winner",
    "destroy": "$destroy_winner"
  }
}
EOF

echo -e "\n${GREEN}Results saved to: $RESULTS_DIR/benchmark_${TIMESTAMP}.json${NC}"

# Generate HTML report
HTML_FILE="$RESULTS_DIR/benchmark_${TIMESTAMP}.html"

# Calculate speed comparisons (safe defaults to avoid divide by zero when tools not run)
bicep_total=$(echo "$bicep_deploy_avg + $bicep_destroy_avg" | bc)
tf_total=$(echo "$tf_deploy_avg + $tf_destroy_avg" | bc)
pulumi_total=$(echo "$pulumi_deploy_avg + $pulumi_destroy_avg" | bc)

# Set safe defaults for legacy percentage variables (not currently used in HTML)
pulumi_vs_bicep_deploy="-"
pulumi_vs_tf_deploy="-"
pulumi_vs_bicep_destroy="-"
pulumi_vs_tf_destroy="-"

cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IaC Benchmark Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --bicep-color: #0078d4;
            --terraform-color: #7b42bc;
            --opentofu-color: #ffda18;
            --pulumi-color: #f7bf2a;
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #333333;
            --border-color: #e0e0e0;
            --success-color: #28a745;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 2rem;
        }
        
        .container { max-width: 1400px; margin: 0 auto; }
        
        header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2.5rem;
            background: linear-gradient(135deg, var(--bicep-color) 0%, var(--terraform-color) 50%, var(--pulumi-color) 100%);
            border-radius: 16px;
            color: white;
            box-shadow: 0 10px 40px rgba(0,0,0,0.15);
        }
        
        header h1 { font-size: 2.8rem; margin-bottom: 0.5rem; }
        header p { font-size: 1.2rem; opacity: 0.95; }
        .timestamp { margin-top: 1rem; font-size: 0.9rem; opacity: 0.8; }
        
        .winner-banner {
            background: linear-gradient(135deg, #ffd700, #ffed4a, #ffd700);
            color: #333;
            padding: 1.5rem 2rem;
            border-radius: 12px;
            text-align: center;
            margin-bottom: 2rem;
            box-shadow: 0 4px 20px rgba(255, 215, 0, 0.3);
        }
        
        .winner-banner h3 { font-size: 1.8rem; margin-bottom: 0.5rem; }
        .winner-banner p { font-size: 1.1rem; }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: var(--card-bg);
            border-radius: 16px;
            padding: 1.5rem;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .card:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
        }
        
        .card h2 {
            font-size: 1.3rem;
            margin-bottom: 1rem;
            padding-bottom: 0.75rem;
            border-bottom: 3px solid var(--border-color);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .card.bicep h2 { border-color: var(--bicep-color); }
        .card.terraform h2 { border-color: var(--terraform-color); }
        .card.opentofu h2 { border-color: var(--opentofu-color); }
        .card.pulumi h2 { border-color: var(--pulumi-color); }
        
        .tool-icon {
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        
        .card.bicep .tool-icon { background: var(--bicep-color); }
        .card.terraform .tool-icon { background: var(--terraform-color); }
        .card.opentofu .tool-icon { background: var(--opentofu-color); }
        .card.pulumi .tool-icon { background: var(--pulumi-color); }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.6rem 0;
            border-bottom: 1px solid var(--border-color);
        }
        
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #666; font-size: 0.95rem; }
        .metric-value { font-weight: 600; font-size: 1.05rem; }
        .metric-value.time { font-size: 1.6rem; font-weight: 700; }
        
        .card.bicep .metric-value.time { color: var(--bicep-color); }
        .card.terraform .metric-value.time { color: var(--terraform-color); }
        .card.opentofu .metric-value.time { color: var(--opentofu-color); }
        .card.pulumi .metric-value.time { color: var(--pulumi-color); }
        
        .badge {
            display: inline-block;
            padding: 0.2rem 0.6rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 500;
            margin-left: 0.5rem;
        }
        
        .badge.winner { background: linear-gradient(135deg, #ffd700, #ffed4a); color: #333; }
        .badge.success { background: #d4edda; color: #155724; }
        
        .chart-container {
            background: var(--card-bg);
            border-radius: 16px;
            padding: 2rem;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            margin-bottom: 2rem;
        }
        
        .chart-container h2 { margin-bottom: 1.5rem; font-size: 1.4rem; }
        
        .chart-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 2rem;
        }
        
        .chart-wrapper { position: relative; height: 350px; }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 1rem;
        }
        
        th, td {
            padding: 0.75rem 1rem;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
        }
        
        th {
            background-color: var(--bg-color);
            font-weight: 600;
            font-size: 0.9rem;
        }
        
        footer {
            text-align: center;
            margin-top: 3rem;
            padding-top: 2rem;
            border-top: 1px solid var(--border-color);
            color: #666;
        }
        
        @media (max-width: 1024px) {
            .grid { grid-template-columns: 1fr; }
            .chart-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🏎️ IaC Benchmark Report</h1>
            <p>Bicep vs Terraform vs OpenTofu vs Pulumi (Python & .NET) - ITERATIONS_PLACEHOLDER Iterations Each</p>
            <div class="timestamp">Generated: DATETIME_PLACEHOLDER | Region: West Europe</div>
        </header>
        
        <div class="winner-banner">
            <h3>🏆 Overall Winner: DEPLOY_WINNER_PLACEHOLDER</h3>
            <p>Fastest Deploy (DEPLOY_BEST_PLACEHOLDERs avg) — WINNER_DESC_PLACEHOLDER</p>
        </div>
        
        <div class="grid">
            <div class="card bicep">
                <h2><span class="tool-icon">B</span> BicepBICEP_BADGE_PLACEHOLDER</h2>
                <div class="metric">
                    <span class="metric-label">Avg Deploy Time</span>
                    <span class="metric-value time">BICEP_DEPLOY_AVGsBICEP_DEPLOY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Avg Destroy Time</span>
                    <span class="metric-value time">BICEP_DESTROY_AVGsBICEP_DESTROY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Deploy Range</span>
                    <span class="metric-value">BICEP_DEPLOY_MINs - BICEP_DEPLOY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Destroy Range</span>
                    <span class="metric-value">BICEP_DESTROY_MINs - BICEP_DESTROY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="badge success">✓ ITERATIONS_PLACEHOLDER/ITERATIONS_PLACEHOLDER Success</span>
                </div>
            </div>
            
            <div class="card terraform">
                <h2><span class="tool-icon">T</span> TerraformTERRAFORM_BADGE_PLACEHOLDER</h2>
                <div class="metric">
                    <span class="metric-label">Avg Deploy Time</span>
                    <span class="metric-value time">TF_DEPLOY_AVGsTF_DEPLOY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Avg Destroy Time</span>
                    <span class="metric-value time">TF_DESTROY_AVGsTF_DESTROY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Deploy Range</span>
                    <span class="metric-value">TF_DEPLOY_MINs - TF_DEPLOY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Destroy Range</span>
                    <span class="metric-value">TF_DESTROY_MINs - TF_DESTROY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="badge success">✓ ITERATIONS_PLACEHOLDER/ITERATIONS_PLACEHOLDER Success</span>
                </div>
            </div>
            
            <div class="card opentofu">
                <h2><span class="tool-icon">O</span> OpenTofuOPENTOFU_BADGE_PLACEHOLDER</h2>
                <div class="metric">
                    <span class="metric-label">Avg Deploy Time</span>
                    <span class="metric-value time">OT_DEPLOY_AVGsOT_DEPLOY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Avg Destroy Time</span>
                    <span class="metric-value time">OT_DESTROY_AVGsOT_DESTROY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Deploy Range</span>
                    <span class="metric-value">OT_DEPLOY_MINs - OT_DEPLOY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Destroy Range</span>
                    <span class="metric-value">OT_DESTROY_MINs - OT_DESTROY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="badge success">✓ ITERATIONS_PLACEHOLDER/ITERATIONS_PLACEHOLDER Success</span>
                </div>
            </div>
            
            <div class="card pulumi">
                <h2><span class="tool-icon">P</span> PulumiPULUMI_BADGE_PLACEHOLDER</h2>
                <div class="metric">
                    <span class="metric-label">Avg Deploy Time</span>
                    <span class="metric-value time">PULUMI_DEPLOY_AVGsPULUMI_DEPLOY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Avg Destroy Time</span>
                    <span class="metric-value time">PULUMI_DESTROY_AVGsPULUMI_DESTROY_FASTEST</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Deploy Range</span>
                    <span class="metric-value">PULUMI_DEPLOY_MINs - PULUMI_DEPLOY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Destroy Range</span>
                    <span class="metric-value">PULUMI_DESTROY_MINs - PULUMI_DESTROY_MAXs</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="badge success">✓ ITERATIONS_PLACEHOLDER/ITERATIONS_PLACEHOLDER Success</span>
                </div>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>📊 Performance Comparison</h2>
            <div class="chart-grid">
                <div class="chart-wrapper">
                    <canvas id="deployChart"></canvas>
                </div>
                <div class="chart-wrapper">
                    <canvas id="destroyChart"></canvas>
                </div>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>📈 Per-Iteration Results</h2>
            <div class="chart-wrapper" style="height: 400px;">
                <canvas id="iterationChart"></canvas>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>💾 Resource Usage (Deploy)</h2>
            <div class="chart-grid">
                <div class="chart-wrapper">
                    <canvas id="memoryChart"></canvas>
                </div>
                <div class="chart-wrapper">
                    <canvas id="cpuChart"></canvas>
                </div>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>⚖️ Speed Comparison Summary</h2>
            <table>
                <thead>
                    <tr>
                        <th>Metric</th>
                        <th>Winner</th>
                        <th>vs Bicep</th>
                        <th>vs Terraform</th>
                        <th>vs OpenTofu</th>
                        <th>vs Pulumi</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Deploy Speed</strong></td>
                        <td style="color: DEPLOY_WINNER_COLOR; font-weight: bold;">🏆 DEPLOY_WINNER_PLACEHOLDER</td>
                        <td>VS_BICEP_DEPLOY</td>
                        <td>VS_TF_DEPLOY</td>
                        <td>VS_OT_DEPLOY</td>
                        <td>VS_PULUMI_DEPLOY</td>
                    </tr>
                    <tr>
                        <td><strong>Destroy Speed</strong></td>
                        <td style="color: DESTROY_WINNER_COLOR; font-weight: bold;">🏆 DESTROY_WINNER_PLACEHOLDER</td>
                        <td>VS_BICEP_DESTROY</td>
                        <td>VS_TF_DESTROY</td>
                        <td>VS_OT_DESTROY</td>
                        <td>VS_PULUMI_DESTROY</td>
                    </tr>
                </tbody>
            </table>
        </div>
        
        <footer>
            <p><strong>Azure IaC Benchmark Tool</strong></p>
            <p>Run: DATETIME_PLACEHOLDER | ITERATIONS_PLACEHOLDER Iterations | West Europe</p>
        </footer>
    </div>
    
    <script>
        // Deploy Time Chart
        new Chart(document.getElementById('deployChart').getContext('2d'), {
            type: 'bar',
            data: {
                labels: ['Bicep', 'Terraform', 'OpenTofu', 'Pulumi'],
                datasets: [{
                    label: 'Avg Deploy Time (s)',
                    data: [BICEP_DEPLOY_AVG, TF_DEPLOY_AVG, OT_DEPLOY_AVG, PULUMI_DEPLOY_AVG],
                    backgroundColor: ['rgba(0,120,212,0.8)', 'rgba(123,66,188,0.8)', 'rgba(255,218,24,0.8)', 'rgba(247,191,42,0.8)'],
                    borderColor: ['rgba(0,120,212,1)', 'rgba(123,66,188,1)', 'rgba(255,218,24,1)', 'rgba(247,191,42,1)'],
                    borderWidth: 2,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: { display: true, text: 'Average Deploy Time (seconds)', font: { size: 16, weight: 'bold' } },
                    legend: { display: false }
                },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Seconds' } } }
            }
        });
        
        // Destroy Time Chart
        new Chart(document.getElementById('destroyChart').getContext('2d'), {
            type: 'bar',
            data: {
                labels: ['Bicep', 'Terraform', 'OpenTofu', 'Pulumi'],
                datasets: [{
                    label: 'Avg Destroy Time (s)',
                    data: [BICEP_DESTROY_AVG, TF_DESTROY_AVG, OT_DESTROY_AVG, PULUMI_DESTROY_AVG],
                    backgroundColor: ['rgba(0,120,212,0.8)', 'rgba(123,66,188,0.8)', 'rgba(255,218,24,0.8)', 'rgba(247,191,42,0.8)'],
                    borderColor: ['rgba(0,120,212,1)', 'rgba(123,66,188,1)', 'rgba(255,218,24,1)', 'rgba(247,191,42,1)'],
                    borderWidth: 2,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: { display: true, text: 'Average Destroy Time (seconds)', font: { size: 16, weight: 'bold' } },
                    legend: { display: false }
                },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Seconds' } } }
            }
        });
        
        // Iteration Chart
        new Chart(document.getElementById('iterationChart').getContext('2d'), {
            type: 'line',
            data: {
                labels: [ITERATION_LABELS],
                datasets: [
                    {
                        label: 'Bicep Deploy',
                        data: [BICEP_DEPLOY_TIMES],
                        borderColor: 'rgba(0,120,212,1)',
                        backgroundColor: 'rgba(0,120,212,0.1)',
                        tension: 0.3,
                        fill: false
                    },
                    {
                        label: 'Terraform Deploy',
                        data: [TF_DEPLOY_TIMES],
                        borderColor: 'rgba(123,66,188,1)',
                        backgroundColor: 'rgba(123,66,188,0.1)',
                        tension: 0.3,
                        fill: false
                    },
                    {
                        label: 'OpenTofu Deploy',
                        data: [OT_DEPLOY_TIMES],
                        borderColor: 'rgba(255,218,24,1)',
                        backgroundColor: 'rgba(255,218,24,0.1)',
                        tension: 0.3,
                        fill: false
                    },
                    {
                        label: 'Pulumi Deploy',
                        data: [PULUMI_DEPLOY_TIMES],
                        borderColor: 'rgba(247,191,42,1)',
                        backgroundColor: 'rgba(247,191,42,0.1)',
                        tension: 0.3,
                        fill: false,
                        borderWidth: 2
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: { display: true, text: 'Deploy Time per Iteration', font: { size: 16, weight: 'bold' } },
                    legend: { position: 'bottom' }
                },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Seconds' } } }
            }
        });
        
        // Memory Chart
        new Chart(document.getElementById('memoryChart').getContext('2d'), {
            type: 'bar',
            data: {
                labels: ['Bicep', 'Terraform', 'OpenTofu', 'Pulumi'],
                datasets: [{
                    label: 'Peak Memory (MB)',
                    data: [BICEP_MEM_AVG, TF_MEM_AVG, OT_MEM_AVG, PULUMI_MEM_AVG],
                    backgroundColor: ['rgba(0,120,212,0.8)', 'rgba(123,66,188,0.8)', 'rgba(255,218,24,0.8)', 'rgba(247,191,42,0.8)'],
                    borderColor: ['rgba(0,120,212,1)', 'rgba(123,66,188,1)', 'rgba(255,218,24,1)', 'rgba(247,191,42,1)'],
                    borderWidth: 2,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: { display: true, text: 'Peak Memory Usage - Deploy (MB)', font: { size: 16, weight: 'bold' } },
                    legend: { display: false }
                },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'MB' } } }
            }
        });
        
        // CPU Chart
        new Chart(document.getElementById('cpuChart').getContext('2d'), {
            type: 'bar',
            data: {
                labels: ['Bicep', 'Terraform', 'OpenTofu', 'Pulumi'],
                datasets: [{
                    label: 'CPU Time (s)',
                    data: [BICEP_CPU_AVG, TF_CPU_AVG, OT_CPU_AVG, PULUMI_CPU_AVG],
                    backgroundColor: ['rgba(0,120,212,0.8)', 'rgba(123,66,188,0.8)', 'rgba(255,218,24,0.8)', 'rgba(247,191,42,0.8)'],
                    borderColor: ['rgba(0,120,212,1)', 'rgba(123,66,188,1)', 'rgba(255,218,24,1)', 'rgba(247,191,42,1)'],
                    borderWidth: 2,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: { display: true, text: 'CPU Time - Deploy (seconds)', font: { size: 16, weight: 'bold' } },
                    legend: { display: false }
                },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Seconds' } } }
            }
        });
    </script>
</body>
</html>
HTMLEOF

# Replace placeholders with actual values
sed -i "s/ITERATIONS_PLACEHOLDER/$ITERATIONS/g" "$HTML_FILE"
sed -i "s/DATETIME_PLACEHOLDER/$(date '+%B %d, %Y %H:%M')/g" "$HTML_FILE"
sed -i "s/DEPLOY_WINNER_PLACEHOLDER/$deploy_winner/g" "$HTML_FILE"
sed -i "s/DESTROY_WINNER_PLACEHOLDER/$destroy_winner/g" "$HTML_FILE"
sed -i "s/DEPLOY_BEST_PLACEHOLDER/$deploy_best/g" "$HTML_FILE"

# Winner description
if [ "$deploy_winner" = "$destroy_winner" ]; then
    sed -i "s/WINNER_DESC_PLACEHOLDER/Fastest Destroy (${destroy_best}s avg) - dominating both metrics!/g" "$HTML_FILE"
else
    sed -i "s/WINNER_DESC_PLACEHOLDER/Destroy winner: $destroy_winner (${destroy_best}s avg)/g" "$HTML_FILE"
fi

# Winner colors
case "$deploy_winner" in
    Bicep) sed -i "s/DEPLOY_WINNER_COLOR/var(--bicep-color)/g" "$HTML_FILE" ;;
    Terraform) sed -i "s/DEPLOY_WINNER_COLOR/var(--terraform-color)/g" "$HTML_FILE" ;;
    OpenTofu) sed -i "s/DEPLOY_WINNER_COLOR/var(--opentofu-color)/g" "$HTML_FILE" ;;
    "Pulumi") sed -i "s/DEPLOY_WINNER_COLOR/var(--pulumi-color)/g" "$HTML_FILE" ;;
    *) sed -i "s/DEPLOY_WINNER_COLOR/#888888/g" "$HTML_FILE" ;;
esac

case "$destroy_winner" in
    Bicep) sed -i "s/DESTROY_WINNER_COLOR/var(--bicep-color)/g" "$HTML_FILE" ;;
    Terraform) sed -i "s/DESTROY_WINNER_COLOR/var(--terraform-color)/g" "$HTML_FILE" ;;
    OpenTofu) sed -i "s/DESTROY_WINNER_COLOR/var(--opentofu-color)/g" "$HTML_FILE" ;;
    "Pulumi") sed -i "s/DESTROY_WINNER_COLOR/var(--pulumi-color)/g" "$HTML_FILE" ;;
    *) sed -i "s/DESTROY_WINNER_COLOR/#888888/g" "$HTML_FILE" ;;
esac

# Winner badges
if [ "$deploy_winner" = "Bicep" ] && [ "$destroy_winner" = "Bicep" ]; then
    sed -i 's/BICEP_BADGE_PLACEHOLDER/ <span class="badge winner">🏆 Winner<\/span>/g' "$HTML_FILE"
else
    sed -i 's/BICEP_BADGE_PLACEHOLDER//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "Terraform" ] && [ "$destroy_winner" = "Terraform" ]; then
    sed -i 's/TERRAFORM_BADGE_PLACEHOLDER/ <span class="badge winner">🏆 Winner<\/span>/g' "$HTML_FILE"
else
    sed -i 's/TERRAFORM_BADGE_PLACEHOLDER//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "OpenTofu" ] && [ "$destroy_winner" = "OpenTofu" ]; then
    sed -i 's/OPENTOFU_BADGE_PLACEHOLDER/ <span class="badge winner">🏆 Winner<\/span>/g' "$HTML_FILE"
else
    sed -i 's/OPENTOFU_BADGE_PLACEHOLDER//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "Pulumi" ] && [ "$destroy_winner" = "Pulumi" ]; then
    sed -i 's/PULUMI_BADGE_PLACEHOLDER/ <span class="badge winner">🏆 Winner<\/span>/g' "$HTML_FILE"
else
    sed -i 's/PULUMI_BADGE_PLACEHOLDER//g' "$HTML_FILE"
fi

# Fastest badges
if [ "$deploy_winner" = "Bicep" ]; then
    sed -i 's/BICEP_DEPLOY_FASTEST/ <span class="badge winner">Fastest<\\/span>/g' "$HTML_FILE"
else
    sed -i 's/BICEP_DEPLOY_FASTEST//g' "$HTML_FILE"
fi

if [ "$destroy_winner" = "Bicep" ]; then
    sed -i 's/BICEP_DESTROY_FASTEST/ <span class="badge winner">Fastest<\\/span>/g' "$HTML_FILE"
else
    sed -i 's/BICEP_DESTROY_FASTEST//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "Terraform" ]; then
    sed -i 's/TF_DEPLOY_FASTEST/ <span class="badge winner">Fastest<\\/span>/g' "$HTML_FILE"
else
    sed -i 's/TF_DEPLOY_FASTEST//g' "$HTML_FILE"
fi

if [ "$destroy_winner" = "Terraform" ]; then
    sed -i 's/TF_DESTROY_FASTEST/ <span class="badge winner">Fastest<\\/span>/g' "$HTML_FILE"
else
    sed -i 's/TF_DESTROY_FASTEST//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "OpenTofu" ]; then
    sed -i 's/OT_DEPLOY_FASTEST/ <span class="badge winner">Fastest<\/span>/g' "$HTML_FILE"
else
    sed -i 's/OT_DEPLOY_FASTEST//g' "$HTML_FILE"
fi

if [ "$destroy_winner" = "OpenTofu" ]; then
    sed -i 's/OT_DESTROY_FASTEST/ <span class="badge winner">Fastest<\/span>/g' "$HTML_FILE"
else
    sed -i 's/OT_DESTROY_FASTEST//g' "$HTML_FILE"
fi

if [ "$deploy_winner" = "Pulumi" ]; then
    sed -i 's/PULUMI_DEPLOY_FASTEST/ <span class="badge winner">Fastest<\/span>/g' "$HTML_FILE"
else
    sed -i 's/PULUMI_DEPLOY_FASTEST//g' "$HTML_FILE"
fi

if [ "$destroy_winner" = "Pulumi" ]; then
    sed -i 's/PULUMI_DESTROY_FASTEST/ <span class="badge winner">Fastest<\/span>/g' "$HTML_FILE"
else
    sed -i 's/PULUMI_DESTROY_FASTEST//g' "$HTML_FILE"
fi

# Metric values
sed -i "s/BICEP_DEPLOY_AVG/$bicep_deploy_avg/g" "$HTML_FILE"
sed -i "s/BICEP_DESTROY_AVG/$bicep_destroy_avg/g" "$HTML_FILE"
sed -i "s/BICEP_DEPLOY_MIN/$bicep_deploy_min/g" "$HTML_FILE"
sed -i "s/BICEP_DEPLOY_MAX/$bicep_deploy_max/g" "$HTML_FILE"
sed -i "s/BICEP_DESTROY_MIN/$bicep_destroy_min/g" "$HTML_FILE"
sed -i "s/BICEP_DESTROY_MAX/$bicep_destroy_max/g" "$HTML_FILE"

sed -i "s/TF_DEPLOY_AVG/$tf_deploy_avg/g" "$HTML_FILE"
sed -i "s/TF_DESTROY_AVG/$tf_destroy_avg/g" "$HTML_FILE"
sed -i "s/TF_DEPLOY_MIN/$tf_deploy_min/g" "$HTML_FILE"
sed -i "s/TF_DEPLOY_MAX/$tf_deploy_max/g" "$HTML_FILE"
sed -i "s/TF_DESTROY_MIN/$tf_destroy_min/g" "$HTML_FILE"
sed -i "s/TF_DESTROY_MAX/$tf_destroy_max/g" "$HTML_FILE"

sed -i "s/OT_DEPLOY_AVG/$ot_deploy_avg/g" "$HTML_FILE"
sed -i "s/OT_DESTROY_AVG/$ot_destroy_avg/g" "$HTML_FILE"
sed -i "s/OT_DEPLOY_MIN/$ot_deploy_min/g" "$HTML_FILE"
sed -i "s/OT_DEPLOY_MAX/$ot_deploy_max/g" "$HTML_FILE"
sed -i "s/OT_DESTROY_MIN/$ot_destroy_min/g" "$HTML_FILE"
sed -i "s/OT_DESTROY_MAX/$ot_destroy_max/g" "$HTML_FILE"

sed -i "s/PULUMI_DEPLOY_AVG/$pulumi_deploy_avg/g" "$HTML_FILE"
sed -i "s/PULUMI_DESTROY_AVG/$pulumi_destroy_avg/g" "$HTML_FILE"
sed -i "s/PULUMI_DEPLOY_MIN/$pulumi_deploy_min/g" "$HTML_FILE"
sed -i "s/PULUMI_DEPLOY_MAX/$pulumi_deploy_max/g" "$HTML_FILE"
sed -i "s/PULUMI_DESTROY_MIN/$pulumi_destroy_min/g" "$HTML_FILE"
sed -i "s/PULUMI_DESTROY_MAX/$pulumi_destroy_max/g" "$HTML_FILE"


# Iteration data
iteration_labels=""
for i in $(seq 1 $ITERATIONS); do
    iteration_labels="${iteration_labels}'Iteration $i'"
    [ $i -lt $ITERATIONS ] && iteration_labels="${iteration_labels}, "
done
sed -i "s|ITERATION_LABELS|$iteration_labels|g" "$HTML_FILE"

bicep_times=$(IFS=,; echo "${BICEP_DEPLOY_TIMES[*]}")
tf_times=$(IFS=,; echo "${TERRAFORM_DEPLOY_TIMES[*]}")
ot_times=$(IFS=,; echo "${OPENTOFU_DEPLOY_TIMES[*]}")
pulumi_times=$(IFS=,; echo "${PULUMI_DEPLOY_TIMES[*]}")

sed -i "s|BICEP_DEPLOY_TIMES|$bicep_times|g" "$HTML_FILE"
sed -i "s|TF_DEPLOY_TIMES|$tf_times|g" "$HTML_FILE"
sed -i "s|OT_DEPLOY_TIMES|$ot_times|g" "$HTML_FILE"
sed -i "s|PULUMI_DEPLOY_TIMES|$pulumi_times|g" "$HTML_FILE"

# Memory and CPU data for charts
sed -i "s/BICEP_MEM_AVG/$bicep_deploy_mem_avg/g" "$HTML_FILE"
sed -i "s/TF_MEM_AVG/$tf_deploy_mem_avg/g" "$HTML_FILE"
sed -i "s/OT_MEM_AVG/$ot_deploy_mem_avg/g" "$HTML_FILE"
sed -i "s/PULUMI_MEM_AVG/$pulumi_deploy_mem_avg/g" "$HTML_FILE"

sed -i "s/BICEP_CPU_AVG/$bicep_deploy_cpu_avg/g" "$HTML_FILE"
sed -i "s/TF_CPU_AVG/$tf_deploy_cpu_avg/g" "$HTML_FILE"
sed -i "s/OT_CPU_AVG/$ot_deploy_cpu_avg/g" "$HTML_FILE"
sed -i "s/PULUMI_CPU_AVG/$pulumi_deploy_cpu_avg/g" "$HTML_FILE"

# Comparison table - Calculate percentage differences from winner
calc_pct_diff() {
    local winner_val=$1
    local other_val=$2
    # Guard against divide by zero
    if [ "$(echo "$winner_val == 0" | bc -l)" = "1" ]; then
        echo "N/A"
        return
    fi
    echo "scale=1; (($other_val - $winner_val) / $winner_val) * 100" | bc
}

# Deploy comparisons
for tool in Bicep Terraform OpenTofu Pulumi; do
    case "$tool" in
        Bicep) tool_avg=$bicep_deploy_avg; placeholder="VS_BICEP_DEPLOY" ;;
        Terraform) tool_avg=$tf_deploy_avg; placeholder="VS_TF_DEPLOY" ;;
        OpenTofu) tool_avg=$ot_deploy_avg; placeholder="VS_OT_DEPLOY" ;;
        Pulumi) tool_avg=$pulumi_deploy_avg; placeholder="VS_PULUMI_DEPLOY" ;;
    esac
    
    if [ "$deploy_winner" = "$tool" ]; then
        sed -i "s|$placeholder|-|g" "$HTML_FILE"
    elif [ "$(echo "$tool_avg == 0" | bc -l)" = "1" ]; then
        sed -i "s|$placeholder|N/A|g" "$HTML_FILE"
    else
        pct=$(calc_pct_diff "$deploy_best" "$tool_avg")
        if [ "$pct" = "N/A" ]; then
            sed -i "s|$placeholder|N/A|g" "$HTML_FILE"
        else
            sed -i "s|$placeholder|${pct}% slower|g" "$HTML_FILE"
        fi
    fi
done

# Destroy comparisons
for tool in Bicep Terraform OpenTofu Pulumi; do
    case "$tool" in
        Bicep) tool_avg=$bicep_destroy_avg; placeholder="VS_BICEP_DESTROY" ;;
        Terraform) tool_avg=$tf_destroy_avg; placeholder="VS_TF_DESTROY" ;;
        OpenTofu) tool_avg=$ot_destroy_avg; placeholder="VS_OT_DESTROY" ;;
        Pulumi) tool_avg=$pulumi_destroy_avg; placeholder="VS_PULUMI_DESTROY" ;;
    esac
    
    if [ "$destroy_winner" = "$tool" ]; then
        sed -i "s|$placeholder|-|g" "$HTML_FILE"
    elif [ "$(echo "$tool_avg == 0" | bc -l)" = "1" ]; then
        sed -i "s|$placeholder|N/A|g" "$HTML_FILE"
    else
        pct=$(calc_pct_diff "$destroy_best" "$tool_avg")
        if [ "$pct" = "N/A" ]; then
            sed -i "s|$placeholder|N/A|g" "$HTML_FILE"
        else
            sed -i "s|$placeholder|${pct}% slower|g" "$HTML_FILE"
        fi
    fi
done

echo -e "${GREEN}HTML report saved to: $HTML_FILE${NC}"

# Open in browser if xdg-open is available
if command -v xdg-open &> /dev/null; then
    echo -e "${BLUE}Opening report in browser...${NC}"
    xdg-open "$HTML_FILE" 2>/dev/null &
fi
