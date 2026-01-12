# ------------------------------------------------------------
# Azure costByResource monthly diff per subscription with anomaly detection
# Includes: new items (not in November) + increases (Dec > Nov)
# Handles empty ResourceId rows (refunds/purchases/reservations) via composite key
# Produces: a .txt report per subscription with a 3-line header + formatted table
# ------------------------------------------------------------

function ItemKey($r) {
  # Prefer ResourceId if available
  if (-not [string]::IsNullOrWhiteSpace($r.ResourceId)) { return $r.ResourceId }

  # Fallback key for non-resource lines (refunds/purchases/reservations/etc.)
  "{0}|{1}|{2}|{3}|{4}|{5}" -f `
    $r.ChargeType, $r.ServiceName, $r.ServiceTier, $r.Meter, $r.ResourceLocation, $r.ResourceGroupName
}

function ItemName($r) {
  if (-not [string]::IsNullOrWhiteSpace($r.ResourceId)) { return $r.ResourceId }

  $parts = @()
  if ($r.ChargeType) { $parts += $r.ChargeType }
  if ($r.ServiceName) { $parts += $r.ServiceName }
  if ($r.Meter) { $parts += $r.Meter }
  if ($r.ResourceLocation) { $parts += $r.ResourceLocation }
  ($parts -join " • ")
}

function ResourceDisplayName($r) {
  if ([string]::IsNullOrWhiteSpace($r.ResourceId)) {
    return (ItemName $r)
  }

  $parts = $r.ResourceId.Trim('/') -split '/'

  # Everything after "providers/<provider>"
  $providerIndex = [Array]::IndexOf($parts, 'providers')
  if ($providerIndex -ge 0 -and $providerIndex + 2 -lt $parts.Length) {
    return ($parts[($providerIndex + 2)..($parts.Length - 1)] -join '/')
  }

  # Fallback: last segment
  return $parts[-1]
}

function Center([string]$text, [int]$width = 90) {
  if ([string]::IsNullOrEmpty($text)) { return "" }
  if ($text.Length -ge $width) { return $text }
  $pad = [math]::Floor(($width - $text.Length) / 2)
  (" " * $pad) + $text
}

# Function to detect anomalies in cost data
function Detect-CostAnomalies {
    param(
        [array]$NovData,
        [array]$DecData,
        [double]$SignificantChangeThreshold = 0.5,  # 50% change threshold
        [double]$MinimumCostThreshold = 1.0         # Minimum cost to consider
    )
    
    # Build SUM maps (key -> total cost)
    $novMap = @{}
    foreach ($r in $NovData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($novMap.ContainsKey($k)) { $novMap[$k] += $c } else { $novMap[$k] = $c }
    }

    $decMap = @{}
    foreach ($r in $DecData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($decMap.ContainsKey($k)) { $decMap[$k] += $c } else { $decMap[$k] = $c }
    }
    
    $anomalies = @()
    
    # Check all resources in December data
    foreach ($k in $decMap.Keys) {
        $decCost = [double]$decMap[$k]
        $novCost = [double]($novMap[$k] ?? 0)
        $change = $decCost - $novCost
        $percentChange = if ($novCost -ne 0) { [math]::Abs($change / $novCost) } else { [double]::PositiveInfinity }
        
        # Skip if below minimum cost threshold
        if ($decCost -lt $MinimumCostThreshold -and $novCost -lt $MinimumCostThreshold) {
            continue
        }
        
        # Check for new costs (appeared in Dec but not in Nov or Nov cost was 0)
        if (($novCost -eq 0 -or -not $novMap.ContainsKey($k)) -and $decCost -ge $MinimumCostThreshold) {
            # Get representative row for metadata
            $rep = $DecData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "NewCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                NovemberCost = $novCost
                DecemberCost = $decCost
                Change = $change
                PercentChange = if ($novCost -eq 0) { "N/A" } else { ("{0:P2}" -f $percentChange) }
                Message = "New cost detected"
            }
        }
        # Check for removed costs (existed in Nov but not in Dec or Dec cost is 0)
        elseif ($novCost -ge $MinimumCostThreshold -and $decCost -eq 0) {
            # Get representative row for metadata
            $rep = $NovData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "RemovedCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                NovemberCost = $novCost
                DecemberCost = $decCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = "Cost removed"
            }
        }
        # Check for significant changes
        elseif ($novCost -ge $MinimumCostThreshold -and $decCost -ge $MinimumCostThreshold -and $percentChange -ge $SignificantChangeThreshold) {
            # Get representative row for metadata
            $rep = $DecData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "SignificantChange"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                NovemberCost = $novCost
                DecemberCost = $decCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = if ($change -gt 0) { "Significant cost increase" } else { "Significant cost decrease" }
            }
        }
    }
    
    return $anomalies
}

# Function to append anomalies to file
function Append-AnomaliesToFile {
    param(
        [array]$Anomalies,
        [string]$Currency,
        [string]$OutFile
    )
    
    if ($Anomalies.Count -eq 0) {
        "`nNo anomalies detected" | Out-File $OutFile -Encoding utf8 -Append
        return
    }
    
    "`n=== DETECTED ANOMALIES ===" | Out-File $OutFile -Encoding utf8 -Append
    
    # Group by type
    $newCosts = $Anomalies | Where-Object { $_.Type -eq "NewCost" }
    $removedCosts = $Anomalies | Where-Object { $_.Type -eq "RemovedCost" }
    $significantChanges = $Anomalies | Where-Object { $_.Type -eq "SignificantChange" } | Sort-Object Change -Descending
    
    # Append new costs
    if ($newCosts.Count -gt 0) {
        "`n💰 NEW COSTS DETECTED:" | Out-File $OutFile -Encoding utf8 -Append
        $newCosts | Sort-Object Change -Descending | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name="November"; Expression={ "{0:N2} {1}" -f $_.NovemberCost, $Currency }},
                @{Name="December"; Expression={ "{0:N2} {1}" -f $_.DecemberCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append removed costs
    if ($removedCosts.Count -gt 0) {
        "`n💸 COSTS REMOVED:" | Out-File $OutFile -Encoding utf8 -Append
        $removedCosts | Sort-Object Change | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name="November"; Expression={ "{0:N2} {1}" -f $_.NovemberCost, $Currency }},
                @{Name="December"; Expression={ "{0:N2} {1}" -f $_.DecemberCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append significant changes
    if ($significantChanges.Count -gt 0) {
        "`n📊 SIGNIFICANT COST CHANGES:" | Out-File $OutFile -Encoding utf8 -Append
        $significantChanges | Select-Object -First 15 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name="November"; Expression={ "{0:N2} {1}" -f $_.NovemberCost, $Currency }},
                @{Name="December"; Expression={ "{0:N2} {1}" -f $_.DecemberCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }},
                @{Name="Percent"; Expression={ $_.PercentChange }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    "`nTotal anomalies detected: $($Anomalies.Count)" | Out-File $OutFile -Encoding utf8 -Append
}

# ---- Date ranges (edit as needed) ----
$fromNov = "2025-11-01"
$toNov   = "2025-11-30"
$fromDec = "2025-12-01"
$toDec   = "2025-12-31"

# Labels (for the header; adjust if you change dates above)
$sourceLabel = "Source: (11/1/2025 to 11/30/2025)"
$targetLabel = "Target: (12/1/2025 to 12/31/2025)"

# ---- Process each subscription ----
$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
  $id = $id.Trim()
  if (-not $id) { continue }

  Write-Host "`n=== Subscription: $id ==="

  $novFile = "nov-resources-$id.json"
  $decFile = "dec-resources-$id.json"
  $outFile = "diff-resources-top50-$id.txt"

  # Export November
  azure-cost costByResource -s $id --timeframe Custom --from $fromNov --to $toNov -o json |
    Out-File $novFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Nov export failed)"; continue }
  if (-not (Test-Path $novFile) -or (Get-Item $novFile).Length -eq 0) { Write-Warning "Skipping $id (Nov empty)"; continue }

  # Export December
  azure-cost costByResource -s $id --timeframe Custom --from $fromDec --to $toDec -o json |
    Out-File $decFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Dec export failed)"; continue }
  if (-not (Test-Path $decFile) -or (Get-Item $decFile).Length -eq 0) { Write-Warning "Skipping $id (Dec empty)"; continue }

  # Load JSON
  $nov = Get-Content $novFile -Raw | ConvertFrom-Json
  $dec = Get-Content $decFile -Raw | ConvertFrom-Json

  # Determine currency (assume consistent; fallback EUR)
  $currency = ($dec | Where-Object Currency | Select-Object -First 1 -ExpandProperty Currency)
  if (-not $currency) { $currency = "EUR" }

  # Build SUM maps (key -> total cost)
  $novMap = @{}
  foreach ($r in $nov) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($novMap.ContainsKey($k)) { $novMap[$k] += $c } else { $novMap[$k] = $c }
  }

  $decMap = @{}
  foreach ($r in $dec) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($decMap.ContainsKey($k)) { $decMap[$k] += $c } else { $decMap[$k] = $c }
  }

  # Build diff rows (one row per key): include new + increased (Change > 0)
  $diff = foreach ($k in $decMap.Keys) {
    $decCost = [double]$decMap[$k]
    $novCost = [double]($novMap[$k] ?? 0)
    $change  = $decCost - $novCost

    if ($change -le 0) { continue }

    # Grab one representative Dec row for display metadata
    $rep = $dec | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1

    [pscustomobject]@{
      Name        = (ResourceDisplayName $rep)
      Service     = $rep.ServiceName
      Location    = $rep.ResourceLocation
      ResourceGrp = $rep.ResourceGroupName
      November    = [math]::Round($novCost, 3)
      December    = [math]::Round($decCost, 3)
      Change      = [math]::Round($change, 3)

      # Treat "nov missing OR novCost==0" as "New spend" (optional; change to (-not $novMap.ContainsKey($k)) if you prefer)
      IsNew       = (-not $novMap.ContainsKey($k) -or $novCost -eq 0)
    }
  }

  # Top 50 by increase
  $top50 = $diff | Sort-Object Change -Descending | Select-Object -First 50

  # Write header
  @(
    Center "Azure Cost Diff (Resource Level)"
    Center $sourceLabel
    Center $targetLabel
    ""
  ) | Out-File $outFile -Encoding utf8

  # Write table (append)
  $top50 |
    Select-Object `
      Service,
      ResourceGrp,
      Location,
      @{n="Source";e={ "{0:N2} {1}" -f $_.November, $currency }},
      @{n="Target";e={ "{0:N2} {1}" -f $_.December, $currency }},
      @{n="Change";e={ "{0}{1:N2} {2}" -f ($(if ($_.Change -ge 0){"+"}else{""})), $_.Change, $currency }},
      @{n="New?";e={ if ($_.IsNew) { "YES" } else { "" } }},
      @{n="Name";e={ if ($_.Name.Length -gt 140) { $_.Name.Substring(0,140) + "…" } else { $_.Name } }} |
    Format-Table -AutoSize -Wrap |
    Out-String -Width 500 |
    Out-File $outFile -Encoding utf8 -Append

    # ---- Append Summary (for all included items, not just top50) ----
    $srcTotal = ($diff | Measure-Object November -Sum).Sum
    $tgtTotal = ($diff | Measure-Object December -Sum).Sum
    $chgTotal = ($diff | Measure-Object Change   -Sum).Sum
"" | Out-File $outFile -Encoding utf8 -Append
"Summary" | Out-File $outFile -Encoding utf8 -Append
"-------" | Out-File $outFile -Encoding utf8 -Append

@(
  [pscustomobject]@{
    Comparison = "TOTAL COSTS (new + increases)"
    Source     = ("{0:N2} {1}" -f $srcTotal, $currency)
    Target     = ("{0:N2} {1}" -f $tgtTotal, $currency)
    Change     = ("{0}{1:N2} {2}" -f ($(if ($chgTotal -ge 0){"+"}else{""})), $chgTotal, $currency)
  }
) |
  Format-Table -AutoSize |
  Out-String -Width 200 |
  Out-File $outFile -Encoding utf8 -Append

Write-Host "Saved: $outFile"

# Detect and append anomalies to file
$anomalies = Detect-CostAnomalies -NovData $nov -DecData $dec -SignificantChangeThreshold 0.5 -MinimumCostThreshold 1.0
Append-AnomaliesToFile -Anomalies $anomalies -Currency $currency -OutFile $outFile

Write-Host "Anomalies appended to: $outFile"
}

