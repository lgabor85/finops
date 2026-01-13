# Azure FinOps Cost Analysis Tools

A comprehensive collection of PowerShell scripts for Azure cost analysis, providing parameterized cost comparisons, anomaly detection, and detailed reporting across all Azure subscriptions.

## 🎯 Features

- 📊 **Parameterized Cost Comparisons**: Compare any two months using command-line parameters
- 💰 **Accumulated Cost Analysis**: Track total costs across time periods with ANSI-stripped output
- 🔍 **Resource-Level Analysis**: Detailed cost breakdown by individual Azure resources
- 🚨 **Anomaly Detection**: Automatically identify new costs, removed costs, and significant changes
- 📈 **Top 50 Cost Increases**: Focus on the most impactful cost changes
- 💵 **Multi-Currency Support**: Automatic currency detection and formatting
- 📄 **Subscription-Based Reports**: Individual reports per subscription with friendly names
- 🎨 **Clean Output**: ANSI escape codes and box-drawing characters stripped for readability
- 🔐 **Multi-Subscription Support**: Process all Azure subscriptions automatically

## 📋 Requirements

- PowerShell 5.1 or higher (PowerShell Core 7+ recommended)
- [Azure Cost CLI](https://github.com/mivano/azure-cost-cli) installed and configured
- Azure CLI (`az`) installed and authenticated
- Access to Azure subscriptions with Cost Management permissions

## 🚀 Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd finops
```

2. Install Azure Cost CLI:
```bash
# Using dotnet tool
dotnet tool install -g azure-cost-cli

# Or download from releases
# https://github.com/mivano/azure-cost-cli/releases
```

3. Authenticate with Azure:
```bash
az login
```

## 💻 Usage

### Accumulated Cost Analysis

Compare accumulated costs between any two months across all subscriptions:

```powershell
# Navigate to the script directory
cd finops/azure/cost_analysis/diff_accumulated

# Compare costs between two months
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
```

**Parameters:**
- `-SourceMonth`: Source month in `YYYY-MM` format (e.g., "2025-11")
- `-TargetMonth`: Target month in `YYYY-MM` format (e.g., "2025-12")

**Output Files:**
- `YYYY-MM-SubscriptionName.json` - Raw cost data for each subscription
- `diff_accumulatedCost-SubscriptionName-YYYY-MM-vs-YYYY-MM.txt` - Clean diff report

### Resource-Level Cost Analysis

Analyze costs at the resource level with anomaly detection:

```powershell
# Navigate to the script directory
cd finops/azure/cost_analysis/diff_resource

# Compare resource costs between two months
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"

# With custom thresholds
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0
```

**Parameters:**
- `-SourceMonth`: Source month in `YYYY-MM` format (required)
- `-TargetMonth`: Target month in `YYYY-MM` format (required)
- `-SignificantChangeThreshold`: Percentage threshold for significant changes (default: 0.5 = 50%)
- `-MinimumCostThreshold`: Minimum cost in currency units to consider (default: 1.0)

**Output Files:**
- `YYYY-MM-resources-SubscriptionName.json` - Raw resource cost data
- `diff-resources-top50-SubscriptionName.txt` - Top 50 cost increases with anomalies

## 📊 Output Report Structure

### Accumulated Cost Reports

Clean, ANSI-stripped diff reports showing:
- Total cost comparison between source and target months
- Cost breakdown by service
- Absolute and percentage changes
- Easy-to-read plain text format

### Resource-Level Reports

Comprehensive reports including:

#### 1. Top 50 Cost Increases
Table showing resources with the highest cost increases:
- Service name
- Resource group
- Location
- Source month cost
- Target month cost
- Change amount
- "New?" indicator for newly created resources
- Full resource name/path

#### 2. Summary Section
- Total costs for new resources and increases
- Aggregate change metrics

#### 3. Detected Anomalies

**💰 New Costs Detected:**
- Resources that appeared in the target month
- Sorted by cost impact

**💸 Costs Removed:**
- Resources that disappeared in the target month
- Potential cost savings or decommissioned resources

**📊 Significant Cost Changes:**
- Resources exceeding the change threshold
- Both increases and decreases
- Percentage change calculations

## 📁 Directory Structure

```
finops/
├── README.md                                  # This file
├── LICENSE                                    # MIT License
├── .gitignore                                 # Git ignore rules
└── azure/
    └── cost_analysis/
        ├── requirements.txt                   # Python dependencies (if needed)
        ├── diff_accumulated/
        │   └── accumulatedCost.ps1           # Parameterized accumulated cost comparison
        └── diff_resource/
            └── diff_costByResource.ps1       # Parameterized resource-level analysis with anomaly detection
```

## 📝 Script Details

### accumulatedCost.ps1

**Purpose:** Compare total accumulated costs between two months with clean output

**Key Features:**
- Parameterized date ranges (no hardcoded months)
- Dynamic output file naming with subscription names
- ANSI escape code stripping for clean text output
- Box-drawing character replacement
- Error handling for invalid date formats
- Processes all subscriptions automatically

**How it works:**
1. Parses source and target month parameters
2. Calculates first and last day of each month
3. Retrieves all Azure subscriptions
4. For each subscription:
   - Exports accumulated cost data as JSON
   - Runs diff comparison using azure-cost CLI
   - Strips ANSI codes and formatting characters
   - Saves clean report to text file

### diff_costByResource.ps1

**Purpose:** Detailed resource-level cost analysis with anomaly detection

**Key Features:**
- Parameterized date ranges and thresholds
- Composite key handling for non-resource items (refunds, purchases, reservations)
- Top 50 cost increases focus
- Automatic anomaly detection with three categories
- Configurable sensitivity thresholds
- Summary statistics and totals

**How it works:**
1. Parses parameters and validates date formats
2. Retrieves all Azure subscriptions with names
3. For each subscription:
   - Exports resource-level cost data for both months
   - Builds cost maps using composite keys
   - Identifies resources with cost increases
   - Detects anomalies (new, removed, significant changes)
   - Generates formatted report with top 50 increases
   - Appends anomaly analysis sections

## 📈 Example Output

### Accumulated Cost Report Example

```
Azure Cost Diff (Accumulated)
Source: (2025-11-01 to 2025-11-30)
Target: (2025-12-01 to 2025-12-31)

| TOTAL COSTS | 9,499.42 EUR | 1,620.68 EUR | -7,878.74 EUR |
| Service A   | 5,234.12 EUR | 1,123.45 EUR | -4,110.67 EUR |
| Service B   | 4,265.30 EUR |   497.23 EUR | -3,768.07 EUR |
```

### Resource-Level Report Example

```
                    Azure Cost Diff (Resource Level)
                    Source: (2025-11-01 to 2025-11-30)
                    Target: (2025-12-01 to 2025-12-31)

Service          ResourceGrp    Location    Source         Target         Change         New?  Name
-------          -----------    --------    ------         ------         ------         ----  ----
Virtual Machines rg-prod-01     westeurope  1,234.56 EUR   2,345.67 EUR   +1,111.11 EUR       vm-prod-web-01
Storage          rg-storage     eastus      0.00 EUR       567.89 EUR     +567.89 EUR    YES  storageaccount123

Summary
-------
Comparison                          Source           Target           Change
----------                          ------           ------           ------
TOTAL COSTS (new + increases)       1,234.56 EUR     2,913.56 EUR     +1,679.00 EUR

=== DETECTED ANOMALIES ===

💰 NEW COSTS DETECTED:
Resource                Service    Resource Group  Location   November 2025  December 2025  Change
--------                -------    --------------  --------   -------------  -------------  ------
storageaccount123       Storage    rg-storage      eastus     0.00 EUR       567.89 EUR     +567.89 EUR

📊 SIGNIFICANT COST CHANGES:
Resource                Service            Resource Group  Location    November 2025  December 2025  Change          Percent
--------                -------            --------------  --------    -------------  -------------  ------          -------
vm-prod-web-01          Virtual Machines   rg-prod-01      westeurope  1,234.56 EUR   2,345.67 EUR   +1,111.11 EUR  +90.00%

Total anomalies detected: 2
```

## 🔧 Configuration

### Default Settings

**accumulatedCost.ps1:**
- Output format: Clean text (ANSI-stripped)
- File naming: Uses subscription names
- Date format: YYYY-MM

**diff_costByResource.ps1:**
- Significant change threshold: 50% (0.5)
- Minimum cost threshold: 1.0 (currency units)
- Top results shown: 50 resources
- Anomaly categories: New costs, removed costs, significant changes

### Customization

Modify thresholds when running the resource analysis:

```powershell
# More sensitive anomaly detection (30% threshold, 5 EUR minimum)
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0

# Less sensitive (100% threshold, 10 EUR minimum)
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 1.0 `
    -MinimumCostThreshold 10.0
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Make your changes
4. Commit: `git commit -m "Add new feature"`
5. Push: `git push origin feature/new-feature`
6. Submit a Pull Request

## 📄 License

MIT License - feel free to use this project for your own FinOps needs.

## 👤 Author

Azure FinOps Team

## 🐛 Issues

If you encounter any issues or have suggestions, please file an issue on the GitHub repository.

## 📚 Additional Resources

- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [FinOps Foundation](https://www.finops.org/)
- [Azure Cost CLI](https://github.com/mivano/azure-cost-cli)

## 🔄 Version History

- **v2.0.0** - Restructured with parameterized scripts and anomaly detection
  - Moved to organized directory structure
  - Parameterized date ranges (no hardcoded months)
  - Added anomaly detection to resource analysis
  - Dynamic file naming with subscription names
  - Improved error handling and validation
- **v1.0.0** - Initial release with basic cost comparison scripts
