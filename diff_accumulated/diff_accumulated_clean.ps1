# Azure Cost Diff - Clean Text Version
# This script compares costs between two months and produces clean, 
# readable text output without ANSI escape codes or special characters

$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    $id = $id.Trim()
    if (-not $id) { continue }

    Write-Host "Processing subscription: $id"

    $nov = "november-$id.json"
    $dec = "december-$id.json"
    $out = "diff_accumulatedCost-$id-clean.txt"

    # November
    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-11-01 --to 2025-11-30 -o json |
        Out-File $nov -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Nov failed)"; continue }
    if (-not (Test-Path $nov) -or (Get-Item $nov).Length -eq 0) { Write-Warning "Skipping $id (Nov empty)"; continue }

    # December
    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-12-01 --to 2025-12-31 -o json |
        Out-File $dec -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Dec failed)"; continue }
    if (-not (Test-Path $dec) -or (Get-Item $dec).Length -eq 0) { Write-Warning "Skipping $id (Dec empty)"; continue }

    # Process JSON data directly to create clean text output
    $novData = Get-Content $nov -Raw | ConvertFrom-Json
    $decData = Get-Content $dec -Raw | ConvertFrom-Json

    # Create a clean text report
    $report = @"
Azure Cost Diff (Clean Text Format)
===================================

Subscription: $id
Source Period: November 1-30, 2025
Target Period: December 1-31, 2025

