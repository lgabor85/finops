$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
    Write-Host "Subscription: $id"

    # Make a filesystem-friendly tag (subscriptionId already is, but trimming is nice)
    $tag = $id.Trim()

    $novFile  = "november-$tag.json"
    $decFile  = "december-$tag.json"
    $diffFile = "diff-accumulatedCost-$tag.md"

    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-11-01 --to 2025-11-30 -o json |
        Out-File $novFile -Encoding utf8

    azure-cost accumulatedCost -s $id --timeframe Custom --from 2025-12-01 --to 2025-12-31 -o json |
        Out-File $decFile -Encoding utf8

    azure-cost diff --compare-from $novFile --compare-to $decFile |
        Out-File $diffFile -Encoding utf8
}
