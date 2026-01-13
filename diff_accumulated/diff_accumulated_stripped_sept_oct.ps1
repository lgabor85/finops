# Azure Cost Diff - ANSI Stripped Version (September vs October)
# This script compares costs between September and October and strips ANSI escape codes
# for better readability in basic text editors

$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    $id = $id.Trim()
    if (-not $id) { continue }

    Write-Host "Processing subscription: $id"

    $sept = "september-$id.json"
    $oct = "october-$id.json"
    $out = "diff_accumulatedCost-$id-stripped-sept-oct.txt"

    # September
    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-09-01 --to 2025-09-30 -o json |
        Out-File $sept -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Sept failed)"; continue }
    if (-not (Test-Path $sept) -or (Get-Item $sept).Length -eq 0) { Write-Warning "Skipping $id (Sept empty)"; continue }

    # October
    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-10-01 --to 2025-10-31 -o json |
        Out-File $oct -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Oct failed)"; continue }
    if (-not (Test-Path $oct) -or (Get-Item $oct).Length -eq 0) { Write-Warning "Skipping $id (Oct empty)"; continue }

    # Diff with ANSI codes
    $diffWithAnsi = azure-cost diff --compare-from $sept --compare-to $oct

    # Strip ANSI escape codes using regex
    $ansiRegex = '\x1b\[[0-9;]*m'
    $cleanOutput = $diffWithAnsi -replace $ansiRegex, ''

    # Also replace box drawing characters for even cleaner output
    $cleanOutput = $cleanOutput -replace '┌|┬|┐|├|┼|┤|└|┴|┘|│|─|╭|╮|╰|╯', '|'

    # Write the clean output
    $cleanOutput | Out-File $out -Encoding utf8
    Write-Host "ANSI-stripped report saved to: $out"
}