$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    $id = $id.Trim()
    if (-not $id) { continue }

    Write-Host "Subscription: $id"

    $nov = "november-$id.json"
    $dec = "december-$id.json"
    $out = "diff_accumulatedCost-$id.txt"

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

    # Diff
    azure-cost diff --compare-from $nov --compare-to $dec |
        Out-File $out -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Diff failed)"; continue }
}