"@

    # Process Services
    $report += "SERVICES BREAKDOWN`n"
    $report += "==================`n"
    $report += "{0,-40} {1,-15} {2,-15} {3,-15}`n" -f "Service Name", "Nov 2025", "Dec 2025", "Change"
    $report += ("-" * 80) + "`n"

    # Create maps for easier comparison
    $novMap = @{}
    foreach ($item in $novData.byServiceNames) {
        if ($item.ServiceName) {
            $novMap[$item.ServiceName] = $item.Cost
        }
    }

    $decMap = @{}
    foreach ($item in $decData.byServiceNames) {
        if ($item.ServiceName) {
            $decMap[$item.ServiceName] = $item.Cost
        }
    }

    # Get all unique service names
    $allServices = ($novMap.Keys + $decMap.Keys) | Sort-Object -Unique

    $totalNov = 0
    $totalDec = 0

    foreach ($service in $allServices) {
        $novCost = [double]($novMap[$service] ?? 0)
        $decCost = [double]($decMap[$service] ?? 0)
        $change = $decCost - $novCost

        $totalNov += $novCost
        $totalDec += $decCost

        # Format change with + or - sign
        if ($change -ge 0) {
            $changeFormatted = "+{0:N2}" -f $change
        } else {
            $changeFormatted = "{0:N2}" -f $change
        }

        $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f $service, $novCost, $decCost, $changeFormatted
    }

    $totalChange = $totalDec - $totalNov

    # Format total change with + or - sign
    if ($totalChange -ge 0) {
        $totalChangeFormatted = "+{0:N2}" -f $totalChange
    } else {
        $totalChangeFormatted = "{0:N2}" -f $totalChange
    }

    $report += ("-" * 80) + "`n"
    $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f "TOTAL", $totalNov, $totalDec, $totalChangeFormatted
    $report += "`n"

    # Process Locations
    $report += "LOCATIONS BREAKDOWN`n"
    $report += "===================`n"
    $report += "{0,-40} {1,-15} {2,-15} {3,-15}`n" -f "Location Name", "Nov 2025", "Dec 2025", "Change"
    $report += ("-" * 80) + "`n"

    # Create maps for easier comparison
    $novLocationMap = @{}
    foreach ($item in $novData.ByLocation) {
        if ($item.Location) {
            $novLocationMap[$item.Location] = $item.Cost
        }
    }

    $decLocationMap = @{}
    foreach ($item in $decData.ByLocation) {
        if ($item.Location) {
            $decLocationMap[$item.Location] = $item.Cost
        }
    }

    # Get all unique location names
    $allLocations = ($novLocationMap.Keys + $decLocationMap.Keys) | Sort-Object -Unique

    $totalLocationNov = 0
    $totalLocationDec = 0

    foreach ($location in $allLocations) {
        $novCost = [double]($novLocationMap[$location] ?? 0)
        $decCost = [double]($decLocationMap[$location] ?? 0)
        $change = $decCost - $novCost

        $totalLocationNov += $novCost
        $totalLocationDec += $decCost

        # Format change with + or - sign
        if ($change -ge 0) {
            $changeFormatted = "+{0:N2}" -f $change
        } else {
            $changeFormatted = "{0:N2}" -f $change
        }

        $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f $location, $novCost, $decCost, $changeFormatted
    }

    $totalLocationChange = $totalLocationDec - $totalLocationNov

    # Format total change with + or - sign
    if ($totalLocationChange -ge 0) {
        $totalLocationChangeFormatted = "+{0:N2}" -f $totalLocationChange
    } else {
        $totalLocationChangeFormatted = "{0:N2}" -f $totalLocationChange
    }

    $report += ("-" * 80) + "`n"
    $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f "TOTAL", $totalLocationNov, $totalLocationDec, $totalLocationChangeFormatted
    $report += "`n"

    # Process Resource Groups
    $report += "RESOURCE GROUPS BREAKDOWN`n"
    $report += "=========================`n"
    $report += "{0,-40} {1,-15} {2,-15} {3,-15}`n" -f "Resource Group Name", "Nov 2025", "Dec 2025", "Change"
    $report += ("-" * 80) + "`n"

    # Create maps for easier comparison
    $novResourceGroupMap = @{}
    foreach ($item in $novData.ByResourceGroup) {
        if ($item.ResourceGroup) {
            $novResourceGroupMap[$item.ResourceGroup] = $item.Cost
        }
    }

    $decResourceGroupMap = @{}
    foreach ($item in $decData.ByResourceGroup) {
        if ($item.ResourceGroup) {
            $decResourceGroupMap[$item.ResourceGroup] = $item.Cost
        }
    }

    # Get all unique resource group names
    $allResourceGroups = ($novResourceGroupMap.Keys + $decResourceGroupMap.Keys) | Sort-Object -Unique

    $totalResourceGroupNov = 0
    $totalResourceGroupDec = 0

    foreach ($resourceGroup in $allResourceGroups) {
        $novCost = [double]($novResourceGroupMap[$resourceGroup] ?? 0)
        $decCost = [double]($decResourceGroupMap[$resourceGroup] ?? 0)
        $change = $decCost - $novCost

        $totalResourceGroupNov += $novCost
        $totalResourceGroupDec += $decCost

        # Format change with + or - sign
        if ($change -ge 0) {
            $changeFormatted = "+{0:N2}" -f $change
        } else {
            $changeFormatted = "{0:N2}" -f $change
        }

        $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f $resourceGroup, $novCost, $decCost, $changeFormatted
    }

    $totalResourceGroupChange = $totalResourceGroupDec - $totalResourceGroupNov

    # Format total change with + or - sign
    if ($totalResourceGroupChange -ge 0) {
        $totalResourceGroupChangeFormatted = "+{0:N2}" -f $totalResourceGroupChange
    } else {
        $totalResourceGroupChangeFormatted = "{0:N2}" -f $totalResourceGroupChange
    }

    $report += ("-" * 80) + "`n"
    $report += "{0,-40} {1,-15:N2} {2,-15:N2} {3,-15}`n" -f "TOTAL", $totalResourceGroupNov, $totalResourceGroupDec, $totalResourceGroupChangeFormatted
    $report += "`n"

    # Summary
    $report += "SUMMARY`n"
    $report += "=======`n"
    $report += "Total cost in November 2025: EUR {0:N2}`n" -f $totalNov
    $report += "Total cost in December 2025: EUR {0:N2}`n" -f $totalDec
    $report += "Net change: EUR {0}`n" -f $totalChangeFormatted
    $report += "`n"

    if ($totalChange -lt 0) {
        $report += "Costs decreased by EUR {0:N2} from November to December.`n" -f [Math]::Abs($totalChange)
    } else {
        $report += "Costs increased by EUR {0:N2} from November to December.`n" -f $totalChange
    }

    # Write the clean report
    $report | Out-File $out -Encoding utf8
    Write-Host "Clean text report saved to: $out"
}