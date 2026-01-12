# Azure FinOps Cost Aggregator

A comprehensive Python script that recursively searches for Azure cost data files, extracts amortized cost information, and generates detailed cost reports with month-over-month comparisons across all Azure subscriptions.

## 🎯 Features

- 🔍 **Recursive File Search**: Automatically finds all cost data files containing "diff" in `~/Downloads/finops`
- 📊 **Multi-Source Data Extraction**: Parses both JSON and diff text files
- 💰 **Cost Aggregation**: Combines costs across all Azure subscriptions
- 📈 **Month-over-Month Analysis**: Compares November vs December 2025 costs
- 📉 **Percentage Calculations**: Automatic change percentage calculations
- 💵 **Currency Formatting**: Properly formatted EUR values with thousands separators
- 📄 **Consolidated Reporting**: Single comprehensive output file
- 🔐 **Subscription Tracking**: Extracts and tracks Azure subscription UUIDs

## 📋 Requirements

- Python 3.7 or higher
- No external dependencies (uses only Python standard library)

## 🚀 Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd finops
```

2. Verify Python version:
```bash
python3 --version
```

## 💻 Usage

### Basic Usage

1. Ensure your Azure cost data is in `~/Downloads/finops` directory
2. Run the aggregation script:
```bash
python3 aggregate_azure_cost.py
```

3. View the generated report:
```bash
cat total_amortized_costs_summary.txt
```

### PowerShell Scripts

The repository also includes several PowerShell scripts for Azure cost analysis:

- `diff_accumulated_stripped_nov_dec.ps1` - Compare November vs December accumulated costs
- `diff_accumulated_stripped_sept_oct.ps1` - Compare September vs October accumulated costs
- `diff_resource_nov_dec.ps1` - Resource-level cost comparison (Nov-Dec)
- `diff_resource_sept_oct.ps1` - Resource-level cost comparison (Sep-Oct)
- `diff_resource_anomalies.ps1` - Detect cost anomalies in resources
- `diff_monthly.ps1` - Monthly cost comparisons
- `diff_accumulated.ps1` - Accumulated cost analysis with ANSI formatting
- `diff_accumulated_clean.ps1` - Clean accumulated cost reports
- `diff_accumulated_plain.ps1` - Plain text accumulated cost reports

## 📊 Output Report Structure

The generated `total_amortized_costs_summary.txt` includes:

### 1. Grand Totals
Aggregated costs across all subscriptions with overall change metrics

### 2. Per-Subscription Breakdown
Individual subscription analysis including:
- November 2025 costs
- December 2025 costs
- Absolute change in EUR
- Percentage change
- Source file references

### 3. Summary Statistics
- Count of subscriptions with cost increases
- Count of subscriptions with cost decreases
- Average cost per subscription
- Overall trends

### 4. Month-over-Month Comparison
Detailed November vs December 2025 analysis with:
- Total costs for each month
- Absolute change
- Percentage change
- Alert indicators for significant changes

## 📁 File Structure

```
finops/
├── aggregate_azure_cost.py                    # Main Python aggregation script
├── diff_accumulated_stripped_nov_dec.ps1      # PowerShell: Nov-Dec comparison
├── diff_accumulated_stripped_sept_oct.ps1     # PowerShell: Sep-Oct comparison
├── diff_resource_nov_dec.ps1                  # PowerShell: Resource costs Nov-Dec
├── diff_resource_sept_oct.ps1                 # PowerShell: Resource costs Sep-Oct
├── diff_resource_anomalies.ps1                # PowerShell: Anomaly detection
├── diff_monthly.ps1                           # PowerShell: Monthly analysis
├── diff_accumulated.ps1                       # PowerShell: Accumulated costs
├── diff_accumulated_clean.ps1                 # PowerShell: Clean reports
├── diff_accumulated_plain.ps1                 # PowerShell: Plain text reports
├── README.md                                  # This file
├── .gitignore                                 # Git ignore rules
├── requirements.txt                           # Python dependencies
└── total_amortized_costs_summary.txt          # Generated report (not tracked)
```

## 📝 Data Format

### Expected Input Files

#### Diff Text Files
Text files with "diff" in filename containing cost comparison tables:
```
| TOTAL COSTS | 9,499.42 EUR | 1,620.68 EUR | -7,878.74 EUR |
```

#### JSON Files
Azure cost data with the following structure:
```json
{
  "totals": {
    "totalCostInTimeframe": 9499.41754182352
  },
  "cost": [...],
  "byServiceNames": [...],
  "ByLocation": [...],
  "ByResourceGroup": [...]
}
```

## 📈 Example Output

```
================================================================================
AZURE AMORTIZED COSTS SUMMARY REPORT
================================================================================
Generated: 2026-01-12 17:30:00
Source Directory: /home/user/Downloads/finops
Total Subscriptions Analyzed: 18
================================================================================

GRAND TOTALS - ALL SUBSCRIPTIONS
--------------------------------------------------------------------------------
Period                         Total Cost                Change                    % Change            
--------------------------------------------------------------------------------
November 2025                  50,234.56 EUR                                       
December 2025                  48,123.45 EUR             -2,111.11 EUR            -4.20%              
--------------------------------------------------------------------------------

PER-SUBSCRIPTION BREAKDOWN
================================================================================

SUBSCRIPTION #1: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
--------------------------------------------------------------------------------
  November 2025:  9,499.42 EUR
  December 2025:  1,620.68 EUR
  Change:         -7,878.74 EUR (-82.94%)
  Diff File:      diff_accumulatedCost-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx-stripped.txt
  Nov JSON:       november-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json
  Dec JSON:       december-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.json
```

## 🔧 Configuration

The script uses the following default settings:
- **Source Directory**: `~/Downloads/finops`
- **Output File**: `total_amortized_costs_summary.txt`
- **Currency**: EUR (Euro)
- **Comparison Months**: November 2025 vs December 2025

To modify these settings, edit the constants in [`aggregate_azure_cost.py`](aggregate_azure_cost.py).

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

- **v1.0.0** - Initial release with cost aggregation and reporting features
