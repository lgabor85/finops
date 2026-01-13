# Changelog - Azure Cost Analysis Module

All notable changes to the Azure Cost Analysis module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

#### Scope Expansion
- [ ] Support for management group scope analysis
- [ ] Support for billing account scope analysis
- [ ] Support for resource group scope analysis
- [ ] Configurable scope parameter for all scripts
- [ ] Hierarchical cost rollup across scopes

#### Tag-Based Filtering
- [ ] Filter resources by purpose tags (e.g., "Production", "Development", "Testing")
- [ ] Filter resources by business function tags (e.g., "Finance", "Engineering", "Marketing")
- [ ] Filter by cost center or department tags
- [ ] Filter by project or application tags
- [ ] Custom tag-based filtering with multiple criteria
- [ ] Tag compliance reporting
- [ ] Untagged resource identification

#### Log Analytics Integration
- [ ] Query Azure Activity Log for resource changes
- [ ] Correlate VM resize events with cost changes
- [ ] Track VM start/stop events and their cost impact
- [ ] Monitor database scaling operations (scale up/down)
- [ ] Detect resource deletions and their cost savings
- [ ] Track new resource deployments
- [ ] Identify configuration changes affecting cost
- [ ] Generate timeline of changes with cost correlation
- [ ] Export change history with cost impact analysis

#### Advanced Analytics
- [ ] Cost forecasting based on historical trends
- [ ] Anomaly detection using machine learning
- [ ] Seasonal pattern recognition
- [ ] Cost optimization recommendations
- [ ] Idle resource detection
- [ ] Right-sizing recommendations

#### Reporting Enhancements
- [ ] HTML report generation with charts
- [ ] Excel export with multiple worksheets
- [ ] Email report delivery
- [ ] Scheduled report automation
- [ ] Dashboard integration (Power BI, Grafana)

## [2.0.0] - 2026-01-13

### Added
- Parameterized date ranges for flexible month comparisons
- Dynamic output file naming using subscription names
- Anomaly detection with three categories:
  - New costs (resources that appeared)
  - Removed costs (resources that disappeared)
  - Significant cost changes (exceeding threshold)
- Configurable sensitivity thresholds for anomaly detection
- Top 50 cost increases focus in resource analysis
- Comprehensive error handling with try-catch blocks
- Module-specific README with detailed documentation
- Usage examples and troubleshooting guide

### Changed
- **BREAKING**: Restructured into modular directory format
  - `diff_accumulated/` for accumulated cost scripts
  - `diff_resource/` for resource-level scripts
- **BREAKING**: All scripts now require month parameters
  - `-SourceMonth` parameter (format: YYYY-MM)
  - `-TargetMonth` parameter (format: YYYY-MM)
- File naming convention changed from subscription IDs to names
- Month display now includes year (e.g., "November 2025")
- Improved variable naming consistency (PascalCase)

### Fixed
- String splitting for subscription ID and name extraction
- Array bounds checking when parsing subscription data
- Indentation in try-catch blocks
- Error messages now reference correct parameter names
- Composite key handling for resources without ResourceId

### Improved
- **accumulatedCost.ps1**:
  - ANSI escape code stripping for clean output
  - Box-drawing character replacement
  - Better error messages with parameter validation
  - UTF-8 encoding for international character support
  
- **diff_costByResource.ps1**:
  - Composite key function for non-resource items (refunds, purchases, reservations)
  - Resource display name extraction from Azure Resource IDs
  - Formatted anomaly reports with emoji indicators
  - Summary statistics and totals
  - Configurable thresholds via parameters

## [1.0.0] - 2025

### Added
- Initial release of Azure cost comparison scripts
- Basic accumulated cost comparison functionality
- Basic resource-level cost comparison
- Support for multiple Azure subscriptions
- JSON output from Azure Cost CLI integration
- Diff comparison capabilities
- ANSI-formatted console output

