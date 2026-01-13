# Azure Cost Diff - Plain Text Version
# This script compares costs between two months and produces clean text output
# without ANSI escape codes for better readability in basic text editors

$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    $id = $id.Trim()
    if (-not $id) { continue }

    Write-Host "Processing subscription: $id"

    $nov = "november-$id.json"
    $dec = "december-$id.json"
    $out = "diff_accumulatedCost-$id-plain.txt"

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
Azure Cost Diff (Plain Text)
============================

Subscription: $id
Source: (11/1/2025 to 11/30/2025)
Target: (12/1/2025 to 12/31/2025)

"@

    # Process Services
    $report += "SERVICES BREAKDOWN`n"
    $report += "------------------`n"
    $report += "{0,-35} {1,-15} {2,-15} {3,-15}`n" -f "Service Name", "Nov 2025 (EUR)", "Dec 2025 (EUR)", "Change (EUR)"
    $report += ("-" * 70) + "`n"

    # Create maps for easier comparison
    $novMap = @{}
    foreach ($item in $novData) {
        if ($item.Name) {
            $novMap[$item.Name] = $item.Cost
        }
    }

    $decMap = @{}
    foreach ($item in $decData) {
        if ($item.Name) {
            $decMap[$item.Name] = $item.Cost
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

        $report += "{0,-35} {1,-15:N2} {2,-15:N2} {3,-15:N2}`n" -f $service, $novCost, $decCost, $change
    }

    $totalChange = $totalDec - $totalNov

    $report += ("-" * 70) + "`n"
    $report += "{0,-35} {1,-15:N2} {2,-15:N2} {3,-15:N2}`n" -f "TOTAL", $totalNov, $totalDec, $totalChange
    $report += "`n"

    # Write the clean report
    $report | Out-File $out -Encoding utf8
    Write-Host "Plain text report saved to: $out"
}