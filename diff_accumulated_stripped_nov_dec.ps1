# Azure Cost Diff - ANSI Stripped Version
# This script compares costs between two months and strips ANSI escape codes
# for better readability in basic text editors

$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    $id = $id.Trim()
    if (-not $id) { continue }

    Write-Host "Processing subscription: $id"

    $nov = "november-$id.json"
    $dec = "december-$id.json"
    $out = "diff_accumulatedCost-$id-stripped.txt"

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

    # Diff with ANSI codes
    $diffWithAnsi = azure-cost diff --compare-from $nov --compare-to $dec

    # Strip ANSI escape codes using regex
    $ansiRegex = '\x1b\[[0-9;]*m'
    $cleanOutput = $diffWithAnsi -replace $ansiRegex, ''

    # Also replace box drawing characters for even cleaner output
    $cleanOutput = $cleanOutput -replace '┌|┬|┐|├|┼|┤|└|┴|┘|│|─|╭|╮|╰|╯', '|'

    # Write the clean output
    $cleanOutput | Out-File $out -Encoding utf8
    Write-Host "ANSI-stripped report saved to: $out"
}