### Features
- Hardcoded date ranges for specific month comparisons
- Subscription ID-based file naming
- Basic cost aggregation
- Simple diff reports

---

## Version Comparison

| Version | Scope Support | Tag Filtering | Log Analytics | Anomaly Detection | Parameterized |
|---------|---------------|---------------|---------------|-------------------|---------------|
| 3.0.0   | ✅ Planned    | ✅ Planned    | ✅ Planned    | ✅ Yes            | ✅ Yes        |
| 2.0.0   | ❌ Subscription only | ❌ No | ❌ No         | ✅ Yes            | ✅ Yes        |
| 1.0.0   | ❌ Subscription only | ❌ No | ❌ No         | ❌ No             | ❌ No         |

## Migration Guides

### Upgrading from 1.0.0 to 2.0.0

#### Script Location Changes
```bash
# Old (v1.0.0)
finops/diff_accumulated_stripped_nov_dec.ps1
finops/diff_resource_nov_dec.ps1

# New (v2.0.0)
finops/azure/cost_analysis/diff_accumulated/accumulatedCost.ps1
finops/azure/cost_analysis/diff_resource/diff_costByResource.ps1
```

#### Usage Changes
```powershell
# Old (v1.0.0) - hardcoded months
.\diff_accumulated_stripped_nov_dec.ps1

# New (v2.0.0) - parameterized
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
```

#### Output File Changes
```bash
# Old naming
november-<subscription-id>.json
diff_accumulatedCost-<subscription-id>-stripped.txt

# New naming
2025-11-SubscriptionName.json
diff_accumulatedCost-SubscriptionName-2025-11-vs-2025-12.txt
```

### Preparing for 3.0.0 (Future)

When version 3.0.0 is released with scope support, tag filtering, and Log Analytics integration:

#### Expected New Parameters
```powershell
# Scope selection
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -Scope "ManagementGroup" `
    -ScopeId "/providers/Microsoft.Management/managementGroups/mg-prod"

# Tag-based filtering
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -FilterByTag @{Environment="Production"; CostCenter="Engineering"}

# Log Analytics integration
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -IncludeChangeHistory `
    -LogAnalyticsWorkspaceId "<workspace-id>"
```

## Roadmap

### Version 3.0.0 (Planned)
**Focus:** Scope expansion, tag filtering, and change correlation

**Target Features:**
- Multi-scope support (management group, billing account, resource group)
- Tag-based resource filtering and grouping
- Log Analytics integration for change history
- Change-to-cost correlation analysis
- Enhanced reporting with change timeline

**Estimated Timeline:** Q2 2026

### Version 3.1.0 (Planned)
**Focus:** Advanced analytics and recommendations

**Target Features:**
- Cost forecasting
- ML-based anomaly detection
- Right-sizing recommendations
- Idle resource detection
- Optimization suggestions

**Estimated Timeline:** Q3 2026

### Version 4.0.0 (Planned)
**Focus:** Reporting and automation

**Target Features:**
- HTML/Excel report generation
- Email delivery
- Scheduled automation
- Dashboard integration
- API endpoints

**Estimated Timeline:** Q4 2026

## Feature Request Process

To request new features or enhancements:

1. Check the [Unreleased] section to see if it's already planned
2. Open an issue on GitHub with the "enhancement" label
3. Describe the use case and expected behavior
4. Include examples if possible

## Contributing to Changelog

When contributing changes:

1. Add entries under `[Unreleased]` section
2. Use appropriate categories:
   - **Added**: New features
   - **Changed**: Changes to existing functionality
   - **Deprecated**: Soon-to-be removed features
   - **Removed**: Removed features
   - **Fixed**: Bug fixes
   - **Security**: Security fixes
3. Mark breaking changes with **BREAKING**
4. Include migration notes for breaking changes
5. Update version comparison table if needed

## References

- [Main Project Changelog](../../CHANGELOG.md)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
