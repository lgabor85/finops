# ------------------------------------------------------------
# Azure costByResource monthly diff per subscription with anomaly detection
# Includes: new items (not in September) + increases (October > September)
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
        [array]$SeptData,
        [array]$OctData,
        [double]$SignificantChangeThreshold = 0.5,  # 50% change threshold
        [double]$MinimumCostThreshold = 1.0         # Minimum cost to consider
    )
    
    # Build SUM maps (key -> total cost)
    $septMap = @{}
    foreach ($r in $SeptData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($septMap.ContainsKey($k)) { $septMap[$k] += $c } else { $septMap[$k] = $c }
    }

    $octMap = @{}
    foreach ($r in $OctData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($octMap.ContainsKey($k)) { $octMap[$k] += $c } else { $octMap[$k] = $c }
    }
    
    $anomalies = @()
    
    # Check all resources in October data
    foreach ($k in $octMap.Keys) {
        $octCost = [double]$octMap[$k]
        $septCost = [double]($septMap[$k] ?? 0)
        $change = $octCost - $septCost
        $percentChange = if ($septCost -ne 0) { [math]::Abs($change / $septCost) } else { [double]::PositiveInfinity }
        
        # Skip if below minimum cost threshold
        if ($octCost -lt $MinimumCostThreshold -and $septCost -lt $MinimumCostThreshold) {
            continue
        }
        
        # Check for new costs (appeared in Oct but not in Sept or Sept cost was 0)
        if (($septCost -eq 0 -or -not $septMap.ContainsKey($k)) -and $octCost -ge $MinimumCostThreshold) {
            # Get representative row for metadata
            $rep = $OctData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "NewCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SeptemberCost = $septCost
                OctoberCost = $octCost
                Change = $change
                PercentChange = if ($septCost -eq 0) { "N/A" } else { ("{0:P2}" -f $percentChange) }
                Message = "New cost detected"
            }
        }
        # Check for removed costs (existed in Sept but not in Oct or Oct cost is 0)
        elseif ($septCost -ge $MinimumCostThreshold -and $octCost -eq 0) {
            # Get representative row for metadata
            $rep = $SeptData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "RemovedCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SeptemberCost = $septCost
                OctoberCost = $octCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = "Cost removed"
            }
        }
        # Check for significant changes
        elseif ($septCost -ge $MinimumCostThreshold -and $octCost -ge $MinimumCostThreshold -and $percentChange -ge $SignificantChangeThreshold) {
            # Get representative row for metadata
            $rep = $OctData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "SignificantChange"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SeptemberCost = $septCost
                OctoberCost = $octCost
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
                @{Name="September"; Expression={ "{0:N2} {1}" -f $_.SeptemberCost, $Currency }},
                @{Name="October"; Expression={ "{0:N2} {1}" -f $_.OctoberCost, $Currency }},
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
                @{Name="September"; Expression={ "{0:N2} {1}" -f $_.SeptemberCost, $Currency }},
                @{Name="October"; Expression={ "{0:N2} {1}" -f $_.OctoberCost, $Currency }},
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
                @{Name="September"; Expression={ "{0:N2} {1}" -f $_.SeptemberCost, $Currency }},
                @{Name="October"; Expression={ "{0:N2} {1}" -f $_.OctoberCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }},
                @{Name="Percent"; Expression={ $_.PercentChange }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    "`nTotal anomalies detected: $($Anomalies.Count)" | Out-File $OutFile -Encoding utf8 -Append
}

# ---- Date ranges (edit as needed) ----
$fromSept = "2025-09-01"
$toSept   = "2025-09-30"
$fromOct = "2025-10-01"
$toOct   = "2025-10-31"

# Labels (for the header; adjust if you change dates above)
$sourceLabel = "Source: (9/1/2025 to 9/30/2025)"
$targetLabel = "Target: (10/1/2025 to 10/31/2025)"

# ---- Process each subscription ----
$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
  $id = $id.Trim()
  if (-not $id) { continue }

  Write-Host "`n=== Subscription: $id ==="

  $septFile = "sept-resources-$id.json"
  $octFile = "oct-resources-$id.json"
  $outFile = "diff-resources-sept-oct-top50-$id.txt"

  # Export September
  azure-cost costByResource -s $id --timeframe Custom --from $fromSept --to $toSept -o json |
    Out-File $septFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Sept export failed)"; continue }
  if (-not (Test-Path $septFile) -or (Get-Item $septFile).Length -eq 0) { Write-Warning "Skipping $id (Sept empty)"; continue }

  # Export October
  azure-cost costByResource -s $id --timeframe Custom --from $fromOct --to $toOct -o json |
    Out-File $octFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Oct export failed)"; continue }
  if (-not (Test-Path $octFile) -or (Get-Item $octFile).Length -eq 0) { Write-Warning "Skipping $id (Oct empty)"; continue }

  # Load JSON
  $sept = Get-Content $septFile -Raw | ConvertFrom-Json
  $oct = Get-Content $octFile -Raw | ConvertFrom-Json

  # Determine currency (assume consistent; fallback EUR)
  $currency = ($oct | Where-Object Currency | Select-Object -First 1 -ExpandProperty Currency)
  if (-not $currency) { $currency = "EUR" }

  # Build SUM maps (key -> total cost)
  $septMap = @{}
  foreach ($r in $sept) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($septMap.ContainsKey($k)) { $septMap[$k] += $c } else { $septMap[$k] = $c }
  }

  $octMap = @{}
  foreach ($r in $oct) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($octMap.ContainsKey($k)) { $octMap[$k] += $c } else { $octMap[$k] = $c }
  }

  # Build diff rows (one row per key): include new + increased (Change > 0)
  $diff = foreach ($k in $octMap.Keys) {
    $octCost = [double]$octMap[$k]
    $septCost = [double]($septMap[$k] ?? 0)
    $change  = $octCost - $septCost

    if ($change -le 0) { continue }

    # Grab one representative Oct row for display metadata
    $rep = $oct | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1

    [pscustomobject]@{
      Name        = (ResourceDisplayName $rep)
      Service     = $rep.ServiceName
      Location    = $rep.ResourceLocation
      ResourceGrp = $rep.ResourceGroupName
      September    = [math]::Round($septCost, 3)
      October    = [math]::Round($octCost, 3)
      Change      = [math]::Round($change, 3)

      # Treat "sept missing OR septCost==0" as "New spend" (optional; change to (-not $septMap.ContainsKey($k)) if you prefer)
      IsNew       = (-not $septMap.ContainsKey($k) -or $septCost -eq 0)
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
      @{n="Source";e={ "{0:N2} {1}" -f $_.September, $currency }},
      @{n="Target";e={ "{0:N2} {1}" -f $_.October, $currency }},
      @{n="Change";e={ "{0}{1:N2} {2}" -f ($(if ($_.Change -ge 0){"+"}else{""})), $_.Change, $currency }},
      @{n="New?";e={ if ($_.IsNew) { "YES" } else { "" } }},
      @{n="Name";e={ if ($_.Name.Length -gt 140) { $_.Name.Substring(0,140) + "…" } else { $_.Name } }} |
    Format-Table -AutoSize -Wrap |
    Out-String -Width 500 |
    Out-File $outFile -Encoding utf8 -Append

    # ---- Append Summary (for all included items, not just top50) ----
    $srcTotal = ($diff | Measure-Object September -Sum).Sum
    $tgtTotal = ($diff | Measure-Object October -Sum).Sum
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
$anomalies = Detect-CostAnomalies -SeptData $sept -OctData $oct -SignificantChangeThreshold 0.5 -MinimumCostThreshold 1.0
Append-AnomaliesToFile -Anomalies $anomalies -Currency $currency -OutFile $outFile

Write-Host "Anomalies appended to: $outFile"
}