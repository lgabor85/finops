# Azure Cost Discrepancy Analysis

## Summary of Findings

Based on the comparison between Azure Cost Management CSV exports and azure-cost-cli JSON data, here are the key findings:

### Cost Comparison (November & December 2025)

| Month | CSV (Portal) | JSON (CLI) | Difference | % Diff |
|-------|--------------|------------|------------|--------|
| Nov 2025 | 536,114.77 EUR | 530,075.72 EUR | +6,039.04 EUR | **+1.13%** ✓ |
| Dec 2025 | 545,078.48 EUR | 415,451.61 EUR | +129,626.86 EUR | **+23.78%** ⚠️ |

### Key Observations

#### ✓ November 2025 - Good Match (1.13% difference)
- **CSV Total**: 536,114.77 EUR
- **JSON Total**: 530,075.72 EUR
- **Difference**: Only 6,039.04 EUR (1.13%)
- **Status**: This is an acceptable variance, likely due to:
  - Rounding differences
  - Minor timing differences in data collection
  - Small adjustments or credits applied

#### ⚠️ December 2025 - Significant Discrepancy (23.78% difference)
- **CSV Total**: 545,078.48 EUR
- **JSON Total**: 415,451.61 EUR
- **Missing**: 129,626.86 EUR (23.78%)
- **Status**: This requires investigation

## Root Causes of Discrepancies

### 1. **Incomplete Subscription Coverage**
The JSON data includes **33 unique subscriptions**, but there may be more subscriptions in your Azure tenant that are:
- Not being queried by azure-cost-cli
- Missing from the PowerShell script subscription list
- Filtered out in the CLI queries

### 2. **Different Cost Types**
- **CSV Export**: May be using "Actual Cost" or include additional charges
- **JSON Data**: Uses "Amortized Cost" from azure-cost-cli
- **Impact**: Amortized cost spreads reservation/savings plan costs over time

### 3. **Negative Costs in JSON Data**
Several subscriptions show **negative costs** in the JSON data:
- `fb763b41-eaa1-43ee-8969-76497e13e2b9`: -11,671.75 EUR (November)
- `40c48167-5cf3-4267-97c7-8a7766ac84c9`: -119.44 EUR (November)
- `2edcf645-634c-424b-9f5e-8e0f254535ef`: -132.67 EUR (November)

These negative costs could be:
- Credits applied
- Refunds or adjustments
- Reservation purchases (which are then amortized)
- Data quality issues

### 4. **Partial or Missing Data**
Some JSON files failed to parse (empty or corrupted):
- `d9e77fd9-406e-426f-8753-058d56df8feb.json`
- `f884772e-37f7-4b9c-b90d-5621d9344116.json`
- `a824fe92-417a-41b8-99aa-ac9afbf2574a.json`
- `8a4696b3-bd42-4565-8216-00610beb6c9e.json`
- `9f7cf468-13f6-4e5f-833c-4e10d034385e.json`
- `94208a7b-f8ed-4732-bb1d-57f228824d0a.json`

These subscriptions may have costs that are included in the CSV but missing from JSON totals.

### 5. **Service Coverage Differences**
The CSV shows costs for service families that may not be fully captured in JSON:
- **AI + Machine Learning**: 4,861.55 EUR (Dec) - significant increase from 412.92 EUR (Nov)
- **Databases**: 224,103.75 EUR (Dec)
- **Compute**: 188,097.08 EUR (Dec)
- **Storage**: 77,109.48 EUR (Dec)

## Recommendations

### Immediate Actions

1. **Verify All Subscriptions Are Included**
   ```bash
   # List all subscriptions in your tenant
   az account list --query "[].{Name:name, ID:id, State:state}" -o table
   
   # Compare with subscriptions in JSON files
   find ~/Downloads/finops -name "december-*.json" | wc -l
   ```

2. **Check for Missing Subscriptions**
   - Count subscriptions in Azure portal
   - Count unique subscription IDs in JSON files (currently 33)
   - Identify any gaps

3. **Investigate Negative Costs**
   ```bash
   # Find subscriptions with negative costs
   grep -r "\"totalCostInTimeframe\": -" ~/Downloads/finops/
   ```

4. **Re-run azure-cost-cli for December**
   - Ensure all subscriptions are queried
   - Verify date range is complete (2025-12-01 to 2025-12-31)
   - Check for any errors during data collection

5. **Verify Cost Type Consistency**
   - Confirm CSV export uses "Amortized Cost"
   - Verify azure-cost-cli is using amortized cost (default)

### Long-term Solutions

1. **Automated Subscription Discovery**
   - Modify PowerShell scripts to dynamically discover all subscriptions
   - Add error handling for failed queries
   - Log any subscriptions that fail to return data

2. **Data Validation**
   - Add checks for negative costs
   - Validate JSON file completeness
   - Compare subscription counts between sources

3. **Reconciliation Process**
   - Run comparison script monthly
   - Investigate discrepancies > 5%
   - Document any known differences (credits, refunds, etc.)

## Expected vs Actual Costs

### November 2025 Analysis
- **Expected (CSV)**: 536,114.77 EUR
- **Calculated (JSON)**: 530,075.72 EUR
- **Variance**: 1.13% ✓ **ACCEPTABLE**

### December 2025 Analysis
- **Expected (CSV)**: 545,078.48 EUR
- **Calculated (JSON)**: 415,451.61 EUR
- **Variance**: 23.78% ⚠️ **REQUIRES INVESTIGATION**
- **Missing Amount**: 129,626.86 EUR

## Possible Missing Subscriptions

Based on the 23.78% discrepancy in December, approximately **129,626.86 EUR** is unaccounted for. This could represent:
- 1-2 large subscriptions with ~60,000-130,000 EUR/month
- 5-10 medium subscriptions with ~13,000-26,000 EUR/month
- Many small subscriptions totaling the difference

## Next Steps

1. ✅ Run the comparison script: `python3 compare_cost_sources.py`
2. ⬜ List all Azure subscriptions and compare with JSON file count
3. ⬜ Investigate the 6 failed JSON files
4. ⬜ Re-run azure-cost-cli for December with all subscriptions
5. ⬜ Verify negative cost subscriptions
6. ⬜ Update aggregation script to flag discrepancies > 5%
7. ⬜ Document any known exclusions (test subscriptions, etc.)

## Conclusion

The **November 2025** data shows good alignment (1.13% difference), indicating the methodology is sound. The **December 2025** discrepancy (23.78%) suggests:
- Missing subscription data in JSON files
- Failed or incomplete data collection for December
- Possible changes in subscription access or permissions

**Action Required**: Re-run the azure-cost-cli data collection for December 2025 ensuring all subscriptions are included and all queries complete successfully.